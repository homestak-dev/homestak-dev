#!/usr/bin/env bash
#
# close.sh - Release closure for release CLI
#
# Validates all phases complete, posts summary, closes release issue
#

# -----------------------------------------------------------------------------
# Phase Validation
# -----------------------------------------------------------------------------

close_check_phases() {
    local errors=()
    local warnings=()

    # Check all tracked phases are complete
    for phase in preflight validation tags releases verification; do
        local phase_status
        phase_status=$(state_get_phase_status "$phase")
        if [[ "$phase_status" != "complete" ]]; then
            errors+=("Phase '$phase' not complete (status: ${phase_status})")
        fi
    done

    # Check retrospective separately (soft check - warning only)
    local retro_status
    retro_status=$(state_get_phase_status "retrospective")
    if [[ "$retro_status" != "complete" ]]; then
        warnings+=("Phase 'retrospective' not complete (status: ${retro_status})")
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        for err in "${errors[@]}"; do
            echo -e "  ${RED}✗${NC} $err"
        done
        return 1
    fi

    if [[ ${#warnings[@]} -gt 0 ]]; then
        for warn in "${warnings[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} $warn"
        done
        echo ""
        echo -e "  ${YELLOW}Retrospective not complete.${NC}"
        echo "  Mark complete: release.sh retrospective --done"
        echo "  Or skip with: release.sh close --force"
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Issue Operations
# -----------------------------------------------------------------------------

close_generate_summary() {
    local version="$1"
    local issue="$2"
    local started_at="$3"
    local completed_at
    completed_at=$(timestamp)

    cat << EOF
## Release v${version} Complete

**Started:** ${started_at}
**Completed:** ${completed_at}

### Phase Summary

| Phase | Status |
|-------|--------|
| Pre-flight | ✅ |
| Validation | ✅ |
| Tags | ✅ |
| Releases | ✅ |
| Verification | ✅ |
| AAR | ✅ (manual) |
| Housekeeping | ✅ (manual) |
| Retrospective | ✅ (manual) |

### Repos

All ${#REPOS[@]} repos tagged and released at v${version}.

---
*Closed by release.sh close command*
EOF
}

close_post_and_close() {
    local issue="$1"
    local summary="$2"
    local dry_run="${3:-true}"

    if [[ -z "$issue" ]]; then
        log_warn "No release issue linked - skipping GitHub operations"
        return 0
    fi

    local comment_cmd="gh issue comment ${issue} --repo homestak-dev/homestak-dev --body \"\$summary\""
    local close_cmd="gh issue close ${issue} --repo homestak-dev/homestak-dev"

    if [[ "$dry_run" == "true" ]]; then
        echo "Would post summary comment to issue #${issue}"
        echo "Would close issue #${issue}"
        return 0
    fi

    # Post summary comment
    log_info "Posting summary to issue #${issue}..."
    if ! gh issue comment "$issue" --repo homestak-dev/homestak-dev --body "$summary"; then
        log_error "Failed to post comment to issue #${issue}"
        return 1
    fi

    # Close the issue
    log_info "Closing issue #${issue}..."
    if ! gh issue close "$issue" --repo homestak-dev/homestak-dev; then
        log_error "Failed to close issue #${issue}"
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Main Close Runner
# -----------------------------------------------------------------------------

run_close() {
    local version="$1"
    local issue="$2"
    local dry_run="${3:-true}"
    local force="${4:-false}"
    local started_at="$5"
    local yes_flag="${6:-false}"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  RELEASE CLOSE: v${version}"
    if [[ "$dry_run" == "true" ]]; then
        echo "  Mode: DRY-RUN (no changes will be made)"
    else
        echo "  Mode: EXECUTE"
    fi
    if [[ -n "$issue" ]]; then
        echo "  Issue: #${issue}"
    else
        echo -e "  Issue: ${YELLOW}(none linked)${NC}"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Check phases complete (unless --force)
    echo "Phase validation:"
    if [[ "$force" != "true" ]]; then
        if ! close_check_phases; then
            echo ""
            log_error "Not all phases complete. Use --force to override."
            echo ""
            echo "Reminder: Complete these phases before closing:"
            echo "  - After Action Report (post to release issue)"
            echo "  - Housekeeping (branch cleanup)"
            echo "  - Retrospective (update lessons learned)"
            return 1
        fi
        echo -e "  ${GREEN}✓${NC} All tracked phases complete"
    else
        echo -e "  ${YELLOW}⚠${NC} Phase check overridden with --force"
    fi
    echo ""

    echo -e "${YELLOW}Reminder:${NC} Before closing, ensure you have completed:"
    echo "  - [ ] After Action Report posted to release issue"
    echo "  - [ ] Housekeeping (branch cleanup) completed"
    echo "  - [ ] Retrospective completed"
    echo "  - [ ] Lessons learned updated in docs/lifecycle/65-lessons-learned.md"
    echo ""

    # Generate summary
    local summary
    summary=$(close_generate_summary "$version" "$issue" "$started_at")

    if [[ "$dry_run" == "true" ]]; then
        echo "Summary that would be posted:"
        echo "---"
        echo "$summary"
        echo "---"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  DRY-RUN COMPLETE - No changes made"
        echo "  Run with --execute to close the release"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    # Confirmation prompt (skip with --yes)
    if [[ "$yes_flag" != "true" ]]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo -e "  ${YELLOW}This will close the release issue and clean up state${NC}"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        read -p "Type 'yes' to proceed, or Ctrl+C to abort: " -r
        if [[ "$REPLY" != "yes" ]]; then
            log_info "Aborted by user"
            return 1
        fi
        echo ""
    fi

    # Post and close
    if ! close_post_and_close "$issue" "$summary" "false"; then
        log_error "Failed to close release"
        return 1
    fi

    # Clean up state files
    log_info "Cleaning up state files..."
    if [[ -f "$STATE_FILE" ]]; then
        rm -f "$STATE_FILE"
        log_success "Removed $STATE_FILE"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  RESULT: ${GREEN}SUCCESS${NC}"
    echo "  Release v${version} closed"
    if [[ -n "$issue" ]]; then
        echo "  Issue #${issue} closed"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    return 0
}
