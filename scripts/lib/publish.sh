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
