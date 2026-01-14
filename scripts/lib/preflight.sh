#!/usr/bin/env bash
#
# preflight.sh - Pre-flight checks for release CLI
#
# Checks:
# 1. All repos have clean working trees
# 2. No existing tags for target version
# 3. CHANGELOG.md exists in each repo
# 4. gh CLI is authenticated
# 5. Site-config secrets are decrypted
# 6. Provider cache matches lockfile version
#

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------

preflight_check_repo_clean() {
    local repo="$1"
    local repo_path

    # homestak-dev is the workspace itself, not a sibling
    if [[ "$repo" == "homestak-dev" ]]; then
        repo_path="${WORKSPACE_DIR}"
    else
        repo_path="${WORKSPACE_DIR}/${repo}"
    fi

    if [[ ! -d "$repo_path" ]]; then
        echo "missing"
        return
    fi

    local status
    status=$(git -C "$repo_path" status --porcelain 2>/dev/null)

    if [[ -z "$status" ]]; then
        echo "clean"
    else
        echo "dirty"
    fi
}

preflight_check_tag_exists() {
    local repo="$1"
    local version="$2"
    local repo_path

    # homestak-dev is the workspace itself, not a sibling
    if [[ "$repo" == "homestak-dev" ]]; then
        repo_path="${WORKSPACE_DIR}"
    else
        repo_path="${WORKSPACE_DIR}/${repo}"
    fi

    if [[ ! -d "$repo_path" ]]; then
        echo "missing"
        return
    fi

    # Check both local and remote tags
    if git -C "$repo_path" tag -l "v${version}" | grep -q "v${version}"; then
        echo "exists"
    elif git -C "$repo_path" ls-remote --tags origin "v${version}" 2>/dev/null | grep -q "v${version}"; then
        echo "exists"
    else
        echo "none"
    fi
}

preflight_check_changelog() {
    local repo="$1"
    local repo_path

    # homestak-dev is the workspace itself, not a sibling
    if [[ "$repo" == "homestak-dev" ]]; then
        repo_path="${WORKSPACE_DIR}"
    else
        repo_path="${WORKSPACE_DIR}/${repo}"
    fi

    if [[ ! -d "$repo_path" ]]; then
        echo "missing"
        return
    fi

    local changelog="${repo_path}/CHANGELOG.md"

    if [[ ! -f "$changelog" ]]; then
        echo "missing"
    elif grep -q "## \[Unreleased\]" "$changelog" 2>/dev/null; then
        echo "has_unreleased"
    elif grep -q "## Unreleased" "$changelog" 2>/dev/null; then
        echo "has_unreleased"
    else
        echo "no_unreleased"
    fi
}

preflight_check_gh_auth() {
    if gh auth status &>/dev/null; then
        local user
        user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
        echo "$user"
    else
        echo "not_authenticated"
    fi
}

preflight_check_secrets() {
    local secrets_file="${WORKSPACE_DIR}/site-config/secrets.yaml"

    if [[ ! -f "$secrets_file" ]]; then
        echo "missing"
    else
        echo "decrypted"
    fi
}

preflight_check_provider_cache() {
    # Check for stale provider caches in iac-driver/.states/
    local states_dir="${WORKSPACE_DIR}/iac-driver/.states"
    local lockfile="${WORKSPACE_DIR}/tofu/envs/generic/.terraform.lock.hcl"

    # If no states directory, no cache to check
    if [[ ! -d "$states_dir" ]]; then
        echo "no_cache"
        return
    fi

    # Get lockfile version
    local lockfile_version=""
    if [[ -f "$lockfile" ]]; then
        lockfile_version=$(grep -A1 'provider "registry.opentofu.org/bpg/proxmox"' "$lockfile" 2>/dev/null | grep 'version' | sed 's/.*= "\([^"]*\)".*/\1/')
    fi

    if [[ -z "$lockfile_version" ]]; then
        echo "no_lockfile"
        return
    fi

    # Find all cached provider versions
    local stale_caches=()
    local provider_base="registry.opentofu.org/bpg/proxmox"

    for state_dir in "$states_dir"/*/; do
        [[ -d "$state_dir" ]] || continue
        local state_name=$(basename "$state_dir")
        local provider_path="${state_dir}data/providers/${provider_base}"

        if [[ -d "$provider_path" ]]; then
            for version_dir in "$provider_path"/*/; do
                [[ -d "$version_dir" ]] || continue
                local cached_version=$(basename "$version_dir")
                if [[ "$cached_version" != "$lockfile_version" ]]; then
                    stale_caches+=("${state_name}:${cached_version}")
                fi
            done
        fi
    done

    if [[ ${#stale_caches[@]} -gt 0 ]]; then
        # Return stale cache info: "stale|lockfile_ver|state1:ver1,state2:ver2"
        local stale_list
        stale_list=$(IFS=','; echo "${stale_caches[*]}")
        echo "stale|${lockfile_version}|${stale_list}"
    else
        echo "ok|${lockfile_version}"
    fi
}

preflight_clear_provider_cache() {
    # Clear all provider caches in iac-driver/.states/
    local states_dir="${WORKSPACE_DIR}/iac-driver/.states"

    if [[ ! -d "$states_dir" ]]; then
        return 0
    fi

    local cleared=0
    for state_dir in "$states_dir"/*/; do
        [[ -d "$state_dir" ]] || continue
        local data_dir="${state_dir}data"
        if [[ -d "$data_dir" ]]; then
            rm -rf "$data_dir"
            ((cleared++))
        fi
    done

    echo "$cleared"
}

# -----------------------------------------------------------------------------
# Main Pre-flight Runner
# -----------------------------------------------------------------------------

run_preflight() {
    local version="$1"
    local json_output="${2:-false}"

    local all_passed=true
    local repo_results=()
    local tag_results=()
    local changelog_results=()

    # Check gh authentication first
    local gh_user
    gh_user=$(preflight_check_gh_auth)

    if [[ "$gh_user" == "not_authenticated" ]]; then
        if [[ "$json_output" != "true" ]]; then
            log_error "GitHub CLI not authenticated"
            log_error "Run: gh auth login"
        fi
        all_passed=false
    fi

    # Check secrets decryption
    local secrets_status
    secrets_status=$(preflight_check_secrets)

    if [[ "$secrets_status" == "missing" ]]; then
        if [[ "$json_output" != "true" ]]; then
            log_error "Site-config secrets not decrypted"
            log_error "Run: cd site-config && make decrypt"
        fi
        all_passed=false
    fi

    # Check provider cache
    local cache_status
    cache_status=$(preflight_check_provider_cache)

    # Check each repo
    for repo in "${REPOS[@]}"; do
        local repo_status tag_status changelog_status

        repo_status=$(preflight_check_repo_clean "$repo")
        tag_status=$(preflight_check_tag_exists "$repo" "$version")
        changelog_status=$(preflight_check_changelog "$repo")

        repo_results+=("$repo:$repo_status")
        tag_results+=("$repo:$tag_status")
        changelog_results+=("$repo:$changelog_status")

        # Track failures
        if [[ "$repo_status" != "clean" ]]; then
            all_passed=false
        fi
        if [[ "$tag_status" == "exists" ]]; then
            all_passed=false
        fi
        # Missing changelog is a warning, not a failure
    done

    # Output results
    if [[ "$json_output" == "true" ]]; then
        # JSON output
        local repos_json="{"
        local first=true
        for i in "${!REPOS[@]}"; do
            local repo="${REPOS[$i]}"
            local rs="${repo_results[$i]#*:}"
            local ts="${tag_results[$i]#*:}"
            local cs="${changelog_results[$i]#*:}"

            if [[ "$first" == "true" ]]; then
                first=false
            else
                repos_json+=","
            fi
            repos_json+="\"${repo}\":{\"working_tree\":\"${rs}\",\"tag\":\"${ts}\",\"changelog\":\"${cs}\"}"
        done
        repos_json+="}"

        # Parse cache status for JSON
        local cache_json_status="${cache_status%%|*}"
        local cache_json_lockfile=""
        local cache_json_stale="[]"
        if [[ "$cache_json_status" == "ok" ]]; then
            cache_json_lockfile="${cache_status#ok|}"
        elif [[ "$cache_json_status" == "stale" ]]; then
            local cache_info="${cache_status#stale|}"
            cache_json_lockfile="${cache_info%%|*}"
            local stale_list="${cache_info#*|}"
            cache_json_stale="["
            local stale_first=true
            IFS=',' read -ra stale_entries <<< "$stale_list"
            for entry in "${stale_entries[@]}"; do
                local state_name="${entry%%:*}"
                local cached_ver="${entry#*:}"
                if [[ "$stale_first" == "true" ]]; then
                    stale_first=false
                else
                    cache_json_stale+=","
                fi
                cache_json_stale+="{\"state\":\"${state_name}\",\"version\":\"${cached_ver}\"}"
            done
            cache_json_stale+="]"
        fi

        cat << EOF
{
  "version": "${version}",
  "passed": ${all_passed},
  "gh_user": "${gh_user}",
  "secrets": "${secrets_status}",
  "provider_cache": {
    "status": "${cache_json_status}",
    "lockfile_version": "${cache_json_lockfile}",
    "stale": ${cache_json_stale}
  },
  "repos": ${repos_json}
}
EOF
    else
        # Human-readable output
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  PREFLIGHT CHECK: v${version}"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        echo "Repository Status:"
        for i in "${!REPOS[@]}"; do
            local repo="${REPOS[$i]}"
            local rs="${repo_results[$i]#*:}"
            local ts="${tag_results[$i]#*:}"

            local icon status_text
            if [[ "$rs" == "clean" && "$ts" == "none" ]]; then
                icon="${GREEN}✓${NC}"
                status_text="clean, no v${version} tag"
            elif [[ "$rs" == "missing" ]]; then
                icon="${RED}✗${NC}"
                status_text="repo not found"
            elif [[ "$rs" == "dirty" ]]; then
                icon="${RED}✗${NC}"
                status_text="uncommitted changes"
            elif [[ "$ts" == "exists" ]]; then
                icon="${RED}✗${NC}"
                status_text="v${version} tag already exists"
            else
                icon="${YELLOW}?${NC}"
                status_text="unknown"
            fi

            printf "  %b %-15s %s\n" "$icon" "$repo" "$status_text"
        done

        echo ""
        echo "CHANGELOG Status:"
        for i in "${!REPOS[@]}"; do
            local repo="${REPOS[$i]}"
            local cs="${changelog_results[$i]#*:}"

            local icon status_text
            case "$cs" in
                has_unreleased)
                    icon="${GREEN}✓${NC}"
                    status_text="Has Unreleased section"
                    ;;
                no_unreleased)
                    icon="${YELLOW}⚠${NC}"
                    status_text="No Unreleased section"
                    ;;
                missing)
                    icon="${YELLOW}⚠${NC}"
                    status_text="CHANGELOG.md not found"
                    ;;
                *)
                    icon="${YELLOW}?${NC}"
                    status_text="unknown"
                    ;;
            esac

            printf "  %b %-15s %s\n" "$icon" "$repo" "$status_text"
        done

        echo ""
        echo "Authentication:"
        if [[ "$gh_user" != "not_authenticated" ]]; then
            echo -e "  ${GREEN}✓${NC} gh CLI authenticated as ${gh_user}"
        else
            echo -e "  ${RED}✗${NC} gh CLI not authenticated"
        fi

        echo ""
        echo "Secrets:"
        if [[ "$secrets_status" == "decrypted" ]]; then
            echo -e "  ${GREEN}✓${NC} site-config/secrets.yaml present"
        else
            echo -e "  ${RED}✗${NC} site-config/secrets.yaml missing (run: cd site-config && make decrypt)"
        fi

        echo ""
        echo "Provider Cache:"
        case "${cache_status%%|*}" in
            no_cache)
                echo -e "  ${GREEN}✓${NC} No cached providers"
                ;;
            no_lockfile)
                echo -e "  ${YELLOW}⚠${NC} No lockfile found (run: cd tofu/envs/generic && tofu init)"
                ;;
            ok)
                local lockfile_ver="${cache_status#ok|}"
                echo -e "  ${GREEN}✓${NC} Provider cache matches lockfile (v${lockfile_ver})"
                ;;
            stale)
                local cache_info="${cache_status#stale|}"
                local lockfile_ver="${cache_info%%|*}"
                local stale_list="${cache_info#*|}"
                echo -e "  ${YELLOW}⚠${NC} Stale provider caches detected (lockfile: v${lockfile_ver})"
                IFS=',' read -ra stale_entries <<< "$stale_list"
                for entry in "${stale_entries[@]}"; do
                    local state_name="${entry%%:*}"
                    local cached_ver="${entry#*:}"
                    echo -e "      - ${state_name}: cached v${cached_ver}"
                done
                echo -e "      Run: rm -rf iac-driver/.states/*/data to clear"
                ;;
        esac

        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        if [[ "$all_passed" == "true" ]]; then
            echo -e "  RESULT: ${GREEN}PASS${NC} (${#REPOS[@]}/${#REPOS[@]} repos ready)"
        else
            echo -e "  RESULT: ${RED}FAIL${NC} (resolve issues above)"
        fi
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
    fi

    if [[ "$all_passed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}
