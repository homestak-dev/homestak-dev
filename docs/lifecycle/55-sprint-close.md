# Phase: Sprint Close

Sprint close wraps up a completed sprint: verifies scope completion, captures retrospective, updates release tracking, and closes the sprint issue.

## When to Use

After all sprint scope issues have been merged to master and validated.

## Inputs

- Completed sprint with all PRs merged
- Sprint issue with scope checklist
- Validation results from sprint
- Active release issue (if sprint is part of a release)

## Activities

### 1. Verify Scope Completion

Check all scope issues are closed:

```markdown
## Scope
| Issue | Tier | Status |
|-------|------|--------|
| iac-driver#52 | Complex | ✅ done |
| iac-driver#53 | Standard | ✅ done |
| ansible#18 | Standard | ✅ done |
```

If any issues remain open:
- Determine if truly incomplete or just not auto-closed
- Close issues with reference to merged PR
- Or document deferral in sprint log

### 2. Document Validation Results

Update sprint log with validation outcome:

```markdown
## Sprint Log

### YYYY-MM-DD - Validation Complete
**Scenario:** `./run.sh test -M n2-tiered -H father`
**Host:** father
**Result:** PASSED

Report: [Link to report in iac-driver/reports/]
```

This creates the validation evidence needed for release.

### 3. Sprint Retrospective

Complete a brief retrospective as a **closing comment** (not in the issue body). This mirrors the release retrospective pattern and keeps the issue body focused on planning/execution state.

```markdown
## Sprint Retrospective

### What Worked Well
- Clear scope definition upfront
- Branch strategy prevented conflicts

### What Could Improve
- Underestimated ansible role complexity
- Should have validated earlier

### Follow-up Items
- [ ] Create issue for discovered tech debt
- [ ] Update CLAUDE.md with new pattern

---
**Started:** YYYY-MM-DD
**Completed:** YYYY-MM-DD
```

**Tier-based depth:**

| Tier | Retrospective Depth |
|------|---------------------|
| Simple | Skip (no sprint) |
| Standard | 2-3 bullet points per section |
| Complex | Full retrospective |
| Exploratory | Full retrospective + ADR summary |

### 4. Update Release Issue

If sprint is linked to a release issue, add a completion comment:

```markdown
## Sprint 152 Complete

**Scope delivered:**
- iac-driver#52 - Recursive action implementation
- iac-driver#53 - ConfigResolver update
- ansible#18 - SSH key handling

**Validation:**
- Scenario: `./run.sh test -M n2-tiered -H father`
- Result: PASSED
- Report: [link]

**Release readiness:** Ready for inclusion in release
```

Update the release issue's scope checklist to mark this sprint complete.

### 5. Archive Decision Log (Exploratory Tier)

For Exploratory tier sprints, ensure decisions and dead-ends are preserved:

```markdown
## Decision Log Archive

### Decision: State Storage
**Options considered:**
1. Local state file (`.sprint-state.json`)
2. Issue as state

**Chosen:** Issue as state
**Rationale:** Self-describing, no git pollution, accessible to all tools

### Dead Ends
- Approach A: Local state file (sync issues)
- Approach B: Centralized service (over-engineering)
```

### 6. Clean Up Sprint Branches

After PRs are merged, delete sprint branches:

```bash
BRANCH="sprint/recursive-pve"
for repo in iac-driver ansible; do
  cd ~/homestak-dev/$repo
  git checkout master
  git branch -d $BRANCH 2>/dev/null  # Delete local
  git push origin --delete $BRANCH 2>/dev/null  # Delete remote
done
```

### 7. Update Sprint Issue Status

```markdown
## Metadata
| Field | Value |
|-------|-------|
| Branch | ~~`sprint/recursive-pve`~~ (deleted) |
| Release | #150 |
| Status | complete |
| Tier | Complex |
```

### 8. Close Sprint Issue

Close with retrospective as the closing comment:

```bash
gh issue close 152 \
  --comment "## Sprint Retrospective

### What Worked Well
- ...

### What Could Improve
- ...

### Follow-up Items
- [ ] ...

---
**Started:** YYYY-MM-DD
**Completed:** YYYY-MM-DD"
```

## Deferred Items

If scope items were deferred:

```markdown
## Deferred to Future Sprint
- iac-driver#54 - Performance optimization (out of time)
- ansible#19 - Additional role tests (lower priority)
```

Create new issues or update existing ones with deferral rationale.

## Release Readiness

A sprint contributes to release readiness when:

- [ ] All scope issues merged
- [ ] Validation scenario passed
- [ ] Validation report available
- [ ] Release issue updated
- [ ] No blocking issues discovered

The release phase (60) checks for this evidence before proceeding.

## Outputs

- Scope verified complete (or deferrals documented)
- Validation results documented
- Sprint retrospective completed
- Release issue updated
- Sprint branches cleaned up
- Sprint issue closed

## Checklist: Sprint Close Complete

- [ ] All scope issues verified closed
- [ ] Validation results documented in sprint log
- [ ] Related design docs in `docs/designs/` reviewed and updated if needed
- [ ] Sprint retrospective completed
- [ ] Release issue updated with outcomes
- [ ] Decision log archived (Exploratory tier)
- [ ] Sprint branches deleted
- [ ] Sprint issue status updated to `complete`
- [ ] Sprint issue closed

## Trunk Path

For trunk-path work (Simple tier), there's no sprint to close. The work is complete when the PR is merged.

## Related Documents

- [10-sprint-planning.md](10-sprint-planning.md) - Sprint setup
- [50-merge.md](50-merge.md) - PR merge process
- [60-release.md](60-release.md) - Release coordination
- [69-release-retro.md](69-release-retro.md) - Release retrospective
