# Phase: Validation

Validation verifies the implementation through integration testing. This phase applies to all work types, with scope scaled to risk.

## Inputs

- Completed implementation on feature branch
- Acceptance criteria
- Test plan from Design phase
- Existing integration test suite

## Activities

### 1. Integration Test Scope

Determine test scope based on change:

| Change Type | Test Scope |
|-------------|------------|
| Isolated bug fix | Targeted tests around affected area |
| Enhancement | Related feature tests + regression |
| Feature | New feature tests + full regression |

### 2. Required Validation by Change Type

Certain changes require validation testing **before merge**, not just code review:

| Change Type | Required Validation |
|-------------|---------------------|
| Packer template changes | Build image, run `vm-roundtrip` or `nested-pve-roundtrip` |
| Boot/startup optimizations | Measure actual timing before and after |
| Cloud-init modifications | Full VM lifecycle test (provision → boot → verify) |
| Tofu module changes | `vm-roundtrip` on target environment |
| Ansible role changes | Run playbook on test VM, verify behavior |
| iac-driver action changes | Scenario that exercises the action |
| CLI commands | Full command flow |

### 3. External Tool Verification

**CRITICAL:** Do not assume CLI flags exist. Test actual behavior.

**Bad (assumption):**
```bash
# Assumed gh release list supports --json
gh release list --json name  # DOES NOT EXIST
```

**Good (verification):**
```bash
# Test in terminal first, then implement
gh release view v0.19 --json assets
```

### 4. Performance Validation

If claiming optimization:

1. Measure baseline (before change)
2. Apply change
3. Measure with change
4. Document results in PR

**Example (v0.19 packer#13):**
```
Baseline (debian-13-custom): 135s guest agent response
Optimized (same image): 133s guest agent response
Result: No significant improvement - revert optimization
```

### 5. Test Execution

Run integration tests appropriate to scope:
- New tests for new functionality
- Existing tests for regression
- Cross-repo tests if changes span repositories

**Using iac-driver:**
```bash
# Quick validation (~2 min)
./run.sh --scenario vm-roundtrip --host father

# Full nested-pve roundtrip (~8 min)
./run.sh --scenario nested-pve-roundtrip --host father

# Or constructor + destructor separately with context persistence
./run.sh --scenario nested-pve-constructor --host father -C /tmp/nested-pve.ctx
# ... verify inner PVE, check test VM ...
./run.sh --scenario nested-pve-destructor --host father -C /tmp/nested-pve.ctx
```

**Document results:**
- Which test suites ran
- Pass/fail summary
- Any flaky or skipped tests (with rationale)

### 6. Issue Documentation

For any failures:
- Identify root cause
- Determine if failure is pre-existing or introduced
- Fix introduced failures before proceeding
- Document pre-existing failures for backlog

### 7. Human Review/Execution

Integration tests involve human at this checkpoint:
- Review test plan and scope
- Review test results
- Execute tests directly when appropriate (environment access, credentials, etc.)
- Approve validation as complete

## Validation Host Prerequisites

A "bootstrapped" host is not automatically validation-ready:

| Prerequisite | Description | Setup Command |
|--------------|-------------|---------------|
| **Node configuration** | `site-config/nodes/{hostname}.yaml` must exist | `cd site-config && make node-config` |
| **API token** | Token in `site-config/secrets.yaml` | `pveum user token add root@pam homestak --privsep 0` |
| **Secrets decrypted** | `site-config/secrets.yaml` must be decrypted | `cd site-config && make decrypt` |
| **Packer images** | Images published to local PVE storage | `cd packer && ./publish.sh` or download from release |
| **SSH access** | SSH key access to the validation host | Standard SSH setup |
| **Nested virtualization** | For nested-pve scenarios | Check: `cat /sys/module/kvm_intel/parameters/nested` |

**Quick check for validation readiness:**
```bash
HOST=$(hostname)

# 1. Check node config exists
ls site-config/nodes/${HOST}.yaml 2>/dev/null || echo "MISSING: node config"

# 2. Check API token exists (requires decrypted secrets)
grep -q "api_tokens:" site-config/secrets.yaml && \
  grep -q "${HOST}:" site-config/secrets.yaml && \
  echo "OK: API token found" || echo "MISSING: API token"

# 3. Check packer images
ls /var/lib/vz/template/iso/debian-*-custom.img 2>/dev/null || echo "MISSING: packer images"

# 4. Check nested virtualization
cat /sys/module/kvm_intel/parameters/nested | grep -q Y && \
  echo "OK: nested virt enabled" || echo "WARNING: nested virt disabled"
```

**Common issues:**

| Issue | Solution |
|-------|----------|
| `API token not found` | Generate token with `pveum`, add to secrets.yaml, run `make encrypt` |
| `node config missing` | Run `make node-config` on the PVE host |
| `packer images missing` | Run `./publish.sh` or download from packer release |
| `tofu provider version conflict` | Clear stale provider cache: `rm -rf iac-driver/.states/*/data/providers/` |

## Outputs

- Test execution results documented
- All introduced issues resolved
- Human approval of validation

## Checklist: Validation Complete

- [ ] Integration test scope determined
- [ ] External tool assumptions verified (tested actual CLI behavior)
- [ ] Appropriate test suites executed
- [ ] Performance claims measured (if applicable)
- [ ] Results documented
- [ ] No introduced failures remain
- [ ] Pre-existing issues documented (if any)
- [ ] Human reviewed and approved

## Anti-Patterns (Lessons from v0.8-v0.19)

### Don't Ship Untested Optimizations

If you claim "faster" or "optimized":

1. Measure baseline
2. Measure with change
3. Include results in PR
4. Revert if no improvement

**v0.19 example:** "Boot time optimization" was never validated against actual boot times. The change broke networking entirely.

### Don't Assume Prerequisite State

Document explicitly:
- What configs must exist
- What artifacts must be available
- What infrastructure must be running

**v0.18 example:** `packer --copy` assumed SHA256SUMS existed in previous releases - it didn't.

### Don't Skip Validation for "Simple" Changes

**v0.19:** A "simple" packer optimization broke networking because it was never tested with actual VM provisioning. Validation at PR time catches issues early.
