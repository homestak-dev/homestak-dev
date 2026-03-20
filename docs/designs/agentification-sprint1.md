# Homestak Multi-Agent Implementation Plan

**Status:** Complete (meta#356, 2026-03-20)

## Context

This plan adds `.claude/settings.json` permission scoping to the 7 repos that don't
have it yet. `iac-driver` already has a working reference implementation. The workspace-
level `.claude/` (in `homestak-dev/.claude`) provides shared skills and statusline only —
repo-level configs handle permissions.

## Implementation Notes

Executed as a single sprint (`sprint/agent-permissions`) across 9 repos. Key
deviations from the original plan:

- `dev/.claude/settings.json` was updated with granular release allow/deny rules
  (the workspace config governs meta's agent session since meta's `.claude/` is
  the child repo mount point)
- iac-driver got `.gitignore` + CLAUDE.md updates only (settings.json already existed)
- Meta got Agent Boundaries in CLAUDE.md only (not full Ecosystem Context, since
  meta IS the ecosystem reference)

**PRs:** bare-metal#9, bootstrap#111, config#101, ansible#70, tofu#82,
packer#72, iac-driver#319, meta#357, .claude#31

---

## Scope

**In scope:**
- `.claude/settings.json` with `permissions.allow` for each repo
- `settings.local.json` added to each repo's `.gitignore`
- "Ecosystem Context" + "Agent Boundaries" section in each repo's `CLAUDE.md`

**Out of scope (follow-up):**
- Per-repo `statusLine` configuration (cosmetic; defer)
- Multi-agent session orchestration patterns (separate design)
- Changes to iac-driver's existing config (already working)

---

## Key Corrections from Prior Analysis

1. **Schema is `permissions.allow`**, not `allowedTools`. The original plan used the wrong
   key. See `iac-driver/.claude/settings.json` for the correct format.
2. **Drop `Bash(grep:*)`, `Bash(find:*)`, `Bash(cat:*)`** from all configs. Claude Code has
   dedicated Read, Glob, and Grep tools that don't require Bash permissions. Adding Bash
   variants is redundant and loosens the sandbox.
3. **Use absolute paths only** in CLAUDE.md cross-references (`~/homestak/dev/meta/CLAUDE.md`).
   Relative paths vary by repo depth and break.
4. **Single tracking issue + one sprint** instead of 8 issues. This is a uniform pattern
   applied to 7 repos — Simple/Standard tier work, not 8 separate work items.
5. **Use modern space syntax, not deprecated colon syntax.** `Bash(tofu:*)` is deprecated —
   the modern equivalent is `Bash(tofu *)`. For subcommand scoping, `Bash(tofu fmt *)` matches
   `tofu fmt -check` but not `tofu apply`. The space before `*` enforces a word boundary.
6. **Add `deny` rules for critical exclusions.** Omitting a tool from `allow` means it requires
   manual approval. Adding it to `deny` blocks it outright. Use `deny` for the most dangerous
   operations (secrets tooling, state-mutating infra commands) as belt-and-suspenders.

> **Note:** `iac-driver`'s existing config uses the deprecated colon syntax. Migrating it
> to modern syntax is a follow-up, not part of this sprint.

---

## GitHub Issue

One tracking issue in `meta`. Individual repos don't need separate issues — the work is
a single sprint branch touching all repos.

```bash
GH_TOKEN=$HOMESTAK_BOT_TOKEN gh issue create \
  --repo homestak-dev/meta \
  --title "Add .claude/ permission scoping to all repos" \
  --label "enhancement" \
  --body "$(cat <<'EOF'
## Context

Multi-agent analysis identified that 7 repos need `.claude/settings.json` with
`permissions.allow` for scoped Claude Code agent operation. `iac-driver` already
has a working reference implementation.

## Repos

| Repo | Allowed Tools | Excluded (safety) |
|---|---|---|
| `ansible` | ansible-lint, make | ansible-playbook |
| `tofu` | tofu fmt, tofu validate, make | tofu apply/destroy/import |
| `packer` | packer validate, packer fmt, shellcheck, bats, make | ./build, ./publish |
| `bare-metal` | shellcheck, bats, make | ./build, ./reinstall |
| `bootstrap` | shellcheck, pylint, bats, make | ./install, homestak CLI |
| `config` | make validate, make check, yamllint, python3 | sops, age, make decrypt/encrypt |
| `meta` | release (read-only subcommands), gita, gh (issues + PR create), make | release --execute phases |

## Changes Per Repo

1. Create `.claude/settings.json` using `permissions.allow` format (match iac-driver)
2. Add `settings.local.json` to `.gitignore`
3. Add "Ecosystem Context" and "Agent Boundaries" sections to `CLAUDE.md`

## Acceptance Criteria

- [ ] Each repo has `.claude/settings.json` with `permissions.allow`
- [ ] Format matches iac-driver reference (comment strings as section headers)
- [ ] config repo explicitly excludes all secrets tooling
- [ ] No infrastructure-executing or state-mutating tools in any allowed list
- [ ] `settings.local.json` gitignored in each repo
- [ ] Each CLAUDE.md has ecosystem context pointing to `~/homestak/dev/meta/CLAUDE.md`
EOF
)"
```

---

## `.claude/settings.json` File Contents

All configs use the `permissions.allow` and `permissions.deny` format. Comment strings
(e.g., `"__ Section __"`) serve as section headers. Claude Code's built-in Read, Edit,
Write, Glob, and Grep tools do not need explicit Bash permission.

**Syntax:** `Bash(command *)` matches any invocation of `command`. `Bash(command subcommand *)`
matches only that subcommand. The space before `*` enforces a word boundary — `Bash(ls *)`
matches `ls -la` but not `lsof`. Deny rules are evaluated before allow rules.

---

### `homestak-iac/ansible`

```json
{
  "permissions": {
    "allow": [
      "__ Lint __",
      "Bash(ansible-lint *)",
      "Bash(yamllint *)",

      "__ Build __",
      "Bash(make *)",

      "__ Claude Code tools __",
      "Read",
      "Edit",
      "Write"
    ],
    "deny": [
      "Bash(ansible-playbook *)"
    ]
  }
}
```

> **Denied:** `ansible-playbook` (executes infrastructure changes on live hosts).

---

### `homestak-iac/tofu`

```json
{
  "permissions": {
    "allow": [
      "__ Validation __",
      "Bash(tofu fmt *)",
      "Bash(tofu validate *)",

      "__ Build __",
      "Bash(make *)",

      "__ Claude Code tools __",
      "Read",
      "Edit",
      "Write"
    ],
    "deny": [
      "Bash(tofu apply *)",
      "Bash(tofu destroy *)",
      "Bash(tofu import *)"
    ]
  }
}
```

> **Denied:** `tofu apply`, `tofu destroy`, `tofu import` (state-mutating operations).
> Provider version bumps (`bpg/proxmox`) require human-approved integration test.

---

### `homestak-iac/packer`

```json
{
  "permissions": {
    "allow": [
      "__ Validation __",
      "Bash(packer validate *)",
      "Bash(packer fmt *)",

      "__ Lint and test __",
      "Bash(shellcheck *)",
      "Bash(bats *)",

      "__ Build __",
      "Bash(make *)",

      "__ Claude Code tools __",
      "Read",
      "Edit",
      "Write"
    ],
    "deny": [
      "Bash(./build *)",
      "Bash(./publish *)"
    ]
  }
}
```

> **Denied:** `./build` (requires KVM), `./publish` (publishes to Proxmox storage).
> Both are human-initiated operations.

---

### `homestak/bare-metal`

```json
{
  "permissions": {
    "allow": [
      "__ Lint and test __",
      "Bash(shellcheck *)",
      "Bash(bats *)",

      "__ Build __",
      "Bash(make *)",

      "__ Claude Code tools __",
      "Read",
      "Edit",
      "Write"
    ],
    "deny": [
      "Bash(./build *)",
      "Bash(./reinstall *)"
    ]
  }
}
```

> **Denied:** `./build` (creates ISOs), `./reinstall` (writes to physical media).
> Both are hardware operations requiring human initiation.

---

### `homestak/bootstrap`

```json
{
  "permissions": {
    "allow": [
      "__ Lint and test __",
      "Bash(shellcheck *)",
      "Bash(pylint *)",
      "Bash(bats *)",

      "__ Build __",
      "Bash(make *)",
      "Bash(python3 *)",

      "__ Claude Code tools __",
      "Read",
      "Edit",
      "Write"
    ],
    "deny": [
      "Bash(./install *)",
      "Bash(homestak *)"
    ]
  }
}
```

> **Denied:** `./install` (system-modifying installer), `homestak` CLI
> (modifies live system state). This is the most user-visible repo — changes
> must be carefully reviewed.

---

### `homestak/config`

```json
{
  "permissions": {
    "allow": [
      "__ Validation __",
      "Bash(make validate)",
      "Bash(make check)",
      "Bash(yamllint *)",
      "Bash(python3 *)",

      "__ Claude Code tools __",
      "Read",
      "Edit",
      "Write"
    ],
    "deny": [
      "Bash(sops *)",
      "Bash(age *)",
      "Bash(make decrypt)",
      "Bash(make encrypt)"
    ]
  }
}
```

> **Security restriction — non-negotiable:** `sops`, `age`, `make decrypt`, and
> `make encrypt` are explicitly denied. This agent operates on `.example`
> templates, schema definitions (`defs/`), postures, presets, specs, and manifests
> only. Never on `secrets.yaml` or its encrypted form. If anything in this config
> could touch secrets, remove it.

---

### `homestak-dev/meta`

```json
{
  "permissions": {
    "allow": [
      "__ Release (read-only) __",
      "Bash(./scripts/release status *)",
      "Bash(./scripts/release resume *)",
      "Bash(./scripts/release audit *)",
      "Bash(./scripts/release preflight *)",
      "Bash(./scripts/release verify *)",

      "__ Cross-repo __",
      "Bash(gita *)",
      "Bash(gh issue *)",
      "Bash(gh pr create *)",
      "Bash(gh pr list *)",
      "Bash(gh pr view *)",

      "__ Lint and test __",
      "Bash(make lint)",
      "Bash(make test)",

      "__ Claude Code tools __",
      "Read",
      "Edit",
      "Write"
    ],
    "deny": [
      "Bash(./scripts/release changelog --execute *)",
      "Bash(./scripts/release tag --execute *)",
      "Bash(./scripts/release publish --execute *)",
      "Bash(./scripts/release full *)"
    ]
  }
}
```

> **Denied:** `release changelog --execute`, `release tag --execute`,
> `release publish --execute`, and `release full` (all execution phases).
> Release gates require explicit human approval.

---

## `CLAUDE.md` Ecosystem Context Template

Add after the main overview section in each repo's `CLAUDE.md`. Adjust the "Agent
Boundaries" bullet for each repo's specific restrictions.

```markdown
## Ecosystem Context

This repo is part of the homestak polyrepo workspace. For project architecture,
development lifecycle, sprint/release process, and cross-repo conventions, see:

- `~/homestak/dev/meta/CLAUDE.md` — primary reference
- `docs/lifecycle/` in meta — 7-phase development process
- `docs/CLAUDE-GUIDELINES.md` in meta — documentation standards

When working in a scoped session (this repo only), follow the same sprint/release
process defined in meta. Use `/session save` before context compaction and
`/session resume` to restore state in new sessions.

### Agent Boundaries

This agent operates within the following constraints:

- Opens PRs via `homestak-bot`; never merges without human approval
- Runs lint and validation tools only; never executes infrastructure operations
- [repo-specific restriction — see issue for details]
```

**Repo-specific boundary lines:**

| Repo | Agent Boundary |
|---|---|
| `ansible` | Never runs `ansible-playbook` or modifies live host configuration |
| `tofu` | Never runs `tofu apply/destroy`; provider bumps require human-approved integration test |
| `packer` | Never runs `./build` or `./publish`; image builds require KVM and human initiation |
| `bare-metal` | Never runs `./build` or `./reinstall`; ISO creation and physical media writes are human-initiated |
| `bootstrap` | Never runs `./install` or `homestak` CLI; system modifications are human-initiated |
| `config` | Never accesses `secrets.yaml`, encryption tooling (`sops`/`age`), or `make decrypt/encrypt` |
| `meta` | Never runs release execution phases (`--execute`); release gates require human approval |

---

## Implementation Sequence

This is a single sprint touching all 7 repos. Run from `~/homestak/dev/meta`:

```
1. Create the tracking issue (above) via gh
2. /sprint plan "Add .claude/ permission scoping to all repos"
3. /sprint init  — creates branches across repos
4. For each of the 7 repos:
   a. Create .claude/settings.json (from configs above)
   b. Add settings.local.json to .gitignore (if not already present)
   c. Add Ecosystem Context + Agent Boundaries sections to CLAUDE.md
5. Run make lint / make test in each repo to verify no breakage
6. /sprint merge --all  — creates PRs via homestak-bot
7. Human reviews and approves each PR
8. /sprint close
```

---

## Post-Implementation Verification

After PRs are merged, verify each repo's config is active:

```bash
# In each repo directory, start a scoped Claude Code session and confirm:
# 1. Tool restrictions apply (try a blocked command, expect denial)
# 2. Allowed tools work (run make lint or equivalent)
# 3. CLAUDE.md ecosystem context renders correctly
```

---

## Future Work (Not This Sprint)

- **Per-repo statusLine**: Add `statusLine` config showing repo name + branch. Low
  priority cosmetic improvement.
- **Agent session patterns**: Document how multi-agent sessions work day-to-day —
  handoff protocols, issue-based communication, when to use scoped vs. workspace sessions.
- **Workspace-level permissions**: Consider whether `dev/.claude/settings.json` should
  define baseline permissions inherited by all repos, or remain skills/statusline only.
