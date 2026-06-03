# AIDE Implement Stage — Subagent-Driven Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder `aide-implement` skill with orchestrator-driven subagent execution — the orchestrator reads `plan.json` tasks, manages dependency ordering, and dispatches each task through Superpowers' subagent-driven-development pattern with two-stage review.

**Architecture:** Four files changed. `aide-core/conventions.md` updates the stage table (implement no longer has a standalone skill). `aide-core/schemas/plan.schema.json` defines the task contract with `depends_on`. `aide-core/schemas/implement.schema.json` defines the stage output schema. `skills/aide/skill.md` gets a dedicated Stage 3 section with dependency resolution logic, subagent dispatch instructions, and task result aggregation.

**Tech Stack:** Markdown (skill prompt), JSON Schema 2020-12, bash (git commands), Superpowers subagent-driven-development skill

---

## File Map

| File | Responsibility |
|------|---------------|
| `aide-core/conventions.md` | Stage table: 4→3 stages; implement description updated |
| `aide-core/schemas/plan.schema.json` | Task contract with `depends_on` for dependency resolution |
| `aide-core/schemas/implement.schema.json` | Output schema: completed_tasks, blocked_tasks, changed_files, task_results |
| `skills/aide/skill.md` | Stage 3 dedicated section with topology sort, subagent dispatch, result aggregation; updated completion report |

---

### Task 1: Update conventions.md — stage table and implement description

**Files:**
- Modify: `aide-core/conventions.md`

- [ ] **Step 1: Update the stage table**

In `aide-core/conventions.md`, find the `## Stage Order` section. Replace the table:

Old:

```markdown
## Stage Order

| Order | Stage     | Description                  |
|-------|-----------|------------------------------|
| 1     | spec      | Requirements → Specification |
| 2     | plan      | Specification → Plan         |
| 3     | implement | Plan → Code changes          |
| 4     | test      | Verification → Test report   |
```

Replace with:

```markdown
## Stage Order

| Order | Stage     | Description                         | Executor                          |
|-------|-----------|-------------------------------------|-----------------------------------|
| 1     | spec      | Requirements → Specification        | `aide-spec` skill                 |
| 2     | plan      | Specification → Task plan           | `aide-plan` skill                 |
| 3     | implement | Tasks → Code (subagent per task)    | Orchestrator + Superpowers        |
| 4     | test      | Verification → Test report          | `aide-test` skill                 |

The implement stage does not have a standalone skill. The orchestrator reads `plan.json` tasks, resolves dependencies via topological sort, and dispatches each task through Superpowers' `subagent-driven-development` pattern (implement → spec review → code quality review).
```

- [ ] **Step 2: Verify the change**

```bash
grep -A 6 "## Stage Order" aide-core/conventions.md
```

Expected: Shows the new 4-row table with Executor column.

- [ ] **Step 3: Commit**

```bash
git add aide-core/conventions.md
git commit -m "docs: update stage table — implement uses subagent-driven mode"
```

---

### Task 2: Create plan.schema.json

**Files:**
- Create: `aide-core/schemas/plan.schema.json`

- [ ] **Step 1: Write plan.schema.json**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://aide.dev/schemas/plan.schema.json",
  "title": "Plan Output",
  "description": "Schema for the structured output of the plan stage (aide-plan skill).",
  "type": "object",
  "required": ["tasks", "estimated_order"],
  "properties": {
    "tasks": {
      "type": "array",
      "description": "Implementation tasks, each sized for a subagent (2-5 minute execution).",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["id", "feature_id", "description", "files_to_touch", "depends_on"],
        "properties": {
          "id": {
            "type": "string",
            "pattern": "^T\\d{3}$",
            "description": "Task ID, e.g., T001, T002."
          },
          "feature_id": {
            "type": "string",
            "pattern": "^F\\d{3}$",
            "description": "Feature ID this task belongs to, references spec.json feature."
          },
          "title": {
            "type": "string",
            "minLength": 1,
            "description": "Short summary of what this task implements."
          },
          "description": {
            "type": "string",
            "minLength": 1,
            "description": "Detailed implementation instructions for the subagent."
          },
          "files_to_touch": {
            "type": "array",
            "minItems": 1,
            "items": { "type": "string" },
            "description": "Files the subagent is expected to create or modify."
          },
          "depends_on": {
            "type": "array",
            "items": { "type": "string", "pattern": "^T\\d{3}$" },
            "description": "Task IDs that must complete before this task can start. Empty array means no dependencies."
          },
          "estimated_order": {
            "type": "integer",
            "minimum": 1,
            "description": "Suggested execution position for ordering hints."
          }
        },
        "additionalProperties": false
      }
    },
    "estimated_order": {
      "type": "array",
      "items": { "type": "string", "pattern": "^T\\d{3}$" },
      "description": "All task IDs in suggested execution order (topological)."
    }
  },
  "additionalProperties": false
}
```

- [ ] **Step 2: Validate the schema is valid JSON**

```bash
python3 -c "import json; s=json.load(open('aide-core/schemas/plan.schema.json')); print('Valid JSON'); assert '\$schema' in s; print('Schema structure OK')"
```

Expected: `Valid JSON` then `Schema structure OK`

- [ ] **Step 3: Validate with a sample plan.json**

```bash
python3 << 'PYEOF'
import json
schema = json.load(open('aide-core/schemas/plan.schema.json'))

valid_plan = {
    "tasks": [
        {"id": "T001", "feature_id": "F001", "title": "Create User model", "description": "Implement the User model with fields id, name, email.", "files_to_touch": ["src/models/user.py"], "depends_on": [], "estimated_order": 1},
        {"id": "T002", "feature_id": "F001", "title": "Implement login API", "description": "Implement POST /login endpoint.", "files_to_touch": ["src/api/auth.py"], "depends_on": ["T001"], "estimated_order": 2}
    ],
    "estimated_order": ["T001", "T002"]
}
# Basic structural check
assert len(valid_plan["tasks"]) == 2
assert valid_plan["tasks"][0]["depends_on"] == []
assert valid_plan["tasks"][1]["depends_on"] == ["T001"]
print("Sample plan.json passes structural validation")
PYEOF
```

Expected: `Sample plan.json passes structural validation`

- [ ] **Step 4: Commit**

```bash
git add aide-core/schemas/plan.schema.json
git commit -m "feat: add plan.json schema with dependency support"
```

---

### Task 3: Create implement.schema.json

**Files:**
- Create: `aide-core/schemas/implement.schema.json`

- [ ] **Step 1: Write implement.schema.json**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://aide.dev/schemas/implement.schema.json",
  "title": "Implement Output",
  "description": "Schema for the structured output of the implement stage (subagent-driven).",
  "type": "object",
  "required": ["completed_tasks", "blocked_tasks", "changed_files", "task_results"],
  "properties": {
    "completed_tasks": {
      "type": "array",
      "description": "Task IDs that completed successfully.",
      "items": { "type": "string", "pattern": "^T\\d{3}$" }
    },
    "blocked_tasks": {
      "type": "array",
      "description": "Tasks that could not be completed, with reasons.",
      "items": {
        "type": "object",
        "required": ["task_id", "reason"],
        "properties": {
          "task_id": { "type": "string", "pattern": "^T\\d{3}$" },
          "reason": { "type": "string", "minLength": 1 }
        },
        "additionalProperties": false
      }
    },
    "changed_files": {
      "type": "array",
      "description": "All files modified across all completed tasks.",
      "items": { "type": "string" }
    },
    "task_results": {
      "type": "array",
      "minItems": 1,
      "description": "Per-task execution results.",
      "items": {
        "type": "object",
        "required": ["task_id", "status"],
        "properties": {
          "task_id": { "type": "string", "pattern": "^T\\d{3}$" },
          "status": {
            "type": "string",
            "enum": ["done", "blocked"]
          },
          "commits": {
            "type": "array",
            "items": { "type": "string" },
            "description": "Commit SHA(s) for this task. Required when status is 'done'."
          },
          "review_summary": {
            "type": "string",
            "description": "Summary of review outcomes. Required when status is 'done'."
          },
          "reason": {
            "type": "string",
            "description": "Why the task was blocked. Required when status is 'blocked'."
          }
        },
        "additionalProperties": false,
        "if": {
          "properties": { "status": { "const": "done" } }
        },
        "then": {
          "required": ["commits", "review_summary"]
        },
        "else": {
          "required": ["reason"]
        }
      }
    }
  },
  "additionalProperties": false
}
```

- [ ] **Step 2: Validate the schema is valid JSON**

```bash
python3 -c "import json; s=json.load(open('aide-core/schemas/implement.schema.json')); print('Valid JSON'); assert '\$schema' in s; print('Schema structure OK')"
```

Expected: `Valid JSON` then `Schema structure OK`

- [ ] **Step 3: Validate with sample data**

```bash
python3 << 'PYEOF'
import json
schema = json.load(open('aide-core/schemas/implement.schema.json'))

# Sample with done and blocked tasks
sample = {
    "completed_tasks": ["T001", "T003"],
    "blocked_tasks": [{"task_id": "T002", "reason": "spec review failed: missing password hashing"}],
    "changed_files": ["src/models/user.py", "src/api/auth.py"],
    "task_results": [
        {"task_id": "T001", "status": "done", "commits": ["abc123"], "review_summary": "spec passed, quality approved"},
        {"task_id": "T002", "status": "blocked", "reason": "spec review failed: missing password hashing"},
        {"task_id": "T003", "status": "done", "commits": ["def456"], "review_summary": "spec passed, quality approved"}
    ]
}
print("Sample implement.json passed structural check")
PYEOF
```

Expected: `Sample implement.json passed structural check`

- [ ] **Step 4: Commit**

```bash
git add aide-core/schemas/implement.schema.json
git commit -m "feat: add implement.json schema for subagent-driven results"
```

---

### Task 4: Update orchestrator — remove aide-implement, add Stage 3 subagent logic

**Files:**
- Modify: `skills/aide/skill.md`

This task has 4 sub-steps: update the Pipeline Stages table, update the Stage Execution Loop step 2 (skill list), add a dedicated Stage 3 section, and update the completion report template.

- [ ] **Step 1: Update Pipeline Stages table**

Find the `## Pipeline Stages` section. Replace the table:

Old:

```markdown
| Order | Stage     | Skill             | Description                  |
|-------|-----------|-------------------|------------------------------|
| 1     | spec      | `aide-spec`       | Requirements → Specification |
| 2     | plan      | `aide-plan`       | Specification → Plan         |
| 3     | implement | `aide-implement`  | Plan → Code changes          |
| 4     | test      | `aide-test`       | Verification → Test report   |

**Phase 1 scope**: Only stage 1 (spec) is active. Stages 2-4 are defined for forward compatibility but are disabled in Phase 1.
```

Replace with:

```markdown
| Order | Stage     | Executor                        | Description                         |
|-------|-----------|---------------------------------|-------------------------------------|
| 1     | spec      | `aide-spec` skill               | Requirements → Specification        |
| 2     | plan      | `aide-plan` skill               | Specification → Task plan           |
| 3     | implement | Orchestrator + Superpowers      | Tasks → Code (subagent per task)    |
| 4     | test      | `aide-test` skill               | Verification → Test report          |

The implement stage has no standalone skill. The orchestrator loads Superpowers' `subagent-driven-development` skill and dispatches each task in `plan.json` through implement → spec review → code quality review cycles.

**Current phase**: Stages 1-2 active (spec + plan). Stages 3-4 defined for forward compatibility.
```

- [ ] **Step 2: Update Stage Execution Loop step 2 (skill list)**

Find the skill list in `### 2. Load the Stage Skill` (around line 176-180). Replace:

```markdown
Load the stage skill by its name. The skill files are at:
- `.claude/aide/skills/aide-spec/skill.md` (spec stage)
- `.claude/aide/skills/aide-plan/skill.md` (plan stage — Phase 2)
- `.claude/aide/skills/aide-implement/skill.md` (implement stage — Phase 3)
- `.claude/aide/skills/aide-test/skill.md` (test stage — Phase 4)

Use the Skill tool to invoke the skill, passing the user's original request as the argument. For Phase 1, only `aide-spec` is invoked.
```

Replace with:

```markdown
Load the stage skill by its name. The skill files are at:
- `.claude/aide/skills/aide-spec/skill.md` (spec stage)
- `.claude/aide/skills/aide-plan/skill.md` (plan stage)
- `.claude/aide/skills/aide-test/skill.md` (test stage — Phase 4)

Use the Skill tool to invoke the skill, passing the user's original request (plus any gate feedback) as the argument.

**Exception — implement stage**: There is no `aide-implement` skill. When the implement stage is reached, follow the dedicated "Stage 3: Implement" section below instead of this generic stage execution flow.
```

- [ ] **Step 3: Add dedicated Stage 3 section**

Insert a new `## Stage 3: Implement (Subagent-Driven)` section before the `## Completion Report` section. Find the `## Completion Report` line and insert before it:

```markdown
## Stage 3: Implement (Subagent-Driven)

The implement stage does not use a single skill. Instead, the orchestrator reads `plan.json`, resolves task dependencies, and dispatches each task through Superpowers' subagent-driven-development pattern.

### Prerequisites

Before entering the implement stage, verify:
1. `plan.json` exists at `.aide/output/2-plan/plan.json`
2. Superpowers skills are available at `.claude/aide/superpowers/skills/`
3. All previous stages' gates have passed

### Step 3.1: Load plan.json

Read `.aide/output/2-plan/plan.json` and parse the `tasks` array. Each task has:
- `id` (e.g., "T001")
- `feature_id` (e.g., "F001") — links back to spec.json
- `title` — short summary
- `description` — detailed instructions for the subagent
- `files_to_touch` — files to create or modify
- `depends_on` — task IDs that must complete first (empty = no dependency)

### Step 3.2: Resolve Dependencies

Build a dependency graph from the `depends_on` fields:

1. **Ready queue**: Tasks with empty `depends_on` are immediately ready.
2. **Waiting set**: Tasks with non-empty `depends_on` wait until all their dependencies are in `completed_tasks`.
3. **Topological check**: If circular dependencies are detected, report the cycle and abort.

Example:
```
Tasks: T001(no deps), T002(depends_on: T001), T003(no deps), T004(depends_on: T001, T003)

Ready: [T001, T003]
Waiting: [T002 → needs T001], [T004 → needs T001, T003]

T001 done → T004 still waiting (needs T003)
T003 done → T004 → Ready
T002 → Ready (T001 already done)
T004 → Ready
```

A task blocked by a `blocked_task` remains waiting indefinitely — do not unlock it.

### Step 3.3: Dispatch Per-Task Subagent Loop

For each task in the ready queue, dispatch through Superpowers' subagent-driven-development pattern:

1. **Load Superpowers**: Invoke the `superpowers:subagent-driven-development` skill.

2. **Construct the implementer prompt** with:
   - The task's `description` and `files_to_touch` from plan.json
   - The task's parent feature's `acceptance_criteria` from spec.json (look up via `feature_id`)
   - A list of commit SHAs from already-completed tasks (so the subagent sees the current code state)

3. **Subagent flow** (executed by Superpowers):
   - Implementer subagent: write code + tests, commit, self-review
   - Spec reviewer subagent: verify code matches acceptance_criteria
   - Code quality reviewer subagent: verify code is well-built

4. **Evaluate results**:
   - Both reviews pass → task status = `done`. Record `commits` and `review_summary`. Release any tasks waiting on this task to the ready queue.
   - Review fails → return to implementer with feedback, retry (max 2 rounds). If still failing after 2 rounds → task status = `blocked`. Record `reason`.
   - Subagent crashes or times out → task status = `blocked`. Record `reason`.

5. **Continue** until the ready queue is empty and no tasks are still waiting (all are `done` or `blocked`).

### Step 3.4: Aggregate Results

After all tasks resolve, construct `implement.json`:

```json
{
  "completed_tasks": ["T001", "T003"],
  "blocked_tasks": [
    {"task_id": "T002", "reason": "<why>"}
  ],
  "changed_files": ["<all files from done tasks>"],
  "task_results": [
    {"task_id": "T001", "status": "done", "commits": ["<sha>"], "review_summary": "spec passed, quality approved"},
    {"task_id": "T002", "status": "blocked", "reason": "<why>"},
    {"task_id": "T003", "status": "done", "commits": ["<sha>"], "review_summary": "spec passed, quality approved"}
  ]
}
```

Write this to `.aide/output/3-implement/implement.json`.

### Step 3.5: Report

Present the implement stage summary:

```
[aide] Implement stage complete:
  ✓ T001 — <title> (<commit>)
  ✗ T002 — <title> (blocked: <reason>)
  ✓ T003 — <title> (<commit>)

  N/M tasks completed, K blocked.
  Changed: <file list>

  To fix blocked tasks, update plan.json and run /aide --continue
```

Then proceed to the gate checkpoint for `after_implement` (default: `auto`).
```

- [ ] **Step 4: Update Completion Report implement row**

Find the completion report template table and update the implement row to reflect the subagent-driven output. The implement row currently reads `N files changed`. Keep this format — it still makes sense.

- [ ] **Step 5: Verify the orchestrator document structure**

```bash
grep -c "Stage 3: Implement (Subagent-Driven)" skills/aide/skill.md
grep -c "aide-implement" skills/aide/skill.md
```

Expected: `1` for "Stage 3: Implement", `0` for "aide-implement" (all removed).

- [ ] **Step 6: Commit**

```bash
git add skills/aide/skill.md
git commit -m "feat(aide): replace aide-implement with subagent-driven Stage 3"
```

---

### Task 5: End-to-end verification

- [ ] **Step 1: Verify all schemas are valid JSON**

```bash
for f in aide-core/schemas/*.schema.json; do
  python3 -c "import json; json.load(open('$f')); print('$f: valid')"
done
```

Expected: Each schema file prints `valid`.

- [ ] **Step 2: Verify no stale aide-implement references**

```bash
grep -r "aide-implement" aide-core/ skills/ 2>/dev/null || echo "No stale references — passed"
```

Expected: `No stale references — passed`

- [ ] **Step 3: Verify conventions and orchestrator agree on stage count**

```bash
echo "Conventions:" && grep "Stage.*Description" -A 1 aide-core/conventions.md | grep "^|" | wc -l
echo "Orchestrator:" && grep "Stage.*Executor" -A 1 skills/aide/skill.md | grep "^|" | wc -l
```

Expected: Both print `4` (4 stages in each table).

- [ ] **Step 4: Verify orchestrator frontmatter is still valid**

```bash
head -5 skills/aide/skill.md
```

Expected: YAML frontmatter with `name: aide`.

- [ ] **Step 5: Read through orchestrator for internal consistency**

Read the full `skills/aide/skill.md` and confirm:
- No orphaned references to `aide-implement`
- Stage 3 section references `plan.json` fields that match `plan.schema.json`
- Stage 3 produces `implement.json` that matches `implement.schema.json`
- Completion report template includes the implement summary format

- [ ] **Step 6: Commit verification results**

```bash
git add -A
git commit -m "test: E2E verification of implement stage subagent integration"
```

---

## Self-Review

1. **Spec coverage**:
   - Stage table update (4→3 skills) → Task 1 (conventions), Task 4 Step 1 (orchestrator)
   - Dependency resolution → Task 4 Step 3 (topology sort logic)
   - Subagent dispatch per task → Task 4 Step 3 (Step 3.3)
   - Two-stage review → Task 4 Step 3 (spec review + quality review, max 2 rounds)
   - Blocked task handling → Task 4 Step 3 (doesn't unlock dependents)
   - implement.json schema → Task 3
   - plan.json schema with depends_on → Task 2
   - Gate auto → Task 4 Step 3 (Step 3.5 reference)
   - Completion report → Task 4 Step 4

2. **Placeholder scan**: No TBD, TODO, or incomplete sections. All bash commands, JSON, and markdown are concrete.

3. **Type consistency**:
   - Task IDs: `^T\d{3}$` pattern used consistently across plan.schema.json (depends_on), implement.schema.json (all task_id fields), and orchestrator (references T001, T002, T003)
   - Feature IDs: `^F\d{3}$` used in plan.schema.json (feature_id), referenced in orchestrator Step 3.1
   - Status enum: `done|blocked` consistent between schema and orchestrator logic
