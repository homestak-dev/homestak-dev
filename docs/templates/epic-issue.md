# Epic Issue Template

Create a new issue using this template.

**Title format:** `Epic: {Theme}`

Examples:
- `Epic: CI/CD strategy`
- `Epic: Manifest-based Orchestration Architecture`

---

## Overview

{1-2 sentence summary of the epic's purpose and scope.}

**Design doc:** {link to primary design document, if any}

## Vision

{Brief description of the end state. Diagrams or tables encouraged.}

## Phased Implementation

Track phases and their sprint issues. Reference sprint tracking issues by number when they exist; leave the Sprint cell empty until a sprint is planned.

| Phase | Issues | Sprint | Scope | Status |
|-------|--------|--------|-------|--------|
| 1 | #N | #M | {scope summary} | {status} |
| 2 | #N | | {scope summary} | Blocked on Phase 1 |

**Status values:** Complete, Active, Planned, Blocked on Phase N, Independent

## Sub-tasks

- [ ] #N - {description} ({sprint issue ref if exists})
- [ ] #M - {description}

## Related Issues

| Issue | Disposition |
|-------|-------------|
| #N | {how this issue relates: expanded, superseded, independent, etc.} |

## Design Decisions

- **{Decision}**: {rationale}

<!--
Tips:
- Epics track multi-issue efforts requiring breakdown
- Apply the `epic` label
- Use scope issues for individual work items (<Verb> <what> format)
- Use sprint issues (Sprint: <Theme>) for coordinated execution
- Cross-reference sprint tracking issues by number, not ordinal (e.g., "#146" not "Sprint 1")
- Keep the Phased Implementation table updated as work progresses
- Link to design docs in docs/designs/ for architectural context
-->
