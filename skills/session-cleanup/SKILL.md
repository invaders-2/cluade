---
name: session-cleanup
version: 0.5.2
description: >
  Adaptive session audit before closure. Uses structured ultrathink
  with category hints to review session work proportionate to complexity.
  Detects session depth (light/standard/thorough) and adjusts analysis.
  Checks for stale planning docs (>30 days). Loads project-specific
  checks if present. Prepares for session-closure.

  INVOCATION: Claude uses the Skill tool to invoke this skill when user
  says "session cleanup", "session review", "audit session", "pre-closure
  check", or "cleanup". The skill is NOT invoked by running scripts directly.

  WHEN: User requests session review before closing. Typically after
  significant work, before "close context" or session-closure.

  WHEN NOT: Quick session endings (use session-closure directly),
  mid-session file reviews, trivial sessions with no changes.
---

# Session Cleanup Protocol

## Contents

1. [Cleanup Steps](#cleanup-steps)
   - [Step 0: Check Permissions](#step-0-check-permissions-one-time-setup)
   - [Step 0.5: Check Uncommitted Changes](#step-05-check-uncommitted-changes)
   - [Step 1: Detect Session Complexity](#step-1-detect-session-complexity)
   - [Step 1.5: Check Stale Planning Docs](#step-15-check-stale-planning-docs)
   - [Step 2: Structured Ultrathink](#step-2-structured-ultrathink)
   - [Step 3: Validation Pass](#step-3-validation-pass)
   - [Step 4: Project-Specific Checks](#step-4-project-specific-checks)
   - [Step 5: Handoff to Session-Closure](#step-5-handoff-to-session-closure)
2. [Additional Documentation](#additional-documentation)

---

## Cleanup Steps

### Step 0: Check Permissions (ONE-TIME SETUP)

**Purpose**: Verify session-cleanup permissions are configured to prevent repeated permission prompts.

Run the permission check script:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_permissions.sh" "${PROJECT_ROOT:-$PWD}"
```

**Script behavior**:
- **All permissions present**: Exits silently (code 0) → proceed to Step 0.5
- **Permissions missing**: Exits with details (code 1) → offer configuration
- **No settings file**: Exits with MISSING_FILE marker → offer to create

**When configuration needed**:

Present configuration offer to user:

```markdown
🔧 Session-cleanup skill needs one-time permission setup

Missing required permissions:
- Skill(session-cleanup)
- [Other patterns from script output]

I can configure these automatically. May I update .claude/settings.local.json?
```

**After user approval, execute inline configuration script**:

```bash
#!/bin/bash
# Inline permission configuration for session-cleanup skill

PROJECT_DIR="${PROJECT_ROOT:-$PWD}"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"

mkdir -p "$PROJECT_DIR/.claude"

# Session-cleanup required permission patterns
REQUIRED_PATTERNS='[
  "Skill(session-cleanup)",
  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_permissions.sh\" \"${PROJECT_ROOT:-$PWD}\")",
  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_uncommitted_changes.sh\" \"${PROJECT_ROOT:-$PWD}\")",
  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/detect_complexity.sh\" \"${PROJECT_ROOT:-$PWD}\")",
  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/find_local_cleanup.sh\" \"${PROJECT_ROOT:-$PWD}\")",
  "Bash(\"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_stale_planning.sh\" \"${PROJECT_ROOT:-$PWD}\")",
  "Read(~/.claude/skills/session-cleanup/**)"
]'

if [ ! -f "$SETTINGS_FILE" ]; then
  cat > "$SETTINGS_FILE" <<EOF
{
  "permissions": {
    "allow": $REQUIRED_PATTERNS,
    "deny": [],
    "ask": []
  }
}
EOF
  echo "✅ Created $SETTINGS_FILE with session-cleanup permissions"
else
  if command -v jq >/dev/null 2>&1; then
    REQUIRED_JSON=$(echo "$REQUIRED_PATTERNS" | jq -c '.')
    jq --argjson new "$REQUIRED_JSON" \
       '.permissions.allow = ([.permissions.allow[], $new[]] | unique)' \
       "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    echo "✅ Updated $SETTINGS_FILE with session-cleanup permissions"
  else
    echo "⚠️  jq not found - add these patterns manually to permissions.allow:"
    echo "$REQUIRED_PATTERNS"
  fi
fi
```

**After configuration**: Proceed to Step 0.5. Future sessions will skip this step.

---

### Step 0.5: Check Uncommitted Changes

Ensure clean git state before audit:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_uncommitted_changes.sh" "${PROJECT_ROOT:-$PWD}"
```

**Script behavior**:
- **Not a git repo**: Exits silently (code 0) → proceed to Step 1
- **No uncommitted changes**: Exits silently (code 0) → proceed to Step 1
- **Uncommitted changes detected**: BLOCKS with details (exit code 1)

**When blocked**: Commit changes first, then re-run "session cleanup".

---

### Step 1: Detect Session Complexity

Determine appropriate depth for session review:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/detect_complexity.sh" "${PROJECT_ROOT:-$PWD}"
```

**Output determines depth**:
- **light**: 0-1 commits, <5 files → abbreviated review
- **standard**: 2-5 commits, 5-15 files → full review
- **thorough**: 6+ commits, 15+ files → deep review with extra validation

Use the detected depth to calibrate Step 2 analysis.

---

### Step 1.5: Check Stale Planning Docs

Detect planning documents that may be abandoned or need completion:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/check_stale_planning.sh" "${PROJECT_ROOT:-$PWD}"
```

**Script behavior**:
- **No planning directory**: Exits silently (code 0) → proceed to Step 2
- **No stale docs**: Reports active docs (informational) → proceed to Step 2
- **Stale docs found** (>30 days): Warns with options (code 1) → add to [ASK user] list

**When stale docs found**:

The script identifies documents that haven't been updated in >30 days and suggests:
1. **COMPLETE**: Integrate findings into permanent docs, then delete
2. **UPDATE**: If work is ongoing, touch file to reset timer
3. **ABANDON**: If obsolete, delete with commit noting abandonment

Add stale docs to the [ASK user] category in Step 2 - user decides disposition.

**Why this matters**: Planning docs are ephemeral by design. Stale docs indicate either:
- Abandoned work (should be deleted)
- Forgotten integration (should be completed)
- Ongoing work that needs attention (should be updated)

**See**: CORE_PROCESSES.md § Transient Artifacts Overview for staleness thresholds.

---

### Step 2: Structured Ultrathink

**Core of session-cleanup**: Guided but flexible analysis.

Execute this ultrathink prompt, adjusting depth based on Step 1:

```
Ultrathink session review [DEPTH from Step 1]:

Consider these categories:
(a) Session continuity - did work match the plan/resume?
(b) Document staleness - any planning docs ready for deletion?
(c) File proliferation - any new files that should be integrated?
(d) Cross-references - any stale paths or broken links?
(e) Technical debt - any workarounds, TODOs, or deferred issues?
(f) Test coverage (BLOCKING) - if skills/hooks modified, were tests written?
    - No deployment without tests (skill-deployment.md § Step 0)
    - v1.7.3 shipped without tests - this is the anti-pattern to prevent
(g) Issue resolution - any GitHub issues resolved? Close with details.
(h) Marketplace changes (BLOCKING) - if marketplace.json modified:
    - Schema validated against Claude Code docs?
    - All keys recognized (no `tools`, etc.)?
    - hooks/mcpServers use .json config format?
    - Installation tested end-to-end?
    - v1.7.2-1.7.4 had invalid schema - this is the anti-pattern to prevent

Categorize findings as:
- [EXECUTE now] - do before session closes
- [DEFER to next session] - capture in resume
- [ASK user] - need decision/clarification
```

**Depth adjustments**:
- **light**: Brief check of each category, focus on obvious issues
- **standard**: Full analysis of each category
- **thorough**: Deep analysis, check file contents, verify cross-refs

**Output format**:

```markdown
## Session Review Findings

### [EXECUTE now]
- Item 1
- Item 2

### [DEFER to next session]
- Item 1

### [ASK user]
- Question 1

### Summary
[1-2 sentence summary of session state]
```

---

### Step 3: Validation Pass

Quick coverage check (not re-analysis):

After completing Step 2, verify you addressed:

- [ ] **Git state** - All work committed?
- [ ] **Context docs** - LOCAL_CONTEXT.md current?
- [ ] **Planning docs** - Any complete/stale?
- [ ] **New files** - Appropriate locations?

If any item missed, add to [EXECUTE now] or [DEFER] list.

---

### Step 4: Project-Specific Checks

Check for project-specific cleanup checklist:

```bash
"${SKILL_BASE:-$HOME/.claude/skills/session-cleanup}/scripts/find_local_cleanup.sh" "${PROJECT_ROOT:-$PWD}"
```

**If local file found** (checked in order):
- `.claude/processes/local-session-cleanup.md` (preferred)
- `claude/processes/local-session-cleanup.md` (legacy)

1. Read the file
2. Execute project-specific checks
3. Add findings to appropriate category ([EXECUTE/DEFER/ASK])

**If no local file**: Skip this step (generic cleanup complete).

---

### Step 5: Handoff to Session-Closure

Present findings and transition:

```markdown
## Session Cleanup Complete

**Depth**: [light/standard/thorough]
**Findings**: [count] EXECUTE, [count] DEFER, [count] ASK

### Action Items
[List any [EXECUTE now] items to complete]

### For Resume
[List [DEFER] items to capture]

### Questions
[List [ASK] items needing user input]

---

When ready to close session, say "close context" or invoke session-closure.
```

**Important**: Session-cleanup does NOT auto-invoke session-closure (safety).

---

## Additional Documentation

- **references/README.md** - Installation and usage guide
- **references/LOCAL_TEMPLATE.md** - Template for project-specific cleanup checklist
- **references/CONTRIBUTING.md** - Development and contribution guide

---

*Session-cleanup skill v0.5.2 - Added category (h) marketplace validation (January 2026)*
