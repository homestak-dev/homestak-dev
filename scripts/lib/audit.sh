#!/usr/bin/env bash
#
# audit.sh - Audit logging for release CLI
#
# Audit log is plain text, one entry per line:
# TIMESTAMP | ACTION | ACTOR | DETAILS
#

# Audit log location (set by main script)
AUDIT_LOG="${AUDIT_LOG:-${WORKSPACE_DIR:-.}/.release-audit.log}"

# -----------------------------------------------------------------------------
# Core Logging
# -----------------------------------------------------------------------------

audit_log() {
    local action="$1"
    local actor="${2:-cli}"
    local details="${3:-}"
    local ts
    ts=$(timestamp)

    # Ensure log directory exists
    mkdir -p "$(dirname "$AUDIT_LOG")"

    # Append to audit log (format: TIMESTAMP | ACTION | ACTOR | DETAILS)
    printf "%s | %-8s | %-6s | %s\n" "$ts" "$action" "$actor" "$details" >> "$AUDIT_LOG"
}

# -----------------------------------------------------------------------------
# Typed Log Entries
# -----------------------------------------------------------------------------

audit_init() {
    local version="$1"
    audit_log "INIT" "human" "Initialized release v${version}"
}

audit_cmd() {
    local cmd="$1"
    local context="${2:-}"
    if [[ -n "$context" ]]; then
        audit_log "CMD" "cli" "${cmd} (in ${context})"
    else
        audit_log "CMD" "cli" "${cmd}"
    fi
}

audit_phase() {
    local phase="$1"
    local status="$2"
    audit_log "PHASE" "cli" "${phase}: ${status}"
}

audit_approve() {
    local action="$1"
    audit_log "APPROVE" "human" "Approved ${action}"
}

audit_error() {
    local error="$1"
    audit_log "ERROR" "cli" "${error}"
}

audit_done() {
    local version="$1"
    audit_log "DONE" "cli" "Release v${version} complete"
}

# -----------------------------------------------------------------------------
# Log Viewing
# -----------------------------------------------------------------------------

audit_show() {
    local lines="${1:-20}"
    if [[ -f "$AUDIT_LOG" ]]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "  Recent Audit Log (last ${lines} entries)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        tail -n "$lines" "$AUDIT_LOG"
        echo ""
    else
        log_info "No audit log found"
    fi
}
