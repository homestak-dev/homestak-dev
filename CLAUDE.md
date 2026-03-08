# homestak

This file provides guidance to Claude Code when working with this project.

## Vision

**homestak** makes setting up and running a homelab repeatable and manageable. The infrastructure-as-code in this repository is a means to an end: creating a platform for "best in class" self-hosted applications like Home Assistant, Jellyfin, Vaultwarden, and other highly desirable home apps.

### Open Source + Commercial Model

| Organization | Purpose |
|--------------|---------|
| **homestak** | Core: bootstrap installer, config |
| **homestak-iac** | IaC components: ansible, iac-driver, tofu, packer |
| **homestak-dev** | Meta: release scripts, docs, process, Claude Code config |
| **homestak-apps** | Application deployment (future) |
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
~/homestak/                    # Workspace root (HOMESTAK_ROOT)
├── bootstrap/                 # homestak/bootstrap - curl|bash installer, homestak CLI
├── config/                    # homestak/config - secrets, manifests, site-specific config
│
├── iac/                       # homestak-iac org
│   ├── ansible/               # Playbooks for host configuration
│   ├── iac-driver/            # Orchestration engine - scenario-based workflows
│   ├── packer/                # Custom Debian cloud images (optional)
│   └── tofu/                  # OpenTofu modules for VM provisioning
│
├── dev/                       # homestak-dev org
│   ├── meta/                  # This repo - release scripts, docs, process
│   │   ├── scripts/           # Release automation CLI
│   │   │   ├── release        # Main CLI entry point
│   │   │   └── lib/           # Modular library functions
│   │   └── docs/              # Lifecycle, designs, guidelines
│   ├── .claude/               # Claude Code configuration and skills (SEPARATE REPO)
│   └── .github/               # GitHub org config (SEPARATE REPO)
│
├── bare-metal/                # homestak/bare-metal - bare metal installer (future)
├── apps/                      # homestak-apps org (future)
└── com/                       # homestak-com org (future)
```

**Important:** Each subdirectory is its own git repository. `.claude/` and `.github/` under `dev/` are **separate repos** from `meta/`. When making changes across repos:
- Create sprint branches in each repo separately
- Commit and push to their own remotes
- Include them in multi-repo PRs

Each component has its own `CLAUDE.md` with detailed context (auto-loaded via imports):

@../.claude/CLAUDE.md
@../.github/CLAUDE.md
@../../iac/ansible/CLAUDE.md
@../../bootstrap/CLAUDE.md
@../../iac/iac-driver/CLAUDE.md
@../../iac/packer/CLAUDE.md
@../../config/CLAUDE.md
@../../iac/tofu/CLAUDE.md

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

### Primary Skills

| Skill | Subcommands | Description |
|-------|-------------|-------------|
| `/sprint` | plan, init, validate, sync, merge, close | Sprint lifecycle management |
| `/release` | plan init, plan update, execute, close | Release lifecycle with gates |
| `/session` | save, resume, checkpoint | Context preservation across compactions |
| `/issues` | - | Gather GitHub issues across all repos |

See [.claude/CLAUDE.md](../.claude/CLAUDE.md) for full skill documentation.

## Value Propositions

1. **Integrated workflow** - Unified tooling across packer->tofu->ansible with orchestration
2. **Proxmox-optimized** - Purpose-built for Proxmox VE homelabs (with Debian escape hatch)
3. **Opinionated defaults** - Sensible choices for homelab (SDN, cloud-init, security profiles)
4. **Testable infrastructure** - Nested PVE integration testing validates the full stack

## Configuration Flow

config (homestak/config) is the single source of truth:

```
config/
├── site.yaml       # Site-wide defaults (timezone, packages)
├── secrets.yaml    # API tokens, SSH keys, passwords
├── defs/           # JSON Schema definitions
├── hosts/          # Physical machines (SSH access)
├── nodes/          # PVE instances (API access)
├── postures/       # Security postures (dev, prod, local)
├── specs/          # Node specifications (what to become)
├── presets/        # VM size presets (cores, memory, disk)
└── manifests/      # Deployment topologies (v2 graph nodes)
        │
        ▼
ConfigResolver (iac-driver)
        │
        ├── resolve_inline_vm()    → tfvars.json  → tofu
        └── resolve_ansible_vars() → ansible-vars → ansible
```

This eliminates configuration drift between components - all settings flow from config.

## Design Principles

- **Do it right** - Prefer proper solutions over quick workarounds. If a task is worth doing, invest in the reusable, maintainable approach rather than one-off hacks. Today's shortcut becomes tomorrow's technical debt.
- **Repeatability over flexibility** - Prefer conventions that "just work" over infinite configurability
- **Local-first execution** - Run on the host being configured to avoid SSH connection issues
- **Idempotent operations** - Safe to run multiple times
- **Secrets in code, encrypted** - SOPS + age in config repo, git hooks for auto-encrypt/decrypt
- **Component independence** - Each repo installs its own dependencies via `make install-deps`
- **Process consistency** - When presenting options to the user, flag any option that deviates from established processes (lifecycle docs, RELEASE.md). Do not present process-inconsistent options as equal alternatives without noting the inconsistency.

## Process Discipline

When assisting with development, follow the lifecycle process defined in `docs/lifecycle/`:

### Phase Sequence is Mandatory

1. **Never skip phases** - Each phase has a purpose. Do not suggest "let's skip design" or "we can do planning later."
2. **Checkpoints require verification** - At each checkpoint in `60-release.md`, pause for human confirmation before proceeding.
3. **Design before implementation** - Features require full design; enhancements need lightweight design. Only bug fixes with clear root causes may skip design.

### Behavioral Guidelines

| Do | Don't |
|----|-------|
| Follow the order in lifecycle docs | Suggest reordering phases for convenience |
| Ask clarifying questions during design | Assume requirements during implementation |
| Flag process deviations explicitly | Present shortcuts as equal alternatives |
| Reference specific lifecycle sections | Make up process steps |
| Respect user's specified order | Impose a different implementation sequence |

### Destructive Operations

For operations that cannot be easily undone:
- Require explicit `--force` flag for overwriting existing resources
- Default to error rather than silent overwrite
- Provide `--dry-run` preview when available

### Rulesets and HITL Gates

All public repos use GitHub Rulesets with OrganizationAdmin bypass. PRs are created by `homestak-bot` so the operator can review and approve normally.

- When `gh pr merge` fails due to ruleset policy, STOP and present the PR for human review
- The merge phase has a mandatory human gate: create PRs → await approval → merge
- Do not conflate "user asked to start merge phase" with "user approved the PRs"
- Use `GH_TOKEN=$HOMESTAK_BOT_TOKEN` when creating PRs via `gh pr create`

## Terminology

Consistent terminology across all repos:

| Use | Don't Use | Rationale |
|-----|-----------|-----------|
| integration test | E2E test, end-to-end test | Our tests validate component integration, not user journeys |
| scenario | workflow, pipeline | Scenarios are iac-driver's unit of orchestration |
| action | task, step | Actions are reusable primitives in iac-driver |
| config (repo) | site-config | Repo was renamed from site-config to config (homestak/config) |
| tofu | terraform | We use OpenTofu, not Terraform |

## Conventions

- **VM IDs**: 5-digit (10000+ dev, 20000+ k8s, 99900+ integration test)
- **Networks**: dev 192.0.2.0/24 (TEST-NET-1), k8s 203.0.113.0/24 (TEST-NET-3), management 198.51.100.0/24 (TEST-NET-2)
- **Hostnames**: `{cluster}{instance}` (dev1, kubeadm1, router)
- **Environments**: dev (permissive) vs prod (hardened)

## Host Capabilities

Not all hosts have the same capabilities. Key distinctions:

| Host | QEMU/KVM | PVE API | Notes |
|------|----------|---------|-------|
| srv1 | Yes | Yes | Primary build host for packer images |
| srv2 | Yes | Yes | Secondary PVE host |
| dev machines | Maybe | No | May lack nested virtualization |

**Packer builds require QEMU/KVM.** Build on capable hosts using `packer/build` directly or via SSH:
```bash
ssh srv1 'cd ~/lib/packer && ./build'
```

## Bootstrap Pattern

The `bootstrap` repo provides capability installation via `homestak install <module>`:

```bash
# Initial setup (on any Debian host)
curl -fsSL https://raw.githubusercontent.com/homestak/bootstrap/master/install | sudo bash

# Switch to homestak user, then add capabilities as needed
sudo -iu homestak
homestak install packer    # QEMU, packer, templates
homestak install tofu      # OpenTofu
homestak install ansible   # Ansible + collections
```

This pattern enables any Debian host to become a build/deploy host without manual setup.

### Installation Paths (User-Owned Model)

All files are owned by the dedicated `homestak` user under `~homestak/`. The layout mirrors the dev workstation structure:

```
~homestak/                     # /home/homestak/
├── bootstrap/                 # CLI and installer (in PATH)
├── config/                    # Secrets, manifests, site-specific config
├── iac/                       # IaC repos
│   ├── ansible/
│   ├── iac-driver/
│   ├── tofu/
│   └── packer/                # (optional)
├── .cache/                    # Downloaded images, temp files
└── logs/                      # Server and config logs
```

Access via: `sudo -iu homestak` (bootstrap adds `~/bootstrap` to PATH via `~/.profile`).

## Release Automation CLI (v0.14+)

The `scripts/release` CLI automates multi-repo release operations.

### Commands

| Command | Description |
|---------|-------------|
| `--version` | Show CLI version |
| `--help` | Show help message |
| `init --version X.Y --issue N` | Initialize release state (issue required) |
| `status [--json]` | Show release progress (--json for machine-readable) |
| `resume` | Show AI-friendly recovery context (markdown) |
| `preflight` | Check repos ready (clean, no tags, CHANGELOGs) |
| `validate [--stage]` | Run iac-driver integration tests (--stage uses installed CLI) |
| `tag --dry-run` | Preview tag creation |
| `tag --execute [--yes]` | Create and push tags (--yes skips confirmation) |
| `tag --reset` | Reset tags to HEAD (v0.x only) |
| `publish --dry-run` | Preview release creation |
| `publish --execute [--yes]` | Create GitHub releases |
| `packer --check` | Check for template changes |
| `packer --upload {--all \| template...}` | Upload local images to `latest` release |
| `packer --remove {--all \| template...}` | Remove image assets from `latest` release |
| `full --dry-run` | Preview complete release workflow |
| `full --execute` | Execute end-to-end release |
| `verify [--json]` | Verify all releases exist (--json for machine-readable) |
| `retrospective --done` | Mark retrospective phase complete |
| `close [--force] [--yes]` | Close release issue and clean up state |
| `sunset --below-version X.Y` | Delete releases below version (preserves tags) |
| `audit` | Show timestamped action log |

### Release Workflow

```bash
# Manual workflow
./scripts/release init --version 0.31 --issue 115
./scripts/release preflight
./scripts/release validate --host srv1
# Or use --stage to validate via installed CLI (requires bootstrap on remote)
./scripts/release validate --stage --remote srv1
./scripts/release tag --dry-run
./scripts/release tag --execute --yes
./scripts/release publish --execute --yes
./scripts/release verify
# ... complete AAR, housekeeping ...
./scripts/release retrospective --done
./scripts/release close --execute --yes

# Or use full command for end-to-end automation
./scripts/release full --dry-run
./scripts/release full --execute --host srv1
```

### Release Issue Tracking

**Important:** When executing a release, always identify the release tracking issue at session start. Use `gh issue list --label release` or check for open issues titled "Release: vX.Y - <Theme>". Include `--issue N` when running `release init` to link the release state to the tracking issue.

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

### Testing

The release CLI has bats test coverage:

```bash
make test    # Run release CLI bats tests
make lint    # Run shellcheck on release CLI
```

Test structure:
- `test/test_helper/common.bash` - Shared setup, mocks, assertions
- `test/state.bats` - State file operations
- `test/cli.bats` - CLI command routing

CI runs tests on push/PR to master via `.github/workflows/ci.yml`.

### Release Session Recovery

When resuming a release after context loss (session timeout, context compaction), use the `resume` command for AI-friendly context:

```bash
# Get markdown-formatted recovery context (recommended for AI)
./scripts/release resume

# Check current release progress (human-readable)
./scripts/release status

# View timestamped action history
./scripts/release audit
```

The `resume` command outputs:
- Version, issue, status, started timestamp
- Phase status table with completion timestamps
- Repo status table (tag/release per repo)
- Recent audit log entries (last 10)
- Next steps based on current state

**State files:**
- `.release-state.json` - Phase completion status, repo tag/release status
- `.release-audit.log` - Chronological action log with timestamps

**Best practice:** Complete releases in a single session when possible. Multi-session releases risk state confusion and repeated/skipped work.

## Documentation Index

### AI Context (CLAUDE.md)

| File | Focus |
|------|-------|
| [CLAUDE.md](CLAUDE.md) | This file - vision, architecture, conventions |
| [.claude/CLAUDE.md](../.claude/CLAUDE.md) | Skills configuration |
| [.github/CLAUDE.md](../.github/CLAUDE.md) | GitHub platform config (CI/CD, branch protection) |
| [ansible/CLAUDE.md](../../iac/ansible/CLAUDE.md) | Playbooks, roles, collections |
| [bootstrap/CLAUDE.md](../../bootstrap/CLAUDE.md) | CLI, installation |
| [iac-driver/CLAUDE.md](../../iac/iac-driver/CLAUDE.md) | Scenarios, actions, testing |
| [packer/CLAUDE.md](../../iac/packer/CLAUDE.md) | Templates, build workflow |
| [config/CLAUDE.md](../../config/CLAUDE.md) | Config schema, secrets |
| [tofu/CLAUDE.md](../../iac/tofu/CLAUDE.md) | Modules, environments |

### Development Lifecycle

7-phase development process in [docs/lifecycle/](docs/lifecycle/):

| File | Purpose |
|------|---------|
| [00-overview.md](docs/lifecycle/00-overview.md) | Work types, phase matrix, multi-repo structure |
| [10-sprint-planning.md](docs/lifecycle/10-sprint-planning.md) | Sprint scoping and backlog formation |
| [20-design.md](docs/lifecycle/20-design.md) | Pre-implementation design and validation planning |
| [30-implementation.md](docs/lifecycle/30-implementation.md) | Development, testing, CHANGELOG updates |
| [40-validation.md](docs/lifecycle/40-validation.md) | Integration testing requirements |
| [50-merge.md](docs/lifecycle/50-merge.md) | PR process and documentation updates |
| [60-release.md](docs/lifecycle/60-release.md) | Release coordination and tagging |
| [69-release-retro.md](docs/lifecycle/69-release-retro.md) | Retrospective and lessons learned codification |
| [75-lessons-learned.md](docs/lifecycle/75-lessons-learned.md) | Accumulated release insights (v0.8-v0.33) |

### Templates

Reusable templates in [docs/templates/](docs/templates/):

| File | Purpose |
|------|---------|
| [aar.md](docs/templates/aar.md) | After Action Report template |
| [retrospective.md](docs/templates/retrospective.md) | Sprint retrospective template |
| [epic-issue.md](docs/templates/epic-issue.md) | Epic issue template |
| [release-issue.md](docs/templates/release-issue.md) | Release planning issue template |
| [design-summary.md](docs/templates/design-summary.md) | Design documentation templates |

### Other Documentation

| File | Purpose |
|------|---------|
| [docs/CLI-CONVENTIONS.md](docs/CLI-CONVENTIONS.md) | CLI flag and naming standards |
| [docs/ISSUE-GUIDELINES.md](docs/ISSUE-GUIDELINES.md) | Issue creation and labeling standards |
| [docs/CLAUDE-GUIDELINES.md](docs/CLAUDE-GUIDELINES.md) | CLAUDE.md documentation standards |
| [docs/REPO-SETTINGS.md](docs/REPO-SETTINGS.md) | Repository configuration standards |
| [docs/uat.md](docs/uat.md) | UAT validation checklist |

### Design Documents

| File | Purpose |
|------|---------|
| [docs/designs/config-distribution.md](docs/designs/config-distribution.md) | Config distribution to delegated PVE nodes |
| [docs/designs/config-phase.md](docs/designs/config-phase.md) | Push/pull execution, spec-to-ansible mapping |
| [docs/designs/node-lifecycle.md](docs/designs/node-lifecycle.md) | Single-node lifecycle (create/config/run/destroy) |
| [docs/designs/node-orchestration.md](docs/designs/node-orchestration.md) | Topology patterns, execution models, system test catalog |
| [docs/designs/packer-pipeline.md](docs/designs/packer-pipeline.md) | Naming conventions, build workflow, caching, release integration |
| [docs/designs/provisioning-token.md](docs/designs/provisioning-token.md) | HMAC token format, signing, verification |
| [docs/designs/scenario-consolidation.md](docs/designs/scenario-consolidation.md) | Scenario migration, PVE lifecycle phases |
| [docs/designs/server-daemon.md](docs/designs/server-daemon.md) | Daemon architecture, PID management, operator integration |
| [docs/designs/test-strategy.md](docs/designs/test-strategy.md) | Test hierarchy, system test catalog (ST-1 through ST-8) |

## Release Process

See [docs/lifecycle/60-release.md](docs/lifecycle/60-release.md) for the release methodology, including:
- Repository dependency order
- 10-phase release workflow
- After action reports and retrospectives

**Automated releases (v0.14+):** Use `scripts/release` CLI - see [Release Automation CLI](#release-automation-cli-v014) section above.

## Issue Management

When creating GitHub issues, follow [docs/ISSUE-GUIDELINES.md](docs/ISSUE-GUIDELINES.md):

- **Title format:** `<Verb> <what>` (e.g., "Add --dry-run flag", "Fix timeout error")
- **Work type label:** Apply exactly one of `bug`, `enhancement`, or `epic`
- **Modifier labels:** Add `documentation`, `refactor`, `testing`, `security`, `breaking-change` as applicable
- **Description:** Include context (why), acceptance criteria (what done looks like), and constraints

For label definitions and examples, see the full guide.

## License

Apache 2.0
