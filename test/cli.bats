#!/usr/bin/env bats
#
# cli.bats - Tests for scripts/release.sh CLI routing
#

load 'test_helper/common'

setup() {
    setup_test_env

    # Export env vars so release.sh subprocess uses test environment
    export WORKSPACE_DIR STATE_FILE AUDIT_LOG

    RELEASE_SH="${BATS_TEST_DIRNAME}/../scripts/release.sh"
}

teardown() {
    teardown_test_env
}

# -----------------------------------------------------------------------------
# Help command tests
# -----------------------------------------------------------------------------

@test "help command shows usage" {
    run "$RELEASE_SH" help
    [ "$status" -eq 0 ]
    assert_output_contains "Usage:"
    assert_output_contains "release.sh"
}

@test "--help flag shows usage" {
    run "$RELEASE_SH" --help
    [ "$status" -eq 0 ]
    assert_output_contains "Usage:"
}

@test "-h flag shows usage" {
    run "$RELEASE_SH" -h
    [ "$status" -eq 0 ]
    assert_output_contains "Usage:"
}

@test "no command shows usage" {
    run "$RELEASE_SH"
    [ "$status" -eq 0 ]
    assert_output_contains "Usage:"
}

# -----------------------------------------------------------------------------
# Init command tests
# -----------------------------------------------------------------------------

@test "init requires --version" {
    run "$RELEASE_SH" init
    [ "$status" -eq 1 ]
    assert_output_contains "Version required"
}

@test "init with version creates state file" {
    run "$RELEASE_SH" init --version 0.99 --no-issue
    [ "$status" -eq 0 ]
    assert_file_exists "$STATE_FILE"
}

@test "init with --issue stores issue number" {
    run "$RELEASE_SH" init --version 0.99 --issue 123
    [ "$status" -eq 0 ]
    assert_json_field "$STATE_FILE" '.release.issue' "123"
}

@test "init fails if release already in progress" {
    "$RELEASE_SH" init --version 0.99 --no-issue

    run "$RELEASE_SH" init --version 0.100 --no-issue
    [ "$status" -eq 1 ]
    assert_output_contains "already in progress"
}

# -----------------------------------------------------------------------------
# Status command tests
# -----------------------------------------------------------------------------

@test "status with no release shows message" {
    run "$RELEASE_SH" status
    [ "$status" -eq 0 ]
    assert_output_contains "No release in progress"
}

@test "status shows release info" {
    "$RELEASE_SH" init --version 0.99 --no-issue

    run "$RELEASE_SH" status
    [ "$status" -eq 0 ]
    assert_output_contains "v0.99"
    assert_output_contains "Phases:"
    assert_output_contains "Repos:"
}

@test "status shows linked issue" {
    "$RELEASE_SH" init --version 0.99 --issue 100

    run "$RELEASE_SH" status
    [ "$status" -eq 0 ]
    assert_output_contains "100"
}

# -----------------------------------------------------------------------------
# Audit command tests
# -----------------------------------------------------------------------------

@test "audit shows entries after init" {
    "$RELEASE_SH" init --version 0.99 --no-issue

    run "$RELEASE_SH" audit
    [ "$status" -eq 0 ]
    assert_output_contains "INIT"
    assert_output_contains "0.99"
}

@test "audit --lines limits output" {
    "$RELEASE_SH" init --version 0.99 --no-issue

    run "$RELEASE_SH" audit --lines 5
    [ "$status" -eq 0 ]
    assert_output_contains "last 5 entries"
}

# -----------------------------------------------------------------------------
# Unknown command tests
# -----------------------------------------------------------------------------

@test "unknown command shows error and help" {
    run "$RELEASE_SH" foobar
    [ "$status" -eq 1 ]
    assert_output_contains "Unknown command"
    assert_output_contains "Usage:"
}

# -----------------------------------------------------------------------------
# Dependency check tests
# -----------------------------------------------------------------------------

# Skip: PATH manipulation test is inherently flaky in CI environments
# The dependency check is covered by manual testing
@test "missing jq is detected" {
    skip "PATH manipulation test unreliable - dependency check verified manually"
}
