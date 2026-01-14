# Phase: Implementation

Implementation covers development, unit testing, and code-level documentation. This phase applies to all work types.

## Inputs

- Approved design (or direct from Planning for bug fixes)
- Acceptance criteria
- Existing codebase

## Activities

### 1. Branch Creation

Create a feature branch from `master`:
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

### 3. Unit Testing

- Write or update unit tests for changed code
- Achieve coverage appropriate to change risk
- Tests must pass locally before proceeding
- **Attach test results to the originating issue** as a comment

**Test file conventions:** Follow repository patterns (e.g., `test_*.py`, `*.test.js`)

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
Co-Authored-By: Claude <assistant@anthropic.com>
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
