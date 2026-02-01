# Phase 68: Release Housekeeping

Clean up branches and perform post-release maintenance.

## Purpose

Clean up development artifacts and prepare for next cycle.

## Prerequisites

- Phase 67 (AAR) complete

## Activities

### 1. Delete Merged Branches

For each repo:

```bash
for repo in .claude .github ansible bootstrap homestak-dev iac-driver packer site-config tofu; do
  echo "=== $repo ==="
  cd ~/homestak-dev/$repo

  # Delete merged local branches
  git branch --merged | grep -v master | xargs -r git branch -d

  # Prune stale remote tracking refs
  git remote prune origin
done
```

### 2. Check for Unmerged Branches

Branches may show as "ahead" even when merged via squash:

```bash
for repo in .claude .github ansible bootstrap homestak-dev iac-driver packer site-config tofu; do
  echo "=== $repo ==="
  cd ~/homestak-dev/$repo

  for branch in $(git branch -r | grep -v HEAD | grep -v master); do
    if [[ -n "$(git diff master..$branch 2>/dev/null)" ]]; then
      echo "UNMERGED: $branch"
    fi
  done
done
```

Use `git diff` to verify actual unmerged content before deleting.

### 3. Delete Remote Branches

For branches confirmed as merged:

```bash
git push origin --delete branch-name
```

### 4. Clean Sprint Branches

Sprint branches should have been cleaned in Sprint Close, but verify:

```bash
git branch -r | grep sprint-
# If any remain, delete them
```

### 5. Check Release Count

Prompt for sunset if count exceeds 5:

```bash
count=$(gh release list --repo homestak-dev/homestak-dev --limit 100 | wc -l)
if [[ $count -gt 5 ]]; then
  echo "Consider: ./scripts/release.sh sunset --below-version X.Y --dry-run"
fi
```

### 6. Update Repository Settings

Verify "Automatically delete head branches" is enabled in GitHub settings for each repo.

## Using release.sh

```bash
./scripts/release.sh housekeeping
```

Performs branch cleanup across repos.

## Outputs

- Merged branches deleted
- Remote refs pruned
- Release count checked

## Checklist: Housekeeping Complete

- [ ] Merged local branches deleted
- [ ] Remote tracking refs pruned
- [ ] Unmerged branches reviewed
- [ ] Sprint branches cleaned
- [ ] Release count checked
- [ ] Sunset prompted if needed

## Next Phase

Proceed to [70-retrospective.md](70-retrospective.md) for release retrospective and issue closure.
