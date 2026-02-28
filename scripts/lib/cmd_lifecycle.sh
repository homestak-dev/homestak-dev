#!/usr/bin/env bash
#
# cmd_lifecycle.sh - Release lifecycle bookend commands
#
# Commands: cmd_init, cmd_status, cmd_resume, cmd_audit, cmd_retrospective, cmd_close
#

cmd_init() {
    local version=""
    local issue=""
    local no_issue=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                version="$2"
                shift 2
                ;;
            --issue)
                issue="$2"
                shift 2
                ;;
            --no-issue)
                no_issue=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if [[ -z "$version" ]]; then
        log_error "Version required: release.sh init --version X.Y"
        exit 1
    fi

    # Require --issue unless --no-issue is explicitly set (v0.31+)
    if [[ -z "$issue" && "$no_issue" != "true" ]]; then
        log_error "Release issue required: release.sh init --version X.Y --issue N"
        echo ""
        echo "The release issue is the tracking hub for the entire release."
        echo "Create it first: gh issue create --title 'vX.Y Release Planning - Theme' --label release"
        echo ""
        echo "Or find existing: gh issue list --label release"
        echo ""
        echo "For hotfix releases without tracking issue, use: --no-issue"
        exit 1
    fi

    # Check if state already exists
    if state_exists; then
        local existing_version existing_status
        existing_version=$(state_get_version)
        existing_status=$(state_get_status)

        if [[ "$existing_status" == "in_progress" ]]; then
            log_error "Release v${existing_version} is already in progress"
            log_error "Use 'release.sh status' to check progress"
            log_error "Or remove ${STATE_FILE} to start fresh"
            exit 1
        fi

        log_warn "Previous release state found (v${existing_version}, status: ${existing_status})"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted"
            exit 0
        fi
    fi

    # Initialize state and audit log
    state_init "$version" "$issue"
    audit_init "$version"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Release v${version} initialized"
    if [[ -n "$issue" ]]; then
        echo "  Tracking issue: #${issue}"
    else
        echo -e "  ${YELLOW}WARNING: No tracking issue linked (--no-issue mode)${NC}"
        echo "  AAR and retrospective will not have a home."
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Next steps:"
    echo "  1. release.sh preflight"
    echo "  2. Update CHANGELOGs"
    echo "  3. release.sh validate --manifest n1-push --host srv1"
    echo "  4. release.sh tag --dry-run"
    echo "  5. release.sh tag --execute"
    echo "  6. release.sh publish --execute"
    echo "  7. release.sh verify"
    echo ""
}

cmd_status() {
    local json_output=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                json_output=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if ! state_exists; then
        if [[ "$json_output" == "true" ]]; then
            echo '{"status": "no_release", "message": "No release in progress"}'
            exit 0
        fi
        log_info "No release in progress"
        log_info "Start with: release.sh init --version X.Y"
        exit 0
    fi

    if ! state_validate; then
        if [[ "$json_output" == "true" ]]; then
            echo '{"status": "error", "message": "State file is corrupted"}'
            exit 3
        fi
        log_error "State file is corrupted"
        exit 3
    fi

    local version status started_at issue
    version=$(state_get_version)
    status=$(state_get_status)
    started_at=$(state_read '.release.started_at')
    issue=$(state_get_issue)

    if [[ "$json_output" == "true" ]]; then
        # Build JSON output
        local phases_json="{"
        local first=true
        for phase in preflight validation tags releases verification; do
            local phase_status
            phase_status=$(state_get_phase_status "$phase")
            if [[ "$first" == "true" ]]; then
                first=false
            else
                phases_json+=","
            fi
            phases_json+="\"${phase}\":\"${phase_status:-pending}\""
        done
        phases_json+="}"

        local repos_json="{"
        first=true
        for repo in "${REPOS[@]}"; do
            local tag_status release_status
            tag_status=$(state_get_repo_field "$repo" "tag")
            release_status=$(state_get_repo_field "$repo" "release")
            if [[ "$first" == "true" ]]; then
                first=false
            else
                repos_json+=","
            fi
            repos_json+="\"${repo}\":{\"tag\":\"${tag_status:-pending}\",\"release\":\"${release_status:-pending}\"}"
        done
        repos_json+="}"

        cat << EOF
{
  "status": "${status}",
  "version": "${version}",
  "issue": ${issue:-null},
  "started_at": "${started_at}",
  "phases": ${phases_json},
  "repos": ${repos_json}
}
EOF
        exit 0
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Release v${version} - Status: ${status}"
    if [[ -n "$issue" ]]; then
        echo "  Tracking: https://github.com/homestak-dev/homestak-dev/issues/${issue}"
    else
        echo -e "  Tracking: ${YELLOW}(no issue linked)${NC}"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Started: ${started_at}"
    echo ""
    echo "Phases:"
    for phase in preflight validation tags releases verification; do
        local phase_status
        phase_status=$(state_get_phase_status "$phase")
        case "$phase_status" in
            complete)
                echo -e "  ${GREEN}✓${NC} ${phase}"
                ;;
            in_progress)
                echo -e "  ${YELLOW}●${NC} ${phase} (in progress)"
                ;;
            failed)
                echo -e "  ${RED}✗${NC} ${phase} (failed)"
                ;;
            *)
                echo -e "  ○ ${phase}"
                ;;
        esac
    done

    echo ""
    echo "Repos:"
    for repo in "${REPOS[@]}"; do
        local tag_status release_status
        tag_status=$(state_get_repo_field "$repo" "tag")
        release_status=$(state_get_repo_field "$repo" "release")

        local tag_icon release_icon
        case "$tag_status" in
            done) tag_icon="${GREEN}✓${NC}" ;;
            pending) tag_icon="○" ;;
            *) tag_icon="${RED}?${NC}" ;;
        esac
        case "$release_status" in
            done) release_icon="${GREEN}✓${NC}" ;;
            pending) release_icon="○" ;;
            *) release_icon="${RED}?${NC}" ;;
        esac

        printf "  %-15s tag: %b  release: %b\n" "$repo" "$tag_icon" "$release_icon"
    done
    echo ""
}

cmd_audit() {
    local lines=20

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lines)
                lines="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    audit_show "$lines"
}

cmd_resume() {
    # AI-friendly context recovery for session resumption
    if ! state_exists; then
        echo "## Release Session Recovery"
        echo ""
        echo "**Status:** No release in progress"
        echo ""
        echo "### Next Steps"
        echo "1. Run \`release.sh init --version X.Y\` to start a new release"
        exit 0
    fi

    if ! state_validate; then
        echo "## Release Session Recovery"
        echo ""
        echo "**Status:** ERROR - State file corrupted"
        echo ""
        echo "### Next Steps"
        echo "1. Check \`.release-state.json\` for corruption"
        echo "2. Remove file and run \`release.sh init\` to start fresh"
        exit 3
    fi

    local version status started_at issue
    version=$(state_get_version)
    status=$(state_get_status)
    started_at=$(state_read '.release.started_at')
    issue=$(state_get_issue)

    echo "## Release Session Recovery"
    echo ""
    echo "**Version:** v${version}"
    if [[ -n "$issue" ]]; then
        echo "**Issue:** homestak-dev#${issue}"
    else
        echo "**Issue:** (none linked)"
    fi
    echo "**Status:** ${status}"
    echo "**Started:** ${started_at}"
    echo ""

    # Phase status table
    echo "### Phase Status"
    echo ""
    echo "| Phase | Status | Completed |"
    echo "|-------|--------|-----------|"
    for phase in preflight validation tags releases verification; do
        local phase_status completed_at
        phase_status=$(state_get_phase_status "$phase")
        completed_at=$(state_read ".phases.${phase}.completed_at")
        [[ "$completed_at" == "null" ]] && completed_at="-"
        echo "| ${phase} | ${phase_status} | ${completed_at} |"
    done
    echo ""

    # Repo status table
    echo "### Repo Status"
    echo ""
    echo "| Repo | Tag | Release |"
    echo "|------|-----|---------|"
    for repo in "${REPOS[@]}"; do
        local tag_status release_status
        tag_status=$(state_get_repo_field "$repo" "tag")
        release_status=$(state_get_repo_field "$repo" "release")
        echo "| ${repo} | ${tag_status} | ${release_status} |"
    done
    echo ""

    # Recent audit log entries
    echo "### Recent Actions"
    echo ""
    if [[ -f "$AUDIT_LOG" ]]; then
        echo '```'
        tail -n 10 "$AUDIT_LOG"
        echo '```'
    else
        echo "(no audit log found)"
    fi
    echo ""

    # Determine next steps based on current state
    echo "### Next Steps"
    echo ""
    local next_phase=""
    for phase in preflight validation tags releases verification; do
        local phase_status
        phase_status=$(state_get_phase_status "$phase")
        if [[ "$phase_status" != "complete" ]]; then
            next_phase="$phase"
            break
        fi
    done

    case "$next_phase" in
        preflight)
            echo "1. Run \`release.sh preflight\` to check repos"
            echo "2. Fix any issues found"
            echo "3. Run \`release.sh validate --manifest n1-push --host <host>\`"
            ;;
        validation)
            echo "1. Run \`release.sh validate --manifest n1-push --host <host>\`"
            echo "2. Attach validation report to release issue"
            echo "3. Run \`release.sh tag --dry-run\` to preview tags"
            ;;
        tags)
            echo "1. Run \`release.sh tag --dry-run\` to preview tags"
            echo "2. Run \`release.sh tag --execute\` to create tags"
            echo "3. Run \`release.sh publish --dry-run\` to preview releases"
            ;;
        releases)
            echo "1. Run \`release.sh publish --dry-run\` to preview releases"
            echo "2. Run \`release.sh publish --execute\` to create releases"
            echo "3. Run \`release.sh verify\` to check completion"
            ;;
        verification)
            echo "1. Run \`release.sh verify\` to check all releases"
            echo "2. Complete Housekeeping, AAR and Retrospective"
            echo "3. Close release issue"
            ;;
        "")
            if [[ "$status" == "complete" ]]; then
                echo "Release v${version} is complete."
                echo ""
                echo "Post-release tasks:"
                echo "1. Complete Housekeeping, AAR and Retrospective (if not done)"
                echo "2. Close release issue"
                echo "3. Run \`release.sh init --version X.Y\` for next release"
            else
                echo "All phases complete. Run \`release.sh status\` for details."
            fi
            ;;
    esac
}

cmd_retrospective() {
    local done_flag=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --done)
                done_flag=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    require_release_state

    local version
    version=$(state_get_version)

    if [[ "$done_flag" == "true" ]]; then
        state_set_phase_status "retrospective" "complete"
        audit_log "RETROSPECTIVE" "cli" "Retrospective marked complete for v${version}"
        log_success "Retrospective marked complete for v${version}"
        echo ""
        echo "You can now close the release with: release.sh close --execute"
        exit 0
    fi

    # Show status
    local retro_status
    retro_status=$(state_get_phase_status "retrospective")
    echo ""
    echo "Retrospective status: ${retro_status:-pending}"
    echo ""
    echo "Before marking complete, ensure you have:"
    echo "  - Reviewed what went well and what could be improved"
    echo "  - Updated docs/lifecycle/75-lessons-learned.md if applicable"
    echo "  - Captured any process improvements for future releases"
    echo ""
    echo "Mark complete with: release.sh retrospective --done"
    exit 0
}

cmd_close() {
    local dry_run=true
    local force=false
    local yes_flag=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --execute)
                dry_run=false
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --yes|-y)
                yes_flag=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    require_release_state

    local version issue started_at
    version=$(state_get_version)
    issue=$(state_get_issue)
    started_at=$(state_read '.release.started_at')

    # Run close
    if run_close "$version" "$issue" "$dry_run" "$force" "$started_at" "$yes_flag"; then
        if [[ "$dry_run" == "false" ]]; then
            audit_log "CLOSE" "cli" "Release v${version} closed"
        fi
        exit 0
    else
        exit 9
    fi
}
