# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
