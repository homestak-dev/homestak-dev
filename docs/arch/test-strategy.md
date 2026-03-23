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

### Test Matrix Command (planned)

A single command to run all manifests with aggregated reporting:

```bash
# UAT mode (default): create → verify → destroy each manifest
meta/scripts/uat test-matrix -H srv1

# Sprint mode: create → verify, stop on first failure
meta/scripts/uat test-matrix -H srv1 --mode sprint

# Specific manifests only
meta/scripts/uat test-matrix -H srv1 --manifests n1-push,n2-push

# Sprint branch validation
meta/scripts/uat test-matrix -H srv1 --branch sprint/operator-simplify
```

## Reporting

**Report location:** `$HOMESTAK_ROOT/logs/reports/` on each target host
(planned move from `iac-driver/reports/`)

### Per-Manifest Report (exists today)

```
$HOMESTAK_ROOT/logs/reports/YYYYMMDD-HHMMSS.n1-push.passed.json
```

### Matrix Summary (planned)

```json
{
  "run_id": "20260322-180000",
  "host": "srv1",
  "mode": "uat",
  "branch": "master",
  "results": {
    "n1-push": { "status": "passed", "duration": 58 },
    "n1-pull": { "status": "passed", "duration": 150 },
    "n2-push": { "status": "passed", "duration": 368 },
    "n2-pull": { "status": "passed", "duration": 489 },
    "n3-deep": { "status": "passed", "duration": 961 }
  },
  "total_duration": 2026,
  "all_passed": true
}
```

Reports include host identity and branch so multi-host aggregation works from
Phase 1.

## Automated UAT Pipeline (planned)

### Single-Host Pipeline

```bash
meta/scripts/uat run -H srv1
```

Orchestrates the full virgin-to-validated flow:

```
bare-metal/reinstall srv1 --yes          # Fresh Debian (~5-10 min)
ssh user@srv1 'curl ... | sudo bash'     # Bootstrap (~3 min)
sudo -iu homestak homestak site-init --yes   # Auto-detect network (bootstrap#71)
sudo -iu homestak homestak pve-setup     # PVE + reboot + re-run (~6 min)
sudo -iu homestak homestak images download all --publish  # (~2 min)
meta/scripts/uat test-matrix -H srv1     # All 5 manifests (~30 min)
```

**Reboot handling:** `pve-setup` reboots after PVE kernel install. The orchestrator
detects the SSH drop, polls for reconnection, and re-runs `pve-setup` to complete
the packages phase.

**Branch support:** `--branch sprint/foo` deploys sprint branches to the target
host before running the matrix.

```bash
meta/scripts/uat run -H srv1 --branch sprint/operator-simplify
```

### Multi-Host Pipeline

```bash
meta/scripts/uat run --hosts srv1,srv2,srv3
```

Provisions N hosts in parallel, distributes manifests by weight, runs tests
concurrently, aggregates results:

```
Dev workstation (orchestrator)
│
├── Provision (parallel)
│   ├── srv1: reinstall → bootstrap → site-init → pve-setup → images
│   ├── srv2: reinstall → bootstrap → site-init → pve-setup → images
│   └── srv3: reinstall → bootstrap → site-init → pve-setup → images
│
├── Test (parallel, distributed by weight)
│   ├── srv1: n1-push, n2-push
│   ├── srv2: n1-pull, n2-pull
│   └── srv3: n3-deep
│
└── Report (aggregate)
    └── Matrix summary (all hosts, all manifests, single pass/fail)
```

**Manifest distribution:** Configurable assignment of manifests to hosts.
Default distributes by resource weight (n1-* light, n2-* medium, n3-deep heavy).

**Agent-per-host model:** Each host can be managed by a separate Claude agent.
The orchestrator dispatches work, host agents execute independently, results
aggregate via structured JSON.

**Multi-host matrix summary:**
```json
{
  "run_id": "20260322-180000",
  "hosts": ["srv1", "srv2", "srv3"],
  "branch": "master",
  "results": {
    "n1-push": { "host": "srv1", "status": "passed", "duration": 58 },
    "n1-pull": { "host": "srv2", "status": "passed", "duration": 150 },
    "n2-push": { "host": "srv1", "status": "passed", "duration": 368 },
    "n2-pull": { "host": "srv2", "status": "passed", "duration": 489 },
    "n3-deep": { "host": "srv3", "status": "passed", "duration": 961 }
  },
  "total_wall_clock": 961,
  "all_passed": true
}
```

Wall-clock time limited by the slowest host, not the sum of all manifests.

## Prerequisites

The UAT pipeline depends on:

| Component | Repo | Status |
|-----------|------|--------|
| `bare-metal/reinstall` | bare-metal | Exists — fresh Debian via EFI boot-next |
| `bootstrap/install` | bootstrap | Exists — curl\|bash installer |
| `homestak site-init --yes` | bootstrap | Planned (bootstrap#71) — auto-detect network |
| `homestak pve-setup` | iac-driver | Exists — PVE install with reboot re-entry |
| `homestak images download all --publish` | bootstrap | Exists |
| `meta/scripts/uat` | meta | Planned — orchestrator script |

## Implementation Phases

| Phase | Delivers | Enables |
|-------|----------|---------|
| 1: Foundation | Report relocation, test matrix command (sequential, single host) | One-command test runs, consistent reporting |
| 2: Zero-touch | bootstrap#71 (site-init --yes), `meta/scripts/uat` orchestrator | Virgin-to-validated in one command |
| 3: Multi-host | Parallel provisioning, manifest distribution, agent-per-host | Full parallel validation across N hosts |

### Design Principles

- **Reports are data, not console output** — structured JSON first, human-readable derived
- **Reports include host identity** — enables multi-host aggregation from Phase 1
- **Manifest list is discoverable** — from `$HOMESTAK_ROOT/config/manifests/n*.yaml`, not hardcoded
- **Orchestration lives in meta** — dev tooling, not runtime infrastructure
- **Exit codes are meaningful** — 0 = all passed, 1 = failures, 2 = setup error

## Changelog

| Date | Change |
|------|--------|
| 2026-03-22 | Major revision: split iac-driver specifics to `iac-driver/docs/testing.md`, added UAT pipeline and multi-host vision |
| 2026-02-03 | Initial document |
