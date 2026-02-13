# Phase: Validation

Validation verifies implementation through integration testing. This phase applies during sprints to ensure code works before merge and before release.

## Validation Timing

| Context | When | Purpose |
|---------|------|---------|
| **Sprint validation** | Before PR merge | Verify implementation works |
| **Release validation** | Before tagging | Confirm no regressions |

Sprint validation is the primary gate. Release validation checks for evidence that sprints were validated.

## Unit Tests vs Integration Tests

Homestak uses two levels of testing:

| Aspect | Unit Tests | Integration Tests |
|--------|------------|-------------------|
| **Purpose** | Verify logic in isolation | Verify components work together |
| **Scope** | Single function/class | Full scenarios (VM lifecycle, playbooks) |
| **Speed** | Fast (seconds) | Slow (minutes) |
| **Dependencies** | Mocked | Real infrastructure |
| **When run** | Every PR (CI) | Before merge, before release |
| **Location** | `tests/` directory | iac-driver scenarios |

**Unit tests** (`make test` in each repo):
- Run automatically in CI on every push/PR
- Must pass before merge
- Test logic patterns, argument parsing, error handling
- Use mocks for external dependencies

**Integration tests** (iac-driver scenarios):
- Run manually before merge for IaC changes
- Required before release
- Test full workflows: provision → boot → verify → destroy
- Catch issues that unit tests miss

## Inputs

- Completed implementation on feature/sprint branch
- Acceptance criteria from issue
- Test plan from Design phase
- Unit tests passing in CI

## Activities

### 1. Determine Test Scope

Based on work tier and change type:

| Tier | Validation Requirement |
|------|------------------------|
| Simple | Smoke test (unit tests + manual check) |
| Standard | Integration scenario |
| Complex | Full scenario suite |
| Exploratory | Full suite + new scenario coverage |

### 2. Select Validation Scenario ("Size to Fit")

Not every change needs full integration testing. Match validation effort to change risk:

| Change Type | Scenario | Duration |
|-------------|----------|----------|
| Documentation only | None (review) | 0 |
| CLI argument/help text | Unit tests only | seconds |
| CLI with new behavior | Manual command test | ~1 min |
| Documentation, CLI, process | `./run.sh manifest test -M n1-push -H <host>` | ~2 min |
| Tofu/ansible changes | `./run.sh manifest test -M n1-push -H <host>` | ~2 min |
| Manifest/operator code | `./run.sh manifest test -M n2-tiered -H <host>` | ~9 min |
| PVE/nested/packer changes | `./run.sh manifest test -M n2-tiered -H <host>` | ~9 min |

**Size to Fit principle:** Use the lightest validation that proves the change works. Don't run 9-minute nested-pve scenarios for a CLI help text fix.

**When unit tests are sufficient:**
- Argument parsing changes (test with bats)
- Error message updates
- Help text modifications
- Pure refactoring with existing test coverage

**When integration tests are required:**
- Any IaC code (tofu, ansible, packer)
- Changes affecting VM lifecycle
- Network or SSH configuration
- Cloud-init modifications

### 3. Required Validation by Change Type

Certain changes require validation **before merge**:

| Change Type | Required Validation |
|-------------|---------------------|
| Packer template changes | Build image, run `./run.sh manifest test -M n1-push` or `n2-tiered` |
| Boot/startup optimizations | Measure actual timing before and after |
| Cloud-init modifications | Full VM lifecycle test |
| Tofu module changes | `./run.sh manifest test -M n1-push -H <host>` |
| Ansible role changes | Run playbook on test VM |
| iac-driver action changes | Scenario that exercises the action |
| CLI commands | Full command flow |

### 4. Verify Prerequisites

Before running validation:

| Prerequisite | Check Command |
|--------------|---------------|
| Node configuration | `ls site-config/nodes/$(hostname).yaml` |
| API token | `grep api_tokens site-config/secrets.yaml` |
| Secrets decrypted | `head -1 site-config/secrets.yaml` (must NOT start with `sops:`) |
| Packer images | `ls /var/lib/vz/template/iso/debian-*-custom.img` |
| Nested virtualization | `cat /sys/module/kvm_intel/parameters/nested` |

Or use preflight check:

```bash
cd iac-driver
./run.sh --preflight --host father
```

### 4a. FHS Branch Alignment (Remote Hosts)

When running integration tests against a remote FHS host (e.g., father at `/usr/local/lib/homestak/`), **all repos must be on the correct branch**. Sprint code on your dev machine won't take effect unless the remote host's repos also have the sprint changes.

**Verify branch alignment:**
```bash
# Check which branches are checked out on the remote host
ssh root@father "for d in /usr/local/lib/homestak/*/; do echo \"\$(basename \$d): \$(git -C \$d branch --show-current)\"; done"
```

**Deploy sprint branches to remote host:**
```bash
# For each repo with sprint changes:
ssh root@father "cd /usr/local/lib/homestak/<repo> && git fetch origin sprint/<name> && git checkout sprint/<name>"

# Don't forget site-config:
ssh root@father "cd /usr/local/etc/homestak && git fetch origin sprint/<name> && git checkout sprint/<name>"
```

**Common mistake:** Deploying 3 of 4 repos and forgetting the 4th. Always verify all affected repos are aligned before running scenarios.

**After validation:** Restore the remote host to master:
```bash
ssh root@father "for d in /usr/local/lib/homestak/*/; do git -C \$d checkout master 2>/dev/null; done"
ssh root@father "cd /usr/local/etc/homestak && git checkout master"
```

Use `homestak update --branch <name>` to automate this (bootstrap#49).

### 5. Execute Validation

**Using iac-driver:**

```bash
cd ~/homestak-dev/iac-driver

# Quick validation (~2 min)
./run.sh manifest test -M n1-push -H father

# Tiered validation (~9 min)
./run.sh manifest test -M n2-tiered -H father

# Full 3-level validation (~15 min)
./run.sh manifest test -M n3-deep -H father
```

**Apply/destroy separately (for debugging):**

```bash
./run.sh manifest apply -M n2-tiered -H father
# ... inspect inner PVE ...
./run.sh manifest destroy -M n2-tiered -H father --yes
```

### 6. Document Results

Post validation results to the sprint issue:

```markdown
## Validation - YYYY-MM-DD

**Scenario:** `./run.sh manifest test -M n1-push -H father`
**Host:** father
**Result:** PASSED

**Summary:**
- VM provisioned in 6.8s
- SSH accessible in 45s
- Guest agent responsive
- Cleanup complete

**Report:** `iac-driver/reports/YYYYMMDD-HHMMSS.passed.md`
```

For failures, include:
- Phase that failed
- Error message
- Root cause analysis
- Fix applied

### 7. Performance Validation

If claiming optimization:

1. Measure baseline (before change)
2. Apply change
3. Measure with change
4. Document results

```markdown
## Performance Validation

**Metric:** Guest agent response time
**Baseline:** 135s
**After change:** 133s
**Conclusion:** No significant improvement - reverted optimization
```

### 8. External Tool Verification

**CRITICAL:** Do not assume CLI flags exist. Test actual behavior.

```bash
# Bad - assumption
gh release list --json name  # DOES NOT EXIST

# Good - verification first
gh release view v0.19 --json assets  # Test actual command
```

## Validation Host Prerequisites

Quick check for validation readiness:

```bash
HOST=$(hostname)

# 1. Check node config exists
ls site-config/nodes/${HOST}.yaml 2>/dev/null || echo "MISSING: node config"

# 2. Check secrets decrypted (not SOPS-encrypted)
head -1 site-config/secrets.yaml | grep -q "^sops:" && echo "ENCRYPTED: run 'make decrypt' in site-config" || echo "OK: secrets decrypted"

# 3. Check API token exists
grep -q "${HOST}:" site-config/secrets.yaml && echo "OK: API token" || echo "MISSING: API token"

# 4. Check packer images
ls /var/lib/vz/template/iso/debian-*-custom.img 2>/dev/null || echo "MISSING: packer images"

# 5. Check nested virtualization
cat /sys/module/kvm_intel/parameters/nested | grep -q Y && echo "OK: nested virt" || echo "WARNING: no nested virt"
```

**Common issues:**

| Issue | Solution |
|-------|----------|
| `secrets.yaml encrypted` | Run `make decrypt` in site-config (file exists but starts with `sops:`) |
| `API token not found` | Generate with `pveum`, add to secrets.yaml |
| `node config missing` | Run `make node-config` on PVE host |
| `packer images missing` | Run `./publish.sh` or download from release |
| `provider version conflict` | Clear: `rm -rf iac-driver/.states/*/data/providers/` |

## Outputs

- Test execution results documented
- All failures resolved
- Performance measured (if applicable)
- Evidence in sprint issue for release

## Checklist: Validation Complete

- [ ] Test scope determined based on tier
- [ ] Prerequisites verified
- [ ] Appropriate scenario executed
- [ ] Results documented in sprint issue
- [ ] External tool assumptions verified
- [ ] Performance measured (if claimed)
- [ ] No introduced failures remain

## Anti-Patterns

### Don't Ship Untested Optimizations

If you claim "faster" or "optimized":
1. Measure baseline
2. Measure with change
3. Include results in PR
4. Revert if no improvement

### Don't Assume Prerequisite State

Document explicitly what must exist before validation can run.

### Don't Skip Validation for "Simple" Changes

A "simple" packer optimization broke networking in v0.19 because it was never tested with actual VM provisioning.

## Related Documents

- [30-implementation.md](30-implementation.md) - Unit testing during implementation
- [55-sprint-close.md](55-sprint-close.md) - Sprint validation wrap-up
- [61-release-preflight.md](61-release-preflight.md) - Release validation evidence check
- [80-reference.md](80-reference.md) - Validation scenario reference
