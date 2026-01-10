#!/usr/bin/env bash
#
# validate.sh - Validation integration for release CLI
#
# Runs integration tests via iac-driver and captures reports
#

# Default values
IAC_DRIVER_DIR="${WORKSPACE_DIR}/iac-driver"
DEFAULT_SCENARIO="vm-roundtrip"
DEFAULT_HOST="father"

# -----------------------------------------------------------------------------
# Validation Functions
# -----------------------------------------------------------------------------

validate_check_iac_driver() {
    if [[ ! -d "$IAC_DRIVER_DIR" ]]; then
        log_error "iac-driver not found at ${IAC_DRIVER_DIR}"
        return 1
    fi

    if [[ ! -x "${IAC_DRIVER_DIR}/run.sh" ]]; then
        log_error "iac-driver/run.sh not executable"
        return 1
    fi

    return 0
}

validate_find_latest_report() {
    local report_dir="${IAC_DRIVER_DIR}/reports"
    local pattern="$1"  # "passed" or "failed"

    if [[ ! -d "$report_dir" ]]; then
        echo ""
        return
    fi

    # Find most recent matching report
    local latest
    latest=$(ls -t "${report_dir}"/*.${pattern}.md 2>/dev/null | head -1)
    echo "$latest"
}

validate_run_scenario() {
    local scenario="$1"
    local host="$2"
    local verbose="${3:-false}"

    local cmd="${IAC_DRIVER_DIR}/run.sh --scenario ${scenario} --host ${host}"
    if [[ "$verbose" == "true" ]]; then
        cmd+=" --verbose"
    fi

    log_info "Running: $cmd"
    audit_cmd "$cmd" "iac-driver"

    # Run scenario and capture exit code
    # Use set +e to prevent script exit on command failure
    set +e
    eval "$cmd"
    local exit_code=$?
    set -e

    return $exit_code
}

# -----------------------------------------------------------------------------
# Main Validation Runner
# -----------------------------------------------------------------------------

run_validation() {
    local scenario="${1:-$DEFAULT_SCENARIO}"
    local host="${2:-$DEFAULT_HOST}"
    local skip="${3:-false}"
    local verbose="${4:-false}"

    # Handle skip
    if [[ "$skip" == "true" ]]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo -e "  ${YELLOW}WARNING: Validation skipped${NC}"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "  Validation was skipped with --skip flag."
        echo "  This should only be used for emergency releases."
        echo ""
        audit_log "SKIP" "human" "Validation skipped (emergency)"
        return 0
    fi

    # Check iac-driver exists
    if ! validate_check_iac_driver; then
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  VALIDATION: ${scenario}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Scenario: ${scenario}"
    echo "  Host:     ${host}"
    echo ""

    # Record start time to find new reports
    local start_time
    start_time=$(date +%s)

    # Run the scenario
    local scenario_passed=false
    if validate_run_scenario "$scenario" "$host" "$verbose"; then
        scenario_passed=true
    fi

    # Find the report generated during this run
    local report_path=""
    local report_dir="${IAC_DRIVER_DIR}/reports"

    if [[ -d "$report_dir" ]]; then
        # Find reports modified after start time
        for report in "${report_dir}"/*.md; do
            if [[ -f "$report" ]]; then
                local mod_time
                mod_time=$(stat -c %Y "$report" 2>/dev/null || stat -f %m "$report" 2>/dev/null)
                if [[ "$mod_time" -ge "$start_time" ]]; then
                    report_path="$report"
                    break
                fi
            fi
        done
    fi

    # Display result
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    if [[ "$scenario_passed" == "true" ]]; then
        echo -e "  RESULT: ${GREEN}PASSED${NC}"
    else
        echo -e "  RESULT: ${RED}FAILED${NC}"
    fi
    echo "═══════════════════════════════════════════════════════════════"

    if [[ -n "$report_path" ]]; then
        echo ""
        echo "  Report: ${report_path}"
        # Store relative path from workspace
        VALIDATION_REPORT="${report_path#${WORKSPACE_DIR}/}"
    else
        echo ""
        echo "  Report: (not found)"
        VALIDATION_REPORT=""
    fi
    echo ""

    if [[ "$scenario_passed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Export the report path variable
VALIDATION_REPORT=""
