# session-closure - User Guide

End sessions with structured resume creation for seamless continuity.

## Installation

### Plugin (Recommended)
```bash
/plugin marketplace add ChristopherA/claude_code_tools
/plugin install session-skills@session-skills
```

### Manual
```bash
git clone https://github.com/ChristopherA/claude_code_tools.git
cp -r claude_code_tools/skills/session-closure ~/.claude/skills/
```

## Required Permissions

Permissions are configured automatically on first use! The skill detects missing permissions and offers to set them up for you.

**First-time setup**:
1. Say "resume" or "close session"
2. If permissions are missing, you'll see a one-time setup prompt
3. Approve the automatic configuration
4. Future sessions run smoothly with no prompts

**Manual setup** (if needed):

Run the one-time script:
```bash
~/.claude/skills/session-closure/scripts/add-permissions.sh
```

**Or manually** add to `.claude/settings.local.json`:
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

**Why?**
- Interactive permission approval doesn't persist across sessions
- Wildcard patterns (`scripts/*`) do not work - must use exact patterns
- Must use exact command format including `${SKILL_BASE:-...}` and `${PROJECT_ROOT:-...}`

**See**: [PERMISSIONS.md](PERMISSIONS.md) for complete details and troubleshooting.

## SessionEnd Hook (Optional)

Auto-invoke on /exit:

```json
{
  "hooks": {
    "SessionEnd": [{
      "type": "skill",
      "skill": "session-closure"
    }]
  }
}
```

## Usage

Say any of:
- "close context"
- "end session"
- "prepare to stop"
- "save state"
- "create resume"

The skill will:
1. Check for uncommitted changes (commit them first if found)
2. Archive previous resume (if exists and not git-tracked)
3. Assess current session state
4. Create CLAUDE_RESUME.md with session details
5. Validate resume structure
6. Commit resume to git (if repository)

## Resume Format

See [RESUME_FORMAT_v1.2.md](RESUME_FORMAT_v1.2.md) for complete specification.

## Troubleshooting

### Resume Not Created

**Symptoms**: CLAUDE_RESUME.md doesn't exist after closure

**Causes**:
- Skill not invoked (say "close context" explicitly)
- Error during creation (check terminal output)
- Permission issues (check file permissions)

**Fix**:
1. Verify skill activated: Look for "session-closure is running"
2. Check for errors in output
3. Try manual creation: Follow SKILL.md steps manually

### Resume Not Committed

**Symptoms**: Resume created but `git status` shows uncommitted

**Causes**:
- Not a git repository
- commit_resume.sh failed
- Permission not granted for script

**Fix**:
1. Check `git rev-parse --git-dir` (should succeed)
2. Run manually: `~/.claude/skills/session-closure/scripts/commit_resume.sh "$PWD"`
3. Check permissions in `.claude/settings.local.json`

### Secret Files Warning

**Symptoms**: "Secret files detected" blocks closure

**Cause**: .env, credentials, keys in uncommitted changes

**Fix**:
1. Review files listed in warning
2. Add to .gitignore if truly secret
3. Commit if safe to track
4. Remove from working directory if temporary

### Archive Not Created

**Symptoms**: Previous resume not archived

**Causes**:
- No previous resume existed
- Archive script failed
- Directory permissions

**Fix**: Check `claude/archive/sessions/` exists and is writable

### Phantom Tasks

**Symptoms**: Tasks in resume that don't exist in todo list

**Cause**: Todo list cleared but resume captures old state

**Fix**: Accept as historical record, or edit resume manually before closure

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

**Archive location**: archives/CLAUDE_RESUME/ (default)
**Git tracking**: Track CLAUDE_RESUME.md for backup

## Getting Help

1. Check error messages in terminal
2. Review SKILL.md for protocol
3. Test scripts manually
4. Report issues: https://github.com/ChristopherA/claude_code_tools/issues

---

*User guide for session-closure*
