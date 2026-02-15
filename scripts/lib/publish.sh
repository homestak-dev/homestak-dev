#!/usr/bin/env bash
#
# publish.sh - Release publishing for release CLI
#
# Creates GitHub releases and handles packer image uploads
#

# Packer images to upload
PACKER_IMAGES=(
    "debian-12.qcow2"
    "debian-13.qcow2"
    "pve-9.qcow2"
)

# -----------------------------------------------------------------------------
# Packer Template Change Detection
# -----------------------------------------------------------------------------

packer_templates_changed() {
    local version="$1"
    local packer_dir="${WORKSPACE_DIR}/packer"

    # If no previous release, templates are "changed"
    local latest_tag
    latest_tag=$(git -C "$packer_dir" describe --tags --abbrev=0 2>/dev/null || echo "")

    if [[ -z "$latest_tag" ]]; then
        log_info "No previous packer release found, templates considered changed"
        echo "true"
        return
    fi

    # Compare template files between latest tag and HEAD
    local changed_files
    changed_files=$(git -C "$packer_dir" diff --name-only "$latest_tag" HEAD -- templates/ scripts/ cloud-init/ 2>/dev/null || echo "")

    if [[ -n "$changed_files" ]]; then
        log_info "Packer templates changed since $latest_tag:"
        echo "$changed_files" | while read -r file; do
            log_info "  - $file"
        done
        echo "true"
    else
        log_info "No packer template changes since $latest_tag"
        echo "false"
    fi
}

# -----------------------------------------------------------------------------
# Packer Upload to Latest
# -----------------------------------------------------------------------------

# Validate template names against PACKER_IMAGES
packer_validate_templates() {
    local -a templates=("$@")
    local valid=true

    for tmpl in "${templates[@]}"; do
        local found=false
        for img in "${PACKER_IMAGES[@]}"; do
            local img_name="${img%.qcow2}"
            if [[ "$tmpl" == "$img_name" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" != "true" ]]; then
            log_error "Unknown template: $tmpl"
            log_error "Valid templates: $(printf '%s ' "${PACKER_IMAGES[@]}" | sed 's/\.qcow2//g')"
            valid=false
        fi
    done

    [[ "$valid" == "true" ]]
}

packer_upload_to_latest() {
    local images_dir="$1"
    local dry_run="$2"
    local force="$3"
    shift 3
    local -a templates=("$@")

    # Validate images directory
    if [[ ! -d "$images_dir" ]]; then
        log_error "Images directory not found: $images_dir"
        return 1
    fi

    # Validate template names
    if ! packer_validate_templates "${templates[@]}"; then
        return 1
    fi

    # Ensure latest release exists
    if ! gh release view latest --repo homestak-dev/packer &>/dev/null; then
        if [[ "$dry_run" == "true" ]]; then
            log_info "[would create] 'latest' release in packer"
        else
            log_info "Creating 'latest' release in packer..."
            if ! gh release create latest --repo homestak-dev/packer \
                --title "Latest Images" --notes "Packer images" --prerelease; then
                log_error "Failed to create 'latest' release"
                return 1
            fi
        fi
    fi

    local uploaded=0
    local skipped=0

    for tmpl in "${templates[@]}"; do
        local image_path="${images_dir}/${tmpl}/${tmpl}.qcow2"
        local checksum_path="${images_dir}/${tmpl}/${tmpl}.qcow2.sha256"

        if [[ ! -f "$image_path" ]]; then
            log_error "Image not found: $image_path"
            return 1
        fi

        if [[ ! -f "$checksum_path" ]]; then
            log_error "Checksum not found: $checksum_path (run build.sh to generate)"
            return 1
        fi

        # Check if upload can be skipped (unless --force)
        if [[ "$force" != "true" ]]; then
            local local_checksum
            local_checksum=$(awk '{print $1}' "$checksum_path")

            # Download remote checksum for comparison
            local remote_checksum=""
            local tmp_remote
            tmp_remote=$(mktemp)
            if gh release download latest --repo homestak-dev/packer \
                --pattern "${tmpl}.qcow2.sha256" --dir "$(dirname "$tmp_remote")" \
                --output "$tmp_remote" 2>/dev/null; then
                remote_checksum=$(awk '{print $1}' "$tmp_remote")
            fi
            rm -f "$tmp_remote"

            if [[ -n "$remote_checksum" && "$local_checksum" == "$remote_checksum" ]]; then
                log_info "${tmpl}: unchanged (checksum match), skipping"
                ((skipped++))
                continue
            fi
        fi

        # Clean up existing remote assets for this template before uploading
        local existing_assets
        existing_assets=$(gh release view latest --repo homestak-dev/packer \
            --json assets --jq ".assets[].name" 2>/dev/null | grep "^${tmpl}\.qcow2" || true)

        if [[ -n "$existing_assets" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                echo "$existing_assets" | while read -r asset; do
                    log_info "[would delete] $asset from latest"
                done
            else
                echo "$existing_assets" | while read -r asset; do
                    log_info "Deleting old asset: $asset"
                    gh release delete-asset latest "$asset" --repo homestak-dev/packer --yes 2>/dev/null || true
                done
            fi
        fi

        # Determine if splitting is needed (GitHub 2GB limit)
        local size
        size=$(stat -c%s "$image_path" 2>/dev/null || stat -f%z "$image_path" 2>/dev/null)
        local threshold=$((1900 * 1024 * 1024))  # 1.9 GiB

        if [[ "$size" -gt "$threshold" ]]; then
            # Split and upload parts
            local tmp_split
            tmp_split=$(mktemp -d)

            if [[ "$dry_run" == "true" ]]; then
                local human_size
                human_size=$(numfmt --to=iec "$size" 2>/dev/null || echo "${size} bytes")
                log_info "[would split] ${tmpl}.qcow2 (${human_size}) into ~1.9GB parts"
                log_info "[would upload] ${tmpl}.qcow2.part* + ${tmpl}.qcow2.sha256 to latest"
            else
                log_info "Splitting ${tmpl}.qcow2 ($(numfmt --to=iec "$size" 2>/dev/null || echo "${size} bytes"))..."
                (cd "$tmp_split" && split -b 1900m "$image_path" "${tmpl}.qcow2.part")

                for part in "$tmp_split"/${tmpl}.qcow2.part*; do
                    [[ -f "$part" ]] || continue
                    local part_name
                    part_name=$(basename "$part")
                    log_info "Uploading $part_name..."
                    if ! gh release upload latest "$part" --repo homestak-dev/packer --clobber; then
                        log_error "Failed to upload $part_name"
                        rm -rf "$tmp_split"
                        return 1
                    fi
                done
            fi

            rm -rf "$tmp_split"
        else
            # Upload single file
            if [[ "$dry_run" == "true" ]]; then
                log_info "[would upload] ${tmpl}.qcow2 to latest"
            else
                log_info "Uploading ${tmpl}.qcow2..."
                if ! gh release upload latest "$image_path" --repo homestak-dev/packer --clobber; then
                    log_error "Failed to upload ${tmpl}.qcow2"
                    return 1
                fi
            fi
        fi

        # Upload checksum
        if [[ "$dry_run" == "true" ]]; then
            log_info "[would upload] ${tmpl}.qcow2.sha256 to latest"
        else
            log_info "Uploading ${tmpl}.qcow2.sha256..."
            if ! gh release upload latest "$checksum_path" --repo homestak-dev/packer --clobber; then
                log_error "Failed to upload ${tmpl}.qcow2.sha256"
                return 1
            fi
        fi

        ((uploaded++))
    done

    if [[ "$dry_run" == "true" ]]; then
        log_info "Would upload $uploaded template(s), skip $skipped unchanged"
    else
        if [[ $uploaded -gt 0 ]]; then
            log_success "Uploaded $uploaded template(s) to latest ($skipped unchanged)"
            audit_log "PACKER_UPLOAD" "cli" "Uploaded $uploaded template(s) to latest"
        else
            log_info "All $skipped template(s) unchanged, nothing to upload"
        fi
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Packer Remove from Latest
# -----------------------------------------------------------------------------

packer_remove_from_latest() {
    local dry_run="$1"
    local remove_all="$2"
    shift 2
    local -a prefixes=("$@")

    # Check latest release exists
    if ! gh release view latest --repo homestak-dev/packer &>/dev/null; then
        log_error "No 'latest' release found in packer"
        return 1
    fi

    # Get all asset names from the release
    local all_assets
    all_assets=$(gh release view latest --repo homestak-dev/packer \
        --json assets --jq ".assets[].name" 2>/dev/null || true)

    if [[ -z "$all_assets" ]]; then
        log_info "No assets on latest release"
        return 0
    fi

    # Build list of assets to remove
    local -a assets_to_remove=()

    if [[ "$remove_all" == "true" ]]; then
        # Remove all assets
        while IFS= read -r asset; do
            assets_to_remove+=("$asset")
        done <<< "$all_assets"
    else
        # Remove assets matching name prefixes ({prefix}.qcow2*)
        for prefix in "${prefixes[@]}"; do
            while IFS= read -r asset; do
                if [[ "$asset" == "${prefix}.qcow2"* ]]; then
                    assets_to_remove+=("$asset")
                fi
            done <<< "$all_assets"
        done
    fi

    if [[ ${#assets_to_remove[@]} -eq 0 ]]; then
        if [[ "$remove_all" == "true" ]]; then
            log_info "No assets on latest release"
        else
            log_warn "No assets found matching: ${prefixes[*]}"
        fi
        return 0
    fi

    for asset in "${assets_to_remove[@]}"; do
        if [[ "$dry_run" == "true" ]]; then
            log_info "[would delete] $asset from latest"
        else
            log_info "Deleting: $asset"
            if ! gh release delete-asset latest "$asset" --repo homestak-dev/packer --yes; then
                log_error "Failed to delete $asset"
            fi
        fi
    done

    local total_removed=${#assets_to_remove[@]}

    if [[ "$dry_run" == "true" ]]; then
        log_info "Would remove $total_removed asset(s) from latest"
    else
        log_success "Removed $total_removed asset(s) from latest"
        audit_log "PACKER_REMOVE" "cli" "Removed $total_removed asset(s) from latest"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Publish Pre-conditions
# -----------------------------------------------------------------------------

publish_check_preconditions() {
    local version="$1"
    local force="${2:-false}"
    local errors=()

    # Check tags phase completed (unless --force)
    if [[ "$force" != "true" ]]; then
        local tags_status
        tags_status=$(state_get_phase_status "tags")
        if [[ "$tags_status" != "complete" ]]; then
            errors+=("Tags not created (status: ${tags_status}). Use --force to override.")
        fi
    fi

    # Check all repos have tags
    for repo in "${REPOS[@]}"; do
        local repo_path
        if [[ "$repo" == "homestak-dev" ]]; then
            repo_path="${WORKSPACE_DIR}"
        else
            repo_path="${WORKSPACE_DIR}/${repo}"
        fi

        if [[ ! -d "$repo_path" ]]; then
            errors+=("Repo not found: $repo")
            continue
        fi

        if ! git -C "$repo_path" tag -l "v${version}" | grep -q "v${version}"; then
            errors+=("Tag v${version} not found locally in: $repo")
        fi
    done

    # Check gh CLI authentication
    if ! gh auth status &>/dev/null; then
        errors+=("GitHub CLI not authenticated. Run: gh auth login")
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        for err in "${errors[@]}"; do
            echo -e "  ${RED}✗${NC} $err"
        done
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Publish Operations
# -----------------------------------------------------------------------------

publish_is_prerelease() {
    local version="$1"
    # v0.x versions are prereleases
    [[ "$version" =~ ^0\. ]]
}

publish_create_single() {
    local repo="$1"
    local version="$2"
    local dry_run="${3:-true}"

    # Check if release already exists
    local release_info
    release_info=$(gh release view "v${version}" --repo "homestak-dev/${repo}" --json isDraft 2>/dev/null || true)

    if [[ -n "$release_info" ]]; then
        # Release exists - check if it's a draft
        if echo "$release_info" | grep -q '"isDraft":true'; then
            # Finalize the draft release
            local finalize_cmd="gh release edit v${version} --repo homestak-dev/${repo} --draft=false"
            if [[ "$dry_run" == "true" ]]; then
                echo "    (draft release v${version} exists, would finalize)"
                echo "    ${finalize_cmd}"
            else
                log_info "Finalizing draft release v${version} in ${repo}"
                audit_cmd "$finalize_cmd" "gh"
                if ! eval "$finalize_cmd"; then
                    log_error "Failed to finalize draft release in $repo"
                    return 1
                fi
                state_set_repo_field "$repo" "release" "done"
            fi
            return 0
        else
            # Already published
            if [[ "$dry_run" == "true" ]]; then
                echo "    (release v${version} already exists, would skip)"
            else
                log_info "Release v${version} already exists in ${repo}, skipping"
                state_set_repo_field "$repo" "release" "done"
            fi
            return 0
        fi
    fi

    local prerelease_flag=""
    if publish_is_prerelease "$version"; then
        prerelease_flag="--prerelease"
    fi

    local title="v${version}"
    local notes="Release v${version}"

    # Get changelog excerpt if available
    local repo_path
    if [[ "$repo" == "homestak-dev" ]]; then
        repo_path="${WORKSPACE_DIR}"
    else
        repo_path="${WORKSPACE_DIR}/${repo}"
    fi

    local changelog="${repo_path}/CHANGELOG.md"
    if [[ -f "$changelog" ]]; then
        notes="See CHANGELOG.md for details"
    fi

    local cmd="gh release create v${version} --repo homestak-dev/${repo} --title \"${title}\" --notes \"${notes}\" ${prerelease_flag}"

    if [[ "$dry_run" == "true" ]]; then
        echo "    ${cmd}"
        return 0
    fi

    # Execute release creation
    audit_cmd "$cmd" "gh"
    if ! eval "$cmd"; then
        log_error "Failed to create release in $repo"
        return 1
    fi

    # Update state
    state_set_repo_field "$repo" "release" "done"

    return 0
}

# -----------------------------------------------------------------------------
# Main Publish Runner
# -----------------------------------------------------------------------------

run_publish() {
    local version="$1"
    local dry_run="${2:-true}"
    local force="${3:-false}"
    local yes_flag="${4:-false}"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  RELEASE PUBLISHING: v${version}"
    if [[ "$dry_run" == "true" ]]; then
        echo "  Mode: DRY-RUN (no changes will be made)"
    else
        echo "  Mode: EXECUTE"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Check preconditions
    echo "Pre-conditions:"
    if ! publish_check_preconditions "$version" "$force"; then
        echo ""
        log_error "Pre-conditions not met"
        return 1
    fi

    if [[ "$force" == "true" ]]; then
        echo -e "  ${YELLOW}⚠${NC} Tag gate overridden with --force"
    else
        echo -e "  ${GREEN}✓${NC} Tags created for v${version}"
    fi
    echo -e "  ${GREEN}✓${NC} GitHub CLI authenticated"
    echo -e "  ${GREEN}✓${NC} All tags exist locally"
    echo ""

    # Show release type
    if publish_is_prerelease "$version"; then
        echo -e "Release type: ${YELLOW}Pre-release${NC} (v0.x)"
    else
        echo -e "Release type: ${GREEN}Stable${NC}"
    fi
    echo ""

    # Show actions
    echo "Actions to execute:"
    for repo in "${REPOS[@]}"; do
        echo "  - Create GitHub release v${version} in ${repo}"
    done
    echo ""
    echo "Total: ${#REPOS[@]} operations"
    echo ""

    # Check packer latest release has images
    local packer_asset_count
    packer_asset_count=$(gh release view latest --repo homestak-dev/packer --json assets --jq '.assets | length' 2>/dev/null || echo "0")
    if [[ "$packer_asset_count" -gt 0 ]]; then
        echo -e "Packer images: ${GREEN}${packer_asset_count} asset(s) on latest${NC}"
    else
        echo -e "Packer images: ${YELLOW}No assets on latest — run 'release.sh packer --upload' to upload${NC}"
    fi
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        echo "Commands that would be executed:"
        echo ""
        for repo in "${REPOS[@]}"; do
            echo "  ${repo}:"
            publish_create_single "$repo" "$version" "true"
            echo ""
        done

        echo "═══════════════════════════════════════════════════════════════"
        echo "  DRY-RUN COMPLETE - No changes made"
        echo "  Run with --execute to publish releases"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    # Confirmation prompt for execute mode (skip with --yes)
    if [[ "$yes_flag" != "true" ]]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo -e "  ${YELLOW}WARNING: This will create GitHub releases for all repos${NC}"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        read -p "Type 'yes' to proceed, or Ctrl+C to abort: " -r
        if [[ "$REPLY" != "yes" ]]; then
            log_info "Aborted by user"
            return 1
        fi
        echo ""
    fi

    # Execute release creation
    local failed=false

    for repo in "${REPOS[@]}"; do
        echo -n "  Creating release in ${repo}... "
        if publish_create_single "$repo" "$version" "false"; then
            echo -e "${GREEN}done${NC}"
        else
            echo -e "${RED}FAILED${NC}"
            failed=true
            break
        fi
    done

    if [[ "$failed" == "true" ]]; then
        echo ""
        log_error "Release creation failed"
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  RESULT: ${GREEN}SUCCESS${NC}"
    echo "  Releases created: v${version} in ${#REPOS[@]} repos"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    return 0
}
