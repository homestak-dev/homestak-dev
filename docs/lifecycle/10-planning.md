# Phase: Planning

Planning establishes the scope and priorities for a sprint. This phase applies to all work types.

## Inputs

- Human-provided sprint scope (issues, features, priorities)
- Repository issue tracker state
- Previous sprint retrospective (if applicable)

## Activities

### 1. Sprint Initiation

Human initiates the sprint by defining:
- Which issues/features to include
- Priority order
- Any constraints (deadlines, dependencies, blocked items)

### 2. Scope Agreement

- Review candidate issues for the release
- Prioritize based on value, dependencies, and risk
- Agree on what's in-scope vs deferred
- Consider release size (prefer smaller, focused releases)

### 3. Create Release Plan Draft

Create a GitHub issue using the [Release Issue Template](../templates/release-issue.md):

- Title: `vX.Y Release Planning - Theme`
- Capture agreed scope with issue references
- Note deferred items and rationale
- Set status to "Planning"

Examples:
- `v0.10 Release Planning - Housekeeping`
- `v0.11 Release Planning - Code Quality`
- `v0.20 Release Planning - Recursive Nested PVE`

### 4. Issue Triage and Classification

For each item in scope:
- Classify as Bug Fix, Minor Enhancement, or Feature
- Verify issue description is clear and actionable
- Identify acceptance criteria (explicit or inferred)
- Flag items needing clarification

### 5. Effort Estimation

Provide rough effort estimates:
- **Small**: < 1 hour (simple bug fix, config change)
- **Medium**: 1-4 hours (typical enhancement, moderate bug)
- **Large**: 4+ hours (feature, complex bug, refactor)

Estimates inform sprint capacity, not commitments.

### 6. Dependency Mapping

Identify:
- Cross-repo dependencies (follow [repository dependency order](00-overview.md#repository-dependency-order))
- Order constraints (X must complete before Y)
- External blockers

### 7. Sprint Backlog Formation

Produce an ordered list of work items with:
- Issue reference
- Classification (bug/enhancement/feature)
- Effort estimate
- Applicable phases (per Phase Applicability Matrix)
- Acceptance criteria summary

### 8. Issue-Level Planning

For each in-scope issue, document planning details:

| Aspect | Content |
|--------|---------|
| Requirements | Acceptance criteria, constraints |
| Design | Technical approach, alternatives considered |
| Implementation | Files to modify, sequence |
| Testing | How to verify, test scenarios |
| Documentation | CLAUDE.md, CHANGELOG, other docs |

Attach planning details to each issue as a comment before implementation. See [20-design.md](20-design.md) for detailed design guidance and templates.

### 9. Update Release Plan

Roll up issue-level planning into the release plan issue:

- Add implementation order/dependencies
- Identify critical path items
- Note any risks or open questions
- Update status to "In Progress" when starting execution

## Cross-Repo Considerations

### Site-Config Prerequisites

Verify configuration requirements:
- `site-config/nodes/{hostname}.yaml` for target hosts
- API tokens in `site-config/secrets.yaml`
- Secrets decrypted (`make decrypt`)

### Validation Host Requirements

A "bootstrapped" host is not automatically validation-ready. Prerequisites:

| Prerequisite | Description |
|--------------|-------------|
| Node configuration | `site-config/nodes/{hostname}.yaml` must exist |
| API token | Token in `site-config/secrets.yaml` |
| Secrets decrypted | `site-config/secrets.yaml` exists |
| Packer images | Images published to local PVE storage |
| SSH access | SSH key access to the validation host |
| Nested virtualization | For nested-pve scenarios |

## Outputs

- Release plan issue (GitHub issue with scope and checklists)
- Sprint backlog document or issue list
- Issue-level planning comments
- Clarification questions for human (if any)

## Checklist: Planning Complete

- [ ] Release plan issue created with scope
- [ ] All items classified by work type
- [ ] Acceptance criteria identified for each item
- [ ] Effort estimates assigned
- [ ] Dependencies mapped
- [ ] Issue-level planning documented
- [ ] Sprint backlog reviewed and approved by human
