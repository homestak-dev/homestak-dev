#!/usr/bin/env bash
#
# changelog.sh - CHANGELOG stamping for release CLI
#
# Stamps version headers in CHANGELOGs across all repos.
# Does NOT author content — only inserts ## vX.Y - YYYY-MM-DD
# between ## Unreleased and existing entries.
#

# Stamp a single repo's CHANGELOG with version header.
# If Unreleased section is empty, inserts "No changes."
#
# Usage: changelog_stamp_file <changelog_path> <version> <date>
# Returns: 0 on success, 1 on error
# Output: the stamped content on stdout (dry-run) or writes in-place (execute)
changelog_stamp_file() {
    local file="$1"
    local version="$2"
    local date="$3"

    if [[ ! -f "$file" ]]; then
        log_error "CHANGELOG not found: $file"
        return 1
    fi

    # Check for ## Unreleased header
    if ! grep -q '^## Unreleased' "$file"; then
        log_error "No '## Unreleased' header found in: $file"
        return 1
    fi

    # Extract content between ## Unreleased and the next ## heading (or EOF)
    local unreleased_content
    unreleased_content=$(awk '
        /^## Unreleased/ { found=1; next }
        found && /^## / { exit }
        found { print }
    ' "$file")

    # Check if there is meaningful content (non-blank lines)
    local has_content=false
    if echo "$unreleased_content" | grep -q '[^[:space:]]'; then
        has_content=true
    fi

    # Build the stamped file
    local version_header="## v${version} - ${date}"

    if [[ "$has_content" == "true" ]]; then
        # Replace: keep ## Unreleased, add blank line, version header, then existing content
        awk -v header="$version_header" '
            /^## Unreleased/ {
                print
                print ""
                print header
                next
            }
            { print }
        ' "$file"
    else
        # Empty unreleased: insert version header with "No changes."
        awk -v header="$version_header" '
            /^## Unreleased/ {
                print
                print ""
                print header
                print ""
                print "No changes."
                # Skip blank lines between Unreleased and next heading
                next
            }
            # Skip blank lines that were between ## Unreleased and next ## heading
            BEGIN { skip_blanks=0 }
            /^## Unreleased/ { skip_blanks=1 }
            skip_blanks && /^[[:space:]]*$/ { next }
            skip_blanks && /^## / { skip_blanks=0; print; next }
            skip_blanks && /[^[:space:]]/ { skip_blanks=0; print; next }
            { print }
        ' "$file"
    fi
}

# Preview CHANGELOG stamp for a single repo (dry-run output)
#
# Usage: changelog_preview_single <repo> <version> <date>
changelog_preview_single() {
    local repo="$1"
    local version="$2"
    local date="$3"

    local repo_path
    repo_path="${WORKSPACE_DIR}/$(repo_dir "$repo")"
    local changelog="${repo_path}/CHANGELOG.md"

    if [[ ! -d "$repo_path" ]]; then
        echo -e "  ${YELLOW}⚠${NC} ${repo}: directory not found (skipping)"
        return 0
    fi

    if [[ ! -f "$changelog" ]]; then
        echo -e "  ${YELLOW}⚠${NC} ${repo}: no CHANGELOG.md (skipping)"
        return 0
    fi

    if ! grep -q '^## Unreleased' "$changelog"; then
        echo -e "  ${RED}✗${NC} ${repo}: no '## Unreleased' header"
        return 1
    fi

    # Check for content under Unreleased
    local unreleased_content
    unreleased_content=$(awk '
        /^## Unreleased/ { found=1; next }
        found && /^## / { exit }
        found { print }
    ' "$changelog")

    local has_content=false
    if echo "$unreleased_content" | grep -q '[^[:space:]]'; then
        has_content=true
    fi

    if [[ "$has_content" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} ${repo}: has unreleased content → stamp v${version}"
        # Show what content will be stamped
        echo "$unreleased_content" | head -10 | sed 's/^/      /'
        local total_lines
        total_lines=$(echo "$unreleased_content" | grep -c '[^[:space:]]' || true)
        if [[ "$total_lines" -gt 10 ]]; then
            echo "      ... ($total_lines lines total)"
        fi
    else
        echo -e "  ${BLUE}○${NC} ${repo}: empty → stamp v${version} with 'No changes.'"
    fi
}

# Execute CHANGELOG stamp for a single repo: branch, stamp, commit, push, PR, approve, merge, cleanup
#
# Usage: changelog_execute_single <repo> <version> <date> <yes_flag>
# Returns: 0 on success, 1 on error
changelog_execute_single() {
    local repo="$1"
    local version="$2"
    local date="$3"
    local yes_flag="$4"

    local repo_path
    repo_path="${WORKSPACE_DIR}/$(repo_dir "$repo")"
    local changelog="${repo_path}/CHANGELOG.md"
    local branch="release/v${version}-changelog"
    local full_name
    full_name=$(repo_full_name "$repo")

    if [[ ! -d "$repo_path" ]]; then
        log_warn "${repo}: directory not found (skipping)"
        return 0
    fi

    if [[ ! -f "$changelog" ]]; then
        log_warn "${repo}: no CHANGELOG.md (skipping)"
        return 0
    fi

    log_info "${repo}: stamping CHANGELOG..."

    # 1. Ensure on master and up to date
    if ! git -C "$repo_path" checkout master &>/dev/null; then
        log_error "${repo}: failed to checkout master"
        return 1
    fi
    git -C "$repo_path" pull --ff-only origin master &>/dev/null || true

    # 2. Create branch
    if ! git -C "$repo_path" checkout -b "$branch" &>/dev/null 2>&1; then
        # Branch may already exist from a failed attempt — reset it
        git -C "$repo_path" checkout "$branch" &>/dev/null
        git -C "$repo_path" reset --hard origin/master &>/dev/null
    fi

    # 3. Stamp CHANGELOG
    local stamped_content
    stamped_content=$(changelog_stamp_file "$changelog" "$version" "$date")
    if [[ $? -ne 0 || -z "$stamped_content" ]]; then
        log_error "${repo}: failed to stamp CHANGELOG"
        git -C "$repo_path" checkout master &>/dev/null
        git -C "$repo_path" branch -D "$branch" &>/dev/null 2>&1 || true
        return 1
    fi

    echo "$stamped_content" > "$changelog"

    # 4. Commit
    git -C "$repo_path" add CHANGELOG.md
    if ! git -C "$repo_path" diff --cached --quiet; then
        git -C "$repo_path" commit -m "docs: Stamp CHANGELOG for v${version}" &>/dev/null
    else
        log_warn "${repo}: no changes to commit (already stamped?)"
        git -C "$repo_path" checkout master &>/dev/null
        git -C "$repo_path" branch -D "$branch" &>/dev/null 2>&1 || true
        return 0
    fi

    # 5. Push
    if ! git -C "$repo_path" push -u origin "$branch" &>/dev/null 2>&1; then
        log_error "${repo}: failed to push branch"
        git -C "$repo_path" checkout master &>/dev/null
        return 1
    fi

    # 6. Create PR (as bot)
    local pr_url
    pr_url=$(GH_TOKEN="${HOMESTAK_BOT_TOKEN:-}" gh pr create \
        --repo "$full_name" \
        --head "$branch" \
        --title "docs: Stamp CHANGELOG for v${version}" \
        --body "CHANGELOG version header stamp for v${version} release.

This PR contains only a CHANGELOG header update — no code changes.

Part of release v${version}." 2>/dev/null)

    if [[ -z "$pr_url" ]]; then
        log_error "${repo}: failed to create PR"
        git -C "$repo_path" checkout master &>/dev/null
        return 1
    fi

    local pr_number
    pr_number=$(echo "$pr_url" | grep -o '[0-9]*$')
    log_info "${repo}: PR #${pr_number} created"

    # 7. Approve PR (as operator, not bot)
    if ! gh pr review "$pr_number" --repo "$full_name" --approve &>/dev/null 2>&1; then
        log_warn "${repo}: auto-approve failed (may need manual approval)"
    fi

    # 8. Enable auto-merge (squash)
    if ! gh pr merge "$pr_number" --repo "$full_name" --auto --squash &>/dev/null 2>&1; then
        log_warn "${repo}: auto-merge failed, attempting direct merge"
        # Try direct squash merge
        if ! gh pr merge "$pr_number" --repo "$full_name" --squash &>/dev/null 2>&1; then
            log_warn "${repo}: PR #${pr_number} needs manual merge"
            git -C "$repo_path" checkout master &>/dev/null
            return 0
        fi
    fi

    # 9. Wait briefly for merge to complete, then sync master
    local attempts=0
    local max_attempts=30
    while [[ $attempts -lt $max_attempts ]]; do
        local pr_state
        pr_state=$(gh pr view "$pr_number" --repo "$full_name" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
        if [[ "$pr_state" == "MERGED" ]]; then
            break
        fi
        sleep 2
        ((attempts++))
    done

    # 10. Sync local master
    git -C "$repo_path" checkout master &>/dev/null
    git -C "$repo_path" fetch origin master &>/dev/null
    git -C "$repo_path" reset --hard origin/master &>/dev/null

    # 11. Clean up local branch
    git -C "$repo_path" branch -D "$branch" &>/dev/null 2>&1 || true

    log_success "${repo}: CHANGELOG stamped and merged"
    audit_log "CHANGELOG" "cli" "${repo}: v${version} CHANGELOG stamped (PR #${pr_number})"

    return 0
}

# Main runner: stamp CHANGELOGs across all repos
#
# Usage: run_changelog <version> <dry_run> <yes_flag>
run_changelog() {
    local version="$1"
    local dry_run="${2:-true}"
    local yes_flag="${3:-false}"
    local date
    date=$(date +%Y-%m-%d)

    echo ""
    echo "CHANGELOG Stamp: v${version} (${date})"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        echo "Preview (no changes will be made):"
        echo ""

        local errors=0
        for repo in "${REPOS[@]}"; do
            if ! changelog_preview_single "$repo" "$version" "$date"; then
                ((errors++))
            fi
        done

        echo ""
        if [[ $errors -gt 0 ]]; then
            log_warn "$errors repo(s) had issues"
            return 1
        fi
        return 0
    fi

    # Execute mode

    # Check bot token
    if [[ -z "${HOMESTAK_BOT_TOKEN:-}" ]]; then
        log_error "HOMESTAK_BOT_TOKEN is not set"
        log_error "Export it before running: export HOMESTAK_BOT_TOKEN=<token>"
        return 1
    fi

    # Confirmation
    if [[ "$yes_flag" != "true" ]]; then
        echo "This will stamp CHANGELOGs in all ${#REPOS[@]} repos:"
        echo "  branch → stamp → commit → push → PR → approve → merge"
        echo ""
        read -p "Type 'yes' to proceed: " -r
        if [[ "$REPLY" != "yes" ]]; then
            log_info "Aborted by user"
            return 1
        fi
        echo ""
    fi

    local failed=()
    for repo in "${REPOS[@]}"; do
        if ! changelog_execute_single "$repo" "$version" "$date" "$yes_flag"; then
            failed+=("$repo")
        fi
    done

    echo ""
    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "Failed repos: ${failed[*]}"
        return 1
    fi

    log_success "All CHANGELOGs stamped for v${version}"
    return 0
}
