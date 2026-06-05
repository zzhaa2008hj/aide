#!/usr/bin/env bash
set -euo pipefail
# install-deepcode-cli.sh — Install AIDE skills into a deepcode-cli project.
#
# deepcode-cli discovers skills from .agents/skills/<name>/SKILL.md
# This script copies AIDE skills from the repo into the project.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/aide_deepcode/install-deepcode-cli.sh | bash
#   or
#   bash aide_deepcode/install-deepcode-cli.sh
#   or
#   AIDE_REPO=https://github.com/zzhaa2008hj/aide.git bash aide_deepcode/install-deepcode-cli.sh

AIDE_REPO="${AIDE_REPO:-https://github.com/zzhaa2008hj/aide.git}"
AIDE_REF="${AIDE_REF:-master}"
SKILLS_DIR="${SKILLS_DIR:-.agents/skills}"

echo "=== AIDE Install for deepcode-cli ==="
echo "  Repo: $AIDE_REPO"
echo "  Dest: $SKILLS_DIR"
echo ""

# Step 1: Verify deepcode-cli
if [ ! -f "package.json" ]; then
    echo "[warn]  No package.json found — are you in a project root?"
fi

if [ -f "$SKILLS_DIR/aide/SKILL.md" ]; then
    echo "[warn]  AIDE skills already exist in $SKILLS_DIR"
    echo "        Remove first: rm -rf $SKILLS_DIR/aide*"
    echo "        Then re-run this script."
    exit 0
fi

# Step 2: Fetch AIDE skills via sparse checkout
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "[info]  Fetching skills/ from $AIDE_REPO ($AIDE_REF)..."

cd "$TMP_DIR"
git init -q
git remote add origin "$AIDE_REPO" 2>/dev/null || git remote set-url origin "$AIDE_REPO"
git sparse-checkout init --cone >/dev/null 2>&1
git sparse-checkout set skills >/dev/null 2>&1
git fetch origin "$AIDE_REF" --depth 1 -q 2>/dev/null || git fetch origin "$AIDE_REF" --depth 1
git checkout FETCH_HEAD >/dev/null 2>&1

# Step 3: Copy AIDE skills to project
cd - > /dev/null
mkdir -p "$SKILLS_DIR"

# Source→Destination: Claude Code skill → deepcode-cli install name
# aide → aide-deepcode (different orchestrator for deepcode-cli)
# aide-spec → aide-spec (shared, same logic)
AIDE_SKILLS=(
    "aide-deepcode:aide"
    "aide-spec:aide-spec"
    "aide-plan:aide-plan"
    "aide-test:aide-test"
    "aide-continue:aide-continue"
    "aide-init:aide-init"
)

COPIED=0
for pair in "${AIDE_SKILLS[@]}"; do
    src_name="${pair%%:*}"
    dst_name="${pair#*:}"
    src="$TMP_DIR/skills/$src_name"
    dst="$SKILLS_DIR/$dst_name"

    if [ -f "$src/SKILL.md" ]; then
        mkdir -p "$dst"
        cp "$src/SKILL.md" "$dst/SKILL.md"
        echo "  [done]  $dst_name"
        COPIED=$((COPIED + 1))
    else
        echo "  [skip]  $src_name (no SKILL.md)"
    fi
done

# Step 4: Also copy shared schemas
mkdir -p .aide/schemas
SCHEMAS_DIR="$TMP_DIR/aide-core/schemas"
if [ -d "$SCHEMAS_DIR" ]; then
    cp "$SCHEMAS_DIR"/*.json .aide/schemas/ 2>/dev/null || true
    echo ""
    echo "  Schemas copied to .aide/schemas/"
fi

echo ""
echo "=== Installation complete ==="
echo "$COPIED AIDE skills installed to $SKILLS_DIR/"
echo ""
echo "Available in deepcode-cli:"
echo "  /aide-deepcode \"<desc>\"  — start the full pipeline"
echo "  /aide-continue            — resume interrupted pipeline"
echo "  /aide-init                — bootstrap .aide/ configuration"
echo ""
echo "Skills installed:"
ls -1 "$SKILLS_DIR"/aide*/SKILL.md 2>/dev/null | while read f; do
    name=$(basename "$(dirname "$f")")
    echo "  $name"
done
