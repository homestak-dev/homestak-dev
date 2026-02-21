# User Acceptance Testing

Internal validation checklist for verifying homestak on a fresh Debian 13 host.

## Prerequisites

- Fresh Debian 13 (Trixie) installation
- Root access
- Internet connection
- QEMU/KVM with nested virtualization enabled

## Setup

```bash
# 1. Bootstrap
curl -fsSL https://raw.githubusercontent.com/homestak-dev/bootstrap/master/install.sh | bash

# 2. Configure site defaults for your network
sudo vi /usr/local/etc/homestak/site.yaml
# Required: defaults.gateway, defaults.dns_servers
# Optional: defaults.domain (e.g., home.arpa)

# 3. Initialize site configuration (generates host config, SSH key)
sudo homestak site-init

# 4. Install PVE + configure host (generates API token, signing key, node config)
# Note: On fresh Debian, pve-setup reboots after kernel install.
#       Re-run the same command after reboot to complete setup.
sudo homestak pve-setup

# 5. Download and publish packer images
sudo homestak images download all --publish
```

## Test Suite

Run from the host console:

```bash
cd /usr/local/lib/homestak/iac-driver
sudo ./run.sh manifest test -M n1-push -H $(hostname -s) --verbose
sudo ./run.sh manifest test -M n1-pull -H $(hostname -s) --verbose
sudo ./run.sh manifest test -M n2-tiered -H $(hostname -s) --verbose
sudo ./run.sh manifest test -M n2-mixed -H $(hostname -s) --verbose
sudo ./run.sh manifest test -M n3-deep -H $(hostname -s) --verbose
```

## Test Descriptions

| Manifest | Pattern | Description |
|----------|---------|-------------|
| n1-push | flat | Single VM, push-mode config |
| n1-pull | flat | Single VM, pull-mode config (cloud-init self-configures) |
| n2-tiered | tiered | PVE VM + leaf VM (push mode) |
| n2-mixed | tiered | PVE VM (push) + leaf VM (pull) |
| n3-deep | tiered | 3-level nesting: PVE → PVE → VM |

## Preflight Checks

The test suite runs automatic preflight validation before starting. It catches:

- Empty `gateway` or `dns_servers` in site.yaml (error)
- Empty `domain` in site.yaml (warning, non-blocking)
- Missing SSH keys in secrets.yaml (error)
- Missing packer images in PVE storage (error)
- API token and host connectivity issues (error)

## Re-running UAT

To reset and re-run on an existing host (e.g., after code changes):

```bash
# Pull latest code
sudo homestak update

# Reset site-config to clean state and re-initialize from templates
sudo rm -f /usr/local/etc/homestak/site.yaml /usr/local/etc/homestak/secrets.yaml
sudo make -C /usr/local/etc/homestak init-site init-secrets

# Continue with Setup steps 2-6
```

## Troubleshooting

- **"gateway not configured"** — edit site.yaml: `defaults.gateway`
- **"dns_servers not configured"** — edit site.yaml: `defaults.dns_servers`
- **"No SSH keys in secrets.yaml"** — run `sudo homestak site-init`
- **"Packer image not found"** — run `sudo homestak images download all --publish`
- **"Unknown host"** — ensure `homestak pve-setup` completed (generates nodes/*.yaml)
- **Permission denied** — use `sudo` (see bootstrap#75 for future improvement)
