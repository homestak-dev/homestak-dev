# Node Lifecycle

**Epic:** [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125), [iac-driver#140](https://github.com/homestak-dev/iac-driver/issues/140)
**Status:** Active (v0.45 complete — create → config integration)
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
1. ./run.sh serve (controller daemon)
2. tofu apply (inject identity + endpoint)
                                 3. Boot with identity
                                 4. homestak spec get
   ◀─────────────────────────────┤
   GET /spec/{identity}          │
   ─────────────────────────────▶
   200 OK + spec                 │
                                 5. Apply spec locally (future)
                                 6. PLATFORM READY
```

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
| **Spec** | `v2/specs/` | Specification — what a node should become |
| **Def** | `v2/defs/` | Schema definition — structure of specs/nodes |
| **Posture** | `v2/postures/` | Security configuration (dev, stage, prod, local) |
| **Preset** | `v2/presets/` | Size preset (vm-small, vm-large, etc.) |

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

## site-config v2 Structure

The v2 directory is self-contained, enabling independent evolution:

```
site-config/
├── v1 (current, unchanged)
├── secrets.yaml              # Shared (site-wide)
└── v2/
    ├── defs/                 # Schema definitions
    │   ├── spec.schema.json
    │   ├── manifest.schema.json
    │   └── posture.schema.json
    ├── specs/                # Node specifications (what to become)
    │   ├── pve.yaml
    │   └── base.yaml
    ├── postures/             # Security postures with auth model
    │   ├── dev.yaml
    │   ├── stage.yaml
    │   ├── prod.yaml
    │   └── local.yaml
    ├── presets/              # Size presets (vm- prefix)
    │   ├── vm-xsmall.yaml
    │   ├── vm-small.yaml
    │   ├── vm-medium.yaml
    │   ├── vm-large.yaml
    │   └── vm-xlarge.yaml
    └── (nodes defined inline in manifests, v2/nodes/ retired)
```

### Lifecycle Coverage

| Directory | Phase | Purpose |
|-----------|-------|---------|
| manifest `nodes[]` + `v2/presets/` | create | Infrastructure provisioning |
| `v2/specs/` + `v2/postures/` | config | What to become + how to secure |

## Spec Schema (v1)

Specifications define "what a node should become":

```yaml
schema_version: 1

identity:
  hostname: pve-01
  domain: homestak.local

network:
  ip: 10.0.12.100
  gateway: 10.0.12.1
  dns: [10.0.12.1, 1.1.1.1]

access:
  posture: dev               # FK to v2/postures/
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
| `access.posture: dev` | `v2/postures/dev.yaml` |
| `ssh_keys.jderose` | `secrets.yaml → ssh_keys.jderose` |

## Node Schema (v1)

Node templates define infrastructure for compute nodes:

```yaml
type: vm
spec: pve                    # FK to v2/specs/
image: debian-13-pve
preset: vm-large             # FK to v2/presets/
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
./run.sh serve                              # Start controller daemon
./run.sh create -M <manifest> -H <host>     # Create nodes per manifest
./run.sh destroy -M <manifest> -H <host>    # Destroy nodes per manifest
./run.sh test -M <manifest> -H <host>       # Roundtrip validation
./run.sh config -M <manifest> -H <host>     # Config phase (future)
```

**Target CLI** (`homestak` — bootstrap, runs on target nodes):

```bash
homestak spec validate <path>     # Validate spec against schema
homestak spec get                 # Fetch spec from server (pull model)
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

### Coexistence Strategy

Both architectures coexist during development:

```
iac-driver/
├── src/                    # Current architecture (push + hybrid)
│   ├── scenarios/
│   └── actions/
│
├── lifecycle/              # New architecture (pull) - future
│   ├── core/
│   │   ├── create.py
│   │   ├── config.py
│   │   └── run.py
│   └── primitives/         # Extracted from src/actions/
│
└── run.sh                  # Entry point (routes appropriately)
```

## Implementation Status

The architecture is being implemented incrementally across multiple releases.

### Completed

| Release | Phase | Deliverables |
|---------|-------|--------------|
| v0.43 | Schema Foundation | V2 directory structure, JSON schemas for specs/nodes/postures |
| v0.44 | Config Infrastructure | Spec server, `homestak spec get` client, auth model |
| v0.45 | create → config | Cloud-init integration, auth token injection, `spec-vm-push-roundtrip` scenario |

### v0.45 Details (create → config)

**Components:**
- **tofu**: Cloud-init injects `HOMESTAK_SPEC_SERVER`, `HOMESTAK_IDENTITY`, `HOMESTAK_AUTH_TOKEN` to `/etc/profile.d/homestak.sh`
- **iac-driver**: ConfigResolver outputs `spec_server` and per-VM `auth_token` based on posture
- **bootstrap**: First-boot spec fetch in cloud-init runcmd (idempotent)
- **site-config**: `defaults.spec_server` in site.yaml

**Validation:**
```bash
./run.sh --scenario spec-vm-push-roundtrip --host father
```

## Related Documents

- [spec-server.md](spec-server.md) — Server design
- [spec-client.md](spec-client.md) — Client design
- [phase-interfaces.md](phase-interfaces.md) — Phase interface contracts (run/destroy phase details)
- [node-orchestration.md](node-orchestration.md) — Multi-node orchestration
- [requirements-catalog.md](requirements-catalog.md) — Structured requirements with IDs
- [test-strategy.md](test-strategy.md) — Test hierarchy and system test catalog
- [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125) — Architecture evolution epic (detailed discussion)

## Changelog

| Date | Change |
|------|--------|
| 2026-02-05 | Update CLI Pattern section: distinguish driver CLI (`./run.sh`) from target CLI (`homestak`); remove premature `homestak config` porcelain reference |
| 2026-02-03 | Rename to node-lifecycle.md; normalize execution models as co-equal (push/hybrid/pull all first-class); add terminology framework; remove "In Progress" section |
| 2026-02-03 | Rename to node-lifecycle-architecture.md; consolidate to 4 phases (create, config, run, destroy); add #140 epic, scope & relationship section |
| 2026-02-02 | Update for v0.45: create → config integration complete |
| 2026-02-02 | Move release plan to epic (avoid staleness) |
| 2026-02-02 | Initial document extracted from iac-driver#125 |
