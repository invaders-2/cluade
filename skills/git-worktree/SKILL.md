---
name: git-worktree
version: 1.0.1
description: >
  Interactive skill for git worktree operations. Safely converts standard repos
  to worktree form, creates/lists/removes worktrees, and troubleshoots issues.
  Uses WORKTREES/GITHUB/{owner}/{repo}/ workspace structure for organization.
  Preserves inception commits (Open Integrity pattern) during conversion.

  WHEN: User says "clone worktree", "create worktree from", "get worktree from",
  "convert to worktree", "create worktree for", "list worktrees", "remove worktree",
  "troubleshoot worktrees", "validate worktree", OR mentions working with
  multiple branches simultaneously.

  WHEN NOT: Standard git operations (commit, push, pull), single-branch workflows,
  or when user explicitly wants standard repo structure.
---

# Git Worktree Skill

## Contents

1. [Commands](#commands)
2. [Clone as Worktree](#clone-as-worktree)
3. [Convert to Worktree Form](#convert-to-worktree-form)
4. [Create Worktree](#create-worktree)
5. [List Worktrees](#list-worktrees)
6. [Remove Worktree](#remove-worktree)
7. [Troubleshoot](#troubleshoot)
8. [Directory Structure](#directory-structure)
9. [Scripts Reference](#scripts-reference)

---

## Commands

| Trigger | Action |
|---------|--------|
| "clone worktree from {url}" | Clone GitHub repo directly into worktree form |
| "get worktree from {repo}" | Same as clone (natural language variant) |
| "create worktree from {url}" | Same as clone |
| "convert to worktree" | Convert current repo to worktree form |
| "create worktree for {branch}" | Add worktree for branch |
| "list worktrees" | Show all worktrees with status |
| "remove worktree {name}" | Safely remove worktree |
| "troubleshoot worktrees" | Diagnose and fix issues |
| "validate worktree" | Check configuration |

**Recognition patterns**:
- GitHub URLs: `https://github.com/owner/repo`, `git@github.com:owner/repo.git`
- Shorthand: `owner/repo`, `blockchaincommons/research`
- Natural variants: "clone", "get", "create from", "set up worktree"

---

## Clone as Worktree

Clone a GitHub repository directly into worktree form.

### Flow

```
User: "clone worktree from https://github.com/BlockchainCommons/research"

Step 1: Parse GitHub URL
  → Owner: BlockchainCommons
  → Repo: research

Step 2: Check target location
  → Target: ~/Documents/Workspace/claudecode/WORKTREES/GITHUB/BlockchainCommons/research/
  → If exists: Report and stop

Step 3: Preview and confirm
  "This will create:
    ~/Documents/Workspace/claudecode/WORKTREES/GITHUB/BlockchainCommons/research/
    ├── research.git/   (bare repository)
    └── main/           (main branch worktree)

   Proceed? [Y/n]"

Step 4: Execute clone
  → Clone as bare repository
  → Configure (core.bare=true, unset core.worktree)
  → Create main worktree

Step 5: Report success
  "✅ Cloned into worktree form

   Location: ~/Documents/Workspace/claudecode/WORKTREES/GITHUB/BlockchainCommons/research/
   ├── research.git/   (bare repository)
   └── main/           (worktree) ← start here

   cd ~/Documents/Workspace/claudecode/WORKTREES/GITHUB/BlockchainCommons/research/main"
```

### Script

```bash
"${SKILL_BASE:-$HOME/.claude/skills/git-worktree}/scripts/clone-as-worktree.sh" "<url>" [branch]
```

---

## Convert to Worktree Form

Convert an existing local repository to worktree form.

### Flow

```
User: "convert to worktree"

Step 1: Detect repository type
  scripts/detect-repo-type.sh
  → STANDARD: Continue
  → WORKTREE: "Already in worktree form"
  → BARE: "Already a bare repository"

Step 2: Check preconditions
  → Uncommitted changes? Offer stash/commit/cancel
  → Submodules? Warn and block (v1.0)
  → Already in WORKTREES? Warn about nesting

Step 3: Extract owner from remote
  scripts/extract-owner.sh
  → GitHub remote found: Extract owner
  → No remote: "Add remote first: git remote add origin <url>"

Step 4: Detect inception commit (optional)
  scripts/detect-inception.sh
  → Signed inception: Note for preservation
  → No inception: Continue normally

Step 5: Preview and confirm
  "This will create:
    ~/Documents/Workspace/claudecode/WORKTREES/GITHUB/{owner}/{repo}/
    ├── {repo}.git/   (bare repository)
    └── main/         (main branch worktree)

   ⚠️  2 uncommitted changes detected
   Options: [A] Stash and convert  [B] Commit first  [C] Cancel"

Step 6: Execute conversion
  scripts/convert-to-worktree.sh [--stash]
  → Create directory structure
  → Clone local repo as bare
  → Configure bare repository
  → Create main worktree
  → Apply stashed changes if applicable

Step 7: Validate and report
  scripts/validate-setup.sh
  "✅ Converted to worktree form

   Location: ~/Documents/Workspace/claudecode/WORKTREES/GITHUB/{owner}/{repo}/
   ├── {repo}.git/   (bare repository)
   └── main/         (worktree) ← start here

   ✓ Branches: 3 preserved
   ✓ History: 47 commits intact
   ✓ Inception: Signed commit preserved ✓

   Original repository unchanged. Remove after verification:
     rm -rf /original/path"
```

### Script

```bash
"${SKILL_BASE:-$HOME/.claude/skills/git-worktree}/scripts/convert-to-worktree.sh" [path] [--stash] [--force]
```

### Options

- `--stash`: Auto-stash uncommitted changes (includes untracked with -u)
- `--force`: Skip confirmation prompt

---

## Create Worktree

Add a worktree for a new or existing branch.

### Flow

```
User: "create worktree for feature/new-api"

Step 1: Verify worktree-form repository
  → Standard repo: "Convert first with 'convert to worktree'"
  → Worktree/bare: Continue

Step 2: Parse branch name
  → Branch type: feature (new feature development)
  → Directory: feature-new-api/
  → Path: ~/WORKTREES/GITHUB/{owner}/{repo}/feature-new-api/

Step 3: Check for conflicts
  → Branch has worktree? Report existing location
  → Directory exists? Offer rename/remove

Step 4: Determine branch source
  → Branch exists: Checkout existing
  → Branch on remote: Track remote
  → New branch: Create from HEAD (or --from base)

Step 5: Create worktree
  scripts/create-worktree.sh feature/new-api [--from main]

Step 6: Report success
  "✅ Worktree created

   ✓ Branch type: feature
   ✓ Created branch: feature/new-api from main
   ✓ Created worktree: feature-new-api/

   cd ../feature-new-api"
```

### Script

```bash
"${SKILL_BASE:-$HOME/.claude/skills/git-worktree}/scripts/create-worktree.sh" <branch> [--from <base>] [--force]
```

### Branch Type Recognition

| Prefix | Type | Description |
|--------|------|-------------|
| `feature/` | Feature | New feature development |
| `bugfix/`, `fix/` | Bugfix | Bug fixes |
| `hotfix/` | Hotfix | Emergency fixes |
| `docs/` | Documentation | Documentation changes |
| `refactor/` | Refactor | Code improvements |
| `release/` | Release | Release preparation |
| `experiment/` | Experiment | Exploration/POC |

---

## List Worktrees

Show all worktrees with status.

### Flow

```
User: "list worktrees"

Step 1: Verify worktree-form repository
  → Standard repo: "Convert first with 'convert to worktree'"

Step 2: Display worktrees
  scripts/list-worktrees.sh

  "📁 research (BlockchainCommons)

   Bare repo: ~/WORKTREES/GITHUB/BlockchainCommons/research/research.git

   Worktrees:
   → main              main/           (current)
     develop           develop/
     feature/auth      feature-auth/

   3 worktree(s) total"
```

### Script

```bash
"${SKILL_BASE:-$HOME/.claude/skills/git-worktree}/scripts/list-worktrees.sh" [path] [--json|--porcelain]
```

### Output Formats

- Human-readable (default): Formatted display with current marker
- `--json`: JSON output for scripting
- `--porcelain`: Machine-readable, one worktree per line

---

## Remove Worktree

Safely remove a worktree.

### Flow

```
User: "remove worktree feature-auth"

Step 1: Find worktree
  → By path: /path/to/feature-auth
  → By directory name: feature-auth
  → By branch: feature/auth → feature-auth/

Step 2: Check preconditions
  → Current directory? "Change to different worktree first"
  → Uncommitted changes? Warn and offer --force

Step 3: Remove worktree
  scripts/remove-worktree.sh feature-auth [--force] [--delete-branch]

Step 4: Report success
  "✅ Worktree removed

   ✓ Removed worktree: feature-auth/

   Remaining worktrees:
   → main     main/    (current)
     develop  develop/"
```

### Script

```bash
"${SKILL_BASE:-$HOME/.claude/skills/git-worktree}/scripts/remove-worktree.sh" <worktree|branch> [--force] [--delete-branch]
```

### Options

- `--force`: Remove even with uncommitted changes (changes lost!)
- `--delete-branch`: Also delete the branch after removing worktree

---

## Troubleshoot

Diagnose and fix common worktree issues.

### Flow

```
User: "troubleshoot worktrees"

Step 1: Locate bare repository
  scripts/detect-repo-type.sh
  → Find bare repo from current location

Step 2: Check core.bare
  → Should be 'true'
  → If wrong: Offer fix

Step 3: Check core.worktree
  → Should be unset (causes warnings if set)
  → If set: Offer fix

Step 4: Check stale entries
  → List prunable worktrees
  → Offer prune

Step 5: Check directory integrity
  → Missing worktree directories
  → Broken .git file links

Report:
  "RESULT: 2 issue(s) found

   ISSUE: core.worktree is set
   ISSUE: 1 stale worktree entry

   Run with --fix to repair:
     troubleshoot.sh --fix"
```

### Script

```bash
"${SKILL_BASE:-$HOME/.claude/skills/git-worktree}/scripts/troubleshoot.sh" [path] [--fix] [--verbose]
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| core.bare not true | Manual config change | `git config core.bare true` |
| core.worktree set | Clone artifact | `git config --unset core.worktree` |
| Stale entries | Deleted worktree dirs | `git worktree prune` |
| Broken links | Moved directories | Recreate worktree |

---

## Directory Structure

The skill uses a workspace-level WORKTREES pattern:

```
~/Documents/Workspace/claudecode/WORKTREES/
└── GITHUB/
    ├── ChristopherA/                    # GitHub user
    │   ├── repo-name/
    │   │   ├── repo-name.git/           # Bare repository
    │   │   ├── main/                    # Main branch worktree
    │   │   └── feature-auth/            # Feature branch worktree
    │   │
    │   └── another-repo/
    │       ├── another-repo.git/
    │       └── main/
    │
    └── BlockchainCommons/               # GitHub organization
        └── research/
            ├── research.git/
            ├── main/
            └── develop/
```

### Why This Structure

- **Mirrors GitHub URLs**: `github.com/{owner}/{repo}` → `WORKTREES/GITHUB/{owner}/{repo}`
- **Prevents name collisions**: Different owners can have repos with same name
- **Claude CLI compatible**: Under `~/Documents/Workspace/claudecode/` for access
- **Centralized**: All worktree repos in one location

### Branch to Directory Mapping

| Branch | Directory |
|--------|-----------|
| `main` | `main/` |
| `develop` | `develop/` |
| `feature/foo-bar` | `feature-foo-bar/` |
| `bugfix/issue-123` | `bugfix-issue-123/` |

Rule: Replace `/` with `-` in directory names.

---

## Scripts Reference

All scripts in `${SKILL_BASE:-$HOME/.claude/skills/git-worktree}/scripts/`:

| Script | Purpose | Exit Codes |
|--------|---------|------------|
| `clone-as-worktree.sh` | Clone GitHub URL into worktree form | 0=success, 1=args, 2=failed |
| `convert-to-worktree.sh` | Convert local repo to worktree form | 0=success, 1=precond, 2=failed |
| `create-worktree.sh` | Add worktree for branch | 0=success, 1=precond, 2=failed |
| `detect-inception.sh` | Find signed inception commit | 0=found/none, 1=error |
| `detect-repo-type.sh` | Detect STANDARD/WORKTREE/BARE | 0=detected, 1=not repo |
| `extract-owner.sh` | Parse owner/repo from remote | 0=found, 1=no remote |
| `list-worktrees.sh` | Show all worktrees | 0=success, 1=not worktree |
| `remove-worktree.sh` | Safely remove worktree | 0=success, 1=changes, 2=failed |
| `troubleshoot.sh` | Diagnose and fix issues | 0=clean, 1=issues, 2=fatal |
| `validate-setup.sh` | Verify configuration | 0=valid, 1=issues |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKTREE_ROOT` | `~/Documents/Workspace/claudecode/WORKTREES` | Root for all worktree repos |
| `GITHUB_HOST` | `GITHUB` | Subdirectory for GitHub repos |
| `DRY_RUN` | `0` | Set to 1 for preview mode |

---

## Limitations

### Not Supported (v1.0)

- **Submodules**: Repos with submodules cannot be converted
- **GitHub Gists**: Gists don't support branches/worktrees
- **Non-GitHub remotes**: Only GitHub URLs are parsed (GitLab, Bitbucket need manual owner)
- **No remote repos**: Requires GitHub remote for owner detection; add remote first with `git remote add origin <url>`

---

## References

For advanced troubleshooting, load `references/troubleshooting.md`.

---

*Git Worktree Skill v1.0.0 - December 2025*
