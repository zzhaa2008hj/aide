#!/usr/bin/env bash
set -euo pipefail
# install-codewhale.sh — Install AIDE for CodeWhale
#
# Installs both aide (pipeline) and aide-fix (bug-fix) skills.
# Defaults to global install (~/.codewhale/). Set SKILLS_DIR and
# COMMANDS_DIR for project-local install.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/aide-core/scripts/install-codewhale.sh | bash
#   AIDE_REF=develop bash ...                                    # develop branch
#   SKILLS_DIR=.agents/skills COMMANDS_DIR=.codewhale/commands bash ...  # project-local

AIDE_REPO="${AIDE_REPO:-https://github.com/zzhaa2008hj/aide.git}"
AIDE_REF="${AIDE_REF:-master}"
COMMANDS_DIR="${COMMANDS_DIR:-$HOME/.codewhale/commands}"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.codewhale/skills}"
RAW_BASE="https://raw.githubusercontent.com/zzhaa2008hj/aide/${AIDE_REF}"

echo "=== AIDE Install for CodeWhale ==="
echo "  Skills dir:  $SKILLS_DIR"
echo "  Commands dir: $COMMANDS_DIR"
echo ""

# Step 1: Record version from plugin.json
echo "[1/6] Fetch version..."
VERSION=$(curl -sSL --fail "${RAW_BASE}/.claude-plugin/plugin.json" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['version'])
" 2>/dev/null || echo "unknown")
mkdir -p .aide
echo "$VERSION" > .aide/version
echo "  Version: $VERSION → .aide/version"

# Step 2: Install slash commands
echo "[2/6] Install slash commands..."
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

# Step 3: Install aide skill
echo "[3/6] Install aide skill..."
mkdir -p "$SKILLS_DIR/aide"
curl -sSL --fail -o "$SKILLS_DIR/aide/SKILL.md" "${RAW_BASE}/skills/aide-codewhale/SKILL.md"
echo "  [done]  $SKILLS_DIR/aide/SKILL.md"

# Step 4: Install aide-fix skill
echo "[4/6] Install aide-fix skill..."
mkdir -p "$SKILLS_DIR/aide-fix"
curl -sSL --fail -o "$SKILLS_DIR/aide-fix/SKILL.md" "${RAW_BASE}/skills/aide-fix/SKILL.md"
echo "  [done]  $SKILLS_DIR/aide-fix/SKILL.md"

# Step 5: Install update script
echo "[5/6] Install update script..."
curl -sSL --fail -o .aide/update-codewhale.sh "${RAW_BASE}/aide-core/scripts/update-codewhale.sh"
chmod +x .aide/update-codewhale.sh
echo "  [done]  .aide/update-codewhale.sh"

# Step 6: Verify
echo "[6/6] Verify installation..."
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
    echo "ERROR: Some files failed to install. Check network and try again."
    exit 1
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "  Version:   $VERSION"
echo "  Skills:    aide + aide-fix → $SKILLS_DIR"
echo "  Commands:  $COMMANDS_DIR"
echo "  Update:    bash .aide/update-codewhale.sh"
echo ""
echo "Project-local install:"
echo "  SKILLS_DIR=.agents/skills COMMANDS_DIR=.codewhale/commands bash ..."
echo ""
echo "Type /aide <task> or /aide-fix <bug> in CodeWhale."
