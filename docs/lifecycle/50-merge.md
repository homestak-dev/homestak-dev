# Phase: Merge

Merge integrates validated changes into the protected `master` branch through pull request review. This phase applies to all work types.

## Inputs

- Validated feature branch
- Test results from Validation phase
- Design artifacts (if applicable)

## Activities

### 1. PR Preparation

Create pull request with:

**Title:** `<type>(<scope>): <summary>` (matches primary commit)

**Description template:**
```markdown
## Summary
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation
- [ ] Other: <!-- describe -->

## Changes
- Key change 1
- Key change 2

## Testing
Summary of validation performed.
- Unit tests added/modified
- Integration test scenario used (e.g., vm-roundtrip, nested-pve-roundtrip)
- Manual verification steps

## Related Issues
Closes #<issue-number>

## Checklist
- [ ] Tests pass locally
- [ ] Integration test scenario identified and passes
- [ ] External tool assumptions verified (test actual CLI behavior)
- [ ] CHANGELOG.md updated (if user-facing change)
- [ ] CLAUDE.md updated (if architecture/workflow changed)
- [ ] Performance claims measured (before/after timing, if applicable)
- [ ] Prerequisites documented (configs, artifacts, permissions)
```

### 2. Documentation Updates

Assess and update cross-cutting documentation:

| Documentation | When to Update |
|---------------|----------------|
| **CHANGELOG** | User-facing changes (should already be done in Implementation phase) |
| **CLAUDE.md** | Architecture, workflow, or interface changes |
| **README** | Installation, usage, or features changed |
| **API docs** | Public interfaces changed |
| **Migration guides** | Breaking changes introduced |

**CHANGELOG in PR, not release:**
- Bad: "I'll update CHANGELOG during release"
- Good: CHANGELOG updated in same PR as feature

### 3. CLAUDE.md Update Requirements

Update repo's CLAUDE.md when:
- Architecture changes
- New CLI options added
- New scenarios added
- New actions or patterns introduced
- Configuration schema changes

Verify accuracy after changes using the [CLAUDE Guidelines](../CLAUDE-GUIDELINES.md).

### 4. Pre-Merge Verification

Before requesting review:
- Rebase on current `master` if needed
- Verify all tests still pass
- Confirm no merge conflicts
- Review diff for unintended changes

### 5. Human Review and Merge

PR requires human action:
- Review code changes
- Review test coverage
- Review documentation updates
- Approve PR
- Merge PR (see Merge Strategy below)

### Merge Strategy

| PR Type | Strategy | Rationale |
|---------|----------|-----------|
| Most PRs | **Squash** | Clean history, one logical change per merge |
| Well-structured multi-commit PRs | **Merge commit** | Preserves meaningful commit breakdown |
| Rebase | **Avoid** | Complicates history for reviewers |

**Default: Squash merge.** Use merge commits only when the PR has intentionally structured commits that tell a story (e.g., "refactor X", then "add Y", then "update tests").

**Single-commit PRs:** Either method produces the same result; squash is fine.

### 6. Post-Merge Verification

After merge:
- Verify `master` branch CI passes
- Confirm changes appear as expected
- Delete feature branch (optional, per convention)

## PR Checklist (Copy to PR)

```markdown
## PR Readiness Checklist

See [50-merge.md](https://github.com/homestak-dev/homestak-dev/blob/master/docs/lifecycle/50-merge.md) for full guidance.

- [ ] Feature tested end-to-end (not just unit tests)
- [ ] External tool assumptions verified (test actual CLI behavior)
- [ ] CHANGELOG entry in this PR
- [ ] CLAUDE.md updated if architecture changed
- [ ] Performance claims measured (before/after timing)
- [ ] Prerequisites documented (configs, artifacts, permissions)
- [ ] Integration test scenario identified
```

## Review Checklists

### Author Self-Review

Before requesting review:
- [ ] I ran the integration test myself
- [ ] I verified external tool commands work
- [ ] I updated CHANGELOG in this PR
- [ ] I documented any prerequisites
- [ ] I tested with real infrastructure, not mocks

### Reviewer Checklist

When reviewing:
- [ ] Code logic reviewed
- [ ] Test coverage adequate
- [ ] Documentation accurate
- [ ] No assumptions about external tools
- [ ] CHANGELOG entry present and accurate

## Definition of Done

### Code Complete
- Implementation matches specification
- Error handling covers realistic scenarios
- No hardcoded values that should be configurable

### Tested
- Unit tests for logic (where applicable)
- Integration test scenario passes

### Documented
- CHANGELOG entry in PR (not deferred to release)
- CLAUDE.md updated for architectural changes
- CLI help text (`--help`) reflects new options
- Examples for non-obvious usage

## Outputs

- Merged PR
- Updated `master` branch
- Global documentation current
- Feature branch cleaned up

## Checklist: Merge Complete

- [ ] PR created with complete description
- [ ] CHANGELOG updated (if applicable)
- [ ] CLAUDE.md updated (if applicable)
- [ ] API docs updated (if applicable)
- [ ] Rebased on current master
- [ ] All checks pass
- [ ] Human reviewed and approved
- [ ] PR merged
- [ ] Post-merge CI verified
