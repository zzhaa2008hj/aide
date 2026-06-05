#!/usr/bin/env bash
set -euo pipefail
# update.sh — Update AIDE for CodeWhale
#
# Checks the installed version against the latest, refreshes the user
# command template, and prints the /skill update command. Mirrors the
# deepcode-cli update pattern.
#
# Usage:
#   bash .aide/update-codewhale.sh
#   or
#   curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/skills/aide-codewhale/update.sh | bash
#   AIDE_REF=develop curl -sSL ... | bash  # use develop branch

AIDE_REF="${AIDE_REF:-master}"
RAW_BASE="https://raw.githubusercontent.com/zzhaa2008hj/aide/${AIDE_REF}"
COMMANDS_DIR="${COMMANDS_DIR:-.codewhale/commands}"

echo "=== AIDE Update for CodeWhale ==="
echo ""

# Step 1: Check current version
echo "[1/3] Check versions..."
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

# Step 2: Refresh the user command
echo "[2/3] Refresh slash command..."
mkdir -p "$COMMANDS_DIR"

cat > "$COMMANDS_DIR/aide.md" << 'EOF'
---
description: AIDE 流水线 — spec → plan → implement → test
argument-hint: "<任务描述>"
---

$aide $ARGUMENTS
EOF

echo "  [done]  $COMMANDS_DIR/aide.md"
echo ""

# Step 3: Refresh the update script itself + print /skill update
echo "[3/3] Update the skill in CodeWhale:"
echo ""

curl -sSL -o .aide/update-codewhale.sh "${RAW_BASE}/skills/aide-codewhale/update.sh" 2>/dev/null
chmod +x .aide/update-codewhale.sh

echo "  Run this in your CodeWhale session:"
echo ""
echo "    /skill update aide"
echo ""

echo "=== Update complete ==="
echo ""
echo "  Version:  $LATEST"
echo "  Update:   bash .aide/update-codewhale.sh"
