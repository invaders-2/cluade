#!/bin/bash
# test_scripts.sh - Test suite for session-closure scripts
# Part of session-closure skill
#
# Usage: ./test_scripts.sh
#
# Tests:
# 1. archive_resume.sh - First closure (no previous resume)
# 2. archive_resume.sh - Second closure (archives previous)
# 3. archive_resume.sh - Git-tracked resume (skips archive)
# 4. validate_resume.sh - Valid resume passes
# 5. validate_resume.sh - Invalid resume fails
# 6. validate_resume.sh - Missing file handled

set -e

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$TEST_DIR/fixtures"
TEMP_DIR="$TEST_DIR/tmp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Utility functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

setup_test_env() {
    # Create temp directory for testing
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
}

cleanup_test_env() {
    cd "$TEST_DIR"
    rm -rf "$TEMP_DIR"
}

# Test 1: First closure (no previous resume)
test_first_closure() {
    echo ""
    echo "Test 1: First closure (no previous resume)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Execute: archive script with no existing resume
    OUTPUT=$("$SCRIPT_DIR/archive_resume.sh" 2>&1)

    # Verify: Should report no resume to archive
    if [[ "$OUTPUT" == *"No previous resume to archive"* ]]; then
        pass "No previous resume message shown"
    else
        fail "Expected 'No previous resume' message, got: $OUTPUT"
    fi

    # Verify: No archive directory created
    if [ ! -d "archives/CLAUDE_RESUME" ]; then
        pass "No archive directory created"
    else
        fail "Archive directory should not exist"
    fi

    cleanup_test_env
}

# Test 2: Second closure (archives previous)
test_second_closure() {
    echo ""
    echo "Test 2: Second closure (archives previous resume)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create existing resume
    cp "$FIXTURE_DIR/sample_resume.md" CLAUDE_RESUME.md

    # Execute: archive script
    OUTPUT=$("$SCRIPT_DIR/archive_resume.sh" 2>&1)

    # Verify: Archive message shown
    if [[ "$OUTPUT" == *"Archived to archives/CLAUDE_RESUME"* ]]; then
        pass "Archive success message shown"
    else
        fail "Expected archive message, got: $OUTPUT"
    fi

    # Verify: Archive directory created
    if [ -d "archives/CLAUDE_RESUME" ]; then
        pass "Archive directory created"
    else
        fail "Archive directory should exist"
    fi

    # Verify: Archive file exists with timestamp format
    ARCHIVE_COUNT=$(find archives/CLAUDE_RESUME -name "*.md" | wc -l | tr -d ' ')
    if [ "$ARCHIVE_COUNT" -eq 1 ]; then
        pass "One archive file created"
    else
        fail "Expected 1 archive file, found: $ARCHIVE_COUNT"
    fi

    # Verify: Original file moved (not copied)
    if [ ! -f "CLAUDE_RESUME.md" ]; then
        pass "Original resume removed"
    else
        fail "Original resume should be moved, not copied"
    fi

    cleanup_test_env
}

# Test 3: Git-tracked resume (skips archive)
test_git_tracked() {
    echo ""
    echo "Test 3: Git-tracked resume (skips archive)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create git repo and track resume
    git init -q
    cp "$FIXTURE_DIR/sample_resume.md" CLAUDE_RESUME.md
    git add CLAUDE_RESUME.md
    git commit -q -m "Initial commit"

    # Execute: archive script
    OUTPUT=$("$SCRIPT_DIR/archive_resume.sh" 2>&1)

    # Verify: Git tracking message shown
    if [[ "$OUTPUT" == *"tracked in git"* ]]; then
        pass "Git tracking detected, archive skipped"
    else
        fail "Expected git tracking message, got: $OUTPUT"
    fi

    # Verify: No archive directory created
    if [ ! -d "archives/CLAUDE_RESUME" ]; then
        pass "No archive directory created (using git history)"
    else
        fail "Archive directory should not exist for git-tracked files"
    fi

    # Verify: Original file still exists
    if [ -f "CLAUDE_RESUME.md" ]; then
        pass "Original resume preserved"
    else
        fail "Original resume should still exist"
    fi

    cleanup_test_env
}

# Test 4: Valid resume passes validation
test_valid_resume() {
    echo ""
    echo "Test 4: Valid resume passes validation"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Copy valid resume
    cp "$FIXTURE_DIR/sample_resume.md" CLAUDE_RESUME.md

    # Execute: validate script (pass current directory as PROJECT_ROOT)
    if "$SCRIPT_DIR/validate_resume.sh" . >/dev/null 2>&1; then
        pass "Valid resume passed validation"
    else
        fail "Valid resume should pass validation"
    fi

    cleanup_test_env
}

# Test 5: Invalid resume fails validation
test_invalid_resume() {
    echo ""
    echo "Test 5: Invalid resume fails validation"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create incomplete resume (missing sections)
    cat > CLAUDE_RESUME.md <<EOF
# Claude Resume - Incomplete

**Last Session**: October 27, 2025

## Last Activity Completed

Did some work.
EOF

    # Execute: validate script (should fail - pass current directory as PROJECT_ROOT)
    if ! "$SCRIPT_DIR/validate_resume.sh" . >/dev/null 2>&1; then
        pass "Invalid resume correctly failed validation"
    else
        fail "Invalid resume should fail validation"
    fi

    cleanup_test_env
}

# Test 6: Missing file handled gracefully
test_missing_file() {
    echo ""
    echo "Test 6: Missing resume file handled"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Execute: validate script on directory with no resume (capture exit code)
    set +e  # Temporarily disable exit on error
    "$SCRIPT_DIR/validate_resume.sh" . >/dev/null 2>&1
    EXIT_CODE=$?
    set -e  # Re-enable exit on error

    if [ $EXIT_CODE -eq 2 ]; then
        pass "Missing resume detected with correct exit code"
    else
        fail "Expected exit code 2, got: $EXIT_CODE"
    fi

    cleanup_test_env
}

# ============================================
# v0.5.1 Tests: Dual Location Support
# ============================================

# Test 7: Archive from .claude/ location
test_archive_claude_dir() {
    echo ""
    echo "Test 7: Archive from .claude/ location"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create resume in .claude/ directory
    mkdir -p .claude
    cp "$FIXTURE_DIR/sample_resume.md" .claude/CLAUDE_RESUME.md

    # Execute: archive script
    OUTPUT=$("$SCRIPT_DIR/archive_resume.sh" 2>&1)

    # Verify: Archive message references .claude/ path
    if [[ "$OUTPUT" == *"Archived to .claude/archives/CLAUDE_RESUME"* ]]; then
        pass ".claude/ archive path used"
    else
        fail "Expected .claude/archives/ path, got: $OUTPUT"
    fi

    # Verify: Archive directory created in .claude/
    if [ -d ".claude/archives/CLAUDE_RESUME" ]; then
        pass ".claude/archives/ directory created"
    else
        fail ".claude/archives/ directory should exist"
    fi

    cleanup_test_env
}

# Test 8: Archive from root when no .claude/ resume
test_archive_root_location() {
    echo ""
    echo "Test 8: Archive from root location"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create resume in root only (no .claude/)
    cp "$FIXTURE_DIR/sample_resume.md" CLAUDE_RESUME.md

    # Execute: archive script
    OUTPUT=$("$SCRIPT_DIR/archive_resume.sh" 2>&1)

    # Verify: Archive message references root path
    if [[ "$OUTPUT" == *"Archived to archives/CLAUDE_RESUME"* ]]; then
        pass "Root archive path used"
    else
        fail "Expected archives/ path, got: $OUTPUT"
    fi

    # Verify: Archive directory created in root
    if [ -d "archives/CLAUDE_RESUME" ]; then
        pass "Root archives/ directory created"
    else
        fail "Root archives/ directory should exist"
    fi

    cleanup_test_env
}

# Test 9: Validate resume in .claude/ location
test_validate_claude_dir() {
    echo ""
    echo "Test 9: Validate resume (.claude/ location)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create valid resume in .claude/
    mkdir -p .claude
    cp "$FIXTURE_DIR/sample_resume.md" .claude/CLAUDE_RESUME.md

    # Execute: validate script
    if "$SCRIPT_DIR/validate_resume.sh" . >/dev/null 2>&1; then
        pass ".claude/ resume validated successfully"
    else
        fail ".claude/ resume should pass validation"
    fi

    cleanup_test_env
}

# Test 10: .claude/ location takes precedence for validation
test_validate_precedence() {
    echo ""
    echo "Test 10: Validate precedence (.claude/ over root)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Invalid resume in root, valid in .claude/
    cat > CLAUDE_RESUME.md <<EOF
# Incomplete Resume
Just some text, missing sections.
EOF

    mkdir -p .claude
    cp "$FIXTURE_DIR/sample_resume.md" .claude/CLAUDE_RESUME.md

    # Execute: validate script (should pass because .claude/ is valid)
    if "$SCRIPT_DIR/validate_resume.sh" . >/dev/null 2>&1; then
        pass ".claude/ takes precedence in validation"
    else
        fail "Should validate .claude/ resume (ignore invalid root)"
    fi

    cleanup_test_env
}

# Run all tests
echo "========================================"
echo "session-closure Script Test Suite"
echo "========================================"

test_first_closure
test_second_closure
test_git_tracked
test_valid_resume
test_invalid_resume
test_missing_file
# v0.5.1 tests
test_archive_claude_dir
test_archive_root_location
test_validate_claude_dir
test_validate_precedence

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
else
    echo "Tests failed: $TESTS_FAILED"
fi
echo "========================================"

# Exit with failure if any tests failed
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0
