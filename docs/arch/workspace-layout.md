# Design: Workspace Layout for Multi-Org Structure

**Issue:** homestak-dev#310
**Epic:** homestak-dev#309 (Multi-org migration)
**Date:** 2026-03-07

## Problem Statement

The org split moves repos to different GitHub organizations (homestak, homestak-dev, homestak-iac, homestak-apps). The local filesystem layout needs a corresponding design that:

1. Reflects the org structure without deep nesting
2. Works identically on dev workstations and installed hosts
3. Preserves cross-repo discovery (iac-driver → ansible, tofu, config)
4. Is position-independent (works at any root path)

## Layout

```
{root}/                          # ~homestak/ (installed) or ~/homestak/ (dev)
├── bare-metal/                  # homestak org
├── bootstrap/                   # homestak org (contains 'homestak' CLI)
├── config/                      # homestak org (was: site-config)
│
├── apps/                        # homestak-apps org
│   ├── pihole/
│   ├── jellyfin/
│   ├── home-assistant/
│   └── ...
│
├── iac/                         # homestak-iac org
│   ├── ansible/
│   ├── iac-driver/
│   ├── packer/
│   └── tofu/
│
├── dev/                         # homestak-dev org
│   ├── meta/                    # was: homestak-dev (release scripts, docs, CLAUDE.md)
│   ├── .claude/
│   └── .github/
│
├── .cache/                      # downloaded images, temp files
└── logs/                        # server and config logs
```

## Naming Convention

Strip the `homestak-` prefix from the org name to get the local directory name. The root org (`homestak`) maps to top-level.

| GitHub org/repo | Local path | Rule |
|-----------------|-----------|------|
| `homestak/bootstrap` | `{root}/bootstrap/` | Root org → top-level |
| `homestak/config` | `{root}/config/` | Root org → top-level |
| `homestak/bare-metal` | `{root}/bare-metal/` | Root org → top-level |
| `homestak-apps/pihole` | `{root}/apps/pihole/` | Strip prefix → subdir |
| `homestak-iac/ansible` | `{root}/iac/ansible/` | Strip prefix → subdir |
| `homestak-dev/meta` | `{root}/dev/meta/` | Strip prefix → subdir |

The mapping is mechanical — derivable from the org/repo name alone.

## Repo Renames

| Current | New | GitHub | Rationale |
|---------|-----|--------|-----------|
| `homestak-dev` (repo) | `meta` | `homestak-dev/meta` | Avoids `dev/homestak-dev` redundancy; it's the meta-repo (release scripts, docs, process) |
| `site-config` | `config` | `homestak/config` | At top-level, `site-` prefix is unnecessary; `config/` is natural for end users |

## Position Independence

The layout works at any root path (`~homestak/`, `~/homestak/`, `/opt/homestak/`). No hardcoded absolute paths in code.

| Mechanism | How | Position-independent |
|-----------|-----|---------------------|
| IaC sibling repos | `../` from current repo | Yes — siblings under `iac/` |
| Config discovery | `$HOMESTAK_ROOT/config` | Yes — anchored to workspace root |
| CLI in PATH | `$HOME/bootstrap` added to `$PATH` | Yes — relative to `$HOME` |
| gita | Registers repos by absolute path | Yes |
| CLAUDE.md imports | Relative `@` paths from importing file | Yes |

## Environment Setup

Bootstrap writes to `~/.profile`:

```bash
export HOMESTAK_ROOT="$HOME"
export PATH="$HOME/bootstrap:$PATH"
```

`HOMESTAK_ROOT` is the single anchor for all path discovery (replaced `HOMESTAK_SITE_CONFIG`, `HOMESTAK_LIB`, `HOMESTAK_ETC` in v0.54).

## Two Contexts, Same Structure

| | Dev workstation | Installed host |
|-|-----------------|----------------|
| User | Operator (e.g., `user`) | `homestak` |
| Root | `~/homestak/` | `~homestak/` (= `/home/homestak/`) |
| Has `dev/` | Yes | No |
| Has `apps/` | Yes | When apps are deployed |
| Has `bare-metal/` | Yes | No |

Dev workstations get the full layout. Installed hosts get only what they need (no `dev/`, no `bare-metal/`).

## Cross-Repo Discovery

### IaC siblings (no change needed)

`get_sibling_dir()` in iac-driver uses `../` from the current repo to find siblings. Since ansible, tofu, packer, and iac-driver are all under `iac/`, this works unchanged:

```python
def get_sibling_dir(name: str) -> Path:
    return get_base_dir().parent / name  # iac/ -> sibling
```

### Config discovery

Config lives at `$HOMESTAK_ROOT/config`. The `get_site_config_dir()` function in `config.py` resolves this directly — no sibling-walking or env var fallbacks needed.

### CLAUDE.md imports

From `dev/meta/CLAUDE.md`:

```markdown
@../../iac/ansible/CLAUDE.md
@../../iac/iac-driver/CLAUDE.md
@../../iac/tofu/CLAUDE.md
@../../iac/packer/CLAUDE.md
@../../bootstrap/CLAUDE.md
@../../config/CLAUDE.md
@../.claude/CLAUDE.md
@../.github/CLAUDE.md
```

Claude Code resolves `@` paths relative to the importing file's location. Max depth: 5 hops. Confirmed working.

## Removed Concepts

| Removed | Replacement | Rationale |
|---------|-------------|-----------|
| `bin/` directory | `$HOME/bootstrap` added to PATH | Only held one symlink |
| `HOMESTAK_LIB` env var | Repos at known paths relative to `$HOME` | `lib/` indirection gone |
| `HOMESTAK_ETC` env var | `$HOMESTAK_ROOT/config` | Single anchor via `HOMESTAK_ROOT` |
| `.sh` extension on executables | No extension on files with shebangs | Shebanged scripts drop extension; sourced libraries keep `.sh` |

## Shell Script Naming Convention

- **Executable scripts** (have a shebang `#!/usr/bin/env bash`): **no extension**. Examples: `homestak`, `release`, `build`, `publish`.
- **Sourced libraries** (loaded via `source` or `.`): **keep `.sh`**. Examples: `scripts/lib/state.sh`, `scripts/lib/publish.sh`.

This applies across all repos.

## Impact on Dependent Work

| Issue | Impact |
|-------|--------|
| #308 (release.sh multi-org) | `WORKSPACE_DIR` → per-repo path lookup using org-to-dir mapping |
| #309 (migration epic) | Repo transfers + renames (homestak-dev → meta, site-config → config) |
| bootstrap#94 (clone URLs) | `install.sh` creates `iac/`, `config/` structure; removes `HOMESTAK_LIB` |
| Lifecycle docs (~31 refs) | `cd ~/homestak-dev/$repo` → `cd ~/homestak/iac/$repo` etc. |
| CLAUDE.md imports (8 refs) | `@ansible/CLAUDE.md` → `@../../iac/ansible/CLAUDE.md` |

## Future Extensibility

| Org | Dir | When |
|-----|-----|------|
| `homestak-com` | `com/` | Commercial layer (roadmap: Run phase) |
| New app repos | `apps/<name>/` | As apps are built |
