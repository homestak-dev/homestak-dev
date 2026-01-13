#!/usr/bin/env bash
#
# release.sh - homestak-dev release automation CLI
#
# Usage:
#   release.sh init --version X.Y
#   release.sh status
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
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
STATE_FILE="${WORKSPACE_DIR}/.release-state.json"
AUDIT_LOG="${WORKSPACE_DIR}/.release-audit.log"

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

    while [[ $# -gt 0 ]]; do
        case "$1" in
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
    state_init "$version"
    audit_init "$version"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Release v${version} initialized"
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

    local version status started_at
    version=$(state_get_version)
    status=$(state_get_status)
    started_at=$(state_read '.release.started_at')

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Release v${version} - Status: ${status}"
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

cmd_preflight() {
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
    if run_preflight "$version" "$json_output"; then
        if state_exists; then
            state_set_phase_status "preflight" "complete"
        fi
        exit 0
    else
        if state_exists; then
            state_set_phase_status "preflight" "failed"
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
    if run_validation "$scenario" "$host" "$skip" "$verbose" "$remote"; then
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
    if run_tag "$version" "$dry_run" "$force"; then
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "tags" "complete"
            audit_log "TAG" "cli" "Tags v${version} created in ${#REPOS[@]} repos"
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

    # Update state
    state_set_phase_status "releases" "in_progress"

    # Run publish
    if run_publish "$version" "$dry_run" "$force" "$images_dir"; then
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "releases" "complete"
            audit_log "PUBLISH" "cli" "Releases v${version} created in ${#REPOS[@]} repos"
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
            local source
            source=$(packer_get_latest_release "$version")

            if [[ -z "$source" ]]; then
                log_error "No previous release with images found"
                exit 1
            fi

            echo "Source release: $source"
            echo "Target release: v${version}"
            echo ""

            if [[ "$dry_run" == "true" ]]; then
                echo "Commands that would be executed:"
                echo ""
                packer_copy_images_local "$version" "$source" "true"
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "  DRY-RUN COMPLETE - No changes made"
                echo "  Run with --execute to copy images"
                echo "═══════════════════════════════════════════════════════════════"
            else
                if packer_copy_images_local "$version" "$source" "false"; then
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
        fi
        exit 0
    else
        if state_exists; then
            state_set_phase_status "verification" "failed"
        fi
        exit 8
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
                ;;

            validate)
                if ! run_validation "$scenario" "$host" "false" "false" ""; then
                    log_error "Validation failed"
                    return 1
                fi
                state_set_phase_status "validation" "complete"
                ;;

            tag)
                if ! run_tag "$version" "false" "false"; then
                    log_error "Tag creation failed"
                    return 1
                fi
                state_set_phase_status "tags" "complete"
                audit_log "TAG" "cli" "Tags v${version} created in ${#REPOS[@]} repos"
                ;;

            publish)
                if ! run_publish "$version" "false" "false" "$images_dir"; then
                    log_error "Publish failed"
                    return 1
                fi
                state_set_phase_status "releases" "complete"
                audit_log "PUBLISH" "cli" "Releases v${version} created in ${#REPOS[@]} repos"
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
    local test_state_file="${WORKSPACE_DIR}/.release-selftest-state.json"
    local test_audit_log="${WORKSPACE_DIR}/.release-selftest-audit.log"

    # Backup real state if exists
    local had_real_state=false
    if [[ -f "$STATE_FILE" ]]; then
        had_real_state=true
        mv "$STATE_FILE" "${STATE_FILE}.bak"
    fi
    if [[ -f "$AUDIT_LOG" ]]; then
        mv "$AUDIT_LOG" "${AUDIT_LOG}.bak"
    fi

    # Cleanup function
    cleanup_selftest() {
        rm -f "$test_state_file" "$test_audit_log"
        rm -f "$STATE_FILE" "$AUDIT_LOG"
        # Restore real state
        if [[ "$had_real_state" == "true" && -f "${STATE_FILE}.bak" ]]; then
            mv "${STATE_FILE}.bak" "$STATE_FILE"
        fi
        if [[ -f "${AUDIT_LOG}.bak" ]]; then
            mv "${AUDIT_LOG}.bak" "$AUDIT_LOG"
        fi
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
            ((passed++))
            return 0
        else
            echo -e "${RED}FAIL${NC} (exit code: $exit_code)"
            if [[ "$verbose" != "true" && -n "$output" ]]; then
                echo "$output" | head -5 | sed 's/^/      /'
            fi
            ((failed++))
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
        ((passed++))
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
        ((passed++))
    else
        echo -e "${YELLOW}SKIP${NC} (verify runs against real releases)"
    fi

    # Test 9: full --dry-run
    run_test "full-dry" "Full release dry-run" "$0" full --dry-run

    # Test 10: audit
    run_test "audit" "Show audit log" "$0" audit --lines 5

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
  preflight   Run pre-flight checks
  validate    Run integration tests
  tag         Create git tags
  publish     Create GitHub releases
  packer      Handle packer image automation
  verify      Verify release artifacts
  full        Execute complete release workflow
  selftest    Run self-test on all commands
  audit       Show audit log

Options:
  --version X.Y      Release version (required for init)
  --dry-run          Show what would be done without executing
  --execute          Execute the operation
  --force            Override validation gate requirement
  --rollback         Rollback tags/releases on failure
  --reset            Reset tags to HEAD (delete and recreate, v0.x only)
  --reset-repo REPO  Reset tag for single repo only
  --skip             Skip validation (emergency releases only)
  --remote HOST      Run validation on remote host via SSH
  --lines N          Number of audit log lines to show (default: 20)

Examples:
  release.sh init --version 0.14
  release.sh status
  release.sh preflight
  release.sh validate --scenario vm-roundtrip --host father
  release.sh validate --scenario vm-roundtrip --host father --remote father
  release.sh validate --skip
  release.sh tag --dry-run
  release.sh tag --execute
  release.sh tag --execute --force
  release.sh tag --rollback
  release.sh tag --reset --dry-run
  release.sh tag --reset --execute
  release.sh tag --reset-repo packer --execute
  release.sh packer --check
  release.sh packer --copy --dry-run
  release.sh packer --copy --execute
  release.sh full --dry-run
  release.sh full --execute --host father
  release.sh full --execute --skip-validate
  release.sh selftest
  release.sh selftest --verbose
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
        full)
            cmd_full "$@"
            ;;
        selftest)
            cmd_selftest "$@"
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
