# AIDE for CodeWhale

AIDE is also available as a [CodeWhale](https://github.com/Hmbown/CodeWhale) skill. Install via CodeWhale's native skill installer.

> Main project: [README.md](README.md)

## Install

```bash
# 从 master 分支安装（稳定版）
curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/develop/skills/aide-codewhale/install.sh | bash

# 从 develop 分支安装（开发版）
curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/develop/skills/aide-codewhale/install.sh | AIDE_REF=develop bash
```

This script:
1. Writes `.aide/version` — version tracking (via `plugin.json`)
2. Sets up `.codewhale/commands/aide.md` — enables `/aide` slash autocomplete
3. Copies `update.sh` to `.aide/update-codewhale.sh` — future upgrades
4. Prints the `/skill install` command to run in CodeWhale

After the script, run the printed command in your CodeWhale session to install the skill. Then invoke via `/aide "<description>"`. Typing `/a` in the composer will show the autocomplete hint.

## Update

```bash
# 更新到当前分支最新
bash .aide/update-codewhale.sh

# 从 develop 分支更新
AIDE_REF=develop bash .aide/update-codewhale.sh
```

Checks `.aide/version` against the latest, refreshes the user command, prints `/skill update aide`.

## Differences from deepcode-cli

| Aspect | deepcode-cli | CodeWhale |
|--------|-------------|-----------|
| Implement stage | Serial task execution | Parallel subagent dispatch via `agent_open` (max 3 per batch) |
| Install | curl + bash | `curl -sSL ... \| bash` + `/skill install` |
| Update | `bash .aide/update-deepcode-cli.sh` | `curl -sSL ... \| bash` + `/skill update aide` |
| Skill discovery | `.agents/skills/` | `.agents/skills/` → `~/.codewhale/skills/` |
| Orchestrator | Reads external stage skills | Fully self-contained (all stages inline) |
| Pipeline protocol | References `aide-core/pipeline-protocol.md` | All rules inlined in SKILL.md |
| Invocation | `/aide` | `$aide` or `/aide` |

Stage-specific skills (`aide-spec`, `aide-plan`, `aide-test`) are shared between all orchestrators in the monorepo, but the CodeWhale orchestrator embeds all workflows inline so it works after a single `/skill install`.

## Implement stage (CodeWhale-specific)

The CodeWhale orchestrator uses `agent_open` for dependency-aware parallel task dispatch:

1. Reads `plan.json`, resolves dependencies via topological sort
2. Batches mutually independent tasks (no `depends_on` intersection within a batch)
3. Dispatches up to 3 tasks per batch via `agent_open` (non-blocking)
4. Waits for `<codewhale:subagent.done>` sentinels, then unlocks dependent tasks
5. Results are aggregated into `.aide/output/3-implement/`

**CodeWhale source basis**: `agent_open` is non-blocking (returns immediately), concurrent cap is 10 (configurable to 20), and `agent_eval` provides bounded result retrieval. (CodeWhale README, Sub-agents section)
