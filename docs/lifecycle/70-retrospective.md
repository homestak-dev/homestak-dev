# Phase: Retrospective

Retrospective captures lessons learned and closes the release cycle. This phase completes the development lifecycle and is separate from the structured release activities (Phase 60).

## Purpose

The Retrospective phase serves a distinct purpose from the Release phase:
- **Release (Phase 60)**: Structured, procedural activities - tagging, publishing, verification
- **Retrospective (Phase 70)**: Creative, evaluative activities - reflection, learning, improvement

This separation enables automation of Release activities while preserving human judgment for Retrospective activities.

## Inputs

- Completed release (all Phase 60 steps done)
- After Action Report from Phase 60
- Sprint experience and observations

## Activities

### 1. Retrospective

> **CHECKPOINT: Phase 60 Complete**
> Before proceeding, verify: Housekeeping completed, stale branches cleaned up, AAR posted to release issue.

**Complete same day as release.**

**AI-Assisted Retrospective:** When working with Claude, request a draft retrospective first. Claude should:
1. Review the release issue comments, AAR, and audit log
2. Identify what worked well and what could improve
3. Present a draft for user review and additions
4. User adds their own observations and approves final version

This ensures retrospectives are completed even when time is short, while preserving human judgment.

Use the [Retrospective Template](../templates/retrospective.md) to document:

| Section | Content |
|---------|---------|
| What Worked Well | Keep doing these |
| What Could Improve | Process improvements |
| Suggestions | Specific ideas for next release |
| Open Questions | Decisions deferred |
| Follow-up Issues | Create issues for discoveries |

**Important:** Create GitHub issues for any problems discovered. Link them in the retrospective.

### 2. Codify Lessons Learned

After the retrospective, update `docs/lifecycle/75-lessons-learned.md` with any process improvements:

1. Add new lessons under the current version heading
2. Update category sections if adding cross-cutting lessons
3. Commit with message: `docs: Update 75-lessons-learned.md with vX.Y lessons`

### 3. Close Release Issue

**Close the release issue only after lessons are codified and committed.**

Use `release.sh close --execute` to:
- Post a summary comment with release stats
- Close the issue
- Clean up state files (`.release-state.json`, `.release-audit.log`)

The release issue is the record of completion - closing it signals all phases are done.

## Human Review Checkpoint

This phase is inherently human-driven:
- Reflect on what worked and what didn't
- Identify process improvements
- Create follow-up issues for discoveries
- Approve lessons learned before committing
- Close the release issue

## Outputs

- Retrospective posted to release issue
- Lessons learned codified in `75-lessons-learned.md`
- Follow-up issues created (if any)
- Release issue closed
- State files cleaned up

## Checklist: Retrospective Complete

- [ ] Retrospective completed using template
- [ ] Follow-up issues created for discoveries
- [ ] Lessons learned added to `75-lessons-learned.md`
- [ ] Lessons committed with proper message
- [ ] Release issue closed via `release.sh close --execute`

## Anti-Patterns

### Don't Skip Retrospective

Retrospective has been skipped in multiple releases (v0.25, v0.26, v0.29). This is the third most common process error.

**Symptoms:**
- Release issue closed immediately after verification
- No lessons learned entry for the release
- Process errors repeat in subsequent releases

**Prevention:**
- `release.sh close` displays a reminder checklist
- Consider blocking close until retrospective is posted
- Same-day completion reduces fatigue-driven shortcuts

### Don't Defer Lessons

**Bad:** "I'll add lessons learned later"
**Good:** Add lessons immediately while context is fresh

Context loss between release completion and lessons documentation leads to incomplete or missing entries.

## Related Documents

- [60-release.md](60-release.md) - Release phase (preceding phase)
- [75-lessons-learned.md](75-lessons-learned.md) - Accumulated lessons
- [../templates/retrospective.md](../templates/retrospective.md) - Retrospective template
