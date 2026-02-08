# Development Lifecycle Overview

This document describes the phased approach to software development used in homestak-dev repositories. It serves as operational context for Claude Code and as a reference for human contributors.

## Purpose

Standardize the development and release process to ensure:
- Consistent quality across bug fixes, enhancements, and features
- Clear human-in-the-loop checkpoints
- Reproducible releases across multiple repositories
- Continuous improvement through structured retrospectives

## Principles

1. **Right-size the process**: Not every change needs every phase. Match rigor to risk.
2. **Human in the loop**: Humans initiate, review, approve, and release. Claude Code proposes and executes.
3. **Document as you go**: Capture decisions and rationale during work, not after.
4. **Learn from every sprint**: After Action Reports and Retrospectives drive improvement.

## Key Terminology

| Term | Definition |
|------|------------|
| **Sprint** | A focused work period (2-5 days) containing related issues. May or may not end in a release. |
| **Release** | A versioned, tagged set of artifacts published to GitHub. Multiple sprints may accumulate before release. |
| **Trunk** | The `master` branch. Direct commits or quick PRs for simple fixes. |
| **Sprint branch** | A branch named `sprint/{theme}` for structured multi-issue work. |

## Branch Model: Hybrid

The hybrid branch model supports both quick fixes and structured sprint work:

```
master ─────●─────●───────────────────●─────●─────●───▶
            │     │                   ↑     │     │
          bugfix docs               merge  bugfix docs
            │     │                   │
            │     │   sprint/... ──●───●───┘
            │     │                f1  f2
            │     │
         (trunk path)           (sprint path)
```

### When to Use Each Path

| Scenario | Path | Branch Name | Merge Strategy | Rationale |
|----------|------|-------------|----------------|-----------|
| Bug fix (Simple tier) | Trunk | `fix/123-desc` or direct | Squash | Quick, isolated |
| Doc updates | Trunk | `docs/topic` or direct | Squash | Non-functional |
| Single-issue enhancement | Trunk | `enhance/123-desc` | Squash | Simple enough |
| Multi-issue sprint | Sprint branch | `sprint/theme` | Merge commit | Coordinated work, preserve history |
| Complex/Exploratory work | Sprint branch | `sprint/theme` | Merge commit | Benefits from isolation |
| Cross-repo changes | Sprint branch | Same branch name in affected repos | Merge commit | Coordinated merge |

### Sprint Branch Naming

Format: `sprint/{theme}`

- `{theme}` is a short kebab-case description

Examples:
- `sprint/recursive-pve` - Sprint focused on recursive PVE stabilization
- `sprint/ci-cd-phase2` - Sprint for CI/CD improvements

## Work Tiers

Work is classified into tiers that determine process rigor:

| Tier | Definition | Session Strategy | Quality Gate | Doc Requirement |
|------|------------|------------------|--------------|-----------------|
| **Simple** | Bug fixes, typos, config tweaks | Informal | PR review + tests pass | None expected |
| **Standard** | Single-issue enhancements | Issue comments | PR + test scenario + smoke test | Update if behavior changes |
| **Complex** | Multi-issue sprints, architectural changes | Issue + decision log | PR + test plan + validation run | CLAUDE.md required |
| **Exploratory** | New patterns, research-driven work | Issue + ADR + dead-ends log | PR + ADR approved + integration test | CLAUDE.md + README required |

### Tier Selection Guide

| Question | Simple | Standard | Complex | Exploratory |
|----------|--------|----------|---------|-------------|
| Touches multiple repos? | No | Maybe | Often | Usually |
| Requires design decisions? | No | Minor | Yes | Many |
| Changes architecture? | No | No | Maybe | Usually |
| Has clear acceptance criteria? | Yes | Yes | Yes | Discovered during work |
| Known solution path? | Yes | Yes | Usually | No |

## Phase Applicability Matrix

| Phase | Simple | Standard | Complex | Exploratory |
|-------|--------|----------|---------|-------------|
| 10-Sprint Planning | Light | Yes | Full | Full + ADR |
| 20-Design | Skip | Light | Full | Full + ADR |
| 25-Documentation | Skip | If changed | Required | Required |
| 30-Implementation | Yes | Yes | Yes | Yes |
| 40-Validation | Smoke | Scenario | Full suite | Full + new tests |
| 50-Merge | Squash | Squash | Merge commit | Merge commit |
| 55-Sprint Close | Skip | Quick | Full | Full + ADR archive |
| 60-Release | Batched | Batched | Batched | Batched |
| 70-Retrospective | Skip | Brief | Full | Full + lessons |

## Sprint vs Release Lifecycle

### Sprint Lifecycle

A sprint is a focused work period with its own lifecycle:

```
Sprint Issue Created
        │
        ▼
   10-Sprint Planning ───▶ Scope defined, branches created
        │
        ▼
   20-Design ─────────────▶ Technical approach (scaled to tier)
        │
        ▼
   25-Documentation ──────▶ CLAUDE.md, README updates
        │
        ▼
   30-Implementation ─────▶ Code, tests, CHANGELOG
        │
        ▼
   40-Validation ─────────▶ Integration tests
        │
        ▼
   50-Merge ──────────────▶ PR merged to master
        │
        ▼
   55-Sprint Close ───────▶ Retrospective, update release issue
        │
        ▼
   Sprint Issue Closed
```

### Release Lifecycle

A release aggregates one or more sprints:

```
Release Issue Created (theme-first)
        │
        ├──── Sprint A completed ───▶ Update release issue
        │
        ├──── Sprint B completed ───▶ Update release issue
        │
        ▼
   60-Release ────────────▶ When critical mass reached
        │
        ├── 61-Preflight ──────▶ Check validation evidence
        ├── 62-CHANGELOG ──────▶ Version headers
        ├── 63-Tags ───────────▶ [GATE] Create tags
        ├── 64-Packer ─────────▶ Image handling
        ├── 65-Publish ────────▶ [GATE] GitHub releases
        ├── 66-Verify ─────────▶ Verification
        ├── 67-AAR ────────────▶ After Action Report
        └── 68-Housekeeping ───▶ Branch cleanup
        │
        ▼
   70-Retrospective ──────▶ Release retrospective
        │
        ▼
   Release Issue Closed
```

## Multi-Repo Structure

homestak-dev is a polyrepo workspace containing 9 repositories:

**Meta repositories** (release process, documentation):
1. **.github** - Organization templates and PR defaults
2. **.claude** - Claude Code configuration and skills
3. **homestak-dev** - Workspace parent, release methodology

**Core repositories** (functional dependencies):
4. **site-config** - Configuration and secrets
5. **tofu** - VM provisioning modules
6. **ansible** - Host configuration playbooks
7. **bootstrap** - Installation and CLI
8. **packer** - Custom images (requires build host)
9. **iac-driver** - Orchestration (depends on all above)

### Repository Dependency Order

Releases follow dependency order (downstream depends on upstream):

```
.github → .claude → homestak-dev → site-config → tofu → ansible → bootstrap → packer → iac-driver
```

### Unified Versioning

All repos get the same version tag on each release, even if unchanged. This simplifies tracking - "homestak v0.18" means all repos at v0.18.

### Cross-Repo Sprint Branches

For sprints touching multiple repos, create the same branch name in each affected repo:

```bash
# Create sprint branch in all affected repos
for repo in iac-driver ansible tofu; do
  cd ~/homestak-dev/$repo
  git checkout -b sprint/recursive-pve
done
```

## Human-in-the-Loop Touchpoints

| Touchpoint | Phase | Action |
|------------|-------|--------|
| Sprint initiation | Sprint Planning | Human defines scope and priorities |
| Tier classification | Sprint Planning | Human approves work tier |
| Design review | Design | Human approves approach before implementation |
| Implementation review | Implementation | Human reviews proposed changes |
| Validation review | Validation | Human reviews or executes integration tests |
| PR approval | Merge | Human reviews, approves, and merges PR |
| Sprint close | Sprint Close | Human reviews retrospective |
| Release gates | Release (63, 65) | Human approves tags and publishing |
| Retrospective | Retrospective | Human reflects on process and codifies lessons |

## Validation Scenarios

Integration testing uses iac-driver scenarios:

| Scenario | Purpose | Duration |
|----------|---------|----------|
| `./run.sh test -M n1-push -H <host>` | Quick validation (provision → boot → verify → destroy) | ~2 min |
| `./run.sh test -M n2-tiered -H <host>` | Tiered validation (PVE + nested VM) | ~9 min |
| `packer-build-fetch` | Build and retrieve packer images | ~5 min |

## Related Documents

### Lifecycle Phases
- [05-session-management.md](05-session-management.md) - Session and context management
- [10-sprint-planning.md](10-sprint-planning.md) - Sprint planning and branch creation
- [20-design.md](20-design.md) - Design artifacts and review
- [25-documentation.md](25-documentation.md) - Knowledge management
- [30-implementation.md](30-implementation.md) - Development, testing, and documentation
- [40-validation.md](40-validation.md) - Integration testing
- [50-merge.md](50-merge.md) - PR process and merge strategies
- [55-sprint-close.md](55-sprint-close.md) - Sprint retrospective and release readiness
- [60-release.md](60-release.md) - Release coordination overview
- [61-release-preflight.md](61-release-preflight.md) - Preflight checks
- [62-release-changelog.md](62-release-changelog.md) - CHANGELOG updates
- [63-release-tag.md](63-release-tag.md) - Tag creation
- [64-release-packer.md](64-release-packer.md) - Packer images
- [65-release-publish.md](65-release-publish.md) - GitHub releases
- [66-release-verify.md](66-release-verify.md) - Verification
- [67-release-housekeeping.md](67-release-housekeeping.md) - Branch cleanup
- [68-release-aar.md](68-release-aar.md) - After Action Report
- [69-release-retro.md](69-release-retro.md) - Release retrospective and lessons learned
- [75-lessons-learned.md](75-lessons-learned.md) - Accumulated release insights
- [80-reference.md](80-reference.md) - Quick reference and checklists

### Templates
- [../templates/sprint-issue.md](../templates/sprint-issue.md) - Sprint tracking issue
- [../templates/release-issue.md](../templates/release-issue.md) - Release planning issue
- [../templates/aar.md](../templates/aar.md) - After Action Report
- [../templates/retrospective.md](../templates/retrospective.md) - Retrospective
