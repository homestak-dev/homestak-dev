# Issue Guidelines

Standards for creating and managing GitHub issues across homestak-dev repositories.

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

## Labels

### Work Type Labels

Apply exactly one work type label:

| Label | When to Use | Maps to |
|-------|-------------|---------|
| `bug` | Something is broken or incorrect | Bug Fix |
| `enhancement` | Improvement to existing functionality | Minor Enhancement |
| `epic` | Multi-issue effort requiring breakdown | Feature |

**Note:** Pure new features without an epic typically use `enhancement`. Reserve `epic` for efforts spanning multiple issues or repos.

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

### Release Label

| Label | When to Use |
|-------|-------------|
| `release` | Release planning and coordination issues |

Used for release plan issues (e.g., "v0.20 Release Planning - Theme").

## Labeling Workflow

### At Issue Creation

1. Apply one work type label (`bug`, `enhancement`, or `epic`)
2. Apply relevant modifier labels
3. Leave status labels empty (applied during triage if needed)

### During Sprint Planning

1. Review unlabeled issues
2. Apply/correct work type labels
3. Add `release` label to release planning issues

### At Issue Close

No label changes needed. Labels remain for historical reference.

## Cross-Repo Issues

For issues affecting multiple repos:

1. Create the issue in the **primary** repo (where most work occurs)
2. Reference related repos in the description
3. Use `epic` label if coordinating work across repos
4. Link to sub-issues in other repos if created

## Examples

### Good Issue

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
3. Description:
   - Context (why)
   - Acceptance criteria (what done looks like)
   - Constraints (scope limits)
```
