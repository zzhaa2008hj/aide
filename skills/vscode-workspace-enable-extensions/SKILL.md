---
name: vscode-workspace-enable-extensions
description: >-
  Analyze project content and auto-enable matching VS Code extensions for the
  workspace. Detects file types (Python, Markdown, Shell, Go, Rust, etc.) and
  writes enabled state to VS Code's state.vscdb using real extension UUIDs.
---

# VS Code Workspace Enable Extensions

You analyze the current project's file types and enable matching VS Code extensions for this workspace. Uses the same `state.vscdb` approach as `vscode-workspace-disable-extensions` — `.vscode/settings.json` does NOT work for workspace-level extension state.

## Process

### Step 1: Run the analysis script

```bash
AIDE_DIR=$(find ~/.claude/plugins/cache/aide .claude/plugins -name "SKILL.md" -path "*/skills/aide/*" 2>/dev/null | head -1 | sed 's|/skills/aide/SKILL.md||')
[ -z "$AIDE_DIR" ] && AIDE_DIR=".claude/aide"

python3 "$AIDE_DIR/aide-core/scripts/vscode/enable_extensions.py"
```

### Step 2: Report

Show which extensions were enabled and which were skipped (not installed). If any extensions need manual installation, provide the `code --install-extension` commands.

### Step 3: Restart reminder

Tell the user: "Restart VS Code for the changes to take effect (Reload Window is not enough — quit and reopen)."

## How It Works

```
Project files → file-type detection → extension ID mapping → state.vscdb write
```

VS Code stores workspace extension state in:
```
~/.config/Code/User/workspaceStorage/<id>/state.vscdb
```

Key: `extensionsIdentifiers/enabled` — must use real UUIDs from `~/.vscode/extensions/extensions.json`.

## Detection Rules

| File Type | Detector | Extensions Enabled |
|-----------|----------|-------------------|
| Python (.py) | `*.py` exists | ms-python.python, ms-python.debugpy, charliermarsh.ruff |
| Markdown (.md) | `**/*.md` exists | yzhang.markdown-all-in-one |
| YAML (.yaml/.yml) | config files | redhat.vscode-yaml |
| Shell (.sh) | `**/*.sh` exists | timonwong.shellcheck |
| JS/TS | `*.js` / `*.ts` | dbaeumer.vscode-eslint, esbenp.prettier-vscode |
| Go | `*.go` exists | golang.go |
| Rust | `*.rs` exists | rust-lang.rust-analyzer |
| Docker | Dockerfile exists | ms-azuretools.vscode-docker |
| Git | `.git/` exists | github.vscode-github-actions, eamodio.gitlens |

## Important Guidelines

- Run `--dry-run` first to preview without writing: `python3 .../enable_extensions.py --dry-run`
- The project must have been opened in VS Code at least once (workspaceStorage must exist).
- Extensions not installed are skipped with an install hint — they are NOT auto-installed.
- Full VS Code restart is required — Reload Window is not sufficient.
