# Requirements Catalog

**Sprint:** 0 (Lifecycle Decomposition)
**Issue:** [iac-driver#141](https://github.com/homestak-dev/iac-driver/issues/141)
**Source:** [iac-driver#125 Comment #5](https://github.com/homestak-dev/iac-driver/issues/125#issuecomment-2621234567)
**Status:** Active
**Last Updated:** 2026-02-03

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
- CTL: Controller (unified HTTP server)
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
| REQ-CRE-001 | VM ID allocation must be deterministic or auto-assigned | P0 | Validated | design | - | `test -M n1-basic-v2` |
| REQ-CRE-002 | Serial device required for Debian 12 cloud images (prevents kernel panic) | P0 | Validated | test | - | `test -M n1-basic-v2` |
| REQ-CRE-003 | Unique identity must be established at birth (hostname, token) | P0 | Validated | design | node-lifecycle.md | spec-vm-push-roundtrip |
| REQ-CRE-004 | Cloud-init user-data must be injected via NoCloud datasource | P0 | Validated | design | - | `test -M n1-basic-v2` |
| REQ-CRE-005 | SSH authorized keys must be injected for initial access | P0 | Validated | design | - | `test -M n1-basic-v2` |
| REQ-CRE-006 | Automation user created via cloud-init (default: homestak) | P0 | Validated | design | - | `test -M n1-basic-v2` |
| REQ-CRE-007 | Packer images use .qcow2, PVE expects .img (extension rename) | P0 | Validated | impl | - | packer-build |
| REQ-CRE-008 | Large images (>2GB) must be split for GitHub release assets | P1 | Validated | test | - | packer-build-fetch |
| REQ-CRE-009 | 'latest' tag requires API resolution (not usable in direct URLs) | P1 | Validated | test | - | DownloadGitHubReleaseAction |
| REQ-CRE-010 | Image must exist before VM creation | P0 | Validated | impl | - | `create -M n1-basic-v2` |
| REQ-CRE-011 | Create constraints (cores, memory, disk) bound future purpose | P2 | Proposed | design | node-lifecycle.md | - |
| REQ-CRE-012 | VM IDs should use 5-digit convention (10000+ dev, 99900+ test) | P2 | Validated | design | - | site-config |

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
| REQ-CFG-009 | State isolation per env+node (`.states/{env}-{node}/`) | P0 | Validated | impl | - | test_actions.py |
| REQ-CFG-010 | State file must be outside TF_DATA_DIR (OpenTofu bug workaround) | P0 | Validated | impl | - | - |
| REQ-CFG-011 | Provider lockfiles can become stale (preflight auto-clears) | P1 | Validated | test | - | - |
| REQ-CFG-012 | Context must be serializable for persistence (JSON) | P1 | Validated | impl | - | test_cli.py |
| REQ-CFG-013 | Context mutations persist (passed by reference) | P0 | Validated | impl | - | - |
| REQ-CFG-014 | tfvars.json written atomically (temp file + rename) | P1 | Validated | impl | - | - |
| REQ-CFG-015 | State directory auto-created if missing | P1 | Validated | impl | - | - |

---

## CTL: Controller

Requirements for the unified controller daemon (specs + repos serving).

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-CTL-001 | Single daemon serving both specs and repos | P0 | Proposed | design | #148 | test_ctrl_server.py |
| REQ-CTL-002 | Single port for all endpoints (default: 44443) | P0 | Proposed | design | #148 | test_ctrl_server.py |
| REQ-CTL-003 | Posture-based auth for /spec/* (network, site_token, node_token) | P0 | Proposed | design | #148 | test_ctrl_auth.py |
| REQ-CTL-004 | Token auth for /repos/* (Bearer token) | P0 | Proposed | design | #148 | test_ctrl_auth.py |
| REQ-CTL-005 | Daemon lifecycle: PID file, SIGTERM graceful shutdown, SIGHUP cache clear | P0 | Proposed | design | #148 | test_ctrl_server.py |
| REQ-CTL-006 | Git dumb HTTP protocol for repos serving | P0 | Proposed | design | #148 | test_ctrl_repos.py |
| REQ-CTL-007 | `_working` branch for uncommitted changes | P0 | Proposed | design | #148 | test_ctrl_repos.py |
| REQ-CTL-008 | /health endpoint (no auth) | P1 | Proposed | design | #148 | test_ctrl_server.py |
| REQ-CTL-009 | /repos endpoint lists available repos | P1 | Proposed | design | #148 | test_ctrl_repos.py |
| REQ-CTL-010 | Spec caching with SIGHUP invalidation | P1 | Proposed | design | #148 | test_ctrl_specs.py |
| REQ-CTL-011 | TLS required for all connections | P0 | Proposed | design | #148 | test_ctrl_server.py |
| REQ-CTL-012 | Self-signed cert auto-generation | P0 | Proposed | design | #148 | test_ctrl_tls.py |
| REQ-CTL-013 | site-config cert support | P1 | Proposed | design | #148 | - (design only) |
| REQ-CTL-014 | Cert fingerprint logging on startup | P2 | Proposed | design | #148 | test_ctrl_server.py |

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
| REQ-NET-007 | Each nesting level needs outer host's SSH key (for jump chains) | P0 | Validated | test | - | nested-pve scenarios |
| REQ-NET-008 | Each nesting level needs its own key (for child VM access) | P0 | Validated | test | - | nested-pve scenarios |
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

---

## LIF: Lifecycle

Requirements for the 4-phase lifecycle model from node-lifecycle.md.

| ID | Requirement | Priority | Status | Source | Design Doc | Test |
|----|-------------|----------|--------|--------|------------|------|
| REQ-LIF-001 | 4-phase model: create → config → run → destroy | P0 | Accepted | design | node-lifecycle.md | ST-1, ST-2 |
| REQ-LIF-002 | Config phase reaches "platform ready" state | P0 | Proposed | design | config-apply.md | ST-1 |
| REQ-LIF-003 | Run phase supports drift detection | P1 | Proposed | design | phase-interfaces.md | - |
| REQ-LIF-004 | Destroy phase handles graceful shutdown | P1 | Proposed | design | phase-interfaces.md | - |
| REQ-LIF-005 | Push, pull, and hybrid are co-equal execution models | P0 | Accepted | design | node-lifecycle.md | ST-1, ST-2, ST-5 |
| REQ-LIF-006 | Spec schema defines "what to become" (packages, services, users) | P0 | Validated | design | node-lifecycle.md | `make validate` (site-config) |
| REQ-LIF-007 | Auth model: network/site_token/node_token by posture | P0 | Validated | design | node-lifecycle.md | spec-vm-push-roundtrip |
| REQ-LIF-008 | Identity injected via cloud-init env vars | P0 | Validated | design | node-lifecycle.md | spec-vm-push-roundtrip |

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
| REQ-NFR-009 | Plumbing code uses reasonable abbreviations (e.g., `ctrl` for controller, `cfg` for config) | P2 | Accepted | design | - | - |
| REQ-NFR-010 | Test files abbreviate long prefixes (e.g., `test_ctrl_*` not `test_controller_*`) | P2 | Accepted | design | - | - |

---

## Traceability Matrix

Mapping test coverage to requirements.

| Test | Requirements Covered |
|------|---------------------|
| `test_config_resolver.py` | REQ-CFG-001, 003, 004, 005, REQ-SEC-003, 007 |
| `test_common.py` | REQ-EXE-001, 002, 003, 005, 008, 009, 010, REQ-NET-001, 002, 006, 012, 013 |
| `test_actions.py` | REQ-CFG-009, REQ-REC-001 |
| `test_cli.py` | REQ-CFG-012, REQ-OBS-004, 007, 009, 012, REQ-REC-005, 007 |
| `test_manifest.py` | REQ-ORC-001, 004 |
| `test_validation.py` | REQ-NET-011 |
| `test_recursive_action.py` | REQ-OBS-001, 011 |
| `test_scenario_attributes.py` | REQ-OBS-010 |
| `test_ctrl_server.py` | REQ-CTL-001, 002, 005, 008, 011, 014 |
| `test_ctrl_tls.py` | REQ-CTL-012 |
| `test_ctrl_auth.py` | REQ-CTL-003, 004 |
| `test_ctrl_specs.py` | REQ-CTL-010 |
| `test_ctrl_repos.py` | REQ-CTL-006, 007, 009 |
| `test_resolver_base.py` | REQ-CFG-003, 004, REQ-SEC-007 |
| `test_spec_resolver.py` | REQ-LIF-006 |
| `test_spec_client.py` | REQ-LIF-007, 008 |
| `test -M n1-basic-v2` | REQ-CRE-001, 002, 004, 005, 006, 010 |
| `spec-vm-push-roundtrip` | REQ-CRE-003, REQ-LIF-007, 008, REQ-CTL-001, 003 |
| `controller-repos` | REQ-CTL-004, 006, 007 |
| `test -M n2-quick-v2` | REQ-NET-007, 008, REQ-CFG-013, 014, 015 |
| ST-1 | REQ-LIF-001, 002, 005, REQ-CTL-001, 003 |
| ST-2 | REQ-LIF-001, REQ-ORC-003, REQ-CTL-004, 006 |
| ST-3, ST-4 | REQ-ORC-005 |
| ST-5 | REQ-LIF-005, REQ-ORC-002, 006 |
| ST-7 | REQ-ORC-004, 009 |
| ST-8 | REQ-TST-004, 005 |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-06 | Sprint #199 overlay: REQ-LIF-006 test ref updated (`spec validate` → `make validate` in site-config); REQ-NFR-005 satisfied (serve.py, spec_resolver.py deleted) |
| 2026-02-05 | Updated REQ-ORC-003 to verb-based CLI pattern |
| 2026-02-05 | Added TLS requirements (REQ-CTL-011 to 014); updated traceability matrix |
| 2026-02-05 | Added CTL category (unified controller) with REQ-CTL-001 through 010; updated traceability matrix |
| 2026-02-03 | Added Source column; integrated implicit requirements from codebase (CFG-013 to 015, EXE-008 to 010, NET-012 to 014, OBS-011, 012) |
| 2026-02-03 | Initial catalog from iac-driver#125 Comment #5 |
