# Phase: Design

Design establishes the technical approach before implementation. The depth of design scales with work type.

## When to Design

Not every issue needs full design. Use this guide:

| Issue Type | Design Needed |
|------------|---------------|
| New feature | Yes - full design |
| Enhancement to existing feature | Yes - abbreviated |
| Bug fix with clear root cause | No - just fix it |
| Documentation update | No |
| Refactoring | Yes - identify test coverage first |
| Performance optimization | Yes - establish baseline first |

**Rule of thumb:** If you're unsure how to approach it, design it.

## Applicability

| Work Type | Design Depth |
|-----------|--------------
| Bug Fix | **Skip** - proceed directly to Implementation |
| Minor Enhancement | **Lightweight** - brief approach summary |
| Feature | **Full** - complete design artifacts |

## Inputs

- Approved sprint backlog item
- Existing codebase and architecture
- Related documentation

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

### Design Considerations

| Consideration | Questions to Ask |
|---------------|------------------|
| **Scope** | Am I solving exactly what's asked, or scope-creeping? |
| **Patterns** | Does similar functionality exist? Should I follow that pattern? |
| **Dependencies** | What must exist before this can work? |
| **Backwards compatibility** | Does this break existing behavior? |
| **Error handling** | What happens when things go wrong? |
| **Configuration** | Does this need to be configurable, or should it just work? |

## Validation Scenario Identification

Before writing code, know how you'll prove it works.

| Change Type | Validation Approach |
|-------------|---------------------|
| Packer template | Build image → `vm-roundtrip` or `nested-pve-roundtrip` |
| Tofu module | `vm-roundtrip` on target environment |
| iac-driver action | Scenario that exercises the action |
| Ansible role | Run playbook on test VM, verify behavior |
| CLI command | Full command flow, including edge cases |
| Boot/startup change | Measure actual timing before AND after |
| release.sh command | `release.sh selftest` + manual verification |

### Document Your Test Plan

```markdown
## Test Plan

**Scenario:** vm-roundtrip on father

**Steps:**
1. Build image with changes: `./build.sh debian-13-custom`
2. Publish to PVE: `./publish.sh`
3. Run validation: `./run.sh --scenario vm-roundtrip --host father`

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
