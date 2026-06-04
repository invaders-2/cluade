# Permission Setup for Session Skills

**Problem**: Claude Code's interactive permission approval doesn't persist across sessions, causing repeated permission prompts for the same commands.

**Solution**: Session skills automatically detect missing permissions and offer one-time setup. For manual configuration, add permission patterns to project `.claude/settings.local.json`.

## Automatic Permission Setup

Session skills automatically check for required permissions on first use and offer to configure them for you.

**How it works**:
1. When you say "resume" or "close session", the skill runs a permission check
2. If permissions are missing or outdated, you'll see a one-time setup offer
3. After approval, permissions are automatically added to `.claude/settings.local.json`
4. Future sessions run smoothly with no permission prompts

**What you'll see**:
```markdown
🔧 Session skills need one-time permission setup

Missing required permissions (11 patterns):
- Skill(session-closure)
- Skill(session-resume)
- [additional patterns...]

I can configure these automatically using an inline script.

May I update .claude/settings.local.json to add these permissions?
```

**After setup**: The permission check runs on every session but exits instantly when configured (no user-visible output).

---

## Manual Permission Setup

## Required Permissions

**CRITICAL**: Claude Code's permission system requires EXACT pattern matching, including variable expansions and arguments.

Add these entries to your project's `.claude/settings.local.json` file:

```json
{
  "permissions": {
    "allow": [
      "Skill(session-closure)",
      "Skill(session-resume)",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/check_permissions.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_permissions.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/check_uncommitted_changes.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/archive_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/validate_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/commit_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_uncommitted_changes.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/list_archives.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-resume}/scripts/check_staleness.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Read(~/.claude/skills/session-closure/**)",
      "Read(~/.claude/skills/session-resume/**)"
    ],
    "deny": [],
    "ask": []
  }
}
```

### Why These Exact Patterns?

**Wildcard patterns DO NOT WORK**.

1. **Variable expansion required**: Skills use `${SKILL_BASE:-$HOME/.claude/skills/...}` syntax
2. **Arguments required**: Pattern must include `"${PROJECT_ROOT:-$PWD}"` argument
3. **Exact quotes required**: Double quotes with backslash escaping in JSON
4. **Each script explicit**: Cannot use `scripts/*` wildcard - must list each script

### What Didn't Work

❌ `Bash(~/.claude/skills/session-closure/scripts/*)` - Wildcard doesn't match variable expansion
❌ `Bash(~/.claude/skills/session-closure/scripts/validate_resume.sh:*)` - Missing variable syntax
❌ `Bash($HOME/.claude/skills/session-closure/scripts/*)` - Wrong variable format

✅ `Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/validate_resume.sh\" \"${PROJECT_ROOT:-$PWD}\")` - **WORKS**

---

## Quick Setup Script

Run this one-time script to add permissions to your project:

```bash
#!/bin/bash
# add-session-skills-permissions.sh
# Adds session-skills permissions to .claude/settings.local.json

PROJECT_DIR="${1:-.}"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"

# Create .claude directory if it doesn't exist
mkdir -p "$PROJECT_DIR/.claude"

# Check if settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Creating new settings.local.json..."
    cat > "$SETTINGS_FILE" <<'EOF'
{
  "permissions": {
    "allow": [
      "Skill(session-closure)",
      "Skill(session-resume)",
      "Bash(~/.claude/skills/session-closure/scripts/*)",
      "Bash(~/.claude/skills/session-resume/scripts/*)",
      "Read(//Users/ChristopherA/.claude/skills/session-closure/**)",
      "Read(//Users/ChristopherA/.claude/skills/session-resume/**)"
    ],
    "deny": [],
    "ask": []
  }
}
EOF
    echo "✅ Created $SETTINGS_FILE with session-skills permissions"
else
    echo "⚠️  $SETTINGS_FILE already exists"
    echo "Add these entries to the 'allow' array:"
    echo ""
    echo '  "Skill(session-closure)",'
    echo '  "Skill(session-resume)",'
    echo '  "Bash(~/.claude/skills/session-closure/scripts/*)",'
    echo '  "Bash(~/.claude/skills/session-resume/scripts/*)",'
    echo '  "Read(//Users/ChristopherA/.claude/skills/session-closure/**)",'
    echo '  "Read(//Users/ChristopherA/.claude/skills/session-resume/**)"'
fi
```

**Usage**:
```bash
# In your project directory
chmod +x add-session-skills-permissions.sh
./add-session-skills-permissions.sh
```

**Or** for existing files, merge permissions manually using jq:
```bash
# TODO: Create jq merge command
```

---

## Verification

After adding permissions, test that prompts no longer appear:

1. **Resume test**: Say "resume" - should not prompt for session-resume scripts
2. **Closure test**: Say "close context" - should not prompt for session-closure scripts

If you still get prompted:
- Check that the exact pattern matches what Claude is requesting
- Look at the permission request and compare to your settings.local.json
- The system may use different variable expansion than expected

---

## Minimal Permission Set

If you want the absolute minimum (no wildcards), these are the scripts that actually get called:

### session-closure
```json
"Bash(~/.claude/skills/session-closure/scripts/check_uncommitted_changes.sh:*)",
"Bash(~/.claude/skills/session-closure/scripts/archive_resume.sh:*)",
"Bash(~/.claude/skills/session-closure/scripts/validate_resume.sh:*)",
"Bash(~/.claude/skills/session-closure/scripts/commit_resume.sh:*)"
```

### session-resume
```json
"Bash(~/.claude/skills/session-resume/scripts/check_uncommitted_changes.sh:*)",
"Bash(~/.claude/skills/session-resume/scripts/list_archives.sh:*)",
"Bash(~/.claude/skills/session-resume/scripts/check_staleness.sh:*)"
```

**However**: Wildcard patterns are recommended to avoid having to update permissions when new scripts are added.

---

## Troubleshooting

### Still Getting Permission Prompts?

The actual command being executed may use `${SKILL_BASE:-...}` expansion:
```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/validate_resume.sh" "$PWD"
```

This may not match the permission pattern. If wildcards don't work, you may need to add the expanded form:
```json
"Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/*\")"
```

### Permission File Getting Polluted?

If interactive approval keeps adding entries:
1. Clean up duplicates using the patterns in this doc
2. Consider adding `.claude/settings.local.json` to `.gitignore` if it changes every session
3. Commit a "clean" version as reference, then gitignore to prevent noise

---

*Session-closure skill v1.3.9 - Permission configuration guide (November 2025)*
