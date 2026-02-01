# Phase 63: Release Tags

Create and push git tags for the release.

## GATE: Human Approval Required

**This phase requires explicit human approval before proceeding.**

Tags are permanent references. Verify:
- CHANGELOGs are complete
- All repos at correct commit
- Version number is correct

## Purpose

Create annotated tags on all repositories in dependency order.

## Prerequisites

- Phase 62 (CHANGELOG) complete
- All CHANGELOG commits pushed
- Human approval obtained

## Activities

### 1. Dry Run

Preview tag creation:

```bash
./scripts/release.sh tag --dry-run
```

Review output:
- Repos to tag
- Current HEAD commits
- Any warnings

### 2. Create Tags

With approval:

```bash
./scripts/release.sh tag --execute --yes
```

Or manually per repo:

```bash
VERSION=0.45
for repo in .github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver; do
  cd ~/homestak-dev/$repo
  git tag -a v${VERSION} -m "Release v${VERSION}"
  git push origin v${VERSION}
done
```

### 3. Verify Tags

```bash
VERSION=0.45
for repo in .github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver; do
  echo "=== $repo ==="
  gh api repos/homestak-dev/$repo/git/refs/tags/v${VERSION} --jq '.ref'
done
```

## Tag Reset (Pre-1.0 Only)

If tags need correction during pre-release:

```bash
./scripts/release.sh tag --reset
```

This deletes and recreates tags at current HEAD. **Not available after v1.0.**

## Rollback

If tags created incorrectly:

```bash
VERSION=0.45
for repo in .github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver; do
  cd ~/homestak-dev/$repo
  git tag -d v${VERSION}
  git push origin :refs/tags/v${VERSION}
done
```

## Outputs

- All repos tagged with version
- Tags pushed to origin

## Checklist: Tags Complete

- [ ] Human approval obtained
- [ ] Dry run reviewed
- [ ] Tags created in dependency order
- [ ] Tags pushed to origin
- [ ] Tags verified via API

## Next Phase

Proceed to [64-release-packer.md](64-release-packer.md).
