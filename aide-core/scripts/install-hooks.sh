#!/usr/bin/env bash
set -euo pipefail
# install-hooks.sh — Install git hooks from hooks/ into .git/hooks/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../../hooks"
GIT_HOOKS="$(git rev-parse --git-dir)/hooks"

if [ ! -d "$HOOKS_DIR" ]; then
    echo "No hooks directory found at $HOOKS_DIR"
    exit 1
fi

INSTALLED=0
for hook in "$HOOKS_DIR"/*; do
    hook_name=$(basename "$hook")
    target="$GIT_HOOKS/$hook_name"
    if [ -L "$target" ] || [ -e "$target" ]; then
        echo "[skip]  $hook_name already installed"
    else
        ln -sf "$(realpath "$hook")" "$target"
        echo "[done]  $hook_name installed"
        INSTALLED=$((INSTALLED + 1))
    fi
done

echo ""
echo "$INSTALLED hook(s) installed."
echo "Run 'git push' — the hook will enforce marketplace.json version bumps."
