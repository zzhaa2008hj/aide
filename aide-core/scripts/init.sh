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

SKILL_DIRS_KEY="extra_skill_dirs: [.claude/aide/skills]"
FRONTMATTER="---
$SKILL_DIRS_KEY
---"

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

# Step 3: CLAUDE.md (YAML frontmatter format)
if [ -f CLAUDE.md ]; then
    if grep -qF '.claude/aide/skills' CLAUDE.md; then
        echo "[skip]  CLAUDE.md already configured with AIDE skill directory"

    elif head -1 CLAUDE.md | grep -q '^---$'; then
        # Has existing YAML frontmatter — add extra_skill_dirs inside it
        # Find the closing --- of the frontmatter block
        CLOSING_LINE=$(grep -n '^---$' CLAUDE.md | sed -n '2p' | cut -d: -f1)
        if [ -n "$CLOSING_LINE" ]; then
            # Insert extra_skill_dirs before the closing ---
            sed -i "${CLOSING_LINE}i\\${SKILL_DIRS_KEY}" CLAUDE.md
            echo "[done]  Added extra_skill_dirs to existing frontmatter in CLAUDE.md"
        else
            # Frontmatter opened but not closed — just append after first ---
            sed -i "1a\\${SKILL_DIRS_KEY}" CLAUDE.md
            echo "[done]  Added extra_skill_dirs to frontmatter in CLAUDE.md"
        fi

    elif grep -q 'extra_skill_dirs' CLAUDE.md; then
        # Has extra_skill_dirs outside frontmatter — merge into existing list
        sed -i 's/extra_skill_dirs: \[\(.*\)\]/extra_skill_dirs: [\1, .claude\/aide\/skills]/' CLAUDE.md
        echo "[done]  Added .claude/aide/skills to existing extra_skill_dirs in CLAUDE.md"

    else
        # File exists but no frontmatter and no extra_skill_dirs — prepend frontmatter
        echo "$FRONTMATTER" | cat - CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
        echo "" >> CLAUDE.md
        echo "[done]  Added extra_skill_dirs frontmatter to CLAUDE.md"
    fi
else
    echo "$FRONTMATTER" > CLAUDE.md
    echo "" >> CLAUDE.md
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
echo "  /aide-update     — update AIDE to latest"
echo "  /aide \"<desc>\"   — start the pipeline"
