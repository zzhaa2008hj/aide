#!/usr/bin/env python3
"""
Smart workspace extension manager for VS Code.

Deep project analysis → enables matching extensions, disables irrelevant ones.

Workflow:
  1. package.json → frameworks, build tools, CSS tools, UI libs, test tools
  2. Config files at root → ESLint, Prettier, TypeScript (tsconfig)
  3. File types in src/ + root → .vue, .css, .py, .go, .md, etc.
  4. Cross-reference with ~/.vscode/extensions/extensions.json for UUIDs
  5. Write enabled + disabled lists to workspace state.vscdb

Matched extensions → enabled (whitelist add + disabled-list remove).
Non-matched installed extensions → disabled (reverse), unless ALWAYS_KEEP.

Usage: python3 manage_extensions.py [--dry-run]
"""

import json
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

# ── Dirs excluded from all file-type scanning ──────────────────────────
SKIP_DIRS = {'node_modules', '.git', 'dist', 'build', '__pycache__',
             '.next', '.nuxt', 'venv', '.venv', '.aide', 'coverage',
             '.claude', 'workflows'}

# ── Priority dirs for source-code scanning ────────────────────────────
PRIORITY_DIRS = ['src', 'lib', 'app', 'public', 'tests', 'test', 'pages',
                 'components', 'layouts', 'plugins', 'middleware']


# ══════════════════════════════════════════════════════════════════════════
# Extensions that are NEVER auto-disabled — they're always useful
# regardless of project type.
# ══════════════════════════════════════════════════════════════════════════
ALWAYS_KEEP = {
    # AI assistants
    "anthropic.claude-code",
    "google.geminicodeassist",
    "openai.chatgpt",
    "tencent-cloud.coding-copilot",
    # Language packs
    "ms-ceintl.vscode-language-pack-zh-hans",
    # Remote dev / collaboration
    "ms-vscode-remote.remote-ssh",
    "ms-vscode-remote.remote-ssh-edit",
    "ms-vscode.remote-explorer",
    "ms-vsliveshare.vsliveshare",
    # Jupyter (useful across projects)
    "ms-toolsai.jupyter",
    "ms-toolsai.jupyter-keymap",
    "ms-toolsai.jupyter-renderers",
    "ms-toolsai.vscode-jupyter-cell-tags",
    "ms-toolsai.vscode-jupyter-slideshow",
    # VS Code built-in / meta
    "vscode-icons-team.vscode-icons",
    "oderwat.indent-rainbow",
    "eamodio.gitlens",
    "gruntfuggly.todo-tree",
    "usernamehw.errorlens",
    "esbenp.prettier-vscode",
    "formulahendry.code-runner",
    "antfu.browse-lite",
    "tal7aouy.rainbow-bracket",
    # Version managers
    "henrynguyen5-vsc.vsc-nvm",
    "nojsja.vscode-nvm",
}


# ══════════════════════════════════════════════════════════════════════════
# Feature → Extension Mapping
# ══════════════════════════════════════════════════════════════════════════

FEATURE_MAP = {
    # ── Vue ecosystem ──
    "vue3": [
        "vue.volar",
    ],
    "vue2": [
        "octref.vetur",
        "nicholashsiang.vscode-vue2-snippets",
    ],
    "vue": [
        "sdras.vue-vscode-snippets",
        "dariofuzinato.vue-peek",
        "hollowtree.vue-snippets",
        "oysun.vuehelper",
        "amayakite.aya-vue3-extension-pack",
    ],
    "vue_files": [
        "vue.volar",
    ],
    "ant-design-vue": ["ant-design-vue.vscode-ant-design-vue-helper"],
    "element-ui": ["elemefe.vscode-element-helper", "ss.element-ui-snippets"],
    "element-plus": ["elemefe.vscode-element-helper"],

    # ── React ecosystem ──
    "react": [
        "dsznajder.es7-react-js-snippets",
        "msjsdiag.vscode-react-native",
        "burkeholland.simple-react-snippets",
        "infeng.vscode-react-typescript",
        "planbcoding.vscode-react-refactor",
    ],

    # ── Angular ──
    "angular": [
        "angular.ng-template",
        "cyrilletuzi.angular-schematics",
    ],

    # ── Svelte ──
    "svelte": ["svelte.svelte-vscode"],

    # ── Build tools ──
    "vite": ["antfu.vite"],
    "webpack": ["amodio.webpack-problem-matchers"],

    # ── CSS / Styling ──
    "tailwind": ["bradlc.vscode-tailwindcss"],
    "scss": [
        "sibiraj-s.vscode-scss-formatter",
        "mrmlnc.vscode-scss",
        "glen-84.sass-lint",
    ],
    "less": ["mrcrowl.easy-less"],
    "css": [
        "ecmel.vscode-html-css",
        "zignd.html-css-class-completion",
    ],
    "css_in_js": [
        "styled-components.vscode-styled-components",
        "jpoissonnier.vscode-styled-components",
    ],

    # ── HTML ──
    "html": [
        "formulahendry.auto-rename-tag",
        "vincaslt.highlight-matching-tag",
    ],

    # ── JavaScript / TypeScript ──
    "javascript": [
        "dbaeumer.vscode-eslint",
        "steoates.autoimport",
        "wix.vscode-import-cost",
        "christian-kohler.path-intellisense",
        "xabikos.javascriptsnippets",
        "pflannery.vscode-versionlens",
        "letrieu.expand-region",
    ],
    "typescript": [
        "dbaeumer.vscode-eslint",
        "steoates.autoimport",
        "pflannery.vscode-versionlens",
    ],

    # ── Lint / Format ──
    "eslint_config": ["dbaeumer.vscode-eslint"],
    "prettier_config": ["esbenp.prettier-vscode"],

    # ── Testing ──
    "vitest": ["vitest.explorer"],
    "jest": ["orta.vscode-jest", "firsttris.vscode-jest-runner"],

    # ── File-type based ──
    "dotenv": ["mikestead.dotenv"],
    "markdown": [
        "yzhang.markdown-all-in-one",
        "shd101wyy.markdown-preview-enhanced",
        "davidanson.vscode-markdownlint",
    ],
    "python": [
        "ms-python.python",
        "ms-python.debugpy",
        "charliermarsh.ruff",
        "ms-python.vscode-pylance",
        "ms-python.vscode-python-envs",
    ],
    "go": ["golang.go"],
    "rust": ["rust-lang.rust-analyzer"],
    "shell": ["timonwong.shellcheck"],
    "c_cpp": ["ms-vscode.cpptools"],
    "yaml": ["redhat.vscode-yaml"],
    "docker": ["ms-azuretools.vscode-docker"],
    "svg": ["jock.svg"],

    # ── C# / .NET ──
    "csharp": [
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "ms-dotnettools.vscode-dotnet-runtime",
    ],

    # ── PHP / Laravel ──
    "laravel": [
        "pgl.laravel-jump-controller",
        "amiralizadeh9480.laravel-extra-intellisense",
        "onecentlin.laravel-blade",
        "onecentlin.laravel5-snippets",
    ],

    # ── GraphQL ──
    "graphql": [
        "graphql.vscode-graphql",
        "graphql.vscode-graphql-syntax",
    ],

    # ── Git ──
    "git": [
        "github.vscode-github-actions",
        "github.vscode-pull-request-github",
    ],

    # ── General web (any package.json project) ──
    "general_web": [
        "tal7aouy.rainbow-bracket",
        "ritwickdey.liveserver",
        "formulahendry.code-runner",
        "christian-kohler.path-intellisense",
        "letrieu.expand-region",
    ],
}


# ══════════════════════════════════════════════════════════════════════════
# Feature Detection
# ══════════════════════════════════════════════════════════════════════════

def read_package_json(root: Path) -> dict | None:
    pkg_path = root / "package.json"
    if not pkg_path.exists():
        return None
    try:
        with open(pkg_path) as f:
            return json.load(f)
    except Exception:
        return None


def detect_package_features(pkg: dict) -> set[str]:
    features = set()
    deps = {
        k.lower(): v
        for k, v in {
            **pkg.get("dependencies", {}),
            **pkg.get("devDependencies", {}),
        }.items()
    }

    # ── Frameworks ──
    if "vue" in deps:
        vue_raw = deps["vue"].lstrip("^~>=< ")
        if vue_raw.startswith("3") or "3." in vue_raw:
            features.add("vue3")
        elif vue_raw.startswith("2") or "2." in vue_raw:
            features.add("vue2")
        else:
            features.add("vue3")
        features.add("vue")

    if "react" in deps or "react-dom" in deps:
        features.add("react")
    if "next" in deps:
        features.add("react")
    if "nuxt" in deps or "@nuxt" in deps:
        features.add("vue")
    if "svelte" in deps or "@sveltejs" in deps:
        features.add("svelte")
    if "@angular/core" in deps:
        features.add("angular")

    # ── Build tools ──
    if "vite" in deps:
        features.add("vite")
    if "webpack" in deps or "webpack-cli" in deps:
        features.add("webpack")

    # ── CSS tools ──
    if "tailwindcss" in deps or "@tailwindcss" in deps:
        features.add("tailwind")
    if "sass" in deps or "node-sass" in deps:
        features.add("scss")
    if "less" in deps:
        features.add("less")
    if "styled-components" in deps or "@emotion" in deps:
        features.add("css_in_js")

    # ── UI libraries ──
    if "ant-design-vue" in deps:
        features.add("ant-design-vue")
    if "element-ui" in deps:
        features.add("element-ui")
    if "element-plus" in deps:
        features.add("element-plus")

    # ── Language ──
    if "typescript" in deps:
        features.add("typescript")

    # ── Testing ──
    if "vitest" in deps:
        features.add("vitest")
    if "jest" in deps or "@jest" in deps:
        features.add("jest")

    # ── GraphQL ──
    if "graphql" in deps or "@apollo" in deps:
        features.add("graphql")

    # ── Docker hints from npm scripts ──
    for val in pkg.get("scripts", {}).values():
        if isinstance(val, str) and "docker" in val.lower():
            features.add("docker")
            break

    # Any package.json implies a web project
    features.add("general_web")

    return features


def has_config(root: Path, *globs: str) -> bool:
    """Check for config files at project root (non-recursive)."""
    for g in globs:
        for p in root.glob(g):
            if p.is_file():
                return True
    return False


def _scan_priority_dirs(root: Path, pattern: str) -> bool:
    for dname in PRIORITY_DIRS:
        d = root / dname
        if not d.is_dir():
            continue
        try:
            for _ in d.rglob(pattern):
                return True
        except PermissionError:
            continue
    return False


def _scan_root_level(root: Path, pattern: str) -> bool:
    try:
        for _ in root.glob(pattern):
            return True
    except PermissionError:
        pass
    return False


def has_pattern(root: Path, pattern: str, *,
                source_only: bool = False) -> bool:
    """Check for files matching pattern with smart directory priority."""
    if _scan_priority_dirs(root, pattern):
        return True
    if _scan_root_level(root, pattern):
        return True
    if source_only:
        return False

    try:
        for p in root.iterdir():
            if p.name in SKIP_DIRS or p.name.startswith('.'):
                continue
            if p.is_dir():
                try:
                    for _ in p.rglob(pattern):
                        return True
                except PermissionError:
                    continue
            elif p.match(pattern):
                return True
    except PermissionError:
        pass
    return False


def detect_file_features(root: Path) -> set[str]:
    features = set()

    # ── Config files at project root ──
    if has_config(root, ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.yaml",
                  ".eslintrc.yml", ".eslintrc.json", ".eslintrc"):
        features.add("eslint_config")
    if has_config(root, ".prettierrc", ".prettierrc.js", ".prettierrc.json",
                  ".prettierrc.yaml", ".prettierrc.yml", ".prettierrc.toml",
                  "prettier.config.js", "prettier.config.cjs"):
        features.add("prettier_config")
    if has_config(root, "tsconfig.json", "tsconfig.*.json"):
        features.add("typescript")

    # ── Frameworks (file-based) ──
    if has_pattern(root, "*.vue"):
        features.add("vue_files")
    if has_pattern(root, "*.jsx") or has_pattern(root, "*.tsx"):
        features.add("react")
    if has_pattern(root, "*.svelte"):
        features.add("svelte")

    # ── Styles ──
    if has_pattern(root, "*.css"):
        features.add("css")
    if has_pattern(root, "*.scss"):
        features.add("scss")
    if has_pattern(root, "*.less"):
        features.add("less")

    # ── HTML ──
    if has_pattern(root, "*.html") or has_pattern(root, "*.htm"):
        features.add("html")

    # ── Scripts ──
    if has_pattern(root, "*.js"):
        features.add("javascript")
    if has_pattern(root, "*.ts"):
        features.add("typescript")

    # ── Config / Data files ──
    if has_pattern(root, "*.yaml") or has_pattern(root, "*.yml"):
        features.add("yaml")
    if has_pattern(root, "*.env*"):
        features.add("dotenv")

    # ── Documents ──
    if has_pattern(root, "*.md"):
        features.add("markdown")

    # ── Images / Vector ──
    if has_pattern(root, "*.svg"):
        features.add("svg")

    # ── Backend languages (source dirs + root only) ──
    if has_pattern(root, "*.py", source_only=True):
        features.add("python")
    if has_pattern(root, "*.go", source_only=True):
        features.add("go")
    if has_pattern(root, "*.rs", source_only=True):
        features.add("rust")
    if has_pattern(root, "*.sh", source_only=True):
        features.add("shell")
    if has_pattern(root, "*.c", source_only=True) or \
       has_pattern(root, "*.cpp", source_only=True) or \
       has_pattern(root, "*.h", source_only=True):
        features.add("c_cpp")
    if has_pattern(root, "*.cs", source_only=True) or \
       has_pattern(root, "*.csproj", source_only=True):
        features.add("csharp")
    if has_pattern(root, "*.php", source_only=True):
        features.add("php")
    if has_pattern(root, "*.graphql", source_only=True) or \
       has_pattern(root, "*.gql", source_only=True):
        features.add("graphql")

    # ── Docker ──
    if has_pattern(root, "Dockerfile*") or has_pattern(root, "docker-compose*"):
        features.add("docker")

    # ── Config file hints (recursive) ──
    if has_pattern(root, "vite.config.*"):
        features.add("vite")
    if has_pattern(root, "webpack.config.*"):
        features.add("webpack")
    if has_pattern(root, "tailwind.config.*"):
        features.add("tailwind")
    if has_pattern(root, "jest.config.*"):
        features.add("jest")

    # ── Git ──
    if (root / ".git").exists():
        features.add("git")

    # ── Laravel ──
    if (root / "artisan").exists():
        features.add("laravel")

    # ── Nuxt ──
    if (root / "nuxt.config.ts").exists() or (root / "nuxt.config.js").exists():
        features.add("vue")

    return features


# ══════════════════════════════════════════════════════════════════════════
# Workspace Storage
# ══════════════════════════════════════════════════════════════════════════

def find_project_root() -> Path:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, cwd=os.getcwd(),
        )
        return Path(result.stdout.strip())
    except Exception:
        return Path(os.getcwd()).resolve()


def load_installed_extensions() -> dict:
    """Read extensions.json → {ext_id: uuid} from any known location."""
    candidates = [
        Path.home() / ".vscode" / "extensions" / "extensions.json",
        Path.home() / ".vscode-server" / "extensions" / "extensions.json",
        Path.home() / "Library" / "Application Support" / "Code" / "User" / "extensions.json",
    ]
    uuid_map = {}
    for ext_json in candidates:
        if not ext_json.exists():
            continue
        with open(ext_json) as f:
            all_exts = json.load(f)
        for ext in all_exts:
            eid = ext.get("identifier", {}).get("id", "")
            uid = ext.get("identifier", {}).get("uuid", "")
            if eid and uid:
                uuid_map[eid] = uid
        if uuid_map:
            break
    return uuid_map


def find_workspace_storage(project_path: str) -> str | None:
    ws_bases = [
        Path.home() / ".config" / "Code" / "User" / "workspaceStorage",
        Path.home() / "Library" / "Application Support" / "Code" / "User" / "workspaceStorage",
    ]
    for ws_base in ws_bases:
        if not ws_base.exists():
            continue
        for d in ws_base.iterdir():
            ws_file = d / "workspace.json"
            if not ws_file.exists():
                continue
            try:
                with open(ws_file) as f:
                    data = json.load(f)
                folder = data.get("folder", "")
                if isinstance(folder, str) and project_path in folder:
                    return str(d)
                if isinstance(folder, dict) and project_path in folder.get("uri", ""):
                    return str(d)
            except Exception:
                continue
    return None


# ══════════════════════════════════════════════════════════════════════════
# Core Logic
# ══════════════════════════════════════════════════════════════════════════

def analyze_project(root: Path) -> dict[str, list[str]]:
    """Detect features and map to extension IDs."""
    result = {}

    pkg = read_package_json(root)
    if pkg:
        for feat in sorted(detect_package_features(pkg)):
            exts = FEATURE_MAP.get(feat, [])
            if exts:
                result[f"pkg → {feat}"] = exts

    for feat in sorted(detect_file_features(root)):
        exts = FEATURE_MAP.get(feat, [])
        if exts:
            label = f"files → {feat}"
            if label not in result:
                result[label] = exts

    return result


def _is_always_keep(ext_id: str) -> bool:
    """Check if an extension ID is in the always-keep set."""
    if ext_id in ALWAYS_KEEP:
        return True
    # Also match by prefix for extensions with versioned dirs
    for keep in ALWAYS_KEEP:
        if ext_id.startswith(keep) and (len(ext_id) == len(keep) or ext_id[len(keep)] == '-'):
            return True
    return False


def compute_actions(
    matched_ids: set[str],
    installed_map: dict,
) -> tuple[set[str], set[str], set[str]]:
    """Compute which extensions to enable, disable, or keep.

    Returns (to_enable, to_disable, kept) — sets of extension IDs.
    - to_enable: matched + installed → add to whitelist, remove from disabled
    - to_disable: installed but NOT matched and NOT always-keep → disable
    - kept: always-keep extensions (left alone)
    """
    installed_ids = set(installed_map.keys())

    to_enable = {eid for eid in matched_ids if eid in installed_ids}
    to_disable = set()
    kept = set()

    for eid in installed_ids:
        if eid in matched_ids:
            continue  # Already handled as to_enable
        if _is_always_keep(eid):
            kept.add(eid)
        else:
            to_disable.add(eid)

    return to_enable, to_disable, kept


def apply_workspace_state(
    project_path: str,
    to_enable: set[str],
    to_disable: set[str],
    uuid_map: dict,
    dry_run: bool = False,
) -> tuple[int, int, int, int, str | None]:
    """Write enabled/disabled lists to state.vscdb.

    Returns (enabled_new, already_enabled, disabled_new, already_disabled, error).
    """
    ws_dir = find_workspace_storage(project_path)
    if not ws_dir:
        return 0, 0, 0, 0, "Workspace storage not found. Open the project in VS Code first."

    if dry_run:
        return len(to_enable), 0, len(to_disable), 0, None

    ws_db = os.path.join(ws_dir, "state.vscdb")
    if not os.path.exists(ws_db):
        return 0, 0, 0, 0, f"state.vscdb not found at {ws_db}"

    conn = sqlite3.connect(ws_db)
    cur = conn.cursor()

    # ── Read current state ──
    cur.execute(
        "SELECT value FROM ItemTable WHERE key = 'extensionsIdentifiers/enabled'"
    )
    row = cur.fetchone()
    whitelist = json.loads(row[0]) if row else []

    cur.execute(
        "SELECT value FROM ItemTable WHERE key = 'extensionsIdentifiers/disabled'"
    )
    row = cur.fetchone()
    blacklist = json.loads(row[0]) if row else []

    # ── Track changes ──
    whitelist_uuids = {e["uuid"] for e in whitelist}
    blacklist_uuids = {e["uuid"] for e in blacklist}

    enabled_new = 0
    already_enabled = 0
    disabled_new = 0
    already_disabled = 0

    # ── Enable: add to whitelist, remove from blacklist ──
    for eid in sorted(to_enable):
        uid = uuid_map.get(eid)
        if not uid:
            continue
        if uid not in whitelist_uuids:
            whitelist.append({"id": eid, "uuid": uid})
            whitelist_uuids.add(uid)
            enabled_new += 1
        else:
            already_enabled += 1

    new_blacklist = []
    for entry in blacklist:
        if entry["uuid"] in {uuid_map.get(e) for e in to_enable if uuid_map.get(e)}:
            continue  # Remove from disabled
        new_blacklist.append(entry)
    removed_from_blacklist = len(blacklist) - len(new_blacklist)
    blacklist = new_blacklist

    # ── Disable: add to blacklist, remove from whitelist ──
    for eid in sorted(to_disable):
        uid = uuid_map.get(eid)
        if not uid:
            continue
        if uid not in blacklist_uuids:
            blacklist.append({"id": eid, "uuid": uid})
            blacklist_uuids.add(uid)
            disabled_new += 1
        else:
            already_disabled += 1

    new_whitelist = []
    for entry in whitelist:
        if entry["uuid"] in {uuid_map.get(e) for e in to_disable if uuid_map.get(e)}:
            continue  # Remove from enabled
        new_whitelist.append(entry)
    whitelist = new_whitelist

    # ── Write ──
    cur.execute(
        "REPLACE INTO ItemTable (key, value) VALUES ('extensionsIdentifiers/enabled', ?)",
        (json.dumps(whitelist),),
    )
    cur.execute(
        "REPLACE INTO ItemTable (key, value) VALUES ('extensionsIdentifiers/disabled', ?)",
        (json.dumps(blacklist),),
    )

    conn.commit()
    conn.close()

    return enabled_new, already_enabled, disabled_new, already_disabled, None


# ══════════════════════════════════════════════════════════════════════════
# Report formatting
# ══════════════════════════════════════════════════════════════════════════

def _fmt_ext_list(ext_ids: set[str], uuid_map: dict) -> str:
    """Format extension list with install status."""
    lines = []
    for eid in sorted(ext_ids):
        marker = "✓" if eid in uuid_map else "✗"
        lines.append(f"    {marker} {eid}")
    return "\n".join(lines)


def _reload_vscode_window():
    """Attempt to reload VS Code window."""
    try:
        result = subprocess.run(
            ["code", "--reload-window"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            print("  ✓ Triggered VS Code window reload")
        else:
            print("  ⚠ Could not reload VS Code window — Reload Window manually")
            print("    (Ctrl+Shift+P → Developer: Reload Window)")
    except FileNotFoundError:
        print("  ⚠ 'code' CLI not found — Reload Window manually")
        print("    (Ctrl+Shift+P → Developer: Reload Window)")
    except Exception:
        pass


# ══════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════

def main():
    dry_run = "--dry-run" in sys.argv

    print("═══ VS Code Workspace Extension Manager ═══")
    root = find_project_root()
    print(f"Project: {root}\n")

    # ── 1. Analyze project ──
    print("── Analyzing project content…")
    feature_map = analyze_project(root)

    matched_ids = set()
    for feat, exts in feature_map.items():
        installed_count = sum(1 for e in exts if e in load_installed_extensions())
        print(f"  {feat}  →  {installed_count}/{len(exts)} installed")
        matched_ids.update(exts)

    # ── 2. Load installed extensions ──
    uuid_map = load_installed_extensions()
    installed_ids = set(uuid_map.keys())

    if not installed_ids:
        print("\n  No extensions.json found — cannot determine installed extensions.")
        return

    print(f"\n  Total installed: {len(installed_ids)} extensions")

    # ── 3. Compute actions ──
    to_enable, to_disable, kept = compute_actions(matched_ids, uuid_map)

    # ── 4. Report plan ──
    print(f"\n── Action Plan {'(DRY RUN)' if dry_run else ''} ──")
    print(f"  ✅ Enable:  {len(to_enable)} extension(s)")
    print(f"  🚫 Disable: {len(to_disable)} extension(s)")
    print(f"  🔒 Keep:    {len(kept)} extension(s) (always useful)")

    if to_enable:
        print(f"\n  ── To Enable ──")
        print(_fmt_ext_list(to_enable, uuid_map))

    if to_disable:
        print(f"\n  ── To Disable ──")
        print(_fmt_ext_list(to_disable, uuid_map))

    if kept:
        print(f"\n  ── Kept Active (always useful) ──")
        print(_fmt_ext_list(kept, uuid_map))

    # ── 5. Apply ──
    project_path = str(root)
    enabled_new, already_en, disabled_new, already_dis, error = \
        apply_workspace_state(project_path, to_enable, to_disable,
                              uuid_map, dry_run)

    if error:
        print(f"\n⚠ Error: {error}")
        return

    if not dry_run:
        print(f"\n── Results ──")
        if enabled_new:
            print(f"  ✓ Enabled {enabled_new} extension(s)")
        if already_en:
            print(f"  ℹ {already_en} already enabled")
        if disabled_new:
            print(f"  ✓ Disabled {disabled_new} extension(s)")
        if already_dis:
            print(f"  ℹ {already_dis} already disabled")
        if not enabled_new and not disabled_new:
            print("  ℹ Workspace already in optimal state")

        _reload_vscode_window()

    # ── 6. Not installed hints ──
    not_installed = {e for e in matched_ids if e not in installed_ids}
    if not_installed:
        print(f"\n── Not Installed ({len(not_installed)}) ──")
        for eid in sorted(not_installed):
            print(f"  ✗ {eid}")
        print("\n  Install via: code --install-extension <id>")

    if not dry_run:
        print("\nDone. If changes don't apply, fully quit and reopen VS Code.")


if __name__ == "__main__":
    main()
