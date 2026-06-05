# AIDE for CodeWhale

AIDE is also available as a [CodeWhale](https://github.com/Hmbown/CodeWhale) skill. Install via CodeWhale's native skill installer.

> Main project: [README.md](README.md)

## Install

In a CodeWhale session, run:

```
/skill install github:zzhaa2008hj/aide
```

CodeWhale discovers skills from `.agents/skills/` and `~/.codewhale/skills/`. The orchestrator is self-contained — no additional stage skills needed.

Invoke via `$aide "<description>"` or `/aide "<description>"`.

## Differences from deepcode-cli

| Aspect | deepcode-cli | CodeWhale |
|--------|-------------|-----------|
| Implement stage | Serial task execution | Parallel subagent dispatch via `agent_open` (max 3 per batch) |
| Install | curl + bash | `/skill install github:zzhaa2008hj/aide` |
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
