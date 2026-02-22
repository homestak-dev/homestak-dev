# Bare-Metal ISO Installer

**Epic:** [bootstrap#5](https://github.com/homestak-dev/bootstrap/issues/5)
**Status:** Design
**Date:** 2026-02-14
**Related:** [node-lifecycle.md](node-lifecycle.md), [spec-client.md](spec-client.md), [config-phase.md](config-phase.md)

## Overview

A bootable ISO that installs Debian with homestak pre-configured, enabling "plug and play" homelab deployment. The ISO is a **Debian installer**, not a PVE installer — PVE is optional, selected via spec at install time.

The key architectural insight: this is a **packaging problem**, not a platform problem. The pull-mode self-configuration infrastructure already exists. The ISO simply needs to get Debian + homestak installed, then existing infrastructure handles the rest.

## User Journey

### Current (without ISO)

```
Fresh machine
  → Manual Debian install (USB, 15-20 min)
  → SSH in
  → curl | bash install.sh
  → homestak site-init
  → homestak pve-setup (if desired)
```

### With ISO

```
Fresh machine
  → Boot ISO (answers prompts automatically or interactively)
  → Reboot into Debian + homestak CLI ready
  → (If spec=pve) PVE installs automatically via pull-mode
```

The ISO eliminates manual Debian installation and the SSH-in-and-bootstrap step.

## Install Prompts

| Prompt | Default | Notes |
|--------|---------|-------|
| Hostname | — | Required |
| Disk | First disk | ZFS root (default, no prompt) |
| Network | DHCP | Or static IP/gateway/DNS |
| Root password | — | Required |
| SSH public key URL | (optional) | e.g., `https://github.com/{username}.keys` |
| Spec | base | `base` (general-purpose) or `pve` (Proxmox VE) — or a URL to a custom spec |
| Posture | dev | `dev` (permissive) or `prod` (hardened) |

**Design decisions:**
- **ZFS is the default** — no prompt needed. ZFS provides snapshots, compression, and data integrity. There's no good reason to choose ext4 for a homelab.
- **SSH key URL** — fetching from hosted providers (GitHub, GitLab) eliminates the need to paste keys during installation. Non-fatal if URL is unreachable.
- **Spec as name or URL** — local specs (`base`, `pve`) work offline. URL specs enable custom/curated specs from external sources (including future homestak-com catalog).
- **Posture** — collected at install time because posture fields are all static values (no FK resolution needed), enabling single-pass config apply.

## Architecture

### Scope Boundary

The ISO handles the **create phase** only. The **config phase** is handled by existing pull-mode infrastructure.

```
ISO Installer (create)                Pull-Mode (config)
┌──────────────────────────┐          ┌──────────────────────────┐
│ Debian preseed            │          │ First boot                │
│ ├── ZFS root partition    │          │ ├── cloud-init / runcmd   │
│ ├── Base Debian packages  │ reboot  │ ├── homestak spec get     │
│ ├── install.sh            │────────▶│ ├── spec FK resolution    │
│ └── site-init             │          │ ├── ansible apply         │
│     ├── --ssh-key-url     │          │ └── config-complete       │
│     ├── --spec            │          └──────────────────────────┘
│     └── --posture         │
└──────────────────────────┘
```

### What the ISO Does NOT Do

- Install PVE (that's the config phase, driven by spec)
- Configure applications (that's the run phase, future scope)
- Manage secrets beyond auto-generation (age key, signing key are auto-created)
- Require network at boot (ZFS + preseed work offline; network needed only for bootstrap clone)

### Lifecycle Phase Mapping

| ISO Activity | Lifecycle Phase | Mechanism |
|-------------|----------------|-----------|
| Debian install + partitioning | create | Preseed |
| Package installation | create | Preseed |
| Bootstrap clone + site-init | create | Preseed late_command |
| SSH key import | create | site-init --ssh-key-url |
| Spec selection | create | site-init --spec |
| Posture selection | create | site-init --posture |
| PVE installation | config | Pull-mode (spec=pve) |
| Security hardening | config | Pull-mode (posture) |
| User creation | config | Pull-mode (spec) |

## Component Design

### Unified spec get

`spec get` is refactored to accept any URL with contextual auth. This unifies server-daemon fetch and plain-URL fetch into one command:

```bash
homestak spec get <url>                    # Plain URL, no auth
homestak spec get <url> --token <token>    # URL with auth (server daemon)
homestak spec get                          # Env fallback: HOMESTAK_SERVER + HOMESTAK_TOKEN
```

The `--server` named flag is removed in favor of a positional URL argument. The server daemon is just "a URL that requires a token."

**Backward compatibility:** The env var path (`HOMESTAK_SERVER` + `HOMESTAK_TOKEN`) continues to work unchanged. This is the automated path used by cloud-init runcmd.

### site-init Enhancements

New flags for `homestak site-init`:

```bash
homestak site-init \
  --ssh-key-url https://github.com/<github-user>.keys \
  --spec pve \
  --posture dev
```

**Flag behavior:**

| Flag | Value Type | Behavior |
|------|-----------|----------|
| `--ssh-key-url <url>` | URL | Fetch SSH public keys (one per line), inject via `add-ssh-key.py` |
| `--spec <name-or-url>` | Name or URL | Name → use local `specs/{name}.yaml`. URL → call `spec get <url>`, save to `specs/` |
| `--posture <name>` | Name | Select security posture for downstream config |

**Spec inference:** If the `--spec` value starts with `http://` or `https://`, treat as URL. Otherwise, treat as local spec name.

**Error handling:** All URL fetches are non-fatal. Network failures produce a warning but don't block site-init completion. The user can retry or manually provide resources later.

### SSH Key Flow

```
--ssh-key-url https://github.com/<github-user>.keys
       │
       ▼
  curl -fsSL <url>
       │
       ▼
  Parse: one key per line
       │
       ▼
  For each key:
       ├── Extract key_id from comment field (field 3)
       ├── Fallback key_id: hosted-key-N
       └── Call add-ssh-key.py (dedup, safe YAML write)
              │
              ▼
        secrets.yaml → ssh_keys section
```

GitHub's `/username.keys` endpoint returns all public keys, one per line. Keys typically include a comment field (e.g., `ssh-ed25519 AAAA... user@host`). The comment becomes the key identifier in `secrets.yaml`.

### Preseed Template

The Debian preseed automates the installer. Key sections:

```
# Partitioning: ZFS root
d-i partman-auto/method string zfs
d-i partman-auto-zfs/guided_size string max

# Network
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string <from-prompt>

# Packages
d-i pkgsel/include string git make curl

# Post-install: bootstrap + site-init
d-i preseed/late_command string \
  in-target bash -c ' \
    curl -fsSL https://raw.githubusercontent.com/homestak-dev/bootstrap/master/install.sh | \
    HOMESTAK_SPEC=<spec> HOMESTAK_POSTURE=<posture> HOMESTAK_SSH_KEY_URL=<url> bash \
  '
```

**Note:** The preseed template is a starting point. Debian's ZFS root support via preseed is limited — `debootstrap` + manual ZFS setup in `late_command` may be needed. This is an implementation detail for sub-issue C.

### ISO Build Pipeline

```
Debian netinst ISO (upstream)
       │
       ▼
  xorriso: extract, inject preseed, rebuild
       │
       ▼
  homestak ISO (~350MB)
       │
       ▼
  GitHub Release asset
```

The build script takes a Debian netinst ISO, injects the preseed configuration and any required files, and produces a remastered ISO. UEFI + BIOS boot support required.

## What Already Exists

| Component | Location | Status |
|-----------|----------|--------|
| `install.sh` | bootstrap | Done |
| `site-init` | bootstrap/homestak.sh | Done |
| `add-ssh-key.py` | bootstrap/scripts | Done |
| `spec get` (server daemon) | bootstrap/lib/spec_client.py | Done (needs refactoring for any-URL) |
| Pull-mode self-config | iac-driver | Done |
| Specs + postures | site-config | Done |
| Server daemon | iac-driver | Done |
| Provisioning tokens | iac-driver/config_resolver | Done |

## Sub-Issues

| ID | Title | Issue | Deps | Description |
|----|-------|-------|------|-------------|
| AB | Add URL-based resource fetching to site-init | [#60](https://github.com/homestak-dev/bootstrap/issues/60) | — | Refactor spec get (any URL, contextual auth), add `--ssh-key-url`, `--spec`, `--posture` to site-init |
| C | Create Debian preseed template | — | AB | Automate Debian installer: ZFS root, hostname, disk, network, password |
| D | Inject homestak bootstrap into preseed late_command | — | C | late_command runs install.sh + site-init with collected values |
| E | Build ISO packaging script | — | D | xorriso-based remaster of Debian netinst |
| F | Add ISO build CI workflow | — | E | GitHub Actions to build ISO on release or on-demand |

**AB** is a building block with standalone value.
**C-F** are ISO-specific.

## Considerations

### Hardware Support

- **UEFI + BIOS:** Both required for homelab hardware diversity. The remastered ISO must preserve both boot paths from the upstream Debian netinst.
- **ZFS root:** Requires `contrib` apt component. Debian's installer supports ZFS root natively since Bookworm (with caveats).
- **Drivers:** Upstream Debian netinst includes firmware since Bookworm. No custom driver injection needed for most homelab hardware.

### Network Requirements

- **Online-only for v1:** Bootstrap requires `git clone` from GitHub. Offline mode (embedded repos) is a future enhancement.
- **DHCP preferred:** Simplest path. Static IP requires additional prompts (IP, gateway, DNS).

### Security

- **Age key:** Auto-generated during site-init. No user input needed.
- **Signing key:** Auto-generated during site-init. Used for provisioning tokens.
- **SSH keys:** Optionally fetched from URL. If no URL provided, only the locally-generated key is injected.
- **Root password:** Collected via preseed prompt. Hashed before storage.
- **Secrets at rest:** SOPS + age encryption set up by site-init.

### Future Extensions

- **Curated spec catalog:** homestak-com hosts specs for popular applications (Home Assistant, Jellyfin, Vaultwarden). Users select from a menu or paste a URL.
- **Offline mode:** Embed git repos in the ISO for air-gapped installations.
- **Auto-discovery:** Multicast/mDNS to find existing homestak infrastructure on the network.
- **Fleet provisioning:** Boot multiple machines from the same ISO, each discovering its role from a central server.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| ZFS preseed complexity | High | Medium | Fallback to debootstrap + manual ZFS in late_command |
| UEFI/BIOS dual boot | Medium | High | Test on real hardware early (not just QEMU) |
| ISO size creep | Low | Low | Start from netinst (~350MB), monitor size |
| Upstream Debian changes | Low | Medium | Pin to specific Debian release (Bookworm initially) |
| Network unavailable at install | Medium | Medium | Clear error message; offline mode as future work |

## Test Strategy

| Level | What | How |
|-------|------|-----|
| Unit | site-init flags, spec get refactoring | bats tests (bootstrap) |
| Integration | Full ISO boot | QEMU: boot ISO, verify homestak CLI available |
| Smoke | End-to-end with spec | QEMU: boot ISO with spec=pve, verify PVE installs |
| Hardware | Real machine install | Manual test on homelab hardware |

## Related Documents

- [node-lifecycle.md](node-lifecycle.md) — 4-phase lifecycle model (create/config/run/destroy)
- [config-phase.md](config-phase.md) — Config phase implementation (push/pull modes)
- [spec-client.md](spec-client.md) — Current spec get client design (to be refactored)
- [server-daemon.md](server-daemon.md) — Server daemon architecture
- [provisioning-token.md](provisioning-token.md) — HMAC token format for config phase auth
