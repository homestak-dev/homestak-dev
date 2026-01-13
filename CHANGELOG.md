# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
