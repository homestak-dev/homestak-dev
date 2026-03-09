# Phase 62: Release CHANGELOG

> Part of [Release Lifecycle](60-release.md). See overview for phase sequence and gates.

Update CHANGELOGs to add version headers for the release.

## Purpose

Move content from `## Unreleased` to versioned section in all repos.

## Prerequisites

- Phase 61 (Preflight) complete
- All repos have unreleased content (or explicitly no changes)

## Activities

### 1. Update Each Repo's CHANGELOG

In dependency order:

```
.github → .claude → meta → config → tofu → ansible → bootstrap → packer → iac-driver
```

### 2. CHANGELOG Format

**Before:**

```markdown
## Unreleased

### Features
- Add capability (#123)

### Bug Fixes
- Fix issue (#124)
```

**After:**

```markdown
## Unreleased

## v0.45 - 2024-01-17

### Features
- Add capability (#123)

### Bug Fixes
- Fix issue (#124)
```

### 3. Standard Categories

| Category | Use For |
|----------|---------|
| Features | New capabilities |
| Bug Fixes | Corrections |
| Changes | Modifications to existing behavior |
| Deprecations | Features being phased out |
| Security | Security-related changes |
| Documentation | Doc-only changes (if significant) |

### 4. No Changes Handling

For repos with no changes:

```markdown
## v0.45 - 2024-01-17

No changes.
```

### 5. Commit CHANGELOG Updates

CHANGELOG stamps require PRs (rulesets block direct push). Create a branch, commit, and PR per repo:

```bash
# For each repo: branch, commit, push, PR with --head flag
git -C <repo-path> checkout -b release/vX.Y-changelog
git -C <repo-path> add CHANGELOG.md
git -C <repo-path> commit -m "docs: Stamp CHANGELOG for vX.Y"
git -C <repo-path> push -u origin release/vX.Y-changelog

# Create PR with explicit --head (required for multi-org)
GH_TOKEN=$HOMESTAK_BOT_TOKEN gh pr create --repo <org>/<repo> \
  --head release/vX.Y-changelog --title "docs: Stamp CHANGELOG for vX.Y" --body "..."
gh pr merge --auto --squash <pr> --repo <org>/<repo>
```

**CHANGELOG-only PRs** may be approved by the operator without manual review since they contain only version header stamps.

## Outputs

- All repos have versioned CHANGELOG entries
- Changes committed and pushed via PRs

## Checklist: CHANGELOG Complete

- [ ] .github CHANGELOG updated
- [ ] .claude CHANGELOG updated
- [ ] meta CHANGELOG updated
- [ ] config CHANGELOG updated
- [ ] tofu CHANGELOG updated
- [ ] ansible CHANGELOG updated
- [ ] bootstrap CHANGELOG updated
- [ ] packer CHANGELOG updated
- [ ] iac-driver CHANGELOG updated
- [ ] All PRs merged

## Next Phase

Proceed to [63-release-tag.md](63-release-tag.md).
