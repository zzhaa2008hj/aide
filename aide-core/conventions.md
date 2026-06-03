# AIDE Conventions

## Artifact Root

All AIDE workflow artifacts live under `.aide/` in the business project root. This directory should be added to `.gitignore` in the business project (AIDE's auto-commit explicitly stages `.aide/` files, so `.gitignore` does not block them).

## Output Structure

```
.aide/
├── config.yaml          # Project workflow configuration (copied from template)
├── state.json           # Pipeline state tracking (Phase 2+)
└── output/
    ├── 1-spec/
    │   ├── spec.md      # Human-readable specification
    │   └── spec.json    # Machine-readable specification (conforms to spec.schema.json)
    ├── 2-plan/
    │   ├── plan.md
    │   └── plan.json
    ├── 3-implement/
    │   └── implement.json
    └── 4-test/
        ├── test-report.md
        └── test-report.json
```

## Stage Order

| Order | Stage     | Description                         | Executor                          |
|-------|-----------|-------------------------------------|-----------------------------------|
| 1     | spec      | Requirements → Specification        | `aide-spec` skill                 |
| 2     | plan      | Specification → Task plan           | `aide-plan` skill                 |
| 3     | implement | Tasks → Code (subagent per task)    | Orchestrator + Superpowers        |
| 4     | test      | Verification → Test report          | `aide-test` skill                 |

The implement stage does not have a standalone skill. The orchestrator reads `plan.json` tasks, resolves dependencies via topological sort, and dispatches each task through Superpowers' `subagent-driven-development` pattern (implement → spec review → code quality review).

## File Naming

- Stage directories: `{order}-{stage-name}/` (e.g., `1-spec/`)
- Human-readable artifact: `{stage-name}.md`
- Machine-readable artifact: `{stage-name}.json`

Every stage MUST produce both `.md` and `.json` outputs. The `.json` output must conform to the corresponding schema in `aide-core/schemas/`.

**Exception**: The implement stage (3-implement) only produces `implement.json`. Its primary output is code changes, so a human-readable summary is presented inline by the orchestrator rather than written to a separate `.md` file.

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
