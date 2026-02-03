# Session Management

Session management is a cross-cutting concern that applies to all lifecycle phases. This document provides guidance for maintaining context across Claude Code sessions.

## Purpose

AI-assisted development sessions have limited context windows. Effective session management ensures:
- Work continuity across context compactions
- Knowledge preservation during long sprints
- Smooth handoffs between sessions
- Tier-appropriate documentation

## Session Types

| Type | Duration | Context Strategy |
|------|----------|------------------|
| **Quick** | < 30 min | No special handling needed |
| **Standard** | 30 min - 2 hours | Checkpoint before compaction |
| **Extended** | > 2 hours | Multiple checkpoints, issue updates |
| **Multi-session** | Spans days | Full session save/resume cycle |

## Context Compaction

When Claude's context window fills, compaction summarizes earlier content. This can cause loss of:
- Specific file contents and line numbers
- Decisions made earlier in the session
- Intermediate states and reasoning

### Pre-Compaction Checklist

Before running `/compact`:

- [ ] Commit or stash any uncommitted changes
- [ ] Post significant decisions to the issue
- [ ] Note current phase and next steps in issue comment
- [ ] For Complex/Exploratory tiers: update handoff section

### Compaction Triggers

Run `/compact` proactively when:
- About to start a new phase (e.g., moving from Merge to Release)
- Context becomes sluggish or Claude forgets recent context
- Significant work block completed
- Before multi-tool operations (release, validation)

## Tier-Based Session Strategy

### Simple Tier

No special session management. Work is quick enough to complete in one session.

### Standard Tier

Use issue comments to preserve context:

```markdown
## Session Update - 2024-01-15 14:30

**Completed:**
- Implemented fix for #123
- Unit tests passing

**Next:**
- Run integration test
- Create PR

**Decisions:**
- Used existing error handler pattern from src/common.py
```

### Complex Tier

Use dedicated handoff sections in the sprint issue:

```markdown
## Handoff - 2024-01-15 16:00

### Current State
- Phase: Implementation (30%)
- Branch: sprint/recursive-pve
- Repos touched: iac-driver, ansible

### Decisions Made
| Decision | Choice | Rationale |
|----------|--------|-----------|
| State storage | Issue, not file | Self-describing, no git pollution |
| Auth model | Network trust for dev | Simpler, acceptable risk |

### Files Modified
- `iac-driver/src/actions/recursive.py` - New action
- `ansible/roles/nested-pve/tasks/main.yml` - SSH key handling

### Open Questions
- Timeout for N+1 nesting levels?

### Next Steps
1. Complete SSH key propagation
2. Test 2-level nesting
3. Extend to 3-level
```

### Exploratory Tier

Same as Complex, plus:

```markdown
## Dead Ends Log

### Approach A: Local State File (Abandoned)
- **Tried:** Store sprint state in `.sprint-state.json`
- **Problem:** Git pollution, sync issues across repos
- **Lesson:** Use issue-as-state pattern instead

### Approach B: Centralized Config (Abandoned)
- **Tried:** Single config service
- **Problem:** Over-engineering for the problem size
- **Lesson:** Start simple, add complexity when proven needed
```

## Session Save/Resume

### `/session save`

Capture session state before compaction or ending work:

**For Standard tier:**
- Posts structured comment to issue
- Includes completed items, next steps, decisions

**For Complex/Exploratory tier:**
- Updates handoff section in sprint issue
- Captures file modifications, open questions
- Records any dead ends discovered

### `/session resume`

Load session state when starting new session:

**Actions:**
1. Fetch sprint issue content
2. Parse metadata (branch, repos, status)
3. Read recent handoff section
4. Load relevant file context
5. Present current state and next steps

### `/session checkpoint`

Mid-session save without ending session:

- Useful for long sessions with multiple work blocks
- Updates issue with incremental progress
- Lighter weight than full save

## Sprint Issue as Session State

The sprint issue IS the session state. No separate state files.

### Metadata Section

```markdown
## Metadata
| Field | Value |
|-------|-------|
| Branch | `sprint/recursive-pve` |
| Release | #150 |
| Status | in_progress |
| Tier | Complex |
```

### Scope Section

```markdown
## Scope
| Issue | Tier | Status |
|-------|------|--------|
| iac-driver#52 | Complex | in_progress |
| iac-driver#53 | Standard | done |
| ansible#18 | Standard | not_started |
```

### Sprint Log Section

```markdown
## Sprint Log

### 2024-01-15 - Sprint Init
Created branches, linked to release #150

### 2024-01-16 - Implementation
Completed SSH key handling (iac-driver#52 partial)
Decisions: Use existing `SyncReposToVMAction` pattern

### 2024-01-17 - Validation
vm-roundtrip passed, nested-pve-roundtrip in progress
```

## Multi-Session Sprints

When work spans multiple sessions:

### Session Start Ritual

1. **Check sprint issue** - Read metadata and recent log entries
2. **Verify branch state** - `git status` on affected repos
3. **Review handoff** - Load context from last session
4. **Identify next action** - Pick up where you left off

### Session End Ritual

1. **Commit or stash** - No uncommitted changes left behind
2. **Update sprint log** - What was accomplished
3. **Write handoff** - Context for next session
4. **Post to issue** - Ensure persistence

### Context Recovery

If context is lost unexpectedly:

```bash
# Check sprint issue for state
gh issue view 152 --repo homestak-dev/homestak-dev

# Check branch state across repos
gita shell "git status"
gita shell "git log --oneline -3"

# Check for recent commits
gita shell "git log --oneline --since='24 hours ago'"
```

## Release Session Recovery

For releases specifically, additional recovery tools exist:

```bash
# Get AI-friendly recovery context
./scripts/release.sh resume

# Check release progress
./scripts/release.sh status

# View action history
./scripts/release.sh audit
```

See [60-release.md](60-release.md) for release-specific session management.

## Best Practices

### Do

- Commit frequently with meaningful messages
- Post decisions to issues as they're made
- Use structured formats for handoffs
- Checkpoint before risky operations

### Don't

- Leave uncommitted changes across sessions
- Rely on Claude's memory across compactions
- Skip documentation for "obvious" decisions
- Defer session saves until "later"

## Related Documents

- [00-overview.md](00-overview.md) - Work tiers and phase applicability
- [10-sprint-planning.md](10-sprint-planning.md) - Sprint issue creation
- [55-sprint-close.md](55-sprint-close.md) - Sprint retrospective
- [../templates/sprint-issue.md](../templates/sprint-issue.md) - Sprint issue template
