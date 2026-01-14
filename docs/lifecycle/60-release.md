# Phase: Release

Release coordinates tagging, asset publication, and retrospective across repositories. This phase applies to all work types, typically batched at sprint end.

## Inputs

- Merged changes on `master` branch(es)
- Previous release version
- Sprint backlog (completed items)

## Repository Dependency Order

Releases must follow this order (downstream depends on upstream):

**Meta repositories** (release process, documentation):
1. **.github** - Organization templates and PR defaults
2. **.claude** - Claude Code configuration and skills
3. **homestak-dev** - Workspace parent, release methodology, CLAUDE.md

**Core repositories** (functional dependencies):
4. **site-config** - Configuration and secrets
5. **tofu** - VM provisioning modules
6. **ansible** - Host configuration playbooks
7. **bootstrap** - Installation and CLI
8. **packer** - Custom images (requires build host)
9. **iac-driver** - Orchestration (depends on all above)

**Unified versioning:** All repos get the same version tag on each release, even if unchanged. This simplifies tracking - "homestak v0.18" means all repos at v0.18.

**Packer images required:** Every packer release must include images, even if templates are unchanged. Copy images from the previous release if no rebuild is needed.

## Version Numbering

**Pre-release (current):** `v0.X`
- Simple major.minor versioning (e.g., v0.8, v0.9, v0.10)
- No patch numbers or release candidates while pre-release
- Add `-rc1`, `-rc2` or `.1`, `.2` only if actually needed
- No backward compatibility guarantees
- Delete/recreate tags acceptable for pre-releases

**Stable (future):** `v1.0+`
- Semantic versioning with patch numbers
- Backward compatibility expectations
- No tag recreation

## Release Phases

### Phase 0: Release Plan Refresh

**When:** Execute when transitioning from "Planning" to "In Progress" - not during initial planning.

Before starting release work:
- [ ] Verify prerequisite releases are complete (tags exist, issues closed)
- [ ] Compare release plan against this document
- [ ] Update checklists to match current methodology
- [ ] Add any new checklist items from lessons learned

### Phase 1: Pre-flight

- [ ] Git fetch on all repos (avoid rebase surprises)
- [ ] All PRs merged to main branches
- [ ] Working trees clean (`git status` on all repos)
- [ ] No existing tags for target version
- [ ] Site-config secrets decrypted (`site-config/secrets.yaml` exists)
- [ ] CLAUDE.md files reflect current state
- [ ] Organization README current (`.github/profile/README.md`)
- [ ] CHANGELOGs current (all repos)
- [ ] Packer build smoke test on designated build host

```bash
# Tag validation - ensure no existing tags for target version
VERSION=0.X  # Set to target version
for repo in .claude .github ansible bootstrap homestak-dev iac-driver packer site-config tofu; do
  echo "=== $repo ==="
  gh api repos/homestak-dev/$repo/git/refs/tags/v${VERSION} 2>/dev/null && echo "WARNING: tag exists!" || echo "OK: no tag"
done
```

#### CLAUDE.md Review

Verify each repo's CLAUDE.md reflects current architecture:

**Meta repos:**
- [ ] .github - org templates, PR defaults
- [ ] .claude - skills, settings
- [ ] homestak-dev - workspace structure, documentation index

**Core repos:**
- [ ] site-config - schema, defaults, file structure
- [ ] iac-driver - scenarios, actions, ConfigResolver
- [ ] tofu - modules, variables, workflow
- [ ] packer - templates, build workflow
- [ ] ansible - playbooks, roles, collections
- [ ] bootstrap - CLI, installation

### Phase 2: CHANGELOGs

Update CHANGELOGs in dependency order. Move `## Unreleased` content to versioned header:

```markdown
## Unreleased

## vX.Y - YYYY-MM-DD

### Features
- Add foo capability (#123)

### Bug Fixes
- Fix bar issue (#124)
```

### Phase 3: Validation

Run integration tests before tagging to ensure the release is sound.

**Using release CLI (recommended):**
```bash
# Ensure secrets are decrypted first
cd site-config && make decrypt && cd ..

# Run validation (requires PVE host access)
./scripts/release.sh validate --scenario vm-roundtrip --host father
```

**Manual validation:**
```bash
cd iac-driver

# Full nested-pve roundtrip (~8 min)
./run.sh --scenario nested-pve-roundtrip --host father

# Or quick validation (~2 min)
./run.sh --scenario vm-roundtrip --host father
```

**Attach report to release issue as proof.** Reports are generated in `iac-driver/reports/`.

### Phase 4: Tags

Create and push tags in dependency order:

```bash
# Using release CLI
./scripts/release.sh tag --dry-run
./scripts/release.sh tag --execute

# Or manually for each repo
git tag -a v0.X -m "Release v0.X"
git push origin v0.X
```

### Phase 5: Packer Images

Build images on a host with QEMU/KVM support:

```bash
# Build and fetch images
cd ~/homestak-dev/iac-driver
./run.sh --scenario packer-build-fetch --remote <build-host-ip>

# Images downloaded to /tmp/packer-images/
```

**If images unchanged (reuse from previous release):**
```bash
mkdir -p /tmp/packer-images && cd /tmp/packer-images
gh release download latest --repo homestak-dev/packer --pattern '*.qcow2'
```

**Update `latest` tag:**
```bash
cd ~/homestak-dev/packer
git tag -f latest v0.X
git push origin latest --force

# Recreate latest release
gh release delete latest --repo homestak-dev/packer --yes
gh release create latest --prerelease \
  --title "Latest Images" \
  --notes "Rolling release - points to v0.X" \
  --repo homestak-dev/packer \
  /tmp/packer-images/debian-12-custom.qcow2 \
  /tmp/packer-images/debian-13-custom.qcow2
```

### Phase 6: GitHub Releases

Create releases in dependency order. **Use `--prerelease` flag until v1.0.**

```bash
# Using release CLI
./scripts/release.sh publish --dry-run
./scripts/release.sh publish --execute

# Or manually
gh release create v0.X --prerelease --title "v0.X" --notes "See CHANGELOG.md" --repo homestak-dev/<repo>

# Packer (with image assets)
gh release create v0.X --prerelease \
  --title "v0.X" \
  --notes "See CHANGELOG.md" \
  --repo homestak-dev/packer \
  /tmp/packer-images/debian-12-custom.qcow2 \
  /tmp/packer-images/debian-13-custom.qcow2
```

#### Packer Image Checklist

- [ ] debian-12-custom.qcow2
- [ ] debian-13-custom.qcow2
- [ ] debian-13-pve.qcow2 (or split parts if >2GB)
- [ ] SHA256SUMS

**Note:** Images >2GB must be split due to GitHub limits.

### Phase 7: Verification

```bash
./scripts/release.sh verify

# Or manually
for repo in .github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver; do
  echo "=== $repo ==="
  gh release view v0.X --repo homestak-dev/$repo --json tagName,assets --jq '{tag: .tagName, assets: (.assets | length)}'
done
```

Expected: All repos have releases, packer has 4 assets (3 images + checksums).

#### Post-Release Smoke Test

```bash
# Test bootstrap installation (on a clean system)
curl -fsSL https://raw.githubusercontent.com/homestak-dev/bootstrap/v0.X/install.sh | bash
homestak --version  # Should show v0.X
```

### Phase 8: After Action Report

**Complete immediately after release while details are fresh.** Do not close the release issue until AAR is complete.

Use the [AAR Template](../templates/aar.md) to document:

| Section | Content |
|---------|---------|
| Planned vs Actual | Timeline comparison |
| Deviations | What changed and why |
| Issues Discovered | Problems found during release |
| Artifacts Delivered | Final release inventory |
| Validation Report | Attach integration test report |

### Phase 9: Retrospective

**Complete same day as release.** Use the [Retrospective Template](../templates/retrospective.md) to document:

| Section | Content |
|---------|---------|
| What Worked Well | Keep doing these |
| What Could Improve | Process improvements |
| Suggestions | Specific ideas for next release |
| Open Questions | Decisions deferred |
| Follow-up Issues | Create issues for discoveries |

**Important:** Create GitHub issues for any problems discovered. Link them in the retrospective.

#### Codify Lessons Learned

After the retrospective, update this document with any process improvements. Commit with message: `Update 60-release.md with vX.Y lessons learned`

### Phase 10: Housekeeping (each sprint)

Branch cleanup should be performed at the end of each sprint, not just periodically.

```bash
# For each repo, clean up branches
for repo in .claude .github ansible bootstrap homestak-dev iac-driver packer site-config tofu; do
  echo "=== $repo ==="
  cd ~/homestak-dev/$repo

  # Delete merged local branches
  git branch --merged | grep -v master | xargs -r git branch -d

  # Prune stale remote tracking refs
  git remote prune origin

  # Check for unmerged branches (squash/rebase may leave "ahead" branches)
  for branch in $(git branch -r | grep -v HEAD | grep -v master); do
    if [[ -n "$(git diff master..$branch 2>/dev/null)" ]]; then
      echo "UNMERGED: $branch"
    fi
  done

  cd -
done
```

**Note:** Branches may show as "ahead" by commit count even when content was merged via squash/rebase. Use `git diff` to verify actual unmerged content before deleting.

**Repository setting:** Enable "Automatically delete head branches" in GitHub repo settings to auto-cleanup after PR merge.

## Scope Management

### Scope Freeze

Once a release transitions from "Planning" to "In Progress":
- **No new features** - New scope goes to the next release
- **Bug fixes only** - Critical issues discovered during release may be addressed
- **Document deferrals** - Add deferred items to release issue

### Hotfix Process

For critical bugs requiring immediate release:
1. Create fix on main/master branch
2. Increment patch version (v0.9 → v0.9.1) if needed
3. Update CHANGELOG with hotfix entry
4. Run abbreviated validation (vm-roundtrip)
5. Tag and release affected repo(s) only
6. Hotfixes do NOT require full release train

## Release CLI (v0.14+)

The `scripts/release.sh` CLI automates multi-repo release operations.

| Command | Description |
|---------|-------------|
| `init --version X.Y` | Initialize release state |
| `status` | Show release progress |
| `preflight` | Check repos ready (clean, no tags, CHANGELOGs) |
| `validate` | Run iac-driver integration tests |
| `tag --dry-run` | Preview tag creation |
| `tag --execute` | Create and push tags |
| `tag --reset` | Reset tags to HEAD (v0.x only) |
| `publish --dry-run` | Preview release creation |
| `publish --execute` | Create GitHub releases |
| `packer --check` | Check for template changes |
| `packer --copy` | Copy images from previous release |
| `full --dry-run` | Preview complete release workflow |
| `full --execute` | Execute end-to-end release |
| `verify` | Verify all releases exist |
| `audit` | Show timestamped action log |

### Release Workflow Example

```bash
./scripts/release.sh init --version 0.20
./scripts/release.sh preflight
./scripts/release.sh validate --scenario vm-roundtrip --host father
./scripts/release.sh tag --dry-run
./scripts/release.sh tag --execute
./scripts/release.sh publish --execute
./scripts/release.sh packer --copy --execute
./scripts/release.sh verify

# Or use full command for end-to-end automation
./scripts/release.sh full --dry-run
./scripts/release.sh full --execute --host father
```

## Templates

- [Release Issue Template](../templates/release-issue.md) - Create release planning issue
- [AAR Template](../templates/aar.md) - After Action Report
- [Retrospective Template](../templates/retrospective.md) - Sprint retrospective

## Recipes

### Renaming a Release

To rename a release (e.g., `v0.5.0-rc1` → `v0.5`) without re-uploading assets:

```bash
# 1. Get the commit SHA for the old tag
git show-ref --tags | grep v0.5.0-rc1

# 2. Create new tag pointing to same commit
git tag v0.5 <commit-sha>
git push origin v0.5

# 3. Edit release to use new tag
gh release edit v0.5.0-rc1 --repo homestak-dev/<repo> --tag v0.5 --title "v0.5"

# 4. Delete old tag
git tag -d v0.5.0-rc1
git push origin :refs/tags/v0.5.0-rc1
```

## Path to Stable

Before graduating from pre-release to v1.0.0:

- [ ] User-facing documentation (beyond CLAUDE.md)
- [ ] CI/CD pipeline for automated integration tests
- [ ] All "known issues" resolved or documented
- [ ] Core workflows fully working
- [ ] Security audit (secrets, SSH, API tokens)
- [ ] Bootstrap UX polished

## References

**Historical releases** (issues in .github repo):
- [v0.6 Release](https://github.com/homestak-dev/.github/issues/4)
- [v0.7 Release](https://github.com/homestak-dev/.github/issues/6)
- [v0.8 Release](https://github.com/homestak-dev/.github/issues/11)
- [v0.9 Release](https://github.com/homestak-dev/.github/issues/14)
- [v0.10 Release](https://github.com/homestak-dev/.github/issues/18)
- [v0.11 Release](https://github.com/homestak-dev/.github/issues/21)

**Current releases** (issues in homestak-dev repo):
- v0.12+ release issues tracked in [homestak-dev/homestak-dev](https://github.com/homestak-dev/homestak-dev/issues)

## Lessons Learned

See [65-lessons-learned.md](65-lessons-learned.md) for accumulated insights from v0.8-v0.19 releases, organized by release and by category.

**Before each release:** Scan recent lessons to avoid repeating mistakes.

**After each release:** Add new lessons from retrospective, commit with `Update 65-lessons-learned.md with vX.Y lessons`.

## Checklist: Release Complete

- [ ] Dependency order determined (multi-repo)
- [ ] Version numbers determined
- [ ] All repos tagged
- [ ] GitHub releases created
- [ ] Packer assets uploaded (images + checksums)
- [ ] `latest` tag updated
- [ ] Post-release smoke test passed
- [ ] After Action Report completed
- [ ] Retrospective completed
- [ ] Lessons learned codified
- [ ] Release issue closed
