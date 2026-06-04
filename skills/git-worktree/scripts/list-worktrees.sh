#!/bin/bash
# Show all worktrees with status (usage: [path] [--json|--porcelain])
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
TARGET_PATH="."
OUTPUT_FORMAT="human"

for arg in "$@"; do
    case "$arg" in
        --json)
            OUTPUT_FORMAT="json"
            ;;
        --porcelain)
            OUTPUT_FORMAT="porcelain"
            ;;
        -*)
            echo "Unknown option: $arg" >&2
            echo "Usage: list-worktrees.sh [path] [--json|--porcelain]" >&2
            exit 1
            ;;
        *)
            TARGET_PATH="$arg"
            ;;
    esac
done

# Resolve to absolute path
TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"
cd "$TARGET_PATH"

# Detect repository type and find bare repo
if [ ! -x "$SCRIPT_DIR/detect-repo-type.sh" ]; then
    echo "ERROR: detect-repo-type.sh not found" >&2
    exit 2
fi

REPO_TYPE=$("$SCRIPT_DIR/detect-repo-type.sh" "." 2>/dev/null || echo "NONE")

BARE_REPO=""
CURRENT_WORKTREE=""

case "$REPO_TYPE" in
    WORKTREE)
        # We're in a worktree - find the bare repo
        GITDIR=$(cat .git | sed 's/gitdir: //')
        # GITDIR points to bare_repo/worktrees/{name}
        BARE_REPO=$(dirname "$(dirname "$GITDIR")")
        CURRENT_WORKTREE="$TARGET_PATH"
        ;;
    BARE)
        # We're in a bare repo
        BARE_REPO="$TARGET_PATH"
        ;;
    STANDARD)
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            echo '{"error": "Not a worktree-form repository", "type": "standard"}'
        else
            echo "ERROR: Not a worktree-form repository"
            echo ""
            echo "This is a standard git repository."
            echo "Convert first with: convert-to-worktree.sh"
        fi
        exit 1
        ;;
    *)
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            echo '{"error": "Not a git repository"}'
        else
            echo "ERROR: Not a git repository" >&2
        fi
        exit 1
        ;;
esac

# Verify bare repo
if [ ! -d "$BARE_REPO" ] || [ ! -f "$BARE_REPO/HEAD" ]; then
    echo "ERROR: Cannot find valid bare repository at: $BARE_REPO" >&2
    exit 2
fi

# Get repo name and owner from path
REPO_NAME=$(basename "$BARE_REPO" .git)
OWNER=$(basename "$(dirname "$(dirname "$BARE_REPO")")")

# Get worktree list in porcelain format for parsing
WORKTREE_DATA=$(git -C "$BARE_REPO" worktree list --porcelain)

# Parse worktree data
declare -a WORKTREES
declare -a BRANCHES
declare -a COMMITS
declare -a STATES

CURRENT_WT=""
CURRENT_BR=""
CURRENT_COMMIT=""
CURRENT_STATE=""

while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == worktree\ * ]]; then
        # Save previous worktree if exists
        if [ -n "$CURRENT_WT" ]; then
            WORKTREES+=("$CURRENT_WT")
            BRANCHES+=("$CURRENT_BR")
            COMMITS+=("$CURRENT_COMMIT")
            STATES+=("$CURRENT_STATE")
        fi
        CURRENT_WT="${line#worktree }"
        CURRENT_BR=""
        CURRENT_COMMIT=""
        CURRENT_STATE="ok"
    elif [[ "$line" == HEAD\ * ]]; then
        CURRENT_COMMIT="${line#HEAD }"
    elif [[ "$line" == branch\ * ]]; then
        CURRENT_BR="${line#branch refs/heads/}"
    elif [[ "$line" == detached ]]; then
        CURRENT_BR="(detached)"
    elif [[ "$line" == prunable ]]; then
        CURRENT_STATE="stale"
    elif [[ "$line" == locked ]]; then
        CURRENT_STATE="locked"
    fi
done <<< "$WORKTREE_DATA"

# Save last worktree
if [ -n "$CURRENT_WT" ]; then
    WORKTREES+=("$CURRENT_WT")
    BRANCHES+=("$CURRENT_BR")
    COMMITS+=("$CURRENT_COMMIT")
    STATES+=("$CURRENT_STATE")
fi

# Output based on format
case "$OUTPUT_FORMAT" in
    json)
        echo "{"
        echo "  \"repo\": \"$REPO_NAME\","
        echo "  \"owner\": \"$OWNER\","
        echo "  \"bare_repo\": \"$BARE_REPO\","
        echo "  \"current\": \"$CURRENT_WORKTREE\","
        echo "  \"worktrees\": ["

        for i in "${!WORKTREES[@]}"; do
            WT="${WORKTREES[$i]}"
            BR="${BRANCHES[$i]}"
            COMMIT="${COMMITS[$i]}"
            STATE="${STATES[$i]}"

            IS_CURRENT="false"
            IS_BARE="false"

            if [ "$WT" = "$CURRENT_WORKTREE" ]; then
                IS_CURRENT="true"
            fi

            # Check if this is the bare repo entry
            if [ "$WT" = "$BARE_REPO" ]; then
                IS_BARE="true"
            fi

            # Get directory name
            DIR_NAME=$(basename "$WT")

            echo "    {"
            echo "      \"path\": \"$WT\","
            echo "      \"directory\": \"$DIR_NAME\","
            echo "      \"branch\": \"$BR\","
            echo "      \"commit\": \"$COMMIT\","
            echo "      \"state\": \"$STATE\","
            echo "      \"is_current\": $IS_CURRENT,"
            echo "      \"is_bare\": $IS_BARE"

            if [ $i -lt $((${#WORKTREES[@]} - 1)) ]; then
                echo "    },"
            else
                echo "    }"
            fi
        done

        echo "  ],"
        echo "  \"count\": ${#WORKTREES[@]}"
        echo "}"
        ;;

    porcelain)
        for i in "${!WORKTREES[@]}"; do
            WT="${WORKTREES[$i]}"
            BR="${BRANCHES[$i]}"
            STATE="${STATES[$i]}"

            MARKER=" "
            if [ "$WT" = "$CURRENT_WORKTREE" ]; then
                MARKER="*"
            fi

            if [ "$WT" = "$BARE_REPO" ]; then
                echo "$MARKER	(bare)	$WT"
            else
                echo "$MARKER	$BR	$WT	$STATE"
            fi
        done
        ;;

    human|*)
        echo "📁 $REPO_NAME ($OWNER)"
        echo ""
        echo "Bare repo: $BARE_REPO"
        echo ""
        echo "Worktrees:"

        # Calculate max branch length for alignment
        MAX_BR_LEN=0
        for BR in "${BRANCHES[@]}"; do
            if [ ${#BR} -gt $MAX_BR_LEN ]; then
                MAX_BR_LEN=${#BR}
            fi
        done
        # Minimum padding
        [ $MAX_BR_LEN -lt 15 ] && MAX_BR_LEN=15

        WORKTREE_COUNT=0
        STALE_COUNT=0

        for i in "${!WORKTREES[@]}"; do
            WT="${WORKTREES[$i]}"
            BR="${BRANCHES[$i]}"
            STATE="${STATES[$i]}"

            # Skip bare repo entry
            if [ "$WT" = "$BARE_REPO" ]; then
                continue
            fi

            WORKTREE_COUNT=$((WORKTREE_COUNT + 1))

            # Current marker
            if [ "$WT" = "$CURRENT_WORKTREE" ]; then
                MARKER="→"
            else
                MARKER=" "
            fi

            # Directory name
            DIR_NAME=$(basename "$WT")/

            # State indicator
            STATE_IND=""
            case "$STATE" in
                stale)
                    STATE_IND=" (stale ⚠️)"
                    STALE_COUNT=$((STALE_COUNT + 1))
                    ;;
                locked)
                    STATE_IND=" (locked 🔒)"
                    ;;
            esac

            # Format: → branch          directory/        (state)
            printf "%s %-${MAX_BR_LEN}s  %-20s%s\n" "$MARKER" "$BR" "$DIR_NAME" "$STATE_IND"
        done

        echo ""
        echo "$WORKTREE_COUNT worktree(s) total"

        if [ $STALE_COUNT -gt 0 ]; then
            echo ""
            echo "⚠️  $STALE_COUNT stale worktree(s) found"
            echo "   Run: git -C \"$BARE_REPO\" worktree prune"
        fi
        ;;
esac
