# Sprint Issue Template

Create a new issue in `homestak-dev` repo with this template.

**Title format:** `Sprint {issue#}: {Theme}`

Examples:
- `Sprint 152: Recursive PVE Stabilization`
- `Sprint 155: CI/CD Phase 2`

---

## Metadata

| Field | Value |
|-------|-------|
| Branch | `sprint-{issue#}/{theme}` |
| Release | #{release-issue} |
| Status | planning |
| Tier | {Simple/Standard/Complex/Exploratory} |

## Repos

- [ ] {repo1} - branch created
- [ ] {repo2} - branch created

## Scope

| Issue | Tier | Status | Notes |
|-------|------|--------|-------|
| repo#N | Complex | not_started | Main focus |
| repo#M | Standard | not_started | Dependency |

## Implementation Order

1. **repo#N** - Description (no dependencies)
2. **repo#M** - Description (depends on #N)

## Validation

**Scenario:** `{scenario-name}`
**Host:** {hostname}
**Rationale:** {why this scenario}

## Sprint Log

### YYYY-MM-DD - Sprint Init
- Created branches
- Linked to release #{N}

<!-- Add entries as work progresses -->

## Notes

<!-- Optional: deferred scope, constraints, context -->

---
**Started:** YYYY-MM-DD
**Completed:** YYYY-MM-DD

<!--
Retrospective goes in closing comment, not body.
See docs/lifecycle/55-sprint-close.md for format.
-->
