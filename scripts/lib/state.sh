#!/usr/bin/env bash
#
# state.sh - State management for release CLI
#
# State is stored as JSON in .release-state.json
# Uses jq for parsing (ubiquitous, single implementation)
#

# State file location (set by main script)
STATE_FILE="${STATE_FILE:-${WORKSPACE_DIR:-.}/.release-state.json}"
SCHEMA_VERSION=1

# All repos in dependency order
REPOS=(.github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver)

# -----------------------------------------------------------------------------
# State File Operations
# -----------------------------------------------------------------------------

state_exists() {
    [[ -f "$STATE_FILE" ]]
}

state_validate() {
    if ! state_exists; then
        return 1
    fi

    # Check it's valid JSON
    if ! jq empty "$STATE_FILE" 2>/dev/null; then
        log_error "State file is not valid JSON"
        return 1
    fi

    # Check schema version
    local schema
    schema=$(jq -r '.schema_version // 0' "$STATE_FILE")

    if [[ "$schema" != "$SCHEMA_VERSION" ]]; then
        log_error "State file schema version mismatch (got ${schema}, expected ${SCHEMA_VERSION})"
        return 1
    fi

    # Check required fields
    local version status
    version=$(jq -r '.release.version // ""' "$STATE_FILE")
    status=$(jq -r '.release.status // ""' "$STATE_FILE")

    if [[ -z "$version" || -z "$status" ]]; then
        log_error "State file missing required fields (version or status)"
        return 1
    fi

    return 0
}

state_read() {
    local field="$1"
    jq -r "$field" "$STATE_FILE" 2>/dev/null
}

state_write() {
    local field="$1"
    local value="$2"
    local tmp_file

    tmp_file=$(mktemp)
    if jq "${field} = \"${value}\"" "$STATE_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$STATE_FILE"
    else
        rm -f "$tmp_file"
        log_error "Failed to write state field: $field"
        return 1
    fi
}

state_write_raw() {
    # Write a non-string value (null, number, object)
    local field="$1"
    local value="$2"
    local tmp_file

    tmp_file=$(mktemp)
    if jq "${field} = ${value}" "$STATE_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$STATE_FILE"
    else
        rm -f "$tmp_file"
        log_error "Failed to write state field: $field"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Convenience Accessors
# -----------------------------------------------------------------------------

state_get_version() {
    state_read '.release.version'
}

state_get_status() {
    state_read '.release.status'
}

state_set_status() {
    local status="$1"
    state_write '.release.status' "$status"
}

state_get_phase_status() {
    local phase="$1"
    state_read ".phases.${phase}.status"
}

state_set_phase_status() {
    local phase="$1"
    local status="$2"
    local ts
    ts=$(timestamp)

    state_write ".phases.${phase}.status" "$status"

    if [[ "$status" == "in_progress" ]]; then
        state_write ".phases.${phase}.started_at" "$ts"
    elif [[ "$status" == "complete" || "$status" == "failed" ]]; then
        state_write ".phases.${phase}.completed_at" "$ts"
    fi

    # Log phase change
    audit_phase "$phase" "$status"
}

state_get_repo_field() {
    local repo="$1"
    local field="$2"
    state_read ".repos[\"${repo}\"].${field}"
}

state_set_repo_field() {
    local repo="$1"
    local field="$2"
    local value="$3"
    local tmp_file

    tmp_file=$(mktemp)
    if jq ".repos[\"${repo}\"].${field} = \"${value}\"" "$STATE_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$STATE_FILE"
    else
        rm -f "$tmp_file"
        log_error "Failed to write repo state: $repo.$field"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# State Initialization
# -----------------------------------------------------------------------------

state_init() {
    local version="$1"
    local ts
    ts=$(timestamp)

    # Build repos object
    local repos_json="{"
    local first=true
    for repo in "${REPOS[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            repos_json+=","
        fi
        repos_json+="\"${repo}\":{\"tag\":\"pending\",\"release\":\"pending\"}"
    done
    repos_json+="}"

    # Create state file
    cat > "$STATE_FILE" << EOF
{
  "schema_version": ${SCHEMA_VERSION},
  "release": {
    "version": "${version}",
    "status": "in_progress",
    "started_at": "${ts}",
    "completed_at": null
  },
  "phases": {
    "preflight": {
      "status": "pending",
      "started_at": null,
      "completed_at": null
    },
    "validation": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "report": null
    },
    "tags": {
      "status": "pending",
      "started_at": null,
      "completed_at": null
    },
    "releases": {
      "status": "pending",
      "started_at": null,
      "completed_at": null
    },
    "verification": {
      "status": "pending",
      "started_at": null,
      "completed_at": null
    }
  },
  "repos": ${repos_json}
}
EOF

    log_success "State file initialized for v${version}"
}
