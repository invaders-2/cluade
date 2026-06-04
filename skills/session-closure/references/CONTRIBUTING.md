# session-closure - Contributing Guide

Guide for developers contributing to the session-closure skill.

## Script Documentation

### archive_resume.sh
- **Purpose**: Archive existing resume with timestamp
- **Options**: `--dry-run`
- **Exit**: 0=success

### commit_resume.sh
- **Purpose**: Commit new resume to git
- **Features**: Secrets detection, per-file summaries
- **Exit**: 0=success, 1=error

### validate_resume.sh
- **Purpose**: Verify resume structure
- **Checks**: Required sections present
- **Exit**: 0=valid, 1=invalid

### check_uncommitted_changes.sh
- **Purpose**: Block execution if uncommitted changes exist
- **Output**: Detailed change summary if changes detected
- **Exit**: 0=clean/not-git, 1=blocking, 2=error
- **Note**: Duplicated in session-resume (see Duplication Strategy below)

### check_permissions.sh
- **Purpose**: Verify required permissions are configured in settings.local.json
- **Output**: Structured list of missing/deprecated permissions if configuration needed
- **Exit**: 0=all-present (silent), 1=missing (output details), 2=error
- **Note**: Duplicated in session-resume (see Duplication Strategy below)

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

### Manual Testing

**Test 1: Basic closure**
```bash
# Do some work
# Say "close context"
# Expected: Resume created, validated, committed
```

**Test 2: Uncommitted changes (Step 0.5)**
```bash
# Make changes, don't commit
# Say "close context"
# Expected: Changes detected, committed together with resume
```

**Test 3: Secret files**
```bash
# Create .env file
# Say "close context"
# Expected: Blocks, warns about secrets
```

**Test 4: Archive behavior**
```bash
# Create resume
# Say "close context" again
# Expected: Previous resume archived
```

### Verification

After closure:
- `cat CLAUDE_RESUME.md` - Resume created
- `git log -1` - Resume committed
- `git status` - Clean working directory
- `ls claude/archive/sessions/` - Previous resume archived (if existed)

## Duplication Strategy

**Intentional duplication** exists for skill independence:

### 1. check_uncommitted_changes.sh
- **Duplicated in**: session-resume
- **Reason**: Each skill must work standalone
- **Synchronization**: Changes must be made manually to both copies
- **Verification**: Run `test_sync.sh` after modifications

### 2. check_permissions.sh
- **Duplicated in**: session-resume
- **Reason**: Both skills need permission verification on first use
- **Synchronization**: Changes must be made manually to both copies
- **Verification**: Run `test_sync.sh` after modifications

### 3. RESUME_FORMAT_v1.2.md
- **Duplicated in**: session-resume
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
5. **Test manually**: Say "close context" in a real project
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

*Contributing guide for session-closure*
