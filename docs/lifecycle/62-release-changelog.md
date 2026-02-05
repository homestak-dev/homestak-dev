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
.github → .claude → homestak-dev → site-config → tofu → ansible → bootstrap → packer → iac-driver
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

```bash
for repo in .claude .github ansible bootstrap homestak-dev iac-driver packer site-config tofu; do
  cd ~/homestak-dev/$repo
  git add CHANGELOG.md
  git commit -m "docs: Update CHANGELOG for v0.45

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
  git push origin master
done
```

## Using release.sh

```bash
./scripts/release.sh changelog --version 0.45
```

Automates CHANGELOG updates across repos.

## Outputs

- All repos have versioned CHANGELOG entries
- Changes committed and pushed

## Checklist: CHANGELOG Complete

- [ ] .github CHANGELOG updated
- [ ] .claude CHANGELOG updated
- [ ] homestak-dev CHANGELOG updated
- [ ] site-config CHANGELOG updated
- [ ] tofu CHANGELOG updated
- [ ] ansible CHANGELOG updated
- [ ] bootstrap CHANGELOG updated
- [ ] packer CHANGELOG updated
- [ ] iac-driver CHANGELOG updated
- [ ] All changes committed and pushed

## Next Phase

Proceed to [63-release-tag.md](63-release-tag.md).
