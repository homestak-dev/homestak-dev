# Doc Verification Issue Template

Create one per sprint to verify documentation reflects the sprint's final state.

**Title format:** `Verify docs for {Sprint Theme}`

**Labels:** `documentation`

**Repo:** homestak-dev/meta (cross-repo verification)

---

## Concepts Changed

<!-- List the names, fields, patterns, or behaviors that changed in this sprint -->

| Old | New | Scope |
|-----|-----|-------|
| {old_name} | {new_name} | {which repos/files} |

## Verification Checklist

### 1. Cross-repo reference sweep

Grep all repos for old names. Zero hits expected outside CHANGELOGs and git history.

```bash
gita shell grep -r '{old_name}' --include='*.md' --include='*.py' --include='*.tf' --include='*.sh' --include='*.yaml' | grep -v CHANGELOG
```

- [ ] Old names produce zero hits (excluding CHANGELOGs, reports, git history)

### 2. Design docs match implementation

If the sprint had a design phase, verify scope issue design comments reflect what was actually built (not the initial proposal).

<!-- List scope issues that had design comments -->

- [ ] {repo}#{N} design comment matches final implementation
- [ ] Deviations from design are annotated

### 3. Architecture docs are current

Verify CLAUDE.md and docs/ files accurately describe how components work **right now** — not how they worked before the sprint.

<!-- List repos with changed behavior -->

- [ ] {repo}/CLAUDE.md reflects current state
- [ ] {repo}/docs/{file}.md reflects current state (if exists)

### 4. Memory files are current

Check memory files for references to changed concepts.

```bash
grep -r '{old_name}' ~/.claude/projects/*/memory/
```

- [ ] Memory files updated or no stale references

### 5. Meta design docs

If the sprint touched architecture documented in meta/docs/designs/ or meta/docs/architecture/, verify those docs reflect the new state.

- [ ] No stale references in meta design docs (or N/A)

---

## Notes

- CHANGELOGs are NOT part of this checklist — they ship with PRs per 30-implementation.md
- This issue verifies documentation **accuracy**, not completeness
- Create follow-up issues for documentation gaps discovered during verification
