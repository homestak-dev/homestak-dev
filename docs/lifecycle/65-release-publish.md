# Phase 65: Release Publish

> Part of [Release Lifecycle](60-release.md). See overview for phase sequence and gates.

Create GitHub releases for all repositories.

## GATE: Human Approval Required

**This phase requires explicit human approval before proceeding.**

Publishing makes the release public. Verify:
- Tags are correct
- Packer images handled
- Ready for users

## Purpose

Create GitHub releases for all repos in dependency order.

## Prerequisites

- Phase 63 (Tags) complete
- Phase 64 (Packer) complete
- Human approval obtained

## Activities

### 1. Dry Run

Preview release creation:

```bash
./scripts/release publish --dry-run
```

Review:
- Repos to release
- Tags to use
- Any warnings

### 2. Create Releases

With approval:

```bash
./scripts/release publish --execute --yes
```

Manual fallback requires correct org per repo — prefer `release` which handles the mapping:

```bash
./scripts/release publish --execute --yes
```

**Note:** Use `--prerelease` flag until v1.0.

### 3. Packer Release Notes

Indicate image status:
- If images NOT changed: "Images: See `latest` release"
- If images changed: "Images: Included (rebuilt for [reason])"

### 4. Verify Releases Created

```bash
./scripts/release verify
```

## Outputs

- GitHub releases created for all repos
- Pre-release flag set (until v1.0)

## Checklist: Publish Complete

- [ ] Human approval obtained
- [ ] Dry run reviewed
- [ ] Releases created in dependency order
- [ ] Pre-release flag used
- [ ] Packer release notes include image status
- [ ] All releases verified

## Next Phase

Proceed to [66-release-verify.md](66-release-verify.md).
