# Scenario Consolidation

**Sprint:** homestak-dev#195
**Issues:** iac-driver#145, iac-driver#113
**Epic:** iac-driver#140 (Phase 3)
**Status:** Complete
**Date:** 2026-02-06

## Overview

This document describes the consolidation of 9 legacy scenarios and 3 remote actions into the manifest-based operator engine. After this change, VM lifecycle operations use verb commands (`create`/`destroy`/`test`) instead of scenario-specific classes.

## Migration Map

| Retired Scenario | Replacement |
|------------------|-------------|
| `vm-constructor` | `./run.sh create -M n1-push -H <host>` |
| `vm-destructor` | `./run.sh destroy -M n1-push -H <host>` |
| `vm-roundtrip` | `./run.sh test -M n1-push -H <host>` |
| `nested-pve-constructor` | `./run.sh create -M n2-tiered -H <host>` |
| `nested-pve-destructor` | `./run.sh destroy -M n2-tiered -H <host>` |
| `nested-pve-roundtrip` | `./run.sh test -M n2-tiered -H <host>` |
| `recursive-pve-constructor` | `./run.sh create -M <manifest> -H <host>` |
| `recursive-pve-destructor` | `./run.sh destroy -M <manifest> -H <host>` |
| `recursive-pve-roundtrip` | `./run.sh test -M <manifest> -H <host>` |

Running a retired scenario name prints a migration hint and exits with code 1.

## Retired Actions

| Action | File | Replacement |
|--------|------|-------------|
| `TofuApplyRemoteAction` | `actions/tofu.py` | Operator delegates via `RecursiveScenarioAction` with `raw_command` |
| `TofuDestroyRemoteAction` | `actions/tofu.py` | Operator delegates via `RecursiveScenarioAction` with `raw_command` |
| `SyncReposToVMAction` | `actions/ssh.py` | Bootstrap handles repo installation on remote hosts |

## Architecture

### Execution Model

The operator handles root nodes (depth 0) locally. PVE nodes with children are delegated:

```
Driver host (srv1)                   PVE node (root-pve)
────────────────────                   ─────────────────────
Operator creates root-pve (depth 0)
  → tofu apply, start, wait IP
  → PVE lifecycle (10 phases)
  → delegate subtree ─────SSH──────→  Operator creates edge (depth 0)
                                         → tofu apply, start, wait IP
  ← context (edge_ip, edge_vm_id) ──←   ← done
```

### PVE Lifecycle Phases

When the operator creates a PVE node that has children, it runs these phases before delegation:

| Phase | Action | Purpose |
|-------|--------|---------|
| bootstrap | `BootstrapAction` | curl\|bash installer on target PVE node |
| copy_secrets | `CopySecretsAction` | SCP scoped secrets.yaml (excludes api_tokens) |
| copy_site_config | `CopySiteConfigAction` | SCP site.yaml (DNS, gateway, timezone) |
| inject_ssh_key | `InjectSSHKeyAction` | Driver host key → target secrets |
| copy_private_key | `CopySSHPrivateKeyAction` | Private key for inner → child SSH |
| pve-setup | `RecursiveScenarioAction` | Run pve-setup on target PVE node |
| configure_bridge | `ConfigureNetworkBridgeAction` | Create vmbr0 from eth0 |
| generate_node_config | `GenerateNodeConfigAction` | `make node-config FORCE=1` |
| create_api_token | `CreateApiTokenAction` | pveum token + inject into secrets |
| inject_self_ssh_key | `InjectSelfSSHKeyAction` | PVE node's own key |
| download_images | `DownloadGitHubReleaseAction` | Images needed by children |

### Subtree Delegation

`ManifestGraph.extract_subtree(node_name)` builds a new manifest from a node's descendants:
- Direct children get `parent=None` (promoted to roots)
- Deeper descendants keep their parent references unchanged
- Settings inherited from the original manifest

The subtree manifest is serialized to JSON and passed via SSH:
```
./run.sh create --manifest-json '<json>' -H <hostname> --json-output
```

**HOMESTAK_SOURCE propagation:** `RecursiveScenarioAction._build_serve_repos_prefix()` reads `HOMESTAK_SOURCE`, `HOMESTAK_TOKEN`, and `HOMESTAK_REF` from `os.environ` and prepends them to the SSH command. Each PVE level's executor sets `HOMESTAK_SOURCE` to its own server address via `_set_source_env()`, creating a chain: srv1 → root-pve → leaf-pve. At depth 2+, `_set_source_env` uses `_detect_external_ip()` when `ssh_host` is `localhost` to ensure a routable address ([iac-driver#200](https://github.com/homestak-dev/iac-driver/issues/200)).

### RecursiveScenarioAction Extension

Added `raw_command` field. When set, replaces the default `homestak scenario <name>` command:

```python
RecursiveScenarioAction(
    name='delegate-subtree',
    raw_command='cd ~/lib/iac-driver && ./run.sh create --manifest-json ...',
    host_attr='pve_ip',
    context_keys=['edge_ip', 'edge_vm_id'],
)
```

## Files Changed

### Created
| File | Description |
|------|-------------|
| `src/actions/pve_lifecycle.py` | 9 PVE lifecycle actions + helper |
| `tests/test_pve_lifecycle.py` | Unit tests for lifecycle actions |

### Modified
| File | Change |
|------|--------|
| `src/manifest_opr/executor.py` | PVE lifecycle, delegation, remove depth guard |
| `src/manifest_opr/graph.py` | `extract_subtree()` method |
| `src/actions/recursive.py` | Add `raw_command` field |
| `src/actions/tofu.py` | Remove `TofuApplyRemoteAction`, `TofuDestroyRemoteAction` |
| `src/actions/ssh.py` | Remove `SyncReposToVMAction` |
| `src/scenarios/__init__.py` | Remove retired scenario imports |
| `src/scenarios/vm_roundtrip.py` | Fix `EnsureImageAction` import path |
| `src/cli.py` | Add `RETIRED_SCENARIOS` migration hints |

### Deleted
| File | Scenarios |
|------|-----------|
| `src/scenarios/vm.py` | vm-constructor, vm-destructor, vm-roundtrip |
| `src/scenarios/nested_pve.py` | nested-pve-constructor, nested-pve-destructor, nested-pve-roundtrip |
| `src/scenarios/recursive_pve.py` | recursive-pve-constructor, recursive-pve-destructor, recursive-pve-roundtrip |
| `src/scenarios/cleanup_nested_pve.py` | Shared cleanup actions |

## Remaining Scenarios

These scenarios remain as they serve purposes outside the manifest model:

| Scenario | Purpose |
|----------|---------|
| `pve-setup` | Host configuration (not manifest-based) |
| `user-setup` | User management (not manifest-based) |
| `packer-*` | Image building (not manifest-based) |
| `push-vm-roundtrip / pull-vm-roundtrip` | Spec discovery integration test |

## Related Documents

- [node-orchestration.md](node-orchestration.md) — Multi-node orchestration architecture
- [gap-analysis.md](gap-analysis.md) — Design gap tracking
