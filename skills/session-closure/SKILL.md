---
name: session-closure
version: 0.5.1
description: >
  Execute session closure protocol with resume creation. Automatically
  archives previous resumes unless tracked in git. Uses executable
  scripts for consistent archiving, validation, and commits. Creates
  resumes with Project Status (inter-project communication), Sync
  Status (authoritative source tracking), and Pending Outbound Handoffs
  (cross-project tracking). Checks for ALL uncommitted changes before
  closure and commits them before creating new resume.

  WHEN: User says "close context", "end session", "prepare to stop",
  "prepare to close session", "save state", "create resume", OR when
  I detect context usage approaching 170k tokens (proactive preservation),
  OR when SessionEnd hook invokes (automatic on /exit or /compact).

  WHEN NOT: Mid-session saves, "save draft" requests, temporary
  checkpoints, brief pauses, or "save file" commands. Don't trigger
  on file operations.
---

# Session Closure Protocol

## Contents

1. [Closure Steps](#closure-steps)
   - [Step 0: Check Permissions](#step-0-check-permissions-one-time-setup)
   - [Step 0.1: Project Pre-Check Hook](#step-01-project-pre-check-hook-optional)
   - [Step 0.5: Handle ALL Uncommitted Changes](#step-05-handle-all-uncommitted-changes)
   - [Step 1: Archive Existing Resume](#step-1-archive-existing-resume)
   - [Step 2: Assess Session State](#step-2-assess-session-state)
   - [Step 3: Create CLAUDE_RESUME.md](#step-3-create-claude_resumemd)
   - [Step 4: Verify Resume Creation](#step-4-verify-resume-creation)
   - [Step 5: Commit New Resume](#step-5-commit-new-resume)
   - [Step 6: Confirmation](#step-6-confirmation)
2. [Additional Documentation](#additional-documentation)

---

## Closure Steps

### Step 0: Check Permissions (ONE-TIME SETUP)

**Purpose**: Verify session-skills permissions are configured to prevent repeated permission prompts.

**Why this matters**:
- Claude Code's interactive permission approval doesn't persist across sessions
- Without pre-approved permissions, users get repeated prompts for every skill script
- One-time setup enables smooth session-resume and session-closure operation

**Implementation**:

Run the permission check script:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/check_permissions.sh" "${PROJECT_ROOT:-$PWD}"
```

**Script behavior**:
- **All permissions present**: Exits silently (code 0) → proceed to Step 0.5
- **Permissions missing/outdated**: Exits with details (code 1) → offer configuration
- **No settings file**: Exits with MISSING_FILE marker → offer to create

**When configuration needed**:

The script outputs structured information:
1. **MISSING_REQUIRED**: Critical permissions needed for skills to function
2. **MISSING_RECOMMENDED**: Optional permissions for better UX (git, rsync, etc.)
3. **FOUND_OLD**: Deprecated patterns that should be removed (e.g., `session-*` wildcards)

**Present configuration offer to user**:

```markdown
🔧 Session skills need one-time permission setup

[If missing file:]
No .claude/settings.local.json found. I'll create one with required permissions.

[If missing patterns:]
Missing required permissions ([count] patterns):
- Skill(session-closure)
- Skill(session-resume)
- [List other missing REQUIRED patterns]

[If old patterns found:]
Found deprecated patterns ([count] to remove):
- Bash(~/.claude/skills/session-closure/scripts/*)
- [List other FOUND_OLD patterns]

I can configure these automatically using this inline script:
[Show inline bash script that will be executed]

May I update .claude/settings.local.json to add these permissions?
```

**After user approval, execute inline configuration script**:

```bash
#!/bin/bash
# Inline permission configuration script
# Adds/updates .claude/settings.local.json with session-skills permissions

PROJECT_DIR="${PROJECT_ROOT:-$PWD}"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"

# Create .claude directory if needed
mkdir -p "$PROJECT_DIR/.claude"

# Required permission patterns
REQUIRED_PATTERNS='[
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
]'

# Old patterns to remove
OLD_PATTERNS=(
  'Bash(~/.claude/skills/session-closure/scripts/*)'
  'Bash(~/.claude/skills/session-resume/scripts/*)'
)

if [ ! -f "$SETTINGS_FILE" ]; then
  # Create new settings file
  cat > "$SETTINGS_FILE" <<EOF
{
  "permissions": {
    "allow": $REQUIRED_PATTERNS,
    "deny": [],
    "ask": []
  }
}
EOF
  echo "✅ Created $SETTINGS_FILE with session-skills permissions"
else
  # Merge with existing file using jq
  if command -v jq >/dev/null 2>&1; then
    # Parse required patterns as JSON array
    REQUIRED_JSON=$(echo "$REQUIRED_PATTERNS" | jq -c '.')

    # Read existing permissions, add new ones, remove old ones, deduplicate
    jq --argjson new "$REQUIRED_JSON" \
       '.permissions.allow = ([.permissions.allow[], $new[]] | unique) |
        .permissions.allow -= ["Bash(~/.claude/skills/session-closure/scripts/*)", "Bash(~/.claude/skills/session-resume/scripts/*)"]' \
       "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

    echo "✅ Updated $SETTINGS_FILE with session-skills permissions"
  else
    echo "⚠️  jq not found - manual merge required"
    echo "Add these patterns to permissions.allow array:"
    echo "$REQUIRED_PATTERNS"
  fi
fi
```

**After configuration**:
- Proceed to Step 0.5 (uncommitted changes check)
- Future sessions will skip this step (permissions already configured)

**Error handling**:
- Script not found: Display error, proceed with warning (user will get permission prompts)
- Script fails: Display error, proceed with warning
- User declines: Proceed anyway (user will approve permissions interactively)

---

### Step 0.1: Project Pre-Check Hook (OPTIONAL)

**Purpose**: Allow projects to run custom preparation before the uncommitted changes check.

**Why this matters**:
- Projects may have files that should be stashed, not committed (e.g., Apple Pages autosave)
- Project-specific protocols exist in LOCAL_CONTEXT.md but skills don't read them
- This hook enables mechanical enforcement of project-specific behavior
- Backward compatible: skipped if no hook exists

**Implementation**:

Check for and run project hook if it exists:

```bash
HOOK_PATH="${PROJECT_ROOT:-$PWD}/.claude/hooks/session-pre-check.sh"
if [ -x "$HOOK_PATH" ]; then
  "$HOOK_PATH" "${PROJECT_ROOT:-$PWD}"
fi
```

**Hook location**: `.claude/hooks/session-pre-check.sh` (project-level)

**Hook contract**:
- Receives project root as first argument
- Exit code 0 = proceed to Step 0.5
- Exit code non-zero = abort closure with hook's stderr/stdout as message
- Hook is responsible for its own user communication

**Common use cases**:
- Stash files that shouldn't be committed (`.pages`, `.numbers`, temp files)
- Run project-specific preparation scripts
- Check project-specific preconditions

**Example hook** (stash Apple Pages files):

```bash
#!/bin/bash
# .claude/hooks/session-pre-check.sh
# Stash Apple Pages files before session skills run

PROJECT_ROOT="${1:-$PWD}"
cd "$PROJECT_ROOT" || exit 1

# Find modified .pages files
PAGES_FILES=$(git status --porcelain | grep '\.pages$' | awk '{print $2}')

if [ -n "$PAGES_FILES" ]; then
  echo "📦 Stashing Apple Pages files (autosave noise)..."
  git stash push -m "session-pre-check: .pages files" -- $PAGES_FILES
  echo "✓ Stashed. Will auto-pop after session skill completes."
fi

exit 0
```

**If hook doesn't exist**: Skip silently, proceed to Step 0.5

**Error handling**:
- Hook not executable: Display warning, proceed to Step 0.5
- Hook fails (non-zero): Display hook output, abort closure
- Hook timeout: Not enforced (project's responsibility)

---

### Step 0.5: Handle ALL Uncommitted Changes

Before archiving or creating new resume, check for ANY uncommitted changes in the repository.

**Why**: User may have manually edited files between sessions. These changes contain important context that should be reviewed and preserved in git history.

**Implementation**:

Run the uncommitted changes detection script:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/check_uncommitted_changes.sh" "${PROJECT_ROOT:-$PWD}"
```

**Script behavior**:
- **Not a git repo**: Exits silently (code 0) → proceed to Step 1
- **No uncommitted changes**: Exits silently (code 0) → proceed to Step 1
- **Uncommitted changes detected**: BLOCKS with detailed output (exit code 1)

**When changes detected** (BLOCKING):

The script displays:
1. **Contextual header**: What changed (resume only, project files only, or both)
2. **File list**: `git status --short` output
3. **Full diffs**: All modifications shown with `git diff HEAD`
4. **Untracked file contents**: Transparency about new files
5. **Secret file warning**: If .env, credentials, keys detected
6. **Clear instructions**: Steps to commit manually with CORE_PROCESSES.md reference

**Required action when blocked**:

When uncommitted changes are detected, you MUST commit them before proceeding:

1. **Review changes**: Script displays full diffs
2. **Check for secrets**: Script warns if .env, credentials, keys found
3. **Commit manually**:
   ```bash
   git add <files>
   git commit -S -s -m "Pre-closure changes: $(date +%Y-%m-%d-%H%M)

   CLAUDE_RESUME.md: [what changed]
   LOCAL_CONTEXT.md: [what changed]
   [other files]: [what changed]"
   ```
4. **User says "close context" again** → Step 0 passes (clean state)
5. **Continue closure** → Proceed to Step 1

**Why blocking is necessary**:
- Separates user changes from session closure work
- Maintains clean git checkpoints for recovery
- Ensures explicit approval for all commits (protocol requirement)
- Prevents silent commits of potentially sensitive changes

**Error handling**:
- Script not found: Display error, proceed with warning
- Script fails: Display error, suggest manual `git status`
- Git command fails: Script handles gracefully

### Step 1: Archive Existing Resume

Run archive script before creating new resume:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/archive_resume.sh" "${PROJECT_ROOT:-$PWD}"
```

**Script behavior**:
- If CLAUDE_RESUME.md doesn't exist: Skip
- If tracked in git: Skip (git history is archive)
- Otherwise: Move to `archives/CLAUDE_RESUME/<timestamp>.md`

**Output messages**:
- "✓ No previous resume to archive"
- "✅ CLAUDE_RESUME.md tracked in git with no uncommitted changes"
- "⚠️  CLAUDE_RESUME.md has uncommitted changes" (recommends commit)
- "📦 Archived to archives/CLAUDE_RESUME/YYYY-MM-DD-HHMM.md"

### Step 2: Assess Session State

Analyze the session: What completed? What decisions made and why? Tasks pending? Blockers? Insights? Critical context?

If context is limited, focus on essential state. Optional sections (Key Decisions, Insights & Learnings) can be skipped.

### Step 3: Create CLAUDE_RESUME.md

**Location** (two supported locations):
- `.claude/CLAUDE_RESUME.md` (preferred, aligns with Claude Code patterns)
- `CLAUDE_RESUME.md` (legacy, project root)

Use same location as existing resume if one exists. For new resumes, prefer `.claude/` if that directory exists.

**Format**: See `references/RESUME_FORMAT_v1.3.md` for complete specification.

**BEFORE creating file, verify you will include ALL required sections:**

**Required sections** (verify before writing):
- [ ] Header with `**Last Session**: [date]`, duration, overall status
- [ ] `## Last Activity Completed`
- [ ] `## Pending Tasks`
- [ ] `## Session Summary`
- [ ] `## Project Status` (required)
- [ ] `## Next Session Focus`
- [ ] Footer: `*Resume created by session-closure v[version]: [timestamp]*`

**Optional sections** (include if applicable and context allows):
- [ ] `## Key Decisions Made`
- [ ] `## Insights & Learnings`
- [ ] `## Sync Status` (only if external authoritative sources exist)
- [ ] `## Pending Outbound Handoffs` (only if handoffs sent awaiting response)

**After verifying checklist, create file with these sections:**

- Header (project name, date, duration, status)
- Last Activity Completed
- Pending Tasks
- Key Decisions Made (optional)
- Insights & Learnings (optional)
- Session Summary
- Sync Status (if external authoritative sources exist)
- Pending Outbound Handoffs (if handoffs sent awaiting response)
- Project Status (required)
- Next Session Focus
- Footer (version, timestamp, instructions)

### Step 4: Verify Resume Creation

Validate resume after creation:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/validate_resume.sh" "${PROJECT_ROOT:-$PWD}"
```

**Checks**: File exists, required sections present, footer format correct.

**Output**:
- "✅ Resume validation passed" (success)
- "❌ Resume validation failed: [missing sections]" (failure)

**If validation fails**: Add missing sections, re-run validation.

### Step 5: Commit New Resume

See **CORE_PROCESSES.md § Git Commit Protocol** for commit requirements.

**Quick reference**: `git commit -S -s -m "message"` (no Claude attribution)

Run commit script:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-closure}/scripts/commit_resume.sh" "${PROJECT_ROOT:-$PWD}"
```

**Script behavior**:
- Verifies ONLY CLAUDE_RESUME.md has uncommitted changes
- Commits with standardized message and -S -s flags
- Blocks if unexpected files changed (safety check)

**Output**:
- `✅ Session resume committed` - Success
- `✓ No uncommitted changes` - Already clean
- `✓ Not a git repository` - Skipped
- `❌ ERROR: Unexpected changes detected` - Unexpected files modified

**Hook enforcement**: User-level hooks (`~/.claude/hooks/`) validate all commits:
- `git-commit-compliance.py`: -S -s flags, message quality, no attribution
- `git-workflow-guidance.py`: Separate git add from git commit

### Step 6: Confirmation

Report completion after validation:

```markdown
✅ Session closure complete.

📄 CLAUDE_RESUME.md created and validated
[Archive output if applicable]

Summary: [One sentence about session outcome]

💡 Next session: Say "resume" to continue from here.
```

---

## Additional Documentation

- **references/README.md** - Installation, usage, and troubleshooting guide
- **references/RESUME_FORMAT_v1.3.md** - Complete resume format specification (required reading)
- **references/CONTRIBUTING.md** - Development, testing, and contribution guide

---

*Session-closure skill v0.5.1 - Added pre-check hook, .claude/ location support, version sync (January 2026)*
