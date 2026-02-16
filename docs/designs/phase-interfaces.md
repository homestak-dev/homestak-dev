# Phase Interface Contracts

**Sprint:** 0 (Lifecycle Decomposition)
**Issue:** [iac-driver#141](https://github.com/homestak-dev/iac-driver/issues/141)
**Related:** [node-lifecycle.md](node-lifecycle.md), [node-orchestration.md](node-orchestration.md)
**Status:** Active
**Date:** 2026-02-03

## Overview

Each lifecycle phase has inputs it requires and outputs it must produce for downstream phases. This document defines these "interface contracts" and resolves open architectural questions for the run and destroy phases.

## Phase Summary

```
create → config → run → destroy
   │        │       │       │
   │        │       │       └── Outputs: Cleanup confirmation
   │        │       └── Outputs: Runtime state, health
   │        └── Outputs: Platform ready state
   └── Outputs: Identity, connectivity, auth token
```

---

## Create → Config Interface

The create phase provisions infrastructure and injects the information needed for config.

| Output from Create | Type | Used by Config |
|-------------------|------|----------------|
| Provisioning token | Required (pull) | Spec lookup + authorization (HMAC-signed, contains spec FK + identity) |
| Spec server URL | Required (pull) | Where to fetch spec |
| Network connectivity | Required | HTTP/HTTPS to spec server |
| Automation user | Required | User to run config commands |
| SSH keys | Required | Access for push execution |

### Injection Mechanism

Create injects these values via cloud-init to `/etc/profile.d/homestak.sh`:

```bash
export HOMESTAK_SERVER=https://father:44443
export HOMESTAK_TOKEN=<provisioning-token>
```

The provisioning token is an HMAC-signed artifact minted by the operator at create time. It encodes the spec FK (`s` claim) and node identity (`n` claim), replacing the previous `HOMESTAK_IDENTITY` and `HOMESTAK_AUTH_TOKEN` env vars. See [provisioning-token.md](provisioning-token.md) for full design.

### Validation

Config phase validates these inputs:
- `HOMESTAK_TOKEN` is set and well-formed (pull mode)
- `HOMESTAK_SERVER` is reachable (pull mode)
- SSH access works (push mode)

---

## Config → Run Interface

The config phase brings the node to "platform ready" state. The run phase uses this baseline for ongoing operations.

| Output from Config | Type | Used by Run |
|-------------------|------|-------------|
| Platform ready state | Required | Baseline for operations |
| Spec server URL | Optional | Drift detection (re-fetch spec) |
| Convergence schedule | Optional | When to check for updates |
| Service state | Required | Expected running services |
| Health check endpoints | Optional | Monitoring targets |

### Platform Ready Definition

"Platform ready" means the node has:
- All packages from spec installed
- All services from spec enabled/started
- All users from spec created
- Network configured per spec
- Security posture applied

The node can now fulfill its role but isn't yet doing the role's work (no applications deployed).

### Convergence Handoff

If the spec defines `run.trigger` and `run.interval`, config phase records this in local state:

```yaml
# /usr/local/etc/homestak/state/convergence.yaml
spec_server: https://father:44443
trigger: schedule
interval: 1h
last_check: 2026-02-03T10:00:00Z
```

Run phase reads this to determine its operational mode.

---

## Config → Destroy Interface

Config phase doesn't pass state directly to destroy. Destroy phase works from create's state.

| Output from Config | Used by Destroy |
|-------------------|-----------------|
| (none directly) | Config is stateless from destroy's perspective |

**Rationale:** The config phase converges to a spec. Destroy doesn't need to know what was configured—it only needs the infrastructure identity from create phase to remove the resource.

---

## Create → Destroy Interface

The create phase produces the infrastructure identity that destroy needs to remove.

| Output from Create | Type | Used by Destroy |
|-------------------|------|-----------------|
| VM ID | Required | Resource to delete |
| Parent node | Required | Where to execute destroy |
| Node name | Required | Tofu state lookup |
| Dependent resources | Optional | DNS records, storage, etc. |

### State Location

Create phase stores state in `.states/{manifest}-{node}/terraform.tfstate`. Destroy reads this state to identify resources.

### Discovery Pattern

When state is unavailable, destroy can discover resources:
1. Query PVE API for VMs matching name pattern
2. Attempt destroy of discovered resources
3. Report success/failure

This enables recovery from partial failures where state is lost.

---

## Run → Destroy Interface

The run phase may have active work that destroy should handle gracefully.

| Output from Run | Type | Used by Destroy |
|-----------------|------|-----------------|
| Active connections | Optional | Graceful drain |
| Scheduled jobs | Optional | Cancel or complete |
| Cluster membership | Optional | Remove from quorum |
| Maintenance mode | Optional | Prevent new work |

### Graceful Shutdown Sequence

1. **Enter maintenance mode** - Stop accepting new work
2. **Drain connections** - Wait for active requests to complete (with timeout)
3. **Cancel scheduled jobs** - Or wait for in-progress jobs
4. **Leave cluster** - If part of a cluster, remove self from quorum
5. **Signal ready for destroy** - Run phase exits cleanly

### Timeout Behavior

| Operation | Default Timeout | On Timeout |
|-----------|-----------------|------------|
| Connection drain | 30s | Force close |
| Job completion | 60s | Cancel remaining |
| Cluster leave | 30s | Force remove |
| Total graceful | 120s | Proceed to destroy |

---

## State Requirements

| Phase | State Location | Persistence | Notes |
|-------|---------------|-------------|-------|
| **Create** | `.states/{manifest}-{node}/terraform.tfstate` | Required | Tofu state, needed for destroy |
| **Config** | `/usr/local/etc/homestak/state/spec.yaml` | Optional | For drift detection in run |
| **Run** | Application-specific | Application-specific | Varies by workload |
| **Destroy** | Reads Create state | Cleans up | Removes state on success |

### State Isolation

Each manifest-node combination has isolated state:

```
.states/
├── nested-test-root-pve/
│   ├── data/             # TF_DATA_DIR (plugins, modules)
│   └── terraform.tfstate # Tofu state
└── nested-test-edge/
    ├── data/
    └── terraform.tfstate
```

---

## Resolved Architectural Questions

### Q1: Manifest Execution State

**Question:** Where does "manifest X is 60% deployed" live?

**Resolution:** In the orchestration layer, not in individual nodes.

**Implementation:**
- Manifest executor maintains in-memory state during execution
- Progress written to `.states/{manifest}/execution.json` for recovery
- Each node's create/config state is independent
- Manifest state tracks which nodes are complete, in-progress, failed

```json
// .states/nested-test/execution.json
{
  "manifest": "nested-test",
  "started": "2026-02-03T10:00:00Z",
  "status": "in_progress",
  "nodes": {
    "root-pve": {"status": "complete", "vmid": 99011},
    "edge": {"status": "in_progress", "phase": "config"}
  }
}
```

### Q2: Partial Failure Rollback

**Question:** What's the strategy for multi-node partial failure?

**Resolution:** Configurable via `--on-error` flag.

**Behavior:**

| Mode | Description |
|------|-------------|
| `stop` (default) | Stop on first failure, leave completed nodes running |
| `rollback` | On failure, destroy completed nodes in reverse order |
| `continue` | Log failures, continue with independent nodes |

**Rationale:**
- `stop` is safest default (don't make partial state worse)
- `rollback` is opt-in (may not always be desired)
- `continue` for resilient deployments with independent nodes

**Implementation:**
```bash
# Default: stop on failure
./run.sh create -M nested-test -H father

# Explicit stop (same as default)
./run.sh create -M nested-test -H father --on-error=stop

# Rollback on failure
./run.sh create -M nested-test -H father --on-error=rollback

# Continue despite failures
./run.sh create -M nested-test -H father --on-error=continue
```

### Q3: Run Phase Triggers

**Question:** Schedule, webhook, git push, manual?

**Resolution:** All of the above, specified in spec.

**Trigger Types:**

| Trigger | How It Works | Use Case |
|---------|--------------|----------|
| `schedule` | Cron-like interval | Periodic convergence |
| `webhook` | HTTP endpoint accepts POST | External trigger (CI/CD) |
| `git` | Watch repo, converge on change | GitOps workflow |
| `manual` | CLI command only | Operator control |

**Spec Definition:**
```yaml
run:
  trigger: schedule
  interval: 1h

# Or for webhook
run:
  trigger: webhook
  port: 8080
  path: /converge

# Or for git
run:
  trigger: git
  repo: https://github.com/org/config.git
  branch: main
  poll_interval: 5m

# Or for manual
run:
  trigger: manual
```

**Default:** `manual` (no autonomous convergence)

### Q4: Run Phase Daemon vs One-Shot

**Question:** Should run phase be a long-running daemon or one-shot execution?

**Resolution:** Both, depending on trigger type.

| Trigger | Execution Model |
|---------|-----------------|
| `manual` | One-shot |
| `schedule` | Daemon (or systemd timer) |
| `webhook` | Daemon (HTTP server) |
| `git` | Daemon (polling loop) |

**Implementation:**
- `homestak run --once` - One-shot convergence check
- `homestak run --daemon` - Long-running with trigger handling
- Daemon installs as systemd service when `run.trigger != manual`

### Q5: Destroy Phase Self-Terminate vs External

**Question:** Can a node destroy itself?

**Resolution:** Nodes can self-terminate but require external cleanup.

**Two-Part Destroy:**
1. **Graceful shutdown** (node executes): Stop services, drain, leave cluster
2. **Resource cleanup** (parent executes): Delete VM, reclaim storage

**Implementation:**
```python
# For push execution
destroy_phases = [
    ('graceful_shutdown', SSHCommandAction(...), 'Graceful shutdown'),
    ('delete_vm', TofuDestroyAction(...), 'Delete VM'),
]

# For pull execution (node-initiated)
# Node signals "ready for deletion" to parent
# Parent then executes TofuDestroyAction
```

### Q6: Cross-Phase Communication

**Question:** How do phases communicate beyond explicit outputs?

**Resolution:** Via the spec and local state, not direct communication.

**Pattern:**
1. Create injects identity and spec server URL
2. Config fetches spec, persists to state
3. Run reads state, operates based on spec
4. Destroy reads create state (VM ID), ignores config/run state

**No hidden channels:** All cross-phase data flows through:
- Cloud-init injection (create → config)
- Spec (config → run)
- Tofu state (create → destroy)

---

## Interface Validation

Each phase should validate its inputs before proceeding.

### Create Phase Validation

| Check | Failure Action |
|-------|----------------|
| Parent host reachable | Error: "Cannot reach parent host" |
| API token valid | Error: "Invalid API token" |
| Image exists | Error: "Image not found" |
| Resources available | Error: "Insufficient resources" |

### Config Phase Validation (Pull)

| Check | Failure Action |
|-------|----------------|
| Token set | Error: "HOMESTAK_TOKEN not set" |
| Spec server reachable | Error: "Cannot reach spec server" |
| Spec found | Error: "Spec not found for identity" |
| Auth valid | Error: "Authentication failed" |

### Config Phase Validation (Push)

| Check | Failure Action |
|-------|----------------|
| SSH access works | Error: "Cannot SSH to target" |
| Spec resolvable | Error: "Cannot resolve spec" |
| Target OS compatible | Error: "Unsupported OS" |

### Run Phase Validation

| Check | Failure Action |
|-------|----------------|
| Platform ready | Error: "Node not in platform ready state" |
| Spec available | Warning: "No spec, skipping drift check" |
| Trigger configured | Info: "No trigger, running once" |

### Destroy Phase Validation

| Check | Failure Action |
|-------|----------------|
| State exists | Warning: "No state, attempting discovery" |
| Resources identified | Error: "Cannot identify resources to destroy" |
| Parent reachable | Error: "Cannot reach parent host" |

---

## Error Codes

Consistent error codes across phases for programmatic handling.

| Code | Phase | Meaning |
|------|-------|---------|
| E001 | Create | Parent unreachable |
| E002 | Create | Invalid API token |
| E003 | Create | Image not found |
| E004 | Create | Insufficient resources |
| E101 | Config | Identity not set |
| E102 | Config | Spec server unreachable |
| E103 | Config | Spec not found |
| E104 | Config | Authentication failed |
| E105 | Config | Schema validation failed |
| E201 | Run | Not platform ready |
| E202 | Run | Convergence failed |
| E301 | Destroy | State not found |
| E302 | Destroy | Resource discovery failed |
| E303 | Destroy | Parent unreachable |
| E304 | Destroy | Graceful shutdown timeout |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-03 | Initial document with resolved architectural questions |
