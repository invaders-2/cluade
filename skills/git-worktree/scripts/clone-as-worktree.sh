#!/bin/bash
# Clone GitHub repo directly into worktree form (usage: <github-url> [branch])
set -e

# Configuration
# Default to claudecode workspace WORKTREES for Claude CLI compatibility
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/Documents/Workspace/claudecode/WORKTREES}"
GITHUB_HOST="${GITHUB_HOST:-GITHUB}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Arguments
GITHUB_URL="$1"
BRANCH="${2:-}"  # Optional: specific branch to checkout

if [ -z "$GITHUB_URL" ]; then
    echo "Usage: clone-as-worktree.sh <github-url> [branch]"
    echo ""
    echo "Examples:"
    echo "  clone-as-worktree.sh https://github.com/owner/repo"
    echo "  clone-as-worktree.sh git@github.com:owner/repo.git"
    echo "  clone-as-worktree.sh owner/repo                     # Shorthand"
    echo "  clone-as-worktree.sh owner/repo develop             # With branch"
    exit 1
fi

echo "=== Clone as Worktree ==="
echo "URL: $GITHUB_URL"
echo ""

# Step 1: Parse owner and repo from URL
echo "Step 1/5: Parsing GitHub URL..."

# Normalize URL - handle multiple formats:
# HTTPS: https://github.com/owner/repo or https://github.com/owner/repo.git
# SSH: git@github.com:owner/repo.git or git@github.com:owner/repo
# Shorthand: owner/repo (expanded to https://github.com/owner/repo)

ORIGINAL_INPUT="$GITHUB_URL"

# Check for shorthand format (owner/repo without github.com)
if [[ "$GITHUB_URL" =~ ^[^/:@]+/[^/:@]+$ ]] && [[ ! "$GITHUB_URL" =~ github\.com ]]; then
    # Shorthand format: owner/repo -> expand to full URL
    OWNER=$(echo "$GITHUB_URL" | cut -d'/' -f1)
    REPO=$(echo "$GITHUB_URL" | cut -d'/' -f2 | sed 's/\.git$//')
    GITHUB_URL="https://github.com/$OWNER/$REPO"
    echo "  Expanded: $ORIGINAL_INPUT → $GITHUB_URL"
else
    # Extract owner from full URL
    OWNER=$(echo "$GITHUB_URL" | sed -E 's|.*github\.com[:/]([^/]+)/.*|\1|')
    # Extract repo (remove .git suffix if present)
    REPO=$(echo "$GITHUB_URL" | sed -E 's|.*github\.com[:/][^/]+/([^/]+)(\.git)?$|\1|' | sed 's/\.git$//')
fi

if [ -z "$OWNER" ] || [ -z "$REPO" ] || [ "$OWNER" = "$GITHUB_URL" ]; then
    echo "ERROR: Could not parse GitHub URL"
    echo "  Expected formats:"
    echo "    https://github.com/owner/repo"
    echo "    git@github.com:owner/repo.git"
    echo "    owner/repo (shorthand)"
    exit 1
fi

echo "  Owner: $OWNER"
echo "  Repo:  $REPO"

# Step 2: Determine target paths
echo ""
echo "Step 2/5: Planning target structure..."

TARGET_BASE="$WORKTREE_ROOT/$GITHUB_HOST/$OWNER/$REPO"
BARE_REPO="$TARGET_BASE/$REPO.git"

echo "  Target: $TARGET_BASE"

# Check if target already exists
if [ -d "$TARGET_BASE" ]; then
    echo ""
    echo "ERROR: Target directory already exists"
    echo "  $TARGET_BASE"
    echo ""
    echo "Options:"
    echo "  1. Remove existing: rm -rf \"$TARGET_BASE\""
    echo "  2. Use existing worktree structure (cd into it)"
    exit 1
fi

# Preview mode
if [ "${DRY_RUN:-0}" = "1" ]; then
    echo ""
    echo "=== DRY RUN - No changes made ==="
    echo ""
    echo "Would create:"
    echo "  $TARGET_BASE/"
    echo "  ├── $REPO.git/     (bare repository)"
    echo "  └── {branch}/      (worktree)"
    exit 0
fi

# Step 3: Create bare clone
echo ""
echo "Step 3/5: Cloning as bare repository..."

# Create parent directories
mkdir -p "$WORKTREE_ROOT/$GITHUB_HOST/$OWNER"

# Clone as bare
if ! git clone --bare "$GITHUB_URL" "$BARE_REPO" 2>&1; then
    echo "ERROR: Failed to clone repository"
    rm -rf "$TARGET_BASE" 2>/dev/null || true
    exit 2
fi

echo "  Created: $BARE_REPO"

# Step 4: Configure bare repo
echo ""
echo "Step 4/5: Configuring bare repository..."

# Ensure core.bare is true
git -C "$BARE_REPO" config core.bare true

# Unset core.worktree if set (prevents warnings)
git -C "$BARE_REPO" config --unset core.worktree 2>/dev/null || true

# Set up remote tracking for all branches
git -C "$BARE_REPO" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# Fetch to populate remote tracking branches
git -C "$BARE_REPO" fetch origin 2>&1 | head -5 || true

echo "  Configuration complete"

# Step 5: Determine default branch and create worktree
echo ""
echo "Step 5/5: Creating worktree..."

cd "$BARE_REPO"

# Determine which branch to use
if [ -n "$BRANCH" ]; then
    # User specified a branch
    DEFAULT_BRANCH="$BRANCH"
else
    # Get default branch from remote HEAD
    DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')

    # Fallback: check for main or master
    if [ -z "$DEFAULT_BRANCH" ]; then
        if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
            DEFAULT_BRANCH="main"
        elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
            DEFAULT_BRANCH="master"
        else
            # Use first available branch
            DEFAULT_BRANCH=$(git branch -l | head -1 | tr -d '* ')
        fi
    fi
fi

if [ -z "$DEFAULT_BRANCH" ]; then
    echo "ERROR: Could not determine default branch"
    echo "  Specify branch explicitly: clone-as-worktree.sh $GITHUB_URL <branch>"
    rm -rf "$TARGET_BASE"
    exit 2
fi

MAIN_WORKTREE="$TARGET_BASE/$DEFAULT_BRANCH"

echo "  Branch: $DEFAULT_BRANCH"
echo "  Path:   $MAIN_WORKTREE"

# Create the worktree
if ! git worktree add "$MAIN_WORKTREE" "$DEFAULT_BRANCH" 2>&1; then
    echo "ERROR: Failed to create worktree"
    echo "Rolling back..."
    rm -rf "$TARGET_BASE"
    exit 2
fi

# Validate (optional, don't fail on validation issues)
echo ""
echo "Validating..."
if [ -x "$SCRIPT_DIR/validate-setup.sh" ]; then
    "$SCRIPT_DIR/validate-setup.sh" "$MAIN_WORKTREE" 2>/dev/null || true
fi

# Final report
echo ""
echo "=========================================="
echo "SUCCESS: Cloned into worktree form"
echo "=========================================="
echo ""
echo "Structure:"
echo "  $TARGET_BASE/"
echo "  ├── $REPO.git/        (bare repository)"
echo "  └── $DEFAULT_BRANCH/             (worktree) <- start here"
echo ""
echo "To start working:"
echo "  cd \"$MAIN_WORKTREE\""
echo ""
echo "To add more worktrees:"
echo "  cd \"$BARE_REPO\""
echo "  git worktree add \"$TARGET_BASE/{branch-dir}\" {branch}"
echo ""

# Output the worktree path for scripting
echo "WORKTREE_PATH=$MAIN_WORKTREE"
