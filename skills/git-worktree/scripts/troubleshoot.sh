#!/bin/bash
# Diagnose and fix common worktree issues (usage: [path] [--fix] [--verbose])
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
TARGET_PATH="."
FIX_MODE=0
VERBOSE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --fix)
            FIX_MODE=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Usage: troubleshoot.sh [path] [--fix] [--verbose]" >&2
            exit 1
            ;;
        *)
            TARGET_PATH="$1"
            shift
            ;;
    esac
done

cd "$TARGET_PATH"

echo "=== Worktree Troubleshooter ==="
echo ""

# Step 1: Find bare repo
echo "Step 1/5: Locating bare repository..."

if [ ! -x "$SCRIPT_DIR/detect-repo-type.sh" ]; then
    echo "ERROR: detect-repo-type.sh not found" >&2
    exit 2
fi

REPO_TYPE=$("$SCRIPT_DIR/detect-repo-type.sh" "." 2>/dev/null || echo "NONE")
BARE_REPO=""

case "$REPO_TYPE" in
    WORKTREE)
        GITDIR=$(cat .git | sed 's/gitdir: //')
        BARE_REPO=$(dirname "$(dirname "$GITDIR")")
        echo "  Type: Worktree"
        echo "  Bare repo: $BARE_REPO"
        ;;
    BARE)
        BARE_REPO=$(pwd)
        echo "  Type: Bare repository"
        ;;
    STANDARD)
        echo "  Type: Standard repository"
        echo ""
        echo "ERROR: Not a worktree-form repository"
        echo ""
        echo "Convert first with: convert-to-worktree.sh"
        exit 2
        ;;
    *)
        echo "ERROR: Not a git repository" >&2
        exit 2
        ;;
esac

# Verify bare repo exists
if [ ! -d "$BARE_REPO" ] || [ ! -f "$BARE_REPO/HEAD" ]; then
    echo "ERROR: Cannot find valid bare repository at: $BARE_REPO" >&2
    exit 2
fi

# Track issues
ISSUES_FOUND=0
ISSUES_FIXED=0

# Step 2: Check core.bare configuration
echo ""
echo "Step 2/5: Checking core.bare configuration..."

CORE_BARE=$(git -C "$BARE_REPO" config core.bare 2>/dev/null || echo "unset")
if [ "$CORE_BARE" != "true" ]; then
    echo "  ISSUE: core.bare is '$CORE_BARE' (should be 'true')"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))

    if [ "$FIX_MODE" = "1" ]; then
        echo "  FIX: Setting core.bare = true..."
        git -C "$BARE_REPO" config core.bare true
        echo "  FIXED: core.bare now set to true"
        ISSUES_FIXED=$((ISSUES_FIXED + 1))
    else
        echo "  To fix: git -C \"$BARE_REPO\" config core.bare true"
    fi
else
    echo "  OK: core.bare = true"
fi

# Step 3: Check core.worktree configuration
echo ""
echo "Step 3/5: Checking core.worktree configuration..."

CORE_WORKTREE=$(git -C "$BARE_REPO" config core.worktree 2>/dev/null || echo "")
if [ -n "$CORE_WORKTREE" ]; then
    echo "  ISSUE: core.worktree is set to '$CORE_WORKTREE'"
    echo "         This causes confusing warnings with bare repo + worktrees"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))

    if [ "$FIX_MODE" = "1" ]; then
        echo "  FIX: Unsetting core.worktree..."
        git -C "$BARE_REPO" config --unset core.worktree
        echo "  FIXED: core.worktree now unset"
        ISSUES_FIXED=$((ISSUES_FIXED + 1))
    else
        echo "  To fix: git -C \"$BARE_REPO\" config --unset core.worktree"
    fi
else
    echo "  OK: core.worktree is unset"
fi

# Step 4: Check for stale/prunable worktrees
echo ""
echo "Step 4/5: Checking for stale worktree entries..."

STALE_WORKTREES=()
LOCKED_WORKTREES=()

# Parse porcelain output
CURRENT_PATH=""
while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+) ]]; then
        CURRENT_PATH="${BASH_REMATCH[1]}"
    elif [[ "$line" == "prunable" ]]; then
        if [ -n "$CURRENT_PATH" ]; then
            STALE_WORKTREES+=("$CURRENT_PATH")
        fi
    elif [[ "$line" == "locked" ]]; then
        if [ -n "$CURRENT_PATH" ]; then
            LOCKED_WORKTREES+=("$CURRENT_PATH")
        fi
    fi
done < <(git -C "$BARE_REPO" worktree list --porcelain 2>/dev/null || true)

if [ ${#STALE_WORKTREES[@]} -gt 0 ]; then
    echo "  ISSUE: ${#STALE_WORKTREES[@]} stale worktree entries found:"
    for wt in "${STALE_WORKTREES[@]}"; do
        echo "    - $wt"
    done
    ISSUES_FOUND=$((ISSUES_FOUND + ${#STALE_WORKTREES[@]}))

    if [ "$FIX_MODE" = "1" ]; then
        echo "  FIX: Pruning stale entries..."
        git -C "$BARE_REPO" worktree prune
        echo "  FIXED: Stale entries pruned"
        ISSUES_FIXED=$((ISSUES_FIXED + ${#STALE_WORKTREES[@]}))
    else
        echo "  To fix: git -C \"$BARE_REPO\" worktree prune"
    fi
else
    echo "  OK: No stale worktree entries"
fi

# Report locked worktrees (informational)
if [ ${#LOCKED_WORKTREES[@]} -gt 0 ]; then
    echo ""
    echo "  INFO: ${#LOCKED_WORKTREES[@]} locked worktree(s):"
    for wt in "${LOCKED_WORKTREES[@]}"; do
        echo "    - $wt"
        LOCK_REASON=$(git -C "$BARE_REPO" worktree list --porcelain | grep -A2 "worktree $wt$" | grep "locked " | sed 's/locked //' || echo "(no reason)")
        if [ "$VERBOSE" = "1" ]; then
            echo "      Lock reason: $LOCK_REASON"
        fi
    done
    echo "  Locked worktrees are intentional; use 'git worktree unlock' to unlock"
fi

# Step 5: Check worktree directory integrity
echo ""
echo "Step 5/5: Checking worktree directory integrity..."

BROKEN_LINKS=()
MISSING_DIRS=()

while IFS= read -r line; do
    # Parse line: /path HEAD [branch] or /path (bare)
    WORKTREE_DIR=$(echo "$line" | awk '{print $1}')

    # Skip bare repo entries (marked with "(bare)" in worktree list)
    if [[ "$line" == *"(bare)"* ]]; then
        continue
    fi

    # Also skip if path matches bare repo (belt and suspenders)
    if [ "$WORKTREE_DIR" = "$BARE_REPO" ]; then
        continue
    fi

    # Check if directory exists
    if [ ! -d "$WORKTREE_DIR" ]; then
        MISSING_DIRS+=("$WORKTREE_DIR")
        continue
    fi

    # Check if .git file exists and points correctly
    if [ ! -f "$WORKTREE_DIR/.git" ]; then
        BROKEN_LINKS+=("$WORKTREE_DIR (missing .git file)")
        continue
    fi

    # Verify .git file content
    GITDIR_CONTENT=$(cat "$WORKTREE_DIR/.git" | sed 's/gitdir: //')
    if [ ! -d "$GITDIR_CONTENT" ]; then
        BROKEN_LINKS+=("$WORKTREE_DIR (bad gitdir: $GITDIR_CONTENT)")
    fi

done < <(git -C "$BARE_REPO" worktree list 2>/dev/null || true)

if [ ${#MISSING_DIRS[@]} -gt 0 ]; then
    echo "  ISSUE: ${#MISSING_DIRS[@]} missing worktree directories:"
    for dir in "${MISSING_DIRS[@]}"; do
        echo "    - $dir"
    done
    ISSUES_FOUND=$((ISSUES_FOUND + ${#MISSING_DIRS[@]}))

    if [ "$FIX_MODE" = "1" ]; then
        echo "  FIX: Pruning references to missing directories..."
        git -C "$BARE_REPO" worktree prune
        echo "  FIXED: References pruned"
        ISSUES_FIXED=$((ISSUES_FIXED + ${#MISSING_DIRS[@]}))
    else
        echo "  To fix: git -C \"$BARE_REPO\" worktree prune"
    fi
else
    echo "  OK: All worktree directories exist"
fi

if [ ${#BROKEN_LINKS[@]} -gt 0 ]; then
    echo ""
    echo "  ISSUE: ${#BROKEN_LINKS[@]} broken worktree links:"
    for link in "${BROKEN_LINKS[@]}"; do
        echo "    - $link"
    done
    ISSUES_FOUND=$((ISSUES_FOUND + ${#BROKEN_LINKS[@]}))

    echo "  Manual repair required - recreate worktree:"
    echo "    git worktree remove <path> && git worktree add <path> <branch>"
fi

# Verbose: show current worktree state
if [ "$VERBOSE" = "1" ]; then
    echo ""
    echo "=== Current Worktree State ==="
    git -C "$BARE_REPO" worktree list
fi

# Summary
echo ""
echo "=========================================="
if [ $ISSUES_FOUND -eq 0 ]; then
    echo "RESULT: No issues found"
    echo "=========================================="
    echo ""
    echo "Worktree configuration is healthy."
    exit 0
elif [ "$FIX_MODE" = "1" ]; then
    REMAINING=$((ISSUES_FOUND - ISSUES_FIXED))
    if [ $REMAINING -eq 0 ]; then
        echo "RESULT: All $ISSUES_FOUND issues fixed"
        echo "=========================================="
        exit 0
    else
        echo "RESULT: $ISSUES_FIXED of $ISSUES_FOUND issues fixed"
        echo "        $REMAINING issues require manual repair"
        echo "=========================================="
        exit 1
    fi
else
    echo "RESULT: $ISSUES_FOUND issue(s) found"
    echo "=========================================="
    echo ""
    echo "Run with --fix to attempt automatic repair:"
    echo "  troubleshoot.sh --fix"
    exit 1
fi
