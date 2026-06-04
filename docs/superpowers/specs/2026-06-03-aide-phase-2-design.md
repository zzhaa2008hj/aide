# AIDE Phase 2 — Plan Stage + Implement Execution

## Overview

Phase 2 adds two capabilities to AIDE:

1. **Plan stage (`aide-plan` skill)** — Decompose spec features into implementation tasks with dependency tracking
2. **Implement stage execution** — Orchestrator dispatches tasks to subagents with review gates

Both stages share the existing `plan.schema.json` and `implement.schema.json` schemas. The implement stage design was drafted in `2026-06-03-aide-implement-subagent-design.md`; this spec finalizes the combined design.

## Plan Stage: aide-plan skill

### Input / Output

- **Input**: `.aide/output/1-spec/spec.json` — features array with id, description, acceptance_criteria
- **Output**: `.aide/output/2-plan/plan.json` + `plan.md`
- **Schema**: `aide-core/schemas/plan.schema.json` (already exists)

### Task Decomposition Rules

Each feature in spec.json is decomposed into 2-5 minute implementation tasks:

- **Granularity**: Each task targets 2-5 minutes of subagent execution time
- **Bottom-up**: Data/model → business logic → interface/UI → tests
- **Files**: `files_to_touch` is explicit file paths, not globs
- **Dependencies**: `depends_on` only within same feature or across features that share infrastructure
- **Order**: `order_hint` provides initial sort; combined with `depends_on` for `estimated_order`

Example:

```
Feature F001 "User Login"
  → T001: Create login route and page component       depends_on: []
  → T002: Implement POST /api/login backend           depends_on: []
  → T003: Add session/token management                depends_on: [T002]
  → T004: Write login tests                           depends_on: [T001, T002]
```

### Workflow

1. Read `spec.json`, list all features
2. For each feature, decompose acceptance_criteria into tasks bottom-up
3. Cross-feature check: identify shared infrastructure (DB schema, utility functions), add dependencies
4. Topological sort → `estimated_order`
5. Write `plan.json` (machine-readable) and `plan.md` (human summary)
6. Validate `plan.json` against `plan.schema.json`

### plan.md Format

- Total task count, feature count, estimated execution rounds (parallel batches)
- Per-feature task table: title, files to touch, dependencies
- No implementation details — those live in `plan.json` task descriptions

## Implement Stage: Orchestrator Stage 3

### Core Loop

```
plan.json tasks
      │
      ▼
Topological sort → ready queue
      │
      ▼
┌─ Pop task from ready queue
│   Dispatch implement subagent (spec context + task description + files_to_touch)
│   Subagent self-checks output against spec
│   Subagent commits
│   Dispatch spec compliance review agent
│   Dispatch code quality review agent
│   Both reviews pass → done, release blocked tasks to ready queue
│   Review fails → fix (max 2 rounds), still fails → blocked
└─ Loop until queue empty
      │
      ▼
Aggregate → implement.json + implement.md
```

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Execution model | Subagent-driven per-task + two-phase review | Proven Superpowers pattern |
| Task granularity | Plan stage produces subagent-sized tasks (2-5 min) | Matching granularity across stages |
| Dependency handling | Topological sort + ready queue | Maximize parallelism, blocked tasks don't stall independent ones |
| Failure handling | Blocked task skipped, others continue, final summary | Don't block independent work |
| Gate | auto — output summary only | Per-task reviews sufficient, no need for overall pause |
| Commits | One commit per task | Clean history, easy revert |
| Parallelism | Max 3 concurrent subagents for independent tasks | Balance speed vs context coherence |

### Review Agents

- **Spec compliance review**: Compares implementation against feature acceptance_criteria from spec.json
- **Code quality review**: Checks patterns, conventions, error handling, edge cases
- Each review returns pass/fail with actionable feedback
- Failed tasks get 2 repair rounds, then marked blocked

### Output

- `implement.json` — conforms to `implement.schema.json`: completed_tasks, blocked_tasks, changed_files, task_results
- `implement.md` — human-readable summary with per-task status, changed files, blocked reasons

## Integration Points

### Orchestrator Changes

The orchestrator (`skills/aide/SKILL.md`) already has Stage 3 skeleton (Steps 3.1-3.5). Changes needed:

1. Add Stage 2 invocation (load `aide-plan` skill after spec gate passes)
2. Wire Stage 3 to use `plan.json` from Stage 2 output
3. Add concurrency control (max 3 parallel subagents)

### aide-plan Skill

New skill at `skills/aide-plan/SKILL.md`. Invoked by orchestrator after spec gate passes. Loads Superpowers skills for LLM reasoning during task decomposition but does not implement code.

### No New Schemas

Both `plan.schema.json` and `implement.schema.json` already exist and are sufficient.

## Testing Criteria

- **Plan stage**: Given a spec.json with 2-3 features, produces valid plan.json with correct dependency graph
- **Implement stage**: Given a plan.json with 3-4 tasks (some with deps), dispatches subagents, handles review pass/fail/block, produces valid implement.json
- **End-to-end**: Full pipeline runs spec → plan → implement without gate failures
- **Edge cases**: Empty depends_on, circular dependency detection, single-task plan, all-blocked scenario

## Out of Scope (Phase 3)

- `aide-test` skill and test stage execution
- Cross-task artifact caching
- Subagent pool warming
