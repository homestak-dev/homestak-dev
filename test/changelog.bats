#!/usr/bin/env bats
#
# changelog.bats - Tests for scripts/lib/changelog.sh
#

load 'test_helper/common'

setup() {
    setup_test_env
    source "${LIB_DIR}/audit.sh"
    source "${LIB_DIR}/state.sh"
    source "${LIB_DIR}/changelog.sh"
}

teardown() {
    teardown_test_env
}

# -----------------------------------------------------------------------------
# changelog_stamp_file tests
# -----------------------------------------------------------------------------

@test "changelog_stamp_file stamps version header with content" {
    local changelog="${TEST_TEMP_DIR}/CHANGELOG.md"
    cat > "$changelog" << 'EOF'
# Changelog

## Unreleased

### Added
- New feature

## v0.24 - 2026-01-16

### Fixed
- Bug fix
EOF

    run changelog_stamp_file "$changelog" "0.25" "2026-01-20"
    [ "$status" -eq 0 ]
    assert_output_contains "## v0.25 - 2026-01-20"
    assert_output_contains "## Unreleased"
    assert_output_contains "### Added"
    assert_output_contains "- New feature"
}

@test "changelog_stamp_file inserts No changes for empty section" {
    local changelog="${TEST_TEMP_DIR}/CHANGELOG.md"
    cat > "$changelog" << 'EOF'
# Changelog

## Unreleased

## v0.24 - 2026-01-16

### Fixed
- Bug fix
EOF

    run changelog_stamp_file "$changelog" "0.25" "2026-01-20"
    [ "$status" -eq 0 ]
    assert_output_contains "## v0.25 - 2026-01-20"
    assert_output_contains "No changes."
}

@test "changelog_stamp_file fails for missing file" {
    run changelog_stamp_file "/nonexistent/CHANGELOG.md" "0.25" "2026-01-20"
    [ "$status" -eq 1 ]
}

@test "changelog_stamp_file fails without Unreleased header" {
    local changelog="${TEST_TEMP_DIR}/CHANGELOG.md"
    cat > "$changelog" << 'EOF'
# Changelog

## v0.24 - 2026-01-16

### Fixed
- Bug fix
EOF

    run changelog_stamp_file "$changelog" "0.25" "2026-01-20"
    [ "$status" -eq 1 ]
}

@test "changelog_stamp_file preserves existing content below" {
    local changelog="${TEST_TEMP_DIR}/CHANGELOG.md"
    cat > "$changelog" << 'EOF'
# Changelog

## Unreleased

### Changed
- Updated API

## v0.24 - 2026-01-16

### Fixed
- Bug fix
EOF

    run changelog_stamp_file "$changelog" "0.25" "2026-01-20"
    [ "$status" -eq 0 ]
    assert_output_contains "## v0.24 - 2026-01-16"
    assert_output_contains "- Bug fix"
}

# -----------------------------------------------------------------------------
# changelog_preview_single tests
#
# Note: bats runs each test in a subshell; bash associative arrays (REPO_DIRS)
# cannot be passed to subshells. These tests create repo dirs at the fallback
# path ($WORKSPACE_DIR/$repo) which repo_dir() returns when REPO_DIRS is empty.
# Real path resolution is exercised via the CLI tests below.
# -----------------------------------------------------------------------------

# Helper: run function in current shell, capture output via file redirect.
# Captures exit status without triggering bats set -e.
_run_in_shell() {
    local outfile="${TEST_TEMP_DIR}/_test_output"
    _run_status=0
    "$@" > "$outfile" 2>&1 || _run_status=$?
    _run_output=$(cat "$outfile")
}

@test "changelog_preview_single shows content status" {
    # Use fallback path: repo_dir("meta") returns "meta" in subshell
    mkdir -p "${TEST_TEMP_DIR}/meta"
    cat > "${TEST_TEMP_DIR}/meta/CHANGELOG.md" << 'EOF'
# Changelog

## Unreleased

### Added
- New feature

## v0.24 - 2026-01-16
EOF

    GREEN='' NC='' YELLOW='' RED='' BLUE=''

    _run_in_shell changelog_preview_single "meta" "0.25" "2026-01-20"
    [ "$_run_status" -eq 0 ]
    [[ "$_run_output" == *"meta"* ]]
    [[ "$_run_output" == *"0.25"* ]]
}

@test "changelog_preview_single shows empty status" {
    mkdir -p "${TEST_TEMP_DIR}/meta"
    cat > "${TEST_TEMP_DIR}/meta/CHANGELOG.md" << 'EOF'
# Changelog

## Unreleased

## v0.24 - 2026-01-16
EOF

    GREEN='' NC='' YELLOW='' RED='' BLUE=''

    _run_in_shell changelog_preview_single "meta" "0.25" "2026-01-20"
    [ "$_run_status" -eq 0 ]
    [[ "$_run_output" == *"meta"* ]]
    [[ "$_run_output" == *"empty"* ]]
}

@test "changelog_preview_single skips missing directory" {
    YELLOW='' NC=''

    _run_in_shell changelog_preview_single "nonexistent" "0.25" "2026-01-20"
    [ "$_run_status" -eq 0 ]
    [[ "$_run_output" == *"not found"* ]]
}

@test "changelog_preview_single skips missing CHANGELOG" {
    mkdir -p "${TEST_TEMP_DIR}/meta"

    YELLOW='' NC=''

    _run_in_shell changelog_preview_single "meta" "0.25" "2026-01-20"
    [ "$_run_status" -eq 0 ]
    [[ "$_run_output" == *"no CHANGELOG.md"* ]]
}

@test "changelog_preview_single fails on missing Unreleased header" {
    mkdir -p "${TEST_TEMP_DIR}/meta"
    cat > "${TEST_TEMP_DIR}/meta/CHANGELOG.md" << 'EOF'
# Changelog

## v0.24 - 2026-01-16
EOF

    RED='' NC=''

    _run_in_shell changelog_preview_single "meta" "0.25" "2026-01-20"
    [ "$_run_status" -eq 1 ]
    [[ "$_run_output" == *"no '## Unreleased' header"* ]]
}

# -----------------------------------------------------------------------------
# CLI routing tests (via release script)
# -----------------------------------------------------------------------------

@test "changelog requires release state" {
    export WORKSPACE_DIR STATE_FILE AUDIT_LOG
    RELEASE_SH="${BATS_TEST_DIRNAME}/../scripts/release"

    run "$RELEASE_SH" changelog
    [ "$status" -eq 1 ]
    assert_output_contains "No release in progress"
}

@test "changelog --dry-run runs preview" {
    export WORKSPACE_DIR STATE_FILE AUDIT_LOG
    RELEASE_SH="${BATS_TEST_DIRNAME}/../scripts/release"

    "$RELEASE_SH" init --version 0.99 --no-issue

    run "$RELEASE_SH" changelog --dry-run
    [ "$status" -eq 0 ]
    assert_output_contains "CHANGELOG Stamp"
    assert_output_contains "Preview"
}

@test "changelog rejects unknown options" {
    export WORKSPACE_DIR STATE_FILE AUDIT_LOG
    RELEASE_SH="${BATS_TEST_DIRNAME}/../scripts/release"

    "$RELEASE_SH" init --version 0.99 --no-issue

    run "$RELEASE_SH" changelog --bad-flag
    [ "$status" -eq 1 ]
    assert_output_contains "Unknown option"
}

@test "help shows changelog command" {
    export WORKSPACE_DIR STATE_FILE AUDIT_LOG
    RELEASE_SH="${BATS_TEST_DIRNAME}/../scripts/release"

    run "$RELEASE_SH" help
    [ "$status" -eq 0 ]
    assert_output_contains "changelog"
}

@test "status shows changelog phase" {
    export WORKSPACE_DIR STATE_FILE AUDIT_LOG
    RELEASE_SH="${BATS_TEST_DIRNAME}/../scripts/release"

    "$RELEASE_SH" init --version 0.99 --no-issue

    run "$RELEASE_SH" status
    [ "$status" -eq 0 ]
    assert_output_contains "changelog"
}
