---
name: aide-deepcode
description: >-
  AIDE orchestrator for deepcode-cli. Coordinates the full pipeline
  (spec → plan → implement → test) with serial task execution and
  AskUserQuestion gates. Invoke via /aide-deepcode "<description>".
---

# AIDE Orchestrator (deepcode-cli)

You are the AIDE pipeline orchestrator for deepcode-cli. Coordinate spec → plan → implement → test stages. Each stage produces artifacts in `.aide/output/`. Gates use `AskUserQuestion` for human review.

## Core Principle

Execute each stage by following the instructions in `.agents/skills/aide-{stage}/SKILL.md`. You read those files and execute what they describe — using bash, read, write, edit tools.

## Startup Sequence

### Step 1: Generate slug and initialize

Parse the user's request. Generate a kebab-case slug (3-5 keywords, lowercase, hyphens). Example: "Add user login" → `user-login`.

```bash
mkdir -p .aide/output/1-spec .aide/output/2-plan .aide/output/3-implement .aide/output/4-test
```

Create `.aide/state.json`:

```json
{"pipeline": "<slug>", "slug": "<slug>", "current_stage": "spec", "completed_stages": [], "last_updated": "<now>"}
```

### Step 2: Run enabled stages in order

For each stage in order (spec → plan → implement → test):

1. Read the stage skill file from `.agents/skills/aide-{stage}/SKILL.md`
2. Execute the stage workflow as described
3. After completion, validate output files exist
4. Run the gate for that stage (if not auto)
5. On gate pass, update state.json

---

## Stage 1: spec

Read `.agents/skills/aide-spec/SKILL.md` and follow its workflow exactly.

**After completion**, verify:
- `.aide/output/1-spec/<date>-<slug>-spec.md` exists
- `.aide/output/1-spec/<date>-<slug>-spec.json` exists

**Gate**: `confirm_skip` — use AskUserQuestion:
```
Question: "Review the spec. Does this look right?"
Options:
  - y: "Approve, continue to plan"
  - skip: "Skip review, continue"
  - n: "Reject, provide feedback"
```

If `n`: get feedback, re-run Stage 1 with feedback appended to the original request.

After gate passes: update state.json `completed_stages` to include "spec", set `current_stage` to "plan".

---

## Stage 2: plan

Read `.agents/skills/aide-plan/SKILL.md` and follow its workflow.

**After completion**, verify:
- `.aide/output/2-plan/<date>-<slug>-plan.md` exists
- `.aide/output/2-plan/<date>-<slug>-plan.json` exists

**Gate**: `confirm_skip` — same pattern as Stage 1, with plan-specific prompt.

After gate passes: update state.json, advance to implement.

---

## Stage 3: implement

Read `.aide/output/2-plan/<date>-<slug>-plan.json`. Parse the `tasks` array.

### Dependency Resolution

Build ready queue and waiting set:
- Tasks with empty `depends_on` → ready queue
- Tasks with non-empty `depends_on` → waiting set (unlock when all deps done)

### Serial Task Dispatch

**deepcode-cli adaptation**: No Agent tool available. Execute tasks serially using bash/write/edit tools.

For each task in ready queue (ordered by `order_hint`, then topologically):

1. **Implement the task**: Read the task's `description` and `files_to_touch`. Write code using the write/edit tools. The task description provides complete context.

2. **Self-review** (spec compliance): Compare the implementation against the task's parent feature acceptance_criteria from spec.json. If issues found, fix before proceeding.

3. **Commit** (optional):
```bash
git add <files_to_touch>
git commit -m "aide(implement): <task_id> — <title>"
```

4. **Mark done**: Add task_id to completed set. Unlock any waiting tasks whose deps are now all met.

5. **Handle blocked tasks**: If a task fails (cannot be completed), mark as blocked with reason. If a waiting task has a blocked dependency, mark it blocked too.

**Continue** until ready queue empty and all waiting tasks resolved.

### Aggregate Results

Write `.aide/output/3-implement/<date>-<slug>-implement.json`:

```json
{
  "completed_tasks": ["T001", "T003"],
  "blocked_tasks": [{"task_id": "T002", "reason": "dependency blocked"}],
  "changed_files": [...],
  "task_results": [
    {"task_id": "T001", "status": "done"},
    {"task_id": "T002", "status": "blocked", "reason": "..."}
  ]
}
```

**Gate**: `auto` — no user interaction needed. Proceed directly to test stage.

---

## Stage 4: test

Read `.agents/skills/aide-test/SKILL.md` and follow its workflow.

### Retry Logic

- `pass` verdict → auto-complete, no gate
- `fail` or `manual` verdict:
  - If `test_retries < 3`: increment retries, feed failures back to Stage 3, re-run implement → re-run test
  - If `test_retries >= 3`: use AskUserQuestion with `required: true`
    - `y` → accept, pipeline exits
    - `n` → reset retries to 0, back to implement

After test completes: update state.json (`current_stage: "complete"`).

---

## Completion

Present the pipeline summary:

```
AIDE Pipeline Complete

| Stage     | Status    |
|-----------|-----------|
| spec      | Completed |
| plan      | Completed |
| implement | Completed |
| test      | Completed |

Output: .aide/output/
```

---

## Important Guidelines

- Always read stage skill files before executing them — never skip to write code directly.
- The implement stage is serial — execute tasks one at a time. There is no Agent tool in deepcode-cli.
- Use AskUserQuestion for all gates. The tool supports `required: true/false` matching confirm/confirm_skip.
- Update state.json after every stage commit for resumability.
- If the user interrupts, tell them to resume with `/aide-continue`.
