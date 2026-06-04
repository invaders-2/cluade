# session-resume - Contributing Guide

Guide for developers contributing to the session-resume skill.

## Script Documentation

### check_uncommitted_changes.sh
- **Purpose**: Block resume if uncommitted changes exist
- **Output**: Detailed change summary if changes detected
- **Exit**: 0=clean/not-git, 1=blocking, 2=error
- **Note**: Duplicated in session-closure (see Duplication Strategy below)

### check_permissions.sh
- **Purpose**: Verify required permissions are configured in settings.local.json
- **Output**: Structured list of missing/deprecated permissions if configuration needed
- **Exit**: 0=all-present (silent), 1=missing (output details), 2=error
- **Note**: Duplicated in session-closure (see Duplication Strategy below)

### check_staleness.sh
- **Purpose**: Check resume age
- **Output**: fresh|recent|stale|very_stale
- **Exit**: 0=success, 1=error

### list_archives.sh
- **Purpose**: List archived resumes
- **Options**: `--limit N`, `--format short|detailed`
- **Exit**: 0=success

## Testing

### Automated Tests

Run test suite:
```bash
cd tests && ./test_scripts.sh
```

Verify duplicated files remain synchronized:
```bash
cd tests && ./test_sync.sh
```

Tests cover uncommitted change detection and archive listing.

### Manual Testing

**Test 1: Basic resume loading**
```bash
# Create a resume (use session-closure)
# Exit and restart Claude
# Say "resume"
# Expected: Resume loads, shows summary
```

**Test 2: Uncommitted changes (Step 0.5)**
```bash
# Make changes to a file (don't commit)
# Say "resume"
# Expected: Blocks with change summary
# Commit changes
# Say "resume" again
# Expected: Resume loads normally
```

**Test 3: No resume**
```bash
# Delete CLAUDE_RESUME.md
# Say "resume"
# Expected: "No resume found" message
```

### Cross-Platform Testing

**macOS**: Primary development platform
**Linux**: Verify date command compatibility in check_staleness.sh

## Duplication Strategy

**Intentional duplication** exists for skill independence:

### 1. check_uncommitted_changes.sh
- **Duplicated in**: session-closure
- **Reason**: Each skill must work standalone
- **Synchronization**: Changes must be made manually to both copies
- **Verification**: Run `test_sync.sh` after modifications

### 2. check_permissions.sh
- **Duplicated in**: session-closure
- **Reason**: Both skills need permission verification on first use
- **Synchronization**: Changes must be made manually to both copies
- **Verification**: Run `test_sync.sh` after modifications

### 3. RESUME_FORMAT_v1.2.md
- **Duplicated in**: session-closure
- **Reason**: Each skill documents its own format expectations
- **Synchronization**: Changes must be made manually to both copies
- **Verification**: Run `test_sync.sh` to verify

### Why not use symlinks?

Claude Code has known symlink bugs (GitHub Issues #764, #10573) that break skill functionality. Skills must be self-contained with all dependencies included.

## Contributing Workflow

1. **Make changes** to scripts or documentation
2. **Run tests**:
   ```bash
   cd tests
   ./test_scripts.sh  # Functional tests
   ./test_sync.sh     # Verify duplicated files remain synchronized
   ```
3. **If modifying duplicated files**: Update both copies (session-closure and session-resume)
4. **Update SKILL.md** if protocol changes
5. **Test manually**: Say "resume" in a project with CLAUDE_RESUME.md
6. **Submit PR** with:
   - Clear description of changes
   - Test results
   - Any new dependencies or requirements

## Version Management

- **Authoritative version**: SKILL.md frontmatter only
- **Reference docs**: No version numbers (this file, README.md, etc.)
- **Scripts**: No version comments - git history is source of truth

This reduces sync burden and prevents version drift across documentation.

---

*Contributing guide for session-resume*
