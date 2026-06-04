#!/bin/bash
# Test suite for git-worktree scripts
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$TEST_DIR/tmp"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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

# Test 1: detect-repo-type on standard repo
test_detect_standard() {
    echo ""
    echo "Test 1: detect-repo-type on standard repository"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env
    git init -q test-repo
    cd test-repo

    OUTPUT=$("$SCRIPT_DIR/detect-repo-type.sh" 2>&1)

    if [[ "$OUTPUT" == "STANDARD" ]]; then
        pass "Correctly detected STANDARD repository"
    else
        fail "Expected STANDARD, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 2: detect-repo-type on worktree
test_detect_worktree() {
    echo ""
    echo "Test 2: detect-repo-type on worktree"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    # Create bare repo and worktree
    git clone --bare https://github.com/octocat/Hello-World.git test.git 2>/dev/null || {
        # Fallback: create local bare repo
        git init -q source-repo
        cd source-repo
        git commit --allow-empty -q -m "Initial"
        cd ..
        git clone --bare source-repo test.git
    }
    git -C test.git worktree add ../main main 2>/dev/null || git -C test.git worktree add ../main master 2>/dev/null || git -C test.git worktree add ../main HEAD

    cd main
    OUTPUT=$("$SCRIPT_DIR/detect-repo-type.sh" 2>&1)

    if [[ "$OUTPUT" == "WORKTREE" ]]; then
        pass "Correctly detected WORKTREE"
    else
        fail "Expected WORKTREE, got: $OUTPUT"
    fi

    cleanup_test_env
}

# Test 3: detect-repo-type on non-repo
test_detect_non_repo() {
    echo ""
    echo "Test 3: detect-repo-type on non-repository"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env

    set +e
    "$SCRIPT_DIR/detect-repo-type.sh" >/dev/null 2>&1
    EXIT_CODE=$?
    set -e

    if [ $EXIT_CODE -eq 1 ]; then
        pass "Correctly returned exit code 1 for non-repo"
    else
        fail "Expected exit code 1, got: $EXIT_CODE"
    fi

    cleanup_test_env
}

# Test 4: extract-owner parses GitHub URL
test_extract_owner() {
    echo ""
    echo "Test 4: extract-owner parses GitHub remote"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env
    git init -q test-repo
    cd test-repo
    git remote add origin https://github.com/TestOwner/TestRepo.git

    OUTPUT=$("$SCRIPT_DIR/extract-owner.sh" 2>&1)
    OWNER=$(echo "$OUTPUT" | head -1)
    REPO=$(echo "$OUTPUT" | tail -1)

    if [[ "$OWNER" == "TestOwner" ]] && [[ "$REPO" == "TestRepo" ]]; then
        pass "Correctly extracted owner and repo"
    else
        fail "Expected TestOwner/TestRepo, got: $OWNER/$REPO"
    fi

    cleanup_test_env
}

# Test 5: extract-owner fails without remote
test_extract_no_remote() {
    echo ""
    echo "Test 5: extract-owner fails without remote"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env
    git init -q test-repo
    cd test-repo

    set +e
    "$SCRIPT_DIR/extract-owner.sh" >/dev/null 2>&1
    EXIT_CODE=$?
    set -e

    if [ $EXIT_CODE -eq 1 ]; then
        pass "Correctly failed without remote"
    else
        fail "Expected exit code 1, got: $EXIT_CODE"
    fi

    cleanup_test_env
}

# Test 6: validate-setup on non-worktree
test_validate_non_worktree() {
    echo ""
    echo "Test 6: validate-setup on non-worktree repository"
    TESTS_RUN=$((TESTS_RUN + 1))

    setup_test_env
    git init -q test-repo
    cd test-repo

    set +e
    "$SCRIPT_DIR/validate-setup.sh" >/dev/null 2>&1
    EXIT_CODE=$?
    set -e

    if [ $EXIT_CODE -eq 2 ]; then
        pass "Correctly returned exit code 2 for non-worktree"
    else
        fail "Expected exit code 2, got: $EXIT_CODE"
    fi

    cleanup_test_env
}

# Run all tests
echo "========================================"
echo "git-worktree Script Test Suite"
echo "========================================"

test_detect_standard
test_detect_worktree
test_detect_non_repo
test_extract_owner
test_extract_no_remote
test_validate_non_worktree

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

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0
