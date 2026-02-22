# Phase: Release

Release coordinates tagging, asset publication, and verification across repositories. A release aggregates one or more completed sprints.

## When to Release

Release when:
- Critical mass of features/fixes accumulated
- Major functionality milestone reached
- Security fix requires immediate deployment
- Scheduled release cadence reached

**Theme-first planning:** Create the release issue early with a theme. Sprints link to and update the release issue as they complete.

## Release vs Sprint

| Aspect | Sprint | Release |
|--------|--------|---------|
| Scope | 1-5 issues, focused theme | Multiple sprints accumulated |
| Duration | 2-5 days | When ready |
| Validation | During sprint | Evidence check only |
| State | Sprint issue | Release issue |
| Output | Merged code | Tagged, published artifacts |

## Release Planning (Theme-First)

Create a release issue early:

```bash
gh issue create --repo homestak-dev/homestak-dev \
  --title "Release: v0.45 - Lifecycle Overhaul" \
  --label "release"
```

As sprints complete, update the release issue:

```markdown
## Completed Sprints

### Sprint 152: Recursive PVE (closed)
- iac-driver#52, #53
- ansible#18
- Validation: PASSED

### Sprint 155: Documentation (closed)
- homestak-dev#45
- Validation: PASSED (`./run.sh manifest test -M n1-push -H srv1`)

## Release Readiness
- [x] Sprint 152 validation evidence
- [x] Sprint 155 validation evidence
- [ ] CHANGELOGs updated
- [ ] All repos clean
```

## Release Phases

The release process is divided into discrete phases:

| Phase | Document | Gate | Description |
|-------|----------|------|-------------|
| 61 | [Preflight](61-release-preflight.md) | No | Check prerequisites, validation evidence |
| 62 | [CHANGELOG](62-release-changelog.md) | No | Update version headers |
| 63 | [Tags](63-release-tag.md) | **Yes** | Create git tags |
| 64 | [Packer](64-release-packer.md) | No | Handle packer images |
| 65 | [Publish](65-release-publish.md) | **Yes** | Create GitHub releases |
| 66 | [Verify](66-release-verify.md) | No | Verify releases exist |
| 67 | [Housekeeping](67-release-housekeeping.md) | No | Branch cleanup |
| 68 | [AAR](68-release-aar.md) | No | After Action Report |
| 69 | [Retrospective](69-release-retro.md) | No | Lessons learned, close issue |

**Gates (63, 65):** Require explicit human approval before proceeding.

## Repository Dependency Order

Releases follow dependency order:

```
.github → .claude → homestak-dev → site-config → tofu → ansible → bootstrap → packer → iac-driver
```

**Unified versioning:** All repos get the same version tag, even if unchanged.

## Version Numbering

**Pre-release (current):** `v0.X`
- Simple major.minor (e.g., v0.44, v0.45)
- No patch numbers or RCs unless needed
- No backward compatibility guarantees

**Stable (future):** `v1.0+`
- Semantic versioning with patch numbers
- Backward compatibility expectations

## Release CLI

The `scripts/release.sh` CLI automates release operations:

```bash
# Initialize
./scripts/release.sh init --version 0.45 --issue 157

# Run phases
./scripts/release.sh preflight
./scripts/release.sh validate --host srv1
./scripts/release.sh tag --dry-run
./scripts/release.sh tag --execute --yes
./scripts/release.sh publish --execute --yes
./scripts/release.sh verify
./scripts/release.sh close --execute --yes

# Recovery
./scripts/release.sh resume   # AI-friendly context
./scripts/release.sh status   # Human-readable status
./scripts/release.sh audit    # Action log
```

## Multi-Session Releases

**Best practice:** Complete releases in a single session.

If spanning multiple sessions:

1. **Post phase completion comments:**
   ```markdown
   ✅ Phase 62: CHANGELOGs complete
   - All 9 repos updated
   - Ready for tags
   ```

2. **Use recovery commands:**
   ```bash
   ./scripts/release.sh resume  # AI-friendly
   ./scripts/release.sh status  # Human-readable
   ```

3. **Review state files:**
   - `.release-state.json` - Phase completion status
   - `.release-audit.log` - Action history

## Scope Management

### Scope Freeze

Once release transitions to "In Progress":
- **No new features** - goes to next release
- **Bug fixes only** - critical issues during release
- **Document deferrals** - add to release issue

### Hotfix Process

For critical bugs requiring immediate release:
1. Create fix on master
2. Increment patch version if needed (v0.44 → v0.44.1)
3. Update CHANGELOG
4. Run abbreviated validation
5. Tag and release affected repo(s) only

## Release Sunset

Keep 5 most recent releases. After each release:

```bash
# Check count
count=$(gh release list --repo homestak-dev/homestak-dev --limit 100 | wc -l)
if [[ $count -gt 5 ]]; then
  echo "Consider: ./scripts/release.sh sunset --below-version X.Y"
fi
```

Sunset deletes GitHub releases but preserves git tags.

## Outputs

- All repos tagged with version
- GitHub releases created
- Packer images handled
- Verification complete
- AAR documented
- Branches cleaned up

## Checklist: Release Ready

Before starting release phases:
- [ ] Release issue exists with theme
- [ ] All planned sprints completed
- [ ] Validation evidence available for each sprint
- [ ] No blocking issues open
- [ ] All repos on clean master

## Related Documents

### Release Phases
- [61-release-preflight.md](61-release-preflight.md) - Preflight checks
- [62-release-changelog.md](62-release-changelog.md) - CHANGELOG updates
- [63-release-tag.md](63-release-tag.md) - Tag creation [GATE]
- [64-release-packer.md](64-release-packer.md) - Packer images
- [65-release-publish.md](65-release-publish.md) - GitHub releases [GATE]
- [66-release-verify.md](66-release-verify.md) - Verification
- [67-release-housekeeping.md](67-release-housekeeping.md) - Branch cleanup
- [68-release-aar.md](68-release-aar.md) - After Action Report

### Other
- [55-sprint-close.md](55-sprint-close.md) - Sprint completion before release
- [69-release-retro.md](69-release-retro.md) - Release retrospective
- [75-lessons-learned.md](75-lessons-learned.md) - Accumulated insights
- [../templates/release-issue.md](../templates/release-issue.md) - Release issue template
