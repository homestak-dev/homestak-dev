# Design Summary Template

Use this template for full design documentation on features. For minor enhancements, use the abbreviated version at the bottom.

---

## Design Summary: [Feature Name]

**Issue:** #N
**Author:** [name]
**Date:** YYYY-MM-DD

### Problem Statement

What need does this feature address? What are the success criteria?

### Proposed Solution

**Summary:** One sentence describing the solution.

**High-level approach:**
- Key concept 1
- Key concept 2

**Key components affected:**
- `path/to/file.py` - Add X functionality
- `path/to/other.py` - Update Y to support X

**New components introduced:**
- `path/to/new.py` - Purpose

### Interface Design

**Public APIs or contracts:**
```python
# Example interface
def new_function(param: str) -> Result:
    """Description of what it does."""
    pass
```

**Data structures:**
```python
# Example data structure
@dataclass
class NewConfig:
    field1: str
    field2: int
```

**Configuration changes:**
- New setting in `site-config/site.yaml`
- New CLI flag `--flag-name`

### Integration Points

- How this interacts with existing functionality
- Cross-repo implications
- Dependencies on other components

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Risk 1 | Low/Med/High | Low/Med/High | How to mitigate |
| Risk 2 | Low/Med/High | Low/Med/High | How to mitigate |

### Alternatives Considered

| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| Approach A | + Pro | - Con | Reason |
| Approach B | + Pro | - Con | Reason |

### Test Plan

**Scenario:** [e.g., `./run.sh test -M n1-push -H srv1`]

**Steps:**
1. Step 1
2. Step 2
3. Step 3

**Expected result:** What success looks like

**Performance baseline (if applicable):**
- Current: X seconds
- Target: Y seconds or better

### Open Questions

- Question that needs answering during implementation
- Another open question

---

## Abbreviated Design (Minor Enhancements)

For minor enhancements, use this shorter format as a comment on the issue:

```markdown
## Plan

**Approach:** Brief description of what will be done.

**Files:**
- `path/to/file.py` - Change description
- `path/to/other.py` - Change description

**Validation:** How to prove it works.

**Prerequisites:** What must exist beforehand (or "None").

**Risks:** What could go wrong (or "Low risk - straightforward change").
```
