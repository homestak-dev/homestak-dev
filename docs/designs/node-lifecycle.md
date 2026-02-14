# Node Lifecycle

**Epic:** [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125), [iac-driver#140](https://github.com/homestak-dev/iac-driver/issues/140)
**Status:** Active
**Date:** 2026-02-02
**Related:** [node-orchestration.md](node-orchestration.md)

**Reading order:** Start here for single-node lifecycle concepts, then see [node-orchestration.md](node-orchestration.md) for multi-node patterns and coordination.

## Overview

This document captures the architectural vision for homestak's node lifecycle model. It extends the existing push-based orchestration with a pull-based discovery and convergence model. Both models are first-class approaches — the choice depends on user context, not architectural preference.

## The Four Lifecycle Phases

Every node progresses through the same four phases, regardless of execution model:

```
create → config → run → destroy
   │        │       │       │
   │        │       │       └── Graceful shutdown, cleanup
   │        │       └── Runtime operations, maintenance, drift detection
   │        └── Apply configuration to reach platform ready
   └── Allocate resources, boot node
```

| Phase | Purpose | Activities |
|-------|---------|------------|
| **create** | Provision | Allocate resources, boot node, inject identity + auth token |
| **config** | Configure | Apply configuration (push: SSH/Ansible; pull: fetch spec + converge) |
| **run** | Runtime | Workloads running, health checks, drift detection, updates, patching |
| **destroy** | Teardown | Graceful shutdown, cleanup |

### Phase Mapping (4 vs 6)

The original 6-phase model was consolidated to 4 phases for simplicity:

| New (4 phases) | Old (6 phases) | Rationale |
|----------------|----------------|-----------|
| create | Create | Unchanged |
| config | Specify + Apply | Combined: spec fetch and application are one logical unit |
| run | Operate + Sustain | Combined: normal runtime and maintenance are continuous |
| destroy | Destroy | Unchanged |

### The "Platform Ready" Boundary

"Becoming" (create through config) stops at **Platform Ready** — the machine has everything needed to fulfill its role, but isn't yet doing the role's work.

| In Scope (Becoming) | Out of Scope (Future) |
|---------------------|----------------------|
| Hostname, domain | Application deployment |
| Network (IP, gateway, DNS) | Database initialization |
| Users, SSH keys, sudo | Application config |
| Packages (platform) | Data migration |
| Services (platform) | Runtime secrets |
| System configuration | Application secrets |
| Security posture | |

**Platform Ready** = a hypervisor with PVE installed but no VMs, or a web server with nginx installed but no sites.

## Unified Node Model

All compute entities are "nodes" with a common lifecycle:

```
node (abstract)
├── type: pve     → Proxmox VE hypervisor
├── type: vm      → KVM virtual machine
├── type: ct      → LXC container
└── type: k3s     → Kubernetes node (future)
```

### Parent-Child Topology

```
father (pve, physical)
├── dev1 (vm, parent: father)
├── dev2 (ct, parent: father)
└── nested-pve (vm, parent: father)
    └── test1 (vm, parent: nested-pve)
```

Nodes can spawn child nodes, creating tiered infrastructure topologies.

## Execution Models

Three execution models are available. All are first-class approaches — choose based on your context.

### Push Model

The driver holds orchestration logic and actively configures target nodes via SSH.

```
Driver                           Target
──────                           ──────
1. tofu apply (provision target)
2. SSH → ansible-playbook
3. SSH → commands as needed
                                 - Receives configuration
                                 - Executes as instructed
                                 - No autonomous action
```

**Strengths:** Simple mental model, immediate feedback, easy to debug, no daemon required on targets.

**Best for:** Operator at keyboard, initial setup, debugging, small deployments.

### Hybrid Model

Driver initiates but doesn't micromanage; target nodes have full agency once triggered.

```
Driver                           Target
──────                           ──────
1. tofu apply (provision target)
2. SSH → "homestak scenario ..."
        │
        └── HANDOFF
                                 3. Has full homestak installation
                                 4. Executes remaining work independently
                                 5. Returns JSON result to driver
```

**Strengths:** Combines explicit triggering with autonomous execution. Driver doesn't need continuous SSH access.

**Best for:** Tiered deployments where parent node drives child node creation.

### Pull Model

Nodes discover their spec and converge autonomously.

```
Driver                           Target
──────                           ──────
1. Start server
2. tofu apply (inject HOMESTAK_TOKEN via cloud-init)
                                 3. Boot with provisioning token
                                 4. GET /spec/{hostname}
   ◀─────────────────────────────┤   Authorization: Bearer <token>
   verify HMAC, extract spec FK  │
   ─────────────────────────────▶
   200 OK + resolved spec        │
                                 5. Apply spec locally
                                 6. PLATFORM READY
```

**Note:** The provisioning token is an HMAC-signed artifact minted by the operator at create time. It encodes the spec FK (`s` claim) and node identity (`n` claim), replacing the previous `HOMESTAK_IDENTITY` + `HOMESTAK_AUTH_TOKEN` env vars. See [provisioning-token.md](provisioning-token.md) for full design.

**Strengths:** Autonomous recovery, scales to many nodes, works across network boundaries (no SSH needed), continuous convergence.

**Best for:** Remote sites, managed services, large deployments, autonomous operation.

### Execution Model Comparison

|  | Push | Hybrid | Pull |
|--|------|--------|------|
| SSH required | Yes | Initial only | No |
| Spec server required | No | No | Yes |
| Autonomous recovery | No | Partial | Yes |
| Immediate feedback | Yes | Partial | No |
| Scales to 100+ nodes | Poorly | Well | Well |
| Debugging ease | Easy | Medium | Hard |

## Terminology

This document uses precise terminology to distinguish three orthogonal relationships:

| Relationship | Describes | Terms |
|--------------|-----------|-------|
| **Execution role** | Who runs the scenario | **driver** (runs iac-driver), **target** (receives) |
| **Lifecycle** | Create/destroy dependency | **parent node**, **child node** |
| **Infrastructure** | Virtualization layer | **host** (PVE), **guest** (VM/CT) |

These roles often overlap. When father creates nested-pve:
- father is driver, host, AND parent node
- nested-pve is target, guest, AND child node

When nested-pve creates test1 (inside nested-pve):
- nested-pve becomes driver, host, parent node
- test1 is target, guest, child node

### Term Reference

| Term | Directory | Meaning |
|------|-----------|---------|
| **Node** | manifest `nodes[]` | Compute entity (VM, CT, PVE host, k3s node) |
| **Spec** | `specs/` | Specification — what a node should become |
| **Def** | `defs/` | Schema definition — structure of specs/nodes |
| **Posture** | `postures/` | Security configuration (dev, stage, prod, local) |
| **Preset** | `presets/` | Size preset (vm-small, vm-large, etc.) |

## Key Principles

1. **Multiple execution models** — Push, hybrid, and pull are all valid approaches. Choose based on context, not architectural dogma.

2. **Platform Ready boundary** — "Becoming" stops at platform readiness, not application deployment.

3. **Clean sheet architecture** — New lifecycle layer alongside existing code, extracting proven primitives rather than retrofitting old assumptions.

4. **Explicit/flat first** — Start with explicit specs, graduate to roles/capabilities when patterns emerge.

5. **Unified nodes** — VMs, CTs, PVE hosts, and k3s nodes share the same lifecycle model.

## Auth Model

Authentication for the config phase (pull model) varies by posture:

| Posture | Auth Method | Token Source | Description |
|---------|-------------|--------------|-------------|
| dev | `network` | none | Trust network boundary |
| local | `network` | none | On-box execution |
| stage | `site_token` | `secrets.auth.site_token` | Shared site-wide token |
| prod | `node_token` | `secrets.auth.node_tokens.{name}` | Per-node unique token |

### Auth Flow

```
Request arrives
    │
    ▼
Load spec for {identity}
    │
    ▼
Get posture from spec.access.posture (default: "dev")
    │
    ▼
Load posture → get auth.method
    │
    ├── network → Trust (no token required)
    │
    ├── site_token → Check Authorization header
    │                against secrets.auth.site_token
    │
    └── node_token → Check Authorization header
                     against secrets.auth.node_tokens.{identity}
```

## site-config Structure

Lifecycle entities are at the top level of site-config (consolidated from former `v2/` subdirectory):

```
site-config/
├── secrets.yaml              # Shared (site-wide)
├── defs/                     # Schema definitions
│   ├── spec.schema.json
│   ├── manifest.schema.json
│   └── posture.schema.json
├── specs/                    # Node specifications (what to become)
│   ├── pve.yaml
│   └── base.yaml
├── postures/                 # Security postures with auth model
│   ├── dev.yaml
│   ├── stage.yaml
│   ├── prod.yaml
│   └── local.yaml
├── presets/                  # Size presets (vm- prefix)
│   ├── vm-xsmall.yaml
│   ├── vm-small.yaml
│   ├── vm-medium.yaml
│   ├── vm-large.yaml
│   └── vm-xlarge.yaml
└── (nodes defined inline in manifests)
```

### Lifecycle Coverage

| Directory | Phase | Purpose |
|-----------|-------|---------|
| manifest `nodes[]` + `presets/` | create | Infrastructure provisioning |
| `specs/` + `postures/` | config | What to become + how to secure |

## Spec Schema (v1)

Specifications define "what a node should become":

```yaml
schema_version: 1

identity:
  hostname: pve-01
  domain: homestak.local

network:
  ip: 198.51.100.100
  gateway: 198.51.100.1
  dns: [198.51.100.1, 1.1.1.1]

access:
  posture: dev               # FK to postures/
  users:
    - name: homestak
      sudo: true
      ssh_keys:
        - ssh_keys.jderose   # FK to secrets.yaml

platform:
  packages:
    - proxmox-ve
    - htop
  services:
    enable: [pveproxy, pvedaemon]
    disable: [rpcbind]

config:                      # Type-specific configuration
  pve:
    remove_subscription_nag: true

run:
  trigger: schedule
  interval: 1h
```

### FK Resolution

| Reference | Resolves To |
|-----------|-------------|
| `access.posture: dev` | `postures/dev.yaml` |
| `ssh_keys.jderose` | `secrets.yaml → ssh_keys.jderose` |

## Node Schema (v1)

Node templates define infrastructure for compute nodes:

```yaml
type: vm
spec: pve                    # FK to specs/
image: debian-13-pve
preset: vm-large             # FK to presets/
disk: 64                     # Override preset
parent: father               # Parent node (for VMs)
```

### Type-Specific Fields

| Field | vm | ct | pve |
|-------|----|----|-----|
| `image` | Required | - | - |
| `template` | - | Required | - |
| `unprivileged` | - | Optional | - |
| `hardware` | - | - | Optional |
| `access.api` | - | - | Optional |

## CLI Pattern

**Driver CLI** (`./run.sh` — iac-driver, verb-based subcommands):

```bash
./run.sh server start                       # Start server (daemon)
./run.sh server start --foreground          # Start server (foreground, dev)
./run.sh server stop                        # Stop server
./run.sh server status                      # Check server health
./run.sh create -M <manifest> -H <host>     # Create nodes per manifest
./run.sh destroy -M <manifest> -H <host>    # Destroy nodes per manifest
./run.sh test -M <manifest> -H <host>       # Roundtrip validation
./run.sh config [--spec /path/to/spec.yaml]  # Apply spec locally (v0.48+)
```

**Target CLI** (`homestak` — bootstrap, runs on target nodes):

```bash
homestak spec get                 # Fetch spec from server (pull model)
```

**Developer CLI** (site-config, runs in workspace):

```bash
cd site-config && make validate                    # Validate YAML + schemas
cd site-config && ./scripts/validate-schemas.sh    # Schema validation only
```

## Scope & Relationship

This document describes the lifecycle phases for a **single node**. For multi-node orchestration, see [node-orchestration.md](node-orchestration.md).

| Concept | Defined In |
|---------|------------|
| Lifecycle phases (create, config, run, destroy) | This document |
| Spec schema | This document |
| Auth model for config phase | This document |
| Phase interface contracts (inputs/outputs) | [phase-interfaces.md](phase-interfaces.md) |
| Topology patterns (flat, tiered, mesh, hub-spoke, federated) | node-orchestration.md |
| Execution models (detailed comparison) | node-orchestration.md |
| Manifest schema | node-orchestration.md |
| Multi-node coordination | node-orchestration.md |

## Implementation Approach

### Clean Sheet with Extracted Primitives

The current architecture has embedded assumptions that may conflict with the lifecycle model:

| Current Assumption | Lifecycle Model Consideration |
|-------------------|------------------------------|
| Scenario knows all phases at definition time | Pull model: phases emerge from discovered spec |
| Driver maintains context dict | Pull model: context is distributed across autonomous nodes |
| Actions execute in driver's process | Pull model: actions execute wherever the node lives |
| One-shot execution model | Pull model: continuous convergence loop |

These considerations apply primarily to pull execution. Push and hybrid models continue to work with existing assumptions.

### Implementation Structure

Both push and pull execution models are implemented within the existing `src/` tree:

```
iac-driver/
├── src/
│   ├── scenarios/          # Standalone workflows (pve-setup, *-vm-roundtrip)
│   ├── actions/            # Reusable primitives (tofu, ansible, SSH, etc.)
│   ├── manifest_opr/       # Operator engine (graph walker, verb CLI)
│   ├── server/             # Server daemon (specs + repos)
│   ├── resolver/           # FK resolution (spec, config)
│   ├── config_apply.py     # Config phase: spec → ansible vars → apply
│   └── cli.py              # Verb commands (create, destroy, test, config, serve)
│
└── run.sh                  # Entry point
```

## Implementation Status

Implementation is tracked in [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125) (Node Lifecycle Architecture epic). See the epic's release plan and acceptance criteria for current progress.

## Related Documents

- [server-daemon.md](server-daemon.md) — Server daemon design
- [spec-client.md](spec-client.md) — Client design
- [phase-interfaces.md](phase-interfaces.md) — Phase interface contracts (run/destroy phase details)
- [node-orchestration.md](node-orchestration.md) — Multi-node orchestration
- [requirements-catalog.md](requirements-catalog.md) — Structured requirements with IDs
- [test-strategy.md](test-strategy.md) — Test hierarchy and system test catalog
- [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125) — Architecture evolution epic (detailed discussion)

## Changelog

| Date | Change |
|------|--------|
| 2026-02-08 | Terminology: controller → server (aligns with server-daemon.md rename) |
| 2026-02-07 | Align with updated epics: pull model step 5 no longer "(future)"; replace aspirational `lifecycle/` directory with actual implementation structure |
| 2026-02-07 | Update paths: v2/ consolidated to top-level (specs/, postures/, presets/, defs/) per site-config#53 |
| 2026-02-07 | Status → Active; replace Implementation Status section with epic reference (avoid staleness) |
| 2026-02-05 | Update CLI Pattern section: distinguish driver CLI (`./run.sh`) from target CLI (`homestak`); remove premature `homestak config` porcelain reference |
| 2026-02-03 | Rename to node-lifecycle.md; normalize execution models as co-equal (push/hybrid/pull all first-class); add terminology framework; remove "In Progress" section |
| 2026-02-03 | Rename to node-lifecycle-architecture.md; consolidate to 4 phases (create, config, run, destroy); add #140 epic, scope & relationship section |
| 2026-02-02 | Update for v0.45: create → config integration complete |
| 2026-02-02 | Move release plan to epic (avoid staleness) |
| 2026-02-02 | Initial document extracted from iac-driver#125 |
