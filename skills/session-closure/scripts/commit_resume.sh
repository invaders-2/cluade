#!/bin/bash
# Commit CLAUDE_RESUME.md with -S -s flags (blocks if unexpected files changed)
set -e

# Parse arguments
PROJECT_ROOT="${1:-.}"

# Change to project root directory
cd "$PROJECT_ROOT" || {
    echo "❌ Error: Cannot access project root: $PROJECT_ROOT" >&2
    exit 1
}

# Verify we're in a project root (should have CLAUDE.md)
if [ ! -f "CLAUDE.md" ]; then
    echo "⚠️  Warning: No CLAUDE.md found - may not be project root" >&2
    echo "   Working directory: $(pwd)" >&2
fi

# Check if in git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "✓ Not a git repository (skipping commit)"
    exit 0
fi

# Check for changes using porcelain v2 (machine-parseable format)
CHANGES=$(git status --porcelain=v2 2>/dev/null)

if [ -z "$CHANGES" ]; then
    echo "✓ No uncommitted changes (resume may already be committed)"
    exit 0
fi

# Find which resume location exists
if [ -f ".claude/CLAUDE_RESUME.md" ]; then
    RESUME_FILE=".claude/CLAUDE_RESUME.md"
elif [ -f "CLAUDE_RESUME.md" ]; then
    RESUME_FILE="CLAUDE_RESUME.md"
else
    RESUME_FILE=""
fi

# Check for CLAUDE_RESUME.md changes (either location)
# Porcelain v2 formats:
# - Type 1 (ordinary changed): "1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>"
#   Where XY can be: .M (unstaged), M. (staged), MM (both)
# - Type ? (untracked): "? <path>"
RESUME_CHANGES=$(echo "$CHANGES" | grep -E "(^|/)CLAUDE_RESUME.md$" || true)

# Get all other changes (not CLAUDE_RESUME.md in either location)
UNEXPECTED=$(echo "$CHANGES" | grep -v -E "(^|/)CLAUDE_RESUME.md$" || true)

if [ -n "$UNEXPECTED" ]; then
    echo "❌ ERROR: Unexpected changes detected during closure" >&2
    echo "" >&2
    echo "Step 0.5 should have committed all pre-existing changes." >&2
    echo "These changes appeared DURING closure execution:" >&2
    echo "" >&2
    echo "$UNEXPECTED" >&2
    echo "" >&2
    echo "Full status:" >&2
    git status --short >&2
    exit 1
fi

# If RESUME_CHANGES is empty, no changes to commit
if [ -z "$RESUME_CHANGES" ]; then
    echo "✓ No changes to CLAUDE_RESUME.md"
    exit 0
fi

# Only CLAUDE_RESUME.md changed - safe to commit
if [ -n "$RESUME_FILE" ]; then
    git add "$RESUME_FILE"
else
    # Try both locations
    git add CLAUDE_RESUME.md .claude/CLAUDE_RESUME.md 2>/dev/null || true
fi

# Show what's being committed
echo "=== Staged changes ==="
git diff --staged

# Commit with standardized message
# Note: This is a minimal template. Claude should enhance this message based on:
# - Workspace commit protocols (CORE_PROCESSES.md § Git Commit Protocol)
# - Resume content (summarize what was accomplished)
# - Session significance (bug fixes, milestones, etc.)
#
# WARNING: NEVER include Claude Code attribution or Co-Authored-By: Claude
#          User reviews/approves changes. GPG -S -s flags establish accountability.
git commit -S -s -m "Session closure: $(date +%Y-%m-%d-%H%M)

Resume created with session state."

# Verify no Claude attribution in commit message (protocol compliance check)
COMMIT_MSG=$(git log -1 --format=%B)
if echo "$COMMIT_MSG" | grep -qi "claude code\|co-authored-by.*claude\|generated with"; then
    echo "⚠️  WARNING: Commit contains Claude attribution (protocol violation)" >&2
    echo "   This violates workspace Git Commit Protocol" >&2
    echo "   User should amend: git commit --amend" >&2
fi

echo "✅ Session resume committed"
exit 0
