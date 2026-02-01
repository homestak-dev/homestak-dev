# Phase 61: Release Preflight

Preflight checks verify release prerequisites and validation evidence before proceeding.

## Purpose

- Verify all repos are in releasable state
- Check for validation evidence from completed sprints
- Ensure no blocking issues

## Prerequisites

- Release issue exists
- All planned sprints completed
- `release.sh init` executed

## Activities

### 1. Initialize Release State

**Run first**, before any other checks:

```bash
# Find release issue
gh issue list --repo homestak-dev/homestak-dev --label release --state open

# Initialize release state
./scripts/release.sh init --version 0.45 --issue 157
```

**Why first:** The state file tracks validation status. Running init mid-release causes "validation not complete" errors.

### 2. Check Validation Evidence

Review sprint issues for validation results:

```bash
# Check each completed sprint issue
gh issue view 152 --repo homestak-dev/homestak-dev

# Look for validation sections with PASSED results
```

Evidence needed:
- Scenario run (which scenario, which host)
- Result (PASSED)
- Report link or summary

**Note:** Release validation is evidence-based. Sprints run the tests; release checks they were run.

### 3. Git Fetch All Repos

```bash
gita fetch
```

Avoids rebase surprises from unsynced remotes.

### 4. Check Working Trees Clean

```bash
gita shell "git status --porcelain"
# Should return empty for all repos
```

### 5. Check No Existing Tags

```bash
VERSION=0.45
for repo in .claude .github ansible bootstrap homestak-dev iac-driver packer site-config tofu; do
  gh api repos/homestak-dev/$repo/git/refs/tags/v${VERSION} 2>/dev/null && \
    echo "WARNING: $repo has tag v${VERSION}" || echo "OK: $repo"
done
```

### 6. Check Secrets Decrypted

```bash
ls site-config/secrets.yaml && echo "OK: secrets decrypted" || \
  echo "FAIL: run 'make decrypt' in site-config"
```

### 7. CLAUDE.md Review

Verify each repo's CLAUDE.md reflects current state:

**Meta repos:**
- [ ] .github - org templates, PR defaults
- [ ] .claude - skills, settings
- [ ] homestak-dev - workspace structure, documentation index

**Core repos:**
- [ ] site-config - schema, defaults, file structure
- [ ] iac-driver - scenarios, actions, ConfigResolver
- [ ] tofu - modules, variables, workflow
- [ ] packer - templates, build workflow
- [ ] ansible - playbooks, roles, collections
- [ ] bootstrap - CLI, installation

### 8. Check CHANGELOGs

Verify unreleased content exists:

```bash
for repo in .claude .github ansible bootstrap homestak-dev iac-driver packer site-config tofu; do
  echo "=== $repo ==="
  head -20 $repo/CHANGELOG.md 2>/dev/null | grep -A5 "Unreleased"
done
```

## Using release.sh

```bash
./scripts/release.sh preflight
```

Performs automated checks and reports status.

## Outputs

- All prerequisites verified
- Validation evidence confirmed
- Ready to proceed to CHANGELOG phase

## Checklist: Preflight Complete

- [ ] `release.sh init` executed
- [ ] Validation evidence reviewed
- [ ] Git fetch on all repos
- [ ] Working trees clean
- [ ] No existing tags for version
- [ ] Secrets decrypted
- [ ] CLAUDE.md files reviewed
- [ ] CHANGELOGs have unreleased content

## Next Phase

Proceed to [62-release-changelog.md](62-release-changelog.md).
