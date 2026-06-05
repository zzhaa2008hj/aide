# deepcode-cli Upgrade Mechanism

## Overview

Add a standalone update script `update-deepcode-cli.sh` for deepcode-cli users, enabling them to check for and apply AIDE updates (skills + schemas). Reuses the existing `plugin.json` version as the single source of truth — same file Claude Code's `claude plugin update` reads — so version numbers never drift between distributions.

## Motivation

| Distribution | Install | Upgrade |
|-------------|---------|---------|
| Claude Code | `claude plugin install aide@aide` | `claude plugin update aide@aide` + `/aide-update` |
| deepcode-cli | `install-deepcode-cli.sh` | **none** |

Without an upgrade path, deepcode-cli users are stuck on whichever version they installed. They must manually re-run the install script (which is destructive) to get updates.

## Architecture

```
update-deepcode-cli.sh
├── Step 0: Preflight — verify we're in a deepcode-cli project
│           (check .agents/skills/aide/SKILL.md exists)
├── Step 1: Read local version from .aide/version
├── Step 2: Fetch repo's plugin.json via curl → extract latest version
├── Step 3: Compare
│   ├── Same or local newer → "Already up to date" → exit 0
│   └── Repo newer → Step 4
├── Step 4: Sparse checkout (same mechanism as install-deepcode-cli.sh)
│           → fetch skills + schemas from repo at latest ref
├── Step 5: Write new version to .aide/version
└── Step 6: Report — version delta, updated skills count
```

### Principle

- **Version source of truth**: repo's `plugin.json` (shared with Claude Code distribution)
- **Stateless update**: no `.git` directory preserved; each update is a clean sparse checkout
- **Safe**: never touches `.aide/output/` or `state.json`; pipeline artifacts are untouched

## Deliverables

| File | Action | Description |
|------|--------|-------------|
| `aide_deepcode/update-deepcode-cli.sh` | **NEW** | Update script (~60 lines) |
| `aide_deepcode/install-deepcode-cli.sh` | **MODIFY** | Add version file write at end of install |

## Key Design Decisions

### Version tracking

- **Source**: `curl` to GitHub raw for `plugin.json`, extract `version` field with `python3 -c`
- **Local**: `.aide/version` — plain text file containing the version string (e.g., `1.0.26`)
- **Comparison**: semantic comparison via `python3` tuple unpacking `MAJ, MIN, PAT = map(int, version.split('.'))` — consistent with `bump-version.sh` and `install-deepcode-cli.sh` usage

### Update mechanism

Sparse checkout (same as install), not incremental git pull:
- Payload is under 50KB — bandwidth is negligible
- No `.git` directory to corrupt
- No changes needed to existing install behavior
- Trade-off: re-downloads all skill files even when only one changed (acceptable at <50KB)

### Invocation

```bash
bash update-deepcode-cli.sh
```

Must be run from project root (same convention as `install-deepcode-cli.sh`). Takes no arguments. Respects `AIDE_REPO` and `AIDE_REF` environment variables (same as install script) for custom source repos or branches.

### Scope

Only skills and schemas:
- `.agents/skills/{aide,aide-spec,aide-plan,aide-test,aide-continue,aide-init}/SKILL.md`
- `.aide/schemas/*.json`

Never touches:
- `.aide/output/` — pipeline artifacts
- `.aide/state.json` — pipeline state
- `.aide/version` — except to write the new version

## Changes to install-deepcode-cli.sh

One addition after step 4 (schema copy): write `.aide/version`:

```bash
# After schemas are copied, record the installed version
VERSION=$(python3 -c "
import json
data = json.load(open('$TMP_DIR/.claude-plugin/plugin.json'))
print(data['version'])
" 2>/dev/null || echo "unknown")
echo "$VERSION" > .aide/version
echo "  Version: $VERSION written to .aide/version"
```

This requires the sparse checkout to also include `.claude-plugin/plugin.json`. Update the sparse-checkout set line:

```bash
git sparse-checkout set skills aide-core/schemas .claude-plugin/plugin.json
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Not in a project (no `.agents/skills/aide/SKILL.md`) | Error: "No deepcode-cli AIDE install detected. Run install-deepcode-cli.sh first." |
| No `.aide/version` file (legacy install) | Treat as version "0.0.0", proceed with update |
| `.aide/version` is "unknown" (python3 missing at install) | Treat as version "0.0.0", proceed with update |
| Network failure fetching `plugin.json` | Error: "Cannot reach GitHub. Check your connection." |
| Sparse checkout fails | Error: "Update failed. Your existing install is unchanged." |
| Already up to date | Info: "AIDE is already at the latest version (1.0.26)." |

## Out of Scope

- Auto-update on startup / cron
- DeepCode IDE plugins (frozen — no longer supported per scope decision)
- Mid-pipeline safety checks (update is always safe — skills are read fresh each stage invocation)
- Rollback to previous version
- Update notification / changelog display
