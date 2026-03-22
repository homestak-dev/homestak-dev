# Operations Guide

Day-to-day operational tasks for managing homestak infrastructure.

## Updating Code on Target Hosts

After merging changes to master, update all installed repos on a target host:

```bash
ssh user@srv1 'sudo -u homestak homestak update'
```

Preview what will be updated before applying:

```bash
ssh user@srv1 'sudo -u homestak homestak update --dry-run'
```

Do NOT cherry-pick `git pull` on individual repos. `homestak update` is the
correct deployment method -- it updates all installed repos and handles any
post-update hooks.

## Adding a New PVE Host

### 1. Bootstrap

On a fresh Debian 13 host (with sudo access or as root):

```bash
curl -fsSL https://raw.githubusercontent.com/homestak/bootstrap/master/install | sudo bash
```

This creates the `homestak` user, clones repos, and adds the CLI to PATH.

### 2. Configure Site Defaults

```bash
sudo -iu homestak
sed -i 's/gateway: ""/gateway: "192.0.2.1"/' ~/config/site.yaml
sed -i 's/dns_servers: \[\]/dns_servers: ["192.0.2.1"]/' ~/config/site.yaml
```

### 3. Initialize and Set Up PVE

```bash
homestak site-init       # generates host config, SSH key
homestak pve-setup       # installs PVE, configures host
```

Note: `pve-setup` reboots after kernel install on a fresh Debian host. After
reboot, run `sudo -iu homestak` and re-run `homestak pve-setup`.

### 4. Download Packer Images

```bash
homestak images download all --publish
```

This downloads pre-built Debian and PVE cloud images from GitHub releases and
publishes them to the PVE host's local storage.

## Provisioning VMs

All VM provisioning goes through iac-driver manifests. Run as homestak from
`~/iac/iac-driver`:

```bash
./run.sh manifest apply -M n1-push -H srv1              # create VMs
./run.sh manifest apply -M n1-push -H srv1 --dry-run    # preview only
./run.sh manifest test -M n1-push -H srv1 --verbose     # create + verify + destroy
./run.sh manifest destroy -M n1-push -H srv1 --yes      # tear down
./run.sh manifest validate -M n1-push -H srv1           # preflight only
```

`-M` specifies a manifest from `config/manifests/`. `-H` specifies the target
PVE host from `config/hosts/`.

## Server Daemon

The iac-driver server provides spec serving, git repo mirroring, and bootstrap
endpoints. After code changes, restart to pick up new code:

```bash
cd ~/iac/iac-driver
./run.sh server start / stop / status
```

## Rotating Secrets

Secrets are stored encrypted in `config/secrets.yaml` using SOPS + age.

```bash
cd ~/config

# Decrypt for editing
make decrypt

# Edit secrets.yaml (API tokens, SSH keys, passwords)
$EDITOR secrets.yaml

# Re-encrypt
make encrypt

# Commit the encrypted file
git add secrets.yaml.enc
git commit -m "chore: Rotate API token for srv1"
```

After committing, update target hosts:

```bash
ssh user@srv1 'sudo -u homestak homestak update'
```

## Smoke Testing

Run a quick smoke test to verify a host is working correctly:

```bash
ssh user@srv1 'sudo -u homestak bash -c "
  cd ~/iac/iac-driver && ./run.sh manifest test -M n1-push -H srv1 --verbose
"'
```

This creates a VM, verifies it boots and is reachable, then destroys it. It
exercises the full stack: config resolution, tofu provisioning, cloud-init,
and ansible configuration.

## Common Flags

| Flag | Purpose |
|------|---------|
| `--dry-run` | Preview without executing |
| `--verbose` | Detailed logging |
| `--json-output` | Structured JSON to stdout |
| `--skip-preflight` | Bypass preflight checks |
| `--yes` | Skip confirmation prompts (for destructive ops) |

## Host Access Pattern

Always SSH as your operator user, then `sudo -u homestak` for platform ops.
Never SSH as root. The `homestak` user owns all platform files and ansible
roles handle privilege escalation internally via `become`.
