#!/bin/bash
# Add worktree for new or existing branch (usage: <branch> [--from <base>] [--force])
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
BRANCH=""
FROM_BASE=""
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --from)
            FROM_BASE="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Usage: create-worktree.sh <branch> [--from <base>] [--force]" >&2
            exit 1
            ;;
        *)
            if [ -z "$BRANCH" ]; then
                BRANCH="$1"
            else
                echo "ERROR: Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$BRANCH" ]; then
    echo "ERROR: Branch name required" >&2
    echo "Usage: create-worktree.sh <branch> [--from <base>] [--force]" >&2
    exit 1
fi

# Step 1: Detect repository type - must be worktree-form
echo "=== Create Worktree ==="
echo "Branch: $BRANCH"
echo ""

echo "Step 1/4: Detecting repository type..."

if [ ! -x "$SCRIPT_DIR/detect-repo-type.sh" ]; then
    echo "ERROR: detect-repo-type.sh not found" >&2
    exit 2
fi

REPO_TYPE=$("$SCRIPT_DIR/detect-repo-type.sh" "." 2>/dev/null || echo "NONE")

# Find bare repo path based on repo type
BARE_REPO=""
WORKTREE_BASE=""

case "$REPO_TYPE" in
    WORKTREE)
        # We're in a worktree - find the bare repo
        GITDIR=$(cat .git | sed 's/gitdir: //')
        # GITDIR points to bare_repo/worktrees/{name}
        BARE_REPO=$(dirname "$(dirname "$GITDIR")")
        WORKTREE_BASE=$(dirname "$(pwd)")
        echo "  Type: Worktree"
        echo "  Bare repo: $BARE_REPO"
        ;;
    BARE)
        # We're in a bare repo
        BARE_REPO=$(pwd)
        WORKTREE_BASE=$(dirname "$BARE_REPO")
        echo "  Type: Bare repository"
        ;;
    STANDARD)
        echo "  Type: Standard repository"
        echo ""
        echo "ERROR: Repository must be in worktree form"
        echo ""
        echo "Convert first with: convert-to-worktree.sh"
        exit 1
        ;;
    *)
        echo "ERROR: Not a git repository" >&2
        exit 1
        ;;
esac

# Verify bare repo exists and is valid
if [ ! -d "$BARE_REPO" ] || [ ! -f "$BARE_REPO/HEAD" ]; then
    echo "ERROR: Cannot find valid bare repository at: $BARE_REPO" >&2
    exit 2
fi

# Step 2: Parse branch name and determine directory
echo ""
echo "Step 2/4: Parsing branch name..."

# Convert branch name to directory name (feature/foo -> feature-foo)
DIR_NAME=$(echo "$BRANCH" | tr '/' '-')
WORKTREE_PATH="$WORKTREE_BASE/$DIR_NAME"

# Recognize branch type prefix
BRANCH_TYPE=""
case "$BRANCH" in
    feature/*)
        BRANCH_TYPE="feature"
        echo "  Branch type: Feature (new feature development)"
        ;;
    bugfix/*|fix/*)
        BRANCH_TYPE="bugfix"
        echo "  Branch type: Bugfix (bug fixes)"
        ;;
    hotfix/*)
        BRANCH_TYPE="hotfix"
        echo "  Branch type: Hotfix (emergency fixes)"
        ;;
    docs/*)
        BRANCH_TYPE="docs"
        echo "  Branch type: Documentation"
        ;;
    refactor/*)
        BRANCH_TYPE="refactor"
        echo "  Branch type: Refactor (code improvements)"
        ;;
    release/*)
        BRANCH_TYPE="release"
        echo "  Branch type: Release (release preparation)"
        ;;
    experiment/*)
        BRANCH_TYPE="experiment"
        echo "  Branch type: Experiment (exploration)"
        ;;
    *)
        echo "  Branch type: Standard"
        ;;
esac

echo "  Directory: $DIR_NAME/"
echo "  Path: $WORKTREE_PATH"

# Step 3: Check for conflicts
echo ""
echo "Step 3/4: Checking for conflicts..."

# Check if branch already has a worktree
EXISTING_WORKTREE=$(git -C "$BARE_REPO" worktree list --porcelain | grep -A1 "^worktree" | grep -B1 "branch refs/heads/$BRANCH$" | head -1 | sed 's/worktree //' || true)

if [ -n "$EXISTING_WORKTREE" ]; then
    echo "  Branch '$BRANCH' already has a worktree:"
    echo "    $EXISTING_WORKTREE"
    echo ""
    echo "Use that worktree or remove it first:"
    echo "  cd \"$EXISTING_WORKTREE\""
    echo "  # or"
    echo "  git -C \"$BARE_REPO\" worktree remove \"$EXISTING_WORKTREE\""
    exit 1
fi
echo "  No existing worktree for branch"

# Check if target directory exists
if [ -d "$WORKTREE_PATH" ]; then
    if [ "$FORCE" = "1" ]; then
        echo "  Directory exists - removing (--force)"
        rm -rf "$WORKTREE_PATH"
    else
        echo "  ERROR: Directory already exists: $WORKTREE_PATH"
        echo ""
        echo "Options:"
        echo "  1. Use --force to overwrite"
        echo "  2. Remove manually: rm -rf \"$WORKTREE_PATH\""
        echo "  3. Choose a different branch name"
        exit 1
    fi
else
    echo "  Target directory available"
fi

# Check if branch exists
BRANCH_EXISTS=$(git -C "$BARE_REPO" rev-parse --verify "refs/heads/$BRANCH" 2>/dev/null && echo "yes" || echo "no")

if [ "$BRANCH_EXISTS" = "yes" ]; then
    echo "  Branch '$BRANCH' exists (will checkout)"
    CREATE_BRANCH=0
else
    # Check if it exists on remote
    REMOTE_EXISTS=$(git -C "$BARE_REPO" rev-parse --verify "refs/remotes/origin/$BRANCH" 2>/dev/null && echo "yes" || echo "no")

    if [ "$REMOTE_EXISTS" = "yes" ]; then
        echo "  Branch '$BRANCH' exists on remote (will track)"
        CREATE_BRANCH=0
    else
        echo "  Branch '$BRANCH' does not exist (will create)"
        CREATE_BRANCH=1

        # Determine base for new branch
        if [ -z "$FROM_BASE" ]; then
            # Default to HEAD of the bare repo's default branch
            FROM_BASE=$(git -C "$BARE_REPO" symbolic-ref --short HEAD 2>/dev/null || echo "main")
        fi
        echo "  Base branch: $FROM_BASE"

        # Verify base exists
        if ! git -C "$BARE_REPO" rev-parse --verify "refs/heads/$FROM_BASE" >/dev/null 2>&1; then
            echo "ERROR: Base branch '$FROM_BASE' does not exist" >&2
            exit 1
        fi
    fi
fi

# Step 4: Create worktree
echo ""
echo "Step 4/4: Creating worktree..."

cd "$BARE_REPO"

if [ "$CREATE_BRANCH" = "1" ]; then
    # Create new branch with worktree
    echo "  Creating new branch '$BRANCH' from '$FROM_BASE'..."
    if ! git worktree add -b "$BRANCH" "$WORKTREE_PATH" "$FROM_BASE" 2>&1; then
        echo "ERROR: Failed to create worktree with new branch" >&2
        exit 2
    fi
else
    # Checkout existing branch
    echo "  Checking out existing branch '$BRANCH'..."
    if ! git worktree add "$WORKTREE_PATH" "$BRANCH" 2>&1; then
        echo "ERROR: Failed to create worktree" >&2
        exit 2
    fi
fi

# Success report
echo ""
echo "=========================================="
echo "SUCCESS: Worktree created"
echo "=========================================="
echo ""
if [ -n "$BRANCH_TYPE" ]; then
    echo "✓ Branch type: $BRANCH_TYPE"
fi
if [ "$CREATE_BRANCH" = "1" ]; then
    echo "✓ Created branch: $BRANCH from $FROM_BASE"
else
    echo "✓ Checked out branch: $BRANCH"
fi
echo "✓ Created worktree: $DIR_NAME/"
echo ""
echo "Location: $WORKTREE_PATH"
echo ""
echo "To start working:"
echo "  cd \"$WORKTREE_PATH\""
echo ""

# Output paths for scripting
echo "WORKTREE_PATH=$WORKTREE_PATH"
echo "BRANCH=$BRANCH"
