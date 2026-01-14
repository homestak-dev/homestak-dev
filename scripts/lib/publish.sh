#!/usr/bin/env bash
#
# publish.sh - Release publishing for release CLI
#
# Creates GitHub releases and handles packer image uploads
#

# Packer images to upload
PACKER_IMAGES=(
    "debian-12-custom.qcow2"
    "debian-13-custom.qcow2"
    "debian-13-pve.qcow2"
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

packer_get_latest_release() {
    # Get the latest packer release that has image assets (excluding current version)
    local current_version="$1"
    local tags
    tags=$(gh release list --repo homestak-dev/packer --limit 10 | awk '{print $1}')

    for tag in $tags; do
        # Skip current version and 'latest' tag
        [[ "$tag" == "v${current_version}" ]] && continue
        [[ "$tag" == "latest" ]] && continue

        # Check if this release has assets
        local asset_count
        asset_count=$(gh release view "$tag" --repo homestak-dev/packer --json assets --jq '.assets | length' 2>/dev/null)
        if [[ "$asset_count" -gt 0 ]]; then
            echo "$tag"
            return 0
        fi
    done
    echo ""
}

packer_dispatch_copy_images() {
    local version="$1"
    local source_release="$2"
    local dry_run="${3:-true}"

    if [[ -z "$source_release" ]]; then
        source_release=$(packer_get_latest_release "$version")
    fi

    if [[ -z "$source_release" ]]; then
        log_error "No source release found with image assets"
        return 1
    fi

    log_info "Copying images from $source_release to v${version}"

    local workflow="copy-images.yml"
    local cmd="gh workflow run $workflow --repo homestak-dev/packer -f source_release=$source_release -f target_release=v${version}"

    if [[ "$dry_run" == "true" ]]; then
        echo "    ${cmd}"
        return 0
    fi

    # Check if workflow exists
    if ! gh workflow list --repo homestak-dev/packer --json name -q '.[].name' 2>/dev/null | grep -q "Copy Images"; then
        log_warn "Workflow '$workflow' not found in packer repo"
        log_info "Images must be copied manually or workflow created"
        return 1
    fi

    # Dispatch the workflow
    audit_cmd "$cmd" "gh"
    if ! eval "$cmd"; then
        log_error "Failed to dispatch copy-images workflow"
        return 1
    fi

    log_success "Workflow dispatched. Monitor at: https://github.com/homestak-dev/packer/actions"
    return 0
}

packer_copy_images_local() {
    local version="$1"
    local source_release="$2"
    local dry_run="${3:-true}"

    if [[ -z "$source_release" ]]; then
        source_release=$(packer_get_latest_release "$version")
    fi

    if [[ -z "$source_release" ]]; then
        log_error "No source release found with image assets"
        return 1
    fi

    log_info "Copying images from $source_release to v${version} locally"

    # Create temp directory for images
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    # Download assets from source release (only images, not SHA256SUMS - we regenerate it)
    local assets
    assets=$(gh release view "$source_release" --repo homestak-dev/packer --json assets --jq '.assets[].name' 2>/dev/null | grep -v SHA256SUMS)

    if [[ -z "$assets" ]]; then
        log_error "No assets found in source release $source_release"
        return 1
    fi

    # Download images
    for asset in $assets; do
        local download_cmd="gh release download $source_release --repo homestak-dev/packer --pattern \"$asset\" --dir \"$tmp_dir\""

        if [[ "$dry_run" == "true" ]]; then
            echo "    ${download_cmd}"
        else
            log_info "Downloading $asset..."
            if ! eval "$download_cmd"; then
                log_error "Failed to download $asset"
                return 1
            fi
        fi
    done

    # Generate fresh SHA256SUMS (don't assume source has it - v0.17 predates feature)
    local sha_cmd="cd \"$tmp_dir\" && sha256sum *.qcow2 > SHA256SUMS 2>/dev/null || true"
    if [[ "$dry_run" == "true" ]]; then
        echo "    ${sha_cmd}"
    else
        log_info "Generating SHA256SUMS..."
        if ! eval "$sha_cmd"; then
            log_warn "Failed to generate SHA256SUMS (no qcow2 files?)"
        fi
    fi

    # Upload all files including generated SHA256SUMS
    local upload_files
    if [[ "$dry_run" == "true" ]]; then
        # In dry-run, list expected files
        upload_files="$assets SHA256SUMS"
    else
        # In execute mode, list actual files
        upload_files=$(ls "$tmp_dir")
    fi

    for file in $upload_files; do
        local upload_cmd="gh release upload v${version} \"${tmp_dir}/${file}\" --repo homestak-dev/packer --clobber"

        if [[ "$dry_run" == "true" ]]; then
            echo "    ${upload_cmd}"
        else
            # Skip if file doesn't exist (for dry-run files list)
            [[ ! -f "${tmp_dir}/${file}" ]] && continue

            log_info "Uploading $file..."
            if ! eval "$upload_cmd"; then
                log_error "Failed to upload $file"
                return 1
            fi
        fi
    done

    if [[ "$dry_run" != "true" ]]; then
        log_success "Images copied from $source_release to v${version} (SHA256SUMS regenerated)"
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

publish_upload_packer_images() {
    local version="$1"
    local images_dir="$2"
    local dry_run="${3:-true}"

    if [[ -z "$images_dir" ]]; then
        log_info "No images directory specified, skipping packer uploads"
        return 0
    fi

    if [[ ! -d "$images_dir" ]]; then
        log_error "Images directory not found: $images_dir"
        return 1
    fi

    local uploaded=0
    for img in "${PACKER_IMAGES[@]}"; do
        local img_path="${images_dir}/${img}"
        if [[ -f "$img_path" ]]; then
            local cmd="gh release upload v${version} \"${img_path}\" --repo homestak-dev/packer --clobber"
            if [[ "$dry_run" == "true" ]]; then
                echo "    ${cmd}"
            else
                audit_cmd "$cmd" "gh"
                if ! eval "$cmd"; then
                    log_error "Failed to upload $img"
                    return 1
                fi
            fi
            ((uploaded++))
        else
            log_warn "Image not found: $img_path"
        fi
    done

    if [[ $uploaded -eq 0 ]]; then
        log_warn "No packer images found to upload"
    fi

    return 0
}

publish_update_latest() {
    local version="$1"
    local dry_run="${2:-true}"

    # Update latest tag to point to new release
    local delete_cmd="gh release delete latest --repo homestak-dev/packer --yes"
    local delete_tag_cmd="git -C ${WORKSPACE_DIR}/packer push origin :refs/tags/latest"
    local create_cmd="gh release create latest --repo homestak-dev/packer --title \"Latest Release\" --notes \"Points to v${version}\" --latest"

    if [[ "$dry_run" == "true" ]]; then
        echo "    ${delete_cmd} (if exists)"
        echo "    ${delete_tag_cmd} (if exists)"
        echo "    ${create_cmd}"
        return 0
    fi

    # Delete existing latest release/tag if present
    audit_cmd "$delete_cmd (cleanup)" "gh"
    eval "$delete_cmd" 2>/dev/null || true

    audit_cmd "$delete_tag_cmd (cleanup)" "git"
    eval "$delete_tag_cmd" 2>/dev/null || true

    # Create new latest release
    audit_cmd "$create_cmd" "gh"
    if ! eval "$create_cmd"; then
        log_warn "Could not create latest release (may need manual update)"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Main Publish Runner
# -----------------------------------------------------------------------------

run_publish() {
    local version="$1"
    local dry_run="${2:-true}"
    local force="${3:-false}"
    local images_dir="${4:-}"

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
    local cmd_count=${#REPOS[@]}
    for repo in "${REPOS[@]}"; do
        echo "  - Create GitHub release v${version} in ${repo}"
    done
    if [[ -n "$images_dir" ]]; then
        echo "  - Upload packer images"
        echo "  - Update 'latest' tag in packer"
        ((cmd_count+=2))
    fi
    echo ""
    echo "Total: ${cmd_count} operations"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        echo "Commands that would be executed:"
        echo ""
        for repo in "${REPOS[@]}"; do
            echo "  ${repo}:"
            publish_create_single "$repo" "$version" "true"
            echo ""
        done

        if [[ -n "$images_dir" ]]; then
            echo "  packer images:"
            publish_upload_packer_images "$version" "$images_dir" "true"
            echo ""
            echo "  latest tag:"
            publish_update_latest "$version" "true"
            echo ""
        fi

        echo "═══════════════════════════════════════════════════════════════"
        echo "  DRY-RUN COMPLETE - No changes made"
        echo "  Run with --execute to publish releases"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    # Confirmation prompt for execute mode
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

    # Upload packer images if specified
    if [[ -n "$images_dir" ]]; then
        echo ""
        echo "Uploading packer images..."
        if ! publish_upload_packer_images "$version" "$images_dir" "false"; then
            log_error "Failed to upload packer images"
            return 1
        fi

        echo ""
        echo "Updating latest tag..."
        publish_update_latest "$version" "false"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  RESULT: ${GREEN}SUCCESS${NC}"
    echo "  Releases created: v${version} in ${#REPOS[@]} repos"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    return 0
}
