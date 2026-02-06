# Design Gap Analysis

**Sprint:** 0 (Lifecycle Decomposition)
**Issue:** [iac-driver#141](https://github.com/homestak-dev/iac-driver/issues/141)
**Status:** Active
**Date:** 2026-02-03

## Overview

This document tracks the design documentation landscape for the homestak lifecycle architecture. It identifies completed designs, missing designs, design debt in existing docs, and code/structure cleanup candidates.

## Existing Design Docs

| Document | Status | Coverage |
|----------|--------|----------|
| [node-lifecycle.md](node-lifecycle.md) | Complete | Single-node lifecycle phases, spec schema, auth model, execution models |
| [node-orchestration.md](node-orchestration.md) | Complete | Multi-node patterns, topology, manifests, system tests |
| [spec-server.md](spec-server.md) | Complete | `homestak serve` HTTP server, auth flow, error codes |
| [spec-client.md](spec-client.md) | Complete | `homestak spec get` client, state directory, error handling |

## Missing Design Docs

| Document | Blocks | Priority | Description |
|----------|--------|----------|-------------|
| `config-apply.md` | iac-driver (TBD) | P0 | Config phase implementation to reach "platform ready" state |
| ~~`manifest-schema-v2.md`~~ | ~~iac-driver#140-P2~~ | ~~P0~~ | ~~Manifest schema v2~~ — **Completed** in iac-driver#143. Schema at `site-config/v2/defs/manifest.schema.json`, implementation in `manifest.py` |
| ~~`scenario-consolidation.md`~~ | ~~iac-driver#145~~ | ~~P1~~ | ~~Transitional doc for migrating from `*-constructor/*-destructor` to verb-based subcommands~~ — **Completed** in homestak-dev#195. See [scenario-consolidation.md](scenario-consolidation.md) |

### Document Dependencies

```
node-lifecycle.md (complete)
        │
        ├── config-apply.md (missing) ─────► iac-driver (TBD)
        │
        └── phase-interfaces.md (new) ─────► Run/Destroy contracts

node-orchestration.md (complete)
        │
        ├── manifest-schema-v2.md (complete) ──► iac-driver#143
        │
        └── scenario-consolidation.md (complete) ──► iac-driver#145
```

## Design Debt

Identified issues in existing design documents that should be corrected.

### node-orchestration.md

| Section | Issue | Fix |
|---------|-------|-----|
| CLI examples | ~~Uses `homestak ...` command pattern~~ | **Complete** — Updated to verb-based `./run.sh create/destroy/test -M X -H host` |
| Architecture Alignment | ~~References "manifest-executor.md"~~ | **Complete** — Operator package replaces inline execution (#144) |
| Implementation Relationship | References phase numbers from sprint planning | Update to reference design docs directly |

### node-lifecycle.md

| Section | Issue | Fix |
|---------|-------|-----|
| Phase scope | Run and Destroy phases described briefly | Add cross-reference to `phase-interfaces.md` once created |
| CLI Pattern | Shows `homestak config` as "Future" | Update status after config-apply.md is written |

### CLAUDE.md Files

| File | Issue | Fix |
|------|-------|-----|
| ~~`iac-driver/CLAUDE.md`~~ | ~~Manifest section references v1 schema~~ | **Done** — v2 operator engine docs added |
| ~~`site-config/CLAUDE.md`~~ | ~~v2/nodes/ described~~ | **Done** — v2/nodes/ removed, manifest v2 docs added |

## Code/Structure Cleanup Candidates

Items identified during iac-driver#141 analysis for NFR (Non-Functional Requirements) cleanup. These don't block functionality but improve maintainability.

### Scenario Naming (iac-driver)

| Current | Issue | Target |
|---------|-------|--------|
| ~~`vm-constructor`~~ | ~~Action encoded in name~~ | **Retired** — `./run.sh create -M n1-basic -H <host>` |
| ~~`vm-destructor`~~ | ~~Action encoded in name~~ | **Retired** — `./run.sh destroy -M n1-basic -H <host>` |
| ~~`vm-roundtrip`~~ | ~~Test pattern encoded in name~~ | **Retired** — `./run.sh test -M n1-basic -H <host>` |
| ~~`nested-pve-constructor`~~ | ~~Hardcoded 2-level~~ | **Retired** — `./run.sh create -M n2-quick -H <host>` |
| ~~`nested-pve-destructor`~~ | ~~Hardcoded 2-level~~ | **Retired** — `./run.sh destroy -M n2-quick -H <host>` |
| ~~`nested-pve-roundtrip`~~ | ~~Hardcoded 2-level~~ | **Retired** — `./run.sh test -M n2-quick -H <host>` |
| ~~`recursive-pve-*`~~ | ~~Old manifest format~~ | **Retired** — `./run.sh create/destroy/test -M <manifest> -H <host>` |

### Directory Structure (iac-driver)

| Current | Issue | Target |
|---------|-------|--------|
| `src/scenarios/*.py` | Contains hardcoded scenarios | Move reusable primitives to `lifecycle/primitives/` |
| No `lifecycle/` directory | New architecture has no home | Create `lifecycle/` for new components |

### Site-Config v2

| Current | Issue | Target |
|---------|-------|--------|
| ~~`v2/nodes/*.yaml`~~ | ~~Instances, not templates~~ | **Done** — deleted, absorbed into manifest `nodes[]` |
| ~~`v2/defs/node.schema.json`~~ | ~~Separate from manifest~~ | **Done** — deleted, properties in `manifest.schema.json` |

### Dead Code Candidates

| Location | Item | Disposition |
|----------|------|-------------|
| ~~`iac-driver/src/scenarios/cleanup_nested_pve.py`~~ | ~~Shared cleanup actions~~ | **Deleted** — Consolidated into operator (#145) |
| `iac-driver/src/actions/recursive.py` | RecursiveScenarioAction | **Kept** — Used by operator for subtree delegation |

## Gap Closure Tracking

Track progress on closing design gaps.

| Gap | Target | Status | Notes |
|-----|--------|--------|-------|
| unified-controller (#148) | iac-driver#146 | **Complete** | Delivered in PR #150, #148 closed |
| config-apply.md | iac-driver#147 | Not started | Blocks first "platform ready" |
| manifest-schema-v2.md | iac-driver#143 | **Complete** | Schema at `site-config/v2/defs/manifest.schema.json` |
| scenario-consolidation.md | iac-driver#145 | **Complete** | [scenario-consolidation.md](scenario-consolidation.md) |
| phase-interfaces.md | iac-driver#141 | **Complete** | Resolved Q1-Q6, documented all phase contracts |
| node-orchestration.md CLI examples | iac-driver#141 | **Complete** | Updated to verb-based `./run.sh create/destroy/test` |
| node-lifecycle.md phase-interfaces ref | iac-driver#141 | **Complete** | Added cross-reference |
| CLI verb pattern update | iac-driver#141 | **Complete** | All design docs updated from `--manifest X --action Y` to verb subcommands |
| requirements-catalog.md Source column | iac-driver#141 | **Complete** | Added Source tracking, 11 implicit requirements |
| requirements-catalog.md CTL category | iac-driver#146 | **Complete** | Added controller requirements (REQ-CTL-001 to 010) |
| Terminology standardization | iac-driver#141 | **Complete** | "spec server" not "config server" |

## Changelog

| Date | Change |
|------|--------|
| 2026-02-06 | Mark scenario consolidation complete (#145); update scenario naming, dead code, gap closure tracking |
| 2026-02-05 | Replace ordinal sprint labels with issue references; update for #143+#144 combination |
| 2026-02-05 | Updated CLI pattern references to verb-based subcommands; marked #148 complete; updated scenario retirement targets |
| 2026-02-05 | Added unified controller (#148) to gap tracking; added CTL category to requirements |
| 2026-02-04 | Updated Sprint 4 to reference iac-driver#147 (config phase) |
| 2026-02-04 | Removed homestak-dev#155 references (closed - config phase belongs in iac-driver) |
| 2026-02-04 | Updated Gap Closure Tracking with Sprint 0 completions |
| 2026-02-03 | Initial document |
