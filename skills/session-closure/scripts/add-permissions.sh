#!/bin/bash
# add-permissions.sh - Add session-skills permissions to .claude/settings.local.json
# Part of session-closure skill v1.3.9
#
# Usage:
#   ./add-permissions.sh [project-directory]
#
#   If project-directory not specified, uses current directory.

set -e

PROJECT_DIR="${1:-.}"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"

# Create .claude directory if it doesn't exist
mkdir -p "$PROJECT_DIR/.claude"

# Check if settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "📝 Creating new settings.local.json with session-skills permissions..."
    cat > "$SETTINGS_FILE" <<'EOF'
{
  "permissions": {
    "allow": [
      "Skill(session-closure)",
      "Skill(session-resume)",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/check_uncommitted_changes.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/archive_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/validate_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/commit_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_uncommitted_changes.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/list_archives.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_staleness.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Read(//Users/ChristopherA/.claude/skills/session-closure/**)",
      "Read(//Users/ChristopherA/.claude/skills/session-resume/**)"
    ],
    "deny": [],
    "ask": []
  }
}
EOF
    echo "✅ Created $SETTINGS_FILE with session-skills permissions"
    echo ""
    echo "Permissions added:"
    echo "  - Skill(session-closure)"
    echo "  - Skill(session-resume)"
    echo "  - Bash scripts for both skills"
    echo "  - Read access to skill directories"
else
    echo "⚠️  $SETTINGS_FILE already exists"
    echo ""
    echo "Please manually add these entries to the 'allow' array:"
    echo ""
    echo '  "Skill(session-closure)",'
    echo '  "Skill(session-resume)",'
    echo '  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/check_uncommitted_changes.sh\" \"${PROJECT_ROOT:-$PWD}\")",'
    echo '  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/archive_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")",'
    echo '  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/validate_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")",'
    echo '  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/commit_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")",'
    echo '  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_uncommitted_changes.sh\" \"${PROJECT_ROOT:-$PWD}\")",'
    echo '  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/list_archives.sh\" \"${PROJECT_ROOT:-$PWD}\")",'
    echo '  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_staleness.sh\" \"${PROJECT_ROOT:-$PWD}\")",'
    echo '  "Read(//Users/ChristopherA/.claude/skills/session-closure/**)",'
    echo '  "Read(//Users/ChristopherA/.claude/skills/session-resume/**)"'
    echo ""
    echo "⚠️  CRITICAL: Wildcard patterns DO NOT work - must use exact patterns with variable syntax"
    echo "See references/PERMISSIONS.md for details"
fi

echo ""
echo "📖 See references/PERMISSIONS.md for complete documentation"
