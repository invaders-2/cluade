#!/bin/bash
# test_sync.sh - Verify duplicated files remain synchronized
# Part of session-resume skill
#
# Usage: ./test_sync.sh
#
# Verifies that files duplicated between session-closure and session-resume
# remain byte-for-byte identical to prevent drift.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths to duplicated files
CLOSURE_BASE="$HOME/.claude/skills/session-closure"
RESUME_BASE="$HOME/.claude/skills/session-resume"

DUPLICATED_FILES=(
    "scripts/check_uncommitted_changes.sh"
    "scripts/check_permissions.sh"
    "references/RESUME_FORMAT_v1.2.md"
)

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

echo "========================================"
echo "Session Skills Sync Verification"
echo "========================================"
echo ""

for file in "${DUPLICATED_FILES[@]}"; do
    TESTS_RUN=$((TESTS_RUN + 1))

    CLOSURE_FILE="$CLOSURE_BASE/$file"
    RESUME_FILE="$RESUME_BASE/$file"

    echo -n "Checking $file... "

    # Check if both files exist
    if [ ! -f "$CLOSURE_FILE" ]; then
        echo -e "${RED}✗${NC} Missing in session-closure"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        continue
    fi

    if [ ! -f "$RESUME_FILE" ]; then
        echo -e "${RED}✗${NC} Missing in session-resume"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        continue
    fi

    # Compare files
    if diff -q "$CLOSURE_FILE" "$RESUME_FILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Synchronized"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Files differ!"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo ""
        echo "  Differences:"
        diff "$CLOSURE_FILE" "$RESUME_FILE" | head -20
        echo ""
    fi
done

echo ""
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
echo "========================================"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All duplicated files are synchronized!${NC}"
    exit 0
else
    echo -e "${RED}$TESTS_FAILED file(s) out of sync!${NC}"
    echo ""
    echo "To fix:"
    echo "1. Review changes in both files"
    echo "2. Decide which version is correct"
    echo "3. Copy correct version to replace the other"
    echo "4. Re-run this test to verify"
    exit 1
fi
