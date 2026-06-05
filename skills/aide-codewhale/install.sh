#!/usr/bin/env bash
set -euo pipefail
# install.sh — Install AIDE for CodeWhale
#
# Sets up the skill, slash-command autocomplete, and version tracking
# in one step. Mirrors the deepcode-cli install pattern (version + update
# script provisioning).
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/skills/aide-codewhale/install.sh | bash
#   AIDE_REF=develop curl -sSL ... | bash  # use develop branch
#   or
#   bash skills/aide-codewhale/install.sh

AIDE_REPO="${AIDE_REPO:-https://github.com/zzhaa2008hj/aide.git}"
AIDE_REF="${AIDE_REF:-master}"
COMMANDS_DIR="${COMMANDS_DIR:-.codewhale/commands}"
RAW_BASE="https://raw.githubusercontent.com/zzhaa2008hj/aide/${AIDE_REF}"

echo "=== AIDE Install for CodeWhale ==="
echo ""

# Step 1: Record version from plugin.json
echo "[1/4] Fetch version..."
VERSION=$(curl -sSL "${RAW_BASE}/.claude-plugin/plugin.json" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['version'])
" 2>/dev/null || echo "unknown")
mkdir -p .aide
echo "$VERSION" > .aide/version
echo "  Version: $VERSION → .aide/version"

# Step 2: Install the user command for slash autocomplete
echo "[2/4] Install slash command autocomplete..."
mkdir -p "$COMMANDS_DIR"

cat > "$COMMANDS_DIR/aide.md" << 'EOF'
---
description: AIDE 流水线 — spec → plan → implement → test
argument-hint: "<任务描述>"
---

$aide $ARGUMENTS
EOF

echo "  [done]  $COMMANDS_DIR/aide.md"

# Step 3: Install update script for future upgrades
echo "[3/4] Install update script..."
curl -sSL -o .aide/update-codewhale.sh "${RAW_BASE}/skills/aide-codewhale/update.sh" 2>/dev/null
chmod +x .aide/update-codewhale.sh
echo "  [done]  .aide/update-codewhale.sh"

# Step 4: Print /skill install command
echo "[4/4] Install the skill in CodeWhale:"
echo ""
echo "  Run this in your CodeWhale session:"
echo ""
echo "    /skill install https://github.com/zzhaa2008hj/aide/archive/refs/heads/${AIDE_REF}.tar.gz"
echo ""

echo "=== Installation complete ==="
echo ""
echo "  Version:  $VERSION"
echo "  Skill:    run '/skill install' in CodeWhale (see above)"
echo "  Command:  $COMMANDS_DIR/aide.md (autocomplete ready)"
echo "  Update:   bash .aide/update-codewhale.sh"
echo ""
echo "Type /aide <task> in CodeWhale — /a will show the autocomplete hint."
