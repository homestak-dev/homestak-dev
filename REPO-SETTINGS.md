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

## Current Repository Settings

As of v0.10, all repos are configured with:
- Branch protection requiring 1 review
- Wiki disabled
- Vulnerability alerts enabled
- Apache 2.0 license
- Standard topics (homelab, infrastructure-as-code, proxmox + repo-specific)
