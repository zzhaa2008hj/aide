---
name: aide
description: >-
  AIDE pipeline orchestrator for CodeWhale. Coordinates the full pipeline
  (spec → plan → implement → test) with dependency-aware parallel task
  execution via agent_open. Invoke via $aide "<description>" or /aide
  "<description>".
---

# AIDE Pipeline Orchestrator (CodeWhale)

## ⛔ CRITICAL — READ THIS BEFORE DOING ANYTHING ELSE

You are a **strict sequential pipeline state machine**. Your current stage is tracked in `.aide/state.json`.

This skill is **fully self-contained** — all protocol rules, schemas, state update patterns, and stage workflows are defined inline. No external files are referenced.

## Output Language

All `.md` output files produced by this pipeline must use **简体中文** for body content:

- `.aide/output/1-spec/*-spec.md` — 中文
- `.aide/output/2-plan/*-plan.md` — 中文
- `.aide/output/3-implement/*-implement.md` — 中文（如有）
- `.aide/output/4-test/*-test-report.md` — 中文

JSON files (`*.json`) use English field names as defined in schemas, but `description`, `title`, `criteria`, `evidence`, `review_summary`, and `reason` string values should be in Chinese.

## Mode Switching

**On skill activation**, switch to Agent mode so the user retains approval control:

```
/agent
```

**When Stage 3 (implement) begins**, switch to YOLO mode so sub-agents can write code without per-edit prompts:

```
/yolo
```

**When Stage 3 completes** (moving to Stage 4), switch back to Agent mode:

```
/agent
```

These mode switches ensure a smooth pipeline: manual review during spec/plan, friction-free execution during implement, manual verification during test.

## How Pipeline Execution Works

```
Stage 0 (init) → Stage 1 (spec) → Gate → Stage 2 (plan) → Gate → Stage 3 (implement) → Stage 4 (test) → Done
```

Each stage transition requires:
1. Completing the stage workflow as defined below
2. Validating output artifacts exist
3. Passing the gate (per `.aide/config.yaml`)
4. Updating `.aide/state.json`

**You are in exactly ONE stage at a time. Complete it fully before proceeding.**

If `.aide/state.json` exists at startup with `completed_stages`, respect it — do NOT re-run completed stages.

## Stage 0: Initialize

### 0.0 Initialize progress checklist

Use `checklist_write` to create a visible progress tracker:
```
checklist_write([
  {id: "0", label: "Initialize", checked: false},
  {id: "1", label: "Spec", checked: false},
  {id: "2", label: "Plan", checked: false},
  {id: "3", label: "Implement", checked: false},
  {id: "4", label: "Test", checked: false}
])
```

### 0.1 Parse request and generate slug

Extract 3-5 keywords from the user's request, lowercase, hyphenate. Example: "Add AI chat drawer to the right side" → `ai-chat-drawer`.

### 0.2 Analyze project context (MANDATORY)

Ground all pipeline decisions in the existing project:

1. **Map the project structure**:
   ```bash
   find . -maxdepth 1 -type f \( -name "*.json" -o -name "*.yaml" -o -name "*.toml" -o -name "Makefile" -o -name "Dockerfile" \) 2>/dev/null | head -20
   ls -la
   ```

2. **Identify tech stack**: Read the project manifest (`package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pyproject.toml`, etc.). Determine: language, framework, build system, test framework, package manager.

3. **Understand directory conventions**:
   ```bash
   find . -maxdepth 3 -type d ! -path './.git/*' ! -path './node_modules/*' ! -path './.aide/*' ! -path './venv/*' ! -path './__pycache__/*' 2>/dev/null | sort
   ```

4. **Identify existing patterns**: Read key source files (entry points, config, representative components). Note: naming conventions, file organization, code style, framework usage.

5. **Check for existing tests**:
   ```bash
   find . -path '*/test*' -o -path '*/__test*' -o -path '*/spec*' 2>/dev/null | head -20
   ```

6. **Summarize findings** in a brief project context memo. This informs ALL subsequent stages.

### 0.3 Generate slug

The slug was generated in Step 0.1. It is used ONLY for naming pipeline output files. No branch is created — AIDE works directly on the current branch.

### 0.5 Initialize AIDE directories and state

```bash
mkdir -p .aide/output/1-spec .aide/output/2-plan .aide/output/3-implement .aide/output/4-test
```

Create `.aide/state.json`:
```json
{
  "slug": "<slug>",
  "current_stage": "spec",
  "completed_stages": [],
  "test_retries": 0,
  "last_updated": "<ISO timestamp>"
}
```

### 0.6 Load configuration

Read `.aide/config.yaml`. If it does not exist, use defaults:
```yaml
version: "1"
language: ""
stages:
  spec:
    enabled: true
    gates:
      - name: after_spec
        type: confirm
        prompt: "Review the spec at .aide/output/1-spec/. Does this look right? (y/n)"
    review_panel:
      enabled: false
      reviewers:
        - id: edge_case
          enabled: true
          max_gaps: 8
        - id: security
          enabled: true
          max_gaps: 5
        - id: performance
          enabled: true
          max_gaps: 5
      min_reviewers: 2
  plan:
    enabled: true
    gates:
      - name: after_plan
        type: confirm_skip
        prompt: "Review the plan at .aide/output/2-plan/. Does this look right? (y/n/skip)"
  implement:
    enabled: true
    gates:
      - name: after_implement
        type: auto
  test:
    enabled: true
    gates:
      - name: after_test
        type: auto
```

### Gate Type Reference

| Type | Behavior |
|------|----------|
| `confirm` | Requires explicit y/n. No skip option. |
| `confirm_skip` | y = proceed, skip = proceed + persist as `auto`, n = reject (feedback loop) |
| `auto` | No user interaction. Passes automatically. |

When user selects `skip` on a `confirm_skip` gate: update `.aide/config.yaml` to change that gate's type from `confirm_skip` to `auto`.

### State update

After initialization, the state file should contain:
```json
{
  "slug": "<slug>",
  "current_stage": "spec",
  "completed_stages": [],
  "test_retries": 0,
  "last_updated": "<ISO timestamp>"
}
```

**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: false},
  {id: "2", label: "Plan", checked: false},
  {id: "3", label: "Implement", checked: false},
  {id: "4", label: "Test", checked: false}
])
```

---

## Stage 1: spec

**CHECK**: `current_stage` must be `"spec"`. If `"spec"` is already in `completed_stages`, skip to Stage 2.

### Workflow

1. Read the project context memo from Stage 0.2
2. Analyze the user's requirement against the existing codebase
3. Identify features with acceptance criteria
4. Document constraints and scope boundary

### Output: `.aide/output/1-spec/<date>-<slug>-spec.md`

Human-readable specification document.

### Output: `.aide/output/1-spec/<date>-<slug>-spec.json`

```json
{
  "schema_version": "1",
  "features": [
    {
      "id": "F001",
      "title": "Short summary",
      "description": "Detailed feature description.",
      "acceptance_criteria": ["Verifiable criterion 1", "Verifiable criterion 2"]
    }
  ],
  "constraints": ["Technical or business constraint"],
  "scope_boundary": "What is explicitly out of scope."
}
```

Schema rules:
- `features`: array, min 1 item. Each has `id` (F001-F999), `title`, `description`, `acceptance_criteria` (array of strings, min 1)
- `constraints`: array of strings
- `scope_boundary`: string
- `schema_version`: must be `"1"`

### Validation

```bash
ls -la .aide/output/1-spec/*-spec.md .aide/output/1-spec/*-spec.json
```

### Gate

**If `review_panel.enabled` is true in config and `review_trail` exists in spec.json**: Read `review_trail` from `.aide/output/1-spec/*-spec.json`. Display review summary:

```
## Spec Review Summary

Review status: <status>  |  <N> reviewers ran, <M> failed
Gaps found: <total>  |  Accepted: <accepted>  |  Rejected: <rejected>  |  Pending: <pending>
Confidence: F001=<confidence>, ...
```

If `gaps_pending > 0`: Present pending gaps interactively. For each:
- Accepted → set `decision: "accepted"`, `decision_source: "user"`, apply `suggested_ac` to spec
- Rejected → set `decision: "rejected"`, `decision_source: "user"`, ask for brief reason

After all decided, update `review_trail` (counts + decisions array), regenerate spec.md + spec.json, re-validate.

If `status == "degraded"`: append "⚠ Spec review panel was degraded." to gate prompt.

Process the `after_spec` gate per the loaded configuration. Ask the user to review the spec.

### State update

Update `.aide/state.json`:
```json
{
  "slug": "<slug>",
  "current_stage": "plan",
  "completed_stages": ["spec"],
  "test_retries": 0,
  "last_updated": "<ISO timestamp>"
}
```

**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: true},
  {id: "2", label: "Plan", checked: false},
  {id: "3", label: "Implement", checked: false},
  {id: "4", label: "Test", checked: false}
])
```

---

## Stage 2: plan

**CHECK**: `current_stage` must be `"plan"`. If `"plan"` is in `completed_stages`, skip to Stage 3.

### Workflow

1. Read the spec from `.aide/output/1-spec/*-spec.json`
2. Decompose each feature into discrete implementation tasks
3. Each task sized for a single sub-agent (2-5 minute execution)
4. Establish dependency relationships between tasks
5. Assign execution order hints

### Output: `.aide/output/2-plan/<date>-<slug>-plan.md`

Human-readable plan with task listing and dependency graph.

### Output: `.aide/output/2-plan/<date>-<slug>-plan.json`

```json
{
  "tasks": [
    {
      "id": "T001",
      "feature_id": "F001",
      "title": "Short summary of what this implements",
      "description": "Detailed implementation instructions.",
      "files_to_touch": ["src/file1.ts", "src/file2.ts"],
      "depends_on": [],
      "order_hint": 1
    }
  ],
  "estimated_order": ["T001", "T002", "T003"]
}
```

Schema rules:
- `tasks`: array, min 1 item. Each has `id` (T001-T999), `feature_id` (F001-F999), `title`, `description`, `files_to_touch` (array, min 1), `depends_on` (array of task IDs, empty = no deps), `order_hint` (integer >= 1)
- `estimated_order`: array of all task IDs in suggested execution order

### Validation

```bash
ls -la .aide/output/2-plan/*-plan.md .aide/output/2-plan/*-plan.json
```

### Gate

Process the `after_plan` gate per the loaded configuration.

### State update

Update `.aide/state.json`:
```json
{
  "slug": "<slug>",
  "current_stage": "implement",
  "completed_stages": ["spec", "plan"],
  "test_retries": 0,
  "last_updated": "<ISO timestamp>"
}
```

**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: true},
  {id: "2", label: "Plan", checked: true},
  {id: "3", label: "Implement", checked: false},
  {id: "4", label: "Test", checked: false}
])
```

---

## Stage 3: implement

**CHECK**: `current_stage` must be `"implement"`. Both spec AND plan must be in `completed_stages`.

**YOU MAY NOW WRITE SOURCE CODE.**

**Mode**: Switch to YOLO if not already — sub-agents need write access without per-edit prompts. Run `/yolo` now.

### Task Dispatch with Dependency-Aware Batching

Read the plan:
```bash
cat .aide/output/2-plan/*-plan.json
```

Parse the `tasks` array. Build two structures:
- `completed`: set of done task IDs (starts empty)
- `ready`: tasks where all `depends_on` entries are in `completed`
- `waiting`: tasks with unmet dependencies

**Batching algorithm**:

1. From `ready`, select up to 3 tasks that are mutually independent (no task in the batch depends on any other task in the batch)
2. Dispatch them in parallel using `agent_open`
3. Wait for `<codewhale:subagent.done>` sentinels. When a sentinel arrives:
   a. Read the **summary line** that precedes the sentinel (CodeWhale injects this automatically)
   b. If summary indicates **DONE**: mark task complete, no further reading needed
   c. If summary indicates **BLOCKED**: use `agent_eval` + `handle_read` to fetch the blocker reason
   d. If summary is **ambiguous**: use `handle_read` with a line-range slice for clarification
4. For each completed task: add to `completed`, move dependent tasks from `waiting` to `ready`
5. If a task fails/errors: mark as `blocked` with reason, block tasks that depend on it
6. Repeat until `ready` is empty or all remaining are blocked

**CodeWhale source basis**: `agent_open` is non-blocking (returns immediately). The runtime injects a `<codewhale:subagent.done>` sentinel with a human-readable summary line. `agent_eval` provides a `transcript_handle`, and `handle_read` supports slices, line ranges, or JSONPath projections for bounded retrieval — keeping the parent context lean. (CodeWhale README, Sub-agents section)

**Per-task sub-agent prompt template**:
```
Execute the following implementation task. Write/edit files as needed.

Task ID: {task_id}
Feature: {feature_id}
Title: {title}
Description: {description}
Files to touch: {files_to_touch}

Acceptance criteria (from spec):
{acceptance_criteria}

Project context:
{context_memo}

After implementation, self-review your changes against the acceptance criteria.
Report: [DONE] or [BLOCKED: reason].
```

### Code Analysis Pass

After all batches complete, read every file listed in `changed_files`. Perform analysis covering:
- **Correctness**: logic errors, off-by-one, null/undefined risks, resource leaks
- **Security**: injection risks, missing validation, exposed secrets
- **Quality**: dead code, overly complex functions, missing error handling
- **Style**: naming consistency, pattern adherence with existing codebase

### Output: `.aide/output/3-implement/<date>-<slug>-implement.json`

```json
{
  "completed_tasks": ["T001", "T003"],
  "blocked_tasks": [
    {"task_id": "T002", "reason": "Depends on blocked T001"}
  ],
  "changed_files": ["src/foo.ts", "src/bar.ts"],
  "task_results": [
    {
      "task_id": "T001",
      "status": "done",
      "commits": ["abc1234"],
      "review_summary": "Implemented feature correctly, all criteria met"
    },
    {
      "task_id": "T002",
      "status": "blocked",
      "reason": "Dependency T001 not completed"
    }
  ],
  "analysis": {
    "files_analyzed": ["src/foo.ts", "src/bar.ts"],
    "issues": [
      {
        "severity": "critical|warning|info",
        "file": "src/foo.ts",
        "line": 42,
        "message": "Issue description",
        "category": "correctness|security|quality|style"
      }
    ]
  }
}
```

Schema rules:
- `completed_tasks`: array of task ID strings (T001-T999)
- `blocked_tasks`: array of `{task_id, reason}`
- `changed_files`: array of file path strings
- `task_results`: array of `{task_id, status: "done"|"blocked"}`, with `commits`+`review_summary` when done, `reason` when blocked
- `analysis`: `{files_analyzed, issues}` where issues have `severity`, `file`, `line`, `message`, `category`

### Gate

`auto` — no user interaction. Proceed directly.

### State update

Update `.aide/state.json`:
```json
{
  "slug": "<slug>",
  "current_stage": "test",
  "completed_stages": ["spec", "plan", "implement"],
  "test_retries": 0,
  "last_updated": "<ISO timestamp>"
}
```

**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: true},
  {id: "2", label: "Plan", checked: true},
  {id: "3", label: "Implement", checked: true},
  {id: "4", label: "Test", checked: false}
])
```

---

## Stage 4: test

**CHECK**: `current_stage` must be `"test"`.

### Workflow

1. Read `changed_files` from `.aide/output/3-implement/*-implement.json`
2. Execute the project's test suite against changes
3. Verify each feature's acceptance criteria against the implementation
4. Run a code verification pass:
   - **Bug detection**: logic errors, edge cases not covered, incorrect assumptions
   - **Security audit**: injection vectors, missing auth, data exposure
   - **Regression risk**: could changes break existing functionality? Trace callers.
   - **Test quality**: meaningful assertions or superficial?

### Output: `.aide/output/4-test/<date>-<slug>-test-report.md`

Human-readable test report.

### Output: `.aide/output/4-test/<date>-<slug>-test-report.json`

```json
{
  "test_suite": {
    "passed": 5,
    "failed": 0,
    "skipped": 0,
    "command": "npm test",
    "output": "Test run summary..."
  },
  "spec_verification": [
    {
      "feature_id": "F001",
      "criteria": "User can log in with OAuth",
      "status": "pass",
      "evidence": "E2E test covers OAuth flow"
    }
  ],
  "coverage": {
    "files_with_tests": ["src/foo.ts"],
    "files_without_tests": [],
    "overall": "All changed files have test coverage"
  },
  "verdict": "pass",
  "verification": {
    "critical": 0,
    "warning": 0,
    "info": 2,
    "issues": [
      {
        "severity": "info",
        "file": "src/foo.ts",
        "line": 88,
        "message": "Consider adding input validation",
        "category": "security"
      }
    ]
  }
}
```

Schema rules:
- `test_suite`: `{passed, failed, skipped, command, output}`
- `spec_verification`: array of `{feature_id, criteria, status: "pass"|"fail"|"untestable", evidence}`
- `coverage`: `{files_with_tests, files_without_tests, overall}` (optional)
- `verdict`: `"pass"` | `"fail"` | `"manual"`
- `verification`: `{critical, warning, info, issues[]}` — each issue `{severity, file, line, message, category}`
- **Verdict influence**: if `verification.critical > 0`, downgrade a `pass` verdict to `fail`

### Retry Logic

Read `verdict` from test-report.json:
- `pass` → auto-complete
- `fail` or `manual`:
  - Read `test_retries` from state.json
  - If < 3: increment retries, feed failures back to Stage 3 (re-run failed tasks, then re-run test)
  - If >= 3: ask user — accept as-is or reset retries and retry

### State update (on pass or user accept)

Update `.aide/state.json`:
```json
{
  "slug": "<slug>",
  "current_stage": "complete",
  "completed_stages": ["spec", "plan", "implement", "test"],
  "last_updated": "<ISO timestamp>"
}
```

**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: true},
  {id: "2", label: "Plan", checked: true},
  {id: "3", label: "Implement", checked: true},
  {id: "4", label: "Test", checked: true}
])
```

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

Pipeline artifacts committed to the current branch. No merge needed.

---

## Resume

If `.aide/state.json` exists with `current_stage` not equal to `"complete"` or `"spec"` when you start, resume from that stage. Do NOT re-run completed stages (check `completed_stages` array).

Tell the user: "Resuming AIDE pipeline from Stage N."
