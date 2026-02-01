# Phase: Documentation

Documentation captures knowledge for future reference. The depth scales with work tier.

## When to Update Documentation

| Tier | CLAUDE.md | README | Inline Comments |
|------|-----------|--------|-----------------|
| Simple | No | No | Only if logic unclear |
| Standard | If behavior changed | If usage changed | Moderate |
| Complex | Required | If applicable | Thorough |
| Exploratory | Required | Required | Thorough + ADR |

## Documentation Types

### CLAUDE.md

AI-focused documentation for Claude Code context.

**Update when:**
- Architecture changes
- New CLI options added
- New scenarios or actions
- Configuration schema changes
- New patterns introduced

**Structure:**
- Quick reference commands
- Project structure
- Key concepts
- Common workflows
- Known issues

### README

User-focused documentation.

**Update when:**
- Installation process changes
- Usage examples need updates
- Features added or removed
- Prerequisites change

### Inline Comments

Code-level documentation.

**Guidelines:**
- Explain "why", not "what"
- Document non-obvious logic
- Note assumptions and constraints
- Reference related code

## Tier-Specific Requirements

### Simple Tier

No documentation expected unless:
- Fix involves non-obvious logic
- Code behavior is confusing without explanation

### Standard Tier

Update documentation if:
- Behavior changes (even slightly)
- New options or flags added
- Error messages or handling changes

Minimum: Brief update to relevant CLAUDE.md section.

### Complex Tier

Required documentation:
- CLAUDE.md section for new capability
- README if user-facing
- Inline comments for complex logic
- Updated CLI help text

### Exploratory Tier

Required documentation:
- Full CLAUDE.md section
- README with examples
- Architecture Decision Record (ADR)
- Dead-ends log (what didn't work)

## Documentation Timing

| Phase | Documentation Activity |
|-------|------------------------|
| Design | Identify doc requirements |
| Implementation | Draft inline comments |
| **Documentation** | CLAUDE.md, README updates |
| Merge | Verify docs in PR |

**Best practice:** Update documentation during implementation, not after. Context is fresh.

## CLAUDE.md Guidelines

See [CLAUDE-GUIDELINES.md](../CLAUDE-GUIDELINES.md) for detailed standards.

Key points:
- Keep AI-focused (commands, structure, workflows)
- Use consistent formatting
- Include examples
- Reference related docs

## Knowledge Preservation

### Session-to-Session

Document decisions in sprint issues:
- Why approach was chosen
- What alternatives were considered
- What constraints influenced decision

### Sprint-to-Sprint

Document patterns in CLAUDE.md:
- Reusable solutions
- Common workflows
- Known pitfalls

### Release-to-Release

Document lessons in 75-lessons-learned.md:
- Process improvements
- Anti-patterns discovered
- Best practices confirmed

## Outputs

- CLAUDE.md updated (if required by tier)
- README updated (if applicable)
- Inline comments added
- Help text updated

## Checklist: Documentation Complete

### Standard Tier
- [ ] CLAUDE.md checked for needed updates
- [ ] Inline comments for non-obvious logic

### Complex Tier
- [ ] CLAUDE.md section added/updated
- [ ] README updated (if user-facing)
- [ ] CLI help text accurate
- [ ] Inline comments complete

### Exploratory Tier
- [ ] Full CLAUDE.md section
- [ ] README with examples
- [ ] ADR documented
- [ ] Dead-ends logged

## Related Documents

- [00-overview.md](00-overview.md) - Tier definitions
- [30-implementation.md](30-implementation.md) - Code documentation
- [../CLAUDE-GUIDELINES.md](../CLAUDE-GUIDELINES.md) - CLAUDE.md standards
