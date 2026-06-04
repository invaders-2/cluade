#!/bin/bash
# Archive CLAUDE_RESUME.md to archives/CLAUDE_RESUME/<timestamp>.md (skips if git-tracked)
set -e

# Parse arguments
PROJECT_ROOT="${1:-.}"
DRY_RUN=false

# Check for --dry-run in any argument position
for arg in "$@"; do
    if [ "$arg" = "--dry-run" ]; then
        DRY_RUN=true
    fi
done

# Change to project root directory
cd "$PROJECT_ROOT" || {
    echo "❌ Error: Cannot access project root: $PROJECT_ROOT" >&2
    exit 1
}

# Verify we're in a project root (should have CLAUDE.md in root or .claude/)
if [ ! -f "CLAUDE.md" ] && [ ! -f ".claude/CLAUDE.md" ]; then
    echo "⚠️  Warning: No CLAUDE.md found (checked root and .claude/) - may not be project root" >&2
    echo "   Working directory: $(pwd)" >&2
fi

# Find resume file (prefer .claude/ location)
if [ -f ".claude/CLAUDE_RESUME.md" ]; then
    SOURCE=".claude/CLAUDE_RESUME.md"
    ARCHIVE_DIR=".claude/archives/CLAUDE_RESUME"
elif [ -f "CLAUDE_RESUME.md" ]; then
    SOURCE="CLAUDE_RESUME.md"
    ARCHIVE_DIR="archives/CLAUDE_RESUME"
else
    SOURCE=""
fi
TIMESTAMP=$(date +%Y-%m-%d-%H%M)

# Function: Check if in git repo
in_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

# Function: Check if file is tracked in git
is_git_tracked() {
    local file="$1"
    git ls-files --error-unmatch "$file" >/dev/null 2>&1
}

# Main logic

# Check if source exists
if [ -z "$SOURCE" ] || [ ! -f "$SOURCE" ]; then
    echo "✓ No previous resume to archive"
    exit 0
fi

# Check if in git repo and file is tracked
if in_git_repo && is_git_tracked "$SOURCE"; then
    # File is tracked - check if it has uncommitted changes
    if git diff --quiet "$SOURCE" 2>/dev/null && git diff --cached --quiet "$SOURCE" 2>/dev/null; then
        # Clean - no uncommitted changes
        echo "✅ CLAUDE_RESUME.md tracked in git with no uncommitted changes"
        echo "   Git history provides backup - safe to proceed"
        echo "✓ Skipping archive (git history serves as backup)"
    else
        # Dirty - has uncommitted changes
        echo "⚠️  CLAUDE_RESUME.md has uncommitted changes"
        echo "   RECOMMENDED: Commit resume alone before making other changes"
        echo ""
        echo "   This preserves a clean checkpoint in git history."
        echo "   Current changes will be committed by session-closure Step 0.5"
        echo ""
        echo "✓ Skipping archive (git will track changes)"
    fi
    exit 0
fi

# Archive the file
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would archive: $SOURCE → $ARCHIVE_DIR/$TIMESTAMP.md"
    exit 0
fi

# Create archive directory
mkdir -p "$ARCHIVE_DIR"

# Move file to archive
mv "$SOURCE" "$ARCHIVE_DIR/$TIMESTAMP.md"
echo "📦 Archived to $ARCHIVE_DIR/$TIMESTAMP.md"

exit 0
