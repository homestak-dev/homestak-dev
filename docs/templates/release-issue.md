# Release Issue Template

Create a new issue in `homestak-dev` repo with this template.

**Title format:** `vX.Y Release Planning - Theme`

Examples:
- `v0.45 Release Planning - Lifecycle Overhaul`
- `v0.46 Release Planning - CI/CD Phase 2`

---

## Summary

Brief description of the release theme and goals.

## Completed Sprints

<!-- Update as sprints complete -->

### Sprint {N}: {Theme} (open/closed)
- repo#A, repo#B
- Validation: {PASSED/PENDING}
- [Link to sprint issue]

## Scope Summary

<!-- Aggregated from sprints -->

### repo-name
- [ ] Feature/fix description (#issue)

### another-repo
- [ ] Item (#issue)

## Deferred to Future Release

- repo#N - Description (reason for deferral)

## Release Readiness

<!-- Check as conditions met -->
- [ ] All planned sprints completed
- [ ] Validation evidence available for each sprint
- [ ] All repos on clean master
- [ ] CHANGELOGs have unreleased content
- [ ] No blocking issues open

## Release Checklist

### Phase 61: Preflight
- [ ] `release.sh init` executed
- [ ] Validation evidence reviewed
- [ ] Git fetch on all repos
- [ ] Working trees clean
- [ ] No existing tags
- [ ] Secrets decrypted

### Phase 62: CHANGELOGs
- [ ] .github, .claude, homestak-dev
- [ ] site-config, tofu, ansible
- [ ] bootstrap, packer, iac-driver

### Phase 63: Tags [GATE]
- [ ] Human approval obtained
- [ ] Tags created in dependency order
- [ ] Tags pushed to origin

### Phase 64: Packer
- [ ] Template changes checked
- [ ] If changed: images rebuilt
- [ ] If unchanged: noted in release

### Phase 65: Publish [GATE]
- [ ] Human approval obtained
- [ ] Releases created in dependency order

### Phase 66: Verify
- [ ] All releases verified
- [ ] Smoke test passed
- [ ] Scope issues closed

### Phase 67: AAR
- [ ] After Action Report posted

### Phase 68: Housekeeping
- [ ] Branches cleaned up
- [ ] Release count checked

### Phase 70: Retrospective
- [ ] Retrospective completed
- [ ] Lessons added to 75-lessons-learned.md

---
**Started:** YYYY-MM-DD
**Completed:** YYYY-MM-DD
**Status:** Planning | In Progress | Complete
