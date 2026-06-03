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

# Step 3: Register AIDE skills via extraSkillDirs
# Instead of copying into .claude/skills/ (which would overwrite project skills),
# we register .claude/aide/skills as a plugin directory in settings.
python3 -c "
import json, os
settings_path = '.claude/settings.local.json'
aide_skills = '.claude/aide/skills'
os.makedirs('.claude', exist_ok=True)
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}
existing = settings.get('extraSkillDirs', [])
if aide_skills in existing:
    print('skip: extraSkillDirs already includes .claude/aide/skills')
else:
    settings['extraSkillDirs'] = existing + [aide_skills]
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
    print('done: registered .claude/aide/skills in extraSkillDirs')
"

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
