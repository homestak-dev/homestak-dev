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

## Work Type Classification

| Type | Description | Typical Scope |
|------|-------------|---------------|
| **Bug Fix** | Corrects incorrect behavior | 1-2 files, existing tests may need updates |
| **Minor Enhancement** | Small improvements to existing functionality | Limited scope, low risk |
| **Feature** | New capability or significant change | Multiple files, new tests, documentation |

## Phase Applicability Matrix

| Phase | Bug Fix | Minor Enhancement | Feature |
|-------|---------|-------------------|---------|
| 10-Planning | ✓ | ✓ | ✓ |
| 20-Design | Skip | Lightweight | Full |
| 30-Implementation | ✓ | ✓ | ✓ |
| 40-Validation | ✓ | ✓ | ✓ |
| 50-Merge | ✓ | ✓ | ✓ |
| 60-Release | ✓ | ✓ | ✓ |

## Human-in-the-Loop Touchpoints

| Touchpoint | Phase | Action |
|------------|-------|--------|
| Sprint initiation | Planning | Human defines scope and priorities |
| Design review | Design | Human approves approach before implementation |
| Implementation review | Implementation | Human reviews proposed changes |
| Validation review | Validation | Human reviews or executes integration tests |
| PR approval | Merge | Human reviews, approves, and merges PR |
| Release execution | Release | Human executes release commands |

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

## Sprint Cadence

Typical sprint: 2-3 days containing either:
- 3-8 issues (bug fixes and minor enhancements), OR
- 1-2 features

## Validation Scenarios

Integration testing uses iac-driver scenarios:

| Scenario | Purpose | Duration |
|----------|---------|----------|
| `vm-roundtrip` | Quick validation (provision → boot → verify → destroy) | ~2 min |
| `nested-pve-roundtrip` | Full stack validation (including PVE installation) | ~9 min |
| `packer-build-fetch` | Build and retrieve packer images | ~5 min |

## Related Documents

- [10-planning.md](10-planning.md) - Sprint planning and backlog formation
- [20-design.md](20-design.md) - Design artifacts and review
- [30-implementation.md](30-implementation.md) - Development, testing, and documentation
- [40-validation.md](40-validation.md) - Integration testing
- [50-merge.md](50-merge.md) - PR process and global documentation
- [60-release.md](60-release.md) - Release coordination, tagging, and retrospective
- [../templates/](../templates/) - Reusable templates for AAR, retrospective, issues
