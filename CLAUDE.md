# homestak-dev

This file provides guidance to Claude Code when working with this project.

## Vision

**homestak** makes setting up and running a homelab repeatable and manageable. The infrastructure-as-code in this repository is a means to an end: creating a platform for "best in class" self-hosted applications like Home Assistant, Jellyfin, Vaultwarden, and other highly desirable home apps.

### Open Source + Commercial Model

| Organization | Purpose |
|--------------|---------|
| **homestak-dev** | Open-source IaC components (this repo) |
| **homestak-com** | Commercial offering: verified releases, remote monitoring/management, cloud backup, high availability, community and live support |

The open-source foundation enables the commercial layer, not the other way around.

## Technical Foundation

### Debian-Rooted, Proxmox-Current

The platform is rooted in **Debian**, with **Proxmox VE** as the current virtualization solution. Proxmox is at the heart of current workflows, but the architecture should leave the door open for:

- QEMU/KVM without Proxmox (bare Debian hosts)
- Alternative virtualization platforms built on Debian

Design decisions should favor Debian primitives over Proxmox-specific features when practical.

### Full Homelab Stack (Roadmap)

Current focus is VM provisioning and PVE host configuration. Future scope includes:

- Kubernetes (k3s, kubeadm)
- Storage (ZFS, Ceph)
- Advanced networking (VLANs, SDN, firewalls)
- Application deployment (the actual goal)

## Repository Structure

This is a polyrepo workspace managed with [gita](https://github.com/nosarthur/gita).

```
homestak-dev/              # This repo (workspace parent)
├── .claude/               # Claude Code configuration and skills
├── .github/               # GitHub org config (PR templates, CI)
├── scripts/               # Release automation CLI
│   ├── release.sh         # Main CLI entry point
│   └── lib/               # Modular library functions
├── ansible/               # Playbooks for host configuration
├── bootstrap/             # Entry point - curl|bash installer, homestak CLI
├── iac-driver/            # Orchestration engine - scenario-based workflows
├── packer/                # Custom Debian cloud images (optional)
├── site-config/           # Site-specific secrets and configuration
└── tofu/                  # OpenTofu modules for VM provisioning
```

Each component has its own `CLAUDE.md` with detailed context (auto-loaded via imports):

@.claude/CLAUDE.md
@.github/CLAUDE.md
@ansible/CLAUDE.md
@bootstrap/CLAUDE.md
@iac-driver/CLAUDE.md
@packer/CLAUDE.md
@site-config/CLAUDE.md
@tofu/CLAUDE.md

## Workspace Management

This workspace uses **gita** to manage multiple repos.

### Common Commands

| Command | Description |
|---------|-------------|
| `gita ll` | Status of all repos |
| `gita fetch` | Fetch all repos |
| `gita pull` | Pull all repos |
| `gita shell <cmd>` | Run shell command in all repos |
| `gita super <repo> <git-cmd>` | Run git command in specific repo |

### Cross-Repo Operations

Use `gita shell` to run commands across all repos:

```bash
gita shell make lint          # Run make lint in all repos
gita shell make test          # Run make test in all repos
gita shell make install-deps  # Install deps in all repos
```

## Claude Code Skills

| Skill | Description |
|-------|-------------|
| `/issues` | Gather GitHub issues across all repos |

## Value Propositions

1. **Integrated workflow** - Unified tooling across packer->tofu->ansible with orchestration
2. **Proxmox-optimized** - Purpose-built for Proxmox VE homelabs (with Debian escape hatch)
3. **Opinionated defaults** - Sensible choices for homelab (SDN, cloud-init, security profiles)
4. **Testable infrastructure** - Nested PVE integration testing validates the full stack

## Configuration Flow (v0.13+)

site-config is the single source of truth:

```
site-config/
├── site.yaml       # Site-wide defaults (timezone, packages)
├── postures/       # Security postures (dev, prod, local)
├── envs/           # Deployment topologies with posture FK
└── secrets.yaml    # API tokens, SSH keys, passwords
        │
        ▼
ConfigResolver (iac-driver)
        │
        ├── resolve_env()          → tfvars.json  → tofu
        └── resolve_ansible_vars() → ansible-vars → ansible
```

This eliminates configuration drift between components - all settings flow from site-config.

## Design Principles

- **Do it right** - Prefer proper solutions over quick workarounds. If a task is worth doing, invest in the reusable, maintainable approach rather than one-off hacks. Today's shortcut becomes tomorrow's technical debt.
- **Repeatability over flexibility** - Prefer conventions that "just work" over infinite configurability
- **Local-first execution** - Run on the host being configured to avoid SSH connection issues
- **Idempotent operations** - Safe to run multiple times
- **Secrets in code, encrypted** - SOPS + age in site-config repo, git hooks for auto-encrypt/decrypt
- **Component independence** - Each repo installs its own dependencies via `make install-deps`
- **Process consistency** - When presenting options to the user, flag any option that deviates from established processes (lifecycle docs, RELEASE.md). Do not present process-inconsistent options as equal alternatives without noting the inconsistency.

## Terminology

Consistent terminology across all repos:

| Use | Don't Use | Rationale |
|-----|-----------|-----------|
| integration test | E2E test, end-to-end test | Our tests validate component integration, not user journeys |
| scenario | workflow, pipeline | Scenarios are iac-driver's unit of orchestration |
| action | task, step | Actions are reusable primitives in iac-driver |
| site-config | config, secrets | Specific repo name; "config" is ambiguous |
| tofu | terraform | We use OpenTofu, not Terraform |

## Conventions

- **VM IDs**: 5-digit (10000+ dev, 20000+ k8s, 99900+ integration test)
- **Networks**: dev 10.10.10.0/24, k8s 10.10.20.0/24, management 10.0.12.0/24
- **Hostnames**: `{cluster}{instance}` (dev1, kubeadm1, router)
- **Environments**: dev (permissive) vs prod (hardened)

## Host Capabilities

Not all hosts have the same capabilities. Key distinctions:

| Host | QEMU/KVM | PVE API | Notes |
|------|----------|---------|-------|
| father | Yes | Yes | Primary build host for packer images |
| mother | Yes | Yes | Secondary PVE host |
| dev machines | Maybe | No | May lack nested virtualization |

**Packer builds require QEMU/KVM.** Use `packer-build-fetch` scenario to build on capable hosts:
```bash
./run.sh --scenario packer-build-fetch --remote father
```

## Bootstrap Pattern

The `bootstrap` repo provides capability installation via `homestak install <module>`:

```bash
# Initial setup (on any Debian host)
curl -fsSL https://raw.githubusercontent.com/homestak-dev/bootstrap/main/install.sh | bash

# Add capabilities as needed
homestak install packer    # QEMU, packer, templates
homestak install tofu      # OpenTofu
homestak install ansible   # Ansible + collections
```

This pattern enables any Debian host to become a build/deploy host without manual setup.

## Release Automation CLI (v0.14+)

The `scripts/release.sh` CLI automates multi-repo release operations.

### Commands

| Command | Description |
|---------|-------------|
| `init --version X.Y` | Initialize release state |
| `status` | Show release progress |
| `preflight` | Check repos ready (clean, no tags, CHANGELOGs) |
| `validate` | Run iac-driver integration tests |
| `tag --dry-run` | Preview tag creation |
| `tag --execute` | Create and push tags |
| `tag --reset` | Reset tags to HEAD (v0.x only) |
| `publish --dry-run` | Preview release creation |
| `publish --execute` | Create GitHub releases |
| `packer --check` | Check for template changes |
| `packer --copy` | Copy images from previous release |
| `full --dry-run` | Preview complete release workflow |
| `full --execute` | Execute end-to-end release |
| `verify` | Verify all releases exist (tags + releases + packer assets) |
| `audit` | Show timestamped action log |

### Release Workflow

```bash
# Manual workflow
./scripts/release.sh init --version 0.18
./scripts/release.sh preflight
./scripts/release.sh validate --scenario vm-roundtrip --host father
./scripts/release.sh tag --dry-run
./scripts/release.sh tag --execute
./scripts/release.sh publish --execute
./scripts/release.sh packer --copy --execute
./scripts/release.sh verify

# Or use full command for end-to-end automation
./scripts/release.sh full --dry-run
./scripts/release.sh full --execute --host father
```

### Release Issue Tracking

**Important:** When executing a release, always identify the release tracking issue at session start. Use `gh issue list --label release` or check for open issues titled "vX.Y Release Planning". Include `--issue N` when running `release.sh init` to link the release state to the tracking issue.

### State Files

| File | Purpose |
|------|---------|
| `.release-state.json` | Release progress tracking (gitignored) |
| `.release-audit.log` | Timestamped action log (gitignored) |

### Safety Features

- **Dry-run mode**: Preview commands before execution
- **Validation gates**: Require integration tests before tagging
- **Rollback**: Automatic cleanup on tag creation failure
- **Dependency order**: Tags/releases created in correct order

## Documentation Index

### AI Context (CLAUDE.md)

| File | Focus |
|------|-------|
| [CLAUDE.md](CLAUDE.md) | This file - vision, architecture, conventions |
| [.claude/CLAUDE.md](.claude/CLAUDE.md) | Skills configuration |
| [.github/CLAUDE.md](.github/CLAUDE.md) | GitHub platform config (CI/CD, branch protection) |
| [ansible/CLAUDE.md](ansible/CLAUDE.md) | Playbooks, roles, collections |
| [bootstrap/CLAUDE.md](bootstrap/CLAUDE.md) | CLI, installation |
| [iac-driver/CLAUDE.md](iac-driver/CLAUDE.md) | Scenarios, actions, testing |
| [packer/CLAUDE.md](packer/CLAUDE.md) | Templates, build workflow |
| [site-config/CLAUDE.md](site-config/CLAUDE.md) | Config schema, secrets |
| [tofu/CLAUDE.md](tofu/CLAUDE.md) | Modules, environments |

### Development Lifecycle

6-phase development process in [docs/lifecycle/](docs/lifecycle/):

| File | Purpose |
|------|---------|
| [00-overview.md](docs/lifecycle/00-overview.md) | Work types, phase matrix, multi-repo structure |
| [10-planning.md](docs/lifecycle/10-planning.md) | Sprint scoping and backlog formation |
| [20-design.md](docs/lifecycle/20-design.md) | Pre-implementation design and validation planning |
| [30-implementation.md](docs/lifecycle/30-implementation.md) | Development, testing, CHANGELOG updates |
| [40-validation.md](docs/lifecycle/40-validation.md) | Integration testing requirements |
| [50-merge.md](docs/lifecycle/50-merge.md) | PR process and documentation updates |
| [60-release.md](docs/lifecycle/60-release.md) | Release coordination, tagging, retrospectives |
| [65-lessons-learned.md](docs/lifecycle/65-lessons-learned.md) | Accumulated release insights (v0.8-v0.19) |

### Templates

Reusable templates in [docs/templates/](docs/templates/):

| File | Purpose |
|------|---------|
| [aar.md](docs/templates/aar.md) | After Action Report template |
| [retrospective.md](docs/templates/retrospective.md) | Sprint retrospective template |
| [release-issue.md](docs/templates/release-issue.md) | Release planning issue template |
| [design-summary.md](docs/templates/design-summary.md) | Design documentation templates |

### Other Documentation

| File | Purpose |
|------|---------|
| [docs/ISSUE-GUIDELINES.md](docs/ISSUE-GUIDELINES.md) | Issue creation and labeling standards |
| [docs/CLAUDE-GUIDELINES.md](docs/CLAUDE-GUIDELINES.md) | CLAUDE.md documentation standards |
| [docs/REPO-SETTINGS.md](docs/REPO-SETTINGS.md) | Repository configuration standards |

## Release Process

See [docs/lifecycle/60-release.md](docs/lifecycle/60-release.md) for the release methodology, including:
- Repository dependency order
- 10-phase release workflow
- After action reports and retrospectives

**Automated releases (v0.14+):** Use `scripts/release.sh` CLI - see [Release Automation CLI](#release-automation-cli-v014) section above.

## Issue Management

When creating GitHub issues, follow [docs/ISSUE-GUIDELINES.md](docs/ISSUE-GUIDELINES.md):

- **Title format:** `<Verb> <what>` (e.g., "Add --dry-run flag", "Fix timeout error")
- **Work type label:** Apply exactly one of `bug`, `enhancement`, or `epic`
- **Modifier labels:** Add `documentation`, `refactor`, `testing`, `security`, `breaking-change` as applicable
- **Description:** Include context (why), acceptance criteria (what done looks like), and constraints

For label definitions and examples, see the full guide.

## License

Apache 2.0
