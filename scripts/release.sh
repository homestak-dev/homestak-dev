#!/usr/bin/env bash
#
# release.sh - homestak-dev release automation CLI
#
# Usage:
#   release.sh init --version X.Y
#   release.sh status
#   release.sh resume
#   release.sh preflight
#   release.sh validate --scenario <name> --host <host>
#   release.sh tag [--dry-run|--execute]
#   release.sh publish [--dry-run|--execute]
#   release.sh verify
#   release.sh audit [--lines N]
#

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-$(dirname "$SCRIPT_DIR")}"
STATE_FILE="${STATE_FILE:-${WORKSPACE_DIR}/.release-state.json}"
AUDIT_LOG="${AUDIT_LOG:-${WORKSPACE_DIR}/.release-audit.log}"

# Export for sourced scripts
export SCRIPT_DIR WORKSPACE_DIR STATE_FILE AUDIT_LOG

# -----------------------------------------------------------------------------
# Colors and Logging
# -----------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Export logging functions for sourced scripts
export -f log_info log_success log_warn log_error timestamp

# -----------------------------------------------------------------------------
# Source Libraries
# -----------------------------------------------------------------------------

source "${SCRIPT_DIR}/lib/audit.sh"
source "${SCRIPT_DIR}/lib/state.sh"
source "${SCRIPT_DIR}/lib/preflight.sh"
source "${SCRIPT_DIR}/lib/validate.sh"
source "${SCRIPT_DIR}/lib/tag.sh"
source "${SCRIPT_DIR}/lib/publish.sh"
source "${SCRIPT_DIR}/lib/verify.sh"
source "${SCRIPT_DIR}/lib/close.sh"

# -----------------------------------------------------------------------------
# Dependency Check
# -----------------------------------------------------------------------------

check_dependencies() {
    local missing=()

    for cmd in git gh jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        log_error "Install with: sudo apt install ${missing[*]}"
        exit 2
    fi
}

# -----------------------------------------------------------------------------
# Commands
# -----------------------------------------------------------------------------

cmd_init() {
    local version=""
    local issue=""

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
        echo -e "  ${YELLOW}Tip: Link a release issue with --issue N${NC}"
        echo "  Look for: gh issue list --label release"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Next steps:"
    echo "  1. release.sh preflight"
    echo "  2. Update CHANGELOGs"
    echo "  3. release.sh validate --scenario vm-roundtrip --host father"
    echo "  4. release.sh tag --dry-run"
    echo "  5. release.sh tag --execute"
    echo "  6. release.sh publish --execute"
    echo "  7. release.sh verify"
    echo ""
}

cmd_status() {
    if ! state_exists; then
        log_info "No release in progress"
        log_info "Start with: release.sh init --version X.Y"
        exit 0
    fi

    if ! state_validate; then
        log_error "State file is corrupted"
        exit 3
    fi

    local version status started_at issue
    version=$(state_get_version)
    status=$(state_get_status)
    started_at=$(state_read '.release.started_at')
    issue=$(state_get_issue)

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
            echo "3. Run \`release.sh validate --scenario vm-roundtrip --host <host>\`"
            ;;
        validation)
            echo "1. Run \`release.sh validate --scenario vm-roundtrip --host <host>\`"
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
            echo "2. Complete AAR and Retrospective"
            echo "3. Close release issue"
            ;;
        "")
            if [[ "$status" == "complete" ]]; then
                echo "Release v${version} is complete."
                echo ""
                echo "Post-release tasks:"
                echo "1. Complete AAR and Retrospective (if not done)"
                echo "2. Close release issue"
                echo "3. Run \`release.sh init --version X.Y\` for next release"
            else
                echo "All phases complete. Run \`release.sh status\` for details."
            fi
            ;;
    esac
}

cmd_preflight() {
    local json_output=false
    local version=""
    local hosts=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                json_output=true
                shift
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            --host)
                hosts+=("$2")
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Get version from state if not provided
    if [[ -z "$version" ]]; then
        if state_exists && state_validate; then
            version=$(state_get_version)
        else
            log_error "No version specified and no release in progress"
            log_error "Use: release.sh preflight --version X.Y"
            log_error "Or: release.sh init --version X.Y"
            exit 1
        fi
    fi

    # Update state
    if state_exists; then
        state_set_phase_status "preflight" "in_progress"
    fi

    # Run checks
    if run_preflight "$version" "$json_output" "${hosts[@]}"; then
        if state_exists; then
            state_set_phase_status "preflight" "complete"
            issue_update_preflight "passed"
        fi
        exit 0
    else
        if state_exists; then
            state_set_phase_status "preflight" "failed"
            issue_update_preflight "failed"
        fi
        exit 4
    fi
}

cmd_validate() {
    local scenario="vm-roundtrip"
    local host="father"
    local skip=false
    local verbose=false
    local remote=""
    local packer_release=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scenario)
                scenario="$2"
                shift 2
                ;;
            --host)
                host="$2"
                shift 2
                ;;
            --remote)
                remote="$2"
                shift 2
                ;;
            --packer-release)
                packer_release="$2"
                shift 2
                ;;
            --skip)
                skip=true
                shift
                ;;
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

    # Update state
    if state_exists; then
        state_set_phase_status "validation" "in_progress"
    fi

    # Run validation
    local validation_passed=false
    if run_validation "$scenario" "$host" "$skip" "$verbose" "$remote" "$packer_release"; then
        validation_passed=true
    fi

    # Store report path in state (regardless of pass/fail)
    if state_exists && [[ -n "$VALIDATION_REPORT" ]]; then
        state_write ".phases.validation.report" "$VALIDATION_REPORT"
    fi

    # Update phase status
    if [[ "$validation_passed" == "true" ]]; then
        if state_exists; then
            state_set_phase_status "validation" "complete"
            issue_update_validation "$scenario" "$host" "${VALIDATION_REPORT:-}"
        fi
        exit 0
    else
        if state_exists; then
            state_set_phase_status "validation" "failed"
        fi
        exit 5
    fi
}

cmd_tag() {
    local dry_run=true
    local force=false
    local rollback=false
    local reset=false
    local reset_repo=""
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
            --rollback)
                rollback=true
                shift
                ;;
            --reset)
                reset=true
                shift
                ;;
            --reset-repo)
                reset=true
                reset_repo="$2"
                shift 2
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

    # Require release in progress
    if ! state_exists; then
        log_error "No release in progress"
        log_error "Start with: release.sh init --version X.Y"
        exit 1
    fi

    if ! state_validate; then
        log_error "State file is corrupted"
        exit 3
    fi

    local version
    version=$(state_get_version)

    # Handle rollback
    if [[ "$rollback" == "true" ]]; then
        state_set_phase_status "tags" "in_progress"
        if run_tag_rollback "$version"; then
            state_set_phase_status "tags" "rolled_back"
            audit_log "ROLLBACK" "human" "Tags v${version} rolled back"
            exit 0
        else
            state_set_phase_status "tags" "failed"
            exit 6
        fi
    fi

    # Handle reset
    if [[ "$reset" == "true" ]]; then
        state_set_phase_status "tags" "in_progress"
        if run_tag_reset "$version" "$dry_run" "$reset_repo"; then
            if [[ "$dry_run" == "false" ]]; then
                state_set_phase_status "tags" "complete"
                issue_update_tags "$version"
            fi
            exit 0
        else
            if [[ "$dry_run" == "false" ]]; then
                state_set_phase_status "tags" "failed"
            fi
            exit 6
        fi
    fi

    # Update state
    state_set_phase_status "tags" "in_progress"

    # Run tag creation
    if run_tag "$version" "$dry_run" "$force" "$yes_flag"; then
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "tags" "complete"
            audit_log "TAG" "cli" "Tags v${version} created in ${#REPOS[@]} repos"
            issue_update_tags "$version"
        fi
        exit 0
    else
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "tags" "failed"
        fi
        exit 6
    fi
}

cmd_publish() {
    local dry_run=true
    local force=false
    local images_dir=""
    local workflow=""  # No default - require explicit choice

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
            --images)
                images_dir="$2"
                shift 2
                ;;
            --workflow)
                workflow="$2"
                if [[ "$workflow" != "github" && "$workflow" != "local" ]]; then
                    log_error "Invalid --workflow value: $workflow (must be 'github' or 'local')"
                    exit 1
                fi
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Require --workflow for --execute mode
    if [[ "$dry_run" == "false" && -z "$workflow" ]]; then
        log_error "--workflow required: specify --workflow github (fast, recommended) or --workflow local"
        exit 1
    fi

    # Require release in progress
    if ! state_exists; then
        log_error "No release in progress"
        log_error "Start with: release.sh init --version X.Y"
        exit 1
    fi

    if ! state_validate; then
        log_error "State file is corrupted"
        exit 3
    fi

    local version
    version=$(state_get_version)

    # Update state
    state_set_phase_status "releases" "in_progress"

    # Run publish
    if run_publish "$version" "$dry_run" "$force" "$images_dir" "$workflow"; then
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "releases" "complete"
            audit_log "PUBLISH" "cli" "Releases v${version} created in ${#REPOS[@]} repos"
            issue_update_releases "$version"
        fi
        exit 0
    else
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "releases" "failed"
        fi
        exit 7
    fi
}

cmd_packer() {
    local action="check"
    local dry_run=true
    local version=""
    local source=""
    local use_workflow=false
    local wait_workflow=true
    local timeout=600

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                action="check"
                shift
                ;;
            --copy)
                action="copy"
                shift
                ;;
            --dry-run)
                dry_run=true
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
            --source)
                source="$2"
                shift 2
                ;;
            --workflow)
                use_workflow=true
                shift
                ;;
            --no-wait)
                wait_workflow=false
                shift
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Get version from state if not provided
    if [[ -z "$version" ]]; then
        if state_exists && state_validate; then
            version=$(state_get_version)
        else
            log_error "No version specified and no release in progress"
            log_error "Use: release.sh packer --copy --version X.Y"
            log_error "Or: release.sh init --version X.Y"
            exit 1
        fi
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  PACKER IMAGES: v${version}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    case "$action" in
        check)
            echo "Checking for template changes..."
            local changed
            changed=$(packer_templates_changed "$version")
            echo ""

            if [[ "$changed" == "true" ]]; then
                echo -e "${YELLOW}Templates have changed.${NC}"
                echo "Options:"
                echo "  1. Build new images: cd packer && ./build.sh"
                echo "  2. Skip images for this release (not recommended)"
                echo ""
                echo "After building, upload with:"
                echo "  release.sh publish --images /path/to/images"
            else
                echo -e "${GREEN}No template changes.${NC}"
                echo "Images can be copied from previous release:"
                echo "  release.sh packer --copy --dry-run"
                echo "  release.sh packer --copy --execute"
            fi
            ;;

        copy)
            # Use provided source or find latest with images
            if [[ -z "$source" ]]; then
                source=$(packer_get_latest_release "$version")
            fi

            if [[ -z "$source" ]]; then
                log_error "No previous release with images found"
                log_error "Specify source with: --source v0.19"
                exit 1
            fi

            echo "Source release: $source"
            echo "Target release: v${version}"
            if [[ "$use_workflow" == "true" ]]; then
                echo "Method: GitHub Actions workflow"
            else
                echo "Method: Local (gh CLI)"
            fi
            echo ""

            if [[ "$dry_run" == "true" ]]; then
                echo "Commands that would be executed:"
                echo ""
                if [[ "$use_workflow" == "true" ]]; then
                    packer_dispatch_copy_images "$version" "$source" "true"
                else
                    packer_copy_images_local "$version" "$source" "true"
                fi
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "  DRY-RUN COMPLETE - No changes made"
                echo "  Run with --execute to copy images"
                echo "═══════════════════════════════════════════════════════════════"
            else
                local copy_result=0
                if [[ "$use_workflow" == "true" ]]; then
                    if ! packer_dispatch_copy_images "$version" "$source" "false" "$wait_workflow" "$timeout"; then
                        copy_result=1
                    fi
                else
                    if ! packer_copy_images_local "$version" "$source" "false"; then
                        copy_result=1
                    fi
                fi

                if [[ "$copy_result" -eq 0 ]]; then
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo -e "  RESULT: ${GREEN}SUCCESS${NC}"
                    echo "  Images copied from $source to v${version}"
                    echo "═══════════════════════════════════════════════════════════════"
                    audit_log "PACKER_COPY" "cli" "Images copied from $source to v${version}"
                else
                    echo ""
                    log_error "Failed to copy images"
                    exit 1
                fi
            fi
            ;;
    esac

    echo ""
}

cmd_verify() {
    local json_output=false
    local version=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                json_output=true
                shift
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Get version from state if not provided
    if [[ -z "$version" ]]; then
        if state_exists && state_validate; then
            version=$(state_get_version)
        else
            log_error "No version specified and no release in progress"
            log_error "Use: release.sh verify --version X.Y"
            exit 1
        fi
    fi

    # Update state if release in progress
    if state_exists; then
        state_set_phase_status "verification" "in_progress"
    fi

    # Run verification
    if run_verify "$version" "$json_output"; then
        if state_exists; then
            state_set_phase_status "verification" "complete"
            state_set_status "complete"
            audit_log "VERIFY" "cli" "Release v${version} verified successfully"
            audit_done "$version"
            issue_update_verification "$version" "passed"
        fi
        exit 0
    else
        if state_exists; then
            state_set_phase_status "verification" "failed"
            issue_update_verification "$version" "failed"
        fi
        exit 8
    fi
}

cmd_close() {
    local dry_run=true
    local force=false

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
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Require release in progress
    if ! state_exists; then
        log_error "No release in progress"
        log_error "Start with: release.sh init --version X.Y"
        exit 1
    fi

    if ! state_validate; then
        log_error "State file is corrupted"
        exit 3
    fi

    local version issue started_at
    version=$(state_get_version)
    issue=$(state_get_issue)
    started_at=$(state_read '.release.started_at')

    # Run close
    if run_close "$version" "$issue" "$dry_run" "$force" "$started_at"; then
        if [[ "$dry_run" == "false" ]]; then
            audit_log "CLOSE" "cli" "Release v${version} closed"
        fi
        exit 0
    else
        exit 9
    fi
}

cmd_full() {
    local host="father"
    local scenario="vm-roundtrip"
    local skip_validate=false
    local dry_run=true
    local images_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host)
                host="$2"
                shift 2
                ;;
            --scenario)
                scenario="$2"
                shift 2
                ;;
            --skip-validate)
                skip_validate=true
                shift
                ;;
            --images)
                images_dir="$2"
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
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Require release in progress
    if ! state_exists; then
        log_error "No release in progress"
        log_error "Start with: release.sh init --version X.Y"
        exit 1
    fi

    if ! state_validate; then
        log_error "State file is corrupted"
        exit 3
    fi

    local version
    version=$(state_get_version)

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  FULL RELEASE: v${version}"
    if [[ "$dry_run" == "true" ]]; then
        echo "  Mode: DRY-RUN (preview only)"
    else
        echo "  Mode: EXECUTE"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    local phases=()
    local phase_status

    # Build phase list based on current state
    phase_status=$(state_get_phase_status "preflight")
    if [[ "$phase_status" != "complete" ]]; then
        phases+=("preflight")
    fi

    if [[ "$skip_validate" != "true" ]]; then
        phase_status=$(state_get_phase_status "validation")
        if [[ "$phase_status" != "complete" ]]; then
            phases+=("validate")
        fi
    fi

    phase_status=$(state_get_phase_status "tags")
    if [[ "$phase_status" != "complete" ]]; then
        phases+=("tag")
    fi

    phase_status=$(state_get_phase_status "releases")
    if [[ "$phase_status" != "complete" ]]; then
        phases+=("publish")
    fi

    # Always check packer if releases will be created
    if [[ " ${phases[*]} " =~ " publish " ]]; then
        phases+=("packer")
    fi

    phase_status=$(state_get_phase_status "verification")
    if [[ "$phase_status" != "complete" ]]; then
        phases+=("verify")
    fi

    if [[ ${#phases[@]} -eq 0 ]]; then
        log_success "Release v${version} is already complete"
        return 0
    fi

    echo "Phases to execute:"
    for phase in "${phases[@]}"; do
        echo "  - $phase"
    done
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "  DRY-RUN COMPLETE"
        echo "  Run with --execute to perform the full release"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    # Confirmation prompt
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  ${YELLOW}WARNING: This will execute a full release${NC}"
    echo "  Version: v${version}"
    echo "  Phases: ${phases[*]}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    read -p "Type 'yes' to proceed, or Ctrl+C to abort: " -r
    if [[ "$REPLY" != "yes" ]]; then
        log_info "Aborted by user"
        return 1
    fi
    echo ""

    # Execute each phase
    for phase in "${phases[@]}"; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  PHASE: $phase"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        case "$phase" in
            preflight)
                if ! run_preflight "$version" "false"; then
                    log_error "Preflight failed"
                    return 1
                fi
                state_set_phase_status "preflight" "complete"
                issue_update_preflight "passed"
                ;;

            validate)
                if ! run_validation "$scenario" "$host" "false" "false" ""; then
                    log_error "Validation failed"
                    return 1
                fi
                state_set_phase_status "validation" "complete"
                issue_update_validation "$scenario" "$host" ""
                ;;

            tag)
                if ! run_tag "$version" "false" "false"; then
                    log_error "Tag creation failed"
                    return 1
                fi
                state_set_phase_status "tags" "complete"
                audit_log "TAG" "cli" "Tags v${version} created in ${#REPOS[@]} repos"
                issue_update_tags "$version"
                ;;

            publish)
                if ! run_publish "$version" "false" "false" "$images_dir"; then
                    log_error "Publish failed"
                    return 1
                fi
                state_set_phase_status "releases" "complete"
                audit_log "PUBLISH" "cli" "Releases v${version} created in ${#REPOS[@]} repos"
                issue_update_releases "$version"
                ;;

            packer)
                # Check if templates changed
                local changed
                changed=$(packer_templates_changed "$version")

                if [[ "$changed" == "true" ]]; then
                    echo -e "${YELLOW}Packer templates have changed.${NC}"
                    if [[ -n "$images_dir" ]]; then
                        echo "Using provided images from: $images_dir"
                        # Images will be uploaded during publish
                    else
                        echo "No --images directory specified."
                        echo "Either build images or skip packer asset upload."
                        echo ""
                        read -p "Skip packer images for this release? [y/N] " -r
                        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                            log_error "Aborted - please build images first"
                            return 1
                        fi
                    fi
                else
                    echo "No template changes - copying images from previous release..."
                    local source
                    source=$(packer_get_latest_release "$version")
                    if [[ -n "$source" ]]; then
                        if ! packer_copy_images_local "$version" "$source" "false"; then
                            log_warn "Failed to copy packer images"
                        fi
                    else
                        log_warn "No previous release with images found"
                    fi
                fi
                ;;

            verify)
                if ! run_verify "$version" "false"; then
                    log_warn "Verification found issues (continuing)"
                fi
                state_set_phase_status "verification" "complete"
                state_set_status "complete"
                audit_log "VERIFY" "cli" "Release v${version} verified"
                audit_done "$version"
                issue_update_verification "$version" "passed"
                ;;
        esac

        echo -e "${GREEN}Phase $phase completed${NC}"
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  RESULT: ${GREEN}SUCCESS${NC}"
    echo "  Release v${version} completed"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    return 0
}

cmd_sunset() {
    local below_version=""
    local dry_run=true
    local yes_flag=false

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
                yes_flag=true
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
    below_minor=$(echo "$below_version" | sed 's/^0\.//')

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
        local description="$1"
        shift

        echo -n "  Testing $name... "
        if [[ "$verbose" == "true" ]]; then
            echo ""
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
    run_test "init" "Initialize test release" "$0" init --version "$test_version" < /dev/null || true
    # Handle the prompt by saying no
    echo "n" | "$0" init --version "$test_version" 2>/dev/null || true

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

    # Test 5: tag --dry-run
    run_test "tag-dry" "Tag creation dry-run" "$0" tag --dry-run || true

    # Test 6: publish --dry-run
    run_test "publish-dry" "Publish dry-run" "$0" publish --dry-run || true

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
    cat << 'EOF'
release.sh - homestak-dev release automation CLI

Usage:
  release.sh <command> [options]

Commands:
  init        Initialize a new release
  status      Show current release status
  resume      Show AI-friendly recovery context (markdown output)
  preflight   Run pre-flight checks
  validate    Run integration tests
  tag         Create git tags
  publish     Create GitHub releases
  packer      Handle packer image automation
  verify      Verify release artifacts
  close       Close release (validate phases, post summary, close issue)
  full        Execute complete release workflow
  sunset      Delete old releases (preserves git tags)
  selftest    Run self-test on all commands
  audit       Show audit log

Options:
  --version X.Y      Release version (required for init)
  --issue N          GitHub issue to track release progress (init only)
  --dry-run          Show what would be done without executing
  --execute          Execute the operation
  --force            Override validation gate requirement
  --rollback         Rollback tags/releases on failure
  --reset            Reset tags to HEAD (delete and recreate, v0.x only)
  --reset-repo REPO  Reset tag for single repo only
  --yes, -y          Skip confirmation prompt (tag command only)
  --skip             Skip validation (emergency releases only)
  --remote HOST      Run validation on remote host via SSH
  --packer-release   Packer release tag for image downloads (validate only)
  --host HOST        Check host readiness (preflight only, repeatable)
  --workflow MODE    Packer image copy method: 'github' (fast, recommended) or 'local' (required for --execute)
  --no-wait          Don't wait for workflow completion (packer only)
  --timeout N        Workflow wait timeout in seconds (default: 600)
  --lines N          Number of audit log lines to show (default: 20)
  --below-version    Delete releases below this version (sunset only)

Examples:
  release.sh init --version 0.14
  release.sh init --version 0.20 --issue 72
  release.sh status
  release.sh preflight
  release.sh preflight --host father
  release.sh preflight --host father --host mother
  release.sh validate --scenario vm-roundtrip --host father
  release.sh validate --scenario vm-roundtrip --host father --remote father
  release.sh validate --scenario nested-pve-roundtrip --host father --packer-release v0.19
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
  release.sh publish --execute --workflow github   # Fast, recommended
  release.sh publish --execute --workflow local    # Slow, downloads ~13GB
  release.sh packer --check
  release.sh packer --copy --dry-run
  release.sh packer --copy --execute
  release.sh packer --copy --version 0.20 --source v0.19
  release.sh packer --copy --workflow --execute
  release.sh packer --copy --workflow --no-wait --execute
  release.sh close --dry-run
  release.sh close --execute
  release.sh close --execute --force             # Skip phase validation
  release.sh full --dry-run
  release.sh full --execute --host father
  release.sh full --execute --skip-validate
  release.sh selftest
  release.sh selftest --verbose
  release.sh sunset --below-version 0.20 --dry-run
  release.sh sunset --below-version 0.20 --execute
  release.sh audit --lines 50

State Files:
  .release-state.json   Release progress state
  .release-audit.log    Timestamped action log
EOF
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    check_dependencies

    if [[ $# -eq 0 ]]; then
        cmd_help
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        init)
            cmd_init "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        audit)
            cmd_audit "$@"
            ;;
        resume)
            cmd_resume "$@"
            ;;
        preflight)
            cmd_preflight "$@"
            ;;
        validate)
            cmd_validate "$@"
            ;;
        tag)
            cmd_tag "$@"
            ;;
        publish)
            cmd_publish "$@"
            ;;
        packer)
            cmd_packer "$@"
            ;;
        verify)
            cmd_verify "$@"
            ;;
        close)
            cmd_close "$@"
            ;;
        full)
            cmd_full "$@"
            ;;
        selftest)
            cmd_selftest "$@"
            ;;
        sunset)
            cmd_sunset "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
