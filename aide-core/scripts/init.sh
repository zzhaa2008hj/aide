#!/usr/bin/env bash
set -euo pipefail

# init.sh — Bootstrap AIDE config into a business project.
#
# Run ONCE after installing AIDE via claude plugin install:
#   claude plugin marketplace add https://github.com/zzhaa2008hj/aide.git
#   claude plugin install aide@aide --scope project
#   bash <aide-path>/aide-core/scripts/init.sh
#
# After this, /aide and /aide-update are available.
# Safe to re-run — skips already-configured steps.

echo "=== AIDE Bootstrap Init ==="
echo ""

# Locate the AIDE installation (installed as a Claude Code plugin)
# Try common locations: project plugin dir, user cache
AIDE_DIR=""
for candidate in \
    .claude/plugins/aide \
    "$HOME/.claude/plugins/cache/aide/aide"/* \
    "$HOME/.claude/plugins/cache/aide"/*/aide; do
    if [ -f "$candidate/skills/aide/skill.md" ]; then
        AIDE_DIR="$candidate"
        break
    fi
done

if [ -z "$AIDE_DIR" ]; then
    echo ""
    echo "WARNING: AIDE installation not found."
    echo "Install AIDE first:"
    echo "  claude plugin marketplace add https://github.com/zzhaa2008hj/aide.git"
    echo "  claude plugin install aide@aide --scope project"
    exit 1
fi
echo "[done]  AIDE found at $AIDE_DIR"

# Step 1: .aide/ directory
if [ -d .aide ]; then
    echo "[skip]  .aide/ already exists"
else
    mkdir -p .aide
    echo "[done]  .aide/ created"
fi

# Step 2: Config template
if [ -f .aide/config.yaml ]; then
    echo "[skip]  .aide/config.yaml already exists"
else
    cp "$AIDE_DIR/templates/aide.config.yaml" .aide/config.yaml
    echo "[done]  .aide/config.yaml created from template"
fi

skill_count=$(ls -1 "$AIDE_DIR/skills/" 2>/dev/null | wc -l)
echo "[done]  $skill_count skills available"

echo ""
echo "=== AIDE bootstrap complete ==="
echo ""
echo "Now you can use:"
echo "  /aide-update     — update AIDE to latest (claude plugin update aide)"
echo "  /aide \"<desc>\"   — start the pipeline"
