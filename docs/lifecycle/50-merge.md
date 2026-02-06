# Phase: Merge

Merge integrates validated changes into the protected `master` branch through pull request review. The merge strategy differs based on branch type.

## Merge Strategies

| Branch Type | Strategy | Rationale |
|-------------|----------|-----------|
| Trunk fixes (`fix/`, `enhance/`) | **Squash** | Clean history, one commit per change |
| Sprint branches (`sprint/`) | **Merge commit** | Preserve sprint history, coordinated work |
| Documentation | **Squash** | Simple, non-functional |

**Default: Squash merge** for trunk-path work.
**Sprint branches: Merge commit** to preserve the work history.

## Inputs

- Validated feature/sprint branch
- Test results from Validation phase
- Design artifacts (if applicable)

## Activities

### 1. PR Preparation

Create pull request with:

**Title:** `<type>(<scope>): <summary>` (conventional commit format for all PRs — see [ISSUE-GUIDELINES.md](../ISSUE-GUIDELINES.md#title-format))

**Description template:**

```markdown
## Summary
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation
- [ ] Sprint merge

## Changes
- Key change 1
- Key change 2

## Testing
- Unit tests: [passing/updated]
- Integration scenario: [scenario name]
- Validation result: [PASSED]

## Related Issues
Closes #<issue-number>

## Checklist
- [ ] Tests pass locally
- [ ] Integration scenario passes
- [ ] CHANGELOG.md updated
- [ ] CLAUDE.md updated (if architecture changed)
```

### 2. Sprint PR Specifics

For sprint PRs, use the same conventional commit title format as trunk PRs:

**Title:** `feat(controller): Add unified controller daemon with spec/repo serving`

Sprint context goes in the description body, not the title.

**Description additions:**

```markdown
## Sprint Scope
- iac-driver#52 - Recursive action
- iac-driver#53 - ConfigResolver update

## Validation Evidence
- Scenario: `./run.sh test -M n2-quick -H father`
- Result: PASSED
- Report: [link]

## Sprint Issue
Closes #152
```

### 3. Documentation Updates

Verify documentation is current:

| Documentation | When to Update |
|---------------|----------------|
| **CHANGELOG** | User-facing changes (in this PR, not deferred) |
| **CLAUDE.md** | Architecture, workflow, or interface changes |
| **README** | Installation, usage, or features changed |
| **API docs** | Public interfaces changed |

**CHANGELOG in PR, not release:**
- Bad: "I'll update CHANGELOG during release"
- Good: CHANGELOG updated in same PR as feature

### 4. Pre-Merge Verification

Before requesting review:

```bash
# Rebase on current master (trunk PRs)
git fetch origin
git rebase origin/master

# Or merge master into sprint branch (sprint PRs)
git fetch origin
git merge origin/master

# Verify tests still pass
make test

# Check for conflicts
git status
```

### 5. Human Review and Merge

> **⚠️ HUMAN GATE:** Stop here. Present PRs to user and await explicit approval before merging.
> Ruleset failures are checkpoints, not obstacles to bypass.

PR requires human action:
- Review code changes
- Review test coverage
- Review documentation updates
- Approve PR
- Merge PR using appropriate strategy:
  - **Squash and merge** for trunk PRs
  - **Create a merge commit** for sprint PRs

### 6. Post-Merge Sync

**Critical:** After merge, sync local master:

```bash
git fetch origin
git checkout master
git reset --hard origin/master
```

**Why sync is required:** After GitHub merges a PR (especially squash), the local `master` branch diverges from `origin/master` because commit SHAs differ. Without `git reset --hard`, subsequent operations show the branch as "ahead" even though content is identical.

### 7. Clean Up Branches

```bash
# Delete local feature/sprint branch
git branch -d feature-branch

# Prune remote tracking refs
git remote prune origin

# For sprint branches, clean up in all affected repos
for repo in iac-driver ansible; do
  cd ~/homestak-dev/$repo
  git checkout master
  git branch -d sprint/recursive-pve
  git push origin --delete sprint/recursive-pve
done
```

### 8. Update Sprint Issue

For sprint PRs, update the sprint issue to reflect merge:

```markdown
## Sprint Log

### YYYY-MM-DD - Merged
PR #55 merged to master
- All scope issues delivered
- Proceeding to sprint close
```

## Cross-Repo Merges

For sprints touching multiple repos:

### Merge Order

Follow [repository dependency order](00-overview.md#repository-dependency-order):

```
site-config → tofu → ansible → bootstrap → packer → iac-driver
```

Upstream repos merge first so downstream can reference their changes.

### Coordinated Merge

1. Create PRs in all affected repos (`GH_TOKEN=$HOMESTAK_BOT_TOKEN gh pr create`)
2. **Immediately** enable auto-merge on each PR (`gh pr merge --auto --squash <pr> --repo homestak-dev/<repo>` — use default auth, not bot)
3. Review all PRs together for consistency
4. Approve PRs in dependency order
5. Sync local master in each repo after merge

## Context Transition

After all sprint PRs are merged, prepare for release or sprint close:

**Run `/compact`** to free context for next phase:
- Release operations are tool-heavy
- Fresh context reduces errors

**When to compact:**
- After all sprint PRs merged
- Before `/release-preflight`
- Especially important for multi-repo releases

## Outputs

- Merged PR(s)
- Updated `master` branch(es)
- Documentation current
- Feature/sprint branches cleaned up

## Checklist: Merge Complete

### Trunk PR
- [ ] PR created with template
- [ ] CHANGELOG updated
- [ ] CLAUDE.md updated (if applicable)
- [ ] Rebased on current master
- [ ] All checks pass
- [ ] Human approved
- [ ] Squash merged
- [ ] Local master synced

### Sprint PR
- [ ] PR created with sprint template (bot token)
- [ ] Auto-merge enabled on each PR (default auth)
- [ ] All scope issues referenced
- [ ] Validation evidence linked
- [ ] CHANGELOG updated
- [ ] CLAUDE.md updated
- [ ] Master merged into branch
- [ ] All checks pass
- [ ] Human approved
- [ ] Merge commit created
- [ ] Local master synced
- [ ] Sprint branches cleaned up
- [ ] Sprint issue updated

## Definition of Done

### Code Complete
- Implementation matches specification
- Error handling covers realistic scenarios
- No hardcoded values that should be configurable

### Tested
- Unit tests for logic (where applicable)
- Integration scenario passes

### Documented
- CHANGELOG entry in PR
- CLAUDE.md updated for architectural changes
- CLI help text reflects new options

## Related Documents

- [40-validation.md](40-validation.md) - Validation before merge
- [55-sprint-close.md](55-sprint-close.md) - Sprint wrap-up after merge
- [60-release.md](60-release.md) - Release coordination
- [80-reference.md](80-reference.md) - Quick reference
