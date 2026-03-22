# Roadmap

Strategic direction for homestak-dev, established after v0.53.

See also:
- `$HOMESTAK_ROOT/user-journey.md` — Full user journey and org architecture vision
- [repo-prototype.md](standards/repo-prototype.md) — Standard repo structure for new repos

## Current State (v0.53)

The platform reliably provisions and configures PVE infrastructure:

- **Bootstrap**: curl|bash installs the full stack on any Debian host
- **PVE setup**: Debian → fully configured Proxmox VE in one command
- **VM provisioning**: Declarative manifests create VMs with specs and presets
- **Multi-level topologies**: PVE-in-PVE delegation up to 3 levels deep
- **Push and pull config**: VMs configured via SSH or self-configuring via cloud-init
- **Custom images**: Packer-built Debian/PVE images with 16s boot times

53 releases of infrastructure work. The foundation is solid.

## The Pivot

The infrastructure layer is a means to an end. The vision is **applications** — Home Assistant, Jellyfin, Vaultwarden, and other homelab staples. Further infrastructure polish has diminishing returns without a real workload driving requirements. The app layer becomes both the goal and the proving ground for remaining infrastructure gaps.

## The User Journey

```
bare-metal → bootstrap → site-config → (IaC engine) → apps
   Day 0        Day 1       Identity      Platform     The point
   USB→Debian   Debian→     Hosts, keys,  VMs, k8s,    Home Assistant,
                homestak    preferences   storage      Jellyfin, etc.
```

site-config is the glue — the only repo that's different for every user. Everything else is the same code, run through the lens of your site-config:

```
bare-metal  reads site-config → which host am I imaging?
bootstrap   reads site-config → what capabilities do I install?
IaC engine  reads site-config → what VMs, what topology?
apps        reads site-config → what apps, what settings?
```

## Org Architecture (Target)

The user journey maps to an org structure. Each org serves a different audience:

| Org | Purpose | Audience |
|-----|---------|----------|
| **homestak** | The product (user's front door) | End users |
| **homestak-apps** | Self-hosted applications | App contributors |
| **homestak-iac** | Infrastructure automation engine | IaC developers |
| **homestak-dev** | Developer experience and process | Core maintainers |
| **homestak-com** | Commercial layer (monitoring, backup, support) | Customers |

### homestak (user-facing)

Purpose-driven names, no jargon:

| Repo | Role | Status |
|------|------|--------|
| `bare-metal` | Day 0: bare hardware → Debian (preseed/autoinstall) | Local repo, no remote yet |
| `bootstrap` | Day 1: Debian → homestak platform | In homestak-dev, will migrate |
| `site-config` | Your homelab identity and preferences (template repo) | In homestak-dev, will migrate |

### homestak-apps (the payoff)

Different contributor profile than IaC — someone who knows Home Assistant config isn't necessarily a Tofu person. Apps release independently from the platform.

One repo per app from the start — no monorepo migration later:

```
homestak-apps/pihole
homestak-apps/jellyfin
homestak-apps/home-assistant
homestak-apps/homarr
homestak-apps/monitoring       # prometheus + grafana
```

Each repo contains the app's spec, ansible role, and documentation. Consistent structure enables community contribution ("add your favorite app").

### homestak-iac (the engine)

Users don't interact directly — iac-driver orchestrates these. Tool names are appropriate because the audience knows the tools:

| Repo | Role |
|------|------|
| `iac-driver` | Orchestration engine |
| `packer` | VM image building |
| `tofu` | VM provisioning |
| `ansible` | Host configuration |

### homestak-dev (the workshop)

Release automation, AI skills, lifecycle process, CI templates:

| Repo | Role |
|------|------|
| `.claude` | Claude Code skills and configuration |
| `.github` | CI/CD, org config |
| `homestak-dev` | CLAUDE.md, scripts/, docs/, gita root |

### Maturity Path

| Phase | What changes |
|-------|-------------|
| **Now** | Everything in homestak-dev (9 repos) |
| **Walk** | Create `homestak`, `homestak-apps`, and `homestak-iac` orgs. Move repos to their target orgs. homestak-dev shrinks to 3 repos (homestak-dev, .claude, .github). |
| **Run** | Add `homestak-com` for commercial layer. |

The "walk" step creates all three orgs at once — the marginal cost of standing up homestak-iac alongside homestak and homestak-apps is low (same bot tokens, rulesets, CI setup work). This takes homestak-dev from 9 repos to 3, and each org is focused and legible.

**Trigger:** Do the org split when we're ready to create the first app repo. That way bare-metal, pihole, and all new repos are born in the right place.

See [repo-prototype.md](standards/repo-prototype.md) for standard repo structure across all orgs.

## Phase 0: Foundation (before first app)

Decisions and setup work required before building apps:

| Item | Type | Description |
|------|------|-------------|
| Container strategy | Design decision | Docker Compose per VM, native packages, or hybrid? Blocks spec schema and role design. |
| App repo contract | Design decision | What's inside an app repo? How does iac-driver discover and consume it? See [repo-prototype.md](standards/repo-prototype.md). |
| Static IP verification | Smoke test | Verify `ip`/`gateway` fields work end-to-end in manifests. Pihole needs a known address. |
| Org split | Administrative | Create `homestak`, `homestak-apps`, `homestak-iac` orgs. Migrate existing repos. Push `bare-metal`. |
| Release tooling | Engineering | Update `release.sh` for multi-org releases (or per-org release independence). |

## Phase 1: Homelab Starter (next)

A single manifest that deploys a working homelab with common services:

```yaml
# manifests/homelab-starter.yaml (conceptual)
nodes:
  - name: dns
    spec: pihole
    preset: vm-xsmall

  - name: media
    spec: jellyfin
    preset: vm-medium

  - name: home
    spec: homeassistant
    preset: vm-small

  - name: monitor
    spec: monitoring        # prometheus + grafana
    preset: vm-small

  - name: dashboard
    spec: homarr
    preset: vm-xsmall
```

**Success criteria:** `./run.sh manifest apply -M homelab-starter -H srv1` produces working services reachable by name from the LAN.

### New work required

| Component | Description |
|-----------|-------------|
| App specs | Extend spec schema to express services (packages, containers, config files) |
| App ansible roles | `homestak.apps.pihole`, `homestak.apps.jellyfin`, etc. |
| Backup scheduling | `vzdump`-based VM backups (PVE-native, low complexity) |
| Manifest dependencies | Deploy ordering (pihole before others for DNS) |

### What already exists

- Manifest graph with topological ordering
- Spec-to-ansible-vars mapping (`spec_to_ansible_vars()`)
- Push/pull config modes
- VM presets for resource sizing
- Packer images with fast boot

## Phase 2: Networking and Access (driven by Phase 1)

These capabilities emerge naturally as apps are deployed:

| Capability | Trigger |
|-----------|---------|
| Reverse proxy | First time you type an IP:port instead of a hostname |
| TLS certificates | Rides on reverse proxy (Let's Encrypt or internal CA) |
| Internal DNS | Pihole itself — deployed as the first node |
| Spec schema evolution | "Run this docker-compose" forces schema extensions |

Don't design these in advance. Let the app manifest surface the exact requirements.

## Phase 3: Operational Maturity (following Phase 1)

Once apps are running and lived on:

| Capability | Issue | Why later |
|-----------|-------|-----------|
| App updates / run phase | iac-driver#171 | MVP is "deploy once"; convergence matters once you're living on it |
| Config reconciliation | homestak-dev#298 | Design is better informed by real drift scenarios |
| Command broadcast (`exec`) | iac-driver#170 | Useful for fleet operations, not single-host MVP |
| Remote access (VPN/Tailscale) | — | LAN-first; external access is a scaling concern |
| Multi-user access | bootstrap#86 | One operator is fine for now |

## Phase 4: Scale and Resilience (future)

| Capability | Issue |
|-----------|-------|
| High availability | — |
| Proxmox Backup Server | homestak-dev#136 |
| Storage management (ZFS/Ceph) | — |
| SDN / VXLAN networking | iac-driver#28 |
| Multi-site deployment | — |
| GCP / cloud deployments | homestak-dev#135 |

## Anticipate vs. Emerge

| Timing | Capabilities |
|--------|-------------|
| **Anticipate** (build proactively) | Backup scheduling, internal DNS (pihole) |
| **Emerge** (let apps drive) | Reverse proxy, TLS, observability, spec extensions |
| **Follow** (build after living on apps) | Run phase, reconciliation, updates, remote access |
| **Future** (scaling concerns) | HA, PBS, multi-site, cloud |

