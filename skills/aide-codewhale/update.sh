#!/usr/bin/env bash
set -euo pipefail
# update.sh — Update AIDE for CodeWhale
#
# Re-fetches the user command template to pick up any frontmatter changes
# (description, argument-hint) and prints the /skill update command.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/develop/skills/aide-codewhale/update.sh | bash
#   or
#   bash skills/aide-codewhale/update.sh

COMMANDS_DIR="${COMMANDS_DIR:-.codewhale/commands}"
AIDE_REF="${AIDE_REF:-develop}"

echo "=== AIDE Update for CodeWhale ==="
echo ""

# Step 1: Refresh the user command
echo "[1/2] Update slash command..."
mkdir -p "$COMMANDS_DIR"

cat > "$COMMANDS_DIR/aide.md" << 'EOF'
---
description: AIDE 流水线 — spec → plan → implement → test
argument-hint: "<任务描述>"
---

$aide $ARGUMENTS
EOF

echo "  [done]  $COMMANDS_DIR/aide.md updated"
echo ""

# Step 2: Update the skill via CodeWhale
echo "[2/2] Update the aide skill:"
echo ""
echo "  Run this in your CodeWhale session:"
echo ""
echo "    /skill update aide"
echo ""

echo "=== Update complete ==="
