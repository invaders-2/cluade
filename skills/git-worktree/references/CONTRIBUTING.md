# git-worktree - Contributing Guide

Guide for developers contributing to the git-worktree skill.

## Script Documentation

### clone-as-worktree.sh
- **Purpose**: Clone GitHub repo directly into worktree form
- **Usage**: `<github-url> [branch]`
- **Exit**: 0=success, 1=args, 2=failed

### convert-to-worktree.sh
- **Purpose**: Convert existing local repo to worktree form
- **Usage**: `[path] [--stash|--force]`
- **Exit**: 0=success, 1=precond, 2=failed

### create-worktree.sh
- **Purpose**: Add worktree for new or existing branch
- **Usage**: `<branch> [--from <base>] [--force]`
- **Exit**: 0=success, 1=precond, 2=failed

### list-worktrees.sh
- **Purpose**: Show all worktrees with status
- **Usage**: `[path] [--json|--porcelain]`
- **Exit**: 0=success, 1=not-worktree

### remove-worktree.sh
- **Purpose**: Safely remove worktree
- **Usage**: `<worktree|branch> [--force] [--delete-branch]`
- **Exit**: 0=success, 1=changes, 2=failed

### troubleshoot.sh
- **Purpose**: Diagnose and fix common worktree issues
- **Usage**: `[path] [--fix] [--verbose]`
- **Exit**: 0=clean, 1=issues, 2=fatal

### detect-repo-type.sh
- **Purpose**: Detect repository type (STANDARD/WORKTREE/BARE)
- **Usage**: `[path]`
- **Exit**: 0=detected, 1=not-repo

### extract-owner.sh
- **Purpose**: Parse owner/repo from GitHub remote
- **Usage**: `[path]`
- **Exit**: 0=found, 1=no-remote

### detect-inception.sh
- **Purpose**: Find signed inception commit (Open Integrity)
- **Usage**: `[path] [--verify] [--json]`
- **Exit**: 0=found/none, 1=error

### validate-setup.sh
- **Purpose**: Verify worktree repository configuration
- **Usage**: `[path]`
- **Exit**: 0=valid, 1=issues, 2=not-worktree

## Testing

### Automated Tests

Run test suite:
```bash
cd tests && ./test_scripts.sh
```

### Manual Testing

**Test 1: Clone as worktree**
```bash
# Say "clone worktree from https://github.com/octocat/Hello-World"
# Expected: Creates WORKTREES/GITHUB/octocat/Hello-World/
```

**Test 2: Convert to worktree**
```bash
# In a standard repo with GitHub remote
# Say "convert to worktree"
# Expected: Creates worktree structure in WORKTREES/
```

**Test 3: Create branch worktree**
```bash
# In worktree-form repo
# Say "create worktree for feature/test"
# Expected: Creates feature-test/ directory
```

**Test 4: Troubleshooting**
```bash
# In worktree with issues
# Say "troubleshoot worktrees"
# Expected: Detects and offers to fix issues
```

### Verification

After operations:
- `git worktree list` - Shows all worktrees
- `git -C <bare>.git config core.bare` - Should be "true"
- `git -C <bare>.git config core.worktree` - Should be empty

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKTREE_ROOT` | `~/Documents/Workspace/claudecode/WORKTREES` | Root for worktree repos |
| `GITHUB_HOST` | `GITHUB` | Subdirectory for GitHub repos |
| `DRY_RUN` | `0` | Set to 1 for preview mode |

## Contributing Workflow

1. **Make changes** to scripts or documentation
2. **Run tests**:
   ```bash
   cd tests && ./test_scripts.sh
   ```
3. **Update SKILL.md** if protocol changes
4. **Test manually**: Try commands in a real project
5. **Submit PR** with:
   - Clear description of changes
   - Test results
   - Any new dependencies or requirements

## Version Management

- **Authoritative version**: SKILL.md frontmatter only
- **Reference docs**: No version numbers
- **Scripts**: No version comments - git history is source of truth

---

*Contributing guide for git-worktree skill*
