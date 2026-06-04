#!/bin/bash
# Convert existing local repo to worktree form (usage: [path] [--stash|--force])
set -e

# Configuration
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/Documents/Workspace/claudecode/WORKTREES}"
GITHUB_HOST="${GITHUB_HOST:-GITHUB}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
TARGET_PATH="."
AUTO_STASH=0
FORCE=0

for arg in "$@"; do
    case "$arg" in
        --stash)
            AUTO_STASH=1
            ;;
        --force)
            FORCE=1
            ;;
        -*)
            echo "Unknown option: $arg"
            echo "Usage: convert-to-worktree.sh [path] [--stash] [--force]"
            exit 1
            ;;
        *)
            TARGET_PATH="$arg"
            ;;
    esac
done

# Resolve to absolute path
TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"

echo "=== Convert to Worktree Form ==="
echo "Source: $TARGET_PATH"
echo ""

# Step 1: Detect repository type
echo "Step 1/7: Detecting repository type..."

if [ ! -x "$SCRIPT_DIR/detect-repo-type.sh" ]; then
    echo "ERROR: detect-repo-type.sh not found"
    exit 2
fi

REPO_TYPE=$("$SCRIPT_DIR/detect-repo-type.sh" "$TARGET_PATH" 2>/dev/null || echo "NONE")

case "$REPO_TYPE" in
    STANDARD)
        echo "  Type: Standard repository (will convert)"
        ;;
    WORKTREE)
        echo "  Type: Already in worktree form"
        echo ""
        echo "This repository is already a worktree."
        echo "No conversion needed."
        exit 0
        ;;
    BARE)
        echo "  Type: Bare repository"
        echo ""
        echo "This is already a bare repository."
        echo "Use 'git worktree add' to create worktrees from it."
        exit 0
        ;;
    *)
        echo "ERROR: Not a git repository"
        exit 1
        ;;
esac

# Step 2: Check preconditions
echo ""
echo "Step 2/7: Checking preconditions..."

cd "$TARGET_PATH"

# Check for uncommitted changes
CHANGES=$(git status --porcelain 2>/dev/null)
STASH_CREATED=0

if [ -n "$CHANGES" ]; then
    CHANGE_COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')
    echo "  ⚠️  $CHANGE_COUNT uncommitted change(s) detected"

    if [ "$AUTO_STASH" = "1" ]; then
        echo "  Auto-stashing changes..."
        # Include untracked files in stash
        if git stash push -u -m "convert-to-worktree: temporary stash" 2>&1 | grep -q "No local changes"; then
            echo "  No changes to stash (files may be ignored)"
        else
            STASH_CREATED=1
            echo "  Stashed successfully"
        fi
    else
        echo ""
        echo "ERROR: Uncommitted changes detected"
        echo ""
        echo "Options:"
        echo "  1. Run with --stash to auto-stash changes"
        echo "  2. Commit changes first: git add . && git commit -m 'WIP'"
        echo "  3. Discard changes: git checkout -- . && git clean -fd"
        echo ""
        echo "Changes:"
        echo "$CHANGES" | head -10
        [ "$CHANGE_COUNT" -gt 10 ] && echo "  ... and $((CHANGE_COUNT - 10)) more"
        exit 1
    fi
else
    echo "  Working directory clean"
fi

# Check for submodules
if [ -f ".gitmodules" ]; then
    SUBMODULE_COUNT=$(grep -c '^\[submodule' .gitmodules 2>/dev/null || echo "0")
    if [ "$SUBMODULE_COUNT" -gt 0 ]; then
        echo ""
        echo "ERROR: Repository contains $SUBMODULE_COUNT submodule(s)"
        echo ""
        echo "Submodule conversion is not supported in v1.0."
        echo "Consider converting submodules to subtrees or removing them first."

        # Unstash if we stashed
        if [ "$STASH_CREATED" = "1" ]; then
            git stash pop
        fi
        exit 1
    fi
fi
echo "  No submodules"

# Check if already in WORKTREES location
if [[ "$TARGET_PATH" == *"/WORKTREES/"* ]]; then
    echo ""
    echo "WARNING: Already inside WORKTREES directory"
    echo "  This may create a nested structure"
    echo ""
    if [ "$FORCE" != "1" ]; then
        echo "Use --force to proceed anyway"
        if [ "$STASH_CREATED" = "1" ]; then
            git stash pop
        fi
        exit 1
    fi
fi

# Step 3: Extract owner and repo
echo ""
echo "Step 3/7: Extracting owner and repo from remote..."

if [ ! -x "$SCRIPT_DIR/extract-owner.sh" ]; then
    echo "ERROR: extract-owner.sh not found"
    if [ "$STASH_CREATED" = "1" ]; then
        git stash pop
    fi
    exit 2
fi

OWNER_REPO=$("$SCRIPT_DIR/extract-owner.sh" "$TARGET_PATH" 2>&1) || EXTRACT_STATUS=$?
EXTRACT_STATUS=${EXTRACT_STATUS:-0}

if [ $EXTRACT_STATUS -ne 0 ]; then
    echo ""
    echo "ERROR: Could not extract owner from remote"
    echo "  $OWNER_REPO"
    echo ""
    echo "This repository may not have a GitHub remote configured."
    echo "Add a remote first: git remote add origin <github-url>"
    if [ "$STASH_CREATED" = "1" ]; then
        git stash pop
    fi
    exit 1
fi

OWNER=$(echo "$OWNER_REPO" | head -1)
REPO=$(echo "$OWNER_REPO" | tail -1)

echo "  Owner: $OWNER"
echo "  Repo:  $REPO"

# Step 4: Detect inception commit (optional, informational)
echo ""
echo "Step 4/7: Checking for inception commit..."

INCEPTION_HASH=""
INCEPTION_SIG=""
INCEPTION=$(git log --max-parents=0 --format="%H %G? %s" 2>/dev/null | head -1)

if [ -n "$INCEPTION" ]; then
    INCEPTION_HASH=$(echo "$INCEPTION" | cut -d' ' -f1)
    INCEPTION_SIG=$(echo "$INCEPTION" | cut -d' ' -f2)
    INCEPTION_MSG=$(echo "$INCEPTION" | cut -d' ' -f3-)

    case "$INCEPTION_SIG" in
        G)
            echo "  Found: $INCEPTION_HASH (signed ✓)"
            echo "  Message: $INCEPTION_MSG"
            ;;
        B)
            echo "  Found: $INCEPTION_HASH (bad signature ⚠️)"
            ;;
        U)
            echo "  Found: $INCEPTION_HASH (unknown signature)"
            ;;
        *)
            echo "  Found: $INCEPTION_HASH (unsigned)"
            ;;
    esac
else
    echo "  No inception commit found"
fi

# Step 5: Show preview and confirm
echo ""
echo "Step 5/7: Planning target structure..."

TARGET_BASE="$WORKTREE_ROOT/$GITHUB_HOST/$OWNER/$REPO"
BARE_REPO="$TARGET_BASE/$REPO.git"

# Get default branch
DEFAULT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
WORKTREE_PATH="$TARGET_BASE/$DEFAULT_BRANCH"

echo ""
echo "Target structure:"
echo "  $TARGET_BASE/"
echo "  ├── $REPO.git/     (bare repository)"
echo "  └── $DEFAULT_BRANCH/             (worktree)"
echo ""

# Check if target already exists
if [ -d "$TARGET_BASE" ]; then
    echo "ERROR: Target directory already exists"
    echo "  $TARGET_BASE"
    echo ""
    echo "Options:"
    echo "  1. Remove existing: rm -rf \"$TARGET_BASE\""
    echo "  2. Choose different WORKTREE_ROOT"
    if [ "$STASH_CREATED" = "1" ]; then
        git stash pop
    fi
    exit 1
fi

# Dry run mode
if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "=== DRY RUN - No changes made ==="
    if [ "$STASH_CREATED" = "1" ]; then
        git stash pop
    fi
    exit 0
fi

# Confirm unless --force
if [ "$FORCE" != "1" ]; then
    echo "This will:"
    echo "  1. Clone '$TARGET_PATH' as bare repository"
    echo "  2. Create worktree for '$DEFAULT_BRANCH' branch"
    echo "  3. Original repository remains unchanged"
    echo ""
    read -p "Continue? [y/N] " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        if [ "$STASH_CREATED" = "1" ]; then
            git stash pop
        fi
        exit 1
    fi
fi

# Step 6: Execute conversion
echo ""
echo "Step 6/7: Creating worktree structure..."

# Create parent directories
mkdir -p "$WORKTREE_ROOT/$GITHUB_HOST/$OWNER"

# Get the remote URL for cloning
REMOTE_URL=$(git remote get-url origin 2>/dev/null)

if [ -z "$REMOTE_URL" ]; then
    echo "ERROR: No origin remote configured"
    if [ "$STASH_CREATED" = "1" ]; then
        git stash pop
    fi
    exit 2
fi

# Clone as bare from local repo (faster than remote)
echo "  Creating bare clone from local..."
if ! git clone --bare "$TARGET_PATH" "$BARE_REPO" 2>&1; then
    echo "ERROR: Failed to create bare clone"
    rm -rf "$TARGET_BASE" 2>/dev/null || true
    if [ "$STASH_CREATED" = "1" ]; then
        cd "$TARGET_PATH"
        git stash pop
    fi
    exit 2
fi

# Configure bare repo
echo "  Configuring bare repository..."
git -C "$BARE_REPO" config core.bare true
git -C "$BARE_REPO" config --unset core.worktree 2>/dev/null || true

# Set remote to original GitHub URL (not local path)
git -C "$BARE_REPO" remote set-url origin "$REMOTE_URL"

# Set up remote tracking for all branches
git -C "$BARE_REPO" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# Create main worktree
echo "  Creating worktree for $DEFAULT_BRANCH..."
cd "$BARE_REPO"
if ! git worktree add "$WORKTREE_PATH" "$DEFAULT_BRANCH" 2>&1; then
    echo "ERROR: Failed to create worktree"
    echo "Rolling back..."
    rm -rf "$TARGET_BASE"
    if [ "$STASH_CREATED" = "1" ]; then
        cd "$TARGET_PATH"
        git stash pop
    fi
    exit 2
fi

# Apply stashed changes to new worktree if we stashed
if [ "$STASH_CREATED" = "1" ]; then
    echo "  Applying stashed changes to new worktree..."
    cd "$TARGET_PATH"
    # Export the stash as a patch
    STASH_PATCH=$(mktemp)
    git stash show -p > "$STASH_PATCH" 2>/dev/null || true
    git stash drop

    # Apply to new worktree
    if [ -s "$STASH_PATCH" ]; then
        cd "$WORKTREE_PATH"
        if git apply "$STASH_PATCH" 2>/dev/null; then
            echo "  Changes applied successfully"
        else
            echo "  WARNING: Could not apply stashed changes automatically"
            echo "  Patch saved to: $STASH_PATCH"
        fi
    fi
    rm -f "$STASH_PATCH" 2>/dev/null || true
fi

# Step 7: Validate and report
echo ""
echo "Step 7/7: Validating..."

cd "$WORKTREE_PATH"
if [ -x "$SCRIPT_DIR/validate-setup.sh" ]; then
    "$SCRIPT_DIR/validate-setup.sh" "$WORKTREE_PATH" 2>/dev/null || true
fi

# Count branches
BRANCH_COUNT=$(git -C "$BARE_REPO" branch -l 2>/dev/null | wc -l | tr -d ' ')

# Count commits
COMMIT_COUNT=$(git -C "$WORKTREE_PATH" rev-list --count HEAD 2>/dev/null || echo "?")

# Final report
echo ""
echo "=========================================="
echo "SUCCESS: Converted to worktree form"
echo "=========================================="
echo ""
echo "Location: $TARGET_BASE/"
echo "├── $REPO.git/        (bare repository)"
echo "└── $DEFAULT_BRANCH/             (worktree) <- start here"
echo ""
echo "✓ Branches: $BRANCH_COUNT preserved"
echo "✓ History: $COMMIT_COUNT commits intact"

if [ -n "$INCEPTION_HASH" ]; then
    if [ "$INCEPTION_SIG" = "G" ]; then
        echo "✓ Inception: Signed commit preserved ✓"
    else
        echo "✓ Inception: Commit preserved (${INCEPTION_SIG:-unsigned})"
    fi
fi

echo ""
echo "Original repository at '$TARGET_PATH' is unchanged."
echo "You may remove it after verifying the conversion:"
echo "  rm -rf \"$TARGET_PATH\""
echo ""
echo "To start working:"
echo "  cd \"$WORKTREE_PATH\""
echo ""
echo "To add more worktrees:"
echo "  cd \"$BARE_REPO\""
echo "  git worktree add \"$TARGET_BASE/{branch-dir}\" {branch}"
echo ""

# Output paths for scripting
echo "WORKTREE_PATH=$WORKTREE_PATH"
echo "BARE_REPO=$BARE_REPO"
