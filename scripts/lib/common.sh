#!/usr/bin/env bash
#
# common.sh - Shared helpers for release CLI command handlers
#

# Require an active release with valid state, or exit with error
require_release_state() {
    if ! state_exists; then
        log_error "No release in progress"
        log_error "Start with: release.sh init --version X.Y"
        exit 1
    fi
    if ! state_validate; then
        log_error "State file is corrupted"
        exit 3
    fi
}

# Check that required external tools are available
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
