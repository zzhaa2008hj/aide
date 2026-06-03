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

# Step 3: Link individual skills into .claude/skills/
# Claude Code auto-discovers skills from .claude/skills/<name>/SKILL.md.
# Each skill gets its own symlink pointing into the AIDE submodule.
mkdir -p .claude/skills
LINKED=0
SKIPPED=0
for skill_dir in .claude/aide/skills/*/; do
    skill_name=$(basename "$skill_dir")
    if [ -L ".claude/skills/$skill_name" ]; then
        SKIPPED=$((SKIPPED + 1))
    elif [ -e ".claude/skills/$skill_name" ]; then
        echo "[skip]  .claude/skills/$skill_name already exists (not a symlink)"
        SKIPPED=$((SKIPPED + 1))
    else
        ln -s "../aide/skills/$skill_name" ".claude/skills/$skill_name"
        LINKED=$((LINKED + 1))
    fi
done
echo "[done]  .claude/skills/: $LINKED linked, $SKIPPED already present"

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
