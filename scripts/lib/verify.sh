#!/usr/bin/env bash
#
# verify.sh - Post-release verification for release CLI
#
# Verifies all releases exist and packer assets are uploaded
#

# Expected packer assets
EXPECTED_PACKER_ASSETS=(
    "debian-12-custom.qcow2"
    "debian-13-custom.qcow2"
    "debian-13-pve.qcow2"
)

# -----------------------------------------------------------------------------
# Verification Functions
# -----------------------------------------------------------------------------

verify_release_exists() {
    local repo="$1"
    local version="$2"

    local release_info
    release_info=$(gh release view "v${version}" --repo "homestak-dev/${repo}" --json tagName,createdAt 2>/dev/null)

    if [[ -n "$release_info" ]]; then
        echo "exists"
    else
        echo "missing"
    fi
}

verify_packer_assets() {
    local version="$1"

    local assets
    assets=$(gh release view "v${version}" --repo "homestak-dev/packer" --json assets --jq '.assets[].name' 2>/dev/null)

    local found=()
    local missing=()

    for expected in "${EXPECTED_PACKER_ASSETS[@]}"; do
        if echo "$assets" | grep -q "^${expected}$"; then
            found+=("$expected")
        else
            missing+=("$expected")
        fi
    done

    echo "${#found[@]}:${#missing[@]}"
}

# -----------------------------------------------------------------------------
# Main Verification Runner
# -----------------------------------------------------------------------------

run_verify() {
    local version="$1"
    local json_output="${2:-false}"

    local all_passed=true
    local release_results=()
    local asset_results=()

    # Check releases exist
    for repo in "${REPOS[@]}"; do
        local status
        status=$(verify_release_exists "$repo" "$version")
        release_results+=("$repo:$status")
        if [[ "$status" != "exists" ]]; then
            all_passed=false
        fi
    done

    # Check packer assets
    local asset_check
    asset_check=$(verify_packer_assets "$version")
    local found_count="${asset_check%%:*}"
    local missing_count="${asset_check##*:}"

    if [[ "$missing_count" -gt 0 ]]; then
        all_passed=false
    fi

    # Output results
    if [[ "$json_output" == "true" ]]; then
        # JSON output
        local repos_json="{"
        local first=true
        for result in "${release_results[@]}"; do
            local repo="${result%%:*}"
            local status="${result##*:}"
            if [[ "$first" == "true" ]]; then
                first=false
            else
                repos_json+=","
            fi
            repos_json+="\"${repo}\":\"${status}\""
        done
        repos_json+="}"

        cat << EOF
{
  "version": "${version}",
  "passed": ${all_passed},
  "releases": ${repos_json},
  "packer_assets": {
    "found": ${found_count},
    "expected": ${#EXPECTED_PACKER_ASSETS[@]}
  }
}
EOF
    else
        # Human-readable output
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  VERIFICATION: v${version}"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        echo "GitHub Releases:"
        for result in "${release_results[@]}"; do
            local repo="${result%%:*}"
            local status="${result##*:}"

            local icon
            if [[ "$status" == "exists" ]]; then
                icon="${GREEN}✓${NC}"
            else
                icon="${RED}✗${NC}"
            fi
            printf "  %b %-15s %s\\n" "$icon" "$repo" "$status"
        done

        echo ""
        echo "Packer Assets:"
        if [[ "$found_count" -eq "${#EXPECTED_PACKER_ASSETS[@]}" ]]; then
            echo -e "  ${GREEN}✓${NC} All ${#EXPECTED_PACKER_ASSETS[@]} expected assets found"
        else
            echo -e "  ${YELLOW}⚠${NC} Found ${found_count}/${#EXPECTED_PACKER_ASSETS[@]} expected assets"
            # List what's missing
            local assets
            assets=$(gh release view "v${version}" --repo "homestak-dev/packer" --json assets --jq '.assets[].name' 2>/dev/null)
            for expected in "${EXPECTED_PACKER_ASSETS[@]}"; do
                if ! echo "$assets" | grep -q "^${expected}$"; then
                    echo -e "    ${RED}✗${NC} Missing: $expected"
                fi
            done
        fi

        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        if [[ "$all_passed" == "true" ]]; then
            echo -e "  RESULT: ${GREEN}PASS${NC}"
            echo "  All ${#REPOS[@]} releases exist, ${#EXPECTED_PACKER_ASSETS[@]} packer assets present"
        else
            echo -e "  RESULT: ${RED}FAIL${NC}"
            echo "  Some releases or assets are missing"
        fi
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        # Generate markdown summary for release issue
        echo "Release Issue Summary (copy/paste):"
        echo "---"
        echo "### Verification Results"
        echo ""
        echo "| Repo | Release |"
        echo "|------|---------|"
        for result in "${release_results[@]}"; do
            local repo="${result%%:*}"
            local status="${result##*:}"
            local icon="✅"
            [[ "$status" != "exists" ]] && icon="❌"
            echo "| ${repo} | ${icon} |"
        done
        echo ""
        echo "**Packer Assets:** ${found_count}/${#EXPECTED_PACKER_ASSETS[@]} present"
        echo "---"
        echo ""
    fi

    if [[ "$all_passed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}
