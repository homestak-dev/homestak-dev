# Release Methodology

Standard process for homestak releases across all repositories.

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

**Unified versioning:** All repos get the same version tag on each release, even if unchanged. This simplifies tracking - "homestak v0.8" means all repos at v0.8.

**Packer images required:** Every packer release must include images, even if templates are unchanged. Copy images from the previous release if no rebuild is needed. An empty packer release breaks the unified versioning promise - users should be able to download any version and have working images.

## Sprint Planning

Before starting release execution, complete sprint planning to ensure scope is well-defined and implementation approach is validated.

### Step 1: Scope Agreement

- Review candidate issues for the release
- Prioritize based on value, dependencies, and risk
- Agree on what's in-scope vs deferred
- Consider release size (prefer smaller, focused releases)

### Step 2: Create Release Plan Draft

Create a GitHub issue using the Release Issue Template:

- Title: `vX.Y Release Planning - Theme`
- Capture agreed scope with issue references
- Note deferred items and rationale
- Set status to "Planning"

### Step 3: Issue-Level Planning

For each in-scope issue, document:

| Aspect | Content |
|--------|---------|
| Requirements | Acceptance criteria, constraints |
| Design | Technical approach, alternatives considered |
| Implementation | Files to modify, sequence |
| Testing | How to verify, test scenarios |
| Documentation | CLAUDE.md, CHANGELOG, other docs |

Attach planning details to each issue as a comment before implementation.

### Step 4: Update Release Plan

Roll up issue-level planning into the release plan issue:

- Add implementation order/dependencies
- Identify critical path items
- Note any risks or open questions
- Update status to "In Progress" when starting execution

## Release Phases

### Phase 0: Release Plan Refresh

**When:** Execute when transitioning from "Planning" to "In Progress" - not during initial planning.

Before starting release work, ensure prerequisites are met and the plan is current:

- [ ] Verify prerequisite releases are complete (tags exist, issues closed)
- [ ] Compare release plan against RELEASE.md template
- [ ] Update Pre-flight, CLAUDE.md Review, CHANGELOGs, Tags & Releases, and Post-Release sections to match current RELEASE.md
- [ ] Add any new checklist items from lessons learned

This ensures each release benefits from accumulated process improvements, especially if time has passed since the plan was created.

### Phase 1: Pre-flight

- [ ] Git fetch on all repos (avoid rebase surprises)
- [ ] All PRs merged to main branches
- [ ] Working trees clean (`git status` on all repos)
- [ ] No existing tags for target version
- [ ] Site-config secrets decrypted (`site-config/secrets.yaml` exists)
- [ ] CLAUDE.md files reflect current state (see below)
- [ ] Organization README current (`.github/profile/README.md`)
- [ ] RELEASE.md current (`homestak-dev/RELEASE.md`)
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

#### CLAUDE.md Review (per .github#5)

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

```bash
# Quick status check
for repo in .github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver; do
  echo "=== $repo ==="
  cd ~/homestak-dev/$repo
  git status --short
  git tag -l "v0.*" | tail -3
done
```

### Phase 2: CHANGELOGs

Update CHANGELOGs in dependency order.

#### Development Workflow

During development, add entries under an `## Unreleased` section:

```markdown
## Unreleased

### Features
- Add foo capability (#123)

### Bug Fixes
- Fix bar issue (#124)
```

#### At Release Time

Move Unreleased content to a new version header:

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

**Using release CLI (v0.14+, recommended):**
```bash
# Ensure secrets are decrypted first
cd site-config && make decrypt && cd ..

# Run validation (requires PVE host access)
./scripts/release.sh validate --scenario vm-roundtrip --host father
```

**Manual validation:**
```bash
# Ensure secrets are decrypted
cd site-config && make decrypt && cd ..

# Full nested-pve roundtrip (~8 min on father)
cd iac-driver
./run.sh --scenario nested-pve-roundtrip --host father

# Or constructor + destructor separately with context persistence
./run.sh --scenario nested-pve-constructor --host father -C /tmp/nested-pve.ctx
# ... verify inner PVE, check test VM ...
./run.sh --scenario nested-pve-destructor --host father -C /tmp/nested-pve.ctx

# Quick validation: vm-roundtrip (~2 min)
./run.sh --scenario vm-roundtrip --host father
```

**Note:** Validation requires PVE API access. Run on a PVE host (father/mother) or ensure credentials are exported.

**Attach report to release issue as proof.** Reports are generated in `iac-driver/reports/`:
- `YYYYMMDD-HHMMSS.passed.md` - Human-readable summary
- `YYYYMMDD-HHMMSS.passed.json` - Machine-readable details

#### Validation Host Prerequisites

A "bootstrapped" host is not automatically validation-ready. The following prerequisites must be in place before running validation scenarios.

| Prerequisite | Description | Setup Command |
|--------------|-------------|---------------|
| **Node configuration** | `site-config/nodes/{hostname}.yaml` must exist with API endpoint and datastore | `cd site-config && make node-config` |
| **API token** | Token for this host in `site-config/secrets.yaml` under `api_tokens.{hostname}` | `pveum user token add root@pam homestak --privsep 0` then add to secrets.yaml |
| **Secrets decrypted** | `site-config/secrets.yaml` must be decrypted | `cd site-config && make decrypt` |
| **Packer images** | Images published to local PVE storage (`/var/lib/vz/template/iso/`) | `cd packer && ./publish.sh` or download from release |
| **SSH access** | SSH key access to the validation host | Standard SSH setup |
| **Nested virtualization** | For nested-pve scenarios, nested virt must be enabled | Check: `cat /sys/module/kvm_intel/parameters/nested` |

**Quick check for validation readiness:**

```bash
# On the validation host
HOST=$(hostname)

# 1. Check node config exists
ls site-config/nodes/${HOST}.yaml 2>/dev/null || echo "MISSING: node config"

# 2. Check API token exists (requires decrypted secrets)
grep -q "api_tokens:" site-config/secrets.yaml && \
  grep -q "${HOST}:" site-config/secrets.yaml && \
  echo "OK: API token found" || echo "MISSING: API token"

# 3. Check packer images
ls /var/lib/vz/template/iso/debian-*-custom.img 2>/dev/null || echo "MISSING: packer images"

# 4. Check nested virtualization
cat /sys/module/kvm_intel/parameters/nested | grep -q Y && \
  echo "OK: nested virt enabled" || echo "WARNING: nested virt disabled"
```

**Common issues:**

| Issue | Solution |
|-------|----------|
| `API token not found` | Generate token with `pveum`, add to secrets.yaml, run `make encrypt` |
| `node config missing` | Run `make node-config` on the PVE host |
| `packer images missing` | Run `./publish.sh` or download from packer release |
| `tofu provider version conflict` | Clear stale provider cache: `rm -rf iac-driver/.states/*/data/providers/` |

### Phase 4: Tags

Create and push tags in dependency order:

```bash
# For each repo
git tag -a v0.X -m "Release v0.X"
git push origin v0.X
```

### Phase 5: Packer Images

Build images on a host with QEMU/KVM support:

```bash
# Prerequisites (one-time on build host)
curl -fsSL https://raw.githubusercontent.com/homestak-dev/bootstrap/main/install.sh | bash
homestak install packer

# Build and fetch images
cd ~/homestak-dev/iac-driver
./run.sh --scenario packer-build-fetch --remote <build-host-ip>

# Images downloaded to /tmp/packer-images/
```

**Build hosts:** father, mother (any PVE host with `homestak install packer`)

**Dev workflow:** Use `packer-sync-build-fetch` to test local packer changes before committing.

#### Image Versioning and `latest` Tag

For unified versioning, **every release includes packer images** attached to the version release, and `latest` is updated to point to the new version. This ensures "homestak v0.X" is complete and self-contained.

**If images were rebuilt this release:**
```bash
# Build and fetch new images
./run.sh --scenario packer-build-fetch --remote <build-host-ip>
```

**If images unchanged (reuse from previous release):**
```bash
# Fetch from current latest
mkdir -p /tmp/packer-images && cd /tmp/packer-images
gh release download latest --repo homestak-dev/packer --pattern '*.qcow2'
```

**Then update `latest` tag and release:**
```bash
# Update latest tag to point to new release
cd ~/homestak-dev/packer
git tag -f latest v0.X
git push origin latest --force

# Delete and recreate latest release with same assets
gh release delete latest --repo homestak-dev/packer --yes
gh release create latest --prerelease \
  --title "Latest Images" \
  --notes "Rolling release - points to v0.X" \
  --repo homestak-dev/packer \
  /tmp/packer-images/debian-12-custom.qcow2 \
  /tmp/packer-images/debian-13-custom.qcow2
```

See packer#5 for the `latest` tag convention details.

**Override:** Pin to specific version with `--packer-release v0.X` or `site.yaml`.

### Phase 6: GitHub Releases

Create releases in dependency order. **Use `--prerelease` flag until v1.0.**

```bash
# Source-only repos
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

Verify all images are uploaded to the packer release:

- [ ] debian-12-custom.qcow2
- [ ] debian-13-custom.qcow2
- [ ] debian-13-pve.qcow2 (or split parts if >2GB)
- [ ] SHA256SUMS

**Note:** Images >2GB must be split due to GitHub limits. See Lessons Learned.

### Phase 7: Verification

```bash
for repo in .github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver; do
  echo "=== $repo ==="
  gh release view v0.X --repo homestak-dev/$repo --json tagName,assets --jq '{tag: .tagName, assets: (.assets | length)}'
done
```

Expected: All repos have releases, packer has 4 assets (3 images + checksums).

#### Post-Release Smoke Test

Verify the released artifacts work from a fresh perspective:

```bash
# Test bootstrap installation (on a clean system or container)
curl -fsSL https://raw.githubusercontent.com/homestak-dev/bootstrap/v0.X/install.sh | bash

# Verify version
homestak --version  # Should show v0.X
```

This catches packaging issues before users encounter them.

### Phase 8: After Action Report (same day)

**Complete immediately after release while details are fresh.** Delaying AAR/retro results in lost insights.

**DO NOT close the release issue until AAR and Retrospective are complete.** These are required deliverables, not optional documentation.

Document on the release issue:

| Section | Content |
|---------|---------|
| Planned vs Actual | Timeline comparison |
| Deviations | What changed and why |
| Issues Discovered | Problems found during release |
| Artifacts Delivered | Final release inventory |
| Validation Report | Attach integration test report (markdown) |

**Attach the integration test report** from `iac-driver/reports/YYYYMMDD-HHMMSS.passed.md` as a code block in the AAR comment. This provides permanent proof of validation.

### Phase 9: Retrospective (same day)

Document on the release issue:

| Section | Content |
|---------|---------|
| What Worked Well | Keep doing these |
| What Could Improve | Process improvements |
| Suggestions | Specific ideas for next release |
| Open Questions | Decisions deferred |
| Follow-up Issues | Create issues for discoveries |

**Important:** Create GitHub issues for any problems discovered during the release. Link them in the retrospective comment and consider them for the next release scope.

#### Codify Lessons Learned

After the retrospective, update this RELEASE.md with any process improvements:
- New phases or steps discovered
- Commands or patterns that should be documented
- Gotchas to avoid in future releases

Commit with message: `Update RELEASE.md with vX.Y lessons learned`

### Phase 10: Housekeeping (periodic)

Clean up local development environment:

```bash
# Delete merged local branches (run in each repo)
git branch --merged | grep -v master | xargs git branch -d

# Prune stale remote tracking refs
git remote prune origin

# Quick status check across all repos
for repo in .github .claude homestak-dev site-config tofu ansible bootstrap packer iac-driver; do
  echo "=== $repo ===" && cd ~/homestak-dev/$repo && git status --short && git branch
done
```

This prevents accumulation of stale branches from merged PRs.

## Scope Management

### Scope Freeze

Once a release transitions from "Planning" to "In Progress":

- **No new features** - New scope goes to the next release
- **Bug fixes only** - Critical issues discovered during release may be addressed
- **Document deferrals** - Add deferred items to "Deferred to Future Release" section

This prevents scope creep and keeps releases focused and predictable.

### Mid-Release Discoveries

If you discover issues during release work:

1. **Critical blocker** - Fix it, document in AAR
2. **Important but not blocking** - Create issue, add to next release plan
3. **Nice to have** - Create issue, add to backlog

### Hotfix Process

For critical bugs requiring immediate release:

1. Create fix on main/master branch
2. Increment patch version (v0.9 → v0.9.1) if needed
3. Update CHANGELOG with hotfix entry
4. Run abbreviated validation (simple-vm-roundtrip)
5. Tag and release affected repo(s) only
6. Hotfixes do NOT require full release train

## Version Numbering

**Pre-release:** `v0.X` (current phase)
- Simple major.minor versioning (e.g., v0.8, v0.9, v0.10)
- No patch numbers or release candidates while pre-release
- Add `-rc1`, `-rc2` or `.1`, `.2` only if actually needed
- No backward compatibility guarantees
- Delete/recreate tags acceptable for pre-releases

**Stable:** `v1.0+` (future)
- Semantic versioning with patch numbers
- Backward compatibility expectations
- No tag recreation

## Release Issue Template

Each release should have a coordination issue in `homestak-dev` repo.

**Issue naming convention:** Use format `vX.Y Release Planning - Theme`

Examples:
- `v0.10 Release Planning - Housekeeping`
- `v0.11 Release Planning - Code Quality`
- `v0.20 Release Planning - Recursive Nested PVE`

**Checkbox maintenance:** Check off items as phases complete to track progress visually. This provides a clear record of completion and helps identify any missed steps.

```markdown
## Summary
Planning for vX.Y release.

## Scope
### repo-name
- [ ] Feature/fix description (#issue)

## Validation
- [ ] Integration test results
- [ ] Manual verification

## Deferred to Future Release
- repo#N - Description

## Release Checklist

### Phase 0: Release Plan Refresh
- [ ] Verify prerequisite releases are complete (tags exist, issues closed)
- [ ] Compare release plan against RELEASE.md template
- [ ] Update checklists to match current methodology

### Pre-flight
- [ ] Git fetch on all repos (avoid rebase surprises)
- [ ] All PRs merged to master
- [ ] Working trees clean (`git status` on all repos)
- [ ] No existing tags for target version
- [ ] Site-config secrets decrypted (`site-config/secrets.yaml` exists)
- [ ] CLAUDE.md files reflect current state (see below)
- [ ] Organization README current (`.github/profile/README.md`)
- [ ] RELEASE.md current (`homestak-dev/RELEASE.md`)
- [ ] CHANGELOGs current (all repos)
- [ ] Packer build smoke test (if images changed)

### CLAUDE.md Review
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

### CHANGELOGs
- [ ] .github
- [ ] .claude
- [ ] homestak-dev
- [ ] site-config
- [ ] tofu
- [ ] ansible
- [ ] bootstrap
- [ ] packer
- [ ] iac-driver

### Validation (before tagging)
- [ ] Site-config secrets decrypted
- [ ] Integration test passed (`release.sh validate` or manual iac-driver)
- [ ] Test report attached to this issue

### Tags & Releases
- [ ] .github vX.Y
- [ ] .claude vX.Y
- [ ] homestak-dev vX.Y
- [ ] site-config vX.Y
- [ ] tofu vX.Y
- [ ] ansible vX.Y
- [ ] bootstrap vX.Y
- [ ] packer vX.Y
- [ ] iac-driver vX.Y

### Packer Images
- [ ] debian-12-custom.qcow2
- [ ] debian-13-custom.qcow2
- [ ] debian-13-pve.qcow2 (or split parts)
- [ ] SHA256SUMS

### Verification
- [ ] All repos have releases
- [ ] Packer has 4 image assets (3 images + checksums)
- [ ] Post-release smoke test (bootstrap install)

### Post-Release (same day - do not defer)
- [ ] After Action Report
- [ ] Retrospective
- [ ] Update RELEASE.md with lessons learned
- [ ] Close release issue

---
**Started:** YYYY-MM-DD HH:MM
**Completed:** YYYY-MM-DD HH:MM
**Status:** Planning | In Progress | Complete
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
- [v0.6 Release](https://github.com/homestak-dev/.github/issues/4) - First release using this methodology
- [v0.7 Release](https://github.com/homestak-dev/.github/issues/6) - Gateway fix, state storage move, E2E validation
- [v0.8 Release](https://github.com/homestak-dev/.github/issues/11) - CLI robustness, `latest` packer release tag
- [v0.9 Release](https://github.com/homestak-dev/.github/issues/14) - Scenario annotations, --timeout, unit tests, CLAUDE.md audit
- [v0.10 Release](https://github.com/homestak-dev/.github/issues/18) - Housekeeping, CI/CD Phase 1, repository settings harmonization
- [v0.11 Release](https://github.com/homestak-dev/.github/issues/21) - Code quality, static analysis, test coverage, security audit

**Current releases** (issues in homestak-dev repo):
- v0.12+ release issues will be tracked in [homestak-dev/homestak-dev](https://github.com/homestak-dev/homestak-dev/issues)

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

Assets remain attached to the release through the tag change.

## Lessons Learned

### v0.18
- **Test the actual CLI flow end-to-end** - `packer --copy` was tested in isolation but not via `release.sh packer --copy`. Four hotfixes required during release execution. Created #61 for `release.sh selftest` command.
- **Verify external tool behavior, don't assume** - `gh release list --json` doesn't exist; assumed it did based on other `gh` commands. Always test against actual CLI behavior.
- **Bootstrap ≠ validation-ready** - A bootstrapped host needs additional setup (node config, packer images, API token) before validation. Created #63 to document prerequisites.
- **Provider upgrades need cache clearing** - When tofu lockfiles are updated, stale provider caches in `iac-driver/.states/*/data/providers/` cause version conflicts. Created #64 for preflight check.
- **Feature prerequisites propagate** - When copying assets from a release that predates a feature (SHA256SUMS), the artifacts won't exist. `packer --copy` should generate SHA256SUMS. Created #62.
- **Workspace path handling** - `verify.sh` looked for `homestak-dev/homestak-dev` instead of recognizing workspace root. Edge cases in multi-repo tooling need explicit handling.
- **Hotfixes acceptable in v0.x** - For pre-1.0 releases, fixing bugs during release execution is reasonable. Post-1.0, more rigorous pre-release testing required.
- **Real-time AAR comments valuable** - Capturing issues as GitHub comments during release made final AAR easy to compile.

### v0.17
- **Never discard uncommitted changes without asking** - During release, Claude discarded an intentional CHANGELOG entry (provider bump to 0.92.0) assuming it was stray. Always ask the user before discarding uncommitted changes - they may be intentional work from a previous session.

### v0.16
- **Tag collision requires manual reset** - When tags exist at older commits, `release.sh tag` fails. Manual deletion required across all 9 repos. Created #49 for `--reset` flag.
- **Verify `latest` packer release completeness** - The `latest` release was missing debian-13-pve. Always verify all expected assets before copying to new release. Created #50 for automation.
- **Tag inventory check before closing** - No verification that all repos are tagged before closing release issue. Created #48 for this check.
- **Unified versioning requires constant awareness** - Easy to slip into "single-repo release" thinking. The rule is clear in RELEASE.md but requires active attention during execution.
- **CHANGELOG updates should be batched** - Update all 9 CHANGELOGs together before tagging, not incrementally during implementation.

### v0.15
- **AAR/Retro are required, not optional** - Release was initially closed without AAR and Retrospective. These are required deliverables that capture lessons learned. Do not close the release issue until both are complete.
- **Packer images required for unified release** - Empty packer releases break the unified versioning promise. If templates are unchanged, copy images from the previous release. Created #45 to automate this.
- **GitHub Actions may auto-create releases** - Packer has a workflow that creates a release on tag push. The publish idempotency fix (#41) correctly handled this by skipping the existing release.

### v0.14
- **Release CLI available** - Use `scripts/release.sh` for automated release workflow (init, preflight, validate, tag, publish, verify). Manual steps remain documented as fallback.
- **Validation requires PVE API access** - Run validation on a PVE host (father/mother) or ensure site-config secrets are decrypted and credentials exported. `cd site-config && make decrypt` before validation.
- **Secrets must be decrypted before validation** - Preflight passes but validation fails without decrypted secrets. Added secrets check to preflight checklist.
- **Design-first for complex features** - When implementing complex features, pause to write implementation spec before coding. Caught yq/jq decision early in v0.14.
- **Dogfooding validates design** - Using release CLI for its own release found 5 real issues not caught in synthetic testing.
- **gh release create race condition** - May report "tag already exists" error but release was created. Check release existence before failing.
- **Split files not verified** - verify.sh expects exact filenames but large images are split. Verification shows 2/3 assets when 4 are present.

### v0.13
- **Create formal test plans for risky changes** - When fixing lint violations or other changes that touch many files, write a test plan documenting coverage before proceeding. Integration tests alone may not cover all modified code paths.
- **Context window compaction causes directory confusion** - Long sessions with many context compactions can lead to "wrong directory" errors during multi-repo operations. Consider a dedicated release agent for future releases to reduce context-related mistakes.
- **Unified versioning requires explicit tracking** - Tag ALL repos even when unchanged. Without explicit checklist tracking, repos like packer get skipped. The release issue checklist must enumerate all 9 repos.
- **ansible-lint cleanup belongs in sprint scope** - 209 lint violations were discovered during v0.13 PR review. Clean these proactively during development sprints, not at release time.
- **Test before announcing completion** - User feedback "have you proved that the ansible roles still work?" caught a gap. Always validate functional correctness after significant refactoring.

### v0.12
- **Validate before tagging** - Run integration tests (Phase 3) before creating tags (Phase 4). Tags should represent validated code. Reordered phases in this release.
- **Use PRs for significant doc changes** - Create PRs for documentation restructuring, CLAUDE.md rewrites, and similar changes. Direct commits acceptable for CHANGELOG alignment and minor fixes.
- **Plan discussions surface design decisions** - Thorough planning discussion (e.g., CLAUDE.md consolidation approach, issue migration strategy) prevents rework during execution.
- **Issue migration timing** - Don't execute issue migration during planning phase. Keep it in execution phase to maintain clear boundaries.
- **Makefile setup target needed** - Contributors need a simpler onboarding path. Created homestak-dev#17 for `make setup` target.

### v0.11
- **Checkpoint before release execution** - After integration tests pass, explicitly pause to review RELEASE.md and the release issue checkboxes before creating tags/releases. The validation phase is part of the sprint, not the release execution. Without this checkpoint, steps get skipped in the rush to complete.
- **Update checkboxes as you go** - Check off items in the release issue as work progresses, not post-hoc. This provides real-time visibility and prevents skipped steps.
- **Distinguish "sprint" from "release"** - A sprint includes code changes, PRs, and validation. The release is the separate act of tagging and publishing. Conflating them leads to skipped release steps.
- **Check for existing tags** - Before creating tags, verify they don't already exist across all repos. Created .github#26 for automation.
- **Use `--prerelease` flag** - Until v1.0, all releases should use `--prerelease` per the methodology.
- **Context loss requires re-reading** - When AI context is exhausted mid-release, re-read RELEASE.md before continuing. The summarized context may lose procedural details.
- **Branch protection friction** - PRs required `--admin` flag due to branch protection. Created .github#27 to evaluate options.

### v0.10
- **Scenario name consistency matters** - `simple-vm-roundtrip` was incorrect in multiple places (RELEASE.md, issue #15, profile README). Fixed during release.
- **Document destructive actions** - vm-destructor has no confirmation prompt. Added caution to examples, created iac-driver#65.
- **Packer image reuse workflow** - When reusing images, must download from `latest` then re-upload to new release. Consider streamlining.
- **Post-scope polish is scope creep** - Added third-party acknowledgments and improved examples during "completed" release. Consider scope freeze earlier.
- **Release plan naming convention** - Inconsistent naming discovered (.github#25). Standardize on `vX.Y Release Planning - Theme`.

### v0.9
- **Thorough CLAUDE.md verification pays off** - Found 6 documentation errors during release. Consider making this a standard release phase rather than optional.
- **Generate scenario tables from code** - Manually maintaining phase counts leads to drift. Consider `--list-scenarios --json` for automation.
- **Integration test is not optional** - Skipping nested-pve-roundtrip before release is risky. Make it a hard blocker.
- **Fetch before release work** - Run `git fetch` on all repos before starting release to avoid rebase surprises.
- **Explicitly verify all image uploads** - debian-13-pve was omitted initially. Add image checklist to release process.
- **GitHub 2GB release asset limit** - Large images (>2GB) must be split: `split -b 1900M image.qcow2 image.qcow2.part`, users reassemble with `cat image.qcow2.part* > image.qcow2`. Document in release notes.
- **Review organization README** - `.github/profile/README.md` was updated retroactively to fix terminology. Added to pre-flight checklist.

### v0.8
- **Complete AAR/retro immediately** - Deferred post-release tasks result in lost context. Block on these before starting next release work.
