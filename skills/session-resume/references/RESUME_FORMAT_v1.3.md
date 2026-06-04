# CLAUDE_RESUME.md Format v1.3.0

**Created by**: session-closure skill
**Loaded by**: session-resume skill
**Purpose**: Session continuity and inter-project communication

> **Note**: This format specification is duplicated in both session-closure and session-resume skills for self-contained documentation. Any changes must be synchronized manually between both copies. Run tests/test_sync.sh to verify files remain identical.

---

## Complete Format

```markdown
# Claude Resume - [Project Name]

**Last Session**: [Date]
**Session Duration**: [Approximate time]
**Overall Status**: [One-line summary]

---

## Last Activity Completed

[What was just finished - enough detail to understand context]

---

## Pending Tasks

- [ ] [Next immediate task]
- [ ] [Subsequent tasks]

---

## Key Decisions Made
*Optional - include when significant decisions were made*

[Important decisions - focus on WHY not just WHAT]

---

## Insights & Learnings
*Optional - include when discoveries were made*

[Patterns found, approaches that worked/didn't work]

---

## Session Summary

[2-3 sentences on what was accomplished and why]

---

## Sync Status
*Include ONLY if project has external authoritative sources (Google Docs, HackMD, GitHub)*

- Google Docs: [last sync date or "current"]
- HackMD: [last sync date or "current"]
- GitHub: [last sync date or "current"]

---

## Pending Outbound Handoffs
*Optional - include when handoffs sent to other projects awaiting response*

| Sent | Destination | Summary | Response requested |
|------|-------------|---------|-------------------|
| YYYY-MM-DD | [Project name] | [Brief description] | YES/NO |

---

## Project Status
*Required for all projects - enables inter-project communication*

- **Current State**: [STATE] - Brief description
- **Key Changes**: What changed this session
- **Next Priority**: Immediate action needed
- **Dependencies**: Any blockers
- **Project Health**: Overall assessment

**State Options**:
- 🟢 ACTIVE - Currently being worked on
- 🔴 BLOCKED - Waiting on external dependency
- 🟡 WAITING - Paused for specific reason
- ✅ COMPLETE - Finished
- 🔄 REVIEW - Under review/testing

---

## Next Session Focus

[What the next session should tackle first]

---

*Resume created by session-closure v1.3.0: [Timestamp]*
*Next session: Say "resume" to load this context*
```

---

## Section Guidelines

### Always Required
- **Header**: Project name, date, duration, status
- **Last Activity**: Past tense, narrative
- **Pending Tasks**: Checkbox format, priority order
- **Project Status**: Current state + next priority
- **Next Session Focus**: Clear starting point
- **Footer**: Version, timestamp, instructions

### Optional Sections
- **Key Decisions**: When significant choices were made
- **Insights & Learnings**: When discoveries occurred
- **Session Summary**: 2-3 sentence overview
- **Sync Status**: ONLY if external authoritative sources exist
- **Pending Outbound Handoffs**: When handoffs sent to other projects await response

### Omit Sync Status If
- No Google Docs/HackMD/GitHub as authoritative sources
- Everything is local/git only
- No synchronization workflow

---

## Version Compatibility

### v1.3.0 (Current)
- Added: "Pending Outbound Handoffs" section (optional)
- Backward compatible: Can read v1.0.0 through v1.2.0

### v1.2.0
- Added: "Project Status" section (required)
- Added: "Sync Status" section (conditional)
- Backward compatible: Can read v1.0.0 and v1.1.0

### v1.1.0
- Added: Archive management
- Format unchanged from v1.0.0

### v1.0.0
- Original format

All versions are backward/forward compatible (newer versions ignore missing sections).

---

## Validation

Use validation script:
```bash
~/.claude/skills/session-closure/scripts/validate_resume.sh CLAUDE_RESUME.md
```

**Checks**: File exists, required sections present, footer format correct.

---

*CLAUDE_RESUME.md Format v1.3.0 - Added Pending Outbound Handoffs (December 2025)*
