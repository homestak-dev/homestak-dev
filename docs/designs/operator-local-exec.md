# Design Summary: Operator Local Execution + Dead Code Cleanup

**Issues:** iac-driver#267, iac-driver#275 (phases 1-2)
**Sprint:** homestak-dev#296
**Author:** Claude + jderose
**Date:** 2026-03-01

## Problem Statement

The iac-driver operator (executor.py) runs on the target PVE host as the `homestak` user, yet several action classes in `proxmox.py` use `run_ssh(config.ssh_host, ...)` to execute PVE commands — SSHing to the very machine they're already running on. This adds unnecessary network round-trips, SSH authentication overhead, and fragility (SSH connectivity issues can fail operations that should be local).

Additionally, organic growth has left vestigial code paths and dead variables across iac-driver and tofu:

- **pve_setup.py** contains ~230 lines of `_run_remote()` methods that are unreachable (all executions use `--local` mode)
- **config_resolver.py** emits `ssh_user` in tfvars output, but tofu's `var.ssh_user` is declared and never referenced
- **file.py** `RemoveImageAction` hardcodes `user = 'root'` instead of using the standard automation_user + sudo pattern
- **config.py** `HostConfig` carries `node_name` and `datastore` attributes with zero references in `src/`

### Success Criteria

1. Local PVE actions (`StartVMAction`, `WaitForGuestAgentAction`, etc.) execute via `run_command()` instead of `run_ssh()`
2. Remote PVE actions (`StartVMRemoteAction`, `WaitForGuestAgentRemoteAction`, `DiscoverVMsAction`, `DestroyDiscoveredVMsAction`) remain SSH-based (they operate on delegated child nodes)
3. Dead remote paths removed from pve_setup.py
4. Dead `var.ssh_user` removed from tofu
5. Dead HostConfig attributes removed
6. All existing tests pass; new tests cover converted actions
7. Integration tests pass: `n1-push` (local path) and `n2-tiered` (delegation path)
8. Code quality: repeated patterns extracted into helpers, stale comments updated, verbose constructs tightened — every touched file leaves cleaner than it was found

## Proposed Solution

**Summary:** Convert local PVE actions from SSH to subprocess execution, remove dead code, and clean up vestigial variables — a pure simplification with no behavioral changes.

### High-level approach

1. **Local action conversion** — Replace `run_ssh(config.ssh_host, cmd, user=ssh_user)` with `run_command(['sudo', 'qm', ...])` in actions that execute on the operator's own host
2. **Preserve remote variants** — `StartVMRemoteAction`, `WaitForGuestAgentRemoteAction`, `DiscoverVMsAction`, and `DestroyDiscoveredVMsAction` keep SSH execution (they operate on delegated PVE nodes via the manifest operator)
3. **Dead code removal** — Delete unreachable `_run_remote()` methods from pve_setup.py
4. **Variable cleanup** — Remove `ssh_user` from ConfigResolver tfvars output and `var.ssh_user` from tofu; remove dead HostConfig attributes
5. **Consistency fix** — Convert `RemoveImageAction` from hardcoded `'root'` to `config.automation_user` + sudo pattern
6. **Code quality pass** — Tighten all touched files: extract DRY helpers, update stale comments, reduce verbosity

### Key components affected

**Phase 1 — Local execution (iac-driver#267):**

| File | Lines | Change |
|------|-------|--------|
| `src/actions/proxmox.py` | 16-248 | Convert 5 local action classes from `run_ssh()` to `run_command()` |
| `src/scenarios/pve_setup.py` | 169-193, 282-376, 493-588 | Remove ~230 lines of dead `_run_remote()` code |
| `src/manifest_opr/server_mgmt.py` | 43 | Enhance `_is_local` detection beyond localhost literals |

**Phase 2 — Dead code cleanup (iac-driver#275 phases 1-2):**

| File | Lines | Change |
|------|-------|--------|
| `src/config.py` | 47, 54 | Remove `node_name` and `datastore` attributes |
| `src/config_resolver.py` | 225 | Remove `ssh_user` from tfvars output dict |
| `src/actions/file.py` | 27 | Replace hardcoded `'root'` with `config.automation_user` + sudo |
| `tofu/envs/generic/variables.tf` | 20-24 | Remove `var.ssh_user` declaration |

**No new components introduced.**

## Detailed Changes

### Phase 1: Local Execution Conversion

#### 1a. proxmox.py — Local Actions (lines 16-248)

Five action classes convert from SSH to subprocess:

| Class | Lines | Current | After |
|-------|-------|---------|-------|
| `StartVMAction` | 16-51 | `run_ssh(pve_host, cmd, user=ssh_user)` | `run_command(['sudo', 'qm', 'start', str(vm_id)])` |
| `WaitForGuestAgentAction` | 54-94 | `run_ssh(pve_host, jq_cmd, user=ssh_user)` | `run_command(['sudo', 'pvesh', 'get', ...])` + parse |
| `LookupVMIPAction` | 97-136 | `run_ssh(pve_host, jq_cmd, user=ssh_user)` | Same pattern as WaitForGuestAgentAction |
| `StartProvisionedVMsAction` | 139-185 | `run_ssh(pve_host, cmd, user=ssh_user)` per VM | `run_command(['sudo', 'qm', 'start', str(vm_id)])` per VM |
| `WaitForProvisionedVMsAction` | 188-248 | `run_ssh(pve_host, jq_cmd, user=ssh_user)` per VM | `run_command(['sudo', 'pvesh', 'get', ...])` per VM |

**Pattern transformation:**

Before:
```python
def run(self, config: HostConfig, context: dict) -> ActionResult:
    pve_host = config.ssh_host
    ssh_user = config.automation_user
    sudo = '' if ssh_user == 'root' else 'sudo '

    cmd = f'{sudo}qm start {vm_id}'
    rc, out, err = run_ssh(pve_host, cmd, user=ssh_user, timeout=self.timeout)
```

After:
```python
def run(self, config: HostConfig, context: dict) -> ActionResult:
    cmd = ['sudo', 'qm', 'start', str(vm_id)]
    rc, out, err = run_command(cmd, timeout=self.timeout)
```

**Key simplifications:**
- No `pve_host` resolution needed (already on host)
- No `ssh_user` / conditional sudo — always `sudo` since operator runs as `homestak`
- No SSH timeout, key authentication, or connection errors
- Commands become list-form (safer, no shell injection surface)

**Guest agent polling** currently uses a shell pipeline:
```bash
sudo pvesh get /nodes/{node}/qemu/{vm_id}/agent/network-get-interfaces --output-format json 2>/dev/null | jq -r '...'
```
After conversion, this splits into:
1. `run_command(['sudo', 'pvesh', 'get', ..., '--output-format', 'json'])`
2. Parse JSON in Python (replace `jq` dependency with `json.loads()`)

This is strictly better — Python JSON parsing is deterministic and doesn't require `jq` to be installed.

#### 1b. proxmox.py — Remote Actions (lines 251-523) — NO CHANGE

Four action classes remain SSH-based:

| Class | Lines | Why SSH stays |
|-------|-------|---------------|
| `StartVMRemoteAction` | 251-296 | Used by `_run_pve_lifecycle()` on delegated child PVE nodes |
| `WaitForGuestAgentRemoteAction` | 299-361 | Polls guest agent on delegated child PVE nodes |
| `DiscoverVMsAction` | 364-441 | Queries remote PVE API for VM enumeration (destroy path) |
| `DestroyDiscoveredVMsAction` | 444-523 | Stops/destroys VMs on remote PVE nodes (destroy path) |

These already use the correct pattern: `ssh_user = config.automation_user` with conditional sudo.

#### 1c. pve_setup.py — Dead Remote Path Removal

Remove three unreachable `_run_remote()` methods:

| Method | Lines | Size | Why dead |
|--------|-------|------|----------|
| `_EnsurePVEPhase._run_remote()` | 169-193 | 25 lines | `--local` flag always set; remote branch unreachable |
| `_GenerateNodeConfigPhase._run_remote()` | 282-376 | 95 lines | Same — includes hardcoded `root@` scp |
| `_CreateApiTokenPhase._run_remote()` | 493-588 | 96 lines | Same — full remote token pipeline |

Total: ~216 lines removed.

The `_PVESetupPhase` remote branch (lines 206-225) is slightly different — the action it calls (`AnsiblePlaybookAction`) is also used by the local path. Removing the remote branch involves simplifying the run dispatch to always use local mode. The ansible action itself stays.

**Note:** The `_run_remote()` method signatures and their parent class references are also removed, simplifying each phase class to just `_run_local()`.

#### 1d. server_mgmt.py — Enhanced Local Detection

Current detection (line 43):
```python
self._is_local = ssh_host in ('localhost', '127.0.0.1', '::1')
```

Problem: `config.ssh_host` resolves to the machine's real IP (e.g., `198.51.100.61`), not `localhost`. The operator IS local but `_is_local` returns False.

Enhancement — add hostname comparison:
```python
import socket
self._is_local = (
    ssh_host in ('localhost', '127.0.0.1', '::1')
    or ssh_host == socket.gethostname()
    or ssh_host == socket.getfqdn()
)
```

This is strictly additive — existing localhost checks still work, new cases are detected.

### Phase 2: Dead Code Cleanup

#### 2a. config.py — Remove Dead HostConfig Attributes

| Attribute | Line | References in src/ | Action |
|-----------|------|-------------------|--------|
| `node_name` | 47 | 0 | Remove |
| `datastore` | 54 | 0 | Remove |

**Impact:** Both attributes are loaded from YAML but never read by any action, scenario, or operator code. The `datastore` value is consumed via ConfigResolver (which reads `node_config["datastore"]` directly from the YAML dict at line 229), NOT from `HostConfig.datastore`.

Tests that construct HostConfig with these fields will need updating.

#### 2b. config_resolver.py — Remove ssh_user from Tfvars

Line 225: `"ssh_user": node_config.get("ssh_user", defaults.get("ssh_user", "root"))`

Remove this line from the `resolve_inline_vm()` return dict. The tofu `var.ssh_user` that consumed it is also being removed.

**Note:** `HostConfig.ssh_user` (line 51) is NOT removed — it's still used by ansible playbook actions (`AnsiblePlaybookAction` passes it for PVE host SSH access).

#### 2c. file.py — Fix RemoveImageAction Hardcoded Root

Line 27: `user = 'root'` → `user = config.automation_user`

Apply the same conditional sudo pattern used by `DownloadFileAction` (lines 90-92):
```python
user = config.automation_user
sudo = '' if user == 'root' else 'sudo '
```

Then prefix commands with `{sudo}`:
```python
rc, out, err = run_ssh(pve_host, f'{sudo}test -f {image_path} && echo exists', user=user, ...)
rc, out, err = run_ssh(pve_host, f'{sudo}rm -f {image_path}', user=user, ...)
```

#### 2d. tofu variables.tf — Remove var.ssh_user

Lines 20-24: Remove the `ssh_user` variable declaration entirely.

```hcl
# REMOVE:
variable "ssh_user" {
  description = "SSH user for provider connection to PVE host"
  type        = string
  default     = "root"
}
```

No other `.tf` file references `var.ssh_user`. The provider already uses `var.automation_user` at `providers.tf` line 17.

## Code Quality Pass

Every file touched by the structural changes also gets a quality pass: extract repeated patterns, update stale comments, reduce verbosity. Scoped to files we're already modifying — no scope creep into untouched files.

### proxmox.py — DRY Extraction and Tightening

**DRY: Attribute resolution (8x duplication)**

Lines 28-29, 68-69, 113, 157, 207, 263-264, 314-315, 381-382 all repeat:
```python
vm_id = context.get(self.vm_id_attr) or getattr(config, self.vm_id_attr, None)
pve_host = context.get(self.pve_host_attr) or getattr(config, self.pve_host_attr, None)
```

Extract module-level helper:
```python
def _resolve(attr: str, config: HostConfig, context: dict):
    """Resolve attribute from context (preferred) or config."""
    return context.get(attr) or getattr(config, attr, None)
```

**DRY: Missing-config validation (8x duplication)**

Lines 32-37, 72-77, 160-165, 210-215, 266-278, 317-329, 384-389, 472-477 all check `if not vm_id or not pve_host:` with identical error structure.

Extract helper:
```python
def _require(name: str, **attrs) -> Optional[ActionResult]:
    """Return error ActionResult if any attr is falsy, else None."""
    missing = {k: v for k, v in attrs.items() if not v}
    if missing:
        return ActionResult(success=False, message=f"[{name}] Missing: {missing}", ...)
    return None
```

**DRY: Sudo prefix (2x, plus used across file.py and pve_lifecycle.py)**

Lines 394, 487: `sudo = '' if ssh_user == 'root' else 'sudo '`

Extract to `common.py`:
```python
def sudo_prefix(user: str) -> str:
    """Return 'sudo ' for non-root users, empty string for root."""
    return '' if user == 'root' else 'sudo '
```

This is also used in `file.py` (lines 92, 242) and `pve_lifecycle.py` (lines 56-61, 406, 496). Centralizing eliminates the pattern from all files.

**Stale comment: LookupVMIPAction docstring (line 100-102)**

Current: "Used by destructor to find VM IPs when context is not available"
No "destructor" exists in codebase. Update to describe actual use case (destroy path VM discovery).

**Verbose: WaitForProvisionedVMsAction dual dict tracking (lines 217-241)**

Maintains both `context_updates` and `vm_ips` for the same data. Consolidate to single dict; derive backward-compat `vm_ip` key from first entry.

**jq → json.loads():** Already covered in Phase 1a structural changes — guest agent polling replaces shell `jq` pipeline with Python `json.loads()`. This simultaneously removes a runtime dependency and makes parsing deterministic.

### pve_setup.py — Tighten Surviving Code

After removing ~216 lines of dead `_run_remote()` code, tighten what remains:

**DRY: Ansible playbook invocation (2x)**

Lines 121, 154 repeat:
```python
cmd = ['ansible-playbook', '-i', 'inventory/local.yml', playbook, '-e', f'pve_hostname={hostname}']
rc, out, err = run_command(cmd, cwd=ansible_dir, timeout=1200)
```

Extract helper:
```python
def _run_playbook(self, playbook: str, hostname: str, ansible_dir: Path, timeout: int = 1200):
    """Run ansible-playbook locally and return (rc, out, err)."""
```

**DRY: Error truncation (2x)**

Lines 123, 156: `error_msg = err[-500:] if err else out[-500:]`

Extract: `_error_summary(err, out, max_len=500)` or inline as `(err or out)[-500:]`.

**DRY: Token existence check + verify (2x)**

Lines 413-420 and 525-532 repeat identical check→verify→early-return. After removing the remote path, only the local path remains — this duplication disappears naturally.

**Stale comments:**
- Line 52-56: Historical note about Ansible 2.20 reboot behavior. Update to explain current split-phase rationale without the backstory.
- Lines 443-444: "removing old token because we can't retrieve existing value" — this is PVE API fact, keep but tighten to one line.

**Redundant local imports:**
- Lines 655, 672: `import os` inside methods when `os` is already imported at module level.
- Lines 106, 271, 400: `import socket` in three separate methods. Move to module-level import.

**Simplify phase classes:**

After removing `_run_remote()`, each phase class simplifies from a local/remote dispatcher to just the local implementation. The `run()` method can inline the local logic directly instead of dispatching through `_run_local()`.

### config.py — Tighten After Attribute Removal

**DRY: Site defaults loading (2x)**

Lines 98-101 and 159-162 both load site.yaml defaults identically:
```python
site_file = site_config_dir / 'site.yaml'
site_defaults = {}
if site_file.exists():
    site_defaults = _parse_yaml(site_file).get('defaults', {})
```

Extract: `_load_site_defaults(site_config_dir: Path) -> dict`

**Verbose: Walrus chain in `_load_from_host_yaml` (lines 168-176)**

Current reads backward through nested walrus operators. Refactor to sequential assignment:
```python
network = host_config.get('network', {}).get('interfaces', {})
vmbr0 = network.get('vmbr0', {})
if address := vmbr0.get('address'):
    self.ssh_host = address.split('/')[0]
```

**Verbose: `get_api_token()` uses defensive `getattr` (line 206)**

`getattr(self, '_api_token', '')` is unnecessary — `_api_token` is defined in the dataclass. Simplify to `return self._api_token`.

**Stale comments:**
- Lines 49-50: References `envs/test.yaml` which doesn't exist in current site-config schema. Update `inner_vm_id`/`test_vm_id` comments to reflect current usage.
- Lines 61, 65: Issue number references (`#229`, `#203`) — remove, the context is self-evident.

**Dead fields: `inner_vm_id` and `test_vm_id` (lines 49-50)**

These are defined with defaults but should be verified for actual usage. If referenced only by legacy scenarios, flag for future removal (not this sprint — verify first).

### config_resolver.py — Tighten After ssh_user Removal

**DRY: `write_tfvars` / `write_ansible_vars` (lines 334-342, 395-403)**

Both are identical `json.dump()` wrappers with different parameter names. Extract:
```python
def _write_json(self, data: dict, output_path: str) -> None:
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
```

**DRY: Secrets access pattern (3x)**

Lines 92, 180, 230: `self.secrets.get("section", {}).get("key", "")` repeated with different section/key.

Extract:
```python
def _secret(self, section: str, key: str, default: str = "") -> str:
    return self.secrets.get(section, {}).get(key, default)
```

**Verbose: Return-through-variable (line 68)**

```python
result: dict = _parse_yaml(path)
return result
```
Simplify: `return _parse_yaml(path)`

**Stale comments:**
- Line 232: Says "Create → Specify flow" — should say "Create → Config flow" (terminology corrected in v0.48).
- Lines 241-244: RSA-only constraint comment. Replace with brief reference: `# RSA only — see CLAUDE.md bpg/proxmox constraints`

### file.py — Tighten After Root Fix

**DRY: File extension rename (2x, lines 122-129, 286-291)**

Both `DownloadFileAction` and `DownloadGitHubReleaseAction` have identical logic for renaming `.qcow2` → `.img`. Extract:
```python
def _rename_image(self, host, user, sudo, src_path, timeout=30) -> tuple[int, str, str]:
    """Rename .qcow2 to .img on remote host."""
```

**DRY: File existence verification (2x, lines 131-139, 293-301)**

Both run `ls -la` and check rc. Extract:
```python
def _verify_exists(self, host, user, sudo, path, timeout=30) -> bool:
```

**Stale comment: Line 26**

"PVE storage operations require root" — inaccurate after the fix. Update to: "PVE storage paths require sudo for non-root users"

### server_mgmt.py — Minimal Tightening

Small file, minimal issues beyond the `_is_local` enhancement already in Phase 1d. No additional quality items identified.

### Summary: Code Quality Changes by File

| File | DRY Extractions | Stale Comments | Verbose Fixes | Total Items |
|------|----------------|----------------|---------------|-------------|
| proxmox.py | 4 (resolve, require, sudo_prefix, dict consolidation) | 1 | 1 | 6 |
| pve_setup.py | 2 (playbook, error_summary) | 2 | 3 (imports, phase simplification) | 7 |
| config.py | 1 (site_defaults) | 3 | 2 (walrus, getattr) | 6 |
| config_resolver.py | 3 (write_json, secret, ssh_keys) | 2 | 1 | 6 |
| file.py | 2 (rename, verify) | 1 | 0 | 3 |
| server_mgmt.py | 0 | 0 | 0 | 0 |
| **Total** | **12** | **9** | **7** | **28** |

### Scope Boundary

These quality improvements are **limited to files we're already modifying**. Related files that could benefit (executor.py, pve_lifecycle.py) are noted but deferred:

- **executor.py**: Has DRY opportunities (context key management, phase loop extraction, delegate consolidation) but is not structurally changed in this sprint.
- **pve_lifecycle.py**: Has the same `_require_context_attr` pattern (8x) and could use `sudo_prefix()` from common.py, but is not directly modified. The shared `sudo_prefix()` helper in common.py will be available for future cleanup.

## Interface Design

### Changed Interfaces

No public API changes. All modifications are internal implementation details:

- Action `run()` signatures remain `(self, config: HostConfig, context: dict) -> ActionResult`
- ConfigResolver output changes (drops `ssh_user` key) but tofu doesn't consume it
- HostConfig drops two unused attributes — no consumers affected

### Removed Interfaces

| Interface | Consumers | Migration |
|-----------|-----------|-----------|
| `HostConfig.node_name` | None | N/A |
| `HostConfig.datastore` | None | N/A |
| `ConfigResolver.ssh_user` in tfvars | `var.ssh_user` (dead) | Both removed together |

## Integration Points

### Cross-Repo Implications

**tofu** (mechanical change):
- Remove `var.ssh_user` from `envs/generic/variables.tf`
- Must happen AFTER iac-driver stops emitting `ssh_user` in tfvars, otherwise tofu would see an unknown variable error
- In practice, tofu ignores extra variables (HCL `-var-file` silently drops unrecognized keys), so ordering is not strictly required — but removing from both sides simultaneously is cleanest

**All other repos**: No impact. ansible, bootstrap, packer, site-config are unaffected.

### Component Interactions

```
Before:
  operator (homestak@pve-host) → SSH → pve-host → sudo qm start 99900

After:
  operator (homestak@pve-host) → sudo qm start 99900
```

The delegation model is unchanged:
```
operator (homestak@mother) → local sudo qm/pvesh (Phase 1 actions)
                           → SSH to child PVE (Remote actions, unchanged)
                               → child runs pve-setup locally
                               → child provisions leaf VMs
```

### Dependency on run_command()

The local actions currently import `run_ssh` from `src/common.py`. After conversion, they'll import `run_command` instead. Both functions already exist in `common.py` — no new utilities needed.

`run_command()` signature:
```python
def run_command(cmd: list[str], timeout: int = DEFAULT_TIMEOUT,
                cwd: Optional[Path] = None, env: Optional[dict] = None) -> tuple[int, str, str]:
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Guest agent JSON parsing breaks when switching from `jq` to `json.loads()` | Low | High — VMs would fail to get IPs | Test with actual guest agent output format; unit tests with sample data |
| Removing `node_name`/`datastore` breaks tests that construct HostConfig | High | Low — test-only impact | Fix tests as part of implementation |
| `_is_local` hostname detection fails on FQDN mismatch | Low | Low — falls back to SSH (current behavior) | Use both `gethostname()` and `getfqdn()` |
| pve_setup.py remote removal exposes a live call path we didn't identify | Very Low | Medium | Grep all callers; remote mode was disabled in v0.36+ |
| Provider lockfile churn from removing `var.ssh_user` | Low | Low — cosmetic | Run `tofu init` to regenerate if needed |

### Backward Compatibility

- **No breaking changes** for users. The operator runs as `homestak` on the PVE host — this is the only supported execution model since v0.51.
- `HostConfig.ssh_user` remains for ansible playbook invocations (not removed).
- `RemoveImageAction` behavioral change (root → automation_user + sudo) is functionally identical — it still executes commands as root via sudo.

## Alternatives Considered

| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| Convert ALL actions to local (including Remote*) | Maximum simplification | Breaks delegation model — Remote actions run on child PVE nodes via SSH | Delegation is fundamental to tiered orchestration |
| Add `local_mode` flag to each action | Gradual migration | Doubles code paths, harder to test | Binary: action either runs locally or remotely. No mixed case. |
| Remove `ssh_user` from HostConfig entirely | Full cleanup | Ansible playbooks still need it for remote PVE host access | Keep until ansible dependency is also refactored (epic phase 3) |
| Socket-based local detection (compare IPs) | More robust | Over-engineering for current needs | Hostname comparison covers all real-world cases |

## Test Plan

### Existing Test Coverage (Audit)

| Test File | Coverage | Risk | Sprint Impact |
|-----------|----------|------|---------------|
| `test_actions_proxmox.py` | 3 tests (StartVMAction only) | HIGH | Must add tests for converted actions |
| `test_pve_lifecycle.py` | ~15 tests | HIGH | Hardcoded `config.ssh_user = 'root'` fixtures will break |
| `test_config.py` | ~50 tests | LOW | Fixtures referencing `node_name`/`datastore` need updating |
| `test_config_resolver.py` | ~35 tests | MODERATE | Assertions on ssh_user in output must be removed |
| `test_actions_file.py` | ~10 tests | MODERATE | No user parameter verification — add test for automation_user |
| `test_pve_setup.py` | NONE | CRITICAL | No test file exists — not adding one (removing dead code doesn't need new tests) |
| `test_server_mgmt.py` | ~15 tests (via executor tests) | LOW | `_is_local` enhancement needs unit test |

### New Tests Required

**Phase 1:**
1. `test_actions_proxmox.py` — Add tests for:
   - `StartVMAction` using `run_command()` (update existing)
   - `WaitForGuestAgentAction` JSON parsing (new — mock `run_command` output)
   - `LookupVMIPAction` using `run_command()` (new)
   - `StartProvisionedVMsAction` multi-VM loop (new)
   - `WaitForProvisionedVMsAction` multi-VM polling (new)
2. `test_server_mgmt.py` — Add test for hostname-based `_is_local` detection

**Phase 2:**
3. `test_config.py` — Update HostConfig construction fixtures (remove `node_name`, `datastore`)
4. `test_config_resolver.py` — Remove `ssh_user` assertions from tfvars output tests
5. `test_actions_file.py` — Add test verifying `RemoveImageAction` uses `config.automation_user`

### Integration Validation

**Scenario 1:** `./run.sh manifest test -M n1-push -H mother`
- Validates: Local PVE commands (`StartVMAction`, `WaitForGuestAgentAction`) work via `run_command()`
- Duration: ~2 min

**Scenario 2:** `./run.sh manifest test -M n2-tiered -H mother`
- Validates: Delegation model still works after removing pve_setup.py remote paths; remote actions (`StartVMRemoteAction`, etc.) unchanged
- Duration: ~9 min

**Execution:**
```bash
ssh jderose@mother 'sudo -u homestak bash -c "cd ~/lib/iac-driver && git checkout sprint/operator-local-exec && git pull && ./run.sh manifest test -M n1-push -H mother --verbose"'
```

### Prerequisites

| Prerequisite | Status | Notes |
|--------------|--------|-------|
| SSH access to mother | Available | Via jderose user |
| API token configured | Available | In secrets.yaml |
| Packer images published | Available | debian-12, pve-9 on mother |
| Sprint branch exists | Done | sprint/operator-local-exec |

## Implementation Sequence

Quality work is interleaved with structural changes per-file — tighten each file as we modify it, not as a separate pass.

```
Phase 1 (iac-driver#267):
  1. Add sudo_prefix() to common.py (shared helper)
  2. Convert 5 local actions in proxmox.py:
     - run_ssh → run_command conversion
     - Extract _resolve() and _require() helpers
     - Replace jq pipeline with json.loads()
     - Consolidate WaitForProvisionedVMsAction dual dicts
     - Fix stale LookupVMIPAction docstring
  3. Update/add unit tests for converted actions
  4. Remove _run_remote() from pve_setup.py + tighten survivors:
     - Delete 3 dead methods (~216 lines)
     - Simplify phase classes (inline _run_local)
     - Extract _run_playbook() and _error_summary() helpers
     - Fix redundant imports (os, socket → module-level)
     - Update stale comments
  5. Enhance server_mgmt.py _is_local detection
  6. Run make test + make lint

Phase 2 (iac-driver#275 phases 1-2):
  7. config.py: remove node_name/datastore + tighten:
     - Extract _load_site_defaults() helper
     - Simplify walrus chain, defensive getattr
     - Update stale comments (envs/test.yaml ref, issue numbers)
  8. config_resolver.py: remove ssh_user from tfvars + tighten:
     - Extract _write_json() and _secret() helpers
     - Fix return-through-variable
     - Update stale comments (Specify → Config, RSA ref)
  9. file.py: fix RemoveImageAction + tighten:
     - automation_user + sudo pattern
     - Extract _rename_image() and _verify_exists() helpers
     - Update stale comment
  10. Update affected test fixtures across all test files
  11. Run make test + make lint

Phase 2 (tofu):
  12. Remove var.ssh_user from variables.tf
  13. Run tofu fmt check

Integration:
  14. Deploy to mother, run n1-push test
  15. Run n2-tiered test
```

## Open Questions

None — all questions were resolved during pre-design analysis:
- SSH user convergence: Not forced now; `ssh_user` stays in HostConfig for ansible
- Orchestrator reuse: Not pursued; duplication is minimal
- PVE lifecycle phases 8-9 redundancy: Deferred to epic phase 3
- pve_setup.py remote path: Confirmed dead; safe to remove
