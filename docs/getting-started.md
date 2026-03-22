# Getting Started

Set up a development workstation for working on homestak.

## Prerequisites

Install these tools before cloning the workspace:

| Tool | Purpose | Install |
|------|---------|---------|
| git | Version control | `apt install git` |
| gita | Polyrepo workspace management | `pip install gita` |
| gh | GitHub CLI (PRs, issues, releases) | [cli.github.com](https://cli.github.com/) |
| make | Build automation (each repo has a Makefile) | `apt install make` |

Authenticate the GitHub CLI:

```bash
gh auth login
```

## Clone the Workspace

All path resolution is anchored by `$HOMESTAK_ROOT`, which defaults to `$HOME`. On installed hosts, `$HOME` *is* the workspace root (`/home/homestak/`), so repos live at `~/bootstrap/`, `~/config/`, `~/iac/` directly. On dev workstations, the workspace is nested under the operator's home — by convention `~/homestak/`:

```bash
export HOMESTAK_ROOT=~/homestak
```

Clone all repos using gita:

```bash
export HOMESTAK_ROOT=~/homestak
mkdir -p $HOMESTAK_ROOT
cd $HOMESTAK_ROOT

# Clone repos into the workspace layout
# homestak org (top-level)
git clone https://github.com/homestak/bootstrap.git
git clone https://github.com/homestak/config.git
git clone https://github.com/homestak/bare-metal.git

# homestak-iac org (under iac/)
mkdir -p iac
git clone https://github.com/homestak-iac/iac-driver.git iac/iac-driver
git clone https://github.com/homestak-iac/tofu.git iac/tofu
git clone https://github.com/homestak-iac/ansible.git iac/ansible
git clone https://github.com/homestak-iac/packer.git iac/packer

# homestak-dev org (under dev/)
mkdir -p dev
git clone https://github.com/homestak-dev/meta.git dev/meta
git clone https://github.com/homestak-dev/.claude.git dev/.claude
git clone https://github.com/homestak-dev/.github.git dev/.github
```

Register all repos with gita so workspace-wide commands work:

```bash
gita add $HOMESTAK_ROOT/bootstrap ~/homestak/config ~/homestak/bare-metal
gita add $HOMESTAK_ROOT/iac/iac-driver ~/homestak/iac/tofu
gita add $HOMESTAK_ROOT/iac/ansible ~/homestak/iac/packer
gita add $HOMESTAK_ROOT/dev/meta ~/homestak/dev/.claude ~/homestak/dev/.github
```

## Understand the Layout

```
$HOMESTAK_ROOT/
├── bare-metal/          # Debian preseed ISO remastering
├── bootstrap/           # curl|bash installer, homestak CLI
├── config/              # Secrets, manifests, site-specific config
├── iac/
│   ├── ansible/         # Playbooks for host configuration
│   ├── iac-driver/      # Orchestration engine (Python)
│   ├── packer/          # Custom Debian cloud images
│   └── tofu/            # OpenTofu modules for VM provisioning
├── dev/
│   ├── meta/            # Release scripts, lifecycle docs, process
│   ├── .claude/         # Claude Code skills and settings
│   └── .github/         # GitHub org config, CI/CD
└── apps/                # Application deployment (future)
```

Each subdirectory is an independent git repo with its own CLAUDE.md, Makefile,
CHANGELOG.md, and CI workflow.

## First Commands

Check the status of all repos:

```bash
gita ll
```

Fetch latest changes across the workspace:

```bash
gita fetch
```

Pull all repos to latest master:

```bash
gita pull
```

## Install Dependencies and Run Tests

Each repo manages its own dependencies. Install all, then test:

```bash
gita shell make install-deps    # install deps in all repos
gita shell make test            # run tests in all repos
gita shell make lint            # run linting in all repos
```

For iac-driver specifically, set up the Python virtual environment first:

```bash
cd $HOMESTAK_ROOT/iac/iac-driver
make install-dev    # creates .venv, installs deps
```

## Set Up a Dev Host

To test infrastructure operations, you need a Debian host with Proxmox VE.
See [uat.md](process/uat.md) for the full setup and validation checklist:

1. Bootstrap a fresh Debian 13 host with `curl|bash`
2. Configure `site.yaml` (gateway, DNS servers)
3. Run `homestak site-init` and `homestak pve-setup`
4. Download packer images with `homestak images download all --publish`
5. Run the integration test suite (`manifest test`)

## Next Steps

- Read each repo's CLAUDE.md for component-specific context
- Review [docs/process/00-overview.md](process/00-overview.md) for the
  development lifecycle
- See [docs/roadmap.md](roadmap.md) for strategic direction
- Use `/sprint`, `/release`, and `/session` skills for workflow automation
