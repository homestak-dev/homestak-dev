# Phase: Retrospective

Retrospective captures lessons learned and closes the release cycle. This phase completes the development lifecycle.

## Sprint vs Release Retrospective

| Type | When | Scope | Depth |
|------|------|-------|-------|
| Sprint | At sprint close (55) | Sprint execution | Brief (in sprint issue) |
| Release | After release (70) | Full release cycle | Full (dedicated section) |

Sprint retrospectives are documented in sprint issues during Phase 55.
This document covers release retrospectives.

## Purpose

- Reflect on the release process
- Identify improvements
- Codify lessons learned
- Close the release cycle

## Prerequisites

- Phase 68 (Housekeeping) complete
- AAR posted to release issue
- All sprints have retrospectives

## Activities

### 1. Release Retrospective

Complete same day as release while context is fresh.

**AI-Assisted Retrospective:**
1. Review release issue, sprint outcomes, AAR
2. Identify what worked well and what could improve
3. Present draft for user review
4. User adds observations and approves

Use the [Retrospective Template](../templates/retrospective.md):

```markdown
## Release Retrospective - v0.45

### What Worked Well
- Theme-first planning kept focus
- Sprint validation caught issues early
- CLI automation reduced errors

### What Could Improve
- CHANGELOG updates took longer than expected
- Packer decision tree wasn't clear

### Suggestions
- Add CHANGELOG helper to release.sh
- Document packer decision more clearly

### Open Questions
- Should we automate more of preflight?

### Follow-up Issues
- #158 - CHANGELOG helper
- #159 - Packer documentation
```

### 2. Codify Lessons Learned

Update `docs/lifecycle/75-lessons-learned.md`:

1. Add new lessons under current version heading
2. Update category sections if adding cross-cutting lessons
3. Commit with message: `docs: Update 75-lessons-learned.md with vX.Y lessons`

### 3. Close Release Issue

Use `release.sh close`:

```bash
./scripts/release.sh close --execute --yes
```

This:
- Posts summary comment with release stats
- Closes the issue
- Cleans up state files

The release issue is the record of completion.

## Outputs

- Release retrospective posted
- Lessons learned codified
- Follow-up issues created
- Release issue closed

## Checklist: Retrospective Complete

- [ ] Release retrospective completed
- [ ] Follow-up issues created
- [ ] Lessons added to 75-lessons-learned.md
- [ ] Lessons committed
- [ ] Release issue closed

## Anti-Patterns

### Don't Skip Retrospective

Retrospective has been skipped in multiple releases. This is a common process error.

**Prevention:**
- `release.sh close` displays reminder
- Complete same day as release
- AI can draft to reduce burden

### Don't Defer Lessons

**Bad:** "I'll add lessons later"
**Good:** Add immediately while context is fresh

Context loss leads to incomplete entries.

## Related Documents

- [55-sprint-close.md](55-sprint-close.md) - Sprint retrospective
- [68-release-housekeeping.md](68-release-housekeeping.md) - Preceding phase
- [75-lessons-learned.md](75-lessons-learned.md) - Accumulated lessons
- [../templates/retrospective.md](../templates/retrospective.md) - Template
