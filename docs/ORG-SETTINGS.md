# Organization Settings Reference

Standard settings for homestak GitHub organizations. Use this as a checklist when creating new orgs.

Companion to [REPO-SETTINGS.md](REPO-SETTINGS.md) (per-repo configuration) and [REPO-PROTOTYPE.md](REPO-PROTOTYPE.md) (repo internal structure).

## Target Organizations

| Org | Purpose | Repos |
|-----|---------|-------|
| `homestak` | User-facing product | bare-metal, bootstrap, config |
| `homestak-dev` | Developer experience | meta, .claude, .github |
| `homestak-iac` | Infrastructure automation | ansible, iac-driver, packer, tofu |
| `homestak-apps` | Self-hosted applications | pihole, jellyfin, home-assistant, ... |
| `homestak-com` | Commercial layer (future) | TBD |

## Org Creation Checklist

### 1. Create Organization

```bash
# Create org (browser — no CLI support for org creation)
# https://github.com/organizations/plan → Free plan

# Set profile
# Settings → Profile → Display name, description, avatar
```

| Setting | Value |
|---------|-------|
| Plan | Free |
| Display name | `homestak` / `homestak apps` / `homestak iac` |
| Email | (org contact email) |
| Description | Per-org (see below) |

**Org descriptions:**

| Org | Description |
|-----|-------------|
| `homestak` | Repeatable, manageable homelabs |
| `homestak-apps` | Self-hosted application configs for homestak |
| `homestak-iac` | Infrastructure-as-code engine for homestak |
| `homestak-dev` | Developer tools and process for homestak |

### 2. Organization Profile

Create `.github` repo in the org with `profile/README.md`:

```bash
gh repo create <org>/.github --public --description "Organization profile and defaults"
```

Add `profile/README.md` with org overview. See `homestak-dev/.github/profile/README.md` for the existing example.

Optionally add `.github/PULL_REQUEST_TEMPLATE.md` for a default PR template across all repos in the org.

### 3. Bot Account Setup

The `homestak-bot` account creates PRs so the operator can review and approve (HITL gate).

#### Personal Access Token (PAT)

**Recommended: Classic PAT** — One token works across all orgs with no expiration. Simpler than managing per-org fine-grained tokens.

| Setting | Value |
|---------|-------|
| Token type | Classic |
| Token name | `homestak-bot` |
| Expiration | No expiration |
| Scopes | `repo`, `admin:org` (read) |

Create at: https://github.com/settings/tokens/new (from the bot's GitHub account).

The `repo` scope covers contents, PRs, and issues across all orgs the bot is a member of. No per-org token management or annual rotation required.

**Why not fine-grained PATs:** Fine-grained PATs are scoped to a single organization. With 4+ orgs, that means 4+ tokens to create, track, rotate (max 1-year expiration), and wire into environment variables. The security benefit (per-permission granularity) doesn't justify the maintenance cost for a private bot account on your own orgs.

#### Environment Variable

Add the bot token to the operator's environment:

```bash
# ~/.profile or equivalent
export HOMESTAK_BOT_TOKEN="ghp_..."    # Classic PAT — works across all orgs
```

Single token, single variable. All tooling (`gh pr create`, `release.sh`, etc.) uses `GH_TOKEN=$HOMESTAK_BOT_TOKEN`.

### 4. Member and Team Setup

| Role | Who | Access |
|------|-----|--------|
| Owner | Primary operator | Full org admin |
| Bot | `homestak-bot` | Member (PAT-scoped) |

For orgs with external contributors (homestak-apps especially):

| Team | Purpose | Permissions |
|------|---------|-------------|
| `maintainers` | Core team | Admin on all repos |
| `contributors` | Community | Write on app repos |

### 5. Default Repository Settings

**Default branch name** (browser only — API does not support this):

Settings → Repositories → Default branch → set to `master`

- `https://github.com/organizations/<org>/settings/repository-defaults`

Configure org-level defaults (Settings → Member privileges):

| Setting | Value | Notes |
|---------|-------|-------|
| Base permissions | Read | Members can read all repos |
| Repository creation | Disabled for members | Admins only |
| Forking | Allowed | Open source |
| Pages creation | Disabled | Not used |

### 6. Security Settings

Configure at org level (Settings → Code security):

| Setting | Value |
|---------|-------|
| Dependabot alerts | Enabled for all repos |
| Dependabot security updates | Enabled |
| Secret scanning | Enabled for all repos |
| Secret scanning push protection | Enabled |

```bash
# Verify security features (per repo, after creation)
gh api repos/<org>/<repo>/vulnerability-alerts -X PUT
```

### 7. Claude Code App

Install the Claude Code GitHub App on the org for CI/CD integration:

| Setting | Value |
|---------|-------|
| App ID | 102617319 |
| Repository access | All repositories |
| Purpose | GitHub Actions CI/CD only |

**Note:** The app does NOT change local CLI commit identity. Commits remain as the human author with `Co-Authored-By` trailer.

## Per-Repo Setup (After Org Creation)

For each repo in the org, follow:

1. [REPO-PROTOTYPE.md](REPO-PROTOTYPE.md) — Internal structure (files, Makefile, CI)
2. [REPO-SETTINGS.md](REPO-SETTINGS.md) — GitHub configuration (rulesets, labels, merge settings)

### Quick Reference: New Repo in Existing Org

```bash
ORG=homestak-apps
REPO=pihole

# 1. Create repo
gh repo create $ORG/$REPO --public --description "Pi-hole DNS for homestak"

# 2. Topics
gh repo edit $ORG/$REPO --add-topic homelab --add-topic self-hosted

# 3. Disable wiki
gh repo edit $ORG/$REPO --enable-wiki=false

# 4. Merge settings
gh api -X PATCH repos/$ORG/$REPO \
  -f allow_squash_merge=true \
  -f allow_merge_commit=true \
  -f allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE \
  -f delete_branch_on_merge=true \
  -f allow_auto_merge=true

# 5. Ruleset
gh api repos/$ORG/$REPO/rulesets --method POST --input - <<'EOF'
{
  "name": "master-protection",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": 0,
      "actor_type": "OrganizationAdmin",
      "bypass_mode": "pull_request"
    }
  ],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/master"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    }
  ]
}
EOF

# 6. Security
gh api repos/$ORG/$REPO/vulnerability-alerts -X PUT

# 7. Labels
gh label create epic --repo $ORG/$REPO --description "Epic issue" --color 3B0A80
gh label create refactor --repo $ORG/$REPO --description "Code refactoring" --color FEF2C0
gh label create sprint --repo $ORG/$REPO --description "Sprint tracking" --color 1D76DB
gh label create release --repo $ORG/$REPO --description "Release coordination" --color 0E8A16
gh label create testing --repo $ORG/$REPO --description "Test coverage" --color BFD4F2
gh label create security --repo $ORG/$REPO --description "Security-related" --color D93F0B
gh label create breaking-change --repo $ORG/$REPO --description "Breaking change" --color B60205

# 8. Clone and scaffold (see REPO-PROTOTYPE.md)
git clone https://github.com/$ORG/$REPO
cd $REPO
# Add README.md, CLAUDE.md, CHANGELOG.md, LICENSE, Makefile, .github/workflows/ci.yml
```

## Org-Specific Topics

Base topics vary by org:

| Org | Base Topics |
|-----|-------------|
| `homestak` | `homelab` |
| `homestak-apps` | `homelab`, `self-hosted` |
| `homestak-iac` | `homelab`, `infrastructure-as-code`, `proxmox` |
| `homestak-dev` | `homelab`, `infrastructure-as-code`, `proxmox` |

Add repo-specific topics as appropriate (e.g., `ansible`, `docker`, `pihole`).

## Repo Migration (homestak-dev → target org)

When moving existing repos during the org split:

```bash
# GitHub Settings → Danger Zone → Transfer repository
# Select target org, confirm repo name
```

| Consideration | Action |
|--------------|--------|
| GitHub redirects | Automatic — old URLs redirect to new location |
| Git remotes | Update local clones: `git remote set-url origin https://github.com/<new-org>/<repo>.git` |
| Cross-repo references | Issues referencing `homestak-dev/<repo>#N` continue to work via redirects |
| Rulesets | Re-apply after transfer (rulesets don't transfer between orgs) |
| Bot PAT | Must have access to the new org |
| CI workflows | Update org references in workflow files |
| CLAUDE.md | Update repo URLs and cross-references |
| gita config | Update paths: `gita rm <repo> && gita add <new-path>` |
| release.sh | Update repo list and org references |

**Order of operations:**
1. Create target org (if new)
2. Set up bot access on target org
3. Transfer repo
4. Re-apply rulesets and settings
5. Update local remotes and gita
6. Verify CI runs on first push/PR

## Related Documents

- [REPO-SETTINGS.md](REPO-SETTINGS.md) — Per-repo GitHub configuration
- [REPO-PROTOTYPE.md](REPO-PROTOTYPE.md) — Repo internal structure
- [roadmap.md](roadmap.md) — Org architecture and maturity path
