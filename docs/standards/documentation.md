# Documentation Standards

Conventions for documentation across the homestak workspace.

## File Organization

### Per-repo docs/

Repos with >200 lines of CLAUDE.md content should extract implementation detail to a flat `docs/` directory:

```
{repo}/
├── CLAUDE.md          # ~150 lines: conventions, commands, agent boundaries
├── docs/
│   ├── arch.md        # How the component works and why
│   ├── cli.md         # CLI usage, flags, examples
│   └── {topic}.md     # Domain-specific detail
```

### Meta docs/

```
meta/docs/
├── process/       # How we work (numbered lifecycle phases)
├── arch/          # Cross-repo architecture decisions
│   └── archive/   # Completed/historical designs
├── standards/     # Reference material (this file, issues, cli)
└── templates/     # Issue and doc templates
```

### File Naming

- **Lowercase**, hyphenated: `arch.md`, `exec-models.md`, `getting-started.md`
- **Abbreviated** where clear: `arch` not `architecture`, `cli` not `cli-reference`, `config-res` not `config-resolution`
- **Full words** for well-known conventions: `getting-started.md`, `troubleshooting.md`

## CLAUDE.md

Each repo's CLAUDE.md should be ~150 lines covering:

1. **Ecosystem context** — pointer to meta for project-wide conventions
2. **Agent boundaries** — what this agent should/shouldn't do
3. **Overview** — what the repo does (1-2 paragraphs)
4. **Quick reference** — common commands (make test, make lint)
5. **Directory structure** — key files and directories
6. **@-imports** — selective import of 1-2 key docs/ files

### @-imports

Import essential context that agents always need. Don't import everything:

```markdown
@docs/arch.md
```

## Cross-References

### Within a repo

Use relative markdown links (clickable in GitHub):

```markdown
See [arch.md](docs/arch.md) for architecture details.
```

### Cross-repo

Use `$HOMESTAK_ROOT` paths in backticks (stable, self-documenting):

```markdown
See `$HOMESTAK_ROOT/iac/iac-driver/docs/config-phase.md` for implementation.
```

Never use deep relative paths (`../../../iac/iac-driver/docs/...`) — they're fragile and unreadable.

### Design docs on scope issues

Post design comments on individual scope issues, not just the sprint issue. Someone reading an issue months later should find the design rationale there.

## Examples and Placeholders

When writing examples in documentation:
- **Hostnames**: use `srv1`, `srv2` — never real hostnames
- **Usernames**: use `user` — never real usernames (e.g., `ssh user@srv1`)
- **IPs**: use RFC 5737 TEST-NET addresses (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24)
- **VM IDs**: use 99xxx range (integration test range)

## Content Guidelines

### New documentation

- **50-150 lines** per doc — concise enough to scan, detailed enough to be useful
- **Written from code**, not invented — read the actual implementation before writing
- **Cross-referenced** to relevant source files
- **No provenance lines** ("Extracted from...") — git history tracks file origins

### Architecture docs (arch.md)

Explain *why* the code works the way it does, not just *what* it does:
- Design rationale and trade-offs
- Component relationships
- Key abstractions and patterns

### Troubleshooting docs

Distill real issues into actionable guides:
- Symptom → cause → fix format
- Reference issue numbers where the problem was discovered
- Include actual commands, not just descriptions

### Getting-started docs

Lower the barrier for new contributors (human or agent):
- Prerequisites and setup commands
- How to run tests
- Where to find things in the codebase

## CHANGELOGs

- Ship with PRs, not deferred to release time
- Use correct verb: Add, Fix, Change, Remove
- Reference issue number
- Place under `## Unreleased`

## Doc Verification

Every sprint should include a doc verification issue using `docs/templates/doc-verification.md`. This verifies documentation accuracy after implementation — not completeness.
