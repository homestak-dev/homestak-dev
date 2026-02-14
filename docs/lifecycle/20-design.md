# Phase: Design

Design establishes the technical approach before implementation. The depth of design scales with work type.

## When to Design

Not every issue needs full design. Use this guide:

| Issue Type | Design Needed |
|------------|---------------|
| New feature | Yes - full design |
| Enhancement to existing feature | Yes - abbreviated |
| Bug fix with clear root cause | No - just fix it (but see [Bug Validation](#bug-validation)) |
| Documentation update | No |
| Refactoring | Yes - identify test coverage first |
| Performance optimization | Yes - establish baseline first |

**Rule of thumb:** If you're unsure how to approach it, design it.

## Applicability by Tier

| Tier | Design Depth |
|------|--------------|
| Simple | **Skip** - proceed directly to Implementation |
| Standard | **Lightweight** - brief approach summary |
| Complex | **Full** - complete design artifacts |
| Exploratory | **Full + ADR** - design with Architecture Decision Record |

See [00-overview.md](00-overview.md) for tier definitions.

## Inputs

- Approved sprint backlog item
- Existing codebase and architecture
- Related documentation

## Bug Validation

Before designing a fix for any bug, verify the root cause — even if the issue seems clear. The initial diagnosis may be wrong.

**Steps:**
1. **Reproduce the issue** — trigger the bug in a controlled environment and confirm the symptoms
2. **Root cause analysis** — investigate before proposing a fix; don't assume the first theory is correct
3. **Update the issue** — if the root cause differs from the initial report, correct the title and description

**Example:** iac-driver#176 was filed as "DNS resolution failure" but live debugging revealed the actual root cause was a stale server process. Design work on a DNS fix would have been wasted effort.

**When to skip:** If you already confirmed root cause during [Bug Triage](10-sprint-planning.md#bug-triage) in sprint planning, a brief re-verification is sufficient.

## Activities

### Understand the Problem

Before designing a solution, ensure you understand:

**Requirements:**
- What is the acceptance criteria?
- What are the constraints?
- What is explicitly out of scope?

**Context:**
- What existing code/patterns does this touch?
- Who/what depends on this?
- Are there related issues or prior attempts?

**Success Criteria:**
- How will we know this works?
- What does "done" look like?

### Lightweight Design (Minor Enhancements)

Produce a brief summary covering:
- What changes and where
- Any interface or behavior changes
- Risk assessment (what could break)

Format: A few sentences to a short paragraph, can be included in implementation plan.

### Full Design (Features)

Produce design artifacts covering:

#### 1. Problem Statement
- What need does this feature address?
- What are the success criteria?

#### 2. Proposed Solution
- High-level approach
- Key components affected
- New components introduced

#### 3. Interface Design
- Public APIs or contracts introduced/modified
- Data structures
- Configuration changes

#### 4. Integration Points
- How this interacts with existing functionality
- Cross-repo implications

#### 5. Risk Assessment
- What could go wrong
- Backward compatibility concerns
- Performance implications

#### 6. Alternatives Considered
- Other approaches evaluated
- Rationale for chosen approach

Use the [Design Summary Template](../templates/design-summary.md) for structured documentation.

### Design Artifact Location

Where to put design documentation depends on its intended lifespan:

| Design Type | Location | Rationale |
|-------------|----------|-----------|
| Ephemeral (single issue) | Issue comment | Self-contained, no git clutter |
| Long-lasting (reference) | `docs/designs/` | Discoverable, versioned |
| Cross-release (architecture) | `docs/designs/` + ADR | Permanent record |

**Guidelines by tier:**

| Tier | Recommended Location |
|------|---------------------|
| Simple | Issue comment (if any design needed) |
| Standard | Issue comment or sprint issue |
| Complex | `docs/designs/` if others will reference |
| Exploratory | Always `docs/designs/` + ADR |

**File naming for `docs/designs/`:**
- Pattern: `vX.Y-<feature-name>.md`
- Examples: `v0.45-specify-server.md`, `v0.45-specify-client.md`

**When to use `docs/designs/`:**
- Design will be referenced beyond the current sprint
- Multiple sprints build on the same architecture
- Design decisions affect multiple repos
- Onboarding documentation for future contributors

### Design Considerations

| Consideration | Questions to Ask |
|---------------|------------------|
| **Scope** | Am I solving exactly what's asked, or scope-creeping? |
| **Patterns** | Does similar functionality exist? Should I follow that pattern? |
| **Dependencies** | What must exist before this can work? |
| **Backwards compatibility** | Does this break existing behavior? |
| **Error handling** | What happens when things go wrong? |
| **Configuration** | Does this need to be configurable, or should it just work? |

### Integration Boundary Analysis

When a feature spans multiple components or repos, trace the data and control flow explicitly.

**Boundary Tracing Checklist:**

| Question | Example |
|----------|---------|
| What data crosses component boundaries? | Config files, secrets, SSH keys |
| What paths are used at each stage? | FHS `/usr/local/lib/homestak/` vs `$HOMESTAK_LIB` for dev |
| What assumptions does each component make? | "FHS paths exist" vs "env vars set for dev" |
| What happens at N+1 depth/scale? | PVE node runs tofu - where does it find envs? |

**Diagram the flow:**
```
Driver Host                   PVE Node                      Leaf VM
┌──────────┐                  ┌──────────┐                  ┌──────────┐
│ run.sh   │ ──SSH+rsync───▶  │ site-cfg │ ──tofu apply──▶ │ created  │
│ site-cfg │                  │ (where?) │                  │          │
└──────────┘                  └──────────┘                  └──────────┘
```

For recursive/nested scenarios, answer: "When level N runs a command, what paths does it use, and do those paths exist?"

### Path Mode Verification

Any feature running on bootstrapped hosts must work with the FHS installation layout. Dev environments use environment variables.

| Mode | Code Path | Config Path | How |
|------|-----------|-------------|-----|
| FHS (production) | `/usr/local/lib/homestak/` | `/usr/local/etc/homestak/` | Bootstrap default |
| Dev workspace | `$HOMESTAK_LIB` | `$HOMESTAK_ETC` | Env vars |

**Note:** Legacy `/opt/homestak/` is still supported by iac-driver's `get_site_config_dir()` for backward compatibility, but new features (e.g., `./run.sh config`) target FHS paths only.

**Checklist:**
- [ ] Does new code hardcode paths? Use env var with FHS fallback (`$HOMESTAK_LIB` → `/usr/local/lib/homestak/`)
- [ ] Do ansible roles/playbooks use variables for paths, not hardcoded strings?
- [ ] For recursive scenarios: does the inner level use the same path mode as outer?
- [ ] For dev testing: document which env vars must be set (e.g., `HOMESTAK_LIB`, `HOMESTAK_ETC`)

### Known Constraints Registry

Review these constraints during design - they're easy to forget:

| Constraint | Limit | Impact |
|------------|-------|--------|
| GitHub release file size | 2 GB | Large images must be split (`.partaa`, `.partab`) |
| Nested virt memory | 8GB → 4GB practical | Each nesting level reduces available RAM |
| PVE API rate limits | Varies | Polling loops need reasonable intervals |
| SSH connection timeout | 60s default | Long operations need explicit timeout |
| Cloud-init user-data | 16 KB typical | Large scripts should be fetched, not inline |

**When designing, ask:** "Does this feature interact with any known constraints?"

### N+1 Analysis

If a feature works at scale N, explicitly analyze N+1:

| Current | N+1 Question |
|---------|--------------|
| 2-level nesting works | What breaks at 3 levels? Memory? Paths? Timeouts? |
| Single VM deployment | What if deploying 5 VMs? 10? Parallel or sequential? |
| One host validation | What if validating across 2 hosts simultaneously? |

**Document what breaks at N+1** even if N+1 isn't in scope - it informs future work.

### Existing Component Audit

When a feature uses existing actions/roles/modules, audit them for compatibility:

| Question | Why It Matters |
|----------|----------------|
| What inputs does it expect? | New use case may provide different inputs |
| What assumptions does it make? | File exists, service running, path accessible |
| What are its failure modes? | Does it fail gracefully or crash? |
| When was it last tested? | Old code may have undiscovered issues |

**Example (v0.40):** `DownloadGitHubReleaseAction` assumed single-file downloads. When used for `debian-13-pve.qcow2` (6GB, split into parts), it 404'd. An audit would have caught: "What if the file is larger than GitHub's 2GB limit?"

## Validation Scenario Identification

Before writing code, know how you'll prove it works.

| Change Type | Validation Approach |
|-------------|---------------------|
| Packer template | Build image → `./run.sh manifest test -M n1-push` or `n2-tiered` |
| Tofu module | `./run.sh manifest test -M n1-push -H <host>` |
| iac-driver action | Scenario that exercises the action |
| Ansible role | Run playbook on test VM, verify behavior |
| CLI command | Full command flow, including edge cases |
| Boot/startup change | Measure actual timing before AND after |
| release.sh command | `release.sh selftest` + manual verification |

### Document Your Test Plan

```markdown
## Test Plan

**Scenario:** `./run.sh manifest test -M n1-push -H father`

**Steps:**
1. Build image with changes: `./build.sh debian-13-custom`
2. Publish to PVE: `./publish.sh`
3. Run validation: `./run.sh manifest test -M n1-push -H father`

**Expected result:** VM boots, SSH accessible, guest agent responds

**Performance baseline (if applicable):**
- Current: X seconds
- Target: Y seconds or better
```

## Prerequisites Verification

Before starting implementation, verify you have what you need.

| Category | Check |
|----------|-------|
| **Access** | SSH to test hosts? API tokens configured? |
| **Configuration** | site-config entries exist? secrets decrypted? |
| **Artifacts** | Packer images available? Previous release assets? |
| **Dependencies** | Required tools installed? Correct versions? |
| **Environment** | Test environment available? Not in use by others? |

### Cross-Repo Dependencies

If your feature depends on another repo:

1. **Check if dependency exists** - Is it already implemented and released?
2. **If not, implement dependency first** - Don't code against imaginary APIs
3. **If in same sprint, sequence correctly** - Dependency PR merges first

## Risk Identification

What could go wrong? Thinking through risks upfront prevents surprises.

| Category | Example | Mitigation |
|----------|---------|------------|
| **External tools** | CLI flag doesn't exist | Test actual command before implementing |
| **Race conditions** | Service not ready when checked | Use stable markers, not transient state |
| **State assumptions** | Config file exists | Check and fail gracefully with guidance |
| **Performance** | "Optimization" makes things worse | Measure before and after |
| **Breaking changes** | Existing users affected | Document migration path |

## Human Review Checkpoint

Before proceeding to Implementation:
- Present design artifacts to human
- Address questions and feedback
- Obtain explicit approval to proceed

## Outputs

- Design summary (lightweight) or design document (full)
- Test plan with validation scenario
- Prerequisites verified
- Risks identified
- Human approval to proceed

## Checklist: Design Complete

### Lightweight
- [ ] Approach summary documented
- [ ] Risk identified
- [ ] Validation scenario identified
- [ ] Human approved

### Full
- [ ] Problem statement clear
- [ ] Solution approach documented
- [ ] Interfaces defined
- [ ] Integration points identified
- [ ] Risks assessed
- [ ] Validation scenario with test plan
- [ ] Prerequisites verified
- [ ] Human approved

## Anti-Patterns (Lessons from v0.8-v0.19)

### Don't Assume, Verify

| Assumption | Reality | Release |
|------------|---------|---------|
| `gh release list --json` exists | It doesn't | v0.18 |
| Service active = installed | Race condition | v0.19 |
| Optimization improves timing | Broke networking | v0.19 |
| Uncommitted changes are mistakes | May be intentional | v0.17 |

### Don't Jump to Implementation

**Bad:** "I'll figure out testing later" - this leads to untested code being merged. Identify the test scenario upfront.

**Good:** Test plan documented before first line of code.

### Don't Over-Engineer

**Bad:** Issue asks for a flag, you add a configuration framework.

**Good:** Solve exactly what's asked, no more.

## Examples

### Good Planning (v0.17 site-config integration)

- Clear approach documented before implementation
- Test scenario identified (pve-setup with site-config)
- Prerequisites verified (site-config structure)
- Result: Merged without issues

### Poor Planning (v0.19 packer optimization)

- No baseline measurement documented
- No test plan for "optimization" claim
- No validation scenario identified
- Result: Broke networking, required revert

### Missing Planning (v0.18 `packer --copy`)

- Assumed external tool behavior (`gh release list --json`)
- No prerequisite check (SHA256SUMS existence)
- No end-to-end test before release
- Result: 4 hotfixes during release
