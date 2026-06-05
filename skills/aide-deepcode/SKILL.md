---
name: aide
description: >-
  AIDE orchestrator for deepcode-cli. Coordinates the full pipeline
  (spec → plan → implement → test) with serial task execution and
  AskUserQuestion gates. Invoke via /aide "<description>".
---

# AIDE Pipeline Orchestrator

## ⛔ CRITICAL — READ THIS BEFORE DOING ANYTHING ELSE

You are a **strict sequential pipeline state machine**. Your current stage is tracked in `.aide/state.json`.

Read `aide-core/pipeline-protocol.md` (Section: CRITICAL Pipeline Discipline) before proceeding. Locate `aide-core/` at `~/.claude/plugins/cache/aide/aide/*/` first, then `.claude/plugins/aide/`.

## How Pipeline Execution Works

```
Stage 0 (init) → Stage 1 (spec) → Gate → Stage 2 (plan) → Gate → Stage 3 (implement) → Stage 4 (test) → Done
```

Each stage transition requires:
1. Reading the stage-specific skill file from `.agents/skills/aide-{stage}/SKILL.md`
2. Following its workflow EXACTLY — do not improvise
3. Validating output artifacts exist
4. Passing the gate (AskUserQuestion or auto)
5. Updating `.aide/state.json`

**You are in exactly ONE stage at a time. Complete it fully before proceeding.**

## Stage 0: Initialize

**Goal**: Set up pipeline state and decide branching.

### 0.1 Parse request and generate slug

Extract 3-5 keywords from the user's request, lowercase, hyphenate. Example: "Add AI chat drawer to the right side" → `ai-chat-drawer`.

### 0.2 Analyze project context (MANDATORY)

**You MUST ground all pipeline decisions in the existing project.** Read `aide-core/pipeline-protocol.md` (Section: Project Context Analysis) and follow the procedure there exactly. To locate `aide-core/`, check `~/.claude/plugins/cache/aide/aide/*/` first, then `.claude/plugins/aide/`.

### 0.3 Record current branch

```bash
ORIG_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
echo "ORIG_BRANCH=$ORIG_BRANCH"
```

### 0.4 Branch decision

Use `AskUserQuestion` with `required: true`:

```
Question: "Create a new aide/<slug> branch for this pipeline?"
Header: "Branch"
Options:
  - "<ORIG_BRANCH> (Recommended)" — create aide/<slug> from current branch
  - "skip (Recommended)" — stay on current branch, no isolation
```

- If user selects a branch name: `git checkout -b aide/<slug> <selected-branch>`
- If `skip`: stay on `ORIG_BRANCH`, no branch creation

### 0.5 Initialize AIDE directories and state

```bash
mkdir -p .aide/output/1-spec .aide/output/2-plan .aide/output/3-implement .aide/output/4-test
```

Create `.aide/state.json`:

```json
{
  "pipeline": "<slug>",
  "slug": "<slug>",
  "current_stage": "spec",
  "completed_stages": [],
  "test_retries": 0,
  "last_updated": "<ISO timestamp>"
}
```

**State updated.** You are now entering Stage 1.

---

## Stage 1: spec

**🔴 CHECK**: Is `current_stage` in `.aide/state.json` set to `"spec"`? If not, STOP — go back to the correct stage. If `"spec"` is already in `completed_stages`, skip to Stage 2.

### What to do

**Read** `.agents/skills/aide-spec/SKILL.md` from beginning to end. **Follow its workflow exactly.** Do not improvise or skip steps.

This stage produces:
- `.aide/output/1-spec/<date>-<slug>-spec.md`
- `.aide/output/1-spec/<date>-<slug>-spec.json`

### Validation

After completing the spec workflow, verify BOTH output files exist:
```bash
ls -la .aide/output/1-spec/*-spec.md .aide/output/1-spec/*-spec.json
```

If either file is missing, go back and complete the spec stage.

### Gate

Use `AskUserQuestion` with `required: true`:

```
Question: "Review the spec. Does this look right?"
Header: "Spec"
Options:
  - "y: Approve, continue to plan (Recommended)"
  - "n: Reject, provide feedback to revise"
```

- `y` → proceed to state update
- `n` → collect feedback, re-run Stage 1 with feedback appended

### State update

Follow **Pattern A — Basic Stage Transition** in `aide-core/pipeline-protocol.md`, substituting `{current_stage}="spec"` and `{next_stage}="plan"`.

**Stage 1 complete.** Proceed to Stage 2.

---

## Stage 2: plan

**🔴 CHECK**: Is `current_stage` set to `"plan"`? If `"plan"` is in `completed_stages`, skip to Stage 3.

**🔴 REMINDER**: You STILL cannot write source code. You are producing plan artifacts only.

### What to do

**Read** `.agents/skills/aide-plan/SKILL.md` from beginning to end. **Follow its workflow exactly.**

This stage produces:
- `.aide/output/2-plan/<date>-<slug>-plan.md`
- `.aide/output/2-plan/<date>-<slug>-plan.json`

### Validation

```bash
ls -la .aide/output/2-plan/*-plan.md .aide/output/2-plan/*-plan.json
```

### Gate

Use `AskUserQuestion` with `required: true`:

```
Question: "Review the implementation plan. Does this look right?"
Header: "Plan"
Options:
  - "y: Approve, continue to implement (Recommended)"
  - "n: Reject, provide feedback to revise"
```

- `y` → proceed
- `n` → collect feedback, re-run Stage 2

### State update

Follow **Pattern A — Basic Stage Transition** in `aide-core/pipeline-protocol.md`, substituting `{current_stage}="plan"` and `{next_stage}="implement"`.

**Stage 2 complete.** Proceed to Stage 3.

---

## Stage 3: implement

**🔴 CHECK**: Is `current_stage` set to `"implement"`? Both spec AND plan must be in `completed_stages`. If not, STOP and go back.

**🟢 YOU MAY NOW WRITE SOURCE CODE.** The restriction is lifted because spec and plan are done.

### What to do

Read the plan to understand what needs to be built:

```bash
cat .aide/output/2-plan/*-plan.json
```

Parse the `tasks` array. Each task has: `id`, `feature_id`, `title`, `description`, `files_to_touch`, `depends_on`, `order_hint`.

### Dependency Resolution

Build two queues:
- **Ready**: tasks where `depends_on` is empty or all dependencies are in completed set
- **Waiting**: tasks with unmet dependencies (unlock when all deps done)

### Serial Task Execution

Execute tasks **one at a time** in order (by `order_hint`, then topologically). For each task:

1. **Read** the task's `description` — it contains complete implementation context
2. **Implement** using write/edit/bash tools on `files_to_touch`
3. **Self-review** — compare against the parent feature's acceptance_criteria from spec.json
4. **Mark done** — add task_id to completed set, unlock dependent waiting tasks
5. **Handle failures** — if a task cannot be completed, mark as blocked with reason. Block tasks that depend on it.

### Aggregate Results

Write `.aide/output/3-implement/<date>-<slug>-implement.json`:

```json
{
  "completed_tasks": ["T001", "T003"],
  "blocked_tasks": [],
  "changed_files": ["<list of all files touched>"],
  "task_results": [
    {"task_id": "T001", "status": "done"},
    {"task_id": "T002", "status": "done"}
  ]
}
```

Use the same date-slug pattern as previous stages for the filename.

### Gate

`auto` — no user interaction. Proceed directly.

### State update

Follow **Pattern A — Basic Stage Transition** in `aide-core/pipeline-protocol.md`, substituting `{current_stage}="implement"` and `{next_stage}="test"`.

**Stage 3 complete.** Proceed to Stage 4.

---

## Stage 4: test

**🔴 CHECK**: Is `current_stage` set to `"test"`?

### What to do

**Read** `.agents/skills/aide-test/SKILL.md` from beginning to end. **Follow its workflow exactly.**

This stage produces:
- `.aide/output/4-test/<date>-<slug>-test-report.md`
- `.aide/output/4-test/<date>-<slug>-test-report.json`

### Retry Logic

Read the `verdict` from test-report.json:

- `pass` → auto-complete, no gate needed
- `fail` or `manual`:
  - Read `test_retries` from state.json
  - If `< 3`: increment retries, feed failures back to Stage 3 (re-run implement for failed tasks, then re-run test)
  - If `>= 3`: use AskUserQuestion with `required: true`
    - `y` → accept as-is, pipeline exits
    - `n` → reset retries to 0, back to Stage 3

### State update (on pass or user accept)

Follow **Pattern C — Stage Transition with Cleanup** in `aide-core/pipeline-protocol.md`, substituting `{current_stage}="test"` and `{next_stage}="complete"`.

---

## Pipeline Complete

Display summary:

```
╔══════════════════════════════════════╗
║     AIDE Pipeline Complete           ║
╠══════════════════════════════════════╣
║ Stage     │ Status                   ║
║───────────┼──────────────────────────║
║ spec      │ ✓ Completed              ║
║ plan      │ ✓ Completed              ║
║ implement │ ✓ Completed              ║
║ test      │ ✓ Completed              ║
╚══════════════════════════════════════╝

Branch: <current-branch>
Output: .aide/output/
```

### Merge decision

If a branch was created (`aide/<slug>`):

Use `AskUserQuestion`:

```
Question: "Merge aide/<slug> into a target branch?"
Header: "Merge"
Options:
  - "<ORIG_BRANCH> (Recommended)" — merge back to original branch
  - "skip (Recommended)" — no merge, artifacts stay on this branch
```

- Branch selected → `git checkout <target> && git merge aide/<slug>`
- `skip` → done

---

## Resume

If `.aide/state.json` exists with `current_stage` not equal to `"complete"` or `"spec"` when you start, resume from that stage. Do NOT re-run completed stages (check `completed_stages` array).

Tell the user: "Resuming AIDE pipeline from Stage N — use `/aide-continue` if you need to resume after interruption."
