# session-cleanup - Contributing Guide

Guide for developers contributing to the session-cleanup skill.

## Script Documentation

### check_permissions.sh
- **Purpose**: Verify required permissions are configured
- **Output**: Structured list of missing permissions if configuration needed
- **Exit**: 0=all-present (silent), 1=missing (output details)
- **Note**: Copied from session-closure (see Duplication Strategy below)

### check_uncommitted_changes.sh
- **Purpose**: Block execution if uncommitted changes exist
- **Output**: Detailed change summary if changes detected
- **Exit**: 0=clean/not-git, 1=blocking
- **Note**: Copied from session-closure (see Duplication Strategy below)

### detect_complexity.sh
- **Purpose**: Determine session audit depth based on commits and files changed
- **Output**: DEPTH: light|standard|thorough + INFO line
- **Exit**: 0=success

### find_local_cleanup.sh
- **Purpose**: Check for project-specific cleanup checklist
- **Output**: FOUND: path or INFO: no local file
- **Exit**: 0=success (always)

## Testing

### Manual Testing

**Test 1: Basic cleanup**
```bash
# Do some work (2-5 commits)
# Say "session cleanup"
# Expected: standard depth, structured findings
```

**Test 2: Light session**
```bash
# Do minimal work (0-1 commits)
# Say "session cleanup"
# Expected: light depth, abbreviated review
```

**Test 3: With local file**
```bash
# Create claude/processes/local-session-cleanup.md
# Say "session cleanup"
# Expected: Generic checks + project-specific checks
```

**Test 4: Uncommitted changes**
```bash
# Make changes, don't commit
# Say "session cleanup"
# Expected: Blocks, shows changes
```

### Verification

After cleanup:
- Findings categorized as EXECUTE/DEFER/ASK
- Depth matches session complexity
- Local file detected (if present)
- Handoff instructions shown

## Duplication Strategy

**Intentional duplication** exists for skill independence:

### 1. check_uncommitted_changes.sh
- **Duplicated in**: session-closure, session-resume
- **Reason**: Each skill must work standalone
- **Synchronization**: Changes must be made manually to all copies

### 2. check_permissions.sh
- **Duplicated in**: session-closure, session-resume
- **Reason**: All skills need permission verification on first use
- **Synchronization**: Changes must be made manually to all copies

### Why not use symlinks?

Claude Code has known symlink bugs (GitHub Issues #764, #10573) that break skill functionality. Skills must be self-contained with all dependencies included.

## Contributing Workflow

1. **Make changes** to scripts or documentation
2. **Test manually**: Say "session cleanup" in a real project
3. **If modifying duplicated files**: Update session-closure and session-resume copies
4. **Update SKILL.md** if protocol changes
5. **Submit PR** with:
   - Clear description of changes
   - Test results
   - Any new dependencies or requirements

## Version Management

- **Authoritative version**: SKILL.md frontmatter only
- **Reference docs**: No version numbers (this file, README.md, etc.)
- **Scripts**: No version comments - git history is source of truth

This reduces sync burden and prevents version drift across documentation.

## Design Decisions

### Middle-Ground Approach

Session-cleanup uses a middle-ground design:
- **Mechanical steps** (0, 0.5): Permissions, uncommitted changes
- **Adaptive depth** (1): Calibrate analysis to session complexity
- **Guided ultrathink** (2): Category hints without rigid checklist
- **Validation** (3): Coverage check without re-analysis
- **Optional local** (4): Project-specific customization

This provides structure without rigidity.

### Category Hints

The five ultrathink categories guide analysis:
- (a) Session continuity
- (b) Document staleness
- (c) File proliferation
- (d) Cross-references
- (e) Technical debt

These are hints, not requirements - Claude adapts to what's relevant.

### No Auto-Invoke

Session-cleanup does NOT auto-invoke session-closure. This is intentional:
- User may want to act on EXECUTE items first
- User may have questions (ASK items)
- Explicit handoff provides control

---

*Contributing guide for session-cleanup*
