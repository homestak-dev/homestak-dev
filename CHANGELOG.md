# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
