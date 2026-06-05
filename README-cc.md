# AIDE for Claude Code

AIDE is also available as a [Claude Code](https://claude.ai/code) plugin. Install via the self-hosted marketplace.

> Main project: [README.md](README.md)

## Install

```bash
cd your-project/
claude plugin marketplace add https://github.com/zzhaa2008hj/aide.git
claude plugin install aide@aide --scope project
```

Skills are auto-discovered by Claude Code. The following commands become available:

| Command | Purpose |
|---------|---------|
| `/aide` | Start a new pipeline |
| `/aide-continue` | Resume interrupted pipeline |
| `/aide-init` | Bootstrap `.aide/` and config |
| `/aide-update` | Update AIDE to latest version |
| `/aide-fix` | Rapid bug-fix pipeline |

## Differences from deepcode-cli

| Aspect | deepcode-cli | Claude Code |
|--------|-------------|-------------|
| Implement stage | Serial task execution | Parallel subagent dispatch (max 3) |
| Update | `bash .aide/update-deepcode-cli.sh` | `/aide-update` (runs `claude plugin update`) |
| Skill discovery | `.agents/skills/` | Plugin system |
| Install | curl + bash | `claude plugin install` |
| Pipeline protocol | Same (`aide-core/pipeline-protocol.md`) | Same |

Stage-specific skills (`aide-spec`, `aide-plan`, `aide-test`) and all `aide-core/` infrastructure are shared between both orchestrators.

## Update

```
/aide-update
```

Runs `claude plugin marketplace update aide` then `claude plugin update aide@aide --scope project`. Safe to run mid-pipeline.

## Implement stage (CC-specific)

Unlike deepcode-cli's serial execution, the Claude Code orchestrator dispatches tasks in parallel:

1. Reads `plan.json`, resolves dependencies via topological sort
2. Groups independent tasks and dispatches them to subagents concurrently (max 3)
3. Each subagent runs the Superpowers `subagent-driven-development` pattern: implement → spec review → quality review
4. Results are aggregated into `.aide/output/3-implement/`

This parallelism is the main architectural difference — deepcode-cli executes tasks one at a time with self-review.
