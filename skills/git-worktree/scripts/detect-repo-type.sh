#!/bin/bash
# Detect repository type: STANDARD, WORKTREE, or BARE (usage: [path])
set -e

TARGET_PATH="${1:-.}"
cd "$TARGET_PATH"

if [ -d ".git" ]; then
    echo "STANDARD"
elif [ -f ".git" ]; then
    echo "WORKTREE"
elif git rev-parse --is-bare-repository 2>/dev/null | grep -q "true"; then
    echo "BARE"
else
    echo "NONE" >&2
    exit 1
fi
