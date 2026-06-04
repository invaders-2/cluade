#!/bin/bash
# Validate worktree repository configuration (usage: [path])
set -e

TARGET_PATH="${1:-.}"
cd "$TARGET_PATH"

ISSUES=0

# Find bare repo from current location
if [ -f ".git" ]; then
    # We're in a worktree, get the bare repo path
    GITDIR=$(cat .git | sed 's/gitdir: //')
    # gitdir points to .git/worktrees/{name}/, bare is two levels up
    BARE_REPO=$(cd "$GITDIR" && cd ../.. && pwd)
elif git rev-parse --is-bare-repository 2>/dev/null | grep -q "true"; then
    BARE_REPO=$(pwd)
else
    echo "ERROR: Not in worktree-form repository"
    exit 2
fi

echo "Bare repo: $BARE_REPO"

# Check core.bare
CORE_BARE=$(git -C "$BARE_REPO" config core.bare 2>/dev/null || echo "unset")
if [ "$CORE_BARE" != "true" ]; then
    echo "ISSUE: core.bare is '$CORE_BARE' (should be 'true')"
    ISSUES=$((ISSUES + 1))
else
    echo "OK: core.bare = true"
fi

# Check core.worktree (should be unset)
CORE_WORKTREE=$(git -C "$BARE_REPO" config core.worktree 2>/dev/null || echo "")
if [ -n "$CORE_WORKTREE" ]; then
    echo "ISSUE: core.worktree is set to '$CORE_WORKTREE' (should be unset)"
    ISSUES=$((ISSUES + 1))
else
    echo "OK: core.worktree is unset"
fi

# Check worktree list
echo ""
echo "Worktrees:"
git -C "$BARE_REPO" worktree list

# Check for stale worktrees
STALE_COUNT=0
while IFS= read -r line; do
    if [[ "$line" == *"prunable"* ]]; then
        STALE_COUNT=$((STALE_COUNT + 1))
    fi
done < <(git -C "$BARE_REPO" worktree list --porcelain 2>/dev/null || true)

if [ "$STALE_COUNT" -gt 0 ]; then
    echo ""
    echo "ISSUE: $STALE_COUNT stale worktree entries (run 'git worktree prune')"
    ISSUES=$((ISSUES + 1))
else
    echo "OK: No stale worktrees"
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    echo "RESULT: All checks passed"
    exit 0
else
    echo "RESULT: $ISSUES issue(s) found"
    exit 1
fi
