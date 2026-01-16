#!/usr/bin/env bats
#
# state.bats - Tests for scripts/lib/state.sh
#

load 'test_helper/common'

setup() {
    setup_test_env
    source "${LIB_DIR}/audit.sh"
    source "${LIB_DIR}/state.sh"
}

teardown() {
    teardown_test_env
}

# -----------------------------------------------------------------------------
# state_exists tests
# -----------------------------------------------------------------------------

@test "state_exists returns false when no state file" {
    run state_exists
    [ "$status" -eq 1 ]
}

@test "state_exists returns true when state file exists" {
    create_test_state
    run state_exists
    [ "$status" -eq 0 ]
}

# -----------------------------------------------------------------------------
# state_init tests
# -----------------------------------------------------------------------------

@test "state_init creates state file with correct version" {
    state_init "0.25"

    assert_file_exists "$STATE_FILE"
    assert_json_field "$STATE_FILE" '.release.version' "0.25"
}

@test "state_init sets status to in_progress" {
    state_init "0.25"

    assert_json_field "$STATE_FILE" '.release.status' "in_progress"
}

@test "state_init sets schema_version" {
    state_init "0.25"

    assert_json_field "$STATE_FILE" '.schema_version' "1"
}

@test "state_init with issue number" {
    state_init "0.25" "100"

    assert_json_field "$STATE_FILE" '.release.issue' "100"
}

@test "state_init without issue sets null" {
    state_init "0.25"

    assert_json_field "$STATE_FILE" '.release.issue' "null"
}

@test "state_init creates all repos with pending status" {
    state_init "0.25"

    for repo in .github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver; do
        assert_json_field "$STATE_FILE" ".repos[\"${repo}\"].tag" "pending"
        assert_json_field "$STATE_FILE" ".repos[\"${repo}\"].release" "pending"
    done
}

@test "state_init creates all phases with pending status" {
    state_init "0.25"

    for phase in preflight validation tags releases verification; do
        assert_json_field "$STATE_FILE" ".phases.${phase}.status" "pending"
    done
}

# -----------------------------------------------------------------------------
# state_validate tests
# -----------------------------------------------------------------------------

@test "state_validate returns false for non-existent file" {
    run state_validate
    [ "$status" -eq 1 ]
}

@test "state_validate returns true for valid state" {
    create_test_state "0.25" "in_progress"

    run state_validate
    [ "$status" -eq 0 ]
}

@test "state_validate fails for invalid JSON" {
    echo "not valid json" > "$STATE_FILE"

    run state_validate
    [ "$status" -eq 1 ]
}

@test "state_validate fails for wrong schema version" {
    create_test_state
    # Modify schema version to invalid value
    local tmp=$(mktemp)
    jq '.schema_version = 99' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"

    run state_validate
    [ "$status" -eq 1 ]
}

# -----------------------------------------------------------------------------
# state_get_* tests
# -----------------------------------------------------------------------------

@test "state_get_version returns version" {
    create_test_state "0.25"

    run state_get_version
    [ "$status" -eq 0 ]
    [ "$output" = "0.25" ]
}

@test "state_get_status returns status" {
    create_test_state "0.25" "in_progress"

    run state_get_status
    [ "$status" -eq 0 ]
    [ "$output" = "in_progress" ]
}

@test "state_get_issue returns issue number" {
    create_test_state_with_progress

    run state_get_issue
    [ "$status" -eq 0 ]
    [ "$output" = "100" ]
}

@test "state_get_issue returns empty for null issue" {
    create_test_state

    run state_get_issue
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "state_get_phase_status returns phase status" {
    create_test_state_with_progress

    run state_get_phase_status "preflight"
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]

    run state_get_phase_status "tags"
    [ "$status" -eq 0 ]
    [ "$output" = "pending" ]
}

@test "state_get_repo_field returns repo field" {
    create_test_state

    run state_get_repo_field ".github" "tag"
    [ "$status" -eq 0 ]
    [ "$output" = "pending" ]
}

# -----------------------------------------------------------------------------
# state_set_* tests
# -----------------------------------------------------------------------------

@test "state_set_status updates status" {
    create_test_state "0.25" "in_progress"

    state_set_status "complete"

    assert_json_field "$STATE_FILE" '.release.status' "complete"
}

@test "state_set_phase_status updates phase status" {
    create_test_state

    state_set_phase_status "preflight" "complete"

    assert_json_field "$STATE_FILE" '.phases.preflight.status' "complete"
}

@test "state_set_phase_status sets completed_at timestamp" {
    create_test_state

    state_set_phase_status "preflight" "complete"

    local completed_at
    completed_at=$(jq -r '.phases.preflight.completed_at' "$STATE_FILE")
    [ "$completed_at" != "null" ]
}

@test "state_set_phase_status sets started_at for in_progress" {
    create_test_state

    state_set_phase_status "preflight" "in_progress"

    local started_at
    started_at=$(jq -r '.phases.preflight.started_at' "$STATE_FILE")
    [ "$started_at" != "null" ]
}

@test "state_set_repo_field updates repo field" {
    create_test_state

    state_set_repo_field ".github" "tag" "done"

    assert_json_field "$STATE_FILE" '.repos[".github"].tag' "done"
}

# -----------------------------------------------------------------------------
# state_set_issue tests
# -----------------------------------------------------------------------------

@test "state_set_issue sets issue number" {
    create_test_state

    state_set_issue "123"

    assert_json_field "$STATE_FILE" '.release.issue' "123"
}

@test "state_set_issue with empty clears issue" {
    create_test_state_with_progress

    state_set_issue ""

    assert_json_field "$STATE_FILE" '.release.issue' "null"
}

# -----------------------------------------------------------------------------
# REPOS array tests
# -----------------------------------------------------------------------------

@test "REPOS array has 9 repositories" {
    [ "${#REPOS[@]}" -eq 9 ]
}

@test "REPOS array is in dependency order" {
    # First should be meta repos
    [ "${REPOS[0]}" = ".github" ]
    [ "${REPOS[1]}" = ".claude" ]
    [ "${REPOS[2]}" = "homestak-dev" ]

    # Last should be iac-driver (depends on all others)
    [ "${REPOS[8]}" = "iac-driver" ]
}
