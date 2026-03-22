# homestak meta

Release scripts, documentation, and development process for the homestak project.

For end-user documentation, see the [organization profile](https://github.com/homestak-dev).

## Quick Start (Contributors)

```bash
# Create workspace root and clone meta
mkdir -p ~/homestak/dev
git clone https://github.com/homestak-dev/meta.git ~/homestak/dev/meta
cd ~/homestak/dev/meta

# Full workspace setup (clones all repos into ~/homestak/)
make setup
```

This clones all repos into the correct directory structure, registers them with gita, checks dependencies, and configures git hooks for secrets management.

## Workspace Structure

```
~/homestak/
├── bootstrap/             # homestak/bootstrap - installer, CLI
├── config/                # homestak/config - secrets, manifests
├── iac/
│   ├── ansible/           # homestak-iac/ansible - playbooks
│   ├── iac-driver/        # homestak-iac/iac-driver - orchestration
│   ├── packer/            # homestak-iac/packer - image templates
│   └── tofu/              # homestak-iac/tofu - VM provisioning
└── dev/
    ├── meta/              # homestak-dev/meta - this repo
    ├── .claude/           # homestak-dev/.claude - Claude Code config
    └── .github/           # homestak-dev/.github - org config
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make setup` | Full workspace setup (clone, register, check deps, configure hooks) |
| `make check-deps` | Check if all dependencies are installed |
| `make install-deps-all` | Install dependencies across all repos (requires sudo) |
| `make test` | Run release CLI bats tests |
| `make lint` | Run shellcheck on release CLI |

## Documentation

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Architecture, conventions, development guide |
| [docs/process/](docs/process/) | 7-phase development lifecycle |
| [docs/standards/repo-settings.md](docs/standards/repo-settings.md) | Repository configuration standards |
| [docs/standards/claude-guidelines.md](docs/standards/claude-guidelines.md) | Documentation standards |
| [docs/standards/issues.md](docs/standards/issues.md) | Issue creation and labeling standards |

## Claude Code Skills

| Skill | Subcommands | Description |
|-------|-------------|-------------|
| `/sprint` | plan, init, validate, sync, merge, close | Sprint lifecycle management |
| `/release` | plan init, plan update, execute | Release lifecycle with gates |
| `/session` | save, resume, checkpoint | Context preservation across compactions |
| `/issues` | - | Gather GitHub issues across all repos |

See [.claude/CLAUDE.md](../.claude/CLAUDE.md) for complete skill documentation.

## License

Apache 2.0
