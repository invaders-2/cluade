# session-cleanup - User Guide

Adaptive session audit before closure with structured ultrathink analysis.

## Installation

### Plugin (Recommended)
```bash
/plugin marketplace add ChristopherA/claude_code_tools
/plugin install session-skills@session-skills
```

### Manual
```bash
git clone https://github.com/ChristopherA/claude_code_tools.git
cp -r claude_code_tools/skills/session-cleanup ~/.claude/skills/
```

## Required Permissions

Permissions are configured automatically on first use! The skill detects missing permissions and offers to set them up for you.

**First-time setup**:
1. Say "session cleanup" or "session review"
2. If permissions are missing, you'll see a one-time setup prompt
3. Approve the automatic configuration
4. Future sessions run smoothly with no prompts

**Or manually** add to `.claude/settings.local.json`:
```json
{
  "permissions": {
    "allow": [
      "Skill(session-cleanup)",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_permissions.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_uncommitted_changes.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/detect_complexity.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/find_local_cleanup.sh\" \"${PROJECT_ROOT:-$PWD}\")",
      "Read(~/.claude/skills/session-cleanup/**)"
    ]
  }
}
```

**Why exact patterns?**
- Interactive permission approval doesn't persist across sessions
- Wildcard patterns (`scripts/*`) do not work - must use exact patterns
- Must use exact command format including `${SKILL_BASE:-...}` and `${PROJECT_ROOT:-...}`

## Usage

Say any of:
- "session cleanup"
- "session review"
- "audit session"
- "pre-closure check"
- "cleanup"

The skill will:
1. Check permissions (one-time setup if needed)
2. Check for uncommitted changes (commit first if found)
3. Detect session complexity (light/standard/thorough)
4. Run structured ultrathink with category hints
5. Validate coverage
6. Load project-specific checks (if local file exists)
7. Present findings with handoff to session-closure

## Workflow Integration

```
session-resume → work → session-cleanup → session-closure
     ↑                        ↓
     └────── next session ────┘
```

**When to use session-cleanup**:
- After significant work (multiple commits, many files changed)
- Before ending long sessions
- When you want systematic review before closure

**When to skip session-cleanup**:
- Quick sessions with minimal changes
- Trivial sessions (use session-closure directly)
- Mid-session file reviews

## Session Depth

The skill adapts to session complexity:

| Depth | Commits | Files | Analysis |
|-------|---------|-------|----------|
| light | 0-1 | <5 | Brief category check |
| standard | 2-5 | 5-15 | Full category analysis |
| thorough | 6+ | 15+ | Deep analysis, verify cross-refs |

## Local Customization

Create project-specific checks in `claude/processes/local-session-cleanup.md`:

```markdown
# Project-Specific Cleanup Checks

## Required Checks
- [ ] Check 1 specific to this project
- [ ] Check 2 specific to this project
```

See [LOCAL_TEMPLATE.md](LOCAL_TEMPLATE.md) for the full template.

## Troubleshooting

### Skill Not Recognized

**Symptoms**: "session cleanup" doesn't invoke the skill

**Causes**:
- Skill not installed
- Claude Code needs restart after installation

**Fix**:
1. Verify installation: `ls ~/.claude/skills/session-cleanup/SKILL.md`
2. Restart Claude Code

### Permission Prompts Repeated

**Symptoms**: Asked for permission every time

**Causes**:
- Permissions not in settings.local.json
- Using wrong pattern format

**Fix**: Accept the one-time setup when offered, or manually add permissions per above.

### Uncommitted Changes Block

**Symptoms**: Skill blocks with "uncommitted changes detected"

**Cause**: This is expected behavior - ensures clean git state before audit

**Fix**: Commit your changes first, then re-run "session cleanup"

### Local File Not Detected

**Symptoms**: Project-specific checks not running

**Cause**: File not in expected location

**Fix**: Ensure file is at `claude/processes/local-session-cleanup.md`

## Getting Help

1. Check error messages in terminal
2. Review SKILL.md for protocol
3. Test scripts manually
4. Report issues: https://github.com/ChristopherA/claude_code_tools/issues

---

*User guide for session-cleanup*
