# Phase 64: Release Packer Images

> Part of [Release Lifecycle](60-release.md). See overview for phase sequence and gates.

Handle packer images for the release.

## Purpose

Determine whether packer images need rebuilding and ensure the `latest` release has current images.

## Latest-Centric Approach

The `latest` release is the primary source for packer images. Versioned releases have NO image assets - they're tag-only releases that inherit images from `latest`.

## Decision Tree

```
Packer templates changed?
├── No → Skip this phase (most releases)
└── Yes → Rebuild images
         └── Upload to 'latest' release
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

Images on `latest` are already current. No action needed.

### Option B: Images Changed

#### 1. Build Images

```bash
# Build on capable host
ssh srv1 'cd /usr/local/lib/homestak/packer && ./build.sh'
```

Or build locally if QEMU/KVM is available:
```bash
cd packer && ./build.sh
```

#### 2. Upload to Latest Release

```bash
# Preview what would be uploaded
./scripts/release.sh packer --upload --all

# Upload all images (skips unchanged)
./scripts/release.sh packer --upload --execute --all

# Force re-upload all images (ignore checksums, implies --execute)
./scripts/release.sh packer --upload --force --all

# Upload specific templates only
./scripts/release.sh packer --upload --execute debian-12 pve-9

# Upload from custom images directory
./scripts/release.sh packer --upload --execute --all --images /tmp/packer-images
```

### 3. Image Checklist (When Rebuilding)

- [ ] debian-12.qcow2 + .sha256
- [ ] debian-13.qcow2 + .sha256
- [ ] pve-9.qcow2 + .sha256 (auto-split if >2GB)

**Note:** Images >2GB are automatically split during upload due to GitHub limits.

### Asset Management

Remove individual image assets from `latest` if needed:

```bash
# Preview
./scripts/release.sh packer --remove debian-12

# Execute
./scripts/release.sh packer --remove --execute debian-12

# Remove all
./scripts/release.sh packer --remove --execute --all
```

## Related

See [packer-pipeline.md](../designs/packer-pipeline.md) for naming conventions, build workflow, and caching strategy.

## Outputs

- Decision documented (skip or rebuild)
- If rebuilt: `latest` release updated with new images

## Checklist: Packer Complete

- [ ] Template changes checked
- [ ] Decision documented in release issue
- [ ] If unchanged: noted in release description
- [ ] If changed: images rebuilt and uploaded to `latest`

## Next Phase

Proceed to [65-release-publish.md](65-release-publish.md).
