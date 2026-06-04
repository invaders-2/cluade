#!/bin/bash
# test_scripts.sh - Test suite for session-resume scripts
# Part of session-resume skill
#
# Usage: ./test_scripts.sh
#
# Tests:
# 1. list_archives.sh - No archives
# 2. list_archives.sh - Multiple archives
# 3. list_archives.sh - Limit parameter
# 4. check_staleness.sh - Fresh resume (<1 day)
# 5. check_staleness.sh - Recent resume (1-6 days)
# 6. check_staleness.sh - Stale resume (7-29 days)
# 7. check_staleness.sh - Very stale resume (30+ days)
# 8. check_staleness.sh - Missing file

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
    # Create minimal CLAUDE.md (required by some scripts)
    echo "# Test Project" > CLAUDE.md
}

cleanup_test_env() {
    cd "$TEST_DIR"
    rm -rf "$TEMP_DIR"
}

# Test 1: list_archives with no archives
test_list_no_archives() {
    echo ""
    echo "Test 1: List archives (none exist)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Execute: list archives when none exist
    OUTPUT=$("$SCRIPT_DIR/list_archives.sh" 2>&1)

    # Verify: Reports no archives
    if [[ "$OUTPUT" == "No archives found" ]]; then
        pass "Correctly reports no archives"
    else
        fail "Expected 'No archives found', got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 2: list_archives with multiple archives
test_list_multiple_archives() {
    echo ""
    echo "Test 2: List archives (multiple exist)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create archive directory with 3 files
    mkdir -p archives/CLAUDE_RESUME
    echo "Archive 1" > archives/CLAUDE_RESUME/2025-10-27-1400.md
    sleep 0.1
    echo "Archive 2" > archives/CLAUDE_RESUME/2025-10-28-1000.md
    sleep 0.1
    echo "Archive 3" > archives/CLAUDE_RESUME/2025-10-29-1600.md

    # Execute: list archives
    OUTPUT=$("$SCRIPT_DIR/list_archives.sh" 2>&1)

    # Verify: Lists archives (newest first)
    if [[ "$OUTPUT" == *"2025-10-29-1600"* ]] && [[ "$OUTPUT" == *"2025-10-28-1000"* ]]; then
        pass "Lists archives correctly"
    else
        fail "Expected archive timestamps in output, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 3: list_archives with limit parameter
test_list_with_limit() {
    echo ""
    echo "Test 3: List archives (with limit)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create 5 archives
    mkdir -p archives/CLAUDE_RESUME
    for i in {1..5}; do
        echo "Archive $i" > "archives/CLAUDE_RESUME/2025-10-2$i-1000.md"
        sleep 0.05
    done

    # Execute: list with limit of 2
    OUTPUT=$("$SCRIPT_DIR/list_archives.sh" --limit 2 2>&1)
    LINE_COUNT=$(echo "$OUTPUT" | wc -l | tr -d ' ')

    # Verify: Only 2 archives listed
    if [ "$LINE_COUNT" -eq 2 ]; then
        pass "Limit parameter works correctly"
    else
        fail "Expected 2 lines, got: $LINE_COUNT"
    fi

    cleanup_test_env
}

# Test 4: check_staleness - Fresh resume
test_staleness_fresh() {
    echo ""
    echo "Test 4: Check staleness (fresh resume)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create resume with today's date (guaranteed fresh)
    TODAY_DATE=$(date "+%B %d, %Y" | sed 's/  / /g')  # "December 04, 2025" format
    cat > CLAUDE_RESUME.md <<EOF
# Claude Resume - Test Project

**Last Session**: $TODAY_DATE

## Last Activity Completed
Testing.

## Pending Tasks
- [ ] Test

## Next Session Focus
Continue.

*Resume created by session-closure v1.4.0*
EOF

    # Execute: check staleness (pass current directory as PROJECT_ROOT)
    OUTPUT=$("$SCRIPT_DIR/check_staleness.sh" . 2>&1)

    # Verify: Reports fresh
    if [[ "$OUTPUT" == "fresh" ]]; then
        pass "Fresh resume detected correctly"
    else
        fail "Expected 'fresh', got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 5: check_staleness - Stale resume
test_staleness_stale() {
    echo ""
    echo "Test 5: Check staleness (stale resume)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Use stale resume fixture (October 15, 2025)
    cp "$FIXTURE_DIR/stale_resume.md" CLAUDE_RESUME.md

    # Execute: check staleness (pass current directory as PROJECT_ROOT)
    OUTPUT=$("$SCRIPT_DIR/check_staleness.sh" . 2>&1)

    # Verify: Reports stale or very_stale (depending on current date)
    if [[ "$OUTPUT" == "stale" ]] || [[ "$OUTPUT" == "very_stale" ]]; then
        pass "Stale resume detected correctly"
    else
        fail "Expected 'stale' or 'very_stale', got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 6: check_staleness - Missing file
test_staleness_missing() {
    echo ""
    echo "Test 6: Check staleness (missing file)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Don't create CLAUDE_RESUME.md - test missing resume handling
    # Note: CLAUDE.md exists from setup_test_env

    # Execute: check staleness on directory with no resume (allow error exit code)
    set +e  # Temporarily disable exit on error
    OUTPUT=$("$SCRIPT_DIR/check_staleness.sh" . 2>&1)
    set -e  # Re-enable exit on error

    # Verify: Reports error
    if [[ "$OUTPUT" == "error" ]]; then
        pass "Missing resume handled correctly"
    else
        fail "Expected 'error', got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 7: list_archives - Detailed format
test_list_detailed_format() {
    echo ""
    echo "Test 7: List archives (detailed format)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create archives
    mkdir -p archives/CLAUDE_RESUME
    echo "Archive 1" > archives/CLAUDE_RESUME/2025-10-27-1400.md

    # Execute: list with detailed format
    OUTPUT=$("$SCRIPT_DIR/list_archives.sh" --format detailed 2>&1)

    # Verify: Shows count and details
    if [[ "$OUTPUT" == *"Found"* ]] && [[ "$OUTPUT" == *"archived session"* ]]; then
        pass "Detailed format works correctly"
    else
        fail "Expected detailed format output, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 8: list_archives - Empty directory (created but no files)
test_list_empty_directory() {
    echo ""
    echo "Test 8: List archives (empty directory)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create empty archive directory
    mkdir -p archives/CLAUDE_RESUME

    # Execute: list archives
    OUTPUT=$("$SCRIPT_DIR/list_archives.sh" 2>&1)

    # Verify: Reports no archives
    if [[ "$OUTPUT" == "No archives found" ]]; then
        pass "Empty directory handled correctly"
    else
        fail "Expected 'No archives found', got: $OUTPUT"
    fi

    cleanup_test_env
}

# ============================================
# v0.5.1 Tests: Dual Location Support
# ============================================

# Test 9: check_staleness - .claude/ location
test_staleness_claude_dir() {
    echo ""
    echo "Test 9: Check staleness (.claude/ location)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create resume in .claude/ directory
    mkdir -p .claude
    TODAY_DATE=$(date "+%B %d, %Y" | sed 's/  / /g')
    cat > .claude/CLAUDE_RESUME.md <<EOF
# Claude Resume - Test Project

**Last Session**: $TODAY_DATE

## Last Activity Completed
Testing .claude/ location.

## Pending Tasks
- [ ] Test

## Next Session Focus
Continue.

*Resume created by session-closure v0.5.1*
EOF

    # Execute: check staleness
    OUTPUT=$("$SCRIPT_DIR/check_staleness.sh" . 2>&1)

    # Verify: Reports fresh (found the file)
    if [[ "$OUTPUT" == "fresh" ]]; then
        pass ".claude/ location detected correctly"
    else
        fail "Expected 'fresh' from .claude/ location, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 10: check_staleness - .claude/ takes precedence over root
test_staleness_precedence() {
    echo ""
    echo "Test 10: Check staleness (.claude/ precedence)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create resume in BOTH locations
    # Root: stale date
    cp "$FIXTURE_DIR/stale_resume.md" CLAUDE_RESUME.md

    # .claude/: fresh date (should take precedence)
    mkdir -p .claude
    TODAY_DATE=$(date "+%B %d, %Y" | sed 's/  / /g')
    cat > .claude/CLAUDE_RESUME.md <<EOF
# Claude Resume - Test Project

**Last Session**: $TODAY_DATE

## Last Activity Completed
Fresh resume in .claude/.

## Pending Tasks
- [ ] Test

## Next Session Focus
Continue.

*Resume created by session-closure v0.5.1*
EOF

    # Execute: check staleness
    OUTPUT=$("$SCRIPT_DIR/check_staleness.sh" . 2>&1)

    # Verify: Reports fresh (from .claude/, not stale from root)
    if [[ "$OUTPUT" == "fresh" ]]; then
        pass ".claude/ location takes precedence"
    else
        fail "Expected 'fresh' (.claude/ precedence), got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 11: list_archives - .claude/archives/ location
test_list_archives_claude_dir() {
    echo ""
    echo "Test 11: List archives (.claude/archives/ location)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create archive in .claude/archives/
    mkdir -p .claude/archives/CLAUDE_RESUME
    echo "Archive in .claude/" > .claude/archives/CLAUDE_RESUME/2025-11-15-1400.md

    # Execute: list archives
    OUTPUT=$("$SCRIPT_DIR/list_archives.sh" 2>&1)

    # Verify: Finds archive in .claude/ location
    if [[ "$OUTPUT" == *"2025-11-15-1400"* ]]; then
        pass ".claude/archives/ location detected"
    else
        fail "Expected archive from .claude/archives/, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 12: list_archives - Both locations (should find from both)
test_list_archives_both_locations() {
    echo ""
    echo "Test 12: List archives (both locations)"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Setup: Create archives in BOTH locations
    mkdir -p archives/CLAUDE_RESUME
    echo "Archive in root" > archives/CLAUDE_RESUME/2025-10-01-1000.md

    mkdir -p .claude/archives/CLAUDE_RESUME
    echo "Archive in .claude/" > .claude/archives/CLAUDE_RESUME/2025-11-01-1000.md

    # Execute: list archives
    OUTPUT=$("$SCRIPT_DIR/list_archives.sh" 2>&1)

    # Verify: Finds archives from both locations
    if [[ "$OUTPUT" == *"2025-10-01"* ]] && [[ "$OUTPUT" == *"2025-11-01"* ]]; then
        pass "Both archive locations detected"
    else
        fail "Expected archives from both locations, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Run all tests
echo "========================================"
echo "session-resume Script Test Suite"
echo "========================================"

test_list_no_archives
test_list_multiple_archives
test_list_with_limit
test_staleness_fresh
test_staleness_stale
test_staleness_missing
test_list_detailed_format
test_list_empty_directory
# v0.5.1 tests
test_staleness_claude_dir
test_staleness_precedence
test_list_archives_claude_dir
test_list_archives_both_locations

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
