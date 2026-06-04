#!/bin/bash
# check_stale_planning.sh - Detect stale planning documents
# Part of session-cleanup skill
#
# Checks claude/planning/ for documents that haven't been updated in >30 days.
# Exits silently (code 0) if no issues found.
# Exits with code 1 and details if stale docs found.

set -euo pipefail

PROJECT_DIR="${1:-$PWD}"
PLANNING_DIR="$PROJECT_DIR/claude/planning"
STALE_THRESHOLD_DAYS=30

# Check if planning directory exists
if [[ ! -d "$PLANNING_DIR" ]]; then
    # No planning directory - that's fine
    exit 0
fi

# Find markdown files in planning directory
PLANNING_FILES=$(find "$PLANNING_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)

if [[ -z "$PLANNING_FILES" ]]; then
    # No planning files - that's fine
    exit 0
fi

# Check each file for staleness
STALE_FILES=()
CURRENT_FILES=()
NOW=$(date +%s)
THRESHOLD=$((STALE_THRESHOLD_DAYS * 24 * 60 * 60))

while IFS= read -r file; do
    if [[ -n "$file" ]]; then
        # Get file modification time
        if [[ "$(uname)" == "Darwin" ]]; then
            MTIME=$(stat -f %m "$file")
        else
            MTIME=$(stat -c %Y "$file")
        fi

        AGE=$((NOW - MTIME))
        AGE_DAYS=$((AGE / 86400))

        FILENAME=$(basename "$file")

        if [[ $AGE -gt $THRESHOLD ]]; then
            STALE_FILES+=("$FILENAME ($AGE_DAYS days)")
        else
            CURRENT_FILES+=("$FILENAME ($AGE_DAYS days)")
        fi
    fi
done <<< "$PLANNING_FILES"

# Report results
if [[ ${#STALE_FILES[@]} -eq 0 ]]; then
    # No stale files - report current files if any (informational)
    if [[ ${#CURRENT_FILES[@]} -gt 0 ]]; then
        echo "PLANNING_DOCS_FOUND"
        echo "Active planning documents (${#CURRENT_FILES[@]}):"
        for f in "${CURRENT_FILES[@]}"; do
            echo "  - $f"
        done
    fi
    exit 0
else
    # Stale files found - warn
    echo "STALE_PLANNING_DOCS"
    echo ""
    echo "=== Stale Planning Documents Detected ==="
    echo ""
    echo "The following planning documents haven't been updated in >$STALE_THRESHOLD_DAYS days:"
    echo ""
    for f in "${STALE_FILES[@]}"; do
        echo "  - $f"
    done
    echo ""
    echo "Options:"
    echo "  1. COMPLETE: Integrate findings into permanent docs, then delete"
    echo "  2. UPDATE: If work is ongoing, touch the file to reset the timer"
    echo "  3. ABANDON: If work is obsolete, delete with git commit noting abandonment"
    echo ""
    echo "See CORE_PROCESSES.md § Planning Document Lifecycle for completion criteria."
    echo ""

    if [[ ${#CURRENT_FILES[@]} -gt 0 ]]; then
        echo "Active planning documents (${#CURRENT_FILES[@]}):"
        for f in "${CURRENT_FILES[@]}"; do
            echo "  - $f"
        done
    fi

    exit 1
fi
