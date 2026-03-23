# Test Strategy

## Overview

Homestak uses a three-tier test hierarchy: unit tests (fast, mocked), integration
tests (single-host, real infrastructure), and system tests (full lifecycle, multi-node).

For iac-driver-specific testing (system test catalog, validation sizing, unit test
guidance), see `$HOMESTAK_ROOT/iac/iac-driver/docs/testing.md`.

This document covers the cross-repo test automation vision: UAT pipeline,
multi-host orchestration, and reporting model.

## Test Matrix

The test matrix is the set of manifests run during validation. Manifests are
discovered from `$HOMESTAK_ROOT/config/manifests/n*.yaml`:

| Manifest | Pattern | Duration | Resource Weight |
|----------|---------|----------|-----------------|
| n1-push | flat | ~1 min | light |
| n1-pull | flat | ~2.5 min | light |
| n2-push | tiered | ~6 min | medium (nested virt) |
| n2-pull | tiered | ~8 min | medium (nested virt) |
| n3-deep | tiered | ~16 min | heavy (3-level nesting) |

### Test Matrix Command

Run the full matrix or specific manifests with aggregated reporting:

```bash
# Test mode (default): create → verify → destroy each manifest
meta/scripts/uat --host srv1

# Apply mode: create → verify, stop on first failure
meta/scripts/uat --host srv1 --mode apply

# Specific manifest only
meta/scripts/uat --host srv1 --manifest n1-push

# Sprint branch validation (deploys branch to target before testing)
meta/scripts/uat --host srv1 --branch sprint/operator-simplify

# Preview planned execution
meta/scripts/uat --host srv1 --dry-run
```

Host-to-manifest assignments are configured in `meta/test-matrix.yaml`.

## Reporting

**Per-manifest reports:** `$HOMESTAK_ROOT/logs/` on each target host (written by iac-driver).

**Matrix summaries:** `$HOMESTAK_ROOT/logs/` on the orchestrator (written by `scripts/uat`).

### Matrix Summary Format

```
$HOMESTAK_ROOT/logs/YYYYMMDD-HHMMSS.json   # structured results
$HOMESTAK_ROOT/logs/YYYYMMDD-HHMMSS.log    # stderr capture
```

```json
{
  "run_id": "20260322-232123",
  "mode": "test",
  "branch": "master",
  "hosts": ["srv1"],
  "started_at": "2026-03-22T23:21:23+00:00",
  "finished_at": "2026-03-22T23:54:54+00:00",
  "results": [
    {"host": "srv1", "manifest": "n1-push", "status": "passed", "duration": 53, "exit_code": 0},
    {"host": "srv1", "manifest": "n1-pull", "status": "passed", "duration": 154, "exit_code": 0}
  ],
  "total_duration": 2011,
  "passed": 5,
  "failed": 0,
  "all_passed": true,
  "interrupted": false
}
```

Summaries include host identity and branch for multi-host aggregation (Phase 3).

## UAT Pipeline

### Single-Host Pipeline (implemented)

```bash
# Full virgin-to-validated: provision host, then run matrix
meta/scripts/uat --host srv1 --provision

# Just run the test matrix (host already provisioned)
meta/scripts/uat --host srv1
```

The `--provision` flag orchestrates the full pipeline for each host:

```
bare-metal/reinstall srv1 --yes               # Fresh Debian
ssh user@srv1 'curl ... | sudo bash'          # Bootstrap
homestak site-init                            # Auto-detect network
homestak pve-setup                            # PVE + reboot + re-run
homestak images download all --publish        # Packer images
# then run assigned manifests from test-matrix.yaml
```

Each step has a configurable timeout (env vars `TIMEOUT_REINSTALL`, etc.) and
logs elapsed time on completion for baseline data collection.

**Reboot handling:** `pve-setup` reboots after PVE kernel install. The orchestrator
detects the SSH drop (exit code 255), polls for reconnection, and re-runs
`pve-setup` to complete the packages phase.

**Branch support:** `--branch sprint/foo` deploys sprint branches to the target
host before running the matrix. `--branch master` explicitly resets targets.

**Interrupt handling:** SIGINT/SIGTERM writes partial results JSON and appends to
the log file before exiting.

### Multi-Host Pipeline (Phase 3, planned)

The current script runs hosts sequentially. Phase 3 (#390) adds parallel execution:

```
Dev workstation (orchestrator)
│
├── Provision (parallel)
│   ├── srv1: reinstall → bootstrap → site-init → pve-setup → images
│   ├── srv2: reinstall → bootstrap → site-init → pve-setup → images
│   └── srv3: reinstall → bootstrap → site-init → pve-setup → images
│
├── Test (parallel per host, sequential per manifest)
│   ├── srv1: n1-push, n2-push
│   ├── srv2: n1-pull, n2-pull
│   └── srv3: n3-deep
│
└── Report (aggregate)
    └── Matrix summary (all hosts, all manifests, single pass/fail)
```

Host-to-manifest assignments are configured in `meta/test-matrix.yaml`.
Wall-clock time limited by the slowest host, not the sum of all manifests.

## Prerequisites

The UAT pipeline depends on:

| Component | Repo | Status |
|-----------|------|--------|
| `bare-metal/reinstall` | bare-metal | Exists — fresh Debian via EFI boot-next |
| `bootstrap/install` | bootstrap | Exists — curl\|bash installer |
| `homestak site-init` | bootstrap | Exists — auto-detect network |
| `homestak pve-setup` | iac-driver | Exists — PVE install with reboot re-entry |
| `homestak images download all --publish` | bootstrap | Exists |
| `meta/scripts/uat` | meta | Exists — matrix-driven test orchestrator |

## Implementation Phases

| Phase | Delivers | Status |
|-------|----------|--------|
| 1: Foundation | Report relocation to `$HOMESTAK_ROOT/logs/`, `homestak site-init` | Complete (sprint #381) |
| 2: Matrix-driven | `meta/scripts/uat` orchestrator, hardening, test-matrix.yaml | Complete (sprint #394) |
| 3: Multi-host | Parallel provisioning, manifest distribution across N hosts | Planned (#390) |

### Design Principles

- **Reports are data, not console output** — structured JSON first, human-readable derived
- **Reports include host identity** — enables multi-host aggregation from Phase 1
- **Manifest list is discoverable** — from `$HOMESTAK_ROOT/config/manifests/n*.yaml`, not hardcoded
- **Orchestration lives in meta** — dev tooling, not runtime infrastructure
- **Exit codes are meaningful** — 0 = all passed, 1 = failures, 2 = setup error

## Changelog

| Date | Change |
|------|--------|
| 2026-03-23 | Updated to reflect implemented state: Phase 1-2 complete, actual CLI and JSON formats, prerequisite statuses |
| 2026-03-22 | Major revision: split iac-driver specifics to `iac-driver/docs/testing.md`, added UAT pipeline and multi-host vision |
| 2026-02-03 | Initial document |
