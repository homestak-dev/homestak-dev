# Phase 64: Release Packer Images

> Part of [Release Lifecycle](60-release.md). See overview for phase sequence and gates.

Handle packer images for the release.

## Purpose

Determine whether packer images need rebuilding and update the `latest` release accordingly.

## Latest-Centric Approach

The `latest` release is the primary source for packer images. Versioned releases typically have NO image assets - they're tag-only releases that inherit images from `latest`.

## Decision Tree

```
Packer templates changed?
├── No → Skip this phase (most releases)
└── Yes → Rebuild images
         └── Update 'latest' release
```

## When to Rebuild Images

- Packer template changes (new packages, cloud-init fixes)
- Base Debian image updates (12.x → 12.y)
- Security fixes in image content
- New image variants added

## When to Skip

- Documentation-only changes
- Build script refactoring (unless affects output)
- CHANGELOG updates
- Templates unchanged

## Activities

### Option A: Images NOT Changed (Default)

Most releases skip image handling:

```bash
./scripts/release.sh packer --check
# Output: No template changes detected
```

Add note to packer release description: "Images: See `latest` release"

### Option B: Images Changed

#### 1. Build Images

```bash
# Build on capable host, then fetch images
ssh <build-host-ip> 'cd /usr/local/lib/homestak/packer && ./build.sh'
scp <build-host-ip>:/usr/local/lib/homestak/packer/images/*/*.qcow2 /tmp/packer-images/
```

#### 2. Update Latest Release

Using release CLI:

```bash
./scripts/release.sh packer --copy --source v0.45 --execute
```

Or manually:

```bash
cd ~/homestak-dev/packer

# Move latest tag
git tag -f latest v0.45
git push origin latest --force

# Recreate latest release with new images
gh release delete latest --repo homestak-dev/packer --yes
gh release create latest --prerelease \
  --title "Latest Images" \
  --notes "Points to v0.45" \
  --repo homestak-dev/packer \
  /tmp/packer-images/*.qcow2 \
  /tmp/packer-images/*.sha256
```

### 3. Image Checklist (When Rebuilding)

- [ ] debian-12-custom.qcow2 + .sha256
- [ ] debian-13-custom.qcow2 + .sha256
- [ ] debian-13-pve.qcow2 + .sha256 (or split parts if >2GB)

**Note:** Images >2GB must be split due to GitHub limits.

## Outputs

- Decision documented (skip or rebuild)
- If rebuilt: `latest` release updated with new images

## Checklist: Packer Complete

- [ ] Template changes checked
- [ ] Decision documented in release issue
- [ ] If unchanged: noted in release description
- [ ] If changed: images rebuilt and uploaded

## Next Phase

Proceed to [65-release-publish.md](65-release-publish.md).
