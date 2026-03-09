# Phase 63: Release Tags

> Part of [Release Lifecycle](60-release.md). See overview for phase sequence and gates.

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

Or manually per repo (must use correct org for each):

```bash
VERSION=0.54
# release.sh handles org mapping and paths automatically
./scripts/release tag --execute --yes
```

### 3. Verify Tags

```bash
# Automated verification
./scripts/release verify
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
# release.sh handles org mapping and paths automatically
./scripts/release tag --reset
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
