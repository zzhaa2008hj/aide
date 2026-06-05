#!/usr/bin/env bash
set -euo pipefail
# install.sh — Install AIDE for CodeWhale
#
# Sets up both the skill and the slash-command autocomplete in one step.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/develop/skills/aide-codewhale/install.sh | bash
#   or
#   bash skills/aide-codewhale/install.sh

AIDE_REPO="${AIDE_REPO:-https://github.com/zzhaa2008hj/aide.git}"
AIDE_REF="${AIDE_REF:-develop}"
COMMANDS_DIR="${COMMANDS_DIR:-.codewhale/commands}"

echo "=== AIDE Install for CodeWhale ==="
echo ""

# Step 1: Install the skill via CodeWhale
echo "[1/2] Install the aide skill:"
echo ""
echo "  Run this in your CodeWhale session:"
echo ""
echo "    /skill install ${AIDE_REPO}"
echo ""
echo "  (Or for the develop branch:)"
echo "    /skill install https://github.com/zzhaa2008hj/aide/archive/refs/heads/${AIDE_REF}.tar.gz"
echo ""

# Step 2: Install the user command for slash autocomplete
echo "[2/2] Install slash command autocomplete..."
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

echo "=== Installation complete ==="
echo ""
echo "  Skill:    run '/skill install' in CodeWhale (see above)"
echo "  Command:  $COMMANDS_DIR/aide.md (autocomplete ready)"
echo ""
echo "Now type /aide <task> in CodeWhale — /a will show the autocomplete hint."
