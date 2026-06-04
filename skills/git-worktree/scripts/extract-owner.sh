#!/bin/bash
# Extract GitHub owner and repo from remote URL (usage: [path])
set -e

TARGET_PATH="${1:-.}"
cd "$TARGET_PATH"

REMOTE_URL=$(git remote get-url origin 2>/dev/null)

if [ -z "$REMOTE_URL" ]; then
    echo "NO_REMOTE" >&2
    exit 1
fi

# Parse owner and repo from HTTPS or SSH URL
# HTTPS: https://github.com/owner/repo.git or https://github.com/owner/repo
# SSH: git@github.com:owner/repo.git or git@github.com:owner/repo
OWNER=$(echo "$REMOTE_URL" | sed -E 's|.*[:/]([^/]+)/[^/]+(\.git)?$|\1|')
REPO=$(echo "$REMOTE_URL" | sed -E 's|.*[:/][^/]+/([^/]+)(\.git)?$|\1|' | sed 's/\.git$//')

if [ -z "$OWNER" ] || [ "$OWNER" = "$REMOTE_URL" ]; then
    echo "PARSE_FAILED: Could not extract owner from $REMOTE_URL" >&2
    exit 1
fi

if [ -z "$REPO" ] || [ "$REPO" = "$REMOTE_URL" ]; then
    echo "PARSE_FAILED: Could not extract repo from $REMOTE_URL" >&2
    exit 1
fi

echo "$OWNER"
echo "$REPO"
