#!/usr/bin/env bash
#
# validate.sh - Validation integration for release CLI
#
# Runs integration tests via iac-driver and captures reports
#
# Execution modes:
#   dev (default) - runs ./iac-driver/run.sh from dev checkout
#   stage         - runs via installed 'homestak scenario' CLI
#

# Default values
IAC_DRIVER_DIR="${WORKSPACE_DIR}/iac-driver"
DEFAULT_SCENARIO="vm-roundtrip"
DEFAULT_HOST="father"

# FHS paths for stage mode
HOMESTAK_CLI="/usr/local/bin/homestak"
HOMESTAK_IAC_DRIVER="/usr/local/lib/homestak/iac-driver"

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
    local packer_release="${4:-}"

    local cmd="${IAC_DRIVER_DIR}/run.sh --scenario ${scenario} --host ${host}"
    if [[ "$verbose" == "true" ]]; then
        cmd+=" --verbose"
    fi
    if [[ -n "$packer_release" ]]; then
        cmd+=" --packer-release ${packer_release}"
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

validate_run_remote() {
    local remote_host="$1"
    local scenario="$2"
    local host="$3"
    local verbose="${4:-false}"
    local packer_release="${5:-}"

    local verbose_flag=""
    if [[ "$verbose" == "true" ]]; then
        verbose_flag="--verbose"
    fi

    local packer_release_flag=""
    if [[ -n "$packer_release" ]]; then
        packer_release_flag="--packer-release ${packer_release}"
    fi

    # Build the remote command
    local remote_cmd="cd ~/homestak-dev && ./scripts/release.sh validate --scenario ${scenario} --host ${host} ${verbose_flag} ${packer_release_flag}"

    log_info "Running validation on ${remote_host}..."
    log_info "Remote command: ${remote_cmd}"
    audit_cmd "ssh ${remote_host} '${remote_cmd}'" "ssh"

    # Run on remote and capture exit code
    set +e
    ssh "${remote_host}" "${remote_cmd}"
    local exit_code=$?
    set -e

    # Copy reports back
    local report_dir="${IAC_DRIVER_DIR}/reports"
    mkdir -p "$report_dir"

    log_info "Copying reports from ${remote_host}..."
    scp -q "${remote_host}:~/homestak-dev/iac-driver/reports/*.md" "${report_dir}/" 2>/dev/null || true

    return $exit_code
}

# -----------------------------------------------------------------------------
# Stage Mode Functions (validate via installed CLI)
# -----------------------------------------------------------------------------

validate_check_homestak_cli() {
    if [[ ! -x "$HOMESTAK_CLI" ]]; then
        log_error "homestak CLI not found at ${HOMESTAK_CLI}"
        log_error "Stage mode requires bootstrap installation"
        log_error "Use --remote <host> to run on a bootstrapped host"
        return 1
    fi
    return 0
}

validate_run_stage_local() {
    local scenario="$1"
    local host="$2"
    local verbose="${3:-false}"
    local packer_release="${4:-}"

    # Build the command (sudo required for FHS paths)
    local cmd="sudo ${HOMESTAK_CLI} scenario ${scenario} --host ${host}"
    if [[ "$verbose" == "true" ]]; then
        cmd+=" --verbose"
    fi
    if [[ -n "$packer_release" ]]; then
        cmd+=" --packer-release ${packer_release}"
    fi

    log_info "Running (stage): $cmd"
    audit_cmd "$cmd" "homestak"

    # Run scenario and capture exit code
    set +e
    eval "$cmd"
    local exit_code=$?
    set -e

    return $exit_code
}

validate_run_stage_remote() {
    local remote_host="$1"
    local scenario="$2"
    local host="$3"
    local verbose="${4:-false}"
    local packer_release="${5:-}"

    local verbose_flag=""
    if [[ "$verbose" == "true" ]]; then
        verbose_flag="--verbose"
    fi

    local packer_release_flag=""
    if [[ -n "$packer_release" ]]; then
        packer_release_flag="--packer-release ${packer_release}"
    fi

    # Build the remote command - uses homestak CLI (sudo required for FHS paths)
    local remote_cmd="sudo homestak scenario ${scenario} --host ${host} ${verbose_flag} ${packer_release_flag}"

    log_info "Running stage validation on ${remote_host}..."
    log_info "Remote command: ${remote_cmd}"
    audit_cmd "ssh ${remote_host} '${remote_cmd}'" "ssh"

    # Run on remote and capture exit code
    set +e
    ssh "${remote_host}" "${remote_cmd}"
    local exit_code=$?
    set -e

    # Copy reports back from FHS location
    local report_dir="${IAC_DRIVER_DIR}/reports"
    mkdir -p "$report_dir"

    log_info "Copying reports from ${remote_host} (FHS path)..."
    scp -q "${remote_host}:${HOMESTAK_IAC_DRIVER}/reports/*.md" "${report_dir}/" 2>/dev/null || true

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
    local remote_host="${5:-}"
    local packer_release="${6:-}"
    local stage="${7:-false}"

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

    # Determine mode and check prerequisites
    local mode="dev"
    if [[ "$stage" == "true" ]]; then
        mode="stage"
        # Stage mode: check homestak CLI exists (local) or trust remote has it
        if [[ -z "$remote_host" ]] && ! validate_check_homestak_cli; then
            return 1
        fi
    else
        # Dev mode: check iac-driver exists (only for local execution)
        if [[ -z "$remote_host" ]] && ! validate_check_iac_driver; then
            return 1
        fi
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  VALIDATION: ${scenario}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Scenario: ${scenario}"
    echo "  Host:     ${host}"
    echo "  Mode:     ${mode}"
    if [[ -n "$remote_host" ]]; then
        echo "  Remote:   ${remote_host}"
    fi
    echo ""

    # Record start time to find new reports
    local start_time
    start_time=$(date +%s)

    # Run the scenario based on mode
    local scenario_passed=false
    if [[ "$stage" == "true" ]]; then
        # Stage mode: use homestak CLI
        if [[ -n "$remote_host" ]]; then
            if validate_run_stage_remote "$remote_host" "$scenario" "$host" "$verbose" "$packer_release"; then
                scenario_passed=true
            fi
        else
            if validate_run_stage_local "$scenario" "$host" "$verbose" "$packer_release"; then
                scenario_passed=true
            fi
        fi
    else
        # Dev mode: use iac-driver directly
        if [[ -n "$remote_host" ]]; then
            if validate_run_remote "$remote_host" "$scenario" "$host" "$verbose" "$packer_release"; then
                scenario_passed=true
            fi
        else
            if validate_run_scenario "$scenario" "$host" "$verbose" "$packer_release"; then
                scenario_passed=true
            fi
        fi
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
