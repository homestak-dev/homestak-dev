# Repository Settings Reference

Standard settings for homestak-dev repositories. Use this as a template when creating new repos.

## Repository Settings

### General

| Setting | Value | Notes |
|---------|-------|-------|
| Visibility | Public | Open-source project |
| Wiki | Disabled | Use docs/ or CLAUDE.md instead |
| Issues | Enabled | - |
| Discussions | Disabled | Use issues instead |

### Topics

All repos should include these base topics:
- `homelab`
- `infrastructure-as-code`
- `proxmox`

Add repo-specific topics as appropriate (e.g., `ansible`, `opentofu`, `packer`).

### Branch Protection (master)

```json
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false
  },
  "enforce_admins": false,
  "required_status_checks": null,
  "restrictions": null
}
```

**CLI to apply:**
```bash
gh api repos/homestak-dev/REPO_NAME/branches/master/protection -X PUT --input - <<'EOF'
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false
  },
  "enforce_admins": false,
  "required_status_checks": null,
  "restrictions": null
}
EOF
```

### Security

Enable these security features:
- Vulnerability alerts (Dependabot)
- Secret scanning (if available)

**CLI to enable:**
```bash
gh api repos/homestak-dev/REPO_NAME/vulnerability-alerts -X PUT
```

### Issue Labels

#### Default Labels (GitHub)

GitHub provides these labels by default on new repositories:

| Label | Color | Description |
|-------|-------|-------------|
| `bug` | `#d73a4a` | Something isn't working |
| `documentation` | `#0075ca` | Improvements or additions to documentation |
| `duplicate` | `#cfd3d7` | This issue or pull request already exists |
| `enhancement` | `#a2eeef` | New feature or request |
| `good first issue` | `#7057ff` | Good for newcomers |
| `help wanted` | `#008672` | Extra attention is needed |
| `invalid` | `#e4e669` | This doesn't seem right |
| `question` | `#d876e3` | Further information is requested |
| `wontfix` | `#ffffff` | This will not be worked on |

#### Custom Labels

In addition to GitHub's defaults, these custom labels are used across homestak-dev repositories:

| Label | Color | Description |
|-------|-------|-------------|
| `epic` | `#3B0A80` | Epic issue tracking multiple sub-tasks |
| `refactor` | `#FEF2C0` | Code refactoring or cleanup |
| `sprint` | `#1D76DB` | Sprint planning and tracking issues |
| `release` | `#0E8A16` | Release planning and coordination |
| `testing` | `#BFD4F2` | Test coverage or testing infrastructure |
| `security` | `#D93F0B` | Security-related issues |
| `breaking-change` | `#B60205` | Changes requiring migration or version bump |

**CLI to create labels:**
```bash
gh label create epic --repo homestak-dev/REPO_NAME --description "Epic issue tracking multiple sub-tasks" --color 3B0A80
gh label create refactor --repo homestak-dev/REPO_NAME --description "Code refactoring or cleanup" --color FEF2C0
gh label create sprint --repo homestak-dev/REPO_NAME --description "Sprint planning and tracking issues" --color 1D76DB
gh label create release --repo homestak-dev/REPO_NAME --description "Release planning and coordination" --color 0E8A16
gh label create testing --repo homestak-dev/REPO_NAME --description "Test coverage or testing infrastructure" --color BFD4F2
gh label create security --repo homestak-dev/REPO_NAME --description "Security-related issues" --color D93F0B
gh label create breaking-change --repo homestak-dev/REPO_NAME --description "Changes requiring migration or version bump" --color B60205
```

## Required Files

| File | Purpose |
|------|---------|
| `LICENSE` | Apache 2.0 (copy from existing repo) |
| `README.md` | User-facing documentation |
| `CLAUDE.md` | AI/developer context (see CLAUDE-GUIDELINES.md) |
| `CHANGELOG.md` | Version history |

## Creating a New Repo

```bash
# 1. Create repo
gh repo create homestak-dev/NEW_REPO --public --description "Description here"

# 2. Add topics
gh repo edit homestak-dev/NEW_REPO \
  --add-topic homelab \
  --add-topic infrastructure-as-code \
  --add-topic proxmox

# 3. Disable wiki
gh repo edit homestak-dev/NEW_REPO --enable-wiki=false

# 4. Clone and add required files
git clone https://github.com/homestak-dev/NEW_REPO
cd NEW_REPO
cp ../tofu/LICENSE .
# Create README.md, CLAUDE.md, CHANGELOG.md

# 5. Initial commit and push
git add .
git commit -m "Initial commit"
git push

# 6. Add branch protection
gh api repos/homestak-dev/NEW_REPO/branches/master/protection -X PUT --input - <<'EOF'
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false
  },
  "enforce_admins": false,
  "required_status_checks": null,
  "restrictions": null
}
EOF

# 7. Enable security
gh api repos/homestak-dev/NEW_REPO/vulnerability-alerts -X PUT
```

### Pull Requests

| Setting | Value | Notes |
|---------|-------|-------|
| Allow squash merging | Enabled | Default for trunk PRs |
| Allow merge commits | Enabled | For sprint branch PRs |
| Allow rebase merging | Disabled | Avoid history complications |
| Default merge method | Squash | Matches [50-merge.md](lifecycle/50-merge.md) guidance |
| Auto-delete head branches | Enabled | Prevents stale branch accumulation (v0.21+) |

**Merge strategy by path:**
- **Trunk path:** Squash merge (clean history for small changes)
- **Sprint path:** Merge commit (preserves sprint branch history)

**CLI to configure merge methods:**
```bash
gh api -X PATCH repos/homestak-dev/REPO_NAME \
  -f allow_squash_merge=true \
  -f allow_merge_commit=true \
  -f allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE \
  -f delete_branch_on_merge=true
```

## Current Repository Settings

As of v0.21, all repos are configured with:
- Branch protection requiring 1 review
- Wiki disabled
- Vulnerability alerts enabled
- Auto-delete head branches enabled
- Apache 2.0 license
- Standard topics (homelab, infrastructure-as-code, proxmox + repo-specific)
