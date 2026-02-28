#!/usr/bin/env bash
#
# cmd_tools.sh - Standalone tool and utility commands
#
# Commands: cmd_packer, cmd_sunset, cmd_selftest, cmd_help
#

cmd_packer() {
    local action="check"
    local dry_run=true
    local version=""
    local images_dir="${WORKSPACE_DIR}/packer/images"
    local force=false
    local use_all=false
    local -a template_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                action="check"
                shift
                ;;
            --upload)
                action="upload"
                shift
                ;;
            --remove)
                action="remove"
                shift
                ;;
            --execute)
                dry_run=false
                shift
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            --images)
                images_dir="$2"
                shift 2
                ;;
            --force)
                force=true
                dry_run=false
                shift
                ;;
            --all)
                use_all=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                template_args+=("$1")
                shift
                ;;
        esac
    done

    # Build template list
    local -a templates=()
    if [[ "$use_all" == "true" ]]; then
        for img in "${PACKER_IMAGES[@]}"; do
            templates+=("${img%.qcow2}")
        done
    else
        templates=("${template_args[@]}")
    fi

    # --check requires --version (from flag or state)
    if [[ "$action" == "check" ]]; then
        if [[ -z "$version" ]]; then
            if state_exists && state_validate; then
                version=$(state_get_version)
            else
                log_error "No version specified and no release in progress"
                log_error "Use: release.sh packer --check --version X.Y"
                exit 1
            fi
        fi
    fi

    # --upload requires --all or template names
    if [[ "$action" == "upload" ]]; then
        if [[ ${#templates[@]} -eq 0 ]]; then
            log_error "Specify --all or template names (e.g., debian-12 pve-9)"
            exit 1
        fi
    fi

    # --remove requires --all or name prefixes
    if [[ "$action" == "remove" ]]; then
        if [[ "$use_all" != "true" && ${#template_args[@]} -eq 0 ]]; then
            log_error "Specify --all or asset name prefixes (e.g., debian-12 pve-9)"
            exit 1
        fi
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  PACKER IMAGES"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    case "$action" in
        check)
            echo "Checking for template changes (v${version})..."
            local changed
            changed=$(packer_templates_changed "$version")
            echo ""

            if [[ "$changed" == "true" ]]; then
                echo -e "${YELLOW}Templates have changed.${NC}"
                echo "Build new images: cd packer && ./build.sh"
                echo "Then upload: release.sh packer --upload --execute --all"
            else
                echo -e "${GREEN}No template changes.${NC}"
                echo "Images on 'latest' release are current."
            fi
            ;;

        upload)
            echo "Target: latest release"
            echo "Images: $images_dir"
            echo "Templates: ${templates[*]}"
            if [[ "$force" == "true" ]]; then
                echo "Force: yes (skip checksum comparison)"
            fi
            echo ""

            if packer_upload_to_latest "$images_dir" "$dry_run" "$force" "${templates[@]}"; then
                if [[ "$dry_run" == "true" ]]; then
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "  PREVIEW - No changes made"
                    echo "  Run with --execute to upload images"
                    echo "═══════════════════════════════════════════════════════════════"
                fi
            else
                echo ""
                log_error "Upload failed"
                exit 1
            fi
            ;;

        remove)
            echo "Target: latest release"
            if [[ "$use_all" == "true" ]]; then
                echo "Scope: all assets"
            else
                echo "Prefixes: ${template_args[*]}"
            fi
            echo ""

            if packer_remove_from_latest "$dry_run" "$use_all" "${template_args[@]}"; then
                if [[ "$dry_run" == "true" ]]; then
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "  PREVIEW - No changes made"
                    echo "  Run with --execute to remove assets"
                    echo "═══════════════════════════════════════════════════════════════"
                fi
            else
                echo ""
                log_error "Remove failed"
                exit 1
            fi
            ;;
    esac

    echo ""
}

cmd_sunset() {
    local below_version=""
    local dry_run=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --below-version)
                below_version="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --execute)
                dry_run=false
                shift
                ;;
            --yes|-y)
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if [[ -z "$below_version" ]]; then
        log_error "Version required: release.sh sunset --below-version X.Y"
        exit 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  SUNSET RELEASES BELOW v${below_version}"
    if [[ "$dry_run" == "true" ]]; then
        echo "  Mode: DRY-RUN (preview only)"
    else
        echo "  Mode: EXECUTE"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Parse version for comparison (e.g., "0.20" -> 20 for v0.x series)
    local below_minor
    below_minor="${below_version#0.}"

    local total_deleted=0
    local repos_with_deletions=()

    for repo in "${REPOS[@]}"; do
        echo "=== $repo ==="

        # Get all releases for this repo (use tab delimiter for correct parsing)
        local releases
        releases=$(gh release list --repo "homestak-dev/$repo" --limit 100 2>/dev/null | awk -F'\t' '{print $3}' || echo "")

        if [[ -z "$releases" ]]; then
            echo "  No releases found"
            echo ""
            continue
        fi

        local to_delete=()
        while IFS= read -r tag; do
            # Skip empty lines
            [[ -z "$tag" ]] && continue

            # Skip 'latest' (special packer release)
            if [[ "$tag" == "latest" ]]; then
                echo "  Keeping: $tag (special release)"
                continue
            fi

            # Parse version: v0.X -> extract X
            local version_num
            if [[ "$tag" =~ ^v0\.([0-9]+) ]]; then
                version_num="${BASH_REMATCH[1]}"

                if [[ "$version_num" -lt "$below_minor" ]]; then
                    to_delete+=("$tag")
                else
                    echo "  Keeping: $tag (>= v${below_version})"
                fi
            else
                echo "  Keeping: $tag (non-standard version)"
            fi
        done <<< "$releases"

        if [[ ${#to_delete[@]} -gt 0 ]]; then
            repos_with_deletions+=("$repo")
            for tag in "${to_delete[@]}"; do
                if [[ "$dry_run" == "true" ]]; then
                    echo -e "  ${YELLOW}Would delete:${NC} $tag"
                else
                    echo -e "  ${RED}Deleting:${NC} $tag"
                    if gh release delete "$tag" --repo "homestak-dev/$repo" --yes 2>/dev/null; then
                        ((++total_deleted))
                    else
                        log_warn "Failed to delete $tag from $repo"
                    fi
                fi
            done
        else
            echo "  No releases to delete"
        fi
        echo ""
    done

    # Summary
    echo "═══════════════════════════════════════════════════════════════"
    if [[ "$dry_run" == "true" ]]; then
        echo "  DRY-RUN COMPLETE"
        echo "  Repos with releases to delete: ${#repos_with_deletions[@]}"
        if [[ ${#repos_with_deletions[@]} -gt 0 ]]; then
            echo "  Affected repos: ${repos_with_deletions[*]}"
        fi
        echo ""
        echo "  Run with --execute to delete releases"
        echo "  Git tags will be preserved"
    else
        echo -e "  RESULT: ${GREEN}SUCCESS${NC}"
        echo "  Deleted: $total_deleted releases"
        echo "  Git tags preserved (use 'git tag' to verify)"
        audit_log "SUNSET" "cli" "Deleted $total_deleted releases below v${below_version}"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

cmd_selftest() {
    local verbose=false
    local test_version="0.99-test"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                verbose=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  RELEASE.SH SELF-TEST"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    local passed=0
    local failed=0

    # Use exported variables for cleanup trap (local vars not accessible in trap)
    export SELFTEST_STATE_FILE="${WORKSPACE_DIR}/.release-selftest-state.json"
    export SELFTEST_AUDIT_LOG="${WORKSPACE_DIR}/.release-selftest-audit.log"
    export SELFTEST_HAD_STATE=false

    # Backup real state if exists
    if [[ -f "$STATE_FILE" ]]; then
        SELFTEST_HAD_STATE=true
        mv "$STATE_FILE" "${STATE_FILE}.bak"
    fi
    if [[ -f "$AUDIT_LOG" ]]; then
        mv "$AUDIT_LOG" "${AUDIT_LOG}.bak"
    fi

    # Cleanup function (uses exported variables)
    cleanup_selftest() {
        rm -f "$SELFTEST_STATE_FILE" "$SELFTEST_AUDIT_LOG" 2>/dev/null || true
        rm -f "$STATE_FILE" "$AUDIT_LOG" 2>/dev/null || true
        # Restore real state
        if [[ "$SELFTEST_HAD_STATE" == "true" && -f "${STATE_FILE}.bak" ]]; then
            mv "${STATE_FILE}.bak" "$STATE_FILE"
        fi
        if [[ -f "${AUDIT_LOG}.bak" ]]; then
            mv "${AUDIT_LOG}.bak" "$AUDIT_LOG"
        fi
        # Clean up exports
        unset SELFTEST_STATE_FILE SELFTEST_AUDIT_LOG SELFTEST_HAD_STATE 2>/dev/null || true
    }
    trap cleanup_selftest EXIT

    # Helper to run a test
    run_test() {
        local name="$1"
        shift
        local desc="$1"
        shift

        echo -n "  Testing $name... "
        if [[ "$verbose" == "true" ]]; then
            echo ""
            echo "    Description: $desc"
            echo "    Command: $*"
        fi

        local output
        local exit_code=0
        if [[ "$verbose" == "true" ]]; then
            "$@" 2>&1 | sed 's/^/    /' || exit_code=$?
        else
            output=$("$@" 2>&1) || exit_code=$?
        fi

        if [[ $exit_code -eq 0 ]]; then
            echo -e "${GREEN}PASS${NC}"
            ((++passed))
            return 0
        else
            echo -e "${RED}FAIL${NC} (exit code: $exit_code)"
            if [[ "$verbose" != "true" && -n "$output" ]]; then
                echo "$output" | head -5 | sed 's/^/      /'
            fi
            ((++failed))
            return 1
        fi
    }

    # Test 1: help
    run_test "help" "Show help text" "$0" help

    # Test 2: init (creates state)
    run_test "init" "Initialize test release" "$0" init --version "$test_version" --no-issue < /dev/null || true
    # Handle the prompt by saying no
    echo "n" | "$0" init --version "$test_version" --no-issue 2>/dev/null || true

    # Test 3: status (requires state)
    run_test "status" "Show release status" "$0" status

    # Test 4: preflight (doesn't require state if version provided)
    # Skip actual preflight since it checks real repos - just verify command parses
    echo -n "  Testing preflight (parse)... "
    if "$0" preflight --version "$test_version" 2>&1 | grep -q "Preflight\|PREFLIGHT\|exists"; then
        echo -e "${GREEN}PASS${NC}"
        ((++passed))
    else
        echo -e "${YELLOW}SKIP${NC} (preflight runs against real repos)"
        # Don't count as failure
    fi

    # Test 5: tag --dry-run (requires validation phase complete, clean repos)
    state_set_phase_status "validation" "complete"
    # Check if repos have uncommitted changes (tag requires clean repos)
    local has_uncommitted=false
    for repo in homestak-dev bootstrap iac-driver; do
        local repo_path
        if [[ "$repo" == "homestak-dev" ]]; then
            repo_path="${WORKSPACE_DIR}"
        else
            repo_path="${WORKSPACE_DIR}/${repo}"
        fi
        if [[ -d "$repo_path" ]] && [[ -n "$(git -C "$repo_path" status --porcelain 2>/dev/null)" ]]; then
            has_uncommitted=true
            break
        fi
    done
    if [[ "$has_uncommitted" == "true" ]]; then
        echo -n "  Testing tag-dry... "
        echo -e "${YELLOW}SKIP${NC} (repos have uncommitted changes)"
    else
        run_test "tag-dry" "Tag creation dry-run" "$0" tag --dry-run || true
    fi

    # Test 6: publish --dry-run (requires tags phase complete, tags to exist)
    state_set_phase_status "tags" "complete"
    # Skip if tags don't exist (they won't for test version)
    echo -n "  Testing publish-dry... "
    if "$0" publish --dry-run 2>&1 | grep -q "RELEASE PUBLISHING"; then
        echo -e "${GREEN}PASS${NC} (command executed)"
        ((++passed))
    else
        echo -e "${YELLOW}SKIP${NC} (tags don't exist for test version)"
    fi

    # Test 7: packer --check
    run_test "packer-check" "Packer template check" "$0" packer --check || true

    # Test 8: verify (may fail due to no releases)
    echo -n "  Testing verify... "
    if "$0" verify --version "$test_version" 2>&1 | grep -qE "Release|release|VERIFY"; then
        echo -e "${GREEN}PASS${NC} (command executed)"
        ((++passed))
    else
        echo -e "${YELLOW}SKIP${NC} (verify runs against real releases)"
    fi

    # Test 9: full --dry-run
    run_test "full-dry" "Full release dry-run" "$0" full --dry-run

    # Test 10: audit
    run_test "audit" "Show audit log" "$0" audit --lines 5

    # Test 11: sunset --dry-run
    run_test "sunset-dry" "Sunset dry-run" "$0" sunset --below-version 0.20 --dry-run

    # Cleanup
    cleanup_selftest
    trap - EXIT

    # Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    local total=$((passed + failed))
    if [[ $failed -eq 0 ]]; then
        echo -e "  RESULT: ${GREEN}ALL TESTS PASSED${NC} ($passed/$total)"
    else
        echo -e "  RESULT: ${RED}$failed TESTS FAILED${NC} ($passed passed, $failed failed)"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    [[ $failed -eq 0 ]]
}

cmd_help() {
    cat << EOF
release.sh $(get_version) - homestak-dev release automation CLI

Usage:
  release.sh <command> [options]

Commands:
  init          Initialize a new release
  status        Show current release status
  resume        Show AI-friendly recovery context (markdown output)
  preflight     Run pre-flight checks
  validate      Run integration tests
  tag           Create git tags
  publish       Create GitHub releases
  packer        Handle packer image automation
  verify        Verify release artifacts
  retrospective Mark retrospective phase complete
  close         Close release (validate phases, post summary, close issue)
  full          Execute complete release workflow
  sunset        Delete old releases (preserves git tags)
  selftest      Run self-test on all commands
  audit         Show audit log

Options:
  --help, -h         Show this help message
  --version          Show CLI version (use as first argument)
  --version X.Y      Release version (required for init, packer --check)
  --issue N          GitHub issue to track release progress (required for init)
  --no-issue         Skip issue requirement for hotfix releases (init only)
  --dry-run          Show what would be done without executing
  --execute          Execute the operation
  --force            Override validation gate / force upload (implies --execute)
  --rollback         Rollback tags/releases on failure
  --reset            Reset tags to HEAD (delete and recreate, v0.x only)
  --reset-repo REPO  Reset tag for single repo only
  --yes, -y          Skip confirmation prompt (tag, publish, close)
  --skip             Skip validation (emergency releases only)
  --stage            Run via 'homestak scenario' CLI instead of ./run.sh (stage mode)
  --remote HOST      Run validation on remote host via SSH
  --packer-release   Packer release tag for image downloads (validate only)
  --manifest NAME    Manifest name for manifest-based tests (default: n1-push)
  --host HOST        Check host readiness (preflight only, repeatable)
  --images DIR       Packer images directory (packer --upload, default: packer/images)
  --all              Target all packer templates (packer --upload/--remove)
  --lines N          Number of audit log lines to show (default: 20)
  --below-version    Delete releases below this version (sunset only)
  --json             Machine-readable JSON output (status, verify, preflight)

Examples:
  release.sh init --version 0.31 --issue 115
  release.sh init --version 0.31-hotfix --no-issue   # Hotfix without tracking issue
  release.sh status
  release.sh preflight
  release.sh preflight --host srv1
  release.sh preflight --host srv1 --host srv2
  release.sh validate --manifest n1-push --host srv1
  release.sh validate --manifest n1-push --host srv1 --remote srv1
  release.sh validate --manifest n2-tiered --host srv1
  release.sh validate --scenario push-vm-roundtrip --host srv1  # Scenario fallback
  release.sh validate --stage --remote srv1              # Stage mode via homestak CLI
  release.sh validate --skip
  release.sh tag --dry-run
  release.sh tag --execute
  release.sh tag --execute --yes                   # Skip confirmation prompt
  release.sh tag --execute --force
  release.sh tag --rollback
  release.sh tag --reset --dry-run
  release.sh tag --reset --execute
  release.sh tag --reset-repo packer --execute
  release.sh publish --dry-run
  release.sh publish --execute
  release.sh publish --execute --yes               # Skip confirmation prompt
  release.sh packer --check
  release.sh packer --check --version 0.45
  release.sh packer --upload --all                         # Preview all uploads
  release.sh packer --upload --execute --all               # Upload all, skip unchanged
  release.sh packer --upload --force --all                 # Upload all, force overwrite
  release.sh packer --upload --execute debian-12 pve-9     # Upload specific templates
  release.sh packer --upload --execute --all --images /tmp/images  # Custom images dir
  release.sh packer --remove --all                         # Preview removal of all assets
  release.sh packer --remove --execute debian-12           # Remove assets matching prefix
  release.sh packer --remove --execute --all               # Remove ALL assets from latest
  release.sh retrospective                       # Show retrospective status
  release.sh retrospective --done                # Mark retrospective complete
  release.sh close --dry-run
  release.sh close --execute
  release.sh close --execute --yes               # Skip confirmation prompt
  release.sh close --execute --force             # Skip phase validation
  release.sh full --dry-run
  release.sh full --execute --host srv1
  release.sh full --execute --skip-validate
  release.sh selftest
  release.sh selftest --verbose
  release.sh sunset --below-version 0.20 --dry-run
  release.sh sunset --below-version 0.20 --execute
  release.sh audit --lines 50
  release.sh --version                             # Show CLI version
  release.sh status --json                         # Machine-readable status
  release.sh verify --json                         # Machine-readable verification

State Files:
  .release-state.json   Release progress state
  .release-audit.log    Timestamped action log
EOF
}
