#!/bin/bash
# Detect uncommitted changes, exit 0=clean, 1=changes-found, 2=error
#
# IMPORTANT: This script is duplicated in both session-closure and session-resume
# Any changes must be synchronized manually between:
#   ~/.claude/skills/session-closure/scripts/check_uncommitted_changes.sh
#   ~/.claude/skills/session-resume/scripts/check_uncommitted_changes.sh
# Run tests/test_sync.sh to verify files remain identical
set -euo pipefail

# Accept working directory parameter (required)
WORK_DIR="${1:-.}"

# Change to working directory
cd "$WORK_DIR" || {
    echo "❌ Error: Cannot access directory: $WORK_DIR"
    exit 2
}

# Check if this is a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    # Not a git repo - skip silently (this is OK)
    exit 0
fi

# Check for uncommitted changes using porcelain v2 (machine-parseable)
CHANGES=$(git status --porcelain=v2)

if [ -z "$CHANGES" ]; then
    # Clean state - proceed silently
    exit 0
fi

# ============================================================================
# UNCOMMITTED CHANGES DETECTED - BLOCK EXECUTION
# ============================================================================

# Analyze what changed for contextual messaging
RESUME_CHANGED=false
OTHER_CHANGED=false

# Check if CLAUDE_RESUME.md changed (either location)
if ! git diff --quiet CLAUDE_RESUME.md 2>/dev/null || ! git diff --cached --quiet CLAUDE_RESUME.md 2>/dev/null; then
    RESUME_CHANGED=true
fi
if ! git diff --quiet .claude/CLAUDE_RESUME.md 2>/dev/null || ! git diff --cached --quiet .claude/CLAUDE_RESUME.md 2>/dev/null; then
    RESUME_CHANGED=true
fi

# Check if any other files changed (exclude both resume locations)
OTHER_FILES=$(echo "$CHANGES" | grep -v "CLAUDE_RESUME.md" | grep -v ".claude/CLAUDE_RESUME.md" || true)
if [ -n "$OTHER_FILES" ]; then
    OTHER_CHANGED=true
fi

# Display contextual header based on what changed
echo "❌ Cannot resume: Uncommitted changes detected"
echo ""

if [ "$RESUME_CHANGED" = true ] && [ "$OTHER_CHANGED" = true ]; then
    echo "📝 Changes found in CLAUDE_RESUME.md AND other project files"
    echo "   (Manual edits to resume + work done while session suspended)"
elif [ "$RESUME_CHANGED" = true ]; then
    echo "📝 Changes found in CLAUDE_RESUME.md"
    echo "   (Manual edits made between sessions)"
else
    echo "📝 Changes found in project files"
    echo "   (Work done while session was suspended)"
fi

echo ""
echo "The following files have uncommitted changes:"
echo ""
git status --short
echo ""
echo "=== Full diff ==="
git diff HEAD

# For untracked files, show content (transparency about what will be committed)
git ls-files --others --exclude-standard | while IFS= read -r file; do
    echo ""
    echo "=== New file: $file ==="
    cat "$file"
done

# ============================================================================
# CHECK FOR SECRET FILES (WARNING ONLY)
# ============================================================================

# Extract filenames from porcelain v2 output (last field)
FILENAMES=$(echo "$CHANGES" | awk '{print $NF}')

# Check for common secret file patterns
SECRET_FILES=$(echo "$FILENAMES" | grep -E '\.(env|credentials|key|pem|secret)$|credentials\.json|\.aws/|\.ssh/' || true)

if [ -n "$SECRET_FILES" ]; then
    echo ""
    echo "⚠️  WARNING: Potential secret files detected:"
    echo "$SECRET_FILES"
    echo ""
    echo "Review carefully before committing!"
fi

# ============================================================================
# PROVIDE CLEAR INSTRUCTIONS
# ============================================================================

echo ""
echo "────────────────────────────────────────"
echo "REQUIRED ACTION: Commit changes before resuming"
echo "────────────────────────────────────────"
echo ""
echo "1. Review the changes above"
echo "2. If CORE_PROCESSES.md exists, follow its Git Commit Protocol"
echo "3. Commit manually:"
echo "   git add <files>"
echo "   git commit -m \"<message>\"  # Use protocol flags if required (-S -s)"
echo ""
echo "4. Then say 'resume' again to load session context"
echo ""
echo "Why this matters:"
echo "- Keeps your changes separate from new session work"
echo "- Maintains clean git checkpoints for recovery"
echo "- Follows Git Commit Protocol (explicit approval required)"
echo ""

# Exit with code 1 to BLOCK further execution
exit 1
