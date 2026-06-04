#!/bin/bash
# Check resume age, output: fresh|recent|stale|very_stale
set -e

# Parse arguments
PROJECT_ROOT="${1:-.}"

# Change to project root directory
cd "$PROJECT_ROOT" || {
    echo "error" >&2
    exit 1
}

# Verify we're in a project root (should have CLAUDE.md)
if [ ! -f "CLAUDE.md" ]; then
    echo "error" >&2
    exit 1
fi

# Find resume file (prefer .claude/ location)
if [ -f ".claude/CLAUDE_RESUME.md" ]; then
    RESUME=".claude/CLAUDE_RESUME.md"
elif [ -f "CLAUDE_RESUME.md" ]; then
    RESUME="CLAUDE_RESUME.md"
else
    echo "error"
    exit 1
fi

# Extract session date from resume
# Looks for "**Last Session**: October 27, 2025" or "Last Session: October 27, 2025"
SESSION_DATE_LINE=$(grep -i "Last Session" "$RESUME" | head -1 || echo "")

if [ -z "$SESSION_DATE_LINE" ]; then
    echo "error"
    exit 1
fi

# Extract date portion (handles both **Last Session**: and Last Session:)
SESSION_DATE=$(echo "$SESSION_DATE_LINE" | sed 's/.*Last Session[*:]*: *//' | sed 's/ (.*//' | cut -d' ' -f1-3)

if [ -z "$SESSION_DATE" ]; then
    echo "error"
    exit 1
fi

# Calculate age in days (cross-platform date command)
TODAY=$(date +%s)

# Detect OS and use appropriate date command
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS (BSD date)
    SESSION_EPOCH=$(date -j -f "%B %d, %Y" "$SESSION_DATE" +%s 2>/dev/null || echo "0")

    if [ "$SESSION_EPOCH" -eq 0 ]; then
        # Try alternate format: Month DD YYYY (without comma)
        SESSION_EPOCH=$(date -j -f "%B %d %Y" "$SESSION_DATE" +%s 2>/dev/null || echo "0")
    fi
else
    # Linux/GNU date
    SESSION_EPOCH=$(date -d "$SESSION_DATE" +%s 2>/dev/null || echo "0")
fi

if [ "$SESSION_EPOCH" -eq 0 ]; then
    echo "error"
    exit 1
fi

AGE_DAYS=$(( (TODAY - SESSION_EPOCH) / 86400 ))

# Determine staleness level
if [ "$AGE_DAYS" -lt 1 ]; then
    echo "fresh"
elif [ "$AGE_DAYS" -lt 7 ]; then
    echo "recent"
elif [ "$AGE_DAYS" -lt 30 ]; then
    echo "stale"
else
    echo "very_stale"
fi

exit 0
