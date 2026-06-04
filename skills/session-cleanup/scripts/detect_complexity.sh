#!/bin/bash
# detect_complexity.sh - Determine session cleanup depth
# Usage: detect_complexity.sh [PROJECT_ROOT]

PROJECT_ROOT="${1:-$PWD}"
cd "$PROJECT_ROOT" 2>/dev/null || exit 1

# Check if git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "DEPTH: standard"
    echo "INFO: Not a git repository, using default depth"
    exit 0
fi

# Count commits today (proxy for "this session")
COMMITS=$(git log --oneline --since="midnight" 2>/dev/null | wc -l | tr -d ' ')
COMMITS=${COMMITS:-0}

# Count modified files in recent commits
if [ "$COMMITS" -gt 0 ]; then
    MODIFIED=$(git diff --stat HEAD~${COMMITS} 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1)
else
    # No commits today, check working tree
    MODIFIED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
fi
MODIFIED=${MODIFIED:-0}

# Determine depth
if [ "$COMMITS" -le 1 ] && [ "$MODIFIED" -lt 5 ]; then
    echo "DEPTH: light"
    echo "INFO: $COMMITS commits, ~$MODIFIED files changed"
elif [ "$COMMITS" -le 5 ] && [ "$MODIFIED" -lt 15 ]; then
    echo "DEPTH: standard"
    echo "INFO: $COMMITS commits, ~$MODIFIED files changed"
else
    echo "DEPTH: thorough"
    echo "INFO: $COMMITS commits, ~$MODIFIED files changed"
fi

exit 0
