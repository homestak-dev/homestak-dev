# Phase: Sprint Planning

Sprint planning establishes scope, creates tracking structures, and sets up branches for focused work. This phase applies to all work requiring coordination beyond a simple fix.

## When to Use Sprint Planning

| Scenario | Use Sprint Planning? |
|----------|---------------------|
| Single bug fix | No - trunk path |
| Doc update | No - trunk path |
| Single-issue enhancement (Simple tier) | No - trunk path |
| Multi-issue work | Yes |
| Complex/Exploratory work | Yes |
| Cross-repo changes | Yes |

For trunk-path work, skip this phase and go directly to Implementation.

## Inputs

- Human-provided sprint scope (issues, features, priorities)
- Work tier classification (from [00-overview.md](00-overview.md))
- Repository issue tracker state
- Previous sprint retrospective (if applicable)
- Active release issue (if targeting a specific release)

## Activities

### 1. Create Sprint Issue

Create a GitHub issue using the [Sprint Issue Template](../templates/sprint-issue.md):

```bash
gh issue create \
  --title "Sprint: Recursive PVE Stabilization" \
  --label "sprint" \
  --body "$(cat docs/templates/sprint-issue.md)"
```

**Title format:** `Sprint: {Theme}`

### 2. Populate Metadata Section

```markdown
## Metadata
| Field | Value |
|-------|-------|
| Branch | `sprint/recursive-pve` |
| Release | #150 |
| Status | planning |
| Tier | Complex |
```

- **Branch**: Will be created in Step 5
- **Release**: Link to release issue if targeting a specific release
- **Status**: `planning` → `in_progress` → `complete`
- **Tier**: From [Work Tiers](00-overview.md#work-tiers)

### 3. Define Scope

List issues to be addressed in this sprint:

```markdown
## Scope
| Issue | Tier | Status | Notes |
|-------|------|--------|-------|
| iac-driver#52 | Complex | not_started | Main focus |
| iac-driver#53 | Standard | not_started | Dependency |
| ansible#18 | Standard | not_started | Required for #52 |
```

For each issue:
- Verify acceptance criteria are clear
- Classify by tier (Simple/Standard/Complex/Exploratory)
- Identify dependencies between issues
- Flag items needing clarification

**Always include a doc cleanup issue.** Every sprint should have a Simple-tier "Update docs and cross-refs" issue in homestak-dev to cover CLAUDE.md updates, CHANGELOG entries, and cross-repo reference fixes. Create it during planning so it's not forgotten at the end. See [ISSUE-GUIDELINES.md](../ISSUE-GUIDELINES.md#issue-placement) for issue placement conventions.

### 4. Identify Affected Repos

```markdown
## Repos
- [ ] iac-driver - branch created
- [ ] ansible - branch created
```

### 5. Create Sprint Branches

Create the same branch in each affected repo:

```bash
BRANCH="sprint/recursive-pve"
for repo in iac-driver ansible; do
  cd ~/homestak-dev/$repo
  git checkout master && git pull origin master
  git checkout -b $BRANCH
  git push -u origin $BRANCH
done
```

Update issue metadata with branch name and check off repos.

### 6. Dependency Mapping

Order issues by dependencies:

```markdown
## Implementation Order
1. **ansible#18** - SSH key handling (no dependencies)
2. **iac-driver#53** - ConfigResolver update (depends on #18)
3. **iac-driver#52** - Recursive action (depends on #53)
```

Follow [repository dependency order](00-overview.md#repository-dependency-order) for cross-repo work.

### 7. Validation Scenario Selection

Select based on sprint scope:

| Sprint Scope | Scenario | When to Use |
|--------------|----------|-------------|
| Documentation, CLI, process | `./run.sh test -M n1-basic-v2 -H <host>` | No IaC code changes |
| Tofu/ansible changes | `./run.sh test -M n1-basic-v2 -H <host>` | Standard VM provisioning |
| Manifest/operator changes | `./run.sh test -M n2-quick-v2 -H <host>` | Tiered topology code |
| PVE/nested/packer changes | `./run.sh test -M n2-quick-v2 -H <host>` | Full stack validation |

Document in sprint issue:

```markdown
## Validation
**Scenario:** `./run.sh test -M n2-quick-v2 -H father`
**Host:** father
**Rationale:** Sprint includes nested-pve changes
```

### 8. Link to Release Issue

If this sprint is part of a planned release:

```markdown
## Release
Targeting: #150 (v0.45 Release)
```

Add a comment to the release issue linking back to this sprint.

### 9. Update Status

Change status from `planning` to `in_progress` when starting execution.

## Conflict Analysis (Multi-Issue Sprints)

For sprints with multiple issues touching the same files:

### Identify File Overlap

| Issue | Files Affected | Conflicts With |
|-------|----------------|----------------|
| #52 (recursive) | `src/actions/*.py` | #53 |
| #53 (config) | `src/config_resolver.py`, `src/actions/tofu.py` | #52 |

### Sequence to Minimize Rework

1. **Phase 1:** Issues with no conflicts
2. **Phase 2:** Restructure/refactor issues (affect many files)
3. **Phase 3:** Issues dependent on restructured code

### Consider Combined PRs

Issues touching the same files may benefit from a single PR:
- Reduces merge conflicts
- Enables atomic review
- May complicate rollback

## Splitting a Sprint

If a sprint grows too large during planning or design, split it into sequential sprints with clear dependency boundaries.

### When to Split

- Sprint scope exceeds Standard tier and contains independent workstreams
- A natural dependency boundary exists (e.g., cleanup before new features)
- The sprint has more than 4-5 scope issues across multiple tiers

### How to Split

1. **Identify the boundary** — look for a point where one group of issues is prerequisite to another
2. **Create the new sprint issue** in homestak-dev with its own scope, repos, and doc cleanup issue
3. **Update the original sprint** — remove moved issues, adjust tier, update sprint log
4. **Rename branches if needed** — if the original sprint's theme changed, rename branches to match:
   ```bash
   git branch -m sprint/old-name sprint/new-name
   git push origin :sprint/old-name sprint/new-name -u
   ```
5. **Link the sprints** — the later sprint should note its dependency on the earlier one

### Example

A "Config Phase" sprint with bootstrap cleanup + new feature work splits into:
- Sprint A (Standard): Bootstrap Cleanup — prerequisite removals and moves
- Sprint B (Complex): Config Phase + Pull Mode — depends on Sprint A

Each sprint gets its own branch name, doc cleanup issue, and validation scenario.

## Cross-Repo Considerations

### Site-Config Prerequisites

Verify configuration requirements:
- `site-config/nodes/{hostname}.yaml` for target hosts
- API tokens in `site-config/secrets.yaml`
- Secrets decrypted (`make decrypt`)

### Validation Host Requirements

A "bootstrapped" host needs additional setup for validation:

| Prerequisite | Description |
|--------------|-------------|
| Node configuration | `site-config/nodes/{hostname}.yaml` must exist |
| API token | Token in `site-config/secrets.yaml` |
| Secrets decrypted | `site-config/secrets.yaml` must be decrypted |
| Packer images | Images published to local PVE storage |
| SSH access | SSH key access to the validation host |
| Nested virtualization | For nested-pve scenarios |

## Outputs

- Sprint issue created with metadata
- Sprint branches created in affected repos
- Scope documented with issue references
- Implementation order defined
- Validation scenario selected
- Linked to release issue (if applicable)

## Checklist: Sprint Planning Complete

- [ ] Sprint issue created with template
- [ ] Metadata section populated (branch, release, tier)
- [ ] Scope issues listed with tiers
- [ ] Affected repos identified
- [ ] Sprint branches created and pushed
- [ ] Dependencies mapped and ordered
- [ ] Validation scenario selected
- [ ] Release issue linked (if applicable)
- [ ] Status set to `in_progress`

## Trunk Path (Simple Work)

For Simple tier work that doesn't need a sprint:

1. Create feature branch: `fix/123-description` or `enhance/123-description`
2. Implement directly
3. Create PR
4. Merge via squash

No sprint issue needed. Work is tracked in the originating issue.

## Related Documents

- [00-overview.md](00-overview.md) - Work tiers and branch model
- [05-session-management.md](05-session-management.md) - Session handling
- [20-design.md](20-design.md) - Design phase
- [../templates/sprint-issue.md](../templates/sprint-issue.md) - Sprint issue template
