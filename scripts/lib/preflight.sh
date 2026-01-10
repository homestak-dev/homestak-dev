#!/usr/bin/env bash
#
# preflight.sh - Pre-flight checks for release CLI
#
# Checks:
# 1. All repos have clean working trees
# 2. No existing tags for target version
# 3. CHANGELOG.md exists in each repo
# 4. gh CLI is authenticated
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

        cat << EOF
{
  "version": "${version}",
  "passed": ${all_passed},
  "gh_user": "${gh_user}",
  "secrets": "${secrets_status}",
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
