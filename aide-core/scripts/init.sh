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

# Step 3: Symlink skills into .claude/skills/
# Claude Code auto-discovers skills from .claude/skills/<name>/SKILL.md.
# AIDE skills live at .claude/aide/skills/, so we create a symlink.
if [ -L .claude/skills ]; then
    CURRENT_TARGET=$(readlink .claude/skills)
    if [ "$CURRENT_TARGET" = "aide/skills" ]; then
        echo "[skip]  .claude/skills already linked to aide/skills"
    else
        echo "[warn]  .claude/skills points to '$CURRENT_TARGET', replacing"
        rm .claude/skills
        ln -s aide/skills .claude/skills
        echo "[done]  .claude/skills linked to aide/skills"
    fi
elif [ -e .claude/skills ]; then
    echo "[warn]  .claude/skills exists but is not a symlink — leaving as-is"
else
    mkdir -p .claude
    ln -s aide/skills .claude/skills
    echo "[done]  .claude/skills linked to aide/skills"
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
