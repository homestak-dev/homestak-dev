# Design Summary: `homestak spec get`

**Sprint:** #162 (v0.44 Config Client + Integration)
**Release:** #153
**Epic:** iac-driver#125 (Architecture evolution)
**Author:** Claude
**Date:** 2026-02-01

## Problem Statement

Nodes need to fetch their specifications from the server (iac-driver) and persist them locally. The `homestak spec get` command provides the client-side of the config phase.

**Success criteria:**
- Client fetches spec from server via HTTP
- CLI flags work for manual testing: `--server`, `--identity`, `--token`
- Env vars work for automated path: `HOMESTAK_SPEC_SERVER`, `HOMESTAK_IDENTITY`, `HOMESTAK_AUTH_TOKEN`
- Fetched spec persisted to `/usr/local/etc/homestak/state/`
- Error responses handled with defined codes

## Proposed Solution

**Summary:** Python HTTP client in bootstrap that fetches specs from the server, validates them, and persists to local state.

**High-level approach:**
- HTTP client using Python's `urllib.request` (stdlib, no deps)
- Configuration via CLI flags (manual) or env vars (automated)
- Persist fetched spec to state directory
- Use same error codes as server (E100-E501)

**Key components affected:**
- `bootstrap/lib/spec_client.py` - New Python module for HTTP client
- `bootstrap/homestak.sh` - Add `spec get` subcommand routing

**New components introduced:**
- `bootstrap/lib/spec_client.py` - HTTP client implementation

**Reused from Sprint #161:**
- Error code structure from `spec_resolver.py` (originally in bootstrap, removed in Sprint #199; resolver now in iac-driver)
- Path discovery pattern (`discover_etc_path()`)

## Interface Design

### CLI

```bash
# Manual invocation (for testing/debugging)
homestak spec get --server https://father:44443 --identity dev1 [--token mytoken]

# Automated invocation (via env vars, for cloud-init path)
HOMESTAK_SPEC_SERVER=https://father:44443 \
HOMESTAK_IDENTITY=dev1 \
HOMESTAK_AUTH_TOKEN=mytoken \
homestak spec get

# Additional flags
--output <path>    # Override output path (default: state dir)
--validate         # Validate against schema before saving (default: true)
--verbose          # Enable verbose output
```

**Flag precedence:** CLI flags override env vars.

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `HOMESTAK_SPEC_SERVER` | Server URL (e.g., `https://father:44443`) | Yes (if no --server) |
| `HOMESTAK_IDENTITY` | Node identity (e.g., `dev1`) | Yes (if no --identity) |
| `HOMESTAK_AUTH_TOKEN` | Bearer token for auth | If posture requires |

### State Directory Structure

```
/usr/local/etc/homestak/state/
├── spec.yaml           # Current spec (most recent fetch)
├── spec.yaml.prev      # Previous spec (for rollback/diff)
└── fetch.log           # Fetch history (timestamp, server, result)
```

### Output Format (Success)

```
Fetching spec for 'dev1' from https://father:44443...
Spec fetched successfully
  Schema version: 1
  Posture: dev
  Packages: 5
Saved to: /usr/local/etc/homestak/state/spec.yaml
```

### Output Format (Error)

```
Error fetching spec: E200 - Spec not found: dev1
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Client error (missing args, invalid config) |
| 2 | Server error (network, HTTP error) |
| 3 | Validation error (schema invalid) |

### Error Code Mapping

Map server error codes to client behavior:

| Server Code | HTTP Status | Client Behavior |
|-------------|-------------|-----------------|
| E100 | 400 | Exit 1, show message |
| E101 | 400 | Exit 1, show message |
| E200 | 404 | Exit 2, "Spec not found" |
| E201 | 404 | Exit 2, "Posture not found" |
| E300 | 401 | Exit 2, "Auth required" |
| E301 | 403 | Exit 2, "Invalid token" |
| E400 | 422 | Exit 3, "Schema validation failed" |
| E500 | 500 | Exit 2, "Server error" |

## Integration Points

1. **Server (iac-driver)** - HTTP API, see [server-daemon.md](server-daemon.md)
2. **Path discovery** - Reuse `discover_etc_path()` pattern
3. **State directory** - New `/usr/local/etc/homestak/state/`
4. **Config completion (v0.48)** - `./run.sh config` reads `state/spec.yaml` and applies via ansible (iac-driver#147)

## Data Flow

**Note:** The automated path (cloud-init) uses provisioning tokens — see [provisioning-token.md](provisioning-token.md). The `homestak spec get` CLI retains `--identity` and `--token` flags for manual testing/debugging.

```
homestak spec get
       │
       ▼
Parse CLI flags / env vars
       │
       ├── --server / HOMESTAK_SPEC_SERVER
       ├── --token / HOMESTAK_TOKEN (provisioning token, automated path)
       ├── --identity / HOMESTAK_IDENTITY (manual testing only)
       └── --auth-token / HOMESTAK_AUTH_TOKEN (manual testing only)
       │
       ▼
Build HTTP request
       │
       ├── URL: {server}/spec/{hostname}
       └── Header: Authorization: Bearer {token}
       │
       ▼
Send request to server
       │
       ├── Success (200) → Parse JSON
       │                         │
       │                         ▼
       │                   Validate schema (optional)
       │                         │
       │                         ▼
       │                   Persist to state/spec.yaml
       │                         │
       │                         ▼
       │                   Exit 0
       │
       └── Error (4xx/5xx) → Log error
                                   │
                                   ▼
                             Write fail marker (if permanent)
                             or retry with backoff (if transient)
                                   │
                                   ▼
                             Exit 1/2/3
```

## Path Mode Verification

Per `20-design.md`, verify both installation modes:

| Mode | State Path |
|------|------------|
| FHS | `/usr/local/etc/homestak/state/` |
| Legacy | `/opt/homestak/site-config/state/` |

**Implementation:** Use `discover_etc_path()` and append `/state/`. Create directory if not exists.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Server unreachable | Medium | Medium | Clear error message, suggest checking server |
| SSL certificate issues | Medium | Low | Support `--insecure` flag for self-signed certs |
| State directory permissions | Low | Medium | Check permissions, suggest sudo if needed |
| Concurrent writes to state | Low | Low | Atomic write (write to .tmp, rename) |

## Alternatives Considered

| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| curl wrapper | Simpler | Less control, parsing issues | Need structured output |
| requests library | Full-featured | External dependency | stdlib preferred |
| gRPC | Type-safe | Complex, overkill | HTTP sufficient |

## Test Plan

**Unit tests:** `bootstrap/tests/test_spec_client.py`

**Test cases:**
1. CLI flags parsed correctly
2. Env vars read when flags missing
3. CLI flags override env vars
4. Success case: spec fetched and saved
5. Error case: server unreachable
6. Error case: spec not found (E200)
7. Error case: auth required (E300)
8. Error case: invalid token (E301)
9. State directory created if missing
10. Previous spec backed up on fetch

**Integration test:** Cross-host fetch

```bash
# On father (server, via iac-driver)
./run.sh server start --port 44443

# On dev VM (client)
homestak spec get --server https://father:44443 --identity base
cat /usr/local/etc/homestak/state/spec.yaml
```

**Expected results:**
- Spec fetched and saved
- Previous spec backed up
- Exit code 0

## Prerequisites

| Category | Check | Status |
|----------|-------|--------|
| Server | iac-driver server daemon | Ready |
| Specs | specs/ files exist | Ready |
| Postures | postures/ files exist | Ready |
| Network | Client can reach server | Test at validation |

## Implementation Sequence

1. Create `lib/spec_client.py` with:
   - `SpecClient` class (HTTP client)
   - CLI argument parsing
   - Error handling
2. Add routing in `homestak.sh` for `spec get`
3. Add state directory management
4. Write unit tests
5. Run integration test cross-host

## Open Questions

1. **Should `spec get` auto-retry on transient failures?**
   - Proposal: No for v0.44, add `--retry N` in future if needed

2. **Should we support HTTP (non-TLS) for dev environments?**
   - Proposal: Yes, but warn. Add `--insecure` to suppress SSL verification.

## Checklist: Design Complete

- [x] Problem statement clear
- [x] Solution approach documented
- [x] Interfaces defined (CLI, env vars, state)
- [x] Integration points identified
- [x] Risks assessed
- [x] Validation scenario with test plan
- [x] Prerequisites verified
- [ ] Human approved

## Related Documents

- [server-daemon.md](server-daemon.md) - Server daemon design (iac-driver#177)
- [iac-driver#125](https://github.com/homestak-dev/iac-driver/issues/125) - Architecture evolution epic
- [homestak-dev#153](https://github.com/homestak-dev/homestak-dev/issues/153) - v0.44 Release Planning
