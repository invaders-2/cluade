#!/bin/bash
# Safely remove worktree (usage: <worktree|branch> [--force] [--delete-branch])
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
TARGET=""
FORCE=0
DELETE_BRANCH=0

while [ $# -gt 0 ]; do
    case "$1" in
        --force|-f)
            FORCE=1
            shift
            ;;
        --delete-branch)
            DELETE_BRANCH=1
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Usage: remove-worktree.sh <worktree|branch> [--force] [--delete-branch]" >&2
            exit 1
            ;;
        *)
            if [ -z "$TARGET" ]; then
                TARGET="$1"
            else
                echo "ERROR: Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo "ERROR: Worktree or branch name required" >&2
    echo "Usage: remove-worktree.sh <worktree|branch> [--force] [--delete-branch]" >&2
    exit 1
fi

echo "=== Remove Worktree ==="
echo "Target: $TARGET"
echo ""

# Detect repository type and find bare repo
echo "Step 1/4: Finding bare repository..."

if [ ! -x "$SCRIPT_DIR/detect-repo-type.sh" ]; then
    echo "ERROR: detect-repo-type.sh not found" >&2
    exit 2
fi

REPO_TYPE=$("$SCRIPT_DIR/detect-repo-type.sh" "." 2>/dev/null || echo "NONE")

BARE_REPO=""
WORKTREE_BASE=""

case "$REPO_TYPE" in
    WORKTREE)
        GITDIR=$(cat .git | sed 's/gitdir: //')
        BARE_REPO=$(dirname "$(dirname "$GITDIR")")
        WORKTREE_BASE=$(dirname "$(pwd)")
        echo "  Bare repo: $BARE_REPO"
        ;;
    BARE)
        BARE_REPO=$(pwd)
        WORKTREE_BASE=$(dirname "$BARE_REPO")
        echo "  Bare repo: $BARE_REPO"
        ;;
    STANDARD)
        echo "ERROR: Not a worktree-form repository"
        echo ""
        echo "This is a standard git repository."
        exit 1
        ;;
    *)
        echo "ERROR: Not a git repository" >&2
        exit 1
        ;;
esac

if [ ! -d "$BARE_REPO" ] || [ ! -f "$BARE_REPO/HEAD" ]; then
    echo "ERROR: Cannot find valid bare repository at: $BARE_REPO" >&2
    exit 2
fi

# Step 2: Find the worktree to remove
echo ""
echo "Step 2/4: Locating worktree..."

WORKTREE_PATH=""
BRANCH_NAME=""

# Get all worktrees
WORKTREE_LIST=$(git -C "$BARE_REPO" worktree list --porcelain)

# Try to match TARGET as:
# 1. Absolute path
# 2. Relative path from current directory
# 3. Directory name in worktree base
# 4. Branch name

# Check if TARGET is a path
if [ -d "$TARGET" ]; then
    WORKTREE_PATH="$(cd "$TARGET" && pwd)"
    echo "  Found by path: $WORKTREE_PATH"
elif [ -d "$WORKTREE_BASE/$TARGET" ]; then
    WORKTREE_PATH="$WORKTREE_BASE/$TARGET"
    echo "  Found in worktree base: $WORKTREE_PATH"
else
    # Try to find by branch name (convert / to - for directory lookup)
    DIR_NAME=$(echo "$TARGET" | tr '/' '-')
    if [ -d "$WORKTREE_BASE/$DIR_NAME" ]; then
        WORKTREE_PATH="$WORKTREE_BASE/$DIR_NAME"
        echo "  Found by branch name: $WORKTREE_PATH"
    else
        # Search in worktree list by branch name
        FOUND_PATH=$(echo "$WORKTREE_LIST" | grep -A2 "^worktree " | grep -B1 "branch refs/heads/$TARGET$" | head -1 | sed 's/worktree //' || true)
        if [ -n "$FOUND_PATH" ]; then
            WORKTREE_PATH="$FOUND_PATH"
            echo "  Found by branch lookup: $WORKTREE_PATH"
        fi
    fi
fi

if [ -z "$WORKTREE_PATH" ]; then
    echo "ERROR: Could not find worktree: $TARGET"
    echo ""
    echo "Available worktrees:"
    git -C "$BARE_REPO" worktree list
    exit 2
fi

# Verify it's not the bare repo
if [ "$WORKTREE_PATH" = "$BARE_REPO" ]; then
    echo "ERROR: Cannot remove bare repository"
    exit 1
fi

# Get the branch name for this worktree
BRANCH_NAME=$(echo "$WORKTREE_LIST" | grep -A2 "^worktree $WORKTREE_PATH$" | grep "^branch " | sed 's/branch refs\/heads\///' || true)

if [ -z "$BRANCH_NAME" ]; then
    # Might be detached HEAD
    IS_DETACHED=$(echo "$WORKTREE_LIST" | grep -A2 "^worktree $WORKTREE_PATH$" | grep "^detached$" || true)
    if [ -n "$IS_DETACHED" ]; then
        BRANCH_NAME="(detached HEAD)"
    fi
fi

echo "  Worktree: $WORKTREE_PATH"
echo "  Branch: ${BRANCH_NAME:-unknown}"

# Check if current directory is the worktree we're removing
CURRENT_DIR=$(pwd)
if [ "$CURRENT_DIR" = "$WORKTREE_PATH" ] || [[ "$CURRENT_DIR" == "$WORKTREE_PATH"/* ]]; then
    echo ""
    echo "ERROR: Cannot remove current working directory"
    echo ""
    echo "Change to a different worktree first:"
    echo "  cd \"$WORKTREE_BASE/main\"  # or another worktree"
    exit 1
fi

# Step 3: Check for uncommitted changes
echo ""
echo "Step 3/4: Checking for uncommitted changes..."

if [ -d "$WORKTREE_PATH" ]; then
    CHANGES=$(git -C "$WORKTREE_PATH" status --porcelain 2>/dev/null || true)

    if [ -n "$CHANGES" ]; then
        CHANGE_COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')
        echo "  ⚠️  $CHANGE_COUNT uncommitted change(s) detected"
        echo ""

        if [ "$FORCE" = "1" ]; then
            echo "  --force specified, proceeding anyway"
        else
            echo "Changes in worktree:"
            echo "$CHANGES" | head -10
            [ "$CHANGE_COUNT" -gt 10 ] && echo "  ... and $((CHANGE_COUNT - 10)) more"
            echo ""
            echo "ERROR: Uncommitted changes detected"
            echo ""
            echo "Options:"
            echo "  1. Use --force to remove anyway (changes will be lost!)"
            echo "  2. Commit changes first: cd \"$WORKTREE_PATH\" && git add . && git commit"
            echo "  3. Stash changes: cd \"$WORKTREE_PATH\" && git stash"
            exit 1
        fi
    else
        echo "  Working directory clean"
    fi
else
    echo "  Worktree directory not found (stale entry)"
    # Check if it's marked as prunable
    IS_STALE=$(echo "$WORKTREE_LIST" | grep -A3 "^worktree $WORKTREE_PATH$" | grep "^prunable$" || true)
    if [ -n "$IS_STALE" ]; then
        echo "  Marked as stale/prunable"
    fi
fi

# Step 4: Remove worktree
echo ""
echo "Step 4/4: Removing worktree..."

cd "$BARE_REPO"

if [ "$FORCE" = "1" ]; then
    if ! git worktree remove --force "$WORKTREE_PATH" 2>&1; then
        echo "WARNING: git worktree remove failed, trying prune..."
        # Remove directory manually and prune
        rm -rf "$WORKTREE_PATH" 2>/dev/null || true
        git worktree prune
    fi
else
    if ! git worktree remove "$WORKTREE_PATH" 2>&1; then
        echo "ERROR: Failed to remove worktree"
        echo ""
        echo "Try --force to force removal"
        exit 2
    fi
fi

echo "  Worktree removed successfully"

# Optionally delete branch
if [ "$DELETE_BRANCH" = "1" ] && [ -n "$BRANCH_NAME" ] && [ "$BRANCH_NAME" != "(detached HEAD)" ]; then
    echo ""
    echo "Deleting branch '$BRANCH_NAME'..."

    # Check if branch is fully merged
    DEFAULT_BRANCH=$(git -C "$BARE_REPO" symbolic-ref --short HEAD 2>/dev/null || echo "main")

    if git -C "$BARE_REPO" branch -d "$BRANCH_NAME" 2>&1; then
        echo "  Branch deleted (was fully merged)"
    else
        echo "  Branch not fully merged"
        echo "  Use 'git branch -D $BRANCH_NAME' from bare repo to force delete"
    fi
fi

# Success report
echo ""
echo "=========================================="
echo "SUCCESS: Worktree removed"
echo "=========================================="
echo ""
echo "✓ Removed worktree: $(basename "$WORKTREE_PATH")/"
if [ "$DELETE_BRANCH" = "1" ] && [ -n "$BRANCH_NAME" ] && [ "$BRANCH_NAME" != "(detached HEAD)" ]; then
    echo "✓ Deleted branch: $BRANCH_NAME"
fi
echo ""
echo "Remaining worktrees:"
git -C "$BARE_REPO" worktree list
