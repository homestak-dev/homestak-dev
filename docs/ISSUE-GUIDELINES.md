# Issue Guidelines

Standards for creating and managing GitHub issues across homestak-dev repositories.

## Issue Types

### Scope Issues

Actual work items representing bugs, enhancements, or features:
- Use standard work type labels (`bug`, `enhancement`, `epic`)
- Assigned to sprints or worked directly on trunk
- Closed when work is complete

### Sprint Issues

Track multi-issue coordinated work (see [10-sprint-planning.md](lifecycle/10-sprint-planning.md)):
- Created via `/sprint plan` command (in any repo)
- Use `sprint` label
- Track branch, repos, scope, and sprint log
- Closed via `/sprint close` command

### Release Issues

Track release planning and execution (see [60-release.md](lifecycle/60-release.md)):
- Created via `/release plan init` command
- Use `release` label
- Accumulate sprint outcomes, track release readiness
- Closed after release completes

## Issue Creation

### Title Format

Use clear, actionable titles:

| Pattern | Example |
|---------|---------|
| `Add <feature>` | Add --dry-run flag to release.sh |
| `Fix <problem>` | Fix guest agent timeout on nested PVE |
| `Update <component>` | Update ansible to support Debian 13 |
| `Remove <item>` | Remove deprecated vm-simple scenario |

**Avoid:**
- Vague titles: "Bug fix", "Improvement", "Update"
- Questions as titles: "Why does X happen?"
- Implementation details: "Refactor X to use Y pattern"

### Description Content

Include:
- **Context:** Why is this needed? What problem does it solve?
- **Acceptance criteria:** How do we know when it's done?
- **Constraints:** Any limitations or scope boundaries?

For bugs, also include:
- Steps to reproduce
- Expected vs actual behavior
- Environment details (host, versions)

## Work Tiers

Classify issues by complexity to guide session management and documentation requirements:

| Tier | Characteristics | Session Strategy |
|------|-----------------|------------------|
| Simple | Quick fix, isolated change | Informal |
| Standard | Clear scope, single repo | Issue comments |
| Complex | Multi-repo, design decisions | Issue + decision log |
| Exploratory | Unknown scope, research needed | Issue + ADR + dead-ends |

See [05-session-management.md](lifecycle/05-session-management.md) for tier-based workflows.

## Labels

### Work Type Labels

Apply exactly one work type label:

| Label | When to Use | Maps to |
|-------|-------------|---------|
| `bug` | Something is broken or incorrect | Bug Fix |
| `enhancement` | Improvement to existing functionality | Minor Enhancement |
| `epic` | Multi-issue effort requiring breakdown | Feature |

**Note:** Pure new features without an epic typically use `enhancement`. Reserve `epic` for efforts spanning multiple issues or repos.

### Coordination Labels

For tracking and coordination issues:

| Label | When to Use |
|-------|-------------|
| `sprint` | Sprint planning and tracking issues |
| `release` | Release planning and coordination issues |

### Modifier Labels

Apply as applicable (zero or more):

| Label | When to Use |
|-------|-------------|
| `documentation` | Primarily documentation changes |
| `refactor` | Code restructuring without behavior change |
| `testing` | Test coverage or testing infrastructure |
| `security` | Security-related changes |
| `breaking-change` | Requires migration or breaks compatibility |

### Status Labels

GitHub defaults (apply as needed):

| Label | When to Use |
|-------|-------------|
| `duplicate` | Issue already exists elsewhere |
| `invalid` | Issue is not valid or misunderstood |
| `wontfix` | Intentionally not addressing |
| `help wanted` | Open for community contribution |
| `good first issue` | Suitable for newcomers |
| `question` | Needs clarification before actionable |

## Labeling Workflow

### At Issue Creation

1. Apply one work type label (`bug`, `enhancement`, or `epic`)
2. Apply relevant modifier labels
3. Leave status labels empty (applied during triage if needed)

### During Sprint Planning

When using `/sprint plan`:
1. Review unlabeled issues in scope
2. Apply/correct work type labels
3. Classify by work tier (Simple/Standard/Complex/Exploratory)
4. Sprint issue automatically gets `sprint` label

### At Issue Close

No label changes needed. Labels remain for historical reference.

## Cross-Repo Issues

For issues affecting multiple repos:

1. **Trunk path (simple changes):** Create in primary repo, reference others
2. **Sprint path (coordinated work):** Use `/sprint plan` to create sprint issue
   - Sprint branches created in each affected repo
   - Sprint issue tracks all repos and scope issues
   - PRs link back to sprint issue

See [00-overview.md](lifecycle/00-overview.md) for when to use each path.

## Examples

### Good Scope Issue

**Title:** Add validation host prerequisites check to preflight

**Labels:** `enhancement`, `testing`

**Description:**
```
## Context
Validation fails on hosts that are bootstrapped but not validation-ready.
Missing: node config, API token, packer images.

## Acceptance Criteria
- [ ] preflight command checks for node config
- [ ] preflight command checks for API token
- [ ] preflight command checks for packer images
- [ ] Clear error messages with remediation steps

## Related
See docs/lifecycle/40-validation.md "Validation Host Prerequisites" section.
```

### Good Sprint Issue

Created via `/sprint plan "Recursive PVE Stabilization" --release 157`

**Title:** Sprint: Recursive PVE Stabilization

**Labels:** `sprint`

**Description:** (populated from template - see [sprint-issue.md](templates/sprint-issue.md))

### Poor Issue

**Title:** Fix bug

**Labels:** (none)

**Description:**
```
Something is broken. Please fix.
```

## Quick Reference

When creating an issue:

```
1. Title: <Verb> <what> [context]
2. Labels:
   - ONE of: bug | enhancement | epic
   - ZERO+ of: documentation | refactor | testing | security | breaking-change
   - IF coordination: sprint | release
3. Description:
   - Context (why)
   - Acceptance criteria (what done looks like)
   - Constraints (scope limits)
4. Tier (for planning):
   - Simple | Standard | Complex | Exploratory
```
