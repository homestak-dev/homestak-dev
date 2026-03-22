# Agentification

Design document for progressive adoption of persistent Claude Code agents across the
homestak polyrepo workspace.

## Vision

Persistent agents, one per repo, that own design/dev/test/doc for their domain. An
orchestrator agent in `homestak-dev/meta` coordinates activities across the repo agents.

Agents do the work; humans review at PR gates. This mirrors the existing parallel
orchestrator pattern — `iac-driver` orchestrates infrastructure, `meta` orchestrates
process — applied at the agent layer.

## Current State

- 10 repos across 3 orgs
- `iac-driver` has a working `.claude/settings.json` (reference implementation)
- Workspace `.claude/` provides shared skills (`/sprint`, `/release`, `/session`, `/issues`)
- `meta/CLAUDE.md` uses `@`-imports to load all sibling CLAUDE.md files
- `/session save/resume` persists agent state via GitHub issues
- `homestak-bot` creates PRs; human reviews and approves (HITL gate)
- GitHub issues are already used for cross-repo coordination

Only `iac-driver` has scoped agent permissions. All other repos operate with default
(unscoped) tool access.

## Architecture

### Agent Topology

```
                    ┌─────────────────────┐
                    │   meta (orchestrator)│
                    │   - decomposes work  │
                    │   - tracks progress  │
                    │   - coordinates deps │
                    └──────────┬──────────┘
                               │ GitHub issues (IPC)
          ┌────────┬───────┬───┴───┬────────┬────────┬────────┐
          ▼        ▼       ▼       ▼        ▼        ▼        ▼
       ansible   tofu   packer  bare-    boot-    config  iac-driver
       agent     agent  agent   metal    strap    agent   agent
                                agent    agent
```

### Communication

Agents communicate through GitHub issues — no new message bus or API needed.

| Channel | Mechanism | Example |
|---------|-----------|---------|
| Work assignment | Meta creates labeled issue in target repo | "Add posture validation" in config |
| Status reporting | Agent comments on tracking issue | "PR #42 ready for review" |
| Dependency signaling | Issue references across repos | "Blocked by homestak/config#15" |
| Coordination | Sprint/release issues in meta | `/sprint merge --all` |

### Safety Model

```
┌──────────────────────────────────────────────────────────┐
│ Layer 1: permissions.allow (per-repo .claude/settings.json) │
│   What tools the agent can use                           │
├──────────────────────────────────────────────────────────┤
│ Layer 2: CLAUDE.md Agent Boundaries                      │
│   What the agent should and shouldn't do                 │
├──────────────────────────────────────────────────────────┤
│ Layer 3: GitHub Rulesets                                 │
│   PRs required, human approval before merge              │
├──────────────────────────────────────────────────────────┤
│ Layer 4: homestak-bot separation                         │
│   Agent creates PRs as bot; operator reviews as human    │
└──────────────────────────────────────────────────────────┘
```

## Permission Scoping Reference

Each repo agent gets a `.claude/settings.json` with `permissions.allow`. The principle:
agents can lint, test, and edit code, but never execute infrastructure, touch secrets,
or publish artifacts.

| Repo | Allowed | Excluded (safety) |
|------|---------|-------------------|
| `ansible` | ansible-lint, yamllint, make | ansible-playbook |
| `tofu` | tofu fmt, tofu validate, make | tofu apply/destroy/import |
| `packer` | packer validate/fmt, shellcheck, bats, make | ./build, ./publish |
| `bare-metal` | shellcheck, bats, make | ./build, ./reinstall |
| `bootstrap` | shellcheck, pylint, bats, python3, make | ./install, homestak CLI |
| `config` | make validate/check, yamllint, python3 | sops, age, make decrypt/encrypt |
| `meta` | release (read-only), gita, gh (issues + PR create), make | release --execute phases |
| `iac-driver` | (existing config — infra tools for orchestration) | — |

See `/tmp/multi-agent-plan.md` for complete `settings.json` file contents.

> **Non-negotiable:** `config` repo must never have access to secrets tooling.
> `meta` must never have access to release execution phases without human gate.

## Progressive Rollout

Each sprint produces independently valuable outcomes. You can stop after any sprint
and still have gained something useful.

### Sprint 1 — Permissions & Boundaries ✓

**Status:** Complete (meta#356, 2026-03-20)

**Goal:** Establish the safety layer.

**Delivered:**
- `.claude/settings.json` with `permissions.allow`/`deny` in 6 repos (bare-metal,
  bootstrap, config, ansible, tofu, packer)
- Updated `dev/.claude/settings.json` with granular release allow/deny rules
- `settings.local.json` added to `.gitignore` in 7 repos (+ iac-driver)
- "Ecosystem Context" and "Agent Boundaries" sections added to 8 CLAUDE.md files

**PRs:** bare-metal#9, bootstrap#111, config#101, ansible#70, tofu#82,
packer#72, iac-driver#319, meta#357, .claude#31

**Outcome:** Every repo has scoped agent permissions. Agents can only use lint/test
tools. No infrastructure can be executed by an agent without human intervention.

**Validated:** `permissions.allow`/`deny` format works correctly across all repos.
Modern space syntax (`Bash(command *)`) used throughout.

---

### Sprint 2 — Session Discipline

**Goal:** Validate the persistence model with real work.

**Work:**
- Pick 1–2 low-risk repos (bare-metal, packer — narrow domain, low velocity)
- Run real backlog issues through the full agent loop:
  agent picks up issue → works it → `/session save` at compaction → opens PR → human reviews
- Document rough edges and session lifecycle patterns

**Outcome:** Validated persistence model. Known patterns for session save/resume
across compaction boundaries. Documented what works and what doesn't.

**Validates:** `/session save/resume` works for real work, not just synthetic exercises.
Identifies gaps in session state capture.

---

### Sprint 3 — Cross-Repo Coordination

**Goal:** First test of meta as orchestrator.

**Work:**
- Pick a change that touches 2–3 repos (e.g., config schema change → iac-driver
  consumption → tofu variable update)
- Meta decomposes work into per-repo issues with dependency annotations
- Repo agents execute independently; meta monitors progress
- Design issue labeling/tagging conventions that become the agent IPC protocol
- Handle dependency ordering (config must land before iac-driver can consume)

**Outcome:** Working orchestration protocol. Issue conventions for agent-to-agent
coordination. Validated dependency tracking.

**Validates:** Meta can decompose and coordinate cross-repo work. GitHub issues
are sufficient as IPC.

**Risk:** This is the highest-risk sprint. Orchestration protocol design is genuinely
new territory. Plan extra room here.

---

### Sprint 4 — Remaining Repo Enablement

**Goal:** Replicate the validated pattern across all repos.

**Work:**
- Enable agent sessions in all remaining repos (ansible, tofu, bootstrap, config)
- Each repo agent works a real issue from its backlog
- Apply session discipline patterns from Sprint 2
- Apply coordination patterns from Sprint 3

**Outcome:** All repos have active, validated agent sessions. The pattern is proven
across different repo types (Python, shell, HCL, YAML).

**Validates:** Pattern scales uniformly. No repo-specific surprises.

---

### Sprint 5 — Orchestration Hardening

**Goal:** Handle failure cases and define operational model.

**Work:**
- Agent gets stuck (context too large, tool failures, blocked on dependency)
- Dependency deadlock between repos
- Conflicting changes across repos
- Session state goes stale
- Define what "persistent" means operationally:
  - Scheduled polling (cron-like)?
  - Event-driven via CI webhooks?
  - Long-running sessions?
  - Human-triggered with context resume?

**Outcome:** Robust orchestration that handles real-world failure modes. Clear
operational model for how agents run day-to-day.

**Validates:** The system degrades gracefully. Failure modes are understood and
handled.

---

### Sprint 6 — Autonomous Steady-State

**Goal:** Agents running independently on their backlogs.

**Work:**
- Meta coordinates sprints and releases across repo agents
- Agents pick up issues, design solutions, implement, test, open PRs
- Human role shifts from "direct the work" to "review PRs and approve releases"
- Measure: time-to-PR, review quality, agent accuracy

**Outcome:** Target operating model. Agents own the design/dev/test/doc cycle.
Humans own approval and strategic direction.

**Validates:** The full vision works end-to-end.

## Open Questions

These should be resolved during implementation, not upfront:

1. **Persistence model** — What does "persistent" mean? Long-running sessions burn
   context. Scheduled sessions lose state. Event-driven needs webhook infrastructure.
   Sprint 5 should answer this empirically.

2. **Agent identity** — Should each repo agent have a distinct GitHub identity, or all
   operate as `homestak-bot`? Distinct identities improve auditability but add
   operational overhead.

3. **Orchestrator scope** — How much authority does meta have? Can it create issues
   and assign work autonomously, or does it propose and human approves? The answer
   likely evolves across sprints.

4. **Context management** — Each repo's CLAUDE.md is already loaded by meta via
   `@`-imports. When meta orchestrates, does it need full context for all repos, or
   just enough to decompose and delegate?

5. **Failure escalation** — When a repo agent is stuck, how does it signal meta?
   A comment on the issue? A label change? A timeout detected by meta?

## Relationship to Roadmap

Agentification is orthogonal to the app-layer roadmap in `docs/roadmap.md`. The
infrastructure pivot (Phases 0–4) defines _what_ gets built. Agentification defines
_how_ it gets built — with increasing agent autonomy.

The app layer may become the proving ground for the full agent model: meta
decomposes "deploy pihole" into per-repo work items, repo agents execute, human
approves the result.

## References

- `iac-driver/.claude/settings.json` — Reference implementation for permissions
- `dev/.claude/` — Workspace skills and configuration
- `docs/process/` — 7-phase development process (agents follow the same process)
- `agentification-sprint1.md` — Sprint 1 implementation details
