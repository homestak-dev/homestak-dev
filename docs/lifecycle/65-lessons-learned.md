# Lessons Learned

Accumulated insights from homestak-dev releases v0.8-v0.19. Each lesson was codified in the retrospective phase of its respective release.

## How to Use This Document

- **Before release:** Scan recent lessons to avoid repeating mistakes
- **During release:** Reference when encountering issues
- **After release:** Add new lessons from retrospective, commit with `Update 65-lessons-learned.md with vX.Y lessons`

## v0.19

- **Validate optimizations before merging** - packer#13 shipped boot time "optimizations" that were never tested. The bootcmd→runcmd change broke networking entirely. Optimizations require validation testing as part of PR scope, not just code review.
- **CHANGELOG updates belong in PRs, not release** - Multiple CHANGELOGs needed mid-release fixes. Each PR should update the relevant CHANGELOG as part of the change.
- **Use stable markers for detection, not service status** - EnsurePVEAction checked `pveproxy` status immediately after SSH, but the service wasn't running yet. Checking marker files is more reliable than racing against service startup.
- **Follow process to the end** - Posted AAR to RELEASE.md instead of the release issue. Fatigue at end of release leads to shortcuts.
- **"Stability" release that needed multiple fixes is a miss** - Ironic that a release themed "Stability & Validation" required mid-release fixes. Having validation tools isn't enough - must use them consistently before merge.

## v0.18

- **Test the actual CLI flow end-to-end** - `packer --copy` was tested in isolation but not via `release.sh packer --copy`. Four hotfixes required during release execution.
- **Verify external tool behavior, don't assume** - `gh release list --json` doesn't exist; assumed it did based on other `gh` commands. Always test against actual CLI behavior.
- **Bootstrap ≠ validation-ready** - A bootstrapped host needs additional setup (node config, packer images, API token) before validation.
- **Provider upgrades need cache clearing** - When tofu lockfiles are updated, stale provider caches cause version conflicts.
- **Feature prerequisites propagate** - When copying assets from a release that predates a feature, the artifacts won't exist.
- **Hotfixes acceptable in v0.x** - For pre-1.0 releases, fixing bugs during release execution is reasonable.

## v0.17

- **Never discard uncommitted changes without asking** - During release, Claude discarded an intentional CHANGELOG entry assuming it was stray. Always ask the user before discarding uncommitted changes.

## v0.16

- **Tag collision requires manual reset** - When tags exist at older commits, `release.sh tag` fails. Manual deletion required.
- **Verify `latest` packer release completeness** - Always verify all expected assets before copying to new release.
- **Tag inventory check before closing** - Verify all repos are tagged before closing release issue.
- **Unified versioning requires constant awareness** - Easy to slip into "single-repo release" thinking.

## v0.15

- **AAR/Retro are required, not optional** - Release was initially closed without AAR and Retrospective. These are required deliverables.
- **Packer images required for unified release** - Empty packer releases break the unified versioning promise.

## v0.14

- **Release CLI available** - Use `scripts/release.sh` for automated release workflow.
- **Validation requires PVE API access** - Run validation on a PVE host or ensure credentials are exported.
- **Secrets must be decrypted before validation** - Preflight passes but validation fails without decrypted secrets.
- **Design-first for complex features** - Pause to write implementation spec before coding.
- **Dogfooding validates design** - Using release CLI for its own release found real issues not caught in synthetic testing.

## v0.13

- **Create formal test plans for risky changes** - Write test plans documenting coverage before proceeding.
- **Context window compaction causes confusion** - Consider a dedicated release agent for future releases.
- **Unified versioning requires explicit tracking** - Tag ALL repos even when unchanged.
- **Test before announcing completion** - Always validate functional correctness after refactoring.

## v0.12

- **Validate before tagging** - Run integration tests before creating tags.
- **Use PRs for significant doc changes** - Create PRs for documentation restructuring.
- **Plan discussions surface design decisions** - Thorough planning prevents rework.

## v0.11

- **Checkpoint before release execution** - Explicitly pause to review methodology before creating tags.
- **Update checkboxes as you go** - Check off items as work progresses, not post-hoc.
- **Distinguish "sprint" from "release"** - A sprint includes code changes and validation. The release is tagging and publishing.
- **Check for existing tags** - Verify tags don't already exist before creating.
- **Use `--prerelease` flag** - Until v1.0, all releases should use `--prerelease`.

## v0.10

- **Scenario name consistency matters** - Incorrect names in multiple places cause confusion.
- **Document destructive actions** - vm-destructor has no confirmation prompt.
- **Packer image reuse workflow** - Must download from `latest` then re-upload to new release.

## v0.9

- **Thorough CLAUDE.md verification pays off** - Found 6 documentation errors during release.
- **Integration test is not optional** - Skipping nested-pve-roundtrip before release is risky.
- **Fetch before release work** - Run `git fetch` on all repos before starting.
- **GitHub 2GB release asset limit** - Large images must be split.

## v0.8

- **Complete AAR/retro immediately** - Deferred post-release tasks result in lost context.

## Lesson Categories

For quick reference, lessons grouped by theme:

### Validation & Testing
- Validate optimizations before merging (v0.19)
- Test the actual CLI flow end-to-end (v0.18)
- Verify external tool behavior, don't assume (v0.18)
- Integration test is not optional (v0.9)
- Test before announcing completion (v0.13)
- Create formal test plans for risky changes (v0.13)

### Process Discipline
- CHANGELOG updates belong in PRs, not release (v0.19)
- Follow process to the end (v0.19)
- AAR/Retro are required, not optional (v0.15)
- Complete AAR/retro immediately (v0.8)
- Checkpoint before release execution (v0.11)
- Update checkboxes as you go (v0.11)

### Multi-Repo Coordination
- Unified versioning requires constant awareness (v0.16)
- Unified versioning requires explicit tracking (v0.13)
- Tag inventory check before closing (v0.16)
- Packer images required for unified release (v0.15)

### Technical Gotchas
- Use stable markers for detection, not service status (v0.19)
- Provider upgrades need cache clearing (v0.18)
- Feature prerequisites propagate (v0.18)
- Tag collision requires manual reset (v0.16)
- GitHub 2GB release asset limit (v0.9)

### Planning & Design
- Design-first for complex features (v0.14)
- Plan discussions surface design decisions (v0.12)
- Dogfooding validates design (v0.14)

### Human Factors
- Never discard uncommitted changes without asking (v0.17)
- Context window compaction causes confusion (v0.13)
- Fatigue at end of release leads to shortcuts (v0.19)
