# git-worktree - User Guide

Interactive git worktree management for Claude Code.

## Installation

### Plugin (Recommended)
```bash
/plugin marketplace add ChristopherA/claude_code_tools
/plugin install git-worktree@claude-code-tools
```

### Manual
```bash
git clone https://github.com/ChristopherA/claude_code_tools.git
cp -r claude_code_tools/skills/git-worktree ~/.claude/skills/
```

## Usage

### Clone Repository as Worktree
```
User: clone worktree from https://github.com/owner/repo
User: get worktree from owner/repo
```

### Convert Existing Repository
```
User: convert to worktree
```

### Manage Worktrees
```
User: create worktree for feature/new-api
User: list worktrees
User: remove worktree feature-auth
```

### Troubleshoot
```
User: troubleshoot worktrees
User: validate worktree setup
```

## Directory Structure

The skill creates:
```
~/Documents/Workspace/claudecode/WORKTREES/GITHUB/{owner}/{repo}/
├── {repo}.git/     (bare repository)
└── main/           (main branch worktree)
```

Additional worktrees are added as sibling directories:
```
├── {repo}.git/
├── main/
├── develop/
└── feature-auth/
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKTREE_ROOT` | `~/Documents/Workspace/claudecode/WORKTREES` | Root directory |
| `GITHUB_HOST` | `GITHUB` | Subdirectory for GitHub repos |
| `DRY_RUN` | `0` | Set to 1 for preview mode |

## Troubleshooting

### "core.bare and core.worktree do not make sense"

**Fix**: Run `troubleshoot worktrees` and accept the fix, or manually:
```bash
git -C <bare-repo> config --unset core.worktree
```

### "Already checked out at..."

**Cause**: Branch already has a worktree.

**Fix**: Use `list worktrees` to find existing worktree, then either use it or remove it first.

### Stale Worktree Entries

**Cause**: Worktree directory deleted without `git worktree remove`.

**Fix**: Run `troubleshoot worktrees` or manually:
```bash
git worktree prune
```

### Convert Fails - No Remote

**Cause**: Repository has no GitHub remote configured.

**Fix**: Add a remote first:
```bash
git remote add origin https://github.com/owner/repo
```

### Convert Fails - Submodules

**Cause**: Repositories with submodules are not supported in v1.0.

**Fix**: Remove submodules or use standard git workflow.

## Limitations

- Submodules not supported
- GitHub remotes only (GitLab/Bitbucket need manual owner)
- Gists not supported (no branches)

## Getting Help

1. Check error messages in terminal
2. Run `troubleshoot worktrees` for diagnostics
3. See [troubleshooting.md](troubleshooting.md) for advanced issues
4. Report issues: https://github.com/ChristopherA/claude_code_tools/issues

---

*User guide for git-worktree skill*
