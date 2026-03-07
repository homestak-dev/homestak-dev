# Repository Prototype

Standard internal structure for homestak repositories. Companion to [REPO-SETTINGS.md](REPO-SETTINGS.md) which covers GitHub configuration.

## Universal Structure

Every repo, regardless of org, includes these files:

```
<repo>/
├── README.md              # User-facing documentation
├── CLAUDE.md              # AI context and developer guidance
├── CHANGELOG.md           # Release history (two-phase workflow)
├── LICENSE                # Apache 2.0
├── Makefile               # Standard targets (see below)
└── .github/
    └── workflows/
        └── ci.yml         # Lint + test on push/PR to master
```

### Standard Makefile Targets

| Target | Required | Description |
|--------|----------|-------------|
| `install-deps` | Yes | Install runtime dependencies (idempotent) |
| `test` | Yes | Run test suite |
| `lint` | Yes | Run linters/formatters |
| `install-dev` | Optional | Dev tooling (venv, pre-commit hooks) |
| `clean` | Optional | Remove generated/cached files |

Every repo must have `install-deps`, `test`, and `lint` — even if `test` is initially a no-op. This enables `gita shell make test` and `gita shell make lint` across all repos without exceptions.

### CHANGELOG.md Format

```markdown
# Changelog

## Unreleased

## vX.Y - YYYY-MM-DD

### Added
### Changed
### Fixed
### Removed
```

Entries go under "Unreleased" during implementation. Version header added during release phase. See [lifecycle/30-implementation.md](lifecycle/30-implementation.md).

### CLAUDE.md Conventions

See [CLAUDE-GUIDELINES.md](CLAUDE-GUIDELINES.md) for content standards. Every CLAUDE.md should include:

- Project overview and purpose
- Quick reference (common commands)
- Project structure
- Related projects table
- License

## Org-Specific Prototypes

### homestak (user-facing)

Repos: `bootstrap`, `site-config`, `bare-metal`

User-facing repos prioritize clear README documentation and simple entry points. Names describe purpose, not tools.

```
<repo>/
├── README.md              # Installation and usage guide
├── CLAUDE.md
├── CHANGELOG.md
├── LICENSE
├── Makefile
├── .github/workflows/ci.yml
└── <repo-specific content>
```

No additional structural requirements beyond the universal set. Each repo is unique in purpose.

### homestak-apps (application repos)

Repos: `pihole`, `jellyfin`, `home-assistant`, `monitoring`, `homarr`, etc.

App repos follow a consistent structure so that iac-driver can consume them uniformly and community contributors know where things go:

```
<app>/
├── README.md              # What the app does, configuration options
├── CLAUDE.md
├── CHANGELOG.md
├── LICENSE
├── Makefile               # install-deps, test, lint
├── spec.yaml              # App specification (consumed by iac-driver)
├── defaults.yaml          # Default configuration values
├── roles/
│   └── <app>/             # Ansible role
│       ├── tasks/
│       │   └── main.yml
│       ├── templates/     # Config file templates (Jinja2)
│       ├── defaults/
│       │   └── main.yml   # Role defaults
│       ├── handlers/
│       │   └── main.yml
│       └── meta/
│           └── main.yml   # Role metadata and dependencies
├── tests/
│   └── verify.yml         # Smoke test playbook (is the service running?)
└── .github/
    └── workflows/
        └── ci.yml         # ansible-lint on roles, YAML validation
```

#### spec.yaml

The app's specification — what the VM should become. Extends the base spec schema:

```yaml
schema_version: 1

access:
  posture: dev
  users:
    - name: homestak
      sudo: true

platform:
  packages:
    - <app-specific packages>
  services:
    enable:
      - <app services>

config:
  timezone: America/Denver    # Inherited from site.yaml at resolve time
  app:
    <app-specific configuration>
```

#### defaults.yaml

User-overridable configuration. Consumed by the ansible role, overridden by site-config:

```yaml
# pihole example
upstream_dns:
  - 1.1.1.1
  - 8.8.8.8
web_port: 80
```

#### Ansible Role Conventions

- Role name matches repo name (e.g., `pihole` repo → `pihole` role)
- Use `homestak.apps.<name>` as the FQCN when used in collections
- Roles must be idempotent (safe to run multiple times)
- Include a `verify.yml` test playbook that checks the service is running
- Use `become: true` where privilege escalation is needed

### homestak-iac (infrastructure)

Repos: `iac-driver`, `tofu`, `ansible`, `packer`

These repos already have established patterns. No structural changes needed — continue with current conventions.

| Repo | Test Framework | Lint |
|------|---------------|------|
| iac-driver | pytest | pylint + mypy |
| tofu | tofu validate | tofu fmt |
| ansible | — | ansible-lint |
| packer | bats | shellcheck + packer validate |

### homestak-dev (developer experience)

Repos: `workspace` (this repo), `.claude`, `.github`

These repos serve the development process. Structure is already established:

- `homestak-dev`: docs/, scripts/, lifecycle process
- `.claude`: skills/, settings
- `.github`: org profile, PR templates, workflows

## CI Workflow Template

Standard CI workflow for new repos:

```yaml
name: CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: make install-deps
      - name: Lint
        run: make lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: make install-deps
      - name: Test
        run: make test
```

Adjust for repo-specific needs (Python setup, Node setup, etc.).

## Creating a New Repo

1. Start with the universal structure (README, CLAUDE.md, CHANGELOG, LICENSE, Makefile, CI)
2. Apply org-specific prototype (app repo structure for homestak-apps, etc.)
3. Configure GitHub settings per [REPO-SETTINGS.md](REPO-SETTINGS.md)
4. Add to gita workspace: `gita add <path>`
5. Add to release.sh repo list (if participating in unified versioning)

## Related Documents

- [REPO-SETTINGS.md](REPO-SETTINGS.md) — GitHub repository configuration
- [CLAUDE-GUIDELINES.md](CLAUDE-GUIDELINES.md) — CLAUDE.md content standards
- [ISSUE-GUIDELINES.md](ISSUE-GUIDELINES.md) — Issue creation and labeling
- [CLI-CONVENTIONS.md](CLI-CONVENTIONS.md) — CLI flag and naming standards
