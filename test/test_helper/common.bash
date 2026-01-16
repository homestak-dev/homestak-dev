#!/usr/bin/env bash
#
# common.bash - Shared test helper for release.sh bats tests
#
# Provides:
# - Test environment setup/teardown
# - Mock functions for external commands (gh, git)
# - Common assertions
#

# -----------------------------------------------------------------------------
# Test Environment
# -----------------------------------------------------------------------------

# Temporary directory for test artifacts
TEST_TEMP_DIR=""

# Path to scripts under test
SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../scripts"
LIB_DIR="${SCRIPTS_DIR}/lib"

setup_test_env() {
    # Create isolated temp directory for each test
    TEST_TEMP_DIR="$(mktemp -d)"
    export WORKSPACE_DIR="$TEST_TEMP_DIR"
    export STATE_FILE="${TEST_TEMP_DIR}/.release-state.json"
    export AUDIT_LOG="${TEST_TEMP_DIR}/.release-audit.log"

    # Source logging functions (required by lib scripts)
    source_logging_functions
}

teardown_test_env() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# -----------------------------------------------------------------------------
# Logging Functions (minimal versions for testing)
# -----------------------------------------------------------------------------

source_logging_functions() {
    # Minimal logging that doesn't use colors (for test output)
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[OK] $*"; }
    log_warn() { echo "[WARN] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

    export -f log_info log_success log_warn log_error timestamp
}

# -----------------------------------------------------------------------------
# Mock Functions
# -----------------------------------------------------------------------------

# Mock gh command - stores calls and returns configured responses
MOCK_GH_CALLS=()
MOCK_GH_RESPONSES=()
MOCK_GH_EXIT_CODES=()
MOCK_GH_RESPONSE_INDEX=0

mock_gh_setup() {
    MOCK_GH_CALLS=()
    MOCK_GH_RESPONSES=()
    MOCK_GH_EXIT_CODES=()
    MOCK_GH_RESPONSE_INDEX=0

    # Create mock gh function
    gh() {
        MOCK_GH_CALLS+=("$*")
        local response="${MOCK_GH_RESPONSES[$MOCK_GH_RESPONSE_INDEX]:-}"
        local exit_code="${MOCK_GH_EXIT_CODES[$MOCK_GH_RESPONSE_INDEX]:-0}"
        ((MOCK_GH_RESPONSE_INDEX++)) || true

        if [[ -n "$response" ]]; then
            echo "$response"
        fi
        return "$exit_code"
    }
    export -f gh
}

mock_gh_add_response() {
    local response="$1"
    local exit_code="${2:-0}"
    MOCK_GH_RESPONSES+=("$response")
    MOCK_GH_EXIT_CODES+=("$exit_code")
}

mock_gh_assert_called_with() {
    local expected="$1"
    local found=false

    for call in "${MOCK_GH_CALLS[@]}"; do
        if [[ "$call" == *"$expected"* ]]; then
            found=true
            break
        fi
    done

    if [[ "$found" != "true" ]]; then
        echo "Expected gh to be called with: $expected"
        echo "Actual calls:"
        printf '  %s\n' "${MOCK_GH_CALLS[@]}"
        return 1
    fi
}

# Mock git command
MOCK_GIT_CALLS=()
MOCK_GIT_RESPONSES=()
MOCK_GIT_EXIT_CODES=()
MOCK_GIT_RESPONSE_INDEX=0

mock_git_setup() {
    MOCK_GIT_CALLS=()
    MOCK_GIT_RESPONSES=()
    MOCK_GIT_EXIT_CODES=()
    MOCK_GIT_RESPONSE_INDEX=0

    git() {
        MOCK_GIT_CALLS+=("$*")
        local response="${MOCK_GIT_RESPONSES[$MOCK_GIT_RESPONSE_INDEX]:-}"
        local exit_code="${MOCK_GIT_EXIT_CODES[$MOCK_GIT_RESPONSE_INDEX]:-0}"
        ((MOCK_GIT_RESPONSE_INDEX++)) || true

        if [[ -n "$response" ]]; then
            echo "$response"
        fi
        return "$exit_code"
    }
    export -f git
}

mock_git_add_response() {
    local response="$1"
    local exit_code="${2:-0}"
    MOCK_GIT_RESPONSES+=("$response")
    MOCK_GIT_EXIT_CODES+=("$exit_code")
}

# -----------------------------------------------------------------------------
# Test State Helpers
# -----------------------------------------------------------------------------

create_test_state() {
    local version="${1:-0.25}"
    local status="${2:-in_progress}"

    cat > "$STATE_FILE" << EOF
{
  "schema_version": 1,
  "release": {
    "version": "${version}",
    "status": "${status}",
    "started_at": "2026-01-16T10:00:00Z",
    "completed_at": null,
    "issue": null
  },
  "phases": {
    "preflight": {"status": "pending", "started_at": null, "completed_at": null},
    "validation": {"status": "pending", "started_at": null, "completed_at": null, "report": null},
    "tags": {"status": "pending", "started_at": null, "completed_at": null},
    "releases": {"status": "pending", "started_at": null, "completed_at": null},
    "verification": {"status": "pending", "started_at": null, "completed_at": null}
  },
  "repos": {
    ".github": {"tag": "pending", "release": "pending"},
    ".claude": {"tag": "pending", "release": "pending"},
    "homestak-dev": {"tag": "pending", "release": "pending"},
    "site-config": {"tag": "pending", "release": "pending"},
    "tofu": {"tag": "pending", "release": "pending"},
    "ansible": {"tag": "pending", "release": "pending"},
    "bootstrap": {"tag": "pending", "release": "pending"},
    "packer": {"tag": "pending", "release": "pending"},
    "iac-driver": {"tag": "pending", "release": "pending"}
  }
}
EOF
}

create_test_state_with_progress() {
    local version="${1:-0.25}"

    cat > "$STATE_FILE" << EOF
{
  "schema_version": 1,
  "release": {
    "version": "${version}",
    "status": "in_progress",
    "started_at": "2026-01-16T10:00:00Z",
    "completed_at": null,
    "issue": 100
  },
  "phases": {
    "preflight": {"status": "complete", "started_at": "2026-01-16T10:01:00Z", "completed_at": "2026-01-16T10:02:00Z"},
    "validation": {"status": "complete", "started_at": "2026-01-16T10:03:00Z", "completed_at": "2026-01-16T10:10:00Z", "report": "reports/test.passed.md"},
    "tags": {"status": "pending", "started_at": null, "completed_at": null},
    "releases": {"status": "pending", "started_at": null, "completed_at": null},
    "verification": {"status": "pending", "started_at": null, "completed_at": null}
  },
  "repos": {
    ".github": {"tag": "pending", "release": "pending"},
    ".claude": {"tag": "pending", "release": "pending"},
    "homestak-dev": {"tag": "pending", "release": "pending"},
    "site-config": {"tag": "pending", "release": "pending"},
    "tofu": {"tag": "pending", "release": "pending"},
    "ansible": {"tag": "pending", "release": "pending"},
    "bootstrap": {"tag": "pending", "release": "pending"},
    "packer": {"tag": "pending", "release": "pending"},
    "iac-driver": {"tag": "pending", "release": "pending"}
  }
}
EOF
}

# -----------------------------------------------------------------------------
# Assertions
# -----------------------------------------------------------------------------

assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Expected file to exist: $file"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"

    if ! grep -q "$pattern" "$file"; then
        echo "Expected file $file to contain: $pattern"
        echo "Actual content:"
        cat "$file"
        return 1
    fi
}

assert_json_field() {
    local file="$1"
    local field="$2"
    local expected="$3"

    local actual
    actual=$(jq -r "$field" "$file")

    if [[ "$actual" != "$expected" ]]; then
        echo "Expected $field to be: $expected"
        echo "Actual value: $actual"
        return 1
    fi
}

assert_output_contains() {
    local expected="$1"

    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    fi
}

assert_output_not_contains() {
    local unexpected="$1"

    if [[ "$output" == *"$unexpected"* ]]; then
        echo "Expected output NOT to contain: $unexpected"
        echo "Actual output: $output"
        return 1
    fi
}
