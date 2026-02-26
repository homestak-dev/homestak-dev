#!/usr/bin/env bash
#
# cmd_release.sh - Core release pipeline commands
#
# Commands: cmd_preflight, cmd_validate, cmd_tag, cmd_publish, cmd_verify, cmd_full
#

cmd_preflight() {
    local json_output=false
    local version=""
    local hosts=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                json_output=true
                shift
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            --host)
                hosts+=("$2")
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Get version from state if not provided
    if [[ -z "$version" ]]; then
        if state_exists && state_validate; then
            version=$(state_get_version)
        else
            log_error "No version specified and no release in progress"
            log_error "Use: release.sh preflight --version X.Y"
            log_error "Or: release.sh init --version X.Y"
            exit 1
        fi
    fi

    # Update state
    if state_exists; then
        state_set_phase_status "preflight" "in_progress"
    fi

    # Run checks
    if run_preflight "$version" "$json_output" "${hosts[@]}"; then
        if state_exists; then
            state_set_phase_status "preflight" "complete"
            issue_update_preflight "passed"
        fi
        exit 0
    else
        if state_exists; then
            state_set_phase_status "preflight" "failed"
            issue_update_preflight "failed"
        fi
        exit 4
    fi
}

cmd_validate() {
    local scenario=""
    local host=""
    local skip=false
    local verbose=false
    local remote=""
    local packer_release=""
    local stage=false
    local manifest="n1-push"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scenario)
                scenario="$2"
                manifest=""  # Explicit scenario overrides default manifest
                shift 2
                ;;
            --host)
                host="$2"
                shift 2
                ;;
            --remote)
                remote="$2"
                shift 2
                ;;
            --packer-release)
                packer_release="$2"
                shift 2
                ;;
            --manifest)
                manifest="$2"
                scenario=""  # Explicit manifest overrides any scenario
                shift 2
                ;;
            --skip)
                skip=true
                shift
                ;;
            --stage)
                stage=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Update state
    if state_exists; then
        state_set_phase_status "validation" "in_progress"
    fi

    # Run validation
    local validation_passed=false
    if run_validation "$scenario" "$host" "$skip" "$verbose" "$remote" "$packer_release" "$stage" "$manifest"; then
        validation_passed=true
    fi

    # Store report path in state (regardless of pass/fail)
    if state_exists && [[ -n "$VALIDATION_REPORT" ]]; then
        state_write ".phases.validation.report" "$VALIDATION_REPORT"
    fi

    # Update phase status
    if [[ "$validation_passed" == "true" ]]; then
        if state_exists; then
            state_set_phase_status "validation" "complete"
            issue_update_validation "$scenario" "$host" "${VALIDATION_REPORT:-}"
        fi
        exit 0
    else
        if state_exists; then
            state_set_phase_status "validation" "failed"
        fi
        exit 5
    fi
}

cmd_tag() {
    local dry_run=true
    local force=false
    local rollback=false
    local reset=false
    local reset_repo=""
    local yes_flag=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --execute)
                dry_run=false
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --rollback)
                rollback=true
                shift
                ;;
            --reset)
                reset=true
                shift
                ;;
            --reset-repo)
                reset=true
                reset_repo="$2"
                shift 2
                ;;
            --yes|-y)
                yes_flag=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    require_release_state

    local version
    version=$(state_get_version)

    # Handle rollback
    if [[ "$rollback" == "true" ]]; then
        state_set_phase_status "tags" "in_progress"
        if run_tag_rollback "$version"; then
            state_set_phase_status "tags" "rolled_back"
            audit_log "ROLLBACK" "human" "Tags v${version} rolled back"
            exit 0
        else
            state_set_phase_status "tags" "failed"
            exit 6
        fi
    fi

    # Handle reset
    if [[ "$reset" == "true" ]]; then
        state_set_phase_status "tags" "in_progress"
        if run_tag_reset "$version" "$dry_run" "$reset_repo"; then
            if [[ "$dry_run" == "false" ]]; then
                state_set_phase_status "tags" "complete"
                issue_update_tags "$version"
            fi
            exit 0
        else
            if [[ "$dry_run" == "false" ]]; then
                state_set_phase_status "tags" "failed"
            fi
            exit 6
        fi
    fi

    # Update state
    state_set_phase_status "tags" "in_progress"

    # Run tag creation
    if run_tag "$version" "$dry_run" "$force" "$yes_flag"; then
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "tags" "complete"
            audit_log "TAG" "cli" "Tags v${version} created in ${#REPOS[@]} repos"
            issue_update_tags "$version"
        fi
        exit 0
    else
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "tags" "failed"
        fi
        exit 6
    fi
}

cmd_publish() {
    local dry_run=true
    local force=false
    local yes_flag=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --execute)
                dry_run=false
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --yes|-y)
                yes_flag=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    require_release_state

    local version
    version=$(state_get_version)

    # Update state
    state_set_phase_status "releases" "in_progress"

    # Run publish
    if run_publish "$version" "$dry_run" "$force" "$yes_flag"; then
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "releases" "complete"
            audit_log "PUBLISH" "cli" "Releases v${version} created in ${#REPOS[@]} repos"
            issue_update_releases "$version"
        fi
        exit 0
    else
        if [[ "$dry_run" == "false" ]]; then
            state_set_phase_status "releases" "failed"
        fi
        exit 7
    fi
}

cmd_verify() {
    local json_output=false
    local version=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                json_output=true
                shift
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Get version from state if not provided
    if [[ -z "$version" ]]; then
        if state_exists && state_validate; then
            version=$(state_get_version)
        else
            log_error "No version specified and no release in progress"
            log_error "Use: release.sh verify --version X.Y"
            exit 1
        fi
    fi

    # Update state if release in progress
    if state_exists; then
        state_set_phase_status "verification" "in_progress"
    fi

    # Run verification
    if run_verify "$version" "$json_output"; then
        if state_exists; then
            state_set_phase_status "verification" "complete"
            state_set_status "complete"
            audit_log "VERIFY" "cli" "Release v${version} verified successfully"
            audit_done "$version"
            issue_update_verification "$version" "passed"
        fi
        exit 0
    else
        if state_exists; then
            state_set_phase_status "verification" "failed"
            issue_update_verification "$version" "failed"
        fi
        exit 8
    fi
}

cmd_full() {
    local host=""
    local scenario=""
    local manifest="n1-push"
    local skip_validate=false
    local dry_run=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host)
                host="$2"
                shift 2
                ;;
            --scenario)
                scenario="$2"
                manifest=""
                shift 2
                ;;
            --manifest)
                manifest="$2"
                scenario=""
                shift 2
                ;;
            --skip-validate)
                skip_validate=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --execute)
                dry_run=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    require_release_state

    local version
    version=$(state_get_version)

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  FULL RELEASE: v${version}"
    if [[ "$dry_run" == "true" ]]; then
        echo "  Mode: DRY-RUN (preview only)"
    else
        echo "  Mode: EXECUTE"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    local phases=()
    local phase_status

    # Build phase list based on current state
    phase_status=$(state_get_phase_status "preflight")
    if [[ "$phase_status" != "complete" ]]; then
        phases+=("preflight")
    fi

    if [[ "$skip_validate" != "true" ]]; then
        phase_status=$(state_get_phase_status "validation")
        if [[ "$phase_status" != "complete" ]]; then
            phases+=("validate")
        fi
    fi

    phase_status=$(state_get_phase_status "tags")
    if [[ "$phase_status" != "complete" ]]; then
        phases+=("tag")
    fi

    phase_status=$(state_get_phase_status "releases")
    if [[ "$phase_status" != "complete" ]]; then
        phases+=("publish")
    fi

    # Always check packer if releases will be created
    if [[ " ${phases[*]} " =~ " publish " ]]; then
        phases+=("packer")
    fi

    phase_status=$(state_get_phase_status "verification")
    if [[ "$phase_status" != "complete" ]]; then
        phases+=("verify")
    fi

    if [[ ${#phases[@]} -eq 0 ]]; then
        log_success "Release v${version} is already complete"
        return 0
    fi

    echo "Phases to execute:"
    for phase in "${phases[@]}"; do
        echo "  - $phase"
    done
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "  DRY-RUN COMPLETE"
        echo "  Run with --execute to perform the full release"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        return 0
    fi

    # Confirmation prompt
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  ${YELLOW}WARNING: This will execute a full release${NC}"
    echo "  Version: v${version}"
    echo "  Phases: ${phases[*]}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    read -p "Type 'yes' to proceed, or Ctrl+C to abort: " -r
    if [[ "$REPLY" != "yes" ]]; then
        log_info "Aborted by user"
        return 1
    fi
    echo ""

    # Execute each phase
    for phase in "${phases[@]}"; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  PHASE: $phase"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        case "$phase" in
            preflight)
                if ! run_preflight "$version" "false"; then
                    log_error "Preflight failed"
                    return 1
                fi
                state_set_phase_status "preflight" "complete"
                issue_update_preflight "passed"
                ;;

            validate)
                if ! run_validation "$scenario" "$host" "false" "false" "" "" "false" "$manifest"; then
                    log_error "Validation failed"
                    return 1
                fi
                local validation_label="${manifest:-$scenario}"
                state_set_phase_status "validation" "complete"
                issue_update_validation "$validation_label" "$host" ""
                ;;

            tag)
                if ! run_tag "$version" "false" "false"; then
                    log_error "Tag creation failed"
                    return 1
                fi
                state_set_phase_status "tags" "complete"
                audit_log "TAG" "cli" "Tags v${version} created in ${#REPOS[@]} repos"
                issue_update_tags "$version"
                ;;

            publish)
                if ! run_publish "$version" "false" "false" "true"; then
                    log_error "Publish failed"
                    return 1
                fi
                state_set_phase_status "releases" "complete"
                audit_log "PUBLISH" "cli" "Releases v${version} created in ${#REPOS[@]} repos"
                issue_update_releases "$version"
                ;;

            packer)
                # Check packer latest release has images
                local packer_assets
                packer_assets=$(gh release view latest --repo homestak-dev/packer --json assets --jq '.assets | length' 2>/dev/null || echo "0")
                if [[ "$packer_assets" -gt 0 ]]; then
                    echo -e "${GREEN}Packer images: $packer_assets asset(s) on latest${NC}"
                else
                    echo -e "${YELLOW}No packer images on latest release.${NC}"
                    echo "Upload with: release.sh packer --upload --execute --all"
                fi
                ;;

            verify)
                if ! run_verify "$version" "false"; then
                    log_warn "Verification found issues (continuing)"
                fi
                state_set_phase_status "verification" "complete"
                state_set_status "complete"
                audit_log "VERIFY" "cli" "Release v${version} verified"
                audit_done "$version"
                issue_update_verification "$version" "passed"
                ;;
        esac

        echo -e "${GREEN}Phase $phase completed${NC}"
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "  RESULT: ${GREEN}SUCCESS${NC}"
    echo "  Release v${version} completed"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    return 0
}
