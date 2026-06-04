---
name: aide-plan
description: >-
  AIDE plan stage: reads spec.json, decomposes features into implementation
  tasks with dependency tracking, writes plan.json + plan.md. Invoked by the
  aide orchestrator after spec gate passes.
---

# AIDE Plan Stage

You are the **plan stage** of the AIDE pipeline. Your job is to read the structured specification from the spec stage and produce a detailed implementation plan: `plan.json` (machine-readable) and `plan.md` (human summary).

## Input

Read `.aide/output/1-spec/spec.json`. It contains:
- `features`: array of objects, each with `id` (e.g., "F001"), `title`, `description`, `acceptance_criteria` (array of strings)

## Output

Write two files:
1. `.aide/output/2-plan/plan.json` — conforms to `plan.schema.json`
2. `.aide/output/2-plan/plan.md` — human-readable summary

## Task Decomposition Rules

For each feature in spec.json:

1. **Analyze acceptance_criteria** — each criterion implies one or more concrete implementation steps
2. **Decompose bottom-up**: data/model → business logic → interface/API → tests
3. **Granularity**: each task targets 2-5 minutes of subagent execution. If a task would take longer, split it further
4. **files_to_touch**: explicit file paths (no globs, no directories). Create paths for new files, note existing paths for modifications
5. **depends_on**: task IDs that must finish before this task. Use sparingly — only real dependencies (e.g., "must have DB schema before API endpoint")
6. **order_hint**: integer starting from 1, reflecting bottom-up ordering within the feature

### Dependency rules
- Within a feature: model before logic, logic before API, API before tests
- Across features: only add cross-feature deps for shared infrastructure (DB schema, utility module, auth middleware)
- No circular dependencies — if two tasks need each other, merge them

### Task ID naming
- Format: T001, T002, T003... across ALL features (global sequence)
- feature_id: references the parent feature's ID from spec.json

Example decomposition:

Feature F001 "API health check endpoint"
  Acceptance criteria: "GET /health returns 200 with {status: ok}"

  → T001: Create health route handler (files: src/routes/health.py, order_hint: 1)
  → T002: Register route in app (files: src/app.py, order_hint: 2, depends_on: [T001])
  → T003: Write test for health endpoint (files: tests/test_health.py, order_hint: 3, depends_on: [T001])

## Workflow

### Step 1: Read input

```bash
mkdir -p .aide/output/2-plan
cat .aide/output/1-spec/spec.json
```

Parse the features array. Count features — report: "Decomposing N features into implementation tasks..."

### Step 2: Decompose each feature

For each feature, apply the decomposition rules above. Write each task as a draft object in memory. Track the global task counter (T001, T002...). For each task, write a detailed `description` field that gives the subagent complete context to implement the task independently — include what to build, where to put it, what patterns to follow, and how it connects to other tasks.

### Step 3: Cross-feature dependency check

After all features are decomposed:
- Scan all tasks for shared files (e.g., two features touch the same DB schema file)
- If shared files found: merge the tasks or add cross-feature deps
- Check for circular dependencies: if T003 → T005 and T005 → T003, merge them

### Step 4: Generate estimated_order

Topological sort all tasks:
- Tasks with empty depends_on come first
- After a task's deps are placed, the task follows
- Use order_hint to break ties

### Step 5: Write plan.json

Construct the JSON according to plan.schema.json:

```json
{
  "tasks": [
    {
      "id": "T001",
      "feature_id": "F001",
      "title": "Create health route handler",
      "description": "Create src/routes/health.py with a GET /health endpoint that returns {\"status\": \"ok\"} with HTTP 200. Use the existing app framework.",
      "files_to_touch": ["src/routes/health.py"],
      "depends_on": [],
      "order_hint": 1
    }
  ],
  "estimated_order": ["T001", "T002", "T003"]
}
```

Write to `.aide/output/2-plan/plan.json`.

### Step 6: Write plan.md

Human-readable summary:

```markdown
# Implementation Plan

**Generated:** <timestamp>
**Features:** N
**Tasks:** M
**Estimated rounds:** R (parallel batches after dependency resolution)

## Feature F001: <title>

| Task | Title | Files | Depends On |
|------|-------|-------|------------|
| T001 | Create health route handler | src/routes/health.py | — |
| T002 | Register route in app | src/app.py | T001 |
| T003 | Write health endpoint test | tests/test_health.py | T001 |

## Estimated Execution Order

1. T001, T004 (no dependencies — parallel batch 1)
2. T002 (after T001)
3. T003, T005 (after T001, T004)
```

Write to `.aide/output/2-plan/plan.md`.

### Step 7: Validate

```bash
AIDE_DIR=$(find ~/.claude/plugins/cache/aide .claude/plugins -name "SKILL.md" -path "*/skills/aide/*" 2>/dev/null | head -1 | sed 's|/skills/aide/SKILL.md||')
[ -z "$AIDE_DIR" ] && AIDE_DIR=".claude/aide"

python3 -c "
import json, jsonschema
with open('${AIDE_DIR}/aide-core/schemas/plan.schema.json') as f:
    schema = json.load(f)
with open('.aide/output/2-plan/plan.json') as f:
    data = json.load(f)
jsonschema.validate(data, schema)
print('plan.json is valid')
"
```

If validation fails, fix the plan.json and re-validate.

### Step 8: Report

```
## Stage 2: plan — Specification → Implementation Plan

Output:
  .aide/output/2-plan/plan.json   — <N> tasks, <M> features
  .aide/output/2-plan/plan.md     — human summary

Ready for implement stage.
```

## Important Guidelines

- Always validate plan.json against the schema before reporting completion. Never skip validation.
- Task descriptions must be self-contained — the implement subagent should have everything it needs to complete the task from the description field alone.
- Prefer more, smaller tasks over fewer, larger ones. A task taking 5+ minutes should be split.
- The estimated_order must be a valid topological sort of the dependency graph. Every task that appears before another in estimated_order must not depend on it.
- If spec.json is missing or malformed, report the error and stop — do not fabricate a plan from memory.
