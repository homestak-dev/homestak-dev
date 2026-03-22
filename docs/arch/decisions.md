# Architecture Decision Records

Accumulated design decisions for the homestak platform. Each records the
context, options considered, and rationale for the choice made.

## ADR-1: Polyrepo over Monorepo

**Context:** The platform spans bare-metal imaging, bootstrap, config management,
orchestration, provisioning, host configuration, and image building. These
components have different release cadences, technology stacks, and contributor
profiles.

**Decision:** Each component is its own git repository, organized into GitHub
organizations by audience (homestak, homestak-iac, homestak-dev, homestak-apps).

**Rationale:**
- Independent versioning: iac-driver can release without touching tofu or ansible
- Org-based access control: IaC contributors need write to homestak-iac, not
  to bootstrap or config
- Component independence: each repo installs its own dependencies via
  `make install-deps` with no shared build system
- CI isolation: a failing packer test does not block an ansible PR
- Clear ownership boundaries: CLAUDE.md per repo scopes agent context

**Trade-offs:** Cross-repo changes require coordinated sprints and multi-repo PR
creation. Unified versioning (all repos tagged at the same version) adds release
overhead. These are managed by the `/sprint` and `/release` skills and the
`scripts/release` CLI.

## ADR-2: gita for Workspace Management

**Context:** With 10+ repos, developers need a way to fetch, status-check, and
run commands across the workspace without custom tooling.

**Decision:** Use [gita](https://github.com/nosarthur/gita) to manage the
polyrepo workspace.

**Rationale:**
- Lightweight: single pip install, no daemon, no config server
- No custom tooling: `gita ll`, `gita fetch`, `gita shell make test` cover
  daily needs out of the box
- Repos registered by absolute path, so the workspace layout is flexible
- Does not impose workflow opinions (branching, merging, releasing)

**Trade-offs:** gita has no dependency graph awareness between repos. Release
ordering and cross-repo coordination are handled by `scripts/release` and the
sprint lifecycle, not by gita itself.

## ADR-3: Unified Versioning Across All Repos

**Context:** With independent repos, each could maintain its own version number.
This creates a matrix of compatible versions that operators must track.

**Decision:** All repos share a single version number. A release tags every repo
at the same version (e.g., v0.57 means all 9 repos at v0.57).

**Rationale:**
- Simplifies support: "what version are you on?" has one answer
- Eliminates compatibility matrices between iac-driver, tofu, ansible, config
- Release CLI (`scripts/release tag`) enforces this automatically
- CHANGELOGs in each repo track what changed in that repo at each version

**Trade-offs:** Repos with no changes still get a new version tag. This is
acceptable for a single-operator project where the alternative (version matrices)
is worse than empty releases.

## ADR-4: Proxmox VE as Virtualization Platform

**Context:** The platform needs a virtualization layer for VM provisioning. Options
include bare QEMU/KVM, Proxmox VE, VMware ESXi, and cloud providers.

**Decision:** Proxmox VE is the primary target, but architecture preserves an
escape hatch to bare Debian with QEMU/KVM.

**Rationale:**
- API-driven: PVE REST API enables programmatic VM lifecycle without SSH scraping
- Web UI: operators get visibility without CLI-only workflows
- Built-in storage (ZFS, LVM) and networking (bridges, SDN) reduce custom
  integration work
- Free and open source, based on Debian (aligns with the Debian-rooted principle)
- bpg/proxmox provider for OpenTofu gives declarative VM provisioning

**Escape hatch:** Design decisions favor Debian primitives over Proxmox-specific
features when practical. The platform is "Debian-rooted, Proxmox-current" --
switching to bare QEMU on Debian is possible without rewriting bootstrap or
ansible fundamentals.

## ADR-5: SOPS + age for Secrets Management

**Context:** The config repo contains secrets (API tokens, SSH keys, passwords)
that must be encrypted at rest in git but decryptable on target hosts.

**Decision:** Use Mozilla SOPS with age encryption. Git hooks auto-encrypt on
commit and auto-decrypt on checkout.

**Rationale:**
- Simple: single binary (sops), single key file (~/.config/sops/age/keys.txt)
- Offline: no server dependency, no network required for encrypt/decrypt
- No infrastructure: unlike HashiCorp Vault, no daemon to run or maintain
- Diff-friendly: SOPS encrypts values, not files, so YAML structure is visible
  in diffs
- age over PGP: simpler key management, no keyserver, no expiration

**Alternatives considered:**
- HashiCorp Vault: too heavy for a homelab, requires its own HA infrastructure
- git-crypt: all-or-nothing file encryption, no partial decryption, no YAML
  awareness
- Plain GPG: complex key management, expiration handling, keyserver dependency

## ADR-6: Claude Code Skills over Custom Scripts

**Context:** Development workflows (sprint management, release coordination,
session persistence) need automation. Options include standalone shell scripts,
Makefiles, or Claude Code skills.

**Decision:** Encode workflow automation as Claude Code skills in
`dev/.claude/skills/`.

**Rationale:**
- Declarative: SKILL.md frontmatter defines name, description, and tool
  permissions in one place
- Version-controlled: skills live in git alongside the code they operate on
- Self-documenting: the skill definition is the documentation
- Context-aware: skills can reference CLAUDE.md, lifecycle docs, and issue
  guidelines without re-encoding that knowledge
- Composable: `/sprint merge` calls git and gh commands, not a custom binary

**Trade-offs:** Skills depend on Claude Code as the execution environment. The
`scripts/release` CLI remains a standalone bash tool for release operations that
must work without an AI assistant. Critical-path automation (tagging, publishing)
does not depend on skills.
