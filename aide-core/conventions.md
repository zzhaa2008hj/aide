# AIDE Conventions

## Artifact Root

All AIDE workflow artifacts live under `.aide/` in the business project root. This directory should be added to `.gitignore` in the business project (AIDE's auto-commit explicitly stages `.aide/` files, so `.gitignore` does not block them).

## File Naming

Stage output files use the format: `{date}-{slug}-{stage}.{ext}`

- `date`: `YYYY-MM-DD` of pipeline run
- `slug`: kebab-case feature identifier (e.g., `user-login-oauth`)
- `stage`: stage name (`spec`, `plan`, `implement`, `test-report`)
- `ext`: `md` or `json`

Before writing, check for existing files. If a file with the same name exists, append `-2`, `-3`, etc. Same-pipeline re-runs (gate feedback loops, test retries) increment the sequence.

Example:
```
.aide/output/1-spec/
  2026-06-04-user-login-spec.md
  2026-06-04-user-login-spec.json
  2026-06-04-user-login-spec-2.md     # re-run after gate rejection
  2026-06-04-user-login-spec-2.json
```

## Output Structure

```
.aide/
├── config.yaml          # Project workflow configuration (copied from template)
├── state.json           # Pipeline state tracking (for --continue resume)
└── output/
    ├── 1-spec/
    │   ├── {date}-{slug}-spec.md
    │   └── {date}-{slug}-spec.json
    ├── 2-plan/
    │   ├── {date}-{slug}-plan.md
    │   └── {date}-{slug}-plan.json
    ├── 3-implement/
    │   └── {date}-{slug}-implement.json
    └── 4-test/
        ├── {date}-{slug}-test-report.md
        └── {date}-{slug}-test-report.json
```

## Stage Order

| Order | Stage     | Description                         | Executor                          |
|-------|-----------|-------------------------------------|-----------------------------------|
| 1     | spec      | Requirements → Specification        | `aide-spec` skill                 |
| 2     | plan      | Specification → Task plan           | `aide-plan` skill                 |
| 3     | implement | Tasks → Code (subagent per task)    | Orchestrator + Superpowers        |
| 4     | test      | Verification → Test report          | `aide-test` skill (Phase 3)       |

The implement stage does not have a standalone skill. The orchestrator reads `plan.json` tasks, resolves dependencies via topological sort, and dispatches each task through Superpowers' `subagent-driven-development` pattern (implement → spec review → code quality review). The test stage is planned for Phase 3 — the `aide-test` skill does not yet exist.

## File Naming

- Stage directories: `{order}-{stage-name}/` (e.g., `1-spec/`)
- Human-readable artifact: `{stage-name}.md`
- Machine-readable artifact: `{stage-name}.json`

Each stage SHOULD produce both `.md` and `.json` outputs. The `.json` output must conform to the corresponding schema in `aide-core/schemas/`.

**Exception**: The implement stage (3-implement) only produces `implement.json` — its primary output is code changes, with a human-readable summary presented inline by the orchestrator.

## Git

After each stage completes, AIDE auto-commits only `.aide/` files with message format:

```
aide(<stage>): <summary>
```

Business code changes are never auto-committed. Working-tree changes outside `.aide/` produce a warning but do not block the commit.

## Branch Isolation

Each new AIDE pipeline run creates a dedicated branch to isolate workflow artifacts from the user's working branch:

- **Naming**: `aide/<slug>` where `<slug>` is a short kebab-case identifier derived from the feature description (e.g., `aide/user-login-oauth`)
- **Base**: The branch is created from the current `HEAD`
- **Auto-stash**: If the working tree has uncommitted changes, they are stashed before branch creation with message `AIDE: auto-stash before aide/<slug>`
- **--continue**: Recovery runs reuse the existing `aide/*` branch — no new branch is created
- **Post-pipeline**: The branch is left as-is; merging back is a manual user decision

## Fix Pipeline Stage Order

| Order | Stage     | Description                         | Executor                |
|-------|-----------|-------------------------------------|-------------------------|
| 0     | init      | Project context + branch creation   | Orchestrator            |
| 1     | analyze   | Root cause → scope fence            | Orchestrator            |
| 2     | implement | Scope-fenced code changes           | Orchestrator (1 agent)  |
| 3     | test      | Verify + auto-retry (max 2)        | Orchestrator + aide-test|

The fix pipeline is a lightweight alternative to the full pipeline, designed for bug fixes and small optimizations. It is invoked via `/aide-fix` and uses independent state tracking (`.aide/fix-state.json`), branch prefix (`aide-fix/`), and output directory (`.aide/fix/output/`).

## Fix Pipeline Output Structure

```
.aide/fix/
├── fix-state.json
└── output/
    ├── 1-analyze/
    │   └── {date}-{slug}-analyze.md
    ├── 2-implement/
    │   └── {date}-{slug}-implement.md
    └── 3-test/
        └── {date}-{slug}-test-report.md
```

File naming follows the same convention: `{date}-{slug}-{stage}.md`. Re-runs append `-2`, `-3`, etc.

## Fix Pipeline Git Conventions

- Branch naming: `aide-fix/<slug>`
- Auto-commit `.aide/fix/` artifacts after each stage with message: `aide-fix(<stage>): <summary>`
- Business code changes are never auto-committed
- After pipeline completes, the branch is left as-is; merging back is a manual user decision
