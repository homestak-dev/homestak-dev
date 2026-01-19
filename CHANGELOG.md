# Changelog

## Unreleased

## v0.31 - 2026-01-19

### Theme: Code Quality

### Changed
- Require `--issue N` for `release.sh init` (#114)
  - Release issue is now required by default
  - Use `--no-issue` for hotfix releases without tracking issue
  - Preflight warns if no issue is linked

## v0.30 - 2026-01-18

### Theme: Developer Experience and Reliability

### Added
- `release.sh retrospective` command to mark retrospective phase complete (#109)
  - Blocks `close` until retrospective is done (use `--force` to override)
  - Prevents premature release closure (pattern from v0.25, v0.26, v0.29)
- `release.sh publish --yes` flag to skip confirmation prompt (#109)
- `release.sh close --yes` flag to skip confirmation prompt (#109)

### Fixed
- Fix selftest failures for tag-dry and publish-dry tests (#108)
  - Skip tests when repos have uncommitted changes
  - Skip publish-dry when tags don't exist for test version

## v0.29 - 2026-01-18

### Theme: Stage Validation

### Added
- `release.sh validate --stage` flag for installed CLI validation (#112)
  - Runs `homestak scenario` via installed CLI instead of dev checkout
  - Validates full bootstrap installation path
  - Requires sudo for FHS paths
  - Works with `--remote` for SSH execution

### Fixed
- bootstrap#21: site-init corrupts secrets.yaml indentation (documented, fix pending)

## v0.28 - 2026-01-18

- Release alignment with homestak v0.28

## v0.27 - 2026-01-17

### Theme: Release CLI UX Improvements

### Added
- `release.sh close` command to finalize releases (#106)
  - Validates all tracked phases complete before closing
  - Posts summary comment to release issue
  - Closes release issue and cleans up state files
  - `--force` flag to skip phase validation
- `release.sh tag --yes` flag to skip confirmation prompt (#106)
  - Enables non-interactive tag execution
  - Short form: `-y`
- Reminder in `release.sh verify` output (#106)
  - Shows remaining phases after verification
  - Prevents premature release issue closure

### Changed
- `release.sh publish --execute` now requires explicit `--workflow` flag (#104)
  - No default workflow - must specify `--workflow github` or `--workflow local`
  - Error message guides user toward recommended option
  - `--dry-run` still works without flag for previewing

## v0.26 - 2026-01-17

- Release alignment with homestak v0.26

All notable changes to this project will be documented in this file.

## [v0.25] - 2026-01-16

### Theme: Release CLI Improvements

### Added
- `release.sh resume` command for AI-friendly session recovery (#101)
  - Outputs markdown-formatted context: version, issue, phase/repo status tables
  - Shows recent audit log entries and suggested next steps
  - Handles edge cases: no release, corrupted state, completed release
- `release.sh publish --workflow` option for packer image handling (#99)
  - `--workflow github` uses GHA copy-images.yml (fast, server-side)
  - `--workflow local` uses local download/upload (default for safety)
  - Auto-fallback to local if github workflow fails
- Bats test framework for release.sh (#97)
  - `test/test_helper/common.bash` - shared setup, mocks, assertions
  - `test/state.bats` - state file operations (27 tests)
  - `test/cli.bats` - CLI command routing (15 tests)
  - `make test` and `make lint` targets in Makefile
- Multi-session release guidance (#98)
  - CLAUDE.md: expanded Release Session Recovery section
  - 60-release.md: Multi-Session Releases guidance with phase comments

### Changed
- `release.sh` now honors `STATE_FILE` env var for test isolation
- `bats` added to `make check-deps` dependency list

## [v0.24] - 2026-01-16

### Added
- v0.24 "Bootstrap DX" release - improved developer experience for bootstrap workflow
  - Extract CLI to standalone `homestak.sh` with FHS-compliant paths (bootstrap#14)
  - Add bats unit tests for CLI (bootstrap#15)
  - Enhance `homestak update` with --dry-run, --version, --stash (bootstrap#13)
  - Add comprehensive preflight checks (iac-driver#97)

## [v0.23] - 2026-01-16

### Added
- Add checkpoint markers to release phases in `docs/lifecycle/60-release.md` (#90)
  - Explicit verification prompts at each phase transition
  - Visible blockquote format for easy scanning
- Add Process Discipline section to `CLAUDE.md` (#90)
  - AI behavioral guidance for lifecycle adherence
  - Phase sequence, checkpoint verification, and design requirements
  - Destructive operations policy (--force flags, --dry-run)
- Add `release.sh sunset` command to delete legacy releases (#91)
  - `--below-version X.Y` specifies version threshold
  - Deletes GitHub releases while preserving git tags
  - Preserves packer's `latest` release
  - Supports `--dry-run` and `--execute` modes

### Fixed
- Fix `release.sh verify` to check `latest` for packer images (#88)
  - Images now checked in `latest` release (latest-centric approach)
  - Updated expected assets: per-image `.sha256` files instead of `SHA256SUMS`
  - Output clearly indicates assets are from 'latest' release
- Fix `release.sh publish` to sync assets to `latest` release (#94, unplanned)
  - `publish_update_latest()` now copies images from versioned release to `latest`
  - Generates missing `.sha256` checksums during sync
  - Ensures `verify` passes after `publish` (closes the publish→verify gap)

## [v0.22] - 2026-01-15

### Changed
- `release.sh packer --copy` now uses per-image `.sha256` checksums (packer#29)
  - Downloads `.qcow2` images and accompanying `.sha256` files from source release
  - Excludes legacy `SHA256SUMS` (consolidated format, deprecated)
  - Aligns with packer build.sh which generates per-image checksums

### Fixed
- Fix `release.sh packer --workflow` gh CLI syntax (.github#30)
  - Changed workflow existence check to use correct `gh workflow list` output format
  - Removed unsupported `--json` flag from workflow list command

### Documentation
- Adopt latest-centric packer image distribution (#83)
  - `latest` is now the primary image source; versioned releases typically have no images
  - Updated `docs/lifecycle/60-release.md` Phase 5 with Option A (skip) / Option B (rebuild) paths
  - Updated verification expectations and release checklists
  - Added `packer_release: latest` note to site-config/CLAUDE.md

### Cross-Repo Changes

**packer v0.22:**
- Fix copy-images workflow to support `latest` as target (.github#30)
  - Relaxed validation to accept `latest` OR `vX.Y` format
  - Auto-create `latest` release if it doesn't exist
  - Fix `force` parameter type in tag update API call (use `-F` for boolean)
  - Improved error messages and debugging output

---

## [v0.21] - 2026-01-15

### Added
- `release.sh validate --packer-release` flag for specifying packer image version (#74)
  - Passes through to iac-driver's `--packer-release` option
  - Enables validation with specific packer release when `latest` tag points to draft

### Improved
- Release issue tracking visibility throughout release process (#77)
  - `release.sh init` shows tip to link release issue if not provided
  - `release.sh status` shows yellow warning when no issue is linked
  - Add release issue checkpoint to lifecycle docs (Phase 1: Pre-flight)
  - Add directive to CLAUDE.md about identifying release issue at session start

---

## [v0.20] - 2026-01-15

### Theme: Release Automation

### Added
- `release.sh preflight --host` for validation host readiness checks (#65)
  - Validates API token, node config, packer images, nested virtualization
  - Supports multiple hosts: `--host father --host mother`
- `release.sh packer --version/--source` flags for explicit version control (#50)
  - `--version` specifies target release version
  - `--source` specifies source release for `--copy` operations
- Auto-ensure packer images exist on `release.sh publish` (#45)
  - Checks for required images before publishing
  - Offers to copy from previous release if missing
- `release.sh packer --workflow` for GHA-based image copy (#56)
  - Triggers copy-images workflow instead of local gh commands
  - `--no-wait` for async, `--timeout` for custom wait duration
- Release issue auto-update integration (#35)
  - `--issue` flag on `init` to track release issue
  - Posts status comments after each phase completes

### Cross-Repo Changes

**packer v0.20:**
- Per-template cleanup scripts (#11)
  - Refactored cleanup into modular `cleanup-common.sh` + per-template overrides
  - PVE-specific cleanup for enterprise repo removal and network fix
- Version details in image names (#8)
  - Images renamed: `debian-13-custom.qcow2` → `deb13.3-custom.qcow2`
  - Backward-compatible symlinks maintained
- Enhanced copy-images workflow with validation and latest tag update (#56)

**iac-driver v0.20:**
- Refactored packer scenarios to use build.sh wrapper
  - Ensures version detection and cleanup scripts run during scenario builds

---

## [v0.19] - 2026-01-14

### Theme: Stabilization

### Added
- `release.sh selftest` command for CLI validation (#61)
  - Exercises all commands in dry-run mode
  - Catches bugs before release (like v0.18's `gh release list --json` issue)
  - Supports `--verbose` for detailed output
- `release.sh packer --copy` now generates SHA256SUMS (#62)
  - Downloads images from source release
  - Generates fresh SHA256SUMS after copy
  - Uploads images + SHA256SUMS to target release
  - Works even if source release predates checksum feature (v0.17)
- Provider cache check in `release.sh preflight` (#64)
  - Detects stale provider caches vs lockfile version
  - Reports mismatches with clear remediation steps

### Documentation
- Restructure development lifecycle documentation (#66)
  - Add `docs/lifecycle/` with 6-phase development process (planning → release)
  - Add `docs/templates/` with reusable AAR, retrospective, and issue templates
  - Move CLAUDE-GUIDELINES.md and REPO-SETTINGS.md to `docs/`
  - Consolidate PLANNING.md, FEATURE.md, RELEASE.md into lifecycle docs
  - Preserve all lessons learned from v0.8-v0.19 in 60-release.md
- Add validation host prerequisites section to RELEASE.md (#63)
  - Documents what makes a host "validation-ready" beyond bootstrap
  - Includes quick check script and common issues table
  - Prerequisites: node config, API token, packer images, nested virt

### Cross-Repo Changes

**iac-driver v0.19:**
- Add API token validation via `--validate-only` flag (#31)
- Add host availability check with SSH reachability test (#32)
- Enhance `--local` flag with auto-config from hostname (#26)

**packer v0.19:**
- Investigate guest agent delay on debian-13-pve image (#13)
  - Tested optimizations found ineffective; no code changes

**site-config v0.19:**
- Add `hosts/.gitkeep` to track directory structure (#16)

## [v0.18] - 2026-01-13

### Theme: Release Tooling Completion

Completes the release automation CLI with end-to-end workflow support and improved verification.

### Added
- `release.sh full` command for end-to-end release automation (#34)
  - Orchestrates: preflight → validate → tag → publish → packer → verify
  - Resumable via state phase tracking
  - Supports `--skip-validate` for emergency releases
- Tag inventory check in `release.sh verify` (#48)
  - Shows missing tags before closing release
  - Integrated into verification output
- Tag reset capability in `release.sh tag` (#49)
  - `--reset` flag deletes and recreates tags at HEAD
  - `--reset-repo` for single repo operations
  - Safety check: only allowed for v0.x pre-releases
- Packer image automation in `release.sh` (#56)
  - `packer --check` detects template changes via git diff
  - `packer --copy` copies images from previous release
  - GitHub Actions workflow for cross-release image copying

### Cross-Repo Changes

**packer v0.18:**
- Add SHA256 checksums to image releases (#22)
- Add `checksums.sh` script for generate/verify/show
- Add `.github/workflows/copy-images.yml` for release automation

**iac-driver v0.18:**
- Add `--dry-run` mode for scenario preview (#40)

## [v0.17] - 2026-01-11

### Added
- release.sh: Draft release detection in verify command (#52)
  - `verify_release_exists()` returns "draft" status when `isDraft:true`
  - Verification fails if any releases are drafts
  - Displays draft status with warning icon
- release.sh: Auto-finalize draft releases in publish command (#52)
  - `publish_create_single()` finalizes drafts instead of skipping

## [v0.16] - 2026-01-11

### Changed
- CLAUDE.md now uses @imports to auto-load sub-project CLAUDE.md files at session start (#46)

## [v0.15] - 2026-01-10

### Theme: CLI Hardening

Addresses dogfooding issues found during v0.14 release execution.

### Added
- `--remote HOST` flag to validate command for running validation on remote PVE host via SSH (#39)

### Fixed
- Preflight now checks for `site-config/secrets.yaml` before validation (#40)
- Publish command now skips existing releases instead of failing (#41)
- Verify command recognizes split packer image files (.partaa, .partab) (#42)

### Related Issues
- Closes #39 (Add --remote flag to validate command)
- Closes #40 (Add secrets decryption check to preflight)
- Closes #41 (Handle existing releases in publish command)
- Closes #42 (Update verify.sh to handle split packer images)

## [v0.14] - 2026-01-10

### Theme: Release Automation Phase 1

This release introduces the release automation CLI (`scripts/release.sh`) to streamline multi-repo release operations. The CLI automates pre-flight checks, validation, tag creation, GitHub release publishing, and post-release verification.

### Added
- `scripts/release.sh` - Release automation CLI with commands:
  - `init` - Initialize release state for a version
  - `status` - Show current release progress
  - `preflight` - Check all repos are ready (clean working trees, no existing tags)
  - `validate` - Run iac-driver integration tests
  - `tag` - Create git tags with dry-run and rollback support
  - `publish` - Create GitHub releases with packer image uploads
  - `verify` - Verify all releases exist with markdown summary
  - `audit` - Show timestamped action log
- `scripts/lib/` - Modular library structure:
  - `state.sh` - JSON state management with jq
  - `audit.sh` - Timestamped action logging
  - `preflight.sh` - Pre-release checks
  - `validate.sh` - iac-driver integration
  - `tag.sh` - Tag creation with rollback
  - `publish.sh` - GitHub release publishing
  - `verify.sh` - Post-release verification
- `.gitignore` - Added `.release-state.json` and `.release-audit.log`
- CLAUDE.md - Added Release Automation CLI section

### Safety Features
- Dry-run mode for tag and publish operations
- Validation gates requiring integration tests before tagging
- Automatic rollback on tag creation failure
- Dependency-ordered operations across all 9 repos

### Related Issues
- Closes #21 (State Management)
- Closes #22 (Pre-flight Implementation)
- Closes #23 (Validation Integration)
- Closes #24 (Tag Creation)
- Closes #25 (Release Publishing)
- Closes #26 (Verification)
- Closes #27 (Audit Logging)

## [v0.13] - 2026-01-10

### Theme: Site-Config as Single Source of Truth

This release establishes site-config as the authoritative configuration source for all homestak components. Ansible now receives resolved configuration from iac-driver, following the same pattern already established for tofu.

### Added
- CLAUDE.md: Configuration Flow section documenting site-config → iac-driver → ansible/tofu

### Cross-Repo Changes

**site-config v0.13:**
- Add `postures/` directory (dev, prod, local security profiles)
- Extend `site.yaml` with packages and pve settings
- Move `datastore` to nodes/ (now required per-node)

**iac-driver v0.13:**
- Add `resolve_ansible_vars()` to ConfigResolver
- Add readiness checks (API token, host availability)
- Add shared test fixtures (`conftest.py`)
- Add pre-commit hooks config

**ansible v0.13:**
- Simplify `group_vars/` (postures now in site-config)
- Fix all ansible-lint violations (209 → 0)
- Enable strict lint enforcement in CI

## [v0.12] - 2025-01-09

Initial release of the homestak-dev parent repo.

### Added
- CLAUDE.md - Consolidated vision, architecture, conventions from .github
- README.md - Developer/contributor quick start guide
- RELEASE.md - Release methodology (moved from .github)
- REPO-SETTINGS.md - Repository configuration standards (copied from .github)
- CLAUDE-GUIDELINES.md - Documentation standards (copied from .github)
- LICENSE - Apache 2.0
- Makefile - Workspace targets (help, install-deps)
- .gitignore - Excludes child repos managed by gita

### Changed
- .github/CLAUDE.md now focuses on GitHub platform configuration (CI/CD, branch protection)
- Release coordination issues now tracked in homestak-dev (previously .github)
