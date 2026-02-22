# Phase: Implementation

Implementation covers development, unit testing, and code-level documentation. This phase applies to all work tiers.

## Inputs

- Approved design (or direct from Planning for Simple tier)
- Acceptance criteria
- Existing codebase

## Branch Strategy by Path

| Path | Branch Type | From |
|------|-------------|------|
| Trunk | Feature branch | `master` |
| Sprint | Sprint branch | Already created in Planning |

## Activities

### 1. Branch Creation (Trunk Path)

For trunk-path work (Simple/Standard tier), create a feature branch:

```bash
git checkout master
git pull origin master
git checkout -b <branch-name>
```

**Branch naming conventions:**
- Bug fix: `fix/<issue-number>-<brief-description>`
- Enhancement: `enhance/<issue-number>-<brief-description>`
- Feature: `feature/<issue-number>-<brief-description>`

Examples:
- `fix/42-null-pointer-handler`
- `enhance/108-improve-logging`
- `feature/15-user-authentication`

### 1b. Sprint Branch (Sprint Path)

For sprint-path work (Complex/Exploratory tier), the branch was created during Planning:

```bash
git checkout sprint/recursive-pve
git pull origin sprint/recursive-pve
```

**Note:** For small fixes without associated issues, the issue number is optional.

### 2. Development

Implement changes following:
- Repository coding standards
- Existing patterns and conventions
- Design specifications (if applicable)

**Principles:**
- Small, focused commits
- Working state at each commit when possible
- Address one concern per commit

### 2b. Status Updates (Sprint Path)

For sprint-path work, update scope issues and the sprint issue at milestones — don't batch updates to the end.

| Trigger | Update scope issue | Update sprint issue |
|---------|-------------------|-------------------|
| Start working on a scope issue | Mark `in_progress` | Update sprint log |
| Implementation complete for a scope issue | Comment with summary | Update scope table status |
| Tests passing for a scope issue | Attach test results (step 3) | — |
| All scope issues complete | — | Ready for validation |

**Cross-reference guidance:**
- Use the most granular issue reference available: "fixed in iac-driver#176" not "fixed in sprint" or "fixed in release v0.50"
- Don't reference releases that haven't shipped — a release in planning is not a fact
- When updating scope issues, check if `docs/designs/` has a related design doc that needs updating

### 3. Unit Testing

- Write or update unit tests for changed code
- Achieve coverage appropriate to change risk
- Tests must pass locally before proceeding
- **Attach test results to the originating issue** as a comment

**When to write unit tests:**

| Change Type | Unit Tests Required? | Notes |
|-------------|---------------------|-------|
| CLI argument parsing | Yes | Test flag combinations, edge cases |
| New Python module | Yes | Test logic in isolation |
| Shell script functions | Yes (bats) | Test argument handling, output |
| Ansible role | No | Use integration test (playbook run) |
| Tofu module | No | Use integration test (`./run.sh manifest test -M n1-push`) |
| Documentation only | No | Review is sufficient |
| Configuration changes | No | Integration test validates |

**Run tests locally:**
```bash
make test  # Run unit tests for the current repo
make lint  # Run linters (if available)
```

**Test frameworks by repo:**

| Repo | Framework | Test Command | Location |
|------|-----------|--------------|----------|
| packer | bats-core | `make test` | `test/*.bats` |
| iac-driver | pytest | `make test` | `tests/test_*.py` |
| bootstrap | bats-core | `make test` | `tests/*.bats` |
| homestak-dev | bats-core | `make test` | `test/*.bats` |

**Test file conventions:** Follow repository patterns (e.g., `test_*.py` for Python, `*.bats` for bash)

**Bats vs shell scripts:**

| Type | Purpose | When to Use |
|------|---------|-------------|
| Bats tests (`*.bats`) | CI-friendly unit tests | Argument parsing, output validation, error handling |
| Shell scripts (`test_*.sh`) | Manual integration tests | End-to-end flows, network operations, multi-step workflows |

Bats tests run in CI on every push/PR. Shell integration tests are run manually before merge.

**CI enforcement:** Unit tests run automatically on push/PR to master. PRs with failing tests will not pass CI checks.

**Test results reporting:** After tests pass, post a comment on the issue with:
- Test command run
- Summary of results (passed/failed counts)
- Any relevant output or coverage metrics

This creates an audit trail and demonstrates that testing was completed.

### 4. Code Documentation

- Add/update docstrings and inline comments
- Document non-obvious logic
- Update README or module docs if public interfaces change

### 5. CHANGELOG Update

**Update CHANGELOG in the same PR as code changes** - do not defer to release time.

- Use correct verb (Add, Fix, Change, Remove)
- Reference issue number
- Place under `## Unreleased` section
- **Do NOT add version headers** (`## vX.Y - YYYY-MM-DD`) - those are added during [Release Phase 2](60-release.md#phase-2-changelogs)

```markdown
## Unreleased

### Features
- Add foo capability (#123)

### Bug Fixes
- Fix bar issue (#124)
```

### 6. Commit Practices

**Commit message format:**
```
<type>(<scope>): <short summary>

<optional body>

<optional footer: issue references>
```

**Types:** `fix`, `feat`, `docs`, `test`, `refactor`, `chore`

**Examples:**
```
fix(auth): handle expired token gracefully

Previously, expired tokens caused an unhandled exception.
Now returns 401 with clear error message.

Fixes #42
```

```
feat(api): add user profile endpoint

Implements GET /users/{id}/profile with basic user info.
Includes unit tests and OpenAPI documentation.

Closes #15
```

**Claude Code commits:** Include co-author line:
```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Human Review Checkpoint

Before proceeding to Validation:
- Summarize implementation for human review
- Highlight any deviations from design
- Note areas of uncertainty or risk
- Address feedback before proceeding

## Outputs

- Feature branch with committed changes
- Unit tests passing
- Code documentation updated
- CHANGELOG entry added
- Human acknowledgment to proceed

## Checklist: Implementation Complete

- [ ] Branch created with appropriate naming
- [ ] Code changes implement acceptance criteria
- [ ] Unit tests written/updated and passing
- [ ] Test results attached to originating issue
- [ ] Code documentation updated
- [ ] CHANGELOG entry added in this PR
- [ ] Commits follow message format
- [ ] No obvious issues (linting, type errors)
- [ ] Human reviewed implementation summary
