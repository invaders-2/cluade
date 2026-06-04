# Git Worktree Troubleshooting Guide

> Advanced troubleshooting for git worktree issues
>
> **Load when**: User encounters errors or asks for troubleshooting help

---

## Quick Fixes

### Issue: "warning: core.bare and core.worktree do not make sense"

**Cause**: `core.worktree` is set in a bare repository (should be unset).

**Fix**:
```bash
# Find bare repo location
git rev-parse --git-common-dir

# Unset core.worktree
git -C <bare-repo-path> config --unset core.worktree
```

**Via skill**: Run `troubleshoot worktrees` and accept the fix.

---

### Issue: "fatal: '<branch>' is already checked out at '<path>'"

**Cause**: Trying to create a worktree for a branch that already has one.

**Fix**:
```bash
# List existing worktrees
git worktree list

# Remove the existing worktree (if no longer needed)
git worktree remove <path>

# Or use a different branch name
git worktree add <new-path> -b <different-branch-name>
```

---

### Issue: Stale worktree entries after directory deletion

**Cause**: Worktree directory was manually deleted without `git worktree remove`.

**Fix**:
```bash
# Prune stale entries
git worktree prune

# Verify cleanup
git worktree list
```

**Via skill**: Run `troubleshoot worktrees` - it detects and prunes stale entries.

---

### Issue: "fatal: not a git repository" in worktree directory

**Cause**: The `.git` file in the worktree points to a location that no longer exists.

**Fix**:
1. Check if bare repo still exists at expected location
2. If moved, update `.git` file to point to new location:
   ```bash
   # In worktree directory, view current pointer
   cat .git
   # Output: gitdir: /old/path/repo.git/worktrees/branch

   # Update to correct path
   echo "gitdir: /new/path/repo.git/worktrees/branch" > .git
   ```
3. Also update bare repo's pointer:
   ```bash
   # In bare repo
   echo "/new/worktree/path" > worktrees/branch/gitdir
   ```

---

## Common Scenarios

### Scenario: Converting a repo that's already in worktree form

**Symptom**: Running "convert to worktree" reports "Already in worktree form"

**Resolution**: The repo is already correctly configured. Use:
- `list worktrees` to see existing worktrees
- `create worktree for <branch>` to add more worktrees

---

### Scenario: Can't create worktree - "directory already exists"

**Resolution**: The target directory exists (possibly from a failed previous attempt).

Options:
1. Remove the directory: `rm -rf <path>` then retry
2. Use a different directory name
3. If it's a valid worktree, use `list worktrees` to confirm

---

### Scenario: Worktree conversion failed mid-process

**Symptom**: Partial structure created, original repo may be modified.

**Recovery**:
1. Check original repo: `cd /original/path && git status`
2. If original is intact, remove partial worktree structure:
   ```bash
   rm -rf ~/WORKTREES/GITHUB/<owner>/<repo>/
   ```
3. Retry conversion

The skill includes rollback logic, but if interrupted (Ctrl+C), manual cleanup may be needed.

---

### Scenario: Uncommitted changes after conversion

**Symptom**: Changes were present before conversion but missing after.

**Cause**: Stash may not have been applied correctly.

**Check**:
```bash
# In new worktree location
git stash list

# If stash exists, apply it
git stash pop
```

---

## Advanced Diagnostics

### Verify worktree integrity

```bash
# From any worktree or bare repo
git worktree list --porcelain

# Check for issues
git worktree list --porcelain | grep -E "(prunable|locked)"
```

### Check bare repo configuration

```bash
# Should return "true"
git -C <bare-repo> config core.bare

# Should return empty/nothing
git -C <bare-repo> config core.worktree
```

### Verify worktree link chain

```bash
# In worktree directory
cat .git  # Shows gitdir pointer

# In bare repo
cat worktrees/<branch>/gitdir  # Shows worktree path
```

Both paths should be valid and point to each other.

---

## Error Codes

Scripts return these exit codes:

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Continue |
| 1 | Precondition failed | Check input, fix issue, retry |
| 2 | Fatal error | Review error message, may need manual intervention |

---

## Getting Help

If troubleshooting doesn't resolve the issue:

1. Run `validate worktree setup` for detailed diagnostics
2. Check `git worktree list --porcelain` output
3. Verify disk space and permissions
4. For inception commit issues, use `detect-inception.sh --verbose`

---

*Troubleshooting guide v1.0 - December 2025*
