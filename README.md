# homestak-dev

Polyrepo workspace for homestak infrastructure-as-code.

For end-user documentation, see the [organization profile](https://github.com/homestak-dev).

## Quick Start (Contributors)

```bash
# Clone the parent repo
git clone https://github.com/homestak-dev/homestak-dev.git
cd homestak-dev

# Install gita (polyrepo manager)
pipx install gita

# Clone all child repos
for repo in .github .claude ansible bootstrap iac-driver packer site-config tofu; do
  git clone https://github.com/homestak-dev/$repo.git
done

# Register repos with gita
gita add .github .claude ansible bootstrap iac-driver packer site-config tofu

# Verify setup
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

### Common Commands

| Command | Description |
|---------|-------------|
| `gita ll` | Status of all repos |
| `gita fetch` | Fetch all repos |
| `gita pull` | Pull all repos |
| `gita shell <cmd>` | Run command in all repos |

### Custom Commands

Configure in `~/.config/gita/cmds.json`:

```json
{
  "lint": {"cmd": "make lint", "shell": true, "allow_all": true},
  "test": {"cmd": "make test", "shell": true, "allow_all": true},
  "build": {"cmd": "make build", "shell": true, "allow_all": true}
}
```

Then use:
```bash
gita lint   # Run make lint in all repos
gita test   # Run make test in all repos
```

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
