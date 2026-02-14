# Node Orchestration

**Status:** Active
**Date:** 2026-02-02
**Epic:** [iac-driver#140](https://github.com/homestak-dev/iac-driver/issues/140) — Manifest-based Orchestration Architecture
**Related:** [node-lifecycle.md](node-lifecycle.md), [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125)

**Reading order:** Read [node-lifecycle.md](node-lifecycle.md) first for single-node lifecycle concepts, then this document for multi-node patterns and coordination.

## Overview

This document establishes a conceptual framework for two orthogonal dimensions of homestak infrastructure:

| Dimension | Question | Options |
|-----------|----------|---------|
| **Deployment Pattern** | What are we building? | Single-host, cluster, nested, tiered, edge, k3s |
| **Execution Model** | How do we build it? | Push, pull, hybrid |

These dimensions are independent. Any deployment pattern can be realized by any execution model. The choice of execution model depends on user context, not topology.

```
┌─────────────────────────────────────────────────────────┐
│                  Deployment Patterns                    │
│  (single-host, cluster, nested, tiered, edge)           │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      Manifests                          │
│  (declarative description of pattern + nodes + specs)   │
└─────────────────────────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
┌─────────────────────────┐  ┌─────────────────────────┐
│    Push Execution       │  │    Pull Execution       │
│    (driver-initiated)   │  │    (target-initiated)   │
└─────────────────────────┘  └─────────────────────────┘
```

## Terminology

This document uses precise terminology to distinguish three orthogonal relationships. See [node-lifecycle.md](node-lifecycle.md) for detailed definitions.

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

**Semantic alignment:** The `iac-driver` repository name → `run.sh` driver script → **driver** node.

## Deployment Patterns

Deployment patterns describe real-world infrastructure topologies that homestak users build.

### Catalog

Deployment patterns are defined by topology, not workload. The same topology can host different workloads (VMs, containers, Kubernetes, applications).

| Pattern | Topology | Description |
|---------|----------|-------------|
| **Single-host** | Flat | One host running child nodes |
| **Cluster** | Mesh | Multiple peer hosts with shared resources |
| **Nested** | Tiered (2-level) | Host-in-VM for dev/test isolation |
| **Tiered** | Tiered (N-level) | Management plane + workload planes |
| **Edge** | Hub-spoke | Central driver + remote sites |
| **Multi-site** | Federated | Regional clusters with cross-links (Horizon 2) |

Workload types (PVE hypervisor, Kubernetes, application containers) are specified in the node's spec, not the deployment pattern.

### Topology Abstractions

Patterns can be abstracted into topology types:

| Topology | Structure | Edges | Example |
|----------|-----------|-------|---------|
| **Flat** | Single node, local children | None between peers | Single-host homelab |
| **Tiered** | Parent-child tree | Directed (parent → child) | Nested PVE, tiered infra |
| **Hub-spoke** | Central driver + remotes | Directed (hub → spokes) | Edge deployment |
| **Mesh** | Peer nodes, mutual relationships | Undirected | PVE cluster |
| **Federated** | Mixed levels, cross-links | Mixed directed/undirected | Federation, hybrid cloud |

**Mesh vs Hub-spoke:** Hub-spoke has a distinguished central node; mesh nodes are peers with no hierarchy. PVE clusters are mesh — any node can manage any other.

**Federated:** A generalization where nodes exist at varying levels with potential cross-links between branches. Example: two regional clusters that peer with each other while each has local tiered structures. This may be out of scope for initial implementation.

### Pattern Examples

**Single-host** (flat):
```
host-a
├── node-1
├── node-2
└── node-3
```

**Nested** (tiered, 2-level):
```
host-a
└── inner-host
    ├── node-1
    └── node-2
```

**Tiered** (tiered, N-level):
```
mgmt-host
├── control-plane
│   ├── controller-1
│   └── controller-2
└── workload-plane
    ├── worker-1
    └── worker-2
```

**Cluster** (mesh):
```
host-a ◄──► host-b ◄──► host-c
  │           │           │
  └── nodes   └── nodes   └── nodes
```

**Edge** (hub-spoke):
```
central-driver
    │
    ├── [WAN] ──→ site-1
    │               └── nodes...
    │
    └── [WAN] ──→ site-2
                    └── nodes...
```

**Multi-site** (federated, Horizon 2):
```
region-west ◄────────────► region-east
    │                           │
    ├── local tiered structure  ├── local tiered structure
    └── nodes...                └── nodes...
```

## Execution Models

Execution models describe how deployment patterns are realized — who initiates actions and how control flows. All three models are first-class approaches.

### Push Execution

Driver initiates all actions; target nodes are passive recipients.

```
Driver
    │
    ├── SSH → target: "tofu apply"
    ├── SSH → target: "ansible-playbook ..."
    └── SSH → target: "./run.sh create -M X -H host"
```

| Characteristic | Value |
|----------------|-------|
| Initiator | Driver |
| Authority | Centralized |
| Timing | Synchronous |
| Transport | SSH |
| Feedback | Immediate |

**Strengths:**
- Simple mental model
- Immediate feedback
- Easy to debug (operator is present)
- No daemon/server required on targets

**Weaknesses:**
- Requires SSH access to all targets
- Driver is single point of failure
- Doesn't scale well to many targets
- No autonomous recovery

### Pull Execution

Nodes initiate their own configuration; driver provides specs on demand.

```
Driver                                  Target
──────                                  ──────
1. Runs spec server
2. Provisions node with provisioning
   token (carries spec FK + identity)
                                        3. Boots, presents token to server
                                        4. Server verifies HMAC, serves spec
                                        5. Applies spec locally
                                        6. Converges to desired state
```

| Characteristic | Value |
|----------------|-------|
| Initiator | Target |
| Authority | Distributed |
| Timing | Asynchronous (convergence) |
| Transport | HTTPS (spec fetch) |
| Feedback | Eventual (polling/reporting) |

**Strengths:**
- Autonomous recovery
- Scales to many nodes
- Works across network boundaries (no SSH needed)
- Continuous convergence (drift detection)

**Weaknesses:**
- More complex infrastructure (spec server)
- Delayed feedback
- Harder to debug (actions happen remotely)
- Requires spec server availability

### Hybrid Execution

Driver triggers action; target node executes autonomously.

```
Driver                                  Target
──────                                  ──────
1. Provisions node with provisioning
   token (carries spec FK + identity)
2. Signals "converge now"
                                        3. Presents token, fetches spec
                                        4. Applies spec
                                        5. Reports result
```

This combines push's explicit triggering with pull's autonomous execution.

**Use cases:**
- Operator wants to trigger deployment but not micromanage
- Audit trail requires explicit initiation
- Network constraints prevent pure pull (no persistent server)

### Execution Model Comparison

|  | Push | Pull | Hybrid |
|--|------|------|--------|
| SSH required | Yes | No | Optional |
| Spec server required | No | Yes | Yes |
| Autonomous recovery | No | Yes | Yes |
| Immediate feedback | Yes | No | Partial |
| Scales to 100+ nodes | Poorly | Well | Well |
| Debugging ease | Easy | Hard | Medium |

## Manifests

Manifests are declarative descriptions of deployment patterns, independent of execution model.

### Purpose

A manifest describes **what** to build without prescribing **how** to build it:

- Nodes and their relationships
- Specs each node should become
- Cardinality (how many of each)
- Constraints and dependencies

### Schema v1 (Removed)

The v1 manifest schema used linear `levels[]` and was coupled to push execution. It was removed in iac-driver#181. Only v2 is supported.

### Schema v2

Manifests define topology, execution model, and node instances:

```yaml
# Manifest defines topology + execution + instances
schema_version: 2
name: nested-test
pattern: tiered

execution:
  default_mode: pull                   # Document-wide default

nodes:
  - name: inner-pve
    type: vm
    spec: pve
    preset: vm-large
    image: debian-13-pve
    execution:
      mode: push                       # Override: push for this node

  - name: test
    type: vm
    spec: base
    preset: vm-small
    image: debian-12-custom
    parent: inner-pve                  # Tiered relationship
    # Inherits default_mode: pull
```

### Simplified CLI

With topology and execution mode externalized to the manifest, the CLI uses verb subcommands (established in iac-driver#146):

```bash
# Legacy: scenario name encodes action + topology style
./run.sh --scenario recursive-pve-constructor --manifest n2-tiered --host father
./run.sh --scenario recursive-pve-destructor --manifest n2-tiered --host father

# Current: verb-based subcommands
./run.sh create -M nested-test -H father
./run.sh destroy -M nested-test -H father
./run.sh test -M nested-test -H father    # create + verify + destroy
```

**Benefits:**
- No scenario proliferation (retired `vm-constructor`, `nested-pve-constructor`, etc. collapsed to `create`)
- Topology and execution mode are externalized, not encoded in scenario names
- CLI is more intuitive: verb is the operation, manifest is the target
- Mode can be overridden at CLI if needed: `./run.sh create -M nested-test -H father --mode push`

### Execution Mode Inheritance

Within a manifest, execution mode flows from document default with per-node overrides:

```
Document default_mode: pull
    │
    ├── inner-pve: mode: push (explicit override)
    │       │
    │       └── test: (inherits default: pull)
    │
    └── monitor: mode: push (explicit override)
```

This allows mixed-mode deployments: push for infrastructure nodes, pull for application nodes that should converge autonomously.

### Relationship to v2/nodes/

With manifests owning topology + execution, what role does `site-config/v2/nodes/` play?

**The identity problem:** A node's filename is its primary key (`pve.yaml` → `pve`). This makes nodes instances, not templates. You can't instantiate "pve" twice — you'd need `inner-pve.yaml`, `outer-pve.yaml`, defeating reusability.

**What's actually reusable:**
- `specs/` — what to become (packages, services) ✓
- `presets/` — resource sizing (cores, memory, disk) ✓
- `postures/` — security configuration ✓
- ~~`v2/nodes/`~~ — type + image + spec FK... with fixed identity ✗ (eliminated)

**Recommendation:** Eliminate standalone node files. Manifests reference specs and presets directly:

```yaml
# manifests/nested-test.yaml
nodes:
  - name: inner-pve           # Instance identity (unique per manifest)
    type: vm
    spec: pve                 # FK to specs/pve.yaml
    preset: vm-large          # FK to presets/vm-large.yaml
    image: debian-13-pve
    execution:
      mode: push

  - name: test
    type: vm
    spec: base
    preset: vm-small
    image: debian-12-custom
    parent: inner-pve         # Topology relationship
```

**Resulting structure:**
```
site-config/
├── defs/
│   ├── manifest.schema.json   # Absorbs node.schema.json properties
│   ├── spec.schema.json
│   └── posture.schema.json
├── specs/          # What nodes become (packages, services, config)
├── presets/        # Resource sizing (cores, memory, disk)
├── postures/       # Security configuration
└── manifests/      # Topology + execution + instance definitions
```

This is simpler and avoids the "template vs instance" confusion that plagued v1/envs.

### Manifest Schema (v2)

The manifest schema absorbs properties from `node.schema.json`, which can be retired:

```yaml
# defs/manifest.schema.json (conceptual)
schema_version: 2
name: string                      # Manifest identifier
pattern: enum                     # flat, tiered, mesh, hub-spoke, federated

execution:
  default_mode: enum              # push, pull

nodes:                            # Arbitrary graph of node definitions
  - name: string                  # Instance identity (unique within manifest)
    type: enum                    # vm, ct, pve (from node.schema.json)
    spec: string                  # FK to specs/
    preset: string                # FK to presets/
    image: string                 # For type: vm
    template: string              # For type: ct
    parent: string                # FK to another node in this manifest (optional)

    execution:                    # Optional per-node override
      mode: enum                  # push, pull
```

**Graph representation:** The `parent` field enables arbitrary topologies:
- **Flat:** All nodes have no parent (or same parent)
- **Tiered:** Linear parent chain
- **Mesh:** Nodes reference each other as peers (parent = null, separate `peers` field?)
- **Hub-spoke:** One hub node, others reference it as parent
- **Federated:** Multiple subgraphs with cross-links

**Migration path:**
- `defs/node.schema.json` → properties moved into manifest node definitions
- Standalone node files → instances defined inline in manifests
- Node schema can be deleted once manifests absorb its responsibilities

## User Personas

Different users prefer different execution models based on their context.

| Persona | Preferred Model | Rationale |
|---------|-----------------|-----------|
| **DIY homelab** | Push | Operator present, wants feedback, simpler setup |
| **Managed service** | Pull | Remote sites, autonomous recovery, less SSH |
| **Enterprise** | Hybrid | Audit trail (push trigger), autonomy (pull execution) |

### homestak-dev vs homestak-com

| Layer | Primary Model | Why |
|-------|---------------|-----|
| **homestak-dev** (OSS) | Push | User is at keyboard, immediate feedback valued |
| **homestak-com** (commercial) | Pull | Remote management, autonomous recovery, scales |

The OSS foundation should support both models. The commercial layer builds on pull for its management capabilities.

## Terminology Reference

### Recommended Terms

| Term | Meaning | Replaces |
|------|---------|----------|
| **driver** | Node running iac-driver | "controller", "outer host" |
| **target** | Node receiving configuration | "inner host", "passive recipient" |
| **parent node** | Node that creates/destroys another | (lifecycle relationship) |
| **child node** | Node created/destroyed by another | (lifecycle relationship) |
| **host** | PVE hypervisor | (infrastructure layer) |
| **guest** | VM or CT running on a host | (infrastructure layer) |
| **push execution** | Driver-initiated, SSH-based | (implicit in current scenarios) |
| **pull execution** | Target-initiated, spec-driven | "lifecycle model" |
| **tiered topology** | N-level parent-child structure | "hierarchical", "recursive" |
| **federated topology** | Mixed levels with cross-links | "constellation" |
| **flat topology** | Single level, peer nodes | N=1 |
| **manifest** | Declarative pattern description | (unchanged) |
| **spawn** | Parent node creating child node | (new) |

### Lifecycle Phases (4-Phase Model)

| Phase | Description | Old 6-Phase Mapping |
|-------|-------------|---------------------|
| **create** | Provision node with identity | Create |
| **config** | Fetch spec, apply configuration | Specify + Apply |
| **run** | Runtime operations and maintenance | Operate + Sustain |
| **destroy** | Teardown and cleanup | Destroy |

### Deprecated Terms

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| "controller" | Ambiguous with k8s controller | "driver" |
| "outer host" / "inner host" | Conflates multiple relationships | Use driver/target, parent/child, or host/guest as appropriate |
| "recursive" | Conflates topology with execution | "tiered" + execution model |
| "nested" (as scenario prefix) | Implies specific topology | Pattern name + execution model |
| "hierarchical" (topology) | Awkward, verbose | "tiered" |
| "constellation" (topology) | Awkward, unclear | "federated" |
| "N=2" | Abstract, not descriptive | Pattern name (e.g., "nested-test") |
| "specify" / "apply" (phases) | Verbose 6-phase model | "config" (merged) |
| "operate" / "sustain" (phases) | Verbose 6-phase model | "run" (merged) |

### Obsolete Terms (Anti-patterns)

These terms and patterns should NOT be used in new development:

| Obsolete Term | Why | Use Instead |
|---------------|-----|-------------|
| `nested-pve-*` scenarios | Hardcoded 2-level, push-only | verb commands (`./run.sh create|destroy|test`) |
| `recursive-pve-*` scenarios | Old manifest format, push-only | verb commands (`./run.sh create|destroy|test`) |
| `vm-constructor` / `vm-destructor` | Action encoded in name | `create` / `destroy` |
| `*-roundtrip` scenarios | Test pattern encoded in name | `test` |
| `levels` (manifest) | Linear only | `nodes` with `parent` |
| `SyncReposToVMAction` | Pre-bootstrap pattern | Bootstrap handles repos |

**Note:** `TofuApplyRemoteAction` and `TofuDestroyRemoteAction` were retired in Sprint homestak-dev#195. The operator delegates via `RecursiveScenarioAction` with `raw_command` instead. See [scenario-consolidation.md](scenario-consolidation.md) for details.

## Relationship to Node Lifecycle

This document complements [node-lifecycle.md](node-lifecycle.md):

| Document | Focus |
|----------|-------|
| Node Lifecycle | The four phases (create → destroy), spec schema, auth model |
| Node Orchestration | Topology patterns, push vs pull, manifests |

The lifecycle document describes what happens to a **single node**. This document describes how **multiple nodes** are organized and orchestrated.

```
Orchestration (this doc)          Node Lifecycle (other doc)
────────────────────────          ──────────────────────────
"Build a nested-test pattern"  →  Each node goes through:
with tiered topology              create → config → run → destroy
using pull execution
```

### Execution Model by Phase

Not all phases support both execution models equally:

| Phase | Push | Pull | Notes |
|-------|------|------|-------|
| **create** | ✓ Primary | ✗ | Node doesn't exist yet; must be externally provisioned |
| **config** | ✓ SSH+Ansible | ✓ Token+fetch+converge | Push injects and applies; pull presents provisioning token, fetches spec, converges locally |
| **run** | ✓ SSH+command | ✓ Job queue | Push: SSH commands; Pull: retrieve and execute instructions |
| **destroy** | ✓ Primary | △ Self-terminate | External cleanup required; node can self-terminate but parent must reclaim resources |

**Key insight:** Push and pull are universal control motions applicable to all phases. Even run (runtime) can use either model — push for ad-hoc commands, pull for job/instruction queues. Create is the exception: the node doesn't exist yet, so it cannot pull. Destroy has asymmetry: a node can self-terminate, but the parent node must reclaim external resources (VM allocation, DNS records, etc.).

### Phase Independence

Each phase can potentially choose its execution model independently:

```
create (push) → config (pull) → run (pull) → destroy (push)
```

This is the hybrid model: push for lifecycle boundaries (create/destroy), pull for configuration and runtime (config/run).

### Scenarios and Execution Model

After scenario consolidation (Sprint homestak-dev#195), VM lifecycle uses verb commands:

| Command | Phases Covered | Execution |
|---------|----------------|-----------|
| `./run.sh create -M <manifest> -H <host>` | create, config (PVE lifecycle) | Push |
| `./run.sh destroy -M <manifest> -H <host>` | destroy | Push |
| `./run.sh test -M <manifest> -H <host>` | create → verify → destroy | Push |
| `pve-setup` | config (to existing host) | Push |
| `push-vm-roundtrip` | create → specify (push) | Push (verify spec server) |

The `push-vm-roundtrip` scenario validates that spec server env vars are injected and reachable via SSH. The `pull-vm-roundtrip` scenario validates the full pull-mode config phase (iac-driver#147/#156, completed in Sprint homestak-dev#201).

### Mode Selection

Execution mode is defined in the manifest with optional CLI override:

```bash
# Use manifest's defined mode
./run.sh create -M nested-test -H father

# Override manifest's mode
./run.sh create -M nested-test -H father --mode push
```

**Mode mixing:** Different nodes can use different modes (defined in manifest). A node created via push can later operate in pull mode for the run phase. The mode is a property of the operation, not the node itself.

**Mode inheritance:** Nodes inherit the document's `default_mode` unless explicitly overridden. This allows patterns like "push for infrastructure nodes, pull for application nodes."

## Open Questions

### Resolved

1. **Manifest syntax:** Use `nodes` (arbitrary graph), not `levels` (linear). Nodes can represent linear hierarchies, but levels cannot represent arbitrary graphs. Solve it right the first time.

2. **Mixed execution:** Addressed in "Mode Selection" section. Per-level mode overrides enable mixed execution.

4. **Manifest FK resolution:** Same FK pattern used throughout site-config. Manifests reference specs, presets, postures by name; resolution happens at runtime.

5. **Scenario consolidation:** Most scenarios collapse to verb subcommands (`create`, `destroy`, `test`). Apply-phase scenarios (`pve-setup`, `user-setup`) deferred to Apply phase design.

   **Manifests are required.** Ad-hoc single-node operations without a manifest are anti-pattern — they produce snowflake infrastructure. Even a one-node deployment should have a manifest. This maintains IaC principles: all infrastructure is declared, versioned, reproducible.

7. **Workload types:** Resolved. Topology and workload are orthogonal. Workload types belong in the spec layer. Pattern catalog uses topology-only names (flat, tiered, mesh, hub-spoke, federated).

8. **v2/nodes/ disposition:** Resolved. Eliminate v2/nodes/, absorb node.schema.json properties into manifest.schema.json. See "Manifest Schema (v2)" section.

### Deferred

3. **Commercial patterns:** Defer. homestak-com may define additional patterns (managed-edge, ha-cluster) when that layer matures.

6. **Federated topology:** Horizon 2. Multi-site deployments (homelab + cloud, regional clusters) use federated topology. Defer detailed design but keep in architectural scope.

## Implementation Relationship

This design document represents a significant architectural evolution. Related implementation work:

### iac-driver#139: Move spec server from bootstrap to iac-driver

[Issue #139](https://github.com/homestak-dev/iac-driver/issues/139) moves the spec server and FK resolution logic from bootstrap to iac-driver. This is a prerequisite for the architecture described here:

| #139 Deliverable | Enables |
|------------------|---------|
| Unified FK resolution | Manifests use same FK pattern as specs |
| Spec server in iac-driver | Server can serve both specs AND manifests |
| `./run.sh server start` entry point | Aligns with verb-based CLI pattern (`./run.sh create/destroy/test`) |
| ConfigResolver + SpecResolver consolidation | Single resolver handles manifests and specs |

### Phased Implementation

| Phase | Scope | Builds On | Status | Released |
|-------|-------|-----------|--------|----------|
| 1. #139, #148 | Move spec server, unified controller | v0.45 | **Complete** | v0.43–v0.45 |
| 2. #143 | Manifest schema v2, retire node.schema.json | Phase 1 | **Complete** | On master |
| 3. #144 | Operator engine (`manifest_opr/`), verb CLI | Phase 2 | **Complete** | On master |
| 4. #145 | Scenario consolidation, retire legacy scenarios | Phase 3 | **Complete** | On master |
| 5. #147 | Pull execution, config phase | All above | **Complete** | On master |

**Note:** v0.43–v0.45 are released. Phases 2–5 are merged to master but unreleased.

### Related Issues

Several open issues are affected by this design:

| Issue | Title | Disposition |
|-------|-------|-------------|
| #93 | Per-host SSH key authorization | **Independent** — SSH access control, not superseded by auth.node_tokens (API auth) |
| #113 | Retire legacy remote execution | **Complete** — retired in #153 (Sprint homestak-dev#195) |
| #115 | Manifest schema v2: Tree structure | **Closed** — this design delivers `nodes` with `parent` references |
| #120 | Deprecate nested-pve scenarios | **Complete** — all `*-constructor`, `*-destructor`, `*-roundtrip` replaced by verb commands (`create`/`destroy`/`test`) |
| #124 | Simplify SSH key injection | **Still relevant** — push execution coexists with pull; push still needs clean SSH handling |

**Disposition:**

- **#115**: Closed — superseded by manifest schema v2
- **#120**: **Complete** — absorbed by #145 (scenario consolidation)
- **#113**: **Complete** — retired in #153 (Sprint homestak-dev#195)
- **#124**: Remains open — push execution path still needs clean SSH handling
- **#93**: Remains open — different concern from auth.node_tokens (SSH access vs API auth)

### Architecture Alignment

**Principle:** iac-driver owns both orchestration AND implementation. Bootstrap stays minimal (installation only).

```
Before (v0.45)                     After (Sprint #199+)
──────────────                     ────────────────────
bootstrap/                         bootstrap/
├── homestak.sh                    ├── homestak.sh (thin wrapper)
├── lib/serve.py      ──removed──  ├── lib/spec_client.py
├── lib/spec_resolver.py ─removed─ └── install.sh
├── lib/spec_client.py
                                   iac-driver/
iac-driver/                        ├── src/
├── src/                           │   ├── resolver/ (unified FK)
│   ├── config_resolver.py         │   ├── server/ (spec+repo server)
│   ├── scenarios/*.py ──retired──►│   ├── manifest_opr/ (operator engine)
│                                  │   └── cli.py (verb commands)
│                                  └── run.sh
```

**Status:** The serve/resolver migration completed in Sprint #199 (bootstrap#38). Scenario retirement completed in Sprint #195 (iac-driver#145). The architecture above reflects current state.

**Key points:**
- **iac-driver** owns all lifecycle code: orchestration (manifests, server) and implementation (spec get, config)
- **bootstrap** stays minimal: installation scripts, `spec_client.py`, and a thin `homestak` wrapper that delegates to iac-driver
- Target VMs have iac-driver installed (via bootstrap), so all commands are available
- `homestak` CLI remains the user-facing command on targets, but delegates to iac-driver internals

The work in #139 positions iac-driver as the lifecycle engine — owning both the server (pull model) and the client/executor (push and pull models).

## System Test Scenarios

These scenarios validate the full stack: orchestration (#140) → lifecycle (#125) → primitives.

### ST-1: Single-node Pull Lifecycle

**Validates:** #125 (config phase), pull execution

```
Preconditions:
- Spec server running on driver
- specs/base.yaml defined
- manifests/single-node.yaml exists

Manifest:
  nodes:
    - name: test-vm
      type: vm
      spec: base
      preset: vm-small
      execution:
        mode: pull

Steps:
1. ./run.sh create -M single-node -H father
2. ConfigResolver mints provisioning token with `s` claim (spec FK)
3. Driver provisions VM with HOMESTAK_TOKEN + HOMESTAK_SPEC_SERVER via cloud-init
4. VM boots, presents token to server (`./run.sh config --fetch`)
5. Server verifies HMAC, extracts `s` claim, serves resolved spec
6. VM applies spec locally, writes config-complete marker
7. Verify: VM reaches platform ready state
8. ./run.sh destroy -M single-node -H father

Assertions:
- Token `s` claim resolves to correct spec (not hostname-based lookup)
- VM fetched spec from server (check /usr/local/etc/homestak/state/spec.yaml)
- SSH access works with keys from spec
- Packages from spec are installed
```

### ST-2: Single-node Push Lifecycle

**Validates:** #125, push execution

```
Preconditions:
- Driver has SSH access to target host
- manifests/single-node-push.yaml exists

Manifest:
  nodes:
    - name: test-vm
      type: vm
      spec: base
      preset: vm-small
      execution:
        mode: push

Steps:
1. ./run.sh create -M single-node-push -H father
2. Driver provisions VM
3. Driver SSHes to VM, runs configuration
4. Verify: VM reaches platform ready state
5. ./run.sh destroy -M single-node-push -H father

Assertions:
- No spec server required
- Configuration applied via SSH
- Same end state as ST-1
```

### ST-3: Tiered Topology (2-level)

**Validates:** #140 (tiered pattern), #125 (lifecycle per node)

```
Preconditions:
- specs/pve.yaml and specs/base.yaml defined
- manifests/nested-test.yaml exists

Manifest:
  pattern: tiered
  execution:
    default_mode: push
  nodes:
    - name: inner-pve
      type: vm
      spec: pve
      preset: vm-large
      parent: null

    - name: test-vm
      type: vm
      spec: base
      preset: vm-small
      parent: inner-pve

Steps:
1. ./run.sh create -M nested-test -H father
2. Driver creates inner-pve on father
3. inner-pve reaches platform ready (PVE installed)
4. Driver creates test-vm on inner-pve
5. test-vm reaches platform ready
6. ./run.sh destroy -M nested-test -H father
7. Destroy order: test-vm first, then inner-pve

Assertions:
- Parent created before children
- Children destroyed before parent
- Each node independently reaches platform ready
- SSH chain works: driver → inner-pve → test-vm
```

### ST-4: Tiered Topology (3-level)

**Validates:** #140 (N-level), tiered depth

**Status:** Available — `--self-addr` propagates routable address at depth 2+ ([iac-driver#200](https://github.com/homestak-dev/iac-driver/issues/200)).

```
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

Assertions:
- Creation order: level-1 → level-2 → level-3
- Destruction order: level-3 → level-2 → level-1
- Each level independently functional
- Server propagation chain: each PVE level serves repos to its children
```

### ST-5: Mixed Execution Modes

**Validates:** #140 (push/pull coexistence), mode inheritance

```
Manifest:
  execution:
    default_mode: pull
  nodes:
    - name: inner-pve
      spec: pve
      parent: null
      execution:
        mode: push        # Override: infrastructure via push

    - name: app-vm
      spec: base
      parent: inner-pve
      # Inherits: pull    # Apps converge autonomously

Steps:
1. ./run.sh create -M mixed-mode -H father
2. inner-pve created via push (driver configures)
3. app-vm provisioned with provisioning token (minted at create time)
4. app-vm boots, presents token, fetches spec via pull (autonomous)
5. Both reach platform ready

Assertions:
- inner-pve configured by driver (push)
- app-vm fetched spec from server (pull) using provisioning token
- Token `s` claim resolved to correct spec for app-vm
```

### ST-6: Flat Topology (Multiple Peers)

**Validates:** #140 (flat pattern), parallel creation

```
Manifest:
  pattern: flat
  nodes:
    - name: worker-1
      spec: base
      parent: null

    - name: worker-2
      spec: base
      parent: null

    - name: worker-3
      spec: base
      parent: null

Steps:
1. ./run.sh create -M workers -H father
2. All three VMs created (potentially in parallel)
3. All reach platform ready
4. ./run.sh destroy -M workers -H father

Assertions:
- No ordering dependency between peers
- All nodes created on same parent host
- Parallel creation (optimization, not required)
```

### ST-7: Manifest Validation

**Validates:** Schema enforcement, FK resolution

```
Steps:
1. `./run.sh validate -M valid` → exit 0
2. `./run.sh validate -M invalid-schema` → exit 1, schema error
3. `./run.sh validate -M invalid-fk` → exit 1, unresolved FK

Assertions:
- Valid manifests pass
- Schema violations caught (missing required fields, wrong types)
- Unresolved FKs caught (spec: nonexistent, preset: unknown)
```

### ST-8: Action Idempotency

**Validates:** Safe re-runs

```
Steps:
1. ./run.sh create -M single-node -H father
2. ./run.sh create -M single-node -H father  # Re-run
3. Verify: No error, no duplicate VM, state unchanged
4. ./run.sh destroy -M single-node -H father
5. ./run.sh destroy -M single-node -H father  # Re-run
6. Verify: No error, clean exit

Assertions:
- Create is idempotent (existing node detected)
- Destroy is idempotent (missing node not an error)
```

### Test Matrix

| Scenario | Topology | Execution | Levels | Key Validation |
|----------|----------|-----------|--------|----------------|
| ST-1 | Flat | Pull | 1 | config phase, spec fetch |
| ST-2 | Flat | Push | 1 | Push execution path |
| ST-3 | Tiered | Push | 2 | Parent-child ordering |
| ST-4 | Tiered | Push | 3 | N-level nesting |
| ST-5 | Tiered | Mixed | 2 | Mode coexistence |
| ST-6 | Flat | Push | 1 (x3) | Peer nodes, parallelism |
| ST-7 | N/A | N/A | N/A | Schema, FK validation |
| ST-8 | Flat | Push | 1 | Idempotency |

### Mapping to Current Scenarios

| System Test | Current Equivalent | Gap |
|-------------|-------------------|-----|
| ST-1 | `pull-vm-roundtrip` | **Available** (Sprint homestak-dev#201) |
| ST-2 | `./run.sh test -M n1-push` | **Available** |
| ST-3 | `./run.sh test -M n2-tiered` | **Available** |
| ST-4 | `./run.sh test -M n3-deep` | **Available** — `--self-addr` propagates routable address (iac-driver#200) |
| ST-5 | None | New capability (mixed execution modes) |
| ST-6 | None | New capability (parallel peers) |
| ST-7 | None | New capability (manifest validation) |
| ST-8 | Partial (scenarios are mostly idempotent) | Formal validation |

## Related Documents

- [node-lifecycle.md](node-lifecycle.md) — Single-node lifecycle phases
- [server-daemon.md](server-daemon.md) — Server daemon design (robustness, CLI, daemonization)
- [phase-interfaces.md](phase-interfaces.md) — Phase interface contracts
- [requirements-catalog.md](requirements-catalog.md) — Structured requirements with IDs
- [test-strategy.md](test-strategy.md) — Test hierarchy and system test catalog
- [provisioning-token.md](provisioning-token.md) — Provisioning token design (HMAC auth for pull-mode spec fetch)
- [gap-analysis.md](gap-analysis.md) — Design gap tracking

## Changelog

| Date | Change |
|------|--------|
| 2026-02-13 | Sprint #243 (Branch Propagation): ST-4 unblocked — `--self-addr` fix (iac-driver#200); update status and gap table |
| 2026-02-11 | Sprint #231 (Provisioning Token): Update pull/hybrid execution sequences for token flow; update ST-1 steps for HMAC token auth; update ST-5 for token minting; update config phase row in execution model table; add provisioning-token.md to related docs |
| 2026-02-08 | Terminology: controller → server in architecture diagram (aligns with server-daemon.md); add server-daemon.md to Related Documents |
| 2026-02-07 | Align with updated epics: Status → Active; manifest v1/v2 framing updated (v2 is current, v1 is legacy); phased implementation adds release status; #113/#120 marked complete; ST-1/ST-2 assertions updated (config phase implemented) |
| 2026-02-07 | Update paths: v2/ consolidated to top-level (specs/, postures/, presets/, defs/) per site-config#53 |
| 2026-02-07 | ST-1 available (Sprint #201 delivered config phase); update pull mode text |
| 2026-02-06 | Update for scenario consolidation (#195): mark `TofuApply/DestroyRemoteAction` retired; update legacy scenarios table to current verb commands |
| 2026-02-05 | Update CLI examples to verb-based pattern (`./run.sh create -M X -H host`); remove `--manifest X --action Y` references; rename "manifest executor" to "operator" |
| 2026-02-03 | Rename to node-orchestration.md; add reading order guidance; apply terminology framework (driver/target, parent/child node, host/guest); update cross-references to node-lifecycle.md |
| 2026-02-03 | Rename to orchestration-architecture.md; terminology updates (hierarchical→tiered, constellation→federated, 6 phases→4 phases); add obsolete terms section |
| 2026-02-03 | Add epic #140, related issues analysis, implementation relationship |
| 2026-02-02 | Initial draft from design discussion |
