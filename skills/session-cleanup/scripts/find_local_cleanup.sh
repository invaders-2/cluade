#!/bin/bash
# find_local_cleanup.sh - Check for project-specific cleanup checklist
# Usage: find_local_cleanup.sh [PROJECT_ROOT]

PROJECT_ROOT="${1:-$PWD}"

# Check both locations (prefer .claude/ location)
if [ -f "$PROJECT_ROOT/.claude/processes/local-session-cleanup.md" ]; then
    echo "FOUND: $PROJECT_ROOT/.claude/processes/local-session-cleanup.md"
elif [ -f "$PROJECT_ROOT/claude/processes/local-session-cleanup.md" ]; then
    echo "FOUND: $PROJECT_ROOT/claude/processes/local-session-cleanup.md"
else
    echo "INFO: No project-specific cleanup checklist"
    echo "INFO: Looked in: .claude/processes/ and claude/processes/"
fi

exit 0
