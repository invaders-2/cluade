#!/bin/bash
# test_session_cleanup.sh - Test suite for session-cleanup scripts
# Part of session-cleanup skill
#
# Usage: ./test_session_cleanup.sh
#
# Tests:
# 1. detect_complexity.sh - Light depth (0-1 commits)
# 2. detect_complexity.sh - Standard depth (2-5 commits)
# 3. detect_complexity.sh - Thorough depth (6+ commits)
# 4. find_local_cleanup.sh - Local file exists
# 5. find_local_cleanup.sh - No local file
# 6. check_permissions.sh - Script exists and runs
# 7. check_uncommitted_changes.sh - Clean repo

set -e

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$TEST_DIR/tmp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
}

cleanup_test_env() {
    cd "$TEST_DIR"
    rm -rf "$TEMP_DIR"
}

# Test 1: Light depth (0-1 commits)
test_light_depth() {
    echo ""
    echo "Test 1: Light depth detection (0-1 commits)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create git repo with 1 commit
    git init -q
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "Initial"

    # Execute
    OUTPUT=$("$SCRIPT_DIR/detect_complexity.sh" 2>&1)

    # Verify
    if [[ "$OUTPUT" == *"DEPTH: light"* ]]; then
        pass "Light depth detected correctly"
    else
        fail "Expected DEPTH: light, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 2: Standard depth (2-5 commits)
test_standard_depth() {
    echo ""
    echo "Test 2: Standard depth detection (2-5 commits)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create git repo with 3 commits
    git init -q
    for i in 1 2 3; do
        echo "content $i" > "file$i.txt"
        git add "file$i.txt"
        git commit -q -m "Commit $i"
    done

    # Execute
    OUTPUT=$("$SCRIPT_DIR/detect_complexity.sh" 2>&1)

    # Verify
    if [[ "$OUTPUT" == *"DEPTH: standard"* ]]; then
        pass "Standard depth detected correctly"
    else
        fail "Expected DEPTH: standard, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 3: Thorough depth (6+ commits)
test_thorough_depth() {
    echo ""
    echo "Test 3: Thorough depth detection (6+ commits)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create git repo with 7 commits
    git init -q
    for i in 1 2 3 4 5 6 7; do
        echo "content $i" > "file$i.txt"
        git add "file$i.txt"
        git commit -q -m "Commit $i"
    done

    # Execute
    OUTPUT=$("$SCRIPT_DIR/detect_complexity.sh" 2>&1)

    # Verify
    if [[ "$OUTPUT" == *"DEPTH: thorough"* ]]; then
        pass "Thorough depth detected correctly"
    else
        fail "Expected DEPTH: thorough, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 4: Local file exists
test_local_file_found() {
    echo ""
    echo "Test 4: Local cleanup file exists"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create local cleanup file
    mkdir -p claude/processes
    echo "# Local cleanup" > claude/processes/local-session-cleanup.md

    # Execute
    OUTPUT=$("$SCRIPT_DIR/find_local_cleanup.sh" 2>&1)

    # Verify
    if [[ "$OUTPUT" == *"FOUND:"* ]]; then
        pass "Local file detected correctly"
    else
        fail "Expected FOUND message, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 5: No local file
test_local_file_not_found() {
    echo ""
    echo "Test 5: No local cleanup file"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # No local file setup

    # Execute
    OUTPUT=$("$SCRIPT_DIR/find_local_cleanup.sh" 2>&1)

    # Verify
    if [[ "$OUTPUT" == *"INFO: No project-specific"* ]]; then
        pass "No local file message shown"
    else
        fail "Expected INFO message, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 6: check_permissions.sh exists and runs
test_permissions_script() {
    echo ""
    echo "Test 6: check_permissions.sh exists and is executable"
    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -x "$SCRIPT_DIR/check_permissions.sh" ]; then
        pass "check_permissions.sh is executable"
    else
        fail "check_permissions.sh should be executable"
    fi
}

# Test 7: check_uncommitted_changes.sh - Clean repo
test_clean_repo() {
    echo ""
    echo "Test 7: Clean repo passes uncommitted check"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create clean git repo
    git init -q
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "Initial"

    # Execute (should succeed with exit 0)
    set +e
    "$SCRIPT_DIR/check_uncommitted_changes.sh" . >/dev/null 2>&1
    EXIT_CODE=$?
    set -e

    if [ $EXIT_CODE -eq 0 ]; then
        pass "Clean repo passes check"
    else
        fail "Expected exit 0, got: $EXIT_CODE"
    fi

    cleanup_test_env
}

# Test 8: SKILL.md exists and has required sections
test_skill_file() {
    echo ""
    echo "Test 8: SKILL.md has required sections"
    TESTS_RUN=$((TESTS_RUN + 1))

    SKILL_FILE="$TEST_DIR/../SKILL.md"

    if [ ! -f "$SKILL_FILE" ]; then
        fail "SKILL.md not found"
        return
    fi

    # Check for required sections
    MISSING=""
    grep -q "^name:" "$SKILL_FILE" || MISSING="$MISSING name"
    grep -q "^version:" "$SKILL_FILE" || MISSING="$MISSING version"
    grep -q "## Cleanup Steps" "$SKILL_FILE" || MISSING="$MISSING CleanupSteps"
    grep -q "### Step 0:" "$SKILL_FILE" || MISSING="$MISSING Step0"
    grep -q "### Step 2: Structured Ultrathink" "$SKILL_FILE" || MISSING="$MISSING Ultrathink"

    if [ -z "$MISSING" ]; then
        pass "SKILL.md has required sections"
    else
        fail "SKILL.md missing:$MISSING"
    fi
}

# ============================================
# v0.5.1 Tests: Dual Location Support
# ============================================

# Test 9: find_local_cleanup - .claude/processes/ location
test_local_claude_processes() {
    echo ""
    echo "Test 9: Local cleanup (.claude/processes/ location)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create local cleanup file in .claude/processes/
    mkdir -p .claude/processes
    echo "# Local cleanup" > .claude/processes/local-session-cleanup.md

    # Execute
    OUTPUT=$("$SCRIPT_DIR/find_local_cleanup.sh" 2>&1)

    # Verify: Finds file in .claude/processes/
    if [[ "$OUTPUT" == *"FOUND:"* ]] && [[ "$OUTPUT" == *".claude/processes"* ]]; then
        pass ".claude/processes/ location detected"
    else
        fail "Expected FOUND with .claude/processes/, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 10: .claude/processes/ takes precedence over claude/processes/
test_local_precedence() {
    echo ""
    echo "Test 10: Local cleanup (.claude/ precedence)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create local cleanup files in BOTH locations
    mkdir -p claude/processes
    echo "# Legacy location" > claude/processes/local-session-cleanup.md

    mkdir -p .claude/processes
    echo "# Preferred location" > .claude/processes/local-session-cleanup.md

    # Execute
    OUTPUT=$("$SCRIPT_DIR/find_local_cleanup.sh" 2>&1)

    # Verify: Finds file in .claude/processes/ (preferred)
    if [[ "$OUTPUT" == *"FOUND:"* ]] && [[ "$OUTPUT" == *".claude/processes"* ]]; then
        pass ".claude/processes/ takes precedence"
    else
        fail "Expected .claude/processes/ precedence, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 11: Falls back to claude/processes/ when .claude/ not present
test_local_fallback() {
    echo ""
    echo "Test 11: Local cleanup (claude/ fallback)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create only in legacy location
    mkdir -p claude/processes
    echo "# Legacy location" > claude/processes/local-session-cleanup.md

    # Execute
    OUTPUT=$("$SCRIPT_DIR/find_local_cleanup.sh" 2>&1)

    # Verify: Finds file in claude/processes/
    if [[ "$OUTPUT" == *"FOUND:"* ]] && [[ "$OUTPUT" == *"claude/processes"* ]]; then
        pass "claude/processes/ fallback works"
    else
        fail "Expected fallback to claude/processes/, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Run all tests
echo "========================================"
echo "session-cleanup Script Test Suite"
echo "========================================"

test_light_depth
test_standard_depth
test_thorough_depth
test_local_file_found
test_local_file_not_found
test_permissions_script
test_clean_repo
test_skill_file
# v0.5.1 tests
test_local_claude_processes
test_local_precedence
test_local_fallback

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
