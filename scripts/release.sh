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

# Git-derived version (do not use hardcoded VERSION constant)
get_version() {
    git -C "$(dirname "${BASH_SOURCE[0]}")" describe --tags --abbrev=0 2>/dev/null || echo "dev"
}

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
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] [INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] [OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[$(date +%H:%M:%S)] [WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +%H:%M:%S)] [ERROR]${NC} $*" >&2
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
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/preflight.sh"
source "${SCRIPT_DIR}/lib/validate.sh"
source "${SCRIPT_DIR}/lib/tag.sh"
source "${SCRIPT_DIR}/lib/publish.sh"
source "${SCRIPT_DIR}/lib/verify.sh"
source "${SCRIPT_DIR}/lib/close.sh"
source "${SCRIPT_DIR}/lib/cmd_lifecycle.sh"
source "${SCRIPT_DIR}/lib/cmd_release.sh"
source "${SCRIPT_DIR}/lib/cmd_tools.sh"

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
        retrospective)
            cmd_retrospective "$@"
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
        --version)
            echo "release.sh $(get_version)"
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
