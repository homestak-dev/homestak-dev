#!/usr/bin/env bash
#
# tag.sh - Tag creation for release CLI
#
# Creates git tags in dependency order with dry-run and rollback support
#

# -----------------------------------------------------------------------------
# Tag Pre-conditions
# -----------------------------------------------------------------------------

tag_check_preconditions() {
    local version="$1"
    local force="${2:-false}"
    local errors=()

    # Check validation phase completed (unless --force)
    if [[ "$force" != "true" ]]; then
        local validation_status
        validation_status=$(state_get_phase_status "validation")
        if [[ "$validation_status" != "complete" ]]; then
            errors+=("Validation not complete (status: ${validation_status}). Use --force to override.")
        fi
    fi

    # Check all repos are clean
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

        local status
        status=$(git -C "$repo_path" status --porcelain 2>/dev/null)
        if [[ -n "$status" ]]; then
            errors+=("Repo has uncommitted changes: $repo")
        fi
    done

    # Check no existing tags
    for repo in "${REPOS[@]}"; do
        local repo_path
        if [[ "$repo" == "homestak-dev" ]]; then
            repo_path="${WORKSPACE_DIR}"
        else
            repo_path="${WORKSPACE_DIR}/${repo}"
        fi

        if [[ ! -d "$repo_path" ]]; then
            continue
        fi

        if git -C "$repo_path" tag -l "v${version}" | grep -q "v${version}"; then
            errors+=("Tag v${version} already exists locally in: $repo")
        elif git -C "$repo_path" ls-remote --tags origin "v${version}" 2>/dev/null | grep -q "v${version}"; then
            errors+=("Tag v${version} already exists on remote in: $repo")
        fi
    done

    if [[ ${#errors[@]} -gt 0 ]]; then
        for err in "${errors[@]}"; do
            echo -e "  ${RED}✗${NC} $err"
        done
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Tag Operations
# -----------------------------------------------------------------------------

tag_create_single() {
    local repo="$1"
    local version="$2"
    local dry_run="${3:-true}"

    local repo_path
    if [[ "$repo" == "homestak-dev" ]]; then
        repo_path="${WORKSPACE_DIR}"
    else
        repo_path="${WORKSPACE_DIR}/${repo}"
    fi

    local tag_cmd="git -C ${repo_path} tag -a v${version} -m \"Release v${version}\""
    local push_cmd="git -C ${repo_path} push origin v${version}"

    if [[ "$dry_run" == "true" ]]; then
        echo "    ${tag_cmd}"
        echo "    ${push_cmd}"
        return 0
    fi

    # Execute tag creation
    audit_cmd "$tag_cmd" "git"
    if ! eval "$tag_cmd"; then
        log_error "Failed to create tag in $repo"
        return 1
    fi

    # Execute push
    audit_cmd "$push_cmd" "git"
    if ! eval "$push_cmd"; then
        log_error "Failed to push tag in $repo"
        return 1
    fi

    # Update state
    state_set_repo_field "$repo" "tag" "done"

    return 0
}

tag_rollback_single() {
    local repo="$1"
    local version="$2"

    local repo_path
    if [[ "$repo" == "homestak-dev" ]]; then
        repo_path="${WORKSPACE_DIR}"
    else
        repo_path="${WORKSPACE_DIR}/${repo}"
    fi

    # Delete local tag
    local local_cmd="git -C ${repo_path} tag -d v${version}"
    audit_cmd "$local_cmd (rollback)" "git"
    eval "$local_cmd" 2>/dev/null || true

    # Delete remote tag
    local remote_cmd="git -C ${repo_path} push origin :refs/tags/v${version}"
    audit_cmd "$remote_cmd (rollback)" "git"
    eval "$remote_cmd" 2>/dev/null || true

    # Update state
    state_set_repo_field "$repo" "tag" "rolled_back"
}

tag_reset_single() {
    local repo="$1"
    local version="$2"
    local dry_run="${3:-true}"

    local repo_path
    if [[ "$repo" == "homestak-dev" ]]; then
        repo_path="${WORKSPACE_DIR}"
    else
        repo_path="${WORKSPACE_DIR}/${repo}"
    fi

    local delete_local="git -C ${repo_path} tag -d v${version}"
    local delete_remote="git -C ${repo_path} push origin :refs/tags/v${version}"
    local create_tag="git -C ${repo_path} tag -a v${version} -m \"Release v${version}\""
    local push_tag="git -C ${repo_path} push origin v${version}"

    if [[ "$dry_run" == "true" ]]; then
        echo "    ${delete_local}"
        echo "    ${delete_remote}"
        echo "    ${create_tag}"
        echo "    ${push_tag}"
        return 0
    fi

    # Delete local tag (may not exist)
    audit_cmd "$delete_local (reset)" "git"
    eval "$delete_local" 2>/dev/null || true

    # Delete remote tag (may not exist)
    audit_cmd "$delete_remote (reset)" "git"
    eval "$delete_remote" 2>/dev/null || true

    # Create new tag at HEAD
    audit_cmd "$create_tag (reset)" "git"
    if ! eval "$create_tag"; then
        log_error "Failed to create tag in $repo"
        return 1
    fi

    # Push new tag
    audit_cmd "$push_tag (reset)" "git"
    if ! eval "$push_tag"; then
        log_error "Failed to push tag in $repo"
        return 1
    fi

    # Update state
    state_set_repo_field "$repo" "tag" "done"

    return 0
}

# -----------------------------------------------------------------------------
# Main Tag Runner
# -----------------------------------------------------------------------------

run_tag() {
    local version="$1"
    local dry_run="${2:-true}"
    local force="${3:-false}"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TAG CREATION: v${version}"
    if [[ "$dry_run" == "true" ]]; then
        echo "  Mode: DRY-RUN (no changes will be made)"
    else
        echo "  Mode: EXECUTE"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Check preconditions
    echo "Pre-conditions:"
    if ! tag_check_preconditions "$version" "$force"; then
        echo ""
        log_error "Pre-conditions not met"
        return 1
    fi

    if [[ "$force" == "true" ]]; then
        echo -e "  ${YELLOW}⚠${NC} Validation gate overridden with --force"
    else
        local validation_report
        validation_report=$(state_read '.phases.validation.report // "none"')
        echo -e "  ${GREEN}✓${NC} Validation passed (report: ${validation_report})"
    fi
    echo -e "  ${GREEN}✓${NC} All repos have clean working trees"
    echo -e "  ${GREEN}✓${NC} No existing v${version} tags"
    echo ""

    # Show actions
    echo "Actions to execute:"
    local cmd_count=0
    for repo in "${REPOS[@]}"; do
        ((cmd_count+=2))
        echo "  ${cmd_count}. Create tag v${version} in ${repo}"
    done
    echo ""
    echo "Total: $((cmd_count)) commands (${#REPOS[@]} repos × 2 commands each)"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        echo "Commands that would be executed:"
        echo ""
        for repo in "${REPOS[@]}"; do
            echo "  ${repo}:"
            tag_create_single "$repo" "$version" "true"
            echo ""
        done

        echo "Rollback command (if needed):"
        echo "  release.sh tag --rollback"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  DRY-RUN COMPLETE - No changes made"
        echo "  Run with --execute to create tags"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    # Confirmation prompt for execute mode
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  ${YELLOW}WARNING: This will create and push tags to all repos${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    read -p "Type 'yes' to proceed, or Ctrl+C to abort: " -r
    if [[ "$REPLY" != "yes" ]]; then
        log_info "Aborted by user"
        return 1
    fi
    echo ""

    # Execute tag creation
    local created_repos=()
    local failed=false

    for repo in "${REPOS[@]}"; do
        echo -n "  Creating tag in ${repo}... "
        if tag_create_single "$repo" "$version" "false"; then
            echo -e "${GREEN}done${NC}"
            created_repos+=("$repo")
        else
            echo -e "${RED}FAILED${NC}"
            failed=true
            break
        fi
    done

    if [[ "$failed" == "true" ]]; then
        echo ""
        log_error "Tag creation failed. Rolling back..."
        for repo in "${created_repos[@]}"; do
            echo -n "  Rolling back ${repo}... "
            tag_rollback_single "$repo" "$version"
            echo "done"
        done
        echo ""
        log_error "Tags rolled back. Fix the issue and try again."
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  RESULT: ${GREEN}SUCCESS${NC}"
    echo "  Tags created: v${version} in ${#REPOS[@]} repos"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    return 0
}

run_tag_rollback() {
    local version="$1"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TAG ROLLBACK: v${version}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    echo -e "${YELLOW}WARNING: This will delete tag v${version} from all repos${NC}"
    echo ""
    read -p "Type 'yes' to proceed, or Ctrl+C to abort: " -r
    if [[ "$REPLY" != "yes" ]]; then
        log_info "Aborted by user"
        return 1
    fi
    echo ""

    for repo in "${REPOS[@]}"; do
        echo -n "  Rolling back ${repo}... "
        tag_rollback_single "$repo" "$version"
        echo "done"
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  ROLLBACK COMPLETE"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    return 0
}

run_tag_reset() {
    local version="$1"
    local dry_run="${2:-true}"
    local target_repo="${3:-}"  # Empty = all repos

    # Safety check: only allow reset for v0.x pre-releases
    if [[ ! "$version" =~ ^0\. ]]; then
        log_error "Tag reset is only allowed for v0.x pre-releases (got: v${version})"
        log_error "For production releases, use proper versioning (e.g., v1.0.1)"
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TAG RESET: v${version}"
    if [[ -n "$target_repo" ]]; then
        echo "  Scope: ${target_repo} only"
    else
        echo "  Scope: All ${#REPOS[@]} repos"
    fi
    if [[ "$dry_run" == "true" ]]; then
        echo "  Mode: DRY-RUN (no changes will be made)"
    else
        echo "  Mode: EXECUTE"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Validate target repo if specified
    local repos_to_reset=()
    if [[ -n "$target_repo" ]]; then
        local found=false
        for repo in "${REPOS[@]}"; do
            if [[ "$repo" == "$target_repo" ]]; then
                found=true
                repos_to_reset+=("$repo")
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            log_error "Unknown repo: $target_repo"
            log_error "Valid repos: ${REPOS[*]}"
            return 1
        fi
    else
        repos_to_reset=("${REPOS[@]}")
    fi

    # Check repos have clean working trees
    echo "Pre-conditions:"
    local errors=()
    for repo in "${repos_to_reset[@]}"; do
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

        local status
        status=$(git -C "$repo_path" status --porcelain 2>/dev/null)
        if [[ -n "$status" ]]; then
            errors+=("Repo has uncommitted changes: $repo")
        fi
    done

    if [[ ${#errors[@]} -gt 0 ]]; then
        for err in "${errors[@]}"; do
            echo -e "  ${RED}✗${NC} $err"
        done
        return 1
    fi
    echo -e "  ${GREEN}✓${NC} All target repos have clean working trees"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        echo "Commands that would be executed:"
        echo ""
        for repo in "${repos_to_reset[@]}"; do
            echo "  ${repo}:"
            tag_reset_single "$repo" "$version" "true"
            echo ""
        done

        echo "═══════════════════════════════════════════════════════════════"
        echo "  DRY-RUN COMPLETE - No changes made"
        echo "  Run with --execute to reset tags"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    # Confirmation prompt for execute mode
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  ${YELLOW}WARNING: This will DELETE and RECREATE tags at HEAD${NC}"
    echo -e "  ${YELLOW}This CANNOT be undone if others have pulled the tags${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    read -p "Type 'yes' to proceed, or Ctrl+C to abort: " -r
    if [[ "$REPLY" != "yes" ]]; then
        log_info "Aborted by user"
        return 1
    fi
    echo ""

    # Execute tag reset
    local failed=false
    for repo in "${repos_to_reset[@]}"; do
        echo -n "  Resetting tag in ${repo}... "
        if tag_reset_single "$repo" "$version" "false"; then
            echo -e "${GREEN}done${NC}"
        else
            echo -e "${RED}FAILED${NC}"
            failed=true
        fi
    done

    echo ""
    if [[ "$failed" == "true" ]]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo -e "  RESULT: ${YELLOW}PARTIAL${NC}"
        echo "  Some repos failed - check output above"
        echo "═══════════════════════════════════════════════════════════════"
        return 1
    else
        echo "═══════════════════════════════════════════════════════════════"
        echo -e "  RESULT: ${GREEN}SUCCESS${NC}"
        echo "  Tags reset to HEAD: v${version} in ${#repos_to_reset[@]} repos"
        echo "═══════════════════════════════════════════════════════════════"
        audit_log "TAG_RESET" "cli" "Tags v${version} reset in ${#repos_to_reset[@]} repos"
    fi
    echo ""

    return 0
}
