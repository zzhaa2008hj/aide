# AIDE for CodeWhale

AIDE is also available as a [CodeWhale](https://github.com/Hmbown/CodeWhale) skill. Install via CodeWhale's native skill installer.

> Main project: [README.md](README.md)

## Install

```bash
# 从 master 分支安装（稳定版）
curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/aide-core/scripts/install-codewhale.sh | bash

# 从 develop 分支安装（开发版）
curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/aide-core/scripts/install-codewhale.sh | AIDE_REF=develop bash
```

This script installs **two** skills to `~/.codewhale/` (global by default):
1. Writes `.aide/version` — version tracking (via `plugin.json`)
2. Sets up slash commands in `~/.codewhale/commands/` — autocomplete for both skills
3. Downloads `aide` + `aide-fix` SKILL.md to `~/.codewhale/skills/`
4. Copies `update.sh` to `.aide/update-codewhale.sh` — future upgrades
5. Verifies all 4 files were written successfully

For project-local install:
```bash
SKILLS_DIR=.agents/skills COMMANDS_DIR=.codewhale/commands bash install.sh
```

After the script, restart CodeWhale — both skills are auto-discovered. Invoke via `/aide "<description>"` or `/aide-fix "<bug description>"`.

## Update

```bash
# 更新到当前分支最新
bash .aide/update-codewhale.sh

# 从 develop 分支更新
AIDE_REF=develop bash .aide/update-codewhale.sh
```

Checks `.aide/version` against the latest, refreshes both `aide` and `aide-fix` skill files and slash commands, prints `/skill update aide`.

## Fix Pipeline (`/aide-fix`)

The fix pipeline is a lightweight alternative for rapid bug fixes:

| Order | Stage     | Description                         |
|-------|-----------|-------------------------------------|
| 1     | analyze   | Root cause → scope fence            |
| 2     | implement | Scope-fenced code changes           |
| 3     | test      | Verify + auto-retry (max 2)        |

Invoke via `/aide-fix "<bug description>"`. Backend-agnostic — works identically under both deepcode-cli and CodeWhale. Both `aide` and `aide-fix` are installed together by the install script.

## Differences from deepcode-cli

| Aspect | deepcode-cli | CodeWhale |
|--------|-------------|-----------|
| Implement stage | Serial task execution | Parallel subagent dispatch via `agent_open` (max 3 per batch) |
| Install | curl + bash | `curl -sSL ... \| bash` (both skills) |
| Update | `bash .aide/update-deepcode-cli.sh` | `bash .aide/update-codewhale.sh` (both skills) |
| Skill discovery | `.agents/skills/` | `.agents/skills/` → `~/.codewhale/skills/` |
| Orchestrator | Reads external stage skills | Fully self-contained (all stages inline) |
| Pipeline protocol | References `aide-core/pipeline-protocol.md` | All rules inlined in SKILL.md |
| Invocation | `/aide`, `/aide-fix` | `$aide` or `/aide`, `$aide-fix` or `/aide-fix` |

Stage-specific skills (`aide-spec`, `aide-plan`, `aide-test`) are shared between all orchestrators in the monorepo, but the CodeWhale orchestrator embeds all workflows inline so it works after a single `/skill install`.

## Implement stage (CodeWhale-specific)

The CodeWhale orchestrator uses `agent_open` for dependency-aware parallel task dispatch:

1. Reads `plan.json`, resolves dependencies via topological sort
2. Batches mutually independent tasks (no `depends_on` intersection within a batch)
3. Dispatches up to 3 tasks per batch via `agent_open` (non-blocking)
4. Waits for `<codewhale:subagent.done>` sentinels, then unlocks dependent tasks
5. Results are aggregated into `.aide/output/3-implement/`

**CodeWhale source basis**: `agent_open` is non-blocking (returns immediately), concurrent cap is 10 (configurable to 20), and `agent_eval` provides bounded result retrieval. (CodeWhale README, Sub-agents section)
