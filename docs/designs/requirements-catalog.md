# Requirements Catalog

**Sprint:** 0 (Lifecycle Decomposition)
**Issue:** [iac-driver#141](https://github.com/homestak-dev/iac-driver/issues/141)
**Source:** [iac-driver#125 Comment #5](https://github.com/homestak-dev/iac-driver/issues/125#issuecomment-2621234567)
**Status:** Active
**Last Updated:** 2026-02-06

## Overview

This document catalogs requirements extracted from ~40 releases (v0.3-v0.45) of homestak development. Requirements are sourced from:

1. **Lessons Learned** (docs/lifecycle/75-lessons-learned.md)
2. **Action Implementations** (iac-driver/src/actions/*.py)
3. **Known Issues** (CLAUDE.md files)
4. **Design Documents** (docs/designs/*.md)

## ID Schema

```
REQ-{CATEGORY}-{NUMBER}

Categories:
- CRE: Create/Provisioning
- CFG: Configuration (config phase)
- CTL: Server (unified HTTP server, formerly "controller")
- EXE: Execution (command running, timeouts)
- NET: Networking (SSH, API access)
- OBS: Observability (logging, reporting)
- REC: Recovery/Failure handling
- SEC: Security (secrets, auth)
- LIF: Lifecycle (4-phase model)
- ORC: Orchestration (multi-node, manifests)
- TST: Testing
- NFR: Non-Functional (cleanup, naming, structure)
```

## Status Values

| Status | Meaning |
|--------|---------|
| `proposed` | Identified but not formally accepted |
| `accepted` | Approved for implementation |
| `implemented` | Code exists but may not be validated |
| `validated` | Tested and confirmed working |
| `deprecated` | Superseded or no longer applicable |

## Source Values

| Source | Meaning |
|--------|---------|
| `design` | Explicitly designed upfront (from design docs or architecture) |
| `impl` | Discovered during implementation (code patterns, workarounds) |
| `test` | Discovered during testing (bug fixes, platform-specific behavior) |
| `prod` | Discovered in production (operational issues) |

---

## CRE: Create/Provisioning

Requirements for the create phase: VM allocation, identity injection, image management.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-CRE-001 | VM ID allocation must be deterministic or auto-assigned | P0 | Validated | design | - | `test -M n1-push` |
| REQ-CRE-002 | Serial device required for Debian 12 cloud images (prevents kernel panic) | P0 | Validated | test | - | `test -M n1-push` |
| REQ-CRE-003 | Unique identity must be established at birth (hostname, token) | P0 | Validated | design | node-lifecycle.md | push-vm-roundtrip |
| REQ-CRE-004 | Cloud-init user-data must be injected via NoCloud datasource | P0 | Validated | design | - | `test -M n1-push` |
| REQ-CRE-005 | SSH authorized keys must be injected for initial access | P0 | Validated | design | - | `test -M n1-push` |
| REQ-CRE-006 | Automation user created via cloud-init (default: homestak) | P0 | Validated | design | - | `test -M n1-push` |
| REQ-CRE-007 | Packer images use .qcow2, PVE expects .img (extension rename) | P0 | Validated | impl | - | packer-build |
| REQ-CRE-008 | Large images (>2GB) must be split for GitHub release assets | P1 | Validated | test | - | packer-build-fetch |
| REQ-CRE-009 | 'latest' tag requires API resolution (not usable in direct URLs) | P1 | Validated | test | - | DownloadGitHubReleaseAction |
| REQ-CRE-010 | Image must exist before VM creation | P0 | Validated | impl | - | `create -M n1-push` |
| REQ-CRE-011 | Create constraints (cores, memory, disk) bound future purpose | P2 | Proposed | design | node-lifecycle.md | - |
| REQ-CRE-012 | VM IDs should use 5-digit convention (10000+ dev, 99900+ test) | P2 | Validated | design | - | site-config |
| REQ-CRE-013 | Cloud-init runcmd chains `spec get` → `./run.sh config` on first boot | P0 | Accepted | design | config-phase.md | `test -M n1-pull` |
| REQ-CRE-014 | Provisioning token minted at create time by ConfigResolver | P0 | Accepted | design | provisioning-token.md | `test -M n1-pull` |
| REQ-CRE-015 | Token injected via cloud-init as `HOMESTAK_TOKEN` env var | P0 | Accepted | design | provisioning-token.md | `test -M n1-pull` |

---

## CFG: Configuration

Requirements for the config phase: sources, resolution, state management.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-CFG-001 | site-config is single source of truth | P0 | Validated | design | - | test_config_resolver.py |
| REQ-CFG-002 | Secrets must be decrypted before use (SOPS + age) | P0 | Validated | design | - | site-config hooks |
| REQ-CFG-003 | ConfigResolver must auto-discover site-config (env → sibling → FHS → legacy) | P0 | Validated | impl | - | test_config_resolver.py |
| REQ-CFG-004 | Config merge order: preset → template → env → overrides | P0 | Validated | design | - | test_config_resolver.py |
| REQ-CFG-005 | All inheritance resolved in Python (consumers get flat config) | P0 | Validated | design | - | test_config_resolver.py |
| REQ-CFG-006 | YAML manipulation must use proper libraries (not sed/echo) | P1 | Accepted | test | - | - |
| REQ-CFG-007 | Boolean extra-vars need `| bool` filter in Ansible | P1 | Validated | test | - | - |
| REQ-CFG-008 | Node config filename must match PVE node name | P0 | Validated | impl | - | - |
| REQ-CFG-009 | State isolation per manifest+node+host (`.states/{manifest}/{node}-{host}/`) | P0 | Validated | impl | - | test_actions.py |
| REQ-CFG-010 | State file must be outside TF_DATA_DIR (OpenTofu bug workaround) | P0 | Validated | impl | - | - |
| REQ-CFG-011 | Provider lockfiles can become stale (preflight auto-clears) | P1 | Validated | test | - | - |
| REQ-CFG-012 | Context must be serializable for persistence (JSON) | P1 | Validated | impl | - | test_cli.py |
| REQ-CFG-013 | Context mutations persist (passed by reference) | P0 | Validated | impl | - | - |
| REQ-CFG-014 | tfvars.json written atomically (temp file + rename) | P1 | Validated | impl | - | - |
| REQ-CFG-015 | State directory auto-created if missing | P1 | Validated | impl | - | - |
| REQ-CFG-016 | `./run.sh config` maps spec to ansible vars and runs existing roles locally | P0 | Accepted | design | config-phase.md | `test -M n1-pull` |
| REQ-CFG-017 | Platform-ready marker written on successful config only | P0 | Accepted | design | config-phase.md | `test -M n1-pull` |
| REQ-CFG-018 | Config command is idempotent (safe to run multiple times) | P0 | Accepted | design | config-phase.md | - |
| REQ-CFG-019 | Spec-to-ansible mapping covers packages, timezone, users, SSH keys, security posture | P0 | Accepted | design | config-phase.md | `test -M n1-pull` |

---

## CTL: Server

Requirements for the unified server daemon (specs + repos serving). Previously named "controller" — renamed in iac-driver#177 because the component is a passive server (nodes pull from it), not a controller.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-CTL-001 | Single daemon serving both specs and repos | P0 | Validated | design | server-daemon.md | test_ctrl_server.py |
| REQ-CTL-002 | Single port for all endpoints (default: 44443) | P0 | Validated | design | server-daemon.md | test_ctrl_server.py |
| REQ-CTL-003 | ~~Posture-based auth for /spec/*~~ Deprecated: replaced by provisioning token (REQ-CTL-025) | P0 | Deprecated | design | server-daemon.md | test_ctrl_auth.py |
| REQ-CTL-004 | Token auth for /repos/* (Bearer token) | P0 | Validated | design | server-daemon.md | test_ctrl_auth.py |
| REQ-CTL-005 | Daemon lifecycle: PID file, SIGTERM graceful shutdown, SIGHUP cache clear | P0 | Accepted | design | server-daemon.md | test_ctrl_server.py |
| REQ-CTL-006 | Git dumb HTTP protocol for repos serving | P0 | Validated | design | server-daemon.md | test_ctrl_repos.py |
| REQ-CTL-007 | `_working` branch for uncommitted changes | P0 | Validated | design | server-daemon.md | test_ctrl_repos.py |
| REQ-CTL-008 | /health endpoint (no auth) | P1 | Validated | design | server-daemon.md | test_ctrl_server.py |
| REQ-CTL-009 | /repos endpoint lists available repos | P1 | Validated | design | server-daemon.md | test_ctrl_repos.py |
| REQ-CTL-010 | Spec caching with SIGHUP invalidation | P1 | Validated | design | server-daemon.md | test_ctrl_specs.py |
| REQ-CTL-011 | TLS required for all connections | P0 | Validated | design | server-daemon.md | test_ctrl_server.py |
| REQ-CTL-012 | Self-signed cert auto-generation | P0 | Validated | design | server-daemon.md | test_ctrl_tls.py |
| REQ-CTL-013 | site-config cert support | P1 | Proposed | design | server-daemon.md | - (design only) |
| REQ-CTL-014 | Cert fingerprint logging on startup | P2 | Validated | design | server-daemon.md | test_ctrl_server.py |
| REQ-CTL-015 | Exec chain: `run.sh` execs python3 directly (no bash wrapper in PID chain) | P0 | Accepted | design | server-daemon.md | `server start` + `server stop` |
| REQ-CTL-016 | Double-fork daemonization: setsid, detach from terminal/SSH | P0 | Accepted | design | server-daemon.md | `server start` via SSH |
| REQ-CTL-017 | Health-check startup gate: parent blocks until /health responds | P0 | Accepted | design | server-daemon.md | `server start` |
| REQ-CTL-018 | Port-qualified PID file at FHS path (`/var/run/homestak/server-{port}.pid`) | P0 | Accepted | design | server-daemon.md | `server start` |
| REQ-CTL-019 | Stale PID detection: dead process → clean up and restart | P1 | Accepted | design | server-daemon.md | Scenario 5 |
| REQ-CTL-020 | `server stop`: SIGTERM → 5s wait → SIGKILL escalation | P0 | Accepted | design | server-daemon.md | `server stop` |
| REQ-CTL-021 | `server status`: JSON output, exit codes (0=healthy, 1=not running, 2=unhealthy) | P1 | Accepted | design | server-daemon.md | `server status --json` |
| REQ-CTL-022 | Daemon logging to FHS path (`/var/log/homestak/server.log`), no fallback | P1 | Accepted | design | server-daemon.md | `server start` |
| REQ-CTL-023 | Operator auto-lifecycle: ensure server for all manifest verbs | P0 | Accepted | design | server-daemon.md | `test -M n1-pull` |
| REQ-CTL-024 | Idempotent start (detect healthy → reuse) and stop (detect not running → success) | P1 | Accepted | design | server-daemon.md | Scenario 4 |
| REQ-CTL-025 | Spec endpoint requires provisioning token (no unauthenticated access, no legacy auth fallback) | P0 | Accepted | design | provisioning-token.md | `test -M n1-pull` |
| REQ-CTL-026 | Server extracts spec FK from token `s` claim (not from URL identity) | P0 | Accepted | design | provisioning-token.md | `test -M n1-pull` |
| REQ-CTL-027 | Server validates token `n` claim matches URL identity (defense in depth) | P1 | Accepted | design | provisioning-token.md | `test -M n1-pull` |

---

## EXE: Execution

Requirements for command execution, timeouts, and idempotency.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-EXE-001 | All commands must have configurable timeout (default 600s) | P0 | Validated | design | - | test_common.py |
| REQ-EXE-002 | Return tuple: (returncode, stdout, stderr) | P0 | Validated | impl | - | test_common.py |
| REQ-EXE-003 | Timeout returns rc=-1 (distinguishes from command failure) | P0 | Validated | impl | - | test_common.py |
| REQ-EXE-004 | Complex scripts need base64 encoding for SSH | P1 | Validated | test | - | - |
| REQ-EXE-005 | All wait_* functions must be idempotent (safe to retry) | P0 | Validated | design | - | test_common.py |
| REQ-EXE-006 | Destructors should handle partial state (discovery patterns) | P1 | Validated | test | - | - |
| REQ-EXE-007 | Detection should use stable markers (not racing service startup) | P1 | Accepted | test | - | - |
| REQ-EXE-008 | Environment inherited via os.environ.copy() | P1 | Validated | impl | - | - |
| REQ-EXE-009 | Process group for cleanup on timeout (subprocess with start_new_session) | P1 | Validated | impl | - | - |
| REQ-EXE-010 | Shell=True for commands with pipes/redirects | P1 | Validated | impl | - | - |
| REQ-EXE-011 | WaitForFileAction polls for file existence via SSH with configurable timeout/interval | P0 | Accepted | design | config-phase.md | `test -M n1-pull` |

### Timeout Tiers (Established)

| Operation | Default | Tier |
|-----------|---------|------|
| SSH command | 60s | Quick |
| SSH wait | 60s | Short |
| Ping wait | 60s | Short |
| Guest agent wait | 300s | Medium |
| Tofu init | 120s | Medium |
| Tofu apply | 300s | Medium |
| Ansible playbook | 600s | Long |
| PVE install | 1200s | Extended |
| File download | 300s | Medium |
| Generic command | 600s | Long |

---

## NET: Networking/Connectivity

Requirements for SSH patterns, multi-level access, and API connectivity.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-NET-001 | Relaxed host key checking required (`StrictHostKeyChecking=no`) | P0 | Validated | test | - | test_common.py |
| REQ-NET-002 | `UserKnownHostsFile=/dev/null` (PVE symlink workaround) | P0 | Validated | test | - | test_common.py |
| REQ-NET-003 | PVE hosts use root user for SSH | P0 | Validated | design | - | - |
| REQ-NET-004 | VMs use automation_user (default: homestak) | P0 | Validated | design | - | - |
| REQ-NET-005 | Jump host chains use nested SSH (not ProxyJump - PVE issue) | P1 | Validated | test | - | - |
| REQ-NET-006 | ConnectTimeout must be per-call | P0 | Validated | impl | - | test_common.py |
| REQ-NET-007 | Each nesting level needs parent node's SSH key (for jump chains) | P0 | Validated | test | - | `test -M n2-tiered` |
| REQ-NET-008 | Each nesting level needs its own key (for child VM access) | P0 | Validated | test | - | `test -M n2-tiered` |
| REQ-NET-009 | SSH chain verification required (VerifySSHChainAction) | P1 | Validated | impl | - | - |
| REQ-NET-010 | PVE API via SSH commands (qm, pvesh) | P0 | Validated | impl | - | - |
| REQ-NET-011 | API token must be valid before scenarios (preflight check) | P0 | Validated | impl | - | test_validation.py |
| REQ-NET-012 | SSH BatchMode=yes for non-interactive execution | P1 | Validated | impl | - | - |
| REQ-NET-013 | SSH LogLevel=ERROR to suppress warnings | P2 | Validated | impl | - | - |
| REQ-NET-014 | Retry with exponential backoff for transient SSH failures | P1 | Validated | impl | - | - |

---

## OBS: Observability

Requirements for logging, reporting, and progress indication.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-OBS-001 | Real-time streaming for nested scenarios (PTY allocation) | P1 | Validated | impl | - | test_recursive_action.py |
| REQ-OBS-002 | Remote output prefixed with [inner] | P1 | Validated | impl | - | - |
| REQ-OBS-003 | Error messages truncated (500 chars) to prevent log flooding | P2 | Validated | impl | - | - |
| REQ-OBS-004 | JSON output for programmatic consumption (--json-output) | P0 | Validated | design | - | test_cli.py |
| REQ-OBS-005 | Markdown reports for humans (YYYYMMDD-HHMMSS.{status}.md) | P1 | Validated | impl | - | - |
| REQ-OBS-006 | Phase timing captured in reports | P1 | Validated | impl | - | - |
| REQ-OBS-007 | Context included in JSON output | P0 | Validated | design | - | test_cli.py |
| REQ-OBS-008 | Phase descriptions displayed during execution | P1 | Validated | impl | - | - |
| REQ-OBS-009 | Dry-run preview available (--dry-run) | P1 | Validated | design | - | test_cli.py |
| REQ-OBS-010 | Scenario runtime estimates (expected_runtime attribute) | P2 | Validated | impl | - | test_scenario_attributes.py |
| REQ-OBS-011 | PTY allocation for streaming (-t flag in SSH) | P1 | Validated | impl | - | - |
| REQ-OBS-012 | JSON output to stdout, logs to stderr (separation) | P0 | Validated | impl | - | - |
| REQ-OBS-013 | All spec-fetch attempts logged (including transient retries) to `/var/log/homestak/config.log` | P1 | Accepted | design | provisioning-token.md | `test -M n1-pull` |

---

## REC: Recovery/Failure

Requirements for error handling, failure modes, and recovery patterns.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-REC-001 | ActionResult captures success/failure | P0 | Validated | impl | - | test_actions.py |
| REQ-REC-002 | No exceptions for operational failures (convert to ActionResult) | P0 | Validated | impl | - | - |
| REQ-REC-003 | Error messages should be actionable (include context) | P1 | Accepted | design | - | - |
| REQ-REC-004 | Fallback to stdout if stderr empty | P1 | Validated | impl | - | - |
| REQ-REC-005 | Context file enables chained runs (--context-file) | P1 | Validated | design | - | test_cli.py |
| REQ-REC-006 | Destructors should work without prior context | P1 | Validated | impl | - | - |
| REQ-REC-007 | Keep-on-failure for debugging (--keep-on-failure) | P1 | Validated | design | - | test_cli.py |
| REQ-REC-008 | Clean temp files between runs | P1 | Accepted | test | - | - |
| REQ-REC-009 | Transient spec-fetch errors retry with exponential backoff (5 attempts, ~2.5 min) | P1 | Accepted | design | provisioning-token.md | `test -M n1-pull` |
| REQ-REC-010 | Permanent spec-fetch errors write fail marker (`config-failed.json`) with null-safe fields | P0 | Accepted | design | provisioning-token.md | `test -M n1-pull` |

---

## SEC: Security

Requirements for secret management, SSH key handling, and access control.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-SEC-001 | Secrets in SOPS-encrypted file (secrets.yaml.enc) | P0 | Validated | design | - | - |
| REQ-SEC-002 | Decryption via age key (~/.config/sops/age/keys.txt) | P0 | Validated | design | - | - |
| REQ-SEC-003 | API tokens resolved by FK reference | P0 | Validated | design | - | test_config_resolver.py |
| REQ-SEC-004 | Never commit plaintext secrets (pre-commit hook blocks) | P0 | Validated | design | - | - |
| REQ-SEC-005 | Keys injected via cloud-init (ssh_authorized_keys) | P0 | Validated | design | - | - |
| REQ-SEC-006 | Private keys copied for nested levels | P1 | Validated | test | - | - |
| REQ-SEC-007 | Key references use FK pattern (secrets.ssh_keys.{name}) | P0 | Validated | design | - | test_config_resolver.py |
| REQ-SEC-008 | FHS installations require sudo | P1 | Validated | test | - | - |
| REQ-SEC-009 | Automation user has passwordless sudo | P1 | Validated | design | - | - |
| REQ-SEC-010 | Root login controlled by posture | P0 | Validated | design | - | - |
| REQ-SEC-011 | Signing key (256-bit HMAC) stored in secrets.yaml, encrypted at rest by SOPS | P0 | Accepted | design | provisioning-token.md | `test -M n1-pull` |
| REQ-SEC-012 | Missing signing_key is a hard error at mint time (no silent fallback) | P0 | Accepted | design | provisioning-token.md | test_config_resolver.py |
| REQ-SEC-013 | HMAC verification uses constant-time comparison (`hmac.compare_digest`) | P0 | Accepted | design | provisioning-token.md | test_ctrl_auth.py |

---

## LIF: Lifecycle

Requirements for the 4-phase lifecycle model from node-lifecycle.md.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-LIF-001 | 4-phase model: create → config → run → destroy | P0 | Accepted | design | node-lifecycle.md | ST-1, ST-2 |
| REQ-LIF-002 | Config phase reaches "platform ready" state | P0 | Accepted | design | config-phase.md | ST-1, `test -M n1-pull` |
| REQ-LIF-003 | Run phase supports drift detection | P1 | Proposed | design | phase-interfaces.md | - |
| REQ-LIF-004 | Destroy phase handles graceful shutdown | P1 | Proposed | design | phase-interfaces.md | - |
| REQ-LIF-005 | Push, pull, and hybrid are co-equal execution models | P0 | Accepted | design | node-lifecycle.md | ST-1, ST-2, ST-5 |
| REQ-LIF-006 | Spec schema defines "what to become" (packages, services, users) | P0 | Validated | design | node-lifecycle.md | `make validate` (site-config) |
| REQ-LIF-007 | ~~Auth model: network/site_token/node_token by posture~~ Deprecated: replaced by provisioning token (REQ-CTL-025, REQ-SEC-011) | P0 | Deprecated | design | node-lifecycle.md | push-vm-roundtrip |
| REQ-LIF-008 | Provisioning token injected via cloud-init as `HOMESTAK_TOKEN` env var (replaces `HOMESTAK_IDENTITY` + `HOMESTAK_AUTH_TOKEN`) | P0 | Validated | design | node-lifecycle.md, provisioning-token.md | `test -M n1-pull` |

---

## ORC: Orchestration

Requirements for multi-node coordination from node-orchestration.md.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-ORC-001 | Manifests define topology independent of execution | P0 | Accepted | design | node-orchestration.md | ST-2 through ST-6 |
| REQ-ORC-002 | Push/pull/hybrid execution models are co-equal | P0 | Accepted | design | node-orchestration.md | ST-5 |
| REQ-ORC-003 | CLI: `./run.sh create\|destroy\|test -M <manifest> -H <host>` (verb-based subcommands) | P0 | Proposed | design | node-orchestration.md | ST-2 through ST-6 |
| REQ-ORC-004 | Manifest v1 (levels) deprecated, v2 (nodes) only | P0 | Accepted | design | node-orchestration.md | ST-7 |
| REQ-ORC-005 | Parent created before children, children destroyed before parent | P0 | Accepted | design | node-orchestration.md | ST-3, ST-4 |
| REQ-ORC-006 | Execution mode inherits from document default with per-node override | P1 | Accepted | design | node-orchestration.md | ST-5 |
| REQ-ORC-007 | Flat topology supports parallel peer creation | P1 | Proposed | design | node-orchestration.md | ST-6 |
| REQ-ORC-008 | Manifests reference specs and presets directly (no v2/nodes/) | P1 | Accepted | design | node-orchestration.md | - |
| REQ-ORC-009 | Manifest validation catches schema violations and unresolved FKs | P0 | Proposed | design | manifest-schema-v2.md | ST-7 |
| REQ-ORC-010 | Pull nodes verified via file markers, not SSH-based config push | P0 | Accepted | design | config-phase.md | `test -M n1-pull` |
| REQ-ORC-011 | `execution.mode: pull` on `type: pve` nodes is a manifest validation error | P1 | Accepted | design | config-phase.md | test_manifest.py |

---

## TST: Testing

Requirements for test infrastructure and validation.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-TST-001 | Unit tests cover ConfigResolver, CLI, actions, manifest parsing | P0 | Validated | design | test-strategy.md | pytest |
| REQ-TST-002 | Integration tests validate component interaction | P0 | Validated | design | test-strategy.md | scenarios |
| REQ-TST-003 | System tests validate full lifecycle (ST-1 through ST-8) | P0 | Proposed | design | test-strategy.md | - |
| REQ-TST-004 | Create action is idempotent (existing node detected) | P0 | Proposed | design | - | ST-8 |
| REQ-TST-005 | Destroy action is idempotent (missing node not error) | P0 | Proposed | design | - | ST-8 |

---

## NFR: Non-Functional Requirements

Requirements for code quality, naming, structure, and cleanup.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-NFR-001 | Code carried forward must follow naming conventions | P1 | Proposed | design | gap-analysis.md | Code review |
| REQ-NFR-002 | Directory structure must align with new architecture | P1 | Proposed | design | gap-analysis.md | - |
| REQ-NFR-003 | Deprecated code paths must have removal timeline | P1 | Proposed | design | scenario-consolidation.md | - |
| REQ-NFR-004 | File/class names must match their purpose | P2 | Proposed | design | - | Code review |
| REQ-NFR-005 | Dead code must be removed, not commented | P2 | Proposed | design | - | Code review |
| REQ-NFR-006 | Scenario names follow `noun-verb` pattern | P2 | Accepted | impl | - | - |
| REQ-NFR-007 | Phase names follow `verb_noun` pattern | P2 | Accepted | impl | - | - |
| REQ-NFR-008 | Action classes follow `VerbNounAction` pattern | P2 | Accepted | impl | - | - |
| REQ-NFR-009 | Plumbing code uses reasonable abbreviations (e.g., `srv` for server, `cfg` for config) | P2 | Accepted | design | - | - |
| REQ-NFR-010 | Test files abbreviate long prefixes (e.g., `test_srv_*` not `test_server_*`) | P2 | Accepted | design | - | - |

---

## Traceability Matrix

Mapping test coverage to requirements.

| Test | Requirements Covered |
|------|---------------------|
| `test_config_resolver.py` | REQ-CFG-001, 003, 004, 005, REQ-SEC-003, 007, 012, REQ-CRE-014 |
| `test_common.py` | REQ-EXE-001, 002, 003, 005, 008, 009, 010, REQ-NET-001, 002, 006, 012, 013 |
| `test_actions.py` | REQ-CFG-009, REQ-REC-001 |
| `test_cli.py` | REQ-CFG-012, REQ-OBS-004, 007, 009, 012, REQ-REC-005, 007 |
| `test_manifest.py` | REQ-ORC-001, 004, 011 |
| `test_validation.py` | REQ-NET-011 |
| `test_recursive_action.py` | REQ-OBS-001, 011 |
| `test_scenario_attributes.py` | REQ-OBS-010 |
| `test_ctrl_server.py` | REQ-CTL-001, 002, 005, 008, 011, 014 |
| `test_ctrl_tls.py` | REQ-CTL-012 |
| `test_ctrl_auth.py` | ~~REQ-CTL-003~~, 004, REQ-CTL-025, 026, 027, REQ-SEC-013 |
| `test_ctrl_specs.py` | REQ-CTL-010 |
| `test_ctrl_repos.py` | REQ-CTL-006, 007, 009 |
| `test_resolver_base.py` | REQ-CFG-003, 004, REQ-SEC-007 |
| `test_spec_resolver.py` | REQ-LIF-006 |
| `test_spec_client.py` | ~~REQ-LIF-007~~, REQ-LIF-008, REQ-REC-009, 010, REQ-OBS-013 |
| `test -M n1-push` | REQ-CRE-001, 002, 004, 005, 006, 010 |
| `push-vm-roundtrip` | REQ-CRE-003, REQ-LIF-008, REQ-CTL-001 |
| `controller-repos` | REQ-CTL-004, 006, 007 |
| `test -M n2-tiered` | REQ-NET-007, 008, REQ-CFG-013, 014, 015 |
| ST-1 | REQ-LIF-001, 002, 005, REQ-CTL-001 |
| ST-2 | REQ-LIF-001, REQ-ORC-003, REQ-CTL-004, 006 |
| ST-3, ST-4 | REQ-ORC-005 |
| ST-5 | REQ-LIF-005, REQ-ORC-002, 006 |
| ST-7 | REQ-ORC-004, 009 |
| ST-8 | REQ-TST-004, 005 |
| `test -M n1-pull` | REQ-CRE-013, 014, 015, REQ-CFG-016, 017, 019, REQ-EXE-011, REQ-LIF-002, REQ-LIF-008, REQ-ORC-010, REQ-CTL-023, 025, 026, 027, REQ-SEC-011, REQ-REC-009, 010, REQ-OBS-013 |
| `server start` | REQ-CTL-005, 015, 016, 017, 018, 022, 024 |
| `server stop` | REQ-CTL-005, 015, 020, 024 |
| `server status` | REQ-CTL-021 |
| Scenario 4 (idempotency) | REQ-CTL-024 |
| Scenario 5 (stale recovery) | REQ-CTL-019 |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-11 | Sprint #231 (Provisioning Token): Deprecated REQ-CTL-003, REQ-LIF-007 (replaced by token auth); updated REQ-LIF-008 (HOMESTAK_TOKEN); added REQ-CRE-014–015, REQ-CTL-025–027, REQ-SEC-011–013, REQ-REC-009–010, REQ-OBS-013; updated traceability matrix |
| 2026-02-08 | iac-driver#177 overlay: Renamed CTL category (Controller → Server); updated CTL-001–014 status to `validated` with server-daemon.md refs; added CTL-015–024 (exec chain, daemonization, PID management, server stop/status, logging, operator lifecycle, idempotency); updated NFR-009/010 abbreviations (ctrl → srv); updated traceability matrix |
| 2026-02-06 | Sprint #201 (Config Phase): Added REQ-CRE-013, REQ-CFG-016–019, REQ-EXE-011, REQ-ORC-010–011; updated REQ-LIF-002 to `accepted` with config-phase.md ref; cleaned `-v2` manifest suffixes; added `test -M n1-pull` traceability |
| 2026-02-06 | Sprint #199 overlay: REQ-LIF-006 test ref updated (`spec validate` → `make validate` in site-config); REQ-NFR-005 satisfied (serve.py, spec_resolver.py deleted) |
| 2026-02-05 | Updated REQ-ORC-003 to verb-based CLI pattern |
| 2026-02-05 | Added TLS requirements (REQ-CTL-011 to 014); updated traceability matrix |
| 2026-02-05 | Added CTL category (unified controller) with REQ-CTL-001 through 010; updated traceability matrix |
| 2026-02-03 | Added Source column; integrated implicit requirements from codebase (CFG-013 to 015, EXE-008 to 010, NET-012 to 014, OBS-011, 012) |
| 2026-02-03 | Initial catalog from iac-driver#125 Comment #5 |
