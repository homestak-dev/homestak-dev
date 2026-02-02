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
./scripts/release.sh verify
```

Or manually:

```bash
VERSION=0.45
for repo in .github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver; do
  echo "=== $repo ==="
  gh release view v${VERSION} --repo homestak-dev/$repo \
    --json tagName,assets --jq '{tag: .tagName, assets: (.assets | length)}'
done
```

### 2. Expected Results

| Repo | Expected Assets |
|------|-----------------|
| All (except packer) | 0 (tag-only) |
| packer (if images changed) | 6 (3 images + 3 checksums) |
| packer (if images unchanged) | 0 (tag-only) |

### 3. Post-Release Smoke Test

Test bootstrap installation:

```bash
# On a clean system or VM
curl -fsSL https://raw.githubusercontent.com/homestak-dev/bootstrap/v0.45/install.sh | bash
homestak --version  # Should show v0.45
```

### 4. Verify Scope Issues Closed

Check all scope issues from completed sprints are closed:

```bash
# Review release issue for sprint links
gh issue view <release-issue> --repo homestak-dev/homestak-dev

# Verify each scope issue is closed
gh issue view <issue-num> --repo homestak-dev/<repo> --json state
```

Close any missed issues:

```bash
gh issue close <issue-num> --repo homestak-dev/<repo> \
  --comment "Implemented in v0.45"
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
