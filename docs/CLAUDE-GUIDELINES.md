# CLAUDE.md Best Practices

Guidelines for maintaining CLAUDE.md files across homestak-dev repositories.

## Purpose

CLAUDE.md serves two audiences:

1. **AI assistants** - Provides context for effective collaboration on the codebase
2. **Developers** - Quick architectural orientation without reading all source code

A well-maintained CLAUDE.md accelerates onboarding for both humans and AI.

## When to Update

### Update triggers (do update)

- New features that change architecture or workflows
- Refactoring that changes file structure or component relationships
- New conventions or patterns introduced
- After onboarding reveals documentation gaps
- Changes to key commands (build, test, run)

### Non-triggers (don't update)

- Typo fixes or minor bug fixes
- Dependency version bumps
- Code changes that don't affect architecture
- Internal refactoring that preserves external interfaces

**Rule of thumb:** If someone reading only CLAUDE.md would be confused or misled by your change, update CLAUDE.md.

## Content Guidelines

### Must Include

| Section | Purpose |
|---------|---------|
| Project Overview | 1-2 sentences explaining what this repo does |
| Quick Reference | Key commands (build, test, run, deploy) |
| Project Structure | Tree diagram of important directories |
| Architecture | How components interact, data flow |

### Should Include

| Section | When Useful |
|---------|-------------|
| Conventions | Naming patterns, code style, ID schemes |
| Workflows | Common multi-step operations |
| Related Projects | Links to sibling repos in multi-repo setup |
| Gotchas | Known issues, non-obvious behaviors |

### Avoid

| Anti-pattern | Why |
|--------------|-----|
| Duplicating README verbatim | README is for users, CLAUDE.md is for contributors |
| Step-by-step tutorials | Link to docs instead |
| Changelog-style history | That's what CHANGELOG.md is for |
| Obvious statements | "src/ contains source code" adds no value |
| Hardcoded versions | Use "current" or omit; versions go stale |
| Excessive detail | Enough to orient, not to replace reading code |

## Section Headers (Standardized)

Use these headers in this order for consistency across repos:

```markdown
# {repo-name}

Brief description of what this repo does.

## Quick Reference
## Overview (or Project Overview)
## Project Structure
## Architecture
## Conventions
## Workflows
## Testing
## Related Projects (or See Also)
```

Not all sections are required - include what's relevant to the repo.

**Note:** Start with `# {repo-name}`, not `# CLAUDE.md` - the filename is already CLAUDE.md.

## Examples

### Good: Concise architecture summary

```markdown
## Architecture

### Config Resolution Flow

site-config/          iac-driver/           tofu/
┌─────────────┐       ┌──────────────┐      ┌─────────────┐
│ vms/*.yaml  │──────▶│ConfigResolver│─────▶│ envs/generic│
└─────────────┘       └──────────────┘      └─────────────┘

ConfigResolver merges YAML layers and outputs tfvars.json for tofu.
```

*Why it works:* Visual diagram + one-sentence explanation. Reader understands the flow without reading code.

### Good: Actionable quick reference

```markdown
## Quick Reference

# Deploy via iac-driver (recommended)
./run.sh --scenario vm-roundtrip --host father

# Direct commands (debugging only)
tofu plan -var-file=/tmp/tfvars.json

# Run integration tests
./run.sh --scenario nested-pve-roundtrip --host father
```

*Why it works:* Shows the recommended path first, alternatives second. Comments explain when to use each.

### Avoid: Over-detailed file listing

```markdown
## Project Structure

src/
├── cli.py           # Command line interface entry point
├── common.py        # Common utilities and ActionResult class
├── config.py        # Configuration loading
├── config_resolver.py  # Resolves site-config for tofu
├── actions/
│   ├── __init__.py  # Action exports
│   ├── tofu.py      # Tofu actions
│   ├── ansible.py   # Ansible actions
│   ├── ssh.py       # SSH actions
│   └── ...
```

*Why to avoid:* File-by-file commentary doesn't help orientation. Better:

```markdown
## Project Structure

src/
├── cli.py              # CLI entry point
├── config_resolver.py  # Merges site-config → tfvars.json
├── actions/            # Reusable operations (tofu, ansible, ssh)
└── scenarios/          # Workflow definitions
```

### Avoid: Stale version references

```markdown
## Dependencies

- Python 3.11+
- OpenTofu 1.6.2
- Ansible 2.15.0
```

*Why to avoid:* Version numbers go stale. Better:

```markdown
## Dependencies

- Python 3.11+
- OpenTofu (current stable)
- Ansible (installed via make install-deps)
```

## PR Checklist

When reviewing or submitting PRs, consider:

- [ ] Does this change affect CLAUDE.md content?
- [ ] Are new components/patterns documented?
- [ ] Are removed features cleaned up from CLAUDE.md?
- [ ] Does CLAUDE.md still accurately describe the repo?

## Maintenance

CLAUDE.md accuracy is verified during each release (see RELEASE.md Phase 1: Pre-flight). This ensures documentation doesn't drift too far from reality.

For questions about these guidelines, see .github#5.
