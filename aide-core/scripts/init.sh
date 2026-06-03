#!/usr/bin/env bash
set -euo pipefail

# init.sh — Bootstrap AIDE into a business project.
#
# Run this ONCE after adding the AIDE submodule:
#   git submodule add <AIDE-url> .claude/aide
#   bash .claude/aide/aide-core/scripts/init.sh
#
# After this, /aide-init and /aide are available.
# Safe to re-run — skips already-configured steps.

SKILL_DIRS_LINE="extra_skill_dirs: [.claude/aide/skills]"

echo "=== AIDE Bootstrap Init ==="
echo ""

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
    cp .claude/aide/templates/aide.config.yaml .aide/config.yaml
    echo "[done]  .aide/config.yaml created from template"
fi

# Step 3: CLAUDE.md
if [ -f CLAUDE.md ]; then
    if grep -qF '.claude/aide/skills' CLAUDE.md; then
        echo "[skip]  CLAUDE.md already configured with AIDE skill directory"
    elif grep -q 'extra_skill_dirs' CLAUDE.md; then
        # Has extra_skill_dirs but missing .claude/aide/skills — merge into existing list
        sed -i 's/extra_skill_dirs: \[\(.*\)\]/extra_skill_dirs: [\1, .claude\/aide\/skills]/' CLAUDE.md
        echo "[done]  Added .claude/aide/skills to existing extra_skill_dirs in CLAUDE.md"
    else
        # File exists but no extra_skill_dirs at all
        # Ensure trailing newline before appending
        [ -s CLAUDE.md ] && [ "$(tail -c1 CLAUDE.md | xxd -p)" != "0a" ] && echo "" >> CLAUDE.md
        echo "$SKILL_DIRS_LINE" >> CLAUDE.md
        echo "[done]  Added extra_skill_dirs to existing CLAUDE.md"
    fi
else
    echo "$SKILL_DIRS_LINE" > CLAUDE.md
    echo "[done]  Created CLAUDE.md with AIDE skill directory configured"
fi

# Step 4: Verify submodule is fully set up
if [ ! -f .claude/aide/skills/aide/skill.md ]; then
    echo ""
    echo "WARNING: AIDE skill files not found at .claude/aide/skills/."
    echo "The git submodule may not be initialized. Run:"
    echo "  git submodule update --init .claude/aide"
    exit 1
fi

echo ""
echo "=== AIDE bootstrap complete ==="
echo ""
echo "Now you can use:"
echo "  /aide-init       — re-run init (idempotent)"
echo "  /aide \"<desc>\"   — start the pipeline"
