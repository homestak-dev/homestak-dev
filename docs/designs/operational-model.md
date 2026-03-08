# Operational Model

How homestak executes, where state lives, and how config flows between hosts.

This document unifies the execution model, state architecture, and node lifecycle into a single reference. It builds on [node-lifecycle.md](node-lifecycle.md), [config-phase.md](config-phase.md), and [config-distribution.md](config-distribution.md).

## Execution Models

iac-driver has three execution contexts:

| Context | Runs where | Reaches out via | `-H` flag |
|---------|-----------|-----------------|-----------|
| **Scenario** | Locally on the host being configured | Nothing (local ansible) | Optional — auto-detects from hostname |
| **Manifest** | Anywhere (orchestrator) | PVE API (HTTPS) + SSH to VMs | Required — specifies target PVE host |
| **Config** | Locally on the VM being configured | Server (HTTPS fetch), then local ansible | Not used |

### Scenarios (local)

Scenarios (pve-setup, user-setup) configure the machine they run on. They invoke ansible with `connection: local`. Run on the PVE host as the `homestak` user.

```
pve-host$ ./run.sh scenario run pve-setup
  → ansible-playbook runs locally
  → configures THIS machine
```

`-H` is optional because the host is auto-detected from `hostname()` matching a `nodes/*.yaml` entry. Specify `-H` only when the hostname doesn't match (e.g., during initial setup before node config exists).

### Manifests (orchestrator)

Manifest commands (apply, destroy, test) orchestrate infrastructure. They call the PVE API over HTTPS to provision/destroy VMs and SSH to VMs for config push. They can run from any machine with API access and SSH keys.

```
any-host$ ./run.sh manifest test -M n1-push -H father
  → calls PVE API on father (HTTPS)
  → tofu provisions VM
  → SSHes to VM for config push
  → tofu destroys VM
```

`-H` is required because it specifies which PVE host config to load (API endpoint, token, datastore).

### Config (pull + local)

Config commands (fetch, apply) are the pull-mode self-configuration path. A VM fetches its spec from the server over HTTPS, then applies it locally with ansible.

```
vm$ ./run.sh config fetch --insecure
  → GET /spec/{identity} from server
vm$ ./run.sh config apply
  → ansible-playbook runs locally
```

Triggered by cloud-init on first boot (pull mode) or by the operator over SSH (push mode).

## State Architecture

### The problem: authored vs generated state

site-config mixes two fundamentally different types of data in a single directory:

**Authored state** — human-written, belongs in git, same across all hosts:
- `site.yaml` (defaults: timezone, packages, DNS)
- `postures/*.yaml` (security postures)
- `presets/*.yaml` (VM sizes)
- `specs/*.yaml` (node specifications)
- `manifests/*.yaml` (deployment topologies)
- `defs/*.schema.json` (JSON schemas)
- `secrets.yaml` authored entries (SSH keys, passwords)

**Generated state** — machine-produced, host-specific, should NOT be in git:
- `nodes/*.yaml` (from `make node-config` or pve-setup)
- `hosts/*.yaml` (from `make host-config`)
- `secrets.yaml` generated entries (API tokens, signing key)
- `state/config-complete.json` (config phase marker)

### Current layout (mixed)

```
~/etc/                          ← site-config repo clone
├── site.yaml                   ← authored (gitignored, from .example or .enc)
├── secrets.yaml                ← MIXED: authored keys + generated tokens
├── postures/                   ← authored
├── presets/                    ← authored
├── specs/                      ← authored
├── manifests/                  ← authored
├── nodes/hostname.yaml         ← generated (gitignored)
├── hosts/hostname.yaml         ← generated (gitignored)
└── state/
    └── config-complete.json    ← generated
```

The mixing of authored and generated data in `secrets.yaml` causes:
- Encrypted merge conflicts when two hosts generate API tokens concurrently
- No clear sync direction (authored flows down from git, generated flows... nowhere)
- Config drift between host copies

### Future layout (separated)

```
~/etc/                          ← authored config (git-tracked, pulled)
├── site.yaml
├── secrets.yaml                ← authored secrets ONLY (SSH keys, passwords)
├── postures/
├── presets/
├── specs/
├── manifests/
└── defs/

~/etc/state/                    ← generated state (local, per-host, never in git)
├── nodes/hostname.yaml
├── hosts/hostname.yaml
├── secrets.yaml                ← generated secrets (API tokens, signing key)
└── config-complete.json
```

- **Authored config** syncs via `git pull`. Same everywhere. No merge conflicts.
- **Generated state** stays local. Each host owns its own. No sync needed.
- **ConfigResolver** merges both layers at runtime (authored + generated).

## Node Lifecycle

Excluding the "run" phase (drift detection, convergence — future work).

### Leaf VM (simple case)

```
CREATE (orchestrator, anywhere)
├── reads authored config (manifests, presets, specs) from git
├── reads authored secrets (SSH keys, passwords) from git
├── tofu provisions VM via PVE API
└── cloud-init injects identity + auth token

CONFIG (push or pull)
├── push: operator SSHes to VM, runs ansible with resolved authored config
└── pull: VM fetches spec from server, applies locally
└── result: ~/etc/state/config-complete.json (generated, local)

DESTROY (orchestrator, anywhere)
├── tofu destroys VM via PVE API
└── generated state disappears with the VM
```

No generated state escapes the VM. No reconciliation needed.

### PVE node (complex case)

#### Current: 11 phases, parent-driven

```
Parent does everything via SSH:
  1. bootstrap            ─┐
  2. copy_secrets (SCP)    │ push
  3. copy_site_config      │
  4. inject_ssh_key        │
  5. copy_private_key     ─┘
  6. pve-setup            ─┐
  7. configure_bridge      │ parent SSHes in
  8. generate_node_config  │ and runs commands
  9. create_api_token      │ (8-9 redundant with pve-setup)
  10. inject_self_ssh_key  │
  11. download_images     ─┘
```

Parent micro-manages every step. Generated state (node config, API token) is created by the parent on the child via SSH.

#### Future: bootstrap then self-configure

```
PHASE 1 — Parent pushes (child has nothing yet):
├── bootstrap (clone repos, create homestak user)
└── copy private key (provider SSH-to-self, can't be pulled)

PHASE 2 — Child pulls authored config:
└── GET /config/{identity} from parent's server
    ├── authored secrets (SSH keys, passwords, signing key)
    └── authored site config (site.yaml defaults)

PHASE 3 — Child self-configures:
└── enriched pve-setup does everything:
    ├── install PVE + configure repos
    ├── configure bridge
    ├── generate node config     → ~/etc/state/nodes/
    ├── create API token         → ~/etc/state/secrets.yaml
    ├── inject self SSH key
    └── download packer images
└── signals completion (marker file, parent polls)
```

Parent goes from micro-managing (11 SSH phases) to bootstrapping then observing. Generated state is created locally by the child, stored in `~/etc/state/`, and never needs to flow back to the parent.

## Config Distribution

### Tiered deployments (parent → child)

Today: SCP push (`copy_secrets`, `copy_site_config`).

Future (iac-driver#248): Child pulls from parent's `/config/{identity}` endpoint. Authenticated via provisioning token. Server serves authored secrets (scoped — no `api_tokens`) and site defaults.

The `/config` endpoint is the pull-mode equivalent of the current SCP push, using the same server that already serves specs and git repos.

### Flat deployments (peer → peer)

No automated mechanism today. Each root host is an island.

With the authored/generated separation, the problem shrinks: authored config syncs via git (already works). Generated state stays local (no sync needed). The remaining gap is operational visibility — knowing what generated state exists across hosts.

See [homestak-dev#298](https://github.com/homestak-dev/meta/issues/298) for the full analysis and possible directions.

## Related

| Document | Relationship |
|----------|-------------|
| [node-lifecycle.md](node-lifecycle.md) | Single-node lifecycle phases (create/config/run/destroy) |
| [config-phase.md](config-phase.md) | Push/pull execution, spec-to-ansible mapping |
| [config-distribution.md](config-distribution.md) | Config distribution to delegated PVE nodes |
| [node-orchestration.md](node-orchestration.md) | Topology patterns, manifest schema |
| [server-daemon.md](server-daemon.md) | Server architecture (spec/repo/config serving) |

| Issue | Relationship |
|-------|-------------|
| [iac-driver#248](https://github.com/homestak-iac/iac-driver/issues/248) | `/config` endpoint for pull-mode distribution (building block) |
| [iac-driver#275](https://github.com/homestak-iac/iac-driver/issues/275) | Operator simplification, PVE lifecycle rebalancing (phase 3) |
| [homestak-dev#298](https://github.com/homestak-dev/meta/issues/298) | Config reconciliation for distributed site-config |
