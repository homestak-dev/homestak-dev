# homestak-dev

Polyrepo workspace for homestak infrastructure-as-code.

For end-user documentation, see the [organization profile](https://github.com/homestak-dev).

## Quick Start (Contributors)

```bash
# Clone the parent repo
git clone https://github.com/homestak-dev/homestak-dev.git
cd homestak-dev

# Full workspace setup
make setup
```

This clones all child repos, registers them with gita, checks dependencies, and configures git hooks for secrets management.

If dependencies are missing, you'll see:
```
Checking dependencies...
  gita:       OK
  packer:     MISSING
  shellcheck: MISSING
  ...

Missing dependencies: packer shellcheck
Run: sudo make install-deps-all
```

Install missing dependencies and verify:
```bash
sudo make install-deps-all
gita ll
```

## Project Structure

```
homestak-dev/              # This repo (workspace parent)
├── .claude/               # Claude Code configuration and skills
├── .github/               # GitHub org config (PR templates, CI)
├── ansible/               # Playbooks for host configuration
├── bootstrap/             # Entry point - curl|bash installer
├── iac-driver/            # Orchestration engine
├── packer/                # Image templates
├── site-config/           # Secrets and configuration
└── tofu/                  # VM provisioning modules
```

## Workspace Management

This workspace uses [gita](https://github.com/nosarthur/gita) to manage multiple repos.

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make setup` | Full workspace setup (clone, register, check deps, configure hooks) |
| `make check-deps` | Check if all dependencies are installed |
| `make install-deps-all` | Install dependencies across all repos (requires sudo) |

### Gita Commands

| Command | Description |
|---------|-------------|
| `gita ll` | Status of all repos |
| `gita fetch` | Fetch all repos |
| `gita pull` | Pull all repos |
| `gita shell <cmd>` | Run command in all repos |

## Documentation

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Architecture, conventions, development guide |
| [RELEASE.md](RELEASE.md) | Release methodology |
| [REPO-SETTINGS.md](REPO-SETTINGS.md) | Repository configuration standards |
| [CLAUDE-GUIDELINES.md](CLAUDE-GUIDELINES.md) | Documentation standards |

## Claude Code Skills

| Skill | Description |
|-------|-------------|
| `/issues` | Gather GitHub issues across all repos |

## License

Apache 2.0
