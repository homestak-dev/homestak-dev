# Quick Reference

Consolidated checklists, commands, and templates for the homestak development lifecycle.

## Sprint Quick Start

### Starting a Sprint

```bash
# 1. Create sprint issue (or use /sprint plan)
gh issue create \
  --title "Sprint: Recursive PVE Stabilization" \
  --label "sprint"

# 2. Create sprint branches in affected repos
for repo in iac-driver ansible; do
  cd ~/homestak-dev/$repo
  git checkout master && git pull
  git checkout -b sprint/recursive-pve
done

# 3. Update sprint issue metadata
# Add branch name, repos, release link to issue body
```

### During Sprint

```bash
# Sync sprint branch with master (periodically)
git fetch origin
git merge origin/master

# Check status across repos
gita ll  # All repos
gita shell "git status"  # Status in all repos
```

### Closing a Sprint

```bash
# 1. Create PRs
gh pr create --title "Sprint 152: Recursive PVE Stabilization" --base master

# 2. After merge, sync local master
git fetch origin
git checkout master
git reset --hard origin/master

# 3. Close sprint issue
gh issue close 152 --repo homestak-dev/homestak-dev
```

## Release Quick Start

```bash
# Initialize release
./scripts/release.sh init --version 0.45 --issue 157

# Preflight checks
./scripts/release.sh preflight

# Validation (choose based on scope)
./scripts/release.sh validate --host father

# Tags [GATE]
./scripts/release.sh tag --dry-run
./scripts/release.sh tag --execute --yes

# Publish [GATE]
./scripts/release.sh publish --dry-run
./scripts/release.sh publish --execute --workflow github --yes

# Verify
./scripts/release.sh verify

# Close
./scripts/release.sh close --execute --yes
```

## Phase Checklists

### Sprint Planning (10)

- [ ] Sprint issue created with metadata section
- [ ] Scope issues linked and classified by tier
- [ ] Sprint branch(es) created in affected repos
- [ ] Linked to release issue (if applicable)
- [ ] Validation scenario selected

### Design (20)

**Simple tier:** Skip

**Standard tier:**
- [ ] Brief approach documented in issue
- [ ] Risk assessed
- [ ] Validation scenario identified

**Complex/Exploratory tier:**
- [ ] Full design document or issue section
- [ ] Interfaces defined
- [ ] Cross-repo dependencies mapped
- [ ] Test plan documented
- [ ] Human approved

### Documentation (25)

- [ ] CLAUDE.md updated (if architecture changed)
- [ ] README updated (if usage changed)
- [ ] Inline comments for complex logic

### Implementation (30)

- [ ] Branch created with appropriate naming
- [ ] Code implements acceptance criteria
- [ ] Unit tests passing (`make test`)
- [ ] CHANGELOG entry added
- [ ] Commits follow message format

### Validation (40)

- [ ] Integration test scope determined
- [ ] External tool assumptions verified
- [ ] Appropriate scenario executed
- [ ] Results documented in issue
- [ ] Performance measured (if claimed)

### Merge (50)

- [ ] PR created with template
- [ ] CHANGELOG in this PR (not deferred)
- [ ] CLAUDE.md updated if needed
- [ ] All checks pass
- [ ] Human approved and merged
- [ ] Local master synced (`git reset --hard origin/master`)

### Sprint Close (55)

- [ ] All scope issues closed
- [ ] Sprint retrospective posted
- [ ] Release issue updated
- [ ] Sprint issue closed

### Release Preflight (61)

- [ ] `release.sh init` run first
- [ ] Git fetch on all repos
- [ ] Working trees clean
- [ ] No existing tags for version
- [ ] Secrets decrypted
- [ ] CHANGELOGs have Unreleased content

### Release CHANGELOG (62)

- [ ] All repos updated with version headers
- [ ] Date matches release date
- [ ] Categories consistent (Features, Bug Fixes, etc.)

### Release Tags (63) [GATE]

- [ ] Human approves tag creation
- [ ] Tags created in dependency order
- [ ] Tags pushed to origin

### Release Packer (64)

- [ ] Images checked (changed or unchanged)
- [ ] If changed: rebuilt and uploaded to `latest`
- [ ] If unchanged: note in release description

### Release Publish (65) [GATE]

- [ ] Human approves release creation
- [ ] Releases created in dependency order
- [ ] All repos have releases

### Release Verify (66)

- [ ] All releases exist
- [ ] Packer assets correct (if applicable)
- [ ] Post-release smoke test passed

### Release AAR (67)

- [ ] After Action Report completed
- [ ] Posted to release issue
- [ ] Follow-up issues created

### Release Housekeeping (68)

- [ ] Merged branches deleted
- [ ] Remote tracking refs pruned
- [ ] Unmerged branches reviewed

### Retrospective (70)

- [ ] Retrospective completed
- [ ] Lessons added to 75-lessons-learned.md
- [ ] Release issue closed

## Tier Quick Reference

| Tier | Branch | Merge | Design | Docs | Validation |
|------|--------|-------|--------|------|------------|
| Simple | `fix/123-desc` | Squash | Skip | Skip | Smoke |
| Standard | `enhance/123-desc` | Squash | Light | If changed | Scenario |
| Complex | `sprint-N/theme` | Merge | Full | Required | Full suite |
| Exploratory | `sprint-N/theme` | Merge | Full + ADR | Required | Full + new |

## Common Commands

### Git

```bash
# Status across repos
gita ll
gita shell "git status"

# Fetch all repos
gita fetch

# Pull all repos (clean trees only)
gita pull

# Check for unmerged branches
for repo in .claude .github ansible bootstrap homestak-dev iac-driver packer site-config tofu; do
  echo "=== $repo ===" && cd ~/homestak-dev/$repo && git branch -r --no-merged
done
```

### GitHub CLI

```bash
# List open issues across org
for repo in .claude .github ansible bootstrap homestak-dev iac-driver packer site-config tofu; do
  echo "=== $repo ===" && gh issue list --repo homestak-dev/$repo
done

# View issue
gh issue view 123 --repo homestak-dev/homestak-dev

# Create PR
gh pr create --title "Title" --body "Body" --base master

# Check PR status
gh pr status
```

### iac-driver

```bash
# List scenarios
./run.sh scenario --help

# Quick validation
./run.sh manifest test -M n1-push -H father

# Tiered validation
./run.sh manifest test -M n2-tiered -H father

# Preflight only
./run.sh --preflight -H father
```

### release.sh

```bash
# Full workflow
./scripts/release.sh init --version 0.45 --issue 157
./scripts/release.sh preflight
./scripts/release.sh validate --host father
./scripts/release.sh tag --dry-run
./scripts/release.sh tag --execute
./scripts/release.sh publish --execute --workflow github
./scripts/release.sh verify
./scripts/release.sh close --execute

# Recovery
./scripts/release.sh resume   # AI-friendly context
./scripts/release.sh status   # Human-readable
./scripts/release.sh audit    # Action log
```

## Templates

### Commit Message

```
<type>(<scope>): <short summary>

<body>

<footer>

Co-Authored-By: Claude <assistant@anthropic.com>
```

Types: `fix`, `feat`, `docs`, `test`, `refactor`, `chore`

### CHANGELOG Entry

```markdown
## Unreleased

### Features
- Add capability description (#123)

### Bug Fixes
- Fix issue description (#124)

### Changes
- Update behavior description (#125)
```

### Issue Comment (Session Save)

```markdown
## Session Update - YYYY-MM-DD HH:MM

**Completed:**
- Item 1
- Item 2

**Next:**
- Item 3

**Decisions:**
- Decision and rationale
```

### Handoff Section

```markdown
## Handoff - YYYY-MM-DD HH:MM

### Current State
- Phase: X
- Branch: sprint-N/theme
- Repos: repo1, repo2

### Decisions Made
| Decision | Choice | Rationale |
|----------|--------|-----------|
| ... | ... | ... |

### Files Modified
- path/to/file.py - Description

### Open Questions
- Question 1

### Next Steps
1. Step 1
2. Step 2
```

## Validation Scenarios

| Scenario | Use When | Duration |
|----------|----------|----------|
| `./run.sh manifest test -M n1-push -H <host>` | Standard changes, docs, CLI | ~2 min |
| `./run.sh manifest test -M n2-tiered -H <host>` | Tiered/PVE/packer changes | ~9 min |
| `./run.sh manifest test -M n3-deep -H <host>` | Full 3-level nesting | ~15 min |

## Repository Order

For releases and cross-repo operations:

```
.github → .claude → homestak-dev → site-config → tofu → ansible → bootstrap → packer → iac-driver
```

## Related Documents

- [00-overview.md](00-overview.md) - Full lifecycle overview
- [05-session-management.md](05-session-management.md) - Session handling
- [75-lessons-learned.md](75-lessons-learned.md) - Historical lessons
