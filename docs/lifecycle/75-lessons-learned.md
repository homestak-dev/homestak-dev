# Lessons Learned

Accumulated insights from homestak-dev releases v0.8-v0.45. Each lesson was codified in the retrospective phase of its respective release.

## How to Use This Document

- **Before release:** Scan recent lessons to avoid repeating mistakes
- **During release:** Reference when encountering issues
- **After release:** Add new lessons from retrospective, commit with `docs: Update 75-lessons-learned.md with vX.Y lessons`

## v0.45

- **Release execute must continue through AAR and Retrospective** - The `/release execute` skill should automatically generate AAR and Retrospective after Housekeeping, not stop and prompt the user to complete them manually. The user reviews and approves, but doesn't generate. This release initially stopped after Phase 67, requiring correction.
- **Sprint validation doesn't satisfy release validation gate** - Even when all sprints have validation evidence (spec-vm-roundtrip, vm-roundtrip), the release.sh state file tracks its own validation phase. Running `release.sh validate` is required during release execution to satisfy the tag precondition.
- **Phase reordering (67↔68) improves AAR completeness** - Moving Housekeeping before AAR (implemented in v0.45) allows the AAR to include branch cleanup results and any issues discovered during housekeeping. This is a process improvement from v0.44 lesson.

## v0.44

- **Closed release before retrospective - fourth occurrence** - Despite prior lessons (v0.25, v0.26, v0.29), same error repeated. The `release.sh close --force` bypasses validation check but doesn't verify retrospective completion. Need stronger guardrail: either block close until retrospective posted, or require explicit `--skip-retrospective` flag.
- **Housekeeping should precede AAR** - Current phase order (67-AAR, 68-Housekeeping) means AAR is written before cleanup completes. Reordering to Housekeeping→AAR would let the report include cleanup results and any issues discovered.

## v0.43

- **CHANGELOG finalization is not verified by preflight** - Phase 2 requires human attention to move "Unreleased" content to version headers. Unlike tags and clean trees, this step has no automated verification, making it easy to skip accidentally. v0.42 was tagged with #146, #148, #149 still in Unreleased.
- **Forward-fixing CHANGELOGs is acceptable** - When CHANGELOG attribution errors are discovered post-release, fixing on master preserves accurate history going forward. Tags are immutable snapshots but master is the living documentation.
- **Multi-session releases compound CHANGELOG risk** - Quick successive releases (v0.41→v0.42) increase risk of skipping Phase 2 CHANGELOG step due to fatigue or haste. Same-session release completion reduces this risk.

## v0.42

- **Pre-merge validation is useful but disconnected from release state** - Running integration tests during implementation phase (via iac-driver directly) validates the code but does not satisfy the release.sh validation gate. Either standardize on `release.sh validate` for all validation, or document that pre-merge validation requires re-running through release.sh.

## v0.41

- **Skills load context for one phase, not the entire process** - The /release-preflight skill covers Phase 0-1 but doesn't ensure subsequent phases are followed correctly. Post-release smoke test, scope issue verification, and sunset check were all skipped until user requested re-read of 60-release.md. The release executor must reference 60-release.md at each phase transition, not just at preflight.
- **Exploratory features expand scope** - When a release theme involves first-time implementation (n3-full), expect 50-100% scope expansion as hidden requirements surface. v0.41 grew from 9 planned items to 16 delivered (~78% expansion). Plan accordingly or split into exploration + stabilization releases.
- **Validation scenario should match release theme** - Using vm-roundtrip to validate a recursive-pve release is insufficient. The release's headline feature should be exercised during validation. Created #149 for configurable validation scenarios.
- **AAR requires scope comparison, not just delivery list** - Initial AAR listed "None" for deviations despite significant scope growth. Explicitly compare delivered items against original scope definition to reveal deviations.
- **Packer image copy inherits metadata** - The GHA copy-images workflow preserves source release notes, causing confusing "What's Changed" sections referencing old PRs. Created #148 to clear notes when copying.

## v0.40

- **Integration boundary blindness** - Design focused on new code (manifests, recursive actions) but didn't trace execution through existing subsystems. The nested-pve ansible role hardcodes `/opt/homestak/` but FHS installations use `/usr/local/etc/homestak/`. This blocked n3-full validation. Added "Integration Boundary Analysis" section to 20-design.md with explicit tracing checklist.
- **Known constraints not applied** - We knew GitHub has a 2GB file limit and that debian-13-pve.qcow2 is ~6GB (that's why we split it). But `DownloadGitHubReleaseAction` wasn't audited for this constraint. Added "Known Constraints Registry" to 20-design.md.
- **N+1 analysis principle** - "It works for N=2" doesn't mean "it works for N=3". Each additional nesting level can surface path, memory, or timeout issues not visible at lower depths. Added "N+1 Analysis" section to 20-design.md.
- **Audit existing components for new use cases** - When reusing existing actions/roles in new contexts, explicitly audit their assumptions. The download action assumed single files; split file support had to be added mid-release.
- **Stabilization releases must deliver core functionality** - A release themed "stabilization" that can't run its headline feature (n3-full) is a planning failure. Either scope appropriately or ensure blockers are identified in design.

## v0.39

- **Base64 encoding for SSH scripts** - Complex Python scripts passed through SSH need base64 encoding to avoid shell quoting issues. Heredocs and escaping fail with certain content (like SSH key material). Pattern: `echo '<base64>' | base64 -d | python3 -`.
- **Provider lockfile caching in iac-driver** - The `.states/{env}-{node}/data/` directories cache tofu provider lockfiles. When provider version constraints change (e.g., Dependabot PRs), stale lockfiles cause validation failures. Clear state directories or add preflight check for version mismatches.
- **Multi-level SSH key injection** - Each nesting level in recursive scenarios needs both the outer host's SSH key AND its own key injected into secrets.yaml. The outer key enables jump chains; the inner key enables the level to SSH to VMs it creates.
- **GitHub issue auto-close limitations** - Multiple "Closes #N" references on the same line in commit messages may not auto-close all issues. Use separate lines or close manually after merge.
- **Verify all PR merges before release** - Check each repo explicitly when multiple PRs are in flight. Easy to miss one (tofu#32 was missed in v0.39) when moving quickly through multi-repo releases.

## v0.37

- **Sync local branches after squash-merge** - After GitHub squash-merges a PR, local feature branches diverge because the merge commit SHA differs from the local branch. Run `git reset --hard origin/master` immediately after merge to avoid branch state confusion during release. This was the third occurrence of this friction point.
- **Initialize release state at phase start** - Run `release.sh init --version X.Y --issue N` as the very first step of the release phase, before preflight. The state file tracks validation status and enables phase gating. Running init mid-release causes "validation not complete" errors even when tests passed.

## v0.33

- **Two-phase CHANGELOG workflow** - Add entries under "Unreleased" during Implementation phase (30-implementation.md). Add version header (`## vX.Y - YYYY-MM-DD`) during Release Phase 2. This keeps feature changes with their PRs while deferring version assignment to release time.
- **Mark infrastructure tests for CI exclusion** - Tests requiring site-config, configured hosts, or API access should use a marker (e.g., `@requires_infrastructure` for pytest) and be excluded in CI via `-m "not requires_infrastructure"`. This enables comprehensive local testing while keeping CI green.
- **Don't auto-close release issues from scope PRs** - PR descriptions with "Closes #N" can prematurely close the release planning issue when the PR is for scope items, not the release itself. Keep release issue references separate from scope PR descriptions.
- **Verify GitHub Action versions exist** - Action versions like `actions/checkout@v6` may not exist yet. Always verify current versions at github.com/actions/{name}/releases before using in CI workflows. At time of v0.33: checkout@v4, setup-python@v5.

## v0.32

- **Git-derived versions eliminate release maintenance** - Using `git describe --tags --abbrev=0` to derive version at runtime means scripts never need VERSION constant updates during releases. Zero maintenance, always accurate. Pattern documented in `docs/CLI-CONVENTIONS.md`.
- **Pre-existing lint warnings can block new PRs** - Shellcheck warnings in `build.sh` (existing code) blocked the CLI standardization PR even though the new code was clean. Consider adding shellcheck to local dev workflow (`make lint`) to catch issues early.
- **CHANGELOGs should be in feature PRs** - Updating CHANGELOGs separately during release is error-prone. Include CHANGELOG entries in feature PRs so they're reviewed together and committed atomically.

## v0.31

- **50-merge.md applies to direct master commits** - Even without PRs, the merge phase checklist (commits, pushes, CHANGELOGs) must be completed before tagging. The user catching uncommitted changes before proceeding to tags prevented a process error.
- **Quality-focused releases are efficient** - Testing infrastructure is inherently testable - low risk, fast validation. The entire release completed in ~30 minutes with 5 scope items.

## v0.30

- **Create release planning issue FIRST** - The release issue must be created at the start of Phase 1 (Pre-flight), not retroactively after release completion. The issue is the tracking hub for the entire release: it receives status updates, hosts the AAR, and documents deviations. Without it from the start, phase tracking via `--issue N` doesn't work, and AAR has no home. This is fundamental to the lifecycle process.
- **AI assistants skip implicit steps** - Claude proceeded with `release.sh init` without creating the release issue because the plan summary didn't explicitly list "create release issue" as a step. Lesson: critical process steps that seem obvious to humans need explicit mention in plans, especially when delegating to AI.

## v0.29

- **FHS installations require sudo for scenarios** - Bootstrap installs to `/usr/local/lib/homestak/` as root, so `homestak scenario` and `homestak playbook` commands need sudo. Document this requirement prominently.
- **Legacy path migration requires fresh bootstrap** - Hosts with `/opt/homestak/` (pre-v0.26) need complete removal and re-bootstrap to get FHS paths with correct ownership. `rm -rf /opt/homestak && curl ... | sudo bash` is the cleanest fix.
- **Clean temp files between validation runs** - Leftover `/tmp/*.tfvars.json` files from previous runs can cause permission errors if ownership differs. Consider using unique temp file names or cleaning up after runs.
- **YAML manipulation in shell scripts is fragile** - The site-init SSH key injection broke YAML indentation. Use proper YAML libraries (Python yaml module) for modifications instead of sed/echo appends.
- **Closing before retrospective: third occurrence** - Same process error as v0.25 and v0.26. The `close` command's reminder checklist isn't preventing this. Need to either block close until retrospective is posted, or require `--force` to close without retrospective.

## v0.28

- **Ansible CLI booleans are strings** - When passing `-e var=true` via CLI, Ansible receives a string, not a boolean. Always use `| bool` filter in conditionals for variables that might come from extra-vars (e.g., `when: bootstrap_use_local | bool`).
- **GitHub 'latest' is API-only** - The 'latest' release concept only works via GitHub API, not in download URLs. URLs like `https://github.com/.../releases/download/latest/file` return 404. Must query API to resolve actual tag name first.
- **Discovery patterns simplify cleanup** - Pattern-based VM discovery (e.g., `nested-pve*` in vmid range 99800-99999) is more robust than context-file dependency for destructors. Works without prior context and handles partial states gracefully.
- **publish command needs --yes flag** - Unlike `tag --execute --yes`, the `publish` command lacks a `--yes` flag, requiring workarounds like `<<< "yes"` for non-interactive execution.

## v0.27

- **Use `tag --yes` for non-interactive execution** - The new `--yes` flag eliminates the need to pipe "yes" to stdin. Use `tag --execute --yes` for automated/scripted releases. This supersedes the v0.26 workaround.
- **CLI-only releases can skip validation** - When changes are limited to release tooling with no infrastructure impact, use `--force` to skip the validation gate. The selftest provides sufficient coverage for CLI changes.
- **Require explicit workflow choice** - Forcing users to specify `--workflow github` or `--workflow local` prevents accidental slow local transfers. The error message guides toward the recommended option.
- **Fix selftest before next release** - The `tag-dry` and `publish-dry` tests fail due to phase precondition requirements in test state. This technical debt should be addressed to maintain test coverage.
- **Passive checklists don't prevent skipped phases** - Even with a reminder in verify output AND a checklist in close output, the retrospective was skipped. Displaying reminders isn't enough; consider requiring explicit acknowledgment or blocking close until all phases are marked complete.

## v0.26

- **Pipe "yes" for non-interactive tag execution** - `echo "yes" | ./scripts/release.sh tag --execute` bypasses confirmation when running non-interactively. The tag command lacks a `--yes` flag, so piping to stdin is the workaround.
- **Verify release issue is open before AAR** - Check issue status before posting AAR; premature closure happened in both v0.25 and v0.26. The release issue should remain open until Phase 10 (Retrospective) is complete and lessons are codified.
- **Same mistake twice = needs automation** - When the same process error happens in consecutive releases, it's a signal that the process needs a guardrail (automation, checklist item, or tooling change), not just documentation.

## v0.25

- **Always use `--workflow github` for publish** - The `publish --execute` command defaults to `--workflow local` which triggers a slow ~13GB download/upload for packer images. Always specify `--workflow github` to use the server-side GHA workflow (~2min vs ~30min). This was the first release to use the new `--workflow` option (implemented in #99).
- **Don't close release issue until checklist complete** - Prematurely closed release issue #100 after AAR, forgetting Phases 9 (Housekeeping) and 10 (Retrospective). Had to reopen and complete remaining phases. Follow the full checklist in 60-release.md.
- **Bats tests need isolated state** - Release.sh tests initially ran against real workspace state files. Fixed by honoring `STATE_FILE` env var to enable test isolation without modifying production state.
- **Use the tools you build** - Implemented context loss mitigation (#98) but didn't use `release.sh resume` or `status` to verify all phases were complete before closing the release issue. The tools only help if you use them.

## v0.24

- **Initialize release state before validation** - Ran nested-pve-roundtrip before `release.sh init`, so validation status wasn't tracked. Tag command failed with "Validation not complete (status: pending)" despite test passing. Always run `release.sh init --version X.Y` before `release.sh validate`, or the validation results won't be recorded in the release state.
- **Session continuations lose release context** - Context compaction during multi-session releases causes confusion about what's done vs pending. The release.sh audit log (`.release-audit.log`) and status command help recover state, but it's better to complete releases in a single session when possible.
- **Housekeeping before Retrospective** - Branch cleanup should happen before the retrospective so any issues discovered during cleanup can be captured. Reordered phases: Phase 9 is now Housekeeping, Phase 10 is now Retrospective (which closes the release issue).

## v0.23

- **Diagnosing a bug is not permission to fix it** - When user asked "what's going on with release verify?", the correct response was diagnosis + proposed fix + wait for approval. Instead, jumped straight from diagnosis to editing code and pushing to master. Ironic given this release added "Process Discipline" guidelines to CLAUDE.md. The fix was correct; the process was not. Always pause after proposing a fix and ask "should I implement this?" before touching code.

## v0.22

- **Always use `--prerelease` for v0.x releases** - Early releases (v0.7-v0.13) were created without `--prerelease`, causing GitHub's "Latest Release" badge to show stale versions. Required retroactive fix of 27 releases.
- **Update release tooling when patterns change** - release.sh verify assumed versioned packer releases have assets, but latest-centric approach puts images only in `latest`. Tooling must evolve with process changes.
- **Wait for explicit user confirmation** - AI assistant acted on a recommendation without user confirmation. When presenting options, always wait for explicit selection before executing.
- **Audit historical release metadata periodically** - Prerelease flags, release notes, and asset attachments can drift from intended state over time.
- **Check for open PRs before tagging** - site-config#35 was missed during merge phase and required post-release tag reset. Run `gh pr list --state open` across all repos before creating tags.

## v0.21

- **Cross-repo ripple effects from restructuring** - Packer's per-template directory change (#19) broke ansible's nested-pve role which expected the old path structure. When restructuring one repo, test the full chain of dependent repos before release.
- **`latest` release requires manual handling** - release.sh adds "v" prefix (causing "vlatest"), and GHA workflow validation rejects non-vX.Y targets. The `latest` packer release must be updated manually after each release.
- **Run benchmarks during release** - Executing homestak-dev#75 during v0.21 release provided actionable data immediately. Infrastructure is already set up, context is fresh, and results inform the current release decision.
- **Validation as hard gate confirmed** - v0.21 caught two bugs (packer#32, ansible role) during validation phase before any tags were created. Reinforces v0.12 lesson: always validate before tagging.

## v0.20

- **Branch cleanup needed after squash/rebase merges** - Branches may show as "ahead" by commit count even when content was merged via squash/rebase. Use `git diff master..branch` to verify actual unmerged content, not just commit history. Delete branches immediately after PR merge.
- **Options inconsistent with process should be flagged** - When presenting options to the user, any option that deviates from established process (e.g., lifecycle docs) should be clearly marked as such. Don't offer "push direct to master" as an equal option alongside "create PR" when process requires PRs.
- **Configure auto-delete for PR branches** - Enable repository settings to auto-delete branches after PR merge to prevent stale branch accumulation across repos.

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
- Validation scenario should match release theme (v0.41)
- Mark infrastructure tests for CI exclusion (v0.33)
- Validation as hard gate confirmed (v0.21)
- Validate optimizations before merging (v0.19)
- Test the actual CLI flow end-to-end (v0.18)
- Verify external tool behavior, don't assume (v0.18)
- Integration test is not optional (v0.9)
- Test before announcing completion (v0.13)
- Create formal test plans for risky changes (v0.13)

### Process Discipline
- Closed release before retrospective - fourth occurrence (v0.44)
- Housekeeping should precede AAR (v0.44)
- Skills load context for one phase, not the entire process (v0.41)
- AAR requires scope comparison, not just delivery list (v0.41)
- Two-phase CHANGELOG workflow (v0.33)
- Don't auto-close release issues from scope PRs (v0.33)
- Closing before retrospective: third occurrence (v0.29)
- Passive checklists don't prevent skipped phases (v0.27)
- CLI-only releases can skip validation (v0.27)
- Same mistake twice = needs automation (v0.26)
- Verify release issue is open before AAR (v0.26)
- Housekeeping before Retrospective (v0.24)
- Initialize release state before validation (v0.24)
- Wait for explicit user confirmation (v0.22)
- Check for open PRs before tagging (v0.22)
- Run benchmarks during release (v0.21)
- Options inconsistent with process should be flagged (v0.20)
- CHANGELOG updates belong in PRs, not release (v0.19)
- Follow process to the end (v0.19)
- AAR/Retro are required, not optional (v0.15)
- Complete AAR/retro immediately (v0.8)
- Checkpoint before release execution (v0.11)
- Update checkboxes as you go (v0.11)

### Branch Management
- Branch cleanup needed after squash/rebase merges (v0.20)
- Configure auto-delete for PR branches (v0.20)

### Multi-Repo Coordination
- Cross-repo ripple effects from restructuring (v0.21)
- Unified versioning requires constant awareness (v0.16)
- Unified versioning requires explicit tracking (v0.13)
- Tag inventory check before closing (v0.16)
- Packer images required for unified release (v0.15)

### Technical Gotchas
- Packer image copy inherits metadata (v0.41)
- Verify GitHub Action versions exist (v0.33)
- FHS installations require sudo for scenarios (v0.29)
- Legacy path migration requires fresh bootstrap (v0.29)
- Clean temp files between validation runs (v0.29)
- YAML manipulation in shell scripts is fragile (v0.29)
- Ansible CLI booleans are strings (v0.28)
- GitHub 'latest' is API-only (v0.28)
- Discovery patterns simplify cleanup (v0.28)
- publish command needs --yes flag (v0.28)
- Use `tag --yes` for non-interactive execution (v0.27, supersedes v0.26)
- Require explicit workflow choice (v0.27)
- Always use `--prerelease` for v0.x releases (v0.22)
- Update release tooling when patterns change (v0.22)
- Audit historical release metadata periodically (v0.22)
- `latest` release requires manual handling (v0.21)
- Use stable markers for detection, not service status (v0.19)
- Provider upgrades need cache clearing (v0.18)
- Feature prerequisites propagate (v0.18)
- Tag collision requires manual reset (v0.16)
- GitHub 2GB release asset limit (v0.9)

### Planning & Design
- Exploratory features expand scope (v0.41)
- Integration boundary blindness (v0.40)
- Known constraints not applied (v0.40)
- N+1 analysis principle (v0.40)
- Audit existing components for new use cases (v0.40)
- Stabilization releases must deliver core functionality (v0.40)
- Design-first for complex features (v0.14)
- Plan discussions surface design decisions (v0.12)
- Dogfooding validates design (v0.14)

### Human Factors
- Session continuations lose release context (v0.24)
- Never discard uncommitted changes without asking (v0.17)
- Context window compaction causes confusion (v0.13)
- Fatigue at end of release leads to shortcuts (v0.19)
