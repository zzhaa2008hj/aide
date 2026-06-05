#!/usr/bin/env bash
set -euo pipefail
# install.sh — Install AIDE plugins into a DeepCode project.
#
# Usage:
#   # Public repo (default):
#   bash aide_deepcode/install.sh
#
#   # Private repo via SSH:
#   AIDE_REPO=git@github.com:zzhaa2008hj/aide.git bash aide_deepcode/install.sh
#
#   # Custom ref:
#   AIDE_REF=dev bash aide_deepcode/install.sh
#
#   # Custom target directory:
#   bash aide_deepcode/install.sh workflows/plugins/my-aide

AIDE_REPO="${AIDE_REPO:-https://github.com/zzhaa2008hj/aide.git}"
AIDE_REF="${AIDE_REF:-master}"
PLUGIN_DIR="${1:-workflows/plugins/aide}"

echo "=== AIDE DeepCode Plugin Install ==="
echo "  Repo: $AIDE_REPO"
echo "  Ref:  $AIDE_REF"
echo "  Dest: $PLUGIN_DIR"
echo ""

# Step 1: Verify git access
if ! git ls-remote "$AIDE_REPO" "$AIDE_REF" >/dev/null 2>&1; then
    echo "[error] Cannot access $AIDE_REPO"
    echo "        If this is a private repo, use SSH:"
    echo "        AIDE_REPO=git@github.com:zzhaa2008hj/aide.git bash aide_deepcode/install.sh"
    exit 1
fi

# Step 2: Create target directory
rm -rf "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"

# Step 3: Sparse checkout aide_deepcode/ only
echo "[info]  Fetching aide_deepcode/ ..."
cd "$PLUGIN_DIR"
git init -q
git remote add origin "$AIDE_REPO" 2>/dev/null || git remote set-url origin "$AIDE_REPO"
git sparse-checkout init --cone >/dev/null 2>&1
git sparse-checkout set aide_deepcode >/dev/null 2>&1
git fetch origin "$AIDE_REF" --depth 1 -q 2>/dev/null || git fetch origin "$AIDE_REF" --depth 1
git checkout FETCH_HEAD >/dev/null 2>&1

# Step 4: Move files up and clean artifacts
mv aide_deepcode/* . 2>/dev/null || true
rm -rf aide_deepcode .git
# Remove repo-root files pulled by sparse-checkout
rm -f README.md SUPERSPOWERS_VERSION .gitignore 2>/dev/null || true

cd - > /dev/null

# Step 5: Register AIDE in DeepCode's plugin init
PLUGIN_INIT="workflows/plugins/__init__.py"
AIDE_LINES="from .aide import register_aide_plugins
register_aide_plugins()"

if [ -f "$PLUGIN_INIT" ]; then
    if grep -q "register_aide_plugins" "$PLUGIN_INIT" 2>/dev/null; then
        echo "[skip]  AIDE already registered in $PLUGIN_INIT"
    else
        echo "$AIDE_LINES" >> "$PLUGIN_INIT"
        echo "[done]  Added AIDE registration to $PLUGIN_INIT"
    fi
else
    echo "[warn]  $PLUGIN_INIT not found — AIDE plugins must be registered manually."
    echo "         Add to DeepCode startup:"
    echo ""
    echo "         from workflows.plugins.aide import register_aide_plugins"
    echo "         register_aide_plugins()"
fi

# Step 6: Verify
echo ""
echo "=== Installation complete ==="
echo "Path: $PLUGIN_DIR"
echo ""
echo "Files installed:"
ls -1 "$PLUGIN_DIR"
echo ""
echo "Restart DeepCode to load the AIDE plugins."
