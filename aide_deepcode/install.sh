#!/usr/bin/env bash
set -euo pipefail
# install.sh — Install AIDE plugins into a DeepCode project.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/aide_deepcode/install.sh | bash
#   or
#   bash aide_deepcode/install.sh

AIDE_REPO="${AIDE_REPO:-https://github.com/zzhaa2008hj/aide.git}"
AIDE_REF="${AIDE_REF:-master}"
PLUGIN_DIR="${1:-workflows/plugins/aide}"

echo "=== AIDE DeepCode Plugin Install ==="
echo ""

# Step 1: Verify we're in a DeepCode project
if [ ! -f "deepcode_config.json" ] && [ ! -f "deepcode_config.json.example" ]; then
    echo "[warn]  deepcode_config.json not found — are you in a DeepCode project root?"
    echo "         Continuing anyway..."
fi

# Step 2: Create plugins directory
mkdir -p "$(dirname "$PLUGIN_DIR")"
rm -rf "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"

# Step 3: Sparse checkout aide_deepcode/ only
echo "[info]  Fetching aide_deepcode/ from $AIDE_REPO ($AIDE_REF)..."
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

# Step 5: Verify
echo ""
echo "=== Installation complete ==="
echo "Path: $PLUGIN_DIR"
echo ""
echo "Files installed:"
ls -1 "$PLUGIN_DIR"
echo ""
echo "Restart DeepCode to load the AIDE plugins."
echo "Test with: /aide \"<your feature description>\""
