#!/usr/bin/env bash
#
# verify.sh - Post-release verification for release CLI
#
# Verifies all releases exist and packer assets are uploaded
#

# Expected packer assets (in 'latest' release)
# Note: Images live in 'latest' release; versioned releases are typically tag-only
EXPECTED_PACKER_ASSETS=(
    "debian-12-custom.qcow2"
    "debian-12-custom.qcow2.sha256"
    "debian-13-custom.qcow2"
    "debian-13-custom.qcow2.sha256"
    "debian-13-pve.qcow2"
    "debian-13-pve.qcow2.sha256"
)

# -----------------------------------------------------------------------------
# Tag Verification Functions
# -----------------------------------------------------------------------------

verify_tag_exists() {
    local repo="$1"
    local version="$2"

    # homestak-dev IS the workspace, not a subdirectory
    local repo_dir
    if [[ "$repo" == "homestak-dev" ]]; then
        repo_dir="${WORKSPACE_DIR}"
    else
        repo_dir="${WORKSPACE_DIR}/${repo}"
    fi

    # Check if tag exists on remote
    if git -C "$repo_dir" ls-remote --tags origin "refs/tags/v${version}" 2>/dev/null | grep -q "v${version}"; then
        echo "exists"
    else
        echo "missing"
    fi
}

verify_tags() {
    local version="$1"

    local missing=()
    local found=()

    for repo in "${REPOS[@]}"; do
        local repo_dir
        # homestak-dev IS the workspace, not a subdirectory
        if [[ "$repo" == "homestak-dev" ]]; then
            repo_dir="${WORKSPACE_DIR}"
        else
            repo_dir="${WORKSPACE_DIR}/${repo}"
        fi

        # Check if repo exists locally
        if [[ ! -d "$repo_dir" ]]; then
            missing+=("$repo (not cloned)")
            continue
        fi

        local status
        status=$(verify_tag_exists "$repo" "$version")

        if [[ "$status" == "exists" ]]; then
            found+=("$repo")
        else
            missing+=("$repo")
        fi
    done

    # Return found:missing counts and missing list
    echo "${#found[@]}:${#missing[@]}:${missing[*]}"
}

# -----------------------------------------------------------------------------
# Release Verification Functions
# -----------------------------------------------------------------------------

verify_release_exists() {
    local repo="$1"
    local version="$2"

    local release_info
    release_info=$(gh release view "v${version}" --repo "homestak-dev/${repo}" --json tagName,isDraft 2>/dev/null)

    if [[ -z "$release_info" ]]; then
        echo "missing"
    elif echo "$release_info" | grep -q '"isDraft":true'; then
        echo "draft"
    else
        echo "exists"
    fi
}

verify_packer_assets() {
    local version="$1"

    # Check 'latest' release for packer assets (latest-centric approach)
    # Versioned releases are typically tag-only; images live in 'latest'
    local assets
    assets=$(gh release view "latest" --repo "homestak-dev/packer" --json assets --jq '.assets[].name' 2>/dev/null)

    local found=()
    local found_split=()
    local missing=()

    for expected in "${EXPECTED_PACKER_ASSETS[@]}"; do
        # Check for exact match
        if echo "$assets" | grep -q "^${expected}$"; then
            found+=("$expected")
        # Check for split files pattern (e.g., file.qcow2.partaa, file.qcow2.partab)
        elif echo "$assets" | grep -q "^${expected}\.part"; then
            found+=("$expected")
            found_split+=("$expected")
        else
            missing+=("$expected")
        fi
    done

    # Return found:missing:split counts
    echo "${#found[@]}:${#missing[@]}:${#found_split[@]}"
}

# -----------------------------------------------------------------------------
# Main Verification Runner
# -----------------------------------------------------------------------------

run_verify() {
    local version="$1"
    local json_output="${2:-false}"

    local all_passed=true
    local release_results=()

    # Check tags exist
    local tag_check
    tag_check=$(verify_tags "$version")
    local tag_found="${tag_check%%:*}"
    local tag_rest="${tag_check#*:}"
    local tag_missing_count="${tag_rest%%:*}"
    local tag_missing_list="${tag_rest#*:}"

    if [[ "$tag_missing_count" -gt 0 ]]; then
        all_passed=false
    fi

    # Check releases exist and are not drafts
    local has_drafts=false
    for repo in "${REPOS[@]}"; do
        local status
        status=$(verify_release_exists "$repo" "$version")
        release_results+=("$repo:$status")
        if [[ "$status" == "draft" ]]; then
            has_drafts=true
            all_passed=false
        elif [[ "$status" != "exists" ]]; then
            all_passed=false
        fi
    done

    # Check packer assets
    local asset_check
    asset_check=$(verify_packer_assets "$version")
    local found_count="${asset_check%%:*}"
    local rest="${asset_check#*:}"
    local missing_count="${rest%%:*}"
    local split_count="${rest##*:}"

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
  "tags": {
    "found": ${tag_found},
    "expected": ${#REPOS[@]},
    "missing": "${tag_missing_list}"
  },
  "releases": ${repos_json},
  "packer_assets": {
    "found": ${found_count},
    "expected": ${#EXPECTED_PACKER_ASSETS[@]},
    "split": ${split_count}
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

        # Show tag inventory
        echo "Git Tags:"
        if [[ "$tag_missing_count" -eq 0 ]]; then
            echo -e "  ${GREEN}✓${NC} All ${#REPOS[@]} repos have tag v${version}"
        else
            echo -e "  ${YELLOW}⚠${NC} ${tag_found}/${#REPOS[@]} repos have tag v${version}"
            echo "  Missing: ${tag_missing_list}"
        fi
        echo ""

        echo "GitHub Releases:"
        for result in "${release_results[@]}"; do
            local repo="${result%%:*}"
            local status="${result##*:}"

            local icon
            if [[ "$status" == "exists" ]]; then
                icon="${GREEN}✓${NC}"
            elif [[ "$status" == "draft" ]]; then
                icon="${YELLOW}⚠${NC}"
            else
                icon="${RED}✗${NC}"
            fi
            printf "  %b %-15s %s\\n" "$icon" "$repo" "$status"
        done

        echo ""
        echo "Packer Assets (from 'latest' release):"
        local assets
        assets=$(gh release view "latest" --repo "homestak-dev/packer" --json assets --jq '.assets[].name' 2>/dev/null)

        if [[ "$found_count" -eq "${#EXPECTED_PACKER_ASSETS[@]}" ]]; then
            if [[ "$split_count" -gt 0 ]]; then
                echo -e "  ${GREEN}✓${NC} All ${#EXPECTED_PACKER_ASSETS[@]} expected assets found in 'latest' (${split_count} split)"
            else
                echo -e "  ${GREEN}✓${NC} All ${#EXPECTED_PACKER_ASSETS[@]} expected assets found in 'latest'"
            fi
            # Show details for each asset
            for expected in "${EXPECTED_PACKER_ASSETS[@]}"; do
                if echo "$assets" | grep -q "^${expected}$"; then
                    echo -e "    ${GREEN}✓${NC} $expected"
                elif echo "$assets" | grep -q "^${expected}\.part"; then
                    local parts
                    parts=$(echo "$assets" | grep -c "^${expected}\.part")
                    echo -e "    ${GREEN}✓${NC} $expected (${parts} parts)"
                fi
            done
        else
            echo -e "  ${YELLOW}⚠${NC} Found ${found_count}/${#EXPECTED_PACKER_ASSETS[@]} expected assets in 'latest'"
            # Show status for each expected asset
            for expected in "${EXPECTED_PACKER_ASSETS[@]}"; do
                if echo "$assets" | grep -q "^${expected}$"; then
                    echo -e "    ${GREEN}✓${NC} $expected"
                elif echo "$assets" | grep -q "^${expected}\.part"; then
                    local parts
                    parts=$(echo "$assets" | grep -c "^${expected}\.part")
                    echo -e "    ${GREEN}✓${NC} $expected (${parts} parts)"
                else
                    echo -e "    ${RED}✗${NC} Missing: $expected"
                fi
            done
        fi

        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        if [[ "$all_passed" == "true" ]]; then
            echo -e "  RESULT: ${GREEN}PASS${NC}"
            echo "  All ${#REPOS[@]} tags, ${#REPOS[@]} releases present"
            echo "  Packer: ${#EXPECTED_PACKER_ASSETS[@]} assets in 'latest' release"
        else
            echo -e "  RESULT: ${RED}FAIL${NC}"
            if [[ "$tag_missing_count" -gt 0 ]]; then
                echo "  Missing tags: ${tag_missing_list}"
            fi
            if [[ "$has_drafts" == "true" ]]; then
                echo "  Some releases are still drafts (run: release.sh publish --finalize)"
            elif [[ "$tag_missing_count" -eq 0 ]]; then
                echo "  Some releases or assets are missing"
            fi
        fi
        echo "═══════════════════════════════════════════════════════════════"
        echo ""

        # Generate markdown summary for release issue
        echo "Release Issue Summary (copy/paste):"
        echo "---"
        echo "### Verification Results"
        echo ""
        echo "**Git Tags:** ${tag_found}/${#REPOS[@]} present"
        if [[ "$tag_missing_count" -gt 0 ]]; then
            echo "Missing: ${tag_missing_list}"
        fi
        echo ""
        echo "| Repo | Release |"
        echo "|------|---------|"
        for result in "${release_results[@]}"; do
            local repo="${result%%:*}"
            local status="${result##*:}"
            local icon="✅"
            if [[ "$status" == "draft" ]]; then
                icon="⚠️ draft"
            elif [[ "$status" != "exists" ]]; then
                icon="❌"
            fi
            echo "| ${repo} | ${icon} |"
        done
        echo ""
        echo "**Packer Assets (in 'latest'):** ${found_count}/${#EXPECTED_PACKER_ASSETS[@]} present"
        echo "---"
        echo ""

        # Reminder about release issue lifecycle
        echo -e "${YELLOW}Note:${NC} Release issue should remain open until Phase 10 (Retrospective) is complete."
        echo "      Phases remaining after verify: AAR → Housekeeping → Retrospective → Close"
        echo ""
    fi

    if [[ "$all_passed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}
