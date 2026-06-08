#!/usr/bin/env bash
set -euo pipefail
# update.sh — Update AIDE for CodeWhale
#
# Checks the installed version against the latest, refreshes both aide
# and aide-fix skill files, slash commands, and the update script itself.
#
# Usage:
#   bash .aide/update-codewhale.sh
#   or
#   curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/skills/aide-codewhale/update.sh | bash
#   AIDE_REF=develop curl -sSL ... | bash  # use develop branch

AIDE_REF="${AIDE_REF:-master}"
RAW_BASE="https://raw.githubusercontent.com/zzhaa2008hj/aide/${AIDE_REF}"
COMMANDS_DIR="${COMMANDS_DIR:-.codewhale/commands}"
SKILLS_DIR="${SKILLS_DIR:-.agents/skills}"

echo "=== AIDE Update for CodeWhale ==="
echo ""

# Step 1: Check current version
echo "[1/5] Check versions..."
CURRENT="unknown"
if [ -f .aide/version ]; then
    CURRENT=$(cat .aide/version)
fi

LATEST=$(curl -sSL "${RAW_BASE}/.claude-plugin/plugin.json" 2>/dev/null | python3 -c "
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

# Step 3: Refresh aide skill file
echo "[3/5] Refresh aide skill..."
mkdir -p "$SKILLS_DIR/aide"
curl -sSL -o "$SKILLS_DIR/aide/SKILL.md" "${RAW_BASE}/skills/aide-codewhale/SKILL.md" 2>/dev/null
echo "  [done]  $SKILLS_DIR/aide/SKILL.md"

# Step 4: Refresh aide-fix skill file
echo "[4/5] Refresh aide-fix skill..."
mkdir -p "$SKILLS_DIR/aide-fix"
curl -sSL -o "$SKILLS_DIR/aide-fix/SKILL.md" "${RAW_BASE}/skills/aide-fix/SKILL.md" 2>/dev/null
echo "  [done]  $SKILLS_DIR/aide-fix/SKILL.md"
echo ""

# Step 5: Refresh the update script itself
echo "[5/5] Refresh update script..."
curl -sSL -o .aide/update-codewhale.sh "${RAW_BASE}/skills/aide-codewhale/update.sh" 2>/dev/null
chmod +x .aide/update-codewhale.sh
echo "  [done]  .aide/update-codewhale.sh"
echo ""

echo "=== Update complete ==="
echo ""
echo "  Version:   $LATEST"
echo "  Skills:    aide + aide-fix → $SKILLS_DIR"
echo "  Update:    bash .aide/update-codewhale.sh"
