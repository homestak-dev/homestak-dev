# Phase 66: Release Verify

> Part of [Release Lifecycle](60-release.md). See overview for phase sequence and gates.

Verify all releases were created correctly.

## Purpose

Confirm releases exist, have correct tags, and assets are present.

## Prerequisites

- Phase 65 (Publish) complete

## Activities

### 1. Verify All Releases

```bash
./scripts/release verify
```

The CLI checks all 10 repos across 3 orgs automatically.

### 2. Expected Results

| Repo | Expected Assets |
|------|-----------------|
| All (except packer) | 0 (tag-only) |
| packer (if images changed) | `debian-12.qcow2`, `debian-13.qcow2`, `pve-9.qcow2` (auto-split if >2GB) + `.sha256` checksums |
| packer (if images unchanged) | 0 (tag-only, images stay on `latest` release) |

### 3. Post-Release Smoke Test

Test bootstrap installation:

```bash
# On a clean system or VM
curl -fsSL https://raw.githubusercontent.com/homestak/bootstrap/vX.Y/install | sudo bash
sudo -iu homestak
homestak --version  # Should show vX.Y
```

### 4. Verify Scope Issues Closed

Check all scope issues from completed sprints are closed:

```bash
# Review release issue for sprint links
gh issue view <release-issue> --repo homestak-dev/meta

# Verify each scope issue is closed (use correct org per repo)
gh issue view <issue-num> --repo <org>/<repo> --json state
```

Close any missed issues:

```bash
gh issue close <issue-num> --repo <org>/<repo> \
  --comment "Implemented in vX.Y"
```

## Outputs

- All releases verified
- Smoke test passed
- Scope issues closed

## Checklist: Verify Complete

- [ ] All repos have releases
- [ ] Packer assets correct (if applicable)
- [ ] Post-release smoke test passed
- [ ] All scope issues closed

## Next Phase

Proceed to [67-release-housekeeping.md](67-release-housekeeping.md).
