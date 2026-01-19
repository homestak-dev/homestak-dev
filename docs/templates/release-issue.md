# Release Issue Template

Create a new issue in `homestak-dev` repo with this template.

**Title format:** `vX.Y Release Planning - Theme`

Examples:
- `v0.20 Release Planning - Documentation Restructure`
- `v0.21 Release Planning - CI/CD Phase 2`

---

## Summary

Brief description of the release theme and goals.

## Scope

### repo-name
- [ ] Feature/fix description (#issue)
- [ ] Another item (#issue)

### another-repo
- [ ] Item (#issue)

## Validation

- [ ] Integration test scenario: `vm-roundtrip` or `nested-pve-roundtrip`
- [ ] Test report attached
- [ ] Manual verification: (describe)

## Deferred to Future Release

- repo#N - Description (reason for deferral)

## Release Checklist

### Phase 0: Release Plan Refresh
- [ ] Verify prerequisite releases are complete (tags exist, issues closed)
- [ ] Compare release plan against `docs/lifecycle/60-release.md`
- [ ] Update checklists to match current methodology

### Pre-flight
- [ ] Git fetch on all repos (avoid rebase surprises)
- [ ] All PRs merged to master
- [ ] Working trees clean (`git status` on all repos)
- [ ] No existing tags for target version
- [ ] Site-config secrets decrypted (`site-config/secrets.yaml` exists)
- [ ] CLAUDE.md files reflect current state
- [ ] Organization README current (`.github/profile/README.md`)
- [ ] CHANGELOGs current (all repos)
- [ ] Packer build smoke test (if images changed)

### CLAUDE.md Review
**Meta repos:**
- [ ] .github - org templates, PR defaults
- [ ] .claude - skills, settings
- [ ] homestak-dev - workspace structure, documentation index

**Core repos:**
- [ ] site-config - schema, defaults, file structure
- [ ] iac-driver - scenarios, actions, ConfigResolver
- [ ] tofu - modules, variables, workflow
- [ ] packer - templates, build workflow
- [ ] ansible - playbooks, roles, collections
- [ ] bootstrap - CLI, installation

### CHANGELOGs
- [ ] .github
- [ ] .claude
- [ ] homestak-dev
- [ ] site-config
- [ ] tofu
- [ ] ansible
- [ ] bootstrap
- [ ] packer
- [ ] iac-driver

### Validation (before tagging)
- [ ] Site-config secrets decrypted
- [ ] Integration test passed (`release.sh validate` or manual iac-driver)
- [ ] Test report attached to this issue

### Tags & Releases
- [ ] .github vX.Y
- [ ] .claude vX.Y
- [ ] homestak-dev vX.Y
- [ ] site-config vX.Y
- [ ] tofu vX.Y
- [ ] ansible vX.Y
- [ ] bootstrap vX.Y
- [ ] packer vX.Y
- [ ] iac-driver vX.Y

### Packer Images
- [ ] debian-12-custom.qcow2
- [ ] debian-13-custom.qcow2
- [ ] debian-13-pve.qcow2 (or split parts)
- [ ] SHA256SUMS

### Verification
- [ ] All repos have releases
- [ ] Packer has 4 image assets (3 images + checksums)
- [ ] Post-release smoke test (bootstrap install)

### Post-Release (Phase 60 complete)
- [ ] After Action Report
- [ ] Housekeeping (branch cleanup)

### Phase 70: Retrospective (same day - do not defer)
- [ ] Retrospective completed
- [ ] Lessons learned added to `docs/lifecycle/75-lessons-learned.md`
- [ ] Close release issue via `release.sh close --execute`

---
**Started:** YYYY-MM-DD HH:MM
**Completed:** YYYY-MM-DD HH:MM
**Status:** Planning | In Progress | Complete
