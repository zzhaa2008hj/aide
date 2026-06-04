#!/usr/bin/env bash
set -euo pipefail
# bump-version.sh — Bump AIDE marketplace version following convention:
#   Same branch (master) → patch bump (x.y.Z)
#   New branch          → minor bump (x.Y.z)
#   --major flag        → major bump (X.y.z, manual)

cd "$(git rev-parse --show-toplevel)"

BRANCH=$(git branch --show-current)
MODE="patch"

if [ "${1:-}" = "--major" ]; then
    MODE="major"
elif [ "$BRANCH" != "master" ] && [ "$BRANCH" != "main" ]; then
    MODE="minor"
fi

OLD_VERSION=$(python3 -c "import json; d=json.load(open('.claude-plugin/marketplace.json')); print(d['plugins'][0]['version'])")
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

# Ensure pre-push hook is installed (idempotent)
HOOK_SRC="$(cd "$(dirname "$0")" && pwd)/../../hooks/pre-push"
HOOK_DST="$(git rev-parse --git-dir)/hooks/pre-push"
if [ ! -L "$HOOK_DST" ] && [ ! -e "$HOOK_DST" ]; then
    ln -sf "$(realpath "$HOOK_SRC")" "$HOOK_DST"
    echo "Hook installed: pre-push"
fi

echo "Version bumped: $OLD_VERSION → $NEW_VERSION  (branch: $BRANCH, mode: $MODE)"
echo ""
echo "Next steps:"
echo "  git add .claude-plugin/marketplace.json"
echo "  git commit -m 'chore: bump version to $NEW_VERSION'"
echo "  git tag aide--v$NEW_VERSION"
echo "  git push"
