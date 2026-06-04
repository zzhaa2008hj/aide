#!/usr/bin/env bash
set -euo pipefail

# sync-superpowers.sh — Merge upstream Superpowers skill updates into AIDE.
#
# Usage: ./aide-core/scripts/sync-superpowers.sh <tag-or-commit>
#
# Compares the baseline commit (SUPERSPOWERS_VERSION) against the target,
# then auto-routes each changed skill:
#   NEW        — auto-copy
#   UNCHANGED  — auto-overwrite
#   MODIFIED   — interactive [o/d/m/s]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
VERSION_FILE="$REPO_ROOT/SUPERSPOWERS_VERSION"
PENDING_FILE="$REPO_ROOT/SUPERSPOWERS_PENDING"
UPSTREAM_URL="https://github.com/obra/superpowers"
TMP_DIR="${TMPDIR:-/tmp}/superpowers-sync-$$"

# ---- helpers ----

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "  $*"; }

cleanup() {
    rm -rf "$TMP_DIR"
}

# Extract a skill's files from upstream into a temp directory
extract_skill() {
    local commit="$1" skill="$2" dest="$3"
    mkdir -p "$dest"
    git -C "$TMP_DIR" ls-tree -r --name-only "$commit:skills/$skill" 2>/dev/null | while read -r f; do
        mkdir -p "$(dirname "$dest/$f")"
        git -C "$TMP_DIR" show "$commit:skills/$skill/$f" > "$dest/$f" 2>/dev/null || true
    done
}

# Copy a skill from upstream into AIDE's skills directory
copy_skill_from_upstream() {
    local commit="$1" skill="$2"
    rm -rf "$SKILLS_DIR/$skill"
    mkdir -p "$SKILLS_DIR/$skill"
    git -C "$TMP_DIR" ls-tree -r --name-only "$commit:skills/$skill" 2>/dev/null | while read -r f; do
        mkdir -p "$(dirname "$SKILLS_DIR/$skill/$f")"
        git -C "$TMP_DIR" show "$commit:skills/$skill/$f" > "$SKILLS_DIR/$skill/$f" 2>/dev/null || true
    done
}

# ---- argument parsing ----

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <tag-or-commit>"
    echo "Example: $0 v5.2.0"
    exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
    die "SUPERSPOWERS_VERSION not found at $VERSION_FILE"
fi

BASELINE=$(tr -d '\n' < "$VERSION_FILE")
if [ -z "$BASELINE" ]; then
    die "SUPERSPOWERS_VERSION is empty"
fi

# ---- clone upstream ----

info "Cloning upstream superpowers..."
trap cleanup EXIT
git clone --depth 50 "$UPSTREAM_URL" "$TMP_DIR" 2>&1 | sed 's/^/    /'

# Resolve target to a commit SHA
TARGET_SHA=$(git -C "$TMP_DIR" rev-list -n1 "$TARGET" 2>/dev/null) || die "Cannot resolve '$TARGET' to a commit"

# Verify baseline exists in the clone
git -C "$TMP_DIR" cat-file -e "$BASELINE" 2>/dev/null || die "Baseline commit $BASELINE not found in upstream (shallow clone too shallow?)"

info "Baseline: ${BASELINE:0:7} → Target: ${TARGET_SHA:0:7}"

# ---- discover changed skills ----

UPSTREAM_SKILLS=$(git -C "$TMP_DIR" ls-tree --name-only "$TARGET_SHA":skills/ 2>/dev/null || true)
BASELINE_SKILLS=$(git -C "$TMP_DIR" ls-tree --name-only "$BASELINE":skills/ 2>/dev/null || true)

declare -a NEW=()
declare -a UNCHANGED=()
declare -a MODIFIED=()

for skill in $UPSTREAM_SKILLS; do
    if ! echo "$BASELINE_SKILLS" | grep -qxF "$skill"; then
        NEW+=("$skill")
    else
        BASELINE_DIR="$TMP_DIR/baseline-$skill"
        extract_skill "$BASELINE" "$skill" "$BASELINE_DIR"
        if diff -rq "$SKILLS_DIR/$skill" "$BASELINE_DIR" >/dev/null 2>&1; then
            UNCHANGED+=("$skill")
        else
            MODIFIED+=("$skill")
        fi
    fi
done

# ---- check for deleted upstream skills ----

declare -a DELETED=()
for skill in $BASELINE_SKILLS; do
    if [ -d "$SKILLS_DIR/$skill" ] && ! echo "$UPSTREAM_SKILLS" | grep -qxF "$skill"; then
        DELETED+=("$skill")
    fi
done

if [ ${#DELETED[@]} -gt 0 ]; then
    echo ""
    echo "--- Deleted upstream ---"
    for skill in "${DELETED[@]}"; do
        echo "[warn]  $skill — deleted from upstream, still in AIDE. Review manually."
    done
fi

# ---- auto-copy unchanged skills ----

if [ ${#NEW[@]} -gt 0 ] || [ ${#UNCHANGED[@]} -gt 0 ]; then
    echo ""
    echo "--- Auto-apply ---"
fi

for skill in "${NEW[@]}"; do
    echo "[new]  $skill — copying from upstream"
    copy_skill_from_upstream "$TARGET_SHA" "$skill"
done

for skill in "${UNCHANGED[@]}"; do
    echo "[auto] $skill — unchanged, overwriting"
    copy_skill_from_upstream "$TARGET_SHA" "$skill"
done

# ---- interactive modified skills ----

if [ ${#MODIFIED[@]} -gt 0 ]; then
    echo ""
    echo "--- Interactive (AIDE modified since baseline) ---"

    for skill in "${MODIFIED[@]}"; do
        echo ""
        echo "[mod]  $skill — AIDE modified since baseline"
        while true; do
            read -r -p "       [o]verwrite / [d]iff / [m]erge / [s]kip? " choice
            case "$choice" in
                o|O)
                    copy_skill_from_upstream "$TARGET_SHA" "$skill"
                    echo "       Overwritten with upstream version."
                    break
                    ;;
                d|D)
                    echo "--- diff for $skill (AIDE vs upstream target) ---"
                    DIFF_DIR="$TMP_DIR/diff-$skill"
                    extract_skill "$TARGET_SHA" "$skill" "$DIFF_DIR"
                    diff -ruN "$SKILLS_DIR/$skill" "$DIFF_DIR" || true
                    echo "--- end diff ---"
                    ;;
                m|M)
                    MERGE_DIR="$REPO_ROOT/.tmp/superpowers-merge/$skill"
                    mkdir -p "$MERGE_DIR"
                    git -C "$TMP_DIR" ls-tree -r --name-only "$TARGET_SHA:skills/$skill" | while read -r f; do
                        mkdir -p "$(dirname "$MERGE_DIR/$f")"
                        git -C "$TMP_DIR" show "$TARGET_SHA:skills/$skill/$f" > "$MERGE_DIR/$f"
                    done
                    echo "       Upstream copied to $MERGE_DIR"
                    echo "       AIDE version at: $SKILLS_DIR/$skill"
                    echo "       Manually merge, then press Enter to continue."
                    read -r
                    break
                    ;;
                s|S)
                    echo "       Skipped."
                    echo "$skill: $TARGET_SHA ($TARGET) — skipped $(date +%Y-%m-%d)" >> "$PENDING_FILE"
                    break
                    ;;
                *)
                    echo "       Invalid choice. Enter o, d, m, or s."
                    ;;
            esac
        done
    done
fi

# ---- update version ----

echo ""
echo "$TARGET_SHA" > "$VERSION_FILE"
info "Updated SUPERSPOWERS_VERSION: ${BASELINE:0:7} → ${TARGET_SHA:0:7}"

if [ -f "$PENDING_FILE" ]; then
    info "Pending manual review (see SUPERSPOWERS_PENDING):"
    sed 's/^/    /' "$PENDING_FILE"
fi

echo ""
info "Review the changes, then commit:"
info "  git add skills/ SUPERSPOWERS_VERSION"
info "  git commit -m \"chore: sync superpowers skills to $TARGET\""
