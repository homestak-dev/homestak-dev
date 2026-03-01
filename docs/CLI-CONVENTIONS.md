# CLI Conventions

This document defines CLI conventions for all homestak scripts. Following these conventions ensures a consistent user experience across all tools.

## Standard Flags

### Universal Flags (Required for All Scripts)

| Flag | Short | Description |
|------|-------|-------------|
| `--help` | `-h` | Show help text and exit |

### Common Flags (Tier 1 + Tier 2 Scripts)

| Flag | Short | Description |
|------|-------|-------------|
| `--version` | | Show version and exit |
| `--verbose` | `-v` | Enable verbose/debug output |

### Operation Flags (Where Applicable)

| Flag | Short | Description |
|------|-------|-------------|
| `--dry-run` | | Preview without executing changes |
| `--yes` | `-y` | Skip confirmation prompts |
| `--force` | `-f` | Override safety checks |
| `--json` | | Machine-readable JSON output |

## Script Tiers

### Tier 1: Primary User-Facing CLIs

Scripts that end-users interact with directly.

| Script | Location |
|--------|----------|
| `homestak` | `bootstrap/homestak.sh` |
| `run.sh` | `iac-driver/run.sh` |
| `release.sh` | `scripts/release.sh` |

**Requirements:**
- All universal flags (`--help`)
- All common flags (`--version`, `--verbose`)
- `--json` where output is useful for automation

### Tier 2: Build/Publish Tools

Developer-facing tools for building and publishing artifacts.

| Script | Location |
|--------|----------|
| `build.sh` | `packer/build.sh` |
| `publish.sh` | `packer/publish.sh` |
| `checksums.sh` | `packer/checksums.sh` |

**Requirements:**
- All universal flags (`--help`)
- All common flags (`--version`)
- `--dry-run` where destructive operations occur

### Tier 3: Helper/Setup Scripts

Internal utilities and setup scripts.

| Script | Location |
|--------|----------|
| `install.sh` | `bootstrap/install.sh` |
| `host-config.sh` | `site-config/scripts/host-config.sh` |
| `node-config.sh` | `site-config/scripts/node-config.sh` |
| `setup-tools.sh` | `iac-driver/scripts/setup-tools.sh` |
| `wait-for-guest-agent.sh` | `iac-driver/scripts/wait-for-guest-agent.sh` |

**Requirements:**
- All universal flags (`--help`)
- Clear usage documentation

## Flag Naming Rules

1. **Long flags**: Use lowercase with hyphens (`--dry-run`, not `--dryRun` or `--dry_run`)
2. **Short flags**: Single character, reserved for frequent operations
3. **Boolean flags**: No value required (`--verbose`, not `--verbose=true`)
4. **Negation**: Use `--no-` prefix for disabling (`--no-color`)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Usage/argument error |
| 3 | Configuration error |
| 4+ | Operation-specific errors |

## Help Text Format

Help text should follow this structure:

```
<tool-name> - <one-line description>

Usage:
  <tool-name> <command> [options]

Commands:
  <command>           <description>
  ...

Options:
  --flag, -f          <description>
  ...

Examples:
  <tool-name> <example-command>
  ...
```

### Guidelines

1. Lead with usage pattern
2. Group related commands together
3. Show most common flags first
4. Include 2-3 practical examples
5. End with a blank line

## Output Conventions

### Human Output (Default)

- Use colors sparingly (green for success, yellow for warnings, red for errors)
- Prefix informational lines with `==>` or similar marker
- Show progress for operations >1 second
- End with clear success/failure summary

### Machine Output (`--json`)

- Output valid JSON to stdout
- Errors as JSON to stderr
- Include status field: `"status": "success"` or `"status": "error"`
- Include relevant data fields

Example:
```json
{
  "status": "success",
  "version": "0.32",
  "repos": ["bootstrap", "ansible", "iac-driver"],
  "tags_created": 9
}
```

## Version Format

Version output should be simple and parseable:

```
<tool-name> v<version>
```

Example:
```
homestak v0.32
release.sh v0.32
```

### Git-Derived Versions (Required)

All scripts must derive their version from git tags at runtime, not from hardcoded constants. This eliminates the need to update version strings during releases.

**Bash:**
```bash
get_version() {
    git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo "dev"
}
```

**Python:**
```python
def get_version():
    try:
        result = subprocess.run(
            ['git', 'describe', '--tags', '--abbrev=0'],
            capture_output=True, text=True,
            cwd=Path(__file__).parent
        )
        return result.stdout.strip() if result.returncode == 0 else 'dev'
    except Exception:
        return 'dev'
```

**Benefits:**
- Zero maintenance - version comes from tags automatically
- Works with existing release workflow (`release.sh tag` creates tags)
- Accurate - shows actual tagged version
- Graceful fallback to "dev" for untagged/non-git scenarios

## Environment Variables

When scripts support environment variable configuration:

1. Document all env vars in `--help` output
2. Use `HOMESTAK_` prefix for homestak-specific vars
3. CLI flags override environment variables
4. Example: `HOMESTAK_BRANCH`, `HOMESTAK_APPLY`

## Implementation Examples

### Bash Help Implementation

```bash
# Git-derived version (required - do not use hardcoded VERSION constant)
get_version() {
    git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || echo "dev"
}

show_help() {
    cat << EOF
tool-name $(get_version) - Brief description

Usage:
  tool-name <command> [options]

Commands:
  action        Do something
  other         Do something else

Options:
  --help, -h    Show this help message
  --version     Show version
  --verbose     Enable verbose output

Examples:
  tool-name action --verbose
EOF
}

# Parse arguments
case "${1:-}" in
    --help|-h|help)
        show_help
        exit 0
        ;;
    --version)
        echo "$(basename "$0") $(get_version)"
        exit 0
        ;;
    # ... other cases
esac
```

### Python Help Implementation (argparse)

```python
import argparse
import subprocess
from pathlib import Path

def get_version():
    """Get version from git tags (do not use hardcoded VERSION constant)."""
    try:
        result = subprocess.run(
            ['git', 'describe', '--tags', '--abbrev=0'],
            capture_output=True, text=True,
            cwd=Path(__file__).parent
        )
        return result.stdout.strip() if result.returncode == 0 else 'dev'
    except Exception:
        return 'dev'

parser = argparse.ArgumentParser(
    description='Tool description'
)
parser.add_argument(
    '--version',
    action='version',
    version=f'%(prog)s {get_version()}'
)
parser.add_argument(
    '--verbose', '-v',
    action='store_true',
    help='Enable verbose output'
)
```

## Migration Notes

When updating existing scripts:

1. Add `--help` first (universal requirement)
2. Add `--version` for Tier 1+2 scripts using `get_version()` function
3. Replace any hardcoded `VERSION="X.Y"` constants with git-derived version
4. Preserve existing flag behavior
5. Document any breaking changes in CHANGELOG

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Project overview and conventions
- [docs/lifecycle/60-release.md](lifecycle/60-release.md) - Release process
- [docs/ISSUE-GUIDELINES.md](ISSUE-GUIDELINES.md) - Issue creation standards
