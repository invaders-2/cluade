# session-resume - User Guide

Load previous session context from CLAUDE_RESUME.md for seamless continuity.

## Installation

### Plugin (Recommended)
```bash
/plugin marketplace add ChristopherA/claude_code_tools
/plugin install session-skills@session-skills
```

### Manual
```bash
git clone https://github.com/ChristopherA/claude_code_tools.git
cp -r claude_code_tools/skills/session-resume ~/.claude/skills/
```

## Required Permissions

Permissions are configured automatically on first use! The skill detects missing permissions and offers to set them up for you.

**First-time setup**:
1. Say "resume"
2. If permissions are missing, you'll see a one-time setup prompt
3. Approve the automatic configuration
4. Future sessions run smoothly with no prompts

**Manual setup** (if needed):

Add to `.claude/settings.local.json`:
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
    ]
  }
}
```

**See**: [session-closure/references/PERMISSIONS.md](../../session-closure/references/PERMISSIONS.md) for complete details.

## SessionStart Hook (Optional)

Notifies when resume available:

```json
{
  "hooks": {
    "SessionStart": [{
      "type": "command",
      "command": "date +'📅 Today is %A, %B %d, %Y' && ([ -f CLAUDE_RESUME.md ] && echo '\\n📋 Previous session available. Say \"resume\" to continue.' || true) && (git rev-parse --git-dir >/dev/null 2>&1 && [ -n \"$(git status --porcelain=v2)\" ] && echo '\\n⚠️  Uncommitted changes from previous session. Review with \"git status\".' || true)"
    }]
  }
}
```

## Usage

Say any of:
- "resume"
- "load resume"
- "continue from last session"
- "what was I working on"
- "show previous session"

The skill will:
1. Check for uncommitted changes (must commit them first if found)
2. Look for CLAUDE_RESUME.md in current directory
3. Load and analyze resume content
4. Present summary with key information
5. Highlight next session focus

## Resume Format

See [RESUME_FORMAT_v1.2.md](RESUME_FORMAT_v1.2.md) for complete specification.

## Examples

### Standard Resume
```
User: resume

📋 Resuming from [Date] session:

**Last activity**: Completed auth module with JWT validation

**Next focus**: Implement rate limiting with express-rate-limit package

**Pending tasks**: 3 tasks remaining
- Add rate limiting middleware
- Write API documentation
- Security review

Ready to continue where you left off!
```

### No Resume Found
```
User: resume

No CLAUDE_RESUME.md found.
Checked archives: None found.
Recommendation: Start fresh session, use "close context" to create resume.
```

### Archives Available
```
User: resume

No current resume, but found archives:
1. 2025-11-04-1430.md (Nov 4, 2:30 PM)
2. 2025-11-03-1615.md (Nov 3, 4:15 PM)

Options: Load most recent / Select specific / Start fresh
```

### Resume with External Sources
```
User: resume

Sync Status:
- Google Docs: synced 2025-11-04 (current)
- HackMD: synced 2025-11-03 (⚠️ 1 day behind)

Alert: Architecture doc may need sync before starting work
```

### Uncommitted Changes
```
User: resume

❌ Cannot resume: Uncommitted changes detected

Files with changes:
  M CLAUDE_RESUME.md
  M src/auth.js

Action Required: Commit changes before resuming
Why: Keeps your changes separate from new session work
```

## Workflow Integration

### Complete Session Cycle
```
End of day:
  User: close context
  → Creates CLAUDE_RESUME.md
  → Archives previous resume

Next morning:
  User: resume
  → Loads CLAUDE_RESUME.md
  → Restores context
  → Ready to continue
```

### Team Collaboration
```
Developer A (end of day):
  close context → commit CLAUDE_RESUME.md → push

Developer B (next morning):
  pull → resume → continues team's work
```

## Command Line Usage

### List Archives
```bash
~/.claude/skills/session-resume/scripts/list_archives.sh --limit 5
# Output: Recent archives with timestamps
```

### Check Uncommitted Changes
```bash
~/.claude/skills/session-resume/scripts/check_uncommitted_changes.sh "$PWD"
# Exit: 0=clean, 1=changes-detected, 2=error
```

## Project Pre-Check Hook

Projects can run custom preparation before the uncommitted changes check by creating `.claude/hooks/session-pre-check.sh`.

**Use cases**:
- Stash files that shouldn't be committed (`.pages`, `.numbers`, temp files)
- Run project-specific preparation scripts
- Check project-specific preconditions

**Example** (stash Apple Pages autosave noise):

```bash
#!/bin/bash
# .claude/hooks/session-pre-check.sh
PROJECT_ROOT="${1:-$PWD}"
cd "$PROJECT_ROOT" || exit 1

PAGES_FILES=$(git status --porcelain | grep '\.pages$' | awk '{print $2}')
if [ -n "$PAGES_FILES" ]; then
  echo "📦 Stashing Apple Pages files..."
  git stash push -m "session-pre-check: .pages files" -- $PAGES_FILES
fi
exit 0
```

**Hook contract**:
- Receives project root as first argument
- Exit 0 = proceed, non-zero = abort with hook output as message
- If hook doesn't exist, step is silently skipped

## Customization

**Resume location**: CLAUDE_RESUME.md in project root
**Archive location**: archives/CLAUDE_RESUME/ (optional)

---

*User guide for session-resume*
