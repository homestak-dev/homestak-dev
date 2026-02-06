# Test Strategy

**Sprint:** 0 (Lifecycle Decomposition)
**Issue:** [iac-driver#141](https://github.com/homestak-dev/iac-driver/issues/141)
**Status:** Active
**Date:** 2026-02-03

## Overview

This document defines the test hierarchy for homestak's lifecycle architecture, covering unit tests, integration tests, and system tests (full lifecycle). It catalogs existing test coverage and maps system test scenarios to requirements.

## Test Hierarchy

### Unit Tests

**Scope:** Single function/class in isolation with mocked dependencies.

**Location:** `iac-driver/tests/`

**Execution:** `pytest` (local, no infrastructure required)

**Current state:**
| File | Lines | Coverage Focus |
|------|-------|----------------|
| `conftest.py` | ~200 | Shared fixtures, mocks |
| `test_actions.py` | ~720 | Action classes (tofu, ansible, SSH, etc.) |
| `test_cli_integration.py` | ~340 | CLI argument parsing, scenario routing |
| `test_cli.py` | ~180 | Basic CLI functions |
| `test_common.py` | ~330 | Utility functions (run_command, wait_*) |
| `test_config.py` | ~490 | HostConfig, node discovery |
| `test_config_resolver.py` | ~820 | ConfigResolver, FK resolution, tfvars |
| `test_manifest.py` | ~600 | Manifest parsing, schema validation |
| `test_readiness.py` | ~260 | Preflight checks |
| `test_recursive_action.py` | ~640 | RecursiveScenarioAction, JSON parsing |
| `test_scenario_attributes.py` | ~340 | Scenario metadata, expected_runtime |
| `test_validation.py` | ~640 | Validation action classes |

**Total:** 12 files, ~5,500 lines (including conftest.py)

**Unified controller additions (iac-driver#146):**
| File | Lines | Coverage Focus |
|------|-------|----------------|
| `test_ctrl_server.py` | ~400 | HTTPS server, daemon lifecycle, signals |
| `test_ctrl_auth.py` | ~300 | Posture + token auth middleware |
| `test_ctrl_specs.py` | ~400 | Spec endpoint, caching, SIGHUP |
| `test_ctrl_repos.py` | ~400 | Git protocol, `_working` branch |
| `test_ctrl_tls.py` | ~200 | Self-signed cert generation, fingerprint |
| `test_resolver_base.py` | ~300 | Shared FK resolution utilities |
| `test_spec_resolver.py` | ~400 | SpecResolver (migrated from bootstrap) |
| `test_spec_client.py` | ~300 | HTTP client, error handling, state |

**iac-driver#146 total:** +2,700 lines, 8 new files

**Target coverage for new lifecycle/ components:**
- `lifecycle/core/create.py` - Create phase orchestration
- `lifecycle/core/config.py` - Config phase orchestration
- `lifecycle/primitives/*.py` - Extracted action primitives

### Integration Tests

**Scope:** Component interaction within a controlled environment. Tests validate that components work together correctly.

**Location:** `iac-driver/src/scenarios/` (current)

**Execution:** `./run.sh --scenario <name> --host <host>`

**Validation focus:** Single-host operations, component boundaries.

**Current scenarios:**
| Scenario | Components Tested | Duration |
|----------|-------------------|----------|
| `./run.sh test -M n1-basic-v2 -H <host>` | tofu + PVE API + SSH | ~2m |
| `spec-vm-push-roundtrip` | controller + spec_client + tofu | ~2m |
| `pve-setup` | ansible + PVE host | ~3m |
| `user-setup` | ansible (users role) | ~30s |
| `bootstrap-install` | bootstrap + validation | ~2m |
| `packer-build` | packer + QEMU | ~3m |

**Unified controller additions (iac-driver#146):**
| Scenario | Components Tested | Duration |
|----------|-------------------|----------|
| `controller-repos` | controller + git clone | ~30s |

**Characteristics:**
- Require real PVE host (not mocked)
- Test single component interactions
- Can run independently
- Focus on "does it work" not "is the full lifecycle correct"

### System Tests (Full Lifecycle)

**Scope:** Multi-phase behavior, multi-node topologies, complete lifecycle validation.

**Location:** `iac-driver/src/manifest_opr/` (operator engine)

**Execution:** `./run.sh test -M <name> -H <host>`

**Validation focus:** ST-1 through ST-8 from node-orchestration.md.

**Characteristics:**
- Validate complete lifecycle (create → config → run → destroy)
- Test multi-node topologies
- Test execution mode variations (push/pull/hybrid)
- Require full infrastructure stack
- Long-running (5-30 minutes)

## System Test Catalog

From [node-orchestration.md](node-orchestration.md), these scenarios validate the full architecture.

### ST-1: Single-node Pull Lifecycle

**Validates:** Config phase, spec fetch, pull execution

**Topology:** Flat (1 node)

**Execution:** Pull

**Blocks:** config-apply.md

```yaml
Manifest:
  nodes:
    - name: test-vm
      spec: base
      preset: vm-small
      execution:
        mode: pull
```

**Steps:**
1. Driver provisions VM with identity + spec_server env vars
2. VM boots, runs `homestak spec get`
3. VM applies spec locally (config phase — future)
4. Verify: VM reaches platform ready state
5. Destroy VM

**Assertions:**
- Spec fetched from server (check `/usr/local/etc/homestak/state/spec.yaml`)
- SSH access works with keys from spec
- Packages from spec installed
- Services from spec running

### ST-2: Single-node Push Lifecycle

**Validates:** Push execution path

**Topology:** Flat (1 node)

**Execution:** Push

**Blocks:** `./run.sh create/destroy/test -M X -H host`

```yaml
Manifest:
  nodes:
    - name: test-vm
      spec: base
      preset: vm-small
      execution:
        mode: push
```

**Steps:**
1. Driver provisions VM
2. Driver SSHes to VM, applies configuration
3. Verify: VM reaches platform ready state
4. Destroy VM

**Assertions:**
- No spec server required
- Configuration applied via SSH
- Same end state as ST-1

### ST-3: Tiered Topology (2-level)

**Validates:** Parent-child ordering, tiered deployment

**Topology:** Tiered (2 levels)

**Execution:** Push

**Blocks:** `./run.sh create/destroy/test -M X -H host`

```yaml
Manifest:
  pattern: tiered
  nodes:
    - name: inner-pve
      spec: pve
      preset: vm-large
      parent: null

    - name: test-vm
      spec: base
      preset: vm-small
      parent: inner-pve
```

**Steps:**
1. Create inner-pve on driver host
2. inner-pve reaches platform ready (PVE installed)
3. Create test-vm on inner-pve
4. test-vm reaches platform ready
5. Destroy in reverse order

**Assertions:**
- Parent created before children
- Children destroyed before parent
- SSH chain works: driver → inner-pve → test-vm

### ST-4: Tiered Topology (3-level)

**Validates:** N-level nesting, depth handling

**Topology:** Tiered (3 levels)

**Execution:** Push

**Blocks:** `./run.sh create/destroy/test -M X -H host`

```yaml
Manifest:
  nodes:
    - name: level-1
      spec: pve
      parent: null

    - name: level-2
      spec: pve
      parent: level-1

    - name: level-3
      spec: base
      parent: level-2
```

**Assertions:**
- Creation order: level-1 → level-2 → level-3
- Destruction order: level-3 → level-2 → level-1
- Each level independently functional

### ST-5: Mixed Execution Modes

**Validates:** Push/pull coexistence, mode inheritance

**Topology:** Tiered (2 levels)

**Execution:** Mixed (push + pull)

**Blocks:** `./run.sh create/destroy/test -M X -H host`

```yaml
Manifest:
  execution:
    default_mode: pull
  nodes:
    - name: inner-pve
      spec: pve
      execution:
        mode: push        # Override

    - name: app-vm
      spec: base
      parent: inner-pve
      # Inherits: pull
```

**Assertions:**
- inner-pve configured by driver (push)
- app-vm fetched spec from server (pull)
- Spec server served app-vm's spec with correct auth

### ST-6: Flat Topology (Multiple Peers)

**Validates:** Parallel creation, peer nodes

**Topology:** Flat (3 peers)

**Execution:** Push

**Blocks:** `./run.sh create/destroy/test -M X -H host`

```yaml
Manifest:
  pattern: flat
  nodes:
    - name: worker-1
      spec: base

    - name: worker-2
      spec: base

    - name: worker-3
      spec: base
```

**Assertions:**
- No ordering dependency between peers
- All nodes created on same parent host
- Parallel creation (optimization)

### ST-7: Manifest Validation

**Validates:** Schema enforcement, FK resolution

**Topology:** N/A

**Execution:** N/A

**Blocks:** manifest-schema-v2.md

**Steps:**
1. `./run.sh validate -M v2/manifests/valid.yaml` → exit 0
2. `./run.sh validate -M v2/manifests/invalid-schema.yaml` → exit 1
3. `./run.sh validate -M v2/manifests/invalid-fk.yaml` → exit 1

**Assertions:**
- Valid manifests pass
- Schema violations caught
- Unresolved FKs caught

### ST-8: Action Idempotency

**Validates:** Safe re-runs, no duplicate resources

**Topology:** Flat (1 node)

**Execution:** Push

**Blocks:** Core

**Steps:**
1. Create node
2. Create again (re-run)
3. Verify no error, no duplicate
4. Destroy node
5. Destroy again (re-run)
6. Verify no error

**Assertions:**
- Create is idempotent (existing node detected)
- Destroy is idempotent (missing node not an error)

## Test Matrix Summary

| ID | Topology | Execution | Levels | Key Validation | Blocking Dependency |
|----|----------|-----------|--------|----------------|---------------------|
| ST-1 | Flat | Pull | 1 | Config phase, spec fetch | config-apply.md |
| ST-2 | Flat | Push | 1 | Push execution path | cli.py --manifest |
| ST-3 | Tiered | Push | 2 | Parent-child ordering | cli.py --manifest |
| ST-4 | Tiered | Push | 3 | N-level nesting | cli.py --manifest |
| ST-5 | Tiered | Mixed | 2 | Mode coexistence | cli.py --manifest |
| ST-6 | Flat | Push | 1 (x3) | Parallel creation | cli.py --manifest |
| ST-7 | N/A | N/A | N/A | Schema/FK validation | manifest-schema-v2.md |
| ST-8 | Flat | Push | 1 | Idempotency | Core |

## Mapping to Current Scenarios

| System Test | Current Equivalent | Gap | Blocked By |
|-------------|-------------------|-----|------------|
| ST-1 | `spec-vm-push-roundtrip` | Missing full config phase | iac-driver#147 |
| ST-2 | `./run.sh test -M n1-basic-v2` | **Available** — operator handles flat VM lifecycle | - |
| ST-3 | `./run.sh test -M n2-quick-v2` | **Available** — operator handles tiered PVE+VM | - |
| ST-4 | `./run.sh test -M n3-full-v2` | **Available** — operator delegates via SSH | - |
| ST-5 | None | New capability (mixed execution modes) | iac-driver#147 |
| ST-6 | None | New capability (parallel peer creation) | Future |
| ST-7 | None | New capability (manifest validation) | Future |
| ST-8 | Partial | Scenarios are mostly idempotent but not formally tested | Core |

### Unified Controller (iac-driver#146) Contribution to System Tests

The unified controller sprint (iac-driver#146) **enables** multiple system tests:

| System Test | Contribution |
|-------------|----------------------|
| ST-1 | Spec server infrastructure (controller/specs.py) |
| ST-2 | Repos serving for push execution (controller/repos.py) |
| ST-5 | Mixed mode support via posture-based auth |

## Coverage Matrix

Requirements → Tests traceability. See [requirements-catalog.md](requirements-catalog.md) for full requirement definitions.

| Requirement ID | Unit Tests | Integration Tests | System Tests |
|----------------|------------|-------------------|--------------|
| REQ-LIF-001 (4-phase model) | - | - | ST-1, ST-2 |
| REQ-LIF-002 (platform ready) | - | - | ST-1 |
| REQ-ORC-001 (manifests) | test_manifest.py | - | ST-2 through ST-6 |
| REQ-ORC-002 (push/pull/hybrid) | - | - | ST-1, ST-2, ST-5 |
| REQ-ORC-003 (CLI --manifest) | - | - | All except ST-1, ST-7 |
| REQ-CRE-001 (VM ID allocation) | test_config_resolver.py | `./run.sh test -M n1-basic-v2` | ST-2 |
| REQ-CRE-002 (serial device) | - | `./run.sh test -M n1-basic-v2` | ST-2 |
| REQ-CFG-001 (site-config source) | test_config_resolver.py | - | - |
| REQ-EXE-001 (timeouts) | test_common.py | - | - |
| REQ-EXE-003 (idempotency) | - | - | ST-8 |

## Test Execution Guidelines

### Running Unit Tests

```bash
cd iac-driver
make test              # Run all unit tests
pytest tests/ -v       # Verbose output
pytest tests/test_config_resolver.py -k "test_resolve_env"  # Specific test
```

### Running Integration Tests

```bash
# Single component test (flat VM lifecycle)
./run.sh test -M n1-basic-v2 -H father

# With verbose output
./run.sh test -M n1-basic-v2 -H father --verbose

# Dry run (preview)
./run.sh test -M n1-basic-v2 -H father --dry-run
```

### Running System Tests

```bash
# Full lifecycle test
./run.sh test -M single-node -H father

# Create only (leave running for debugging)
./run.sh create -M nested-test -H father

# Destroy after debugging
./run.sh destroy -M nested-test -H father
```

## Changelog

| Date | Change |
|------|--------|
| 2026-02-06 | Update for scenario consolidation (#195): retired scenarios replaced with verb commands; ST-2/3/4 now available; system tests no longer "future" |
| 2026-02-05 | Replace ordinal sprint labels with issue references; update for #143+#144 combination |
| 2026-02-05 | Updated CLI references to verb-based subcommands; updated ST-7 validate commands |
| 2026-02-05 | Added test_controller_tls.py for TLS requirements; updated line counts |
| 2026-02-05 | Added unified controller unit tests (iac-driver#146); added controller-repos scenario; mapped ST gaps to scope issues |
| 2026-02-04 | Renamed spec-vm-roundtrip → vm-rt; updated ST-1 gap to reference iac-driver#147 |
| 2026-02-03 | Initial document |
