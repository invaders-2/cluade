#!/bin/bash
# Detect signed inception commit - Open Integrity pattern (usage: [path] [--verify] [--json])
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
TARGET_PATH="."
VERIFY_MODE=0
JSON_OUTPUT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --verify)
            VERIFY_MODE=1
            shift
            ;;
        --json)
            JSON_OUTPUT=1
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Usage: detect-inception.sh [path] [--verify] [--json]" >&2
            exit 1
            ;;
        *)
            TARGET_PATH="$1"
            shift
            ;;
    esac
done

cd "$TARGET_PATH"

# Find the git directory (handle worktree, bare, and standard)
GIT_DIR=""

if [ -f ".git" ]; then
    # Worktree - read gitdir from .git file
    GITDIR=$(cat .git | sed 's/gitdir: //')
    GIT_DIR="$GITDIR"
elif [ -d ".git" ]; then
    # Standard repo
    GIT_DIR=".git"
elif git rev-parse --is-bare-repository 2>/dev/null | grep -q "true"; then
    # Bare repo
    GIT_DIR="."
else
    if [ "$JSON_OUTPUT" = "1" ]; then
        echo '{"error": "Not a git repository", "inception": null}'
    else
        echo "ERROR: Not a git repository" >&2
    fi
    exit 2
fi

# Find parentless commits (root commits)
# A repo can have multiple roots (e.g., from merging unrelated histories)
ROOT_COMMITS=$(git log --max-parents=0 --format="%H" 2>/dev/null || true)

if [ -z "$ROOT_COMMITS" ]; then
    if [ "$JSON_OUTPUT" = "1" ]; then
        echo '{"inception": null, "reason": "No root commits found"}'
    else
        echo "NONE"
    fi
    exit 1
fi

# Count root commits
ROOT_COUNT=$(echo "$ROOT_COMMITS" | wc -l | tr -d ' ')

# Get details of the first root commit (primary inception)
INCEPTION_HASH=$(echo "$ROOT_COMMITS" | head -1)

# Get signature status
# %G?: G=good, B=bad, U=unknown key, N=no signature, E=error
# %GK: signing key
# %GS: signer name
SIG_INFO=$(git log -1 --format="%G? %GK %GS" "$INCEPTION_HASH" 2>/dev/null || echo "E - -")
SIG_STATUS=$(echo "$SIG_INFO" | awk '{print $1}')
SIG_KEY=$(echo "$SIG_INFO" | awk '{print $2}')
SIG_SIGNER=$(echo "$SIG_INFO" | cut -d' ' -f3-)

# Get commit details
COMMIT_MSG=$(git log -1 --format="%s" "$INCEPTION_HASH" 2>/dev/null || echo "")
COMMIT_DATE=$(git log -1 --format="%ci" "$INCEPTION_HASH" 2>/dev/null || echo "")
COMMIT_AUTHOR=$(git log -1 --format="%an <%ae>" "$INCEPTION_HASH" 2>/dev/null || echo "")

# Interpret signature status
SIG_DESCRIPTION=""
IS_SIGNED=0
IS_VALID=0

case "$SIG_STATUS" in
    G)
        SIG_DESCRIPTION="Good signature"
        IS_SIGNED=1
        IS_VALID=1
        ;;
    B)
        SIG_DESCRIPTION="Bad signature"
        IS_SIGNED=1
        IS_VALID=0
        ;;
    U)
        SIG_DESCRIPTION="Unknown key (signature cannot be verified)"
        IS_SIGNED=1
        IS_VALID=0
        ;;
    X)
        SIG_DESCRIPTION="Good signature, but expired"
        IS_SIGNED=1
        IS_VALID=0
        ;;
    Y)
        SIG_DESCRIPTION="Good signature, but expired key"
        IS_SIGNED=1
        IS_VALID=0
        ;;
    R)
        SIG_DESCRIPTION="Good signature, but revoked key"
        IS_SIGNED=1
        IS_VALID=0
        ;;
    N)
        SIG_DESCRIPTION="No signature"
        IS_SIGNED=0
        IS_VALID=0
        ;;
    E|*)
        SIG_DESCRIPTION="Error checking signature"
        IS_SIGNED=0
        IS_VALID=0
        ;;
esac

# JSON output
if [ "$JSON_OUTPUT" = "1" ]; then
    # Build JSON - escape special characters in strings
    ESCAPED_MSG=$(echo "$COMMIT_MSG" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')
    ESCAPED_SIGNER=$(echo "$SIG_SIGNER" | sed 's/\\/\\\\/g; s/"/\\"/g')
    ESCAPED_AUTHOR=$(echo "$COMMIT_AUTHOR" | sed 's/\\/\\\\/g; s/"/\\"/g')

    cat <<EOF
{
  "inception": {
    "hash": "$INCEPTION_HASH",
    "short_hash": "${INCEPTION_HASH:0:7}",
    "message": "$ESCAPED_MSG",
    "date": "$COMMIT_DATE",
    "author": "$ESCAPED_AUTHOR"
  },
  "signature": {
    "status": "$SIG_STATUS",
    "description": "$SIG_DESCRIPTION",
    "is_signed": $( [ "$IS_SIGNED" = "1" ] && echo "true" || echo "false" ),
    "is_valid": $( [ "$IS_VALID" = "1" ] && echo "true" || echo "false" ),
    "key": "$SIG_KEY",
    "signer": "$ESCAPED_SIGNER"
  },
  "root_count": $ROOT_COUNT
}
EOF

    # In verify mode with JSON, also check exit code
    if [ "$VERIFY_MODE" = "1" ] && [ "$IS_VALID" != "1" ]; then
        exit 1
    fi
    exit 0
fi

# Standard output
echo "=== Inception Commit Detection ==="
echo ""

if [ "$ROOT_COUNT" -gt 1 ]; then
    echo "Note: Repository has $ROOT_COUNT root commits (merged histories)"
    echo "      Showing primary inception commit"
    echo ""
fi

echo "Hash:    $INCEPTION_HASH"
echo "Short:   ${INCEPTION_HASH:0:7}"
echo "Message: $COMMIT_MSG"
echo "Author:  $COMMIT_AUTHOR"
echo "Date:    $COMMIT_DATE"
echo ""

echo "=== Signature Status ==="
echo ""
echo "Status:      $SIG_STATUS ($SIG_DESCRIPTION)"

if [ "$IS_SIGNED" = "1" ]; then
    echo "Signed:      Yes"
    if [ -n "$SIG_KEY" ] && [ "$SIG_KEY" != "-" ]; then
        echo "Key:         $SIG_KEY"
    fi
    if [ -n "$SIG_SIGNER" ] && [ "$SIG_SIGNER" != "-" ]; then
        echo "Signer:      $SIG_SIGNER"
    fi

    if [ "$IS_VALID" = "1" ]; then
        echo ""
        echo "✓ Inception commit has valid signature"
        echo "  This establishes cryptographic root-of-trust"
    else
        echo ""
        echo "⚠ Inception commit is signed but signature is not valid"
        echo "  Possible causes:"
        echo "    - Signing key not in keyring"
        echo "    - Key expired or revoked"
        echo "    - Signature corrupted"
    fi
else
    echo "Signed:      No"
    echo ""
    echo "ℹ Inception commit exists but is not signed"
    echo "  For cryptographic root-of-trust, consider:"
    echo "    - Creating signed tags"
    echo "    - Using signed commits for future repos"
fi

# List other root commits if multiple
if [ "$ROOT_COUNT" -gt 1 ]; then
    echo ""
    echo "=== Other Root Commits ==="
    echo ""
    echo "$ROOT_COMMITS" | tail -n +2 | while read hash; do
        OTHER_MSG=$(git log -1 --format="%s" "$hash" 2>/dev/null || echo "")
        OTHER_SIG=$(git log -1 --format="%G?" "$hash" 2>/dev/null || echo "?")
        echo "  ${hash:0:7} [$OTHER_SIG] $OTHER_MSG"
    done
fi

# Verify mode check
if [ "$VERIFY_MODE" = "1" ]; then
    echo ""
    if [ "$IS_VALID" = "1" ]; then
        echo "VERIFY: PASSED - Valid signed inception commit"
        exit 0
    else
        echo "VERIFY: FAILED - No valid signature on inception commit"
        exit 1
    fi
fi

echo ""
exit 0
