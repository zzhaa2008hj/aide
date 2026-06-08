#!/usr/bin/env bash
set -euo pipefail
# update.sh — Update AIDE for CodeWhale
#
# Refreshes both aide and aide-fix skills and slash commands.
# Defaults to global paths (~/.codewhale/). Set SKILLS_DIR and
# COMMANDS_DIR for project-local.
#
# Usage:
#   bash .aide/update-codewhale.sh
#   AIDE_REF=develop bash .aide/update-codewhale.sh               # develop branch
#   SKILLS_DIR=.agents/skills COMMANDS_DIR=.codewhale/commands bash ...  # project-local

AIDE_REF="${AIDE_REF:-master}"
RAW_BASE="https://raw.githubusercontent.com/zzhaa2008hj/aide/${AIDE_REF}"
COMMANDS_DIR="${COMMANDS_DIR:-$HOME/.codewhale/commands}"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.codewhale/skills}"

echo "=== AIDE Update for CodeWhale ==="
echo "  Skills dir:  $SKILLS_DIR"
echo "  Commands dir: $COMMANDS_DIR"
echo ""

# Step 1: Check current version
echo "[1/5] Check versions..."
CURRENT="unknown"
if [ -f .aide/version ]; then
    CURRENT=$(cat .aide/version)
fi

LATEST=$(curl -sSL --fail "${RAW_BASE}/.claude-plugin/plugin.json" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['version'])
" 2>/dev/null || echo "unknown")

echo "  Installed: $CURRENT"
echo "  Latest:    $LATEST"

if [ "$CURRENT" = "$LATEST" ] && [ "$CURRENT" != "unknown" ]; then
    echo "  Already up to date."
else
    echo "  Update available: $CURRENT → $LATEST"
    echo "$LATEST" > .aide/version
fi
echo ""

# Step 2: Refresh slash commands
echo "[2/5] Refresh slash commands..."
mkdir -p "$COMMANDS_DIR"

cat > "$COMMANDS_DIR/aide.md" << 'EOF'
---
description: AIDE 流水线 — spec → plan → implement → test
argument-hint: "<任务描述>"
---

$aide $ARGUMENTS
EOF

cat > "$COMMANDS_DIR/aide-fix.md" << 'EOF'
---
description: AIDE 修复流水线 — analyze → implement → test
argument-hint: "<bug描述>"
---

$aide-fix $ARGUMENTS
EOF

echo "  [done]  $COMMANDS_DIR/aide.md"
echo "  [done]  $COMMANDS_DIR/aide-fix.md"
echo ""

# Step 3: Refresh aide skill
echo "[3/5] Refresh aide skill..."
mkdir -p "$SKILLS_DIR/aide"
curl -sSL --fail -o "$SKILLS_DIR/aide/SKILL.md" "${RAW_BASE}/skills/aide-codewhale/SKILL.md"
echo "  [done]  $SKILLS_DIR/aide/SKILL.md"

# Step 4: Refresh aide-fix skill
echo "[4/5] Refresh aide-fix skill..."
mkdir -p "$SKILLS_DIR/aide-fix"
curl -sSL --fail -o "$SKILLS_DIR/aide-fix/SKILL.md" "${RAW_BASE}/skills/aide-fix/SKILL.md"
echo "  [done]  $SKILLS_DIR/aide-fix/SKILL.md"
echo ""

# Step 5: Refresh update script + verify
echo "[5/5] Refresh update script & verify..."
curl -sSL --fail -o .aide/update-codewhale.sh "${RAW_BASE}/skills/aide-codewhale/update.sh"
chmod +x .aide/update-codewhale.sh

OK=0
for f in "$SKILLS_DIR/aide/SKILL.md" "$SKILLS_DIR/aide-fix/SKILL.md" \
         "$COMMANDS_DIR/aide.md" "$COMMANDS_DIR/aide-fix.md"; do
    if [ -s "$f" ]; then
        echo "  ✓  $f"
    else
        echo "  ✗  $f — MISSING OR EMPTY"
        OK=1
    fi
done
if [ $OK -ne 0 ]; then
    echo ""
    echo "ERROR: Some files failed to update. Check network and try again."
    exit 1
fi

echo ""
echo "=== Update complete ==="
echo ""
echo "  Version:   $LATEST"
echo "  Skills:    aide + aide-fix → $SKILLS_DIR"
echo "  Commands:  $COMMANDS_DIR"
echo "  Update:    bash .aide/update-codewhale.sh"
