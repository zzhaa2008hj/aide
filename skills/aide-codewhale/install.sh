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
SKILLS_DIR="${SKILLS_DIR:-.agents/skills}"
RAW_BASE="https://raw.githubusercontent.com/zzhaa2008hj/aide/${AIDE_REF}"

echo "=== AIDE Install for CodeWhale ==="
echo ""

# Step 1: Record version from plugin.json
echo "[1/6] Fetch version..."
VERSION=$(curl -sSL "${RAW_BASE}/.claude-plugin/plugin.json" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['version'])
" 2>/dev/null || echo "unknown")
mkdir -p .aide
echo "$VERSION" > .aide/version
echo "  Version: $VERSION → .aide/version"

# Step 2: Install the user command for slash autocomplete
echo "[2/6] Install slash command autocomplete..."
mkdir -p "$COMMANDS_DIR"

cat > "$COMMANDS_DIR/aide.md" << 'EOF'
---
description: AIDE 流水线 — spec → plan → implement → test
argument-hint: "<任务描述>"
---

$aide $ARGUMENTS
EOF

echo "  [done]  $COMMANDS_DIR/aide.md"

# Step 3: Install aide-fix skill (direct file placement, bypasses /skill install single-skill limit)
echo "[3/6] Install aide-fix skill..."
mkdir -p "$SKILLS_DIR/aide-fix"
curl -sSL -o "$SKILLS_DIR/aide-fix/SKILL.md" "${RAW_BASE}/skills/aide-fix/SKILL.md" 2>/dev/null
echo "  [done]  $SKILLS_DIR/aide-fix/SKILL.md"

# Step 4: Install aide-fix slash command
echo "[4/6] Install aide-fix slash command..."
cat > "$COMMANDS_DIR/aide-fix.md" << 'EOF'
---
description: AIDE 修复流水线 — analyze → implement → test
argument-hint: "<bug描述>"
---

$aide-fix $ARGUMENTS
EOF
echo "  [done]  $COMMANDS_DIR/aide-fix.md"

# Step 5: Install update script for future upgrades
echo "[5/6] Install update script..."
curl -sSL -o .aide/update-codewhale.sh "${RAW_BASE}/skills/aide-codewhale/update.sh" 2>/dev/null
chmod +x .aide/update-codewhale.sh
echo "  [done]  .aide/update-codewhale.sh"

# Step 6: Print /skill install command
echo "[6/6] Install the main skill in CodeWhale:"
echo ""
echo "  Run this in your CodeWhale session:"
echo ""
echo "    /skill install https://github.com/zzhaa2008hj/aide/archive/refs/heads/${AIDE_REF}.tar.gz"
echo ""

echo "=== Installation complete ==="
echo ""
echo "  Version:   $VERSION"
echo "  Skills:    aide + aide-fix → $SKILLS_DIR"
echo "  Commands:  $COMMANDS_DIR/aide.md (autocomplete ready)"
echo "             $COMMANDS_DIR/aide-fix.md (autocomplete ready)"
echo "  Update:    bash .aide/update-codewhale.sh"
echo ""
echo "Next: run '/skill install' in CodeWhale (see above) to register the main aide skill."
echo "      aide-fix is already in $SKILLS_DIR/aide-fix/ — auto-discovered on next start."
echo ""
echo "To install globally instead: SKILLS_DIR=~/.codewhale/skills bash ..."
echo ""
echo "Type /aide <task> or /aide-fix <bug> in CodeWhale."
