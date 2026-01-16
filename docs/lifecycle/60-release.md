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

**Packer images:** `latest` is the primary image source; automation defaults to `packer_release: latest`. Versioned releases only include images when templates actually change. See [Phase 5](#phase-5-packer-images) for details.

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

- [ ] **Identify release tracking issue** (e.g., homestak-dev#XX)
  - Look for open issues titled "vX.Y Release Planning" or labeled `release`
  - Include `--issue XX` when running `release.sh init`
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

**Latest-centric approach:** The `latest` release is the primary source for packer images. Versioned releases (v0.22, v0.23) typically have NO image assets - they're tag-only releases that inherit images from `latest`.

**When to rebuild images:**
- Packer template changes (new packages, cloud-init fixes)
- Base Debian image updates (12.x → 12.y point release)
- Security fixes in image content
- New image variants added

**When to skip rebuild:**
- Documentation-only changes
- Build script refactoring (unless it affects output)
- CHANGELOG updates
- Releases where templates haven't changed

#### Option A: Images NOT Changed (default)

Most releases skip image handling entirely:

```bash
# No packer image steps needed
# Automation uses: packer_release: latest (default)
# latest already points to correct images
```

Add note to release description: "Images: See `latest` release"

#### Option B: Images Changed (rebuild required)

When templates or base images change, rebuild and update `latest`:

```bash
# Build images on a host with QEMU/KVM support
cd ~/homestak-dev/iac-driver
./run.sh --scenario packer-build-fetch --remote <build-host-ip>

# Images downloaded to /tmp/packer-images/
```

**Update `latest` release (via release CLI):**
```bash
./scripts/release.sh packer --copy --source v0.X --execute

# Or via GHA workflow
./scripts/release.sh packer --workflow --source v0.X
```

**Manual update:**
```bash
cd ~/homestak-dev/packer
git tag -f latest v0.X
git push origin latest --force

# Recreate latest release with new images
gh release delete latest --repo homestak-dev/packer --yes
gh release create latest --prerelease \
  --title "Latest Images" \
  --notes "Points to v0.X" \
  --repo homestak-dev/packer \
  /tmp/packer-images/*.qcow2 \
  /tmp/packer-images/*.sha256
```

Add note to release description: "Images: Included (rebuilt for <reason>)"

### Phase 6: GitHub Releases

Create releases in dependency order. **Use `--prerelease` flag until v1.0.**

```bash
# Using release CLI
./scripts/release.sh publish --dry-run
./scripts/release.sh publish --execute

# Or manually
gh release create v0.X --prerelease --title "v0.X" --notes "See CHANGELOG.md" --repo homestak-dev/<repo>
```

**Packer release notes:** Indicate image status in release description:
- If images NOT changed: "Images: See `latest` release"
- If images changed: "Images: Included (rebuilt for <reason>)"

#### Packer Image Checklist (only when rebuilding)

When `latest` is being updated with new images:
- [ ] debian-12-custom.qcow2 + .sha256
- [ ] debian-13-custom.qcow2 + .sha256
- [ ] debian-13-pve.qcow2 + .sha256 (or split parts if >2GB)

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

Expected: All repos have releases. Packer assets depend on whether images were rebuilt:
- Images NOT changed: 0 assets (tag-only release)
- Images changed: 6 assets (3 images + 3 checksums)

#### Post-Release Smoke Test

```bash
# Test bootstrap installation (on a clean system)
curl -fsSL https://raw.githubusercontent.com/homestak-dev/bootstrap/v0.X/install.sh | bash
homestak --version  # Should show v0.X
```

#### Scope Issue Verification

Before closing the release issue, verify all scope issues are closed:

```bash
# Check release issue for scope list, then verify each is closed
gh issue view <release-issue> --repo homestak-dev/homestak-dev

# Close any that were missed (e.g., direct pushes bypass PR auto-close)
gh issue close <issue-num> --repo homestak-dev/<repo> --comment "Implemented in vX.Y"
```

**Note:** Issues should primarily be closed via PR merge using "Closes #XX" in the PR description. This verification step catches cases where auto-close didn't occur.

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

After the retrospective, update `docs/lifecycle/65-lessons-learned.md` with any process improvements. Commit with message: `Update 65-lessons-learned.md with vX.Y lessons`

**Close the release issue only after lessons are codified and committed.** The release issue is the record of completion - closing it signals all phases are done.

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
- [ ] Packer images handled (see Phase 5 - usually skip, update `latest` if changed)
- [ ] Post-release smoke test passed
- [ ] After Action Report completed
- [ ] Retrospective completed
- [ ] Lessons learned codified
- [ ] Release issue closed
