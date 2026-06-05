#!/usr/bin/env bash
set -euo pipefail
# install-deepcode-cli.sh — Install AIDE skills for deepcode-cli.
#
# deepcode-cli discovers skills from .agents/skills/<name>/SKILL.md
# Only deepcode-cli compatible skills are installed.
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

# Step 1: Clean up any previous AIDE install
if [ -d "$SKILLS_DIR" ]; then
    for old in aide aide-deepcode aide-spec aide-plan aide-test aide-continue aide-init aide-update; do
        if [ -d "$SKILLS_DIR/$old" ]; then
            echo "[clean] Removing $SKILLS_DIR/$old"
            rm -rf "$SKILLS_DIR/$old"
        fi
    done
fi

# Step 2: Fetch AIDE skills via sparse checkout
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "[info] Fetching skills/ from $AIDE_REPO ($AIDE_REF)..."

cd "$TMP_DIR"
git init -q
git remote add origin "$AIDE_REPO" 2>/dev/null || git remote set-url origin "$AIDE_REPO"
git sparse-checkout init --cone >/dev/null 2>&1
git sparse-checkout set skills aide-core/schemas .claude-plugin/plugin.json >/dev/null 2>&1
git fetch origin "$AIDE_REF" --depth 1 -q 2>/dev/null || git fetch origin "$AIDE_REF" --depth 1
git checkout FETCH_HEAD >/dev/null 2>&1
cd - > /dev/null 2>&1 || true

	if [ ! -d "$TMP_DIR/skills" ]; then
	    echo "[error] Installation failed — skills/ directory not found in repo."
	    echo "        The repository structure may have changed."
	    exit 1
	fi

# Step 3: Install only deepcode-cli compatible skills
mkdir -p "$SKILLS_DIR"

# Mapping: source_skill → dest_name
# aide-deepcode replaces aide (different orchestrator for deepcode-cli)
# Other stage skills are shared
# aide-update is Claude Code specific — excluded
declare -A SKILL_MAP=(
    ["aide-deepcode"]="aide"
    ["aide-spec"]="aide-spec"
    ["aide-plan"]="aide-plan"
    ["aide-test"]="aide-test"
    ["aide-continue"]="aide-continue"
    ["aide-init"]="aide-init"
)

COPIED=0
for src_name in "${!SKILL_MAP[@]}"; do
    dst_name="${SKILL_MAP[$src_name]}"
    src="$TMP_DIR/skills/$src_name/SKILL.md"
    dst_dir="$SKILLS_DIR/$dst_name"

    if [ -f "$src" ]; then
        mkdir -p "$dst_dir"
        cp "$src" "$dst_dir/SKILL.md"
        echo "  [done]  $dst_name (from $src_name)"
        COPIED=$((COPIED + 1))
    else
        echo "  [skip]  $src_name (not found in repo)"
    fi
done

# Step 4: Copy shared schemas
SCHEMAS_DST=".aide/schemas"
mkdir -p "$SCHEMAS_DST"
SCHEMAS_SRC="$TMP_DIR/aide-core/schemas"
if [ -d "$SCHEMAS_SRC" ]; then
    for schema in "$SCHEMAS_SRC"/*.json; do
        if [ -f "$schema" ]; then
            cp "$schema" "$SCHEMAS_DST/"
        fi
    done
    echo ""
    echo "  Schemas: $(ls "$SCHEMAS_DST"/*.json 2>/dev/null | wc -l) copied to $SCHEMAS_DST"
fi

# Step 4b: Record installed version from plugin.json
VERSION=$(python3 -c "
import json
data = json.load(open('$TMP_DIR/.claude-plugin/plugin.json'))
print(data['version'])
" 2>/dev/null || echo "unknown")
echo "$VERSION" > .aide/version
echo ""
echo "  Version: $VERSION written to .aide/version"

echo ""
echo "=== Installation complete ==="
echo "$COPIED skills installed:"
for dst_name in "${SKILL_MAP[@]}"; do
    if [ -f "$SKILLS_DIR/$dst_name/SKILL.md" ]; then
        desc=$(python3 -c "
text = open('$SKILLS_DIR/$dst_name/SKILL.md').read()
parts = text.split('---')
if len(parts) >= 2:
    lines = parts[1].strip().split('\n')
    in_desc = False
    desc_parts = []
    for line in lines:
        if line.startswith('description:'):
            val = line.split(':', 1)[1].strip()
            if val in ('>-', '>', '|-', '|'):
                in_desc = True
            else:
                desc_parts.append(val.strip('\"'))
                break
        elif in_desc and line.startswith('  '):
            desc_parts.append(line.strip())
        elif in_desc:
            break
    desc = ' '.join(desc_parts).strip()
    # Remove 'Invoke via' instruction for cleaner display
    desc = desc.split('Invoke via')[0].strip()
    print(desc[:80])
" 2>/dev/null)
        echo "  /$dst_name — ${desc:-<no description>}"
    fi
done

echo ""
echo "Restart deepcode-cli to use /aide."
