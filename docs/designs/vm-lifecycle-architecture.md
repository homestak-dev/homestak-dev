# VM Lifecycle Architecture

**Epic:** [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125)
**Status:** Active (v0.43 complete, subsequent phases in progress)
**Date:** 2026-02-01

## Overview

This document captures the architectural vision for homestak's VM lifecycle model. It represents a shift from push-based orchestration to a pull-based discovery and convergence model where nodes autonomously discover their specifications and converge to desired state.

## The Six Lifecycle Phases

```
CREATE → SPECIFY → APPLY → OPERATE → SUSTAIN → DESTROY
   │        │        │        │         │         │
   │        │        │        │         │         └── Graceful shutdown, cleanup
   │        │        │         │         └── Health checks, drift detection, updates
   │        │        │        └── Normal runtime, serving workloads
   │        │        └── Install packages, configure services, reach platform ready
   │        └── Fetch spec, learn "what to become"
   └── Node provisioned with identity seed + discovery endpoint
```

| Phase | Purpose | Activities |
|-------|---------|------------|
| **Create** | Provision | Allocate resources, boot node, inject identity + auth token |
| **Specify** | Identity | Fetch spec, validate auth, resolve FKs |
| **Apply** | Configure | Install packages, enable services |
| **Operate** | Runtime | Workloads running, serving requests |
| **Sustain** | Maintenance | Health checks, drift detection, updates, patching |
| **Destroy** | Teardown | Graceful shutdown, cleanup |

### The "Platform Ready" Boundary

"Becoming" (Create through Apply) stops at **Platform Ready** — the machine has everything needed to fulfill its role, but isn't yet doing the role's work.

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

Nodes can spawn child nodes, creating hierarchical infrastructure topologies.

## Execution Model Evolution

### Previous: Push Model

Controller holds all orchestration logic; inner hosts are passive recipients.

```
Controller (outer host)
    │
    ├── SSH → tofu apply (controller targets PVE API)
    ├── SSH → rsync repos to inner
    ├── SSH → ansible-playbook (controller runs, targets inner)
    │
Inner Host (passive recipient)
    - Receives files
    - Receives commands
    - Has no agency
```

### Current: Hybrid Model

Controller initiates but doesn't micromanage; inner hosts have full agency once triggered.

```
Controller (outer host)
    │
    ├── PUSH: tofu apply (provision inner VM)
    ├── PUSH: SSH → "homestak scenario ..."
    │              │
    │              └── HANDOFF: Inner takes over
    │
Inner Host (autonomous agent)
    ├── Has full homestak installation
    ├── Executes remaining work independently
    └── REPORT: Returns JSON result to controller
```

### Target: Pull Model

Nodes discover their spec and converge autonomously.

```
Controller                              Node
──────────                              ────
1. homestak serve (config server)
2. tofu apply (inject identity + endpoint)
                                        3. Boot with identity
                                        4. homestak spec get
   ◀────────────────────────────────────┤
   GET /spec/{identity}                 │
   ────────────────────────────────────▶
   200 OK + spec                        │
                                        5. homestak apply
                                        6. PLATFORM READY
```

## Key Principles

1. **Spec is discovered, not embued** — Nodes fetch their configuration from an external source rather than having it injected at creation time.

2. **Platform Ready boundary** — "Becoming" stops at platform readiness, not application deployment.

3. **Clean sheet architecture** — New lifecycle layer alongside existing code, extracting proven primitives rather than retrofitting old assumptions.

4. **Explicit/flat first** — Start with explicit specs, graduate to roles/capabilities when patterns emerge.

5. **Unified nodes** — VMs, CTs, PVE hosts, and k3s nodes share the same lifecycle model.

## Auth Model

Authentication for the Specify phase varies by posture:

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
    │   ├── node.schema.json
    │   └── posture.schema.json
    ├── specs/                # VM specifications (what to become)
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
    └── nodes/                # Node templates (infrastructure)
        ├── pve.yaml
        └── base.yaml
```

### Lifecycle Coverage

| Directory | Phase | Purpose |
|-----------|-------|---------|
| `v2/nodes/` + `v2/presets/` | Create | Infrastructure provisioning |
| `v2/specs/` | Specify | What to become |
| `v2/specs/` + `v2/postures/` | Apply | Configuration |

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

apply:
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

## Terminology

| Term | Directory | Meaning |
|------|-----------|---------|
| **Node** | `v2/nodes/` | Compute entity (VM, CT, PVE host, k3s node) |
| **Spec** | `v2/specs/` | Specification — what a node should become |
| **Def** | `v2/defs/` | Schema definition — structure of specs/nodes |
| **Posture** | `v2/postures/` | Security configuration (dev, stage, prod, local) |
| **Preset** | `v2/presets/` | Size preset (vm-small, vm-large, etc.) |

## CLI Pattern

```bash
homestak <noun> <verb> [args...]

# Spec management
homestak spec validate <path>     # Validate spec against schema
homestak spec get                 # Fetch spec from server

# Server
homestak serve                    # Start config server

# Future
homestak apply                    # Apply spec to reach platform ready
homestak node create <template>   # Create node from template
homestak node list                # List nodes
homestak node destroy <name>      # Destroy node
```

## Implementation Approach

### Clean Sheet with Extracted Primitives

The current architecture has embedded assumptions that conflict with the lifecycle model:

| Current Assumption | Lifecycle Model Conflict |
|-------------------|-------------------------|
| Scenario knows all phases at definition time | Phases emerge from discovered spec |
| Controller maintains context dict | Context is distributed across autonomous nodes |
| Actions execute in controller's process | Actions execute wherever the node lives |
| One-shot execution model | Continuous convergence loop |

Rather than retrofitting, we build a clean lifecycle layer that uses proven primitives extracted from existing code.

### Coexistence Strategy

Both architectures coexist during development:

```
iac-driver/
├── src/                    # Current architecture (traditional + recursive)
│   ├── scenarios/
│   └── actions/
│
├── lifecycle/              # New architecture (clean sheet) - future
│   ├── core/
│   │   ├── create.py
│   │   ├── specify.py
│   │   ├── apply.py
│   │   └── sustain.py
│   └── primitives/         # Extracted from src/actions/
│
└── run.sh                  # Entry point (routes appropriately)
```

## Implementation Status

The architecture is being implemented incrementally across multiple releases. See [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125) for current release status and planning.

## Related Documents

- [v0.44-specify-server.md](v0.44-specify-server.md) — Server design
- [v0.44-specify-client.md](v0.44-specify-client.md) — Client design
- [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125) — Architecture evolution epic (detailed discussion, requirements catalog)

## Changelog

| Date | Change |
|------|--------|
| 2026-02-02 | Move release plan to epic (avoid staleness) |
| 2026-02-02 | Initial document extracted from iac-driver#125 |
