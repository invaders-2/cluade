#!/bin/bash
# List archived CLAUDE_RESUME.md files, newest first
# Checks both .claude/archives/ and archives/ locations
set -e

# Parse PROJECT_ROOT argument (first positional arg if not starting with --)
PROJECT_ROOT="."
if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
    PROJECT_ROOT="$1"
    shift
fi

# Change to project root directory
cd "$PROJECT_ROOT" || {
    echo "Error: Cannot access project root: $PROJECT_ROOT" >&2
    exit 1
}

LIMIT=10
FORMAT="short"

# Parse remaining arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Find all archive files from both locations
ARCHIVE_FILES=""
if [ -d ".claude/archives/CLAUDE_RESUME" ]; then
    ARCHIVE_FILES=$(find ".claude/archives/CLAUDE_RESUME" -name "*.md" -type f 2>/dev/null || true)
fi
if [ -d "archives/CLAUDE_RESUME" ]; then
    ROOT_FILES=$(find "archives/CLAUDE_RESUME" -name "*.md" -type f 2>/dev/null || true)
    if [ -n "$ROOT_FILES" ]; then
        if [ -n "$ARCHIVE_FILES" ]; then
            ARCHIVE_FILES="$ARCHIVE_FILES"$'\n'"$ROOT_FILES"
        else
            ARCHIVE_FILES="$ROOT_FILES"
        fi
    fi
fi

# Check if any archives found
if [ -z "$ARCHIVE_FILES" ]; then
    echo "No archives found"
    exit 0
fi

# Count archives
ARCHIVE_COUNT=$(echo "$ARCHIVE_FILES" | grep -c "\.md$" || echo "0")

if [ "$ARCHIVE_COUNT" -eq 0 ]; then
    echo "No archives found"
    exit 0
fi

# List archives (sorted by modification time, newest first)
if [ "$FORMAT" = "detailed" ]; then
    echo "Found $ARCHIVE_COUNT archived session(s):"
    echo ""
    # Sort by modification time and limit
    echo "$ARCHIVE_FILES" | xargs ls -lt 2>/dev/null | head -n "$LIMIT" | while read -r line; do
        # Extract filename from ls output
        filename=$(echo "$line" | awk '{print $NF}')
        base=$(basename "$filename" .md)
        size=$(echo "$line" | awk '{print $5}')

        # Parse timestamp (YYYY-MM-DD-HHMM format)
        year=$(echo "$base" | cut -d'-' -f1)
        month=$(echo "$base" | cut -d'-' -f2)
        day=$(echo "$base" | cut -d'-' -f3)
        time=$(echo "$base" | cut -d'-' -f4)
        hour="${time:0:2}"
        minute="${time:2:2}"

        echo "- $year-$month-$day $hour:$minute ($size bytes)"
    done
else
    # Short format: just timestamps, sorted newest first
    echo "$ARCHIVE_FILES" | xargs ls -t 2>/dev/null | head -n "$LIMIT" | while read -r file; do
        basename "$file" .md
    done
fi

exit 0
