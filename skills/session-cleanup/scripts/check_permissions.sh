#!/bin/bash
# Check for required permissions in .claude/settings.local.json
# Exit 0=all-present (silent), 1=missing (output details), 2=error
#
# IMPORTANT: This script is duplicated across session-closure, session-resume, and session-cleanup
# Any changes must be synchronized manually between:
#   ~/.claude/skills/session-closure/scripts/check_permissions.sh
#   ~/.claude/skills/session-resume/scripts/check_permissions.sh
#   ~/.claude/skills/session-cleanup/scripts/check_permissions.sh
set -euo pipefail

# Accept working directory parameter (required)
WORK_DIR="${1:-.}"

# Change to working directory
cd "$WORK_DIR" || {
    echo "Error: Cannot access directory: $WORK_DIR"
    exit 2
}

# Look for settings file
SETTINGS_FILE=".claude/settings.local.json"

if [ ! -f "$SETTINGS_FILE" ]; then
    # No settings file - need to create one
    echo "MISSING_FILE"
    exit 1
fi

# Check if jq is available for proper JSON parsing
if command -v jq >/dev/null 2>&1; then
    USE_JQ=true
else
    USE_JQ=false
fi

# ============================================================================
# DEFINE REQUIRED PERMISSION PATTERNS
# ============================================================================

# Core session-skills patterns (REQUIRED - includes session-cleanup)
REQUIRED_PATTERNS=(
    'Skill(session-closure)'
    'Skill(session-resume)'
    'Skill(session-cleanup)'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/check_permissions.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_permissions.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_permissions.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/check_uncommitted_changes.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/archive_resume.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/validate_resume.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/commit_resume.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_uncommitted_changes.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/list_archives.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_staleness.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_uncommitted_changes.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/detect_complexity.sh" "${PROJECT_ROOT:-$PWD}")'
    'Bash("${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/find_local_cleanup.sh" "${PROJECT_ROOT:-$PWD}")'
    'Read(~/.claude/skills/session-closure/**)'
    'Read(~/.claude/skills/session-resume/**)'
    'Read(~/.claude/skills/session-cleanup/**)'
)

# Recommended but optional patterns (for better UX)
RECOMMENDED_PATTERNS=(
    'Bash(git log:*)'
    'Bash(git rev-parse:*)'
    'Bash(rsync:*)'
    'Bash(cat:*)'
    'Bash(readlink:*)'
    'Bash(xargs:*)'
    'Read(~/.claude/**)'
)

# Old patterns to detect and offer removal (deprecated)
OLD_PATTERNS=(
    'Bash(~/.claude/skills/session-closure/scripts/*)'
    'Bash(~/.claude/skills/session-resume/scripts/*)'
    'Bash(~/.claude/skills/session-cleanup/scripts/*)'
)

# ============================================================================
# CHECK FOR PATTERNS
# ============================================================================

MISSING_REQUIRED=()
MISSING_RECOMMENDED=()
FOUND_OLD=()

# Function to check if pattern exists in settings file
pattern_exists() {
    local pattern="$1"

    if [ "$USE_JQ" = true ]; then
        # Use jq for accurate JSON parsing
        jq -e --arg pattern "$pattern" '.permissions.allow | any(. == $pattern)' "$SETTINGS_FILE" >/dev/null 2>&1
    else
        # Fallback: grep-based check (less accurate but works)
        grep -qF "\"$pattern\"" "$SETTINGS_FILE" 2>/dev/null
    fi
}

# Check required patterns
for pattern in "${REQUIRED_PATTERNS[@]}"; do
    if ! pattern_exists "$pattern"; then
        MISSING_REQUIRED+=("$pattern")
    fi
done

# Check recommended patterns
for pattern in "${RECOMMENDED_PATTERNS[@]}"; do
    if ! pattern_exists "$pattern"; then
        MISSING_RECOMMENDED+=("$pattern")
    fi
done

# Check for old patterns
for pattern in "${OLD_PATTERNS[@]}"; do
    if pattern_exists "$pattern"; then
        FOUND_OLD+=("$pattern")
    fi
done

# ============================================================================
# DETERMINE EXIT STATUS
# ============================================================================

if [ ${#MISSING_REQUIRED[@]} -eq 0 ] && [ ${#FOUND_OLD[@]} -eq 0 ]; then
    # All required patterns present, no old patterns - perfect state
    exit 0
fi

# ============================================================================
# OUTPUT STRUCTURED INFORMATION FOR LLM TO PARSE
# ============================================================================

if [ ${#MISSING_REQUIRED[@]} -gt 0 ]; then
    echo "MISSING_REQUIRED"
    for pattern in "${MISSING_REQUIRED[@]}"; do
        echo "$pattern"
    done
    echo "END_MISSING_REQUIRED"
fi

if [ ${#MISSING_RECOMMENDED[@]} -gt 0 ]; then
    echo "MISSING_RECOMMENDED"
    for pattern in "${MISSING_RECOMMENDED[@]}"; do
        echo "$pattern"
    done
    echo "END_MISSING_RECOMMENDED"
fi

if [ ${#FOUND_OLD[@]} -gt 0 ]; then
    echo "FOUND_OLD"
    for pattern in "${FOUND_OLD[@]}"; do
        echo "$pattern"
    done
    echo "END_FOUND_OLD"
fi

# Exit with code 1 to indicate configuration needed
exit 1
