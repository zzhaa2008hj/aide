#!/usr/bin/env bash
set -euo pipefail
# bump-version.sh — Bump AIDE marketplace version following convention:
#   Same branch (master) → patch bump (x.y.Z)
#   New branch          → minor bump (x.Y.z)
#   --major flag        → major bump (X.y.z, manual)

cd "$(git rev-parse --show-toplevel)"

BRANCH=$(git branch --show-current)
MODE="patch"
SILENT=false

# Parse all arguments in any order
for arg in "$@"; do
    case "$arg" in
        --major) MODE="major" ;;
        --minor) MODE="minor" ;;
        --patch) MODE="patch" ;;
        --silent) SILENT=true ;;
    esac
done

# Default mode by branch (only if not explicitly set)
if [ "$MODE" = "patch" ]; then
    if [ "$BRANCH" != "master" ] && [ "$BRANCH" != "main" ]; then
        MODE="minor"
    fi
fi

OLD_VERSION=$(python3 -c "import json; d=json.load(open('.claude-plugin/marketplace.json')); print(d['plugins'][0]['version'])")
PLUGIN_VERSION=$(python3 -c "import json; d=json.load(open('.claude-plugin/plugin.json')); print(d['version'])")

if [ "$OLD_VERSION" != "$PLUGIN_VERSION" ]; then
    echo "ERROR: Version mismatch before bump — marketplace.json: $OLD_VERSION, plugin.json: $PLUGIN_VERSION"
    echo "Both files must have the same version. Please fix manually before bumping."
    exit 1
fi

# Validate version is strictly numeric X.Y.Z (no pre-release suffixes like -rc1, -alpha, etc.)
if ! echo "$OLD_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "ERROR: Invalid version format: $OLD_VERSION"
    echo "Expected X.Y.Z with numeric components only (e.g., 1.2.3)."
    echo "Pre-release suffixes (-alpha, -rc1, etc.) are not supported by bump-version.sh."
    exit 1
fi

IFS='.' read -r MAJ MIN PAT <<< "$OLD_VERSION"

case "$MODE" in
    major) NEW_VERSION="$((MAJ + 1)).0.0" ;;
    minor) NEW_VERSION="$MAJ.$((MIN + 1)).0" ;;
    patch) NEW_VERSION="$MAJ.$MIN.$((PAT + 1))" ;;
esac

python3 -c "
import json

# Update marketplace.json
with open('.claude-plugin/marketplace.json') as f:
    d = json.load(f)
d['metadata']['version'] = '$NEW_VERSION'
d['plugins'][0]['version'] = '$NEW_VERSION'
with open('.claude-plugin/marketplace.json', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')

# Update plugin.json (Claude Code reads this for version comparison)
with open('.claude-plugin/plugin.json') as f:
    p = json.load(f)
p['version'] = '$NEW_VERSION'
with open('.claude-plugin/plugin.json', 'w') as f:
    json.dump(p, f, indent=2)
    f.write('\n')
"

# Ensure hooks are installed (idempotent)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
for hook in pre-commit pre-push; do
    HOOK_SRC="$SCRIPT_DIR/../../hooks/$hook"
    HOOK_DST="$(git rev-parse --git-dir)/hooks/$hook"
    if [ ! -L "$HOOK_DST" ] && [ ! -e "$HOOK_DST" ]; then
        ln -sf "$(realpath "$HOOK_SRC")" "$HOOK_DST"
        echo "Hook installed: $hook"
    fi
done

if [ "$SILENT" != true ]; then
    echo "Version bumped: $OLD_VERSION → $NEW_VERSION  (branch: $BRANCH, mode: $MODE)"
    echo ""
    echo "Next steps:"
    echo "  git add .claude-plugin/"
    echo "  git commit -m 'chore: bump version to $NEW_VERSION'"
    echo "  git tag aide--v$NEW_VERSION"
    echo "  git push"
fi
