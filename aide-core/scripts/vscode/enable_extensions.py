#!/usr/bin/env python3
"""
Match project content to VS Code extensions and enable them for the workspace.

Pattern adapted from vscode-workspace-disable-extensions (superpowers).
Key insight: VS Code stores workspace extension state in state.vscdb
(not .vscode/settings.json). Real UUIDs from extensions.json are required.

Usage: python3 aide-core/scripts/vscode/enable_extensions.py [--dry-run]
"""

import json
import os
import sqlite3
import subprocess
import sys
from pathlib import Path


# ── File-type → extension mapping ──────────────────────────────────────
FILE_MATCHERS = [
    # (description, detector, recommended extension IDs)
    ("Python", lambda root: bool(list(root.glob("*.py")) or list(root.glob("**/*.py"))),
     ["ms-python.python", "ms-python.debugpy", "charliermarsh.ruff"]),
    ("Markdown / docs", lambda root: bool(list(root.glob("**/*.md"))),
     ["yzhang.markdown-all-in-one"]),
    ("YAML / config", lambda root: bool(list(root.glob("**/*.yaml")) or list(root.glob("**/*.yml"))),
     ["redhat.vscode-yaml"]),
    ("JSON Schema", lambda root: bool(list(root.glob("**/*.schema.json"))),
     ["redhat.vscode-yaml"]),
    ("Shell scripts", lambda root: bool(list(root.glob("**/*.sh"))),
     ["timonwong.shellcheck"]),
    ("JavaScript / TypeScript", lambda root: bool(list(root.glob("**/*.js")) or list(root.glob("**/*.ts"))),
     ["dbaeumer.vscode-eslint", "esbenp.prettier-vscode"]),
    ("Git / GitHub", lambda root: (root / ".git").exists(),
     ["github.vscode-github-actions", "eamodio.gitlens"]),
    ("Docker", lambda root: bool(list(root.glob("**/Dockerfile*")) or list(root.glob("**/docker-compose*"))),
     ["ms-azuretools.vscode-docker"]),
    ("Claude Code / AI", lambda root: bool(list((root / ".claude").rglob("*")) if (root / ".claude").exists() else []),
     []),  # No specific extension needed — Claude Code has its own
    ("Go", lambda root: bool(list(root.glob("**/*.go"))),
     ["golang.go"]),
    ("Rust", lambda root: bool(list(root.glob("**/*.rs"))),
     ["rust-lang.rust-analyzer"]),
    ("C / C++", lambda root: bool(list(root.glob("**/*.c")) or list(root.glob("**/*.cpp")) or list(root.glob("**/*.h"))),
     ["ms-vscode.cpptools"]),
]


def find_project_root() -> Path:
    """Find the project root (git toplevel or cwd)."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, cwd=os.getcwd()
        )
        return Path(result.stdout.strip())
    except Exception:
        return Path(os.getcwd()).resolve()


def load_installed_extensions() -> dict:
    """Read ~/.vscode/extensions/extensions.json to get real UUIDs."""
    ext_json = Path.home() / ".vscode" / "extensions" / "extensions.json"
    if not ext_json.exists():
        # macOS path
        ext_json = Path.home() / "Library" / "Application Support" / "Code" / "User" / "extensions.json"

    uuid_map = {}
    if ext_json.exists():
        with open(ext_json) as f:
            all_exts = json.load(f)
        for ext in all_exts:
            eid = ext.get("identifier", {}).get("id", "")
            uid = ext.get("identifier", {}).get("uuid", "")
            if eid and uid:
                uuid_map[eid] = uid
    return uuid_map


def find_workspace_storage(project_path: str) -> str | None:
    """Locate the workspaceStorage directory for the given project."""
    ws_base = Path.home() / ".config" / "Code" / "User" / "workspaceStorage"
    if not ws_base.exists():
        # macOS
        ws_base = Path.home() / "Library" / "Application Support" / "Code" / "User" / "workspaceStorage"

    if not ws_base.exists():
        return None

    for d in ws_base.iterdir():
        ws_file = d / "workspace.json"
        if ws_file.exists():
            try:
                with open(ws_file) as f:
                    data = json.load(f)
                folder = data.get("folder", "")
                if isinstance(folder, str):
                    if project_path in folder:
                        return str(d)
                elif isinstance(folder, dict):
                    if project_path in folder.get("uri", ""):
                        return str(d)
            except Exception:
                continue
    return None


def analyze_project(root: Path) -> list[str]:
    """Scan project and return matching extension IDs."""
    matched = set()
    for desc, detector, exts in FILE_MATCHERS:
        try:
            if detector(root):
                print(f"  Detected: {desc}")
                for eid in exts:
                    matched.add(eid)
        except Exception:
            pass
    return sorted(matched)


def enable_extensions_for_workspace(
    project_path: str,
    extension_ids: list[str],
    uuid_map: dict,
    dry_run: bool = False
) -> tuple[int, list[str]]:
    """Write enabled extensions to state.vscdb."""
    ws_dir = find_workspace_storage(project_path)
    if not ws_dir:
        return 0, [], "Workspace storage not found. Open the project in VS Code first."

    # Build enabled list with real UUIDs
    enabled = []
    missing = []
    for eid in extension_ids:
        uid = uuid_map.get(eid)
        if uid:
            enabled.append({"id": eid, "uuid": uid})
        else:
            missing.append(eid)

    if dry_run:
        return len(enabled), missing, None

    ws_db = os.path.join(ws_dir, "state.vscdb")
    if not os.path.exists(ws_db):
        return 0, missing, f"state.vscdb not found at {ws_db}"

    conn = sqlite3.connect(ws_db)
    cur = conn.cursor()
    cur.execute(
        "REPLACE INTO ItemTable (key, value) VALUES ('extensionsIdentifiers/enabled', ?)",
        (json.dumps(enabled),),
    )
    conn.commit()
    conn.close()

    return len(enabled), missing, None


def main():
    dry_run = "--dry-run" in sys.argv
    action = "Would enable" if dry_run else "Enabling"

    print("=== VS Code Workspace Extension Match ===")
    print(f"Project: {find_project_root()}")
    print()

    # 1. Analyze project content
    print("Analyzing project content...")
    matched = analyze_project(find_project_root())
    if not matched:
        print("  No matching file types detected.")
        return
    print(f"  Matched {len(matched)} extension(s)")
    print()

    # 2. Load installed extension UUIDs
    uuid_map = load_installed_extensions()
    print(f"Loaded {len(uuid_map)} installed extension(s) from extensions.json")
    print()

    # 3. Enable for workspace
    project_path = str(find_project_root())
    count, missing, error = enable_extensions_for_workspace(
        project_path, matched, uuid_map, dry_run
    )

    if error:
        print(f"Warning: {error}")
        return

    print(f"{action} {count} extension(s) for this workspace:")
    for eid in matched:
        status = "✓" if eid in uuid_map else "✗ (not installed)"
        print(f"  {status} {eid}")

    if missing:
        print()
        print(f"Not installed ({len(missing)}):")
        for eid in missing:
            print(f"  - {eid}")
        print("Install via: code --install-extension <id>")

    if not dry_run:
        print()
        print("Done. Restart VS Code for changes to take effect.")


if __name__ == "__main__":
    main()
