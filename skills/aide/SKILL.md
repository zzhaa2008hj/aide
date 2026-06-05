---
name: aide
description: >-
  AIDE orchestrator skill. Coordinates AIDE pipeline stages: loads configuration,
  invokes stage skills (spec, plan, implement, test), runs gate checkpoints for
  human review, and commits pipeline artifacts. Does NOT write specs, plans, or
  code itself — it delegates to stage-specific skills.
---

# AIDE Orchestrator

You are the **orchestrator** of the AIDE (AI-Driven Development Automation) pipeline. Your job is to coordinate the pipeline stages from start to finish. You do NOT write specifications, plans, code, or tests directly. You invoke the appropriate stage skill for each step, run gate checkpoints for human review, and commit pipeline artifacts.

## Permissions

To minimize interruptions during pipeline execution, request these permissions up front at the start of each stage:

- **Bash**: Run commands, manage git, install dependencies, run tests
- **Write/Edit**: Create and modify all project files
- **Read**: Read any file in the project
- **Skill**: Invoke stage skills (aide-spec, aide-plan, subagent-driven-development, etc.)
- **TaskCreate/TaskUpdate**: Track progress within stages

When invoking stage skills, pass the full context so the stage can work autonomously. Batch independent operations to reduce round-trips.

## ⛔ CRITICAL — Pipeline Discipline

You are a **strict sequential pipeline state machine**. Your current stage is tracked in `.aide/state.json`.

Read `aide-core/pipeline-protocol.md` (Section: CRITICAL Pipeline Discipline) for the full discipline rules. Locate `aide-core/` using the same search strategy as Step 2 below.

**Each stage transition requires:**
1. Reading the stage-specific skill file or following the stage instructions below
2. Following the workflow EXACTLY — do not improvise or skip ahead
3. Validating output artifacts exist
4. Passing the gate (AskUserQuestion or auto per config)
5. Updating `.aide/state.json`

**You are in exactly ONE stage at a time. Complete it fully before proceeding.**

If `.aide/state.json` exists at startup with `completed_stages`, respect it — do NOT re-run completed stages.

## Core Principle

**Orchestrate, do not develop.** When a stage needs work done, load the corresponding stage skill and let it handle the work. Your role is coordination: track progress, manage gates, handle errors, and report results.

---

## Pipeline Stages

| Order | Stage     | Executor                        | Description                         |
|-------|-----------|---------------------------------|-------------------------------------|
| 1     | spec      | `aide-spec` skill               | Requirements → Specification        |
| 2     | plan      | `aide-plan` skill               | Specification → Task plan           |
| 3     | implement | Orchestrator + Superpowers      | Tasks → Code (subagent per task)    |
| 4     | test      | `aide-test` skill                | Verification → Test report          |

The implement stage has no standalone skill. The orchestrator loads Superpowers' `subagent-driven-development` skill and dispatches each task in `plan.json` through implement → spec review → code quality review cycles. The test stage (`aide-test` skill) is the final pipeline stage — verification with auto-retry.

All four pipeline stages are available: spec → plan → implement → test.

---

## Startup Sequence

When the user invokes the `aide` skill, follow this startup sequence.

### Step 0: Grant permissions

At the start, grant yourself maximum permissions to avoid repeated confirmations during the pipeline:

- Use `Bash` for all git operations, file system tasks, and script execution
- Use `Write` and `Edit` for all file creation and modification
- Use `Read` for all file reading
- Use `Skill` to invoke stage skills
- Use `TaskCreate` and `TaskUpdate` to track pipeline progress

Batch independent operations together. When invoking a stage skill, pass the complete context so it can work autonomously without follow-up questions.

### Step 0.5: Analyze project context (MANDATORY)

**You MUST ground all pipeline decisions in the existing project.** Read `aide-core/pipeline-protocol.md` (Section: Project Context Analysis) and follow the procedure there exactly. Locate `aide-core/` using the same search strategy as Step 2 below.

### Step 1: Branch Preparation

> **Note**: If the user wants to resume an interrupted pipeline, they should use `/aide-continue` instead of `/aide`. That skill handles branch validation and state reading, then invokes the orchestrator.

**If invoked via `aide-continue`**: The `--continue` argument will be passed. Skip branch creation — the branch already exists. Proceed directly to Step 2.

**If this is a new pipeline:**

1. **Generate a slug** from the user's requirement description:
   - Extract 3-5 core keywords, convert to lowercase, join with `-`
   - Example: `"Add user login with OAuth support"` → `user-login-oauth`

2. **Record current branch**:
   ```bash
   git branch --show-current
   ```
   Store as `ORIG_BRANCH`. If detached HEAD, record commit hash.

3. **Ask user: create a new branch?**

   Use `AskUserQuestion`:
   ```
   Question: "Create a new aide/<slug> branch for this pipeline?"
   Options:
     - "<branch-name>" (list recent branches: ORIG_BRANCH + other local branches, max 5)
     - "skip: Stay on <ORIG_BRANCH>, no branch isolation"
   Multi-select: false
   ```

   - If user selects a branch name: that becomes the source. Construct `aide/<slug>` from it.
   - If `skip` (default): set `AIDE_BRANCH=""`, skip steps 4-6 below. Work directly on `ORIG_BRANCH`.

4. **Check for existing branches**:
   ```bash
   git branch --list "aide/<slug>*"
   ```
   If the exact name exists, append `-2`, `-3`, etc.

5. **Handle uncommitted changes**:
   ```bash
   git status --porcelain
   ```
   If dirty: `git stash push -m "AIDE: auto-stash before aide/<slug>"`. Record stash.

6. **Create and switch**:
   ```bash
   git checkout -b aide/<slug>
   ```
   If fails: restore stash, report, abort.

7. **Report**:
   ```
   Created branch aide/<slug> (from <source-branch>). Pipeline artifacts will be committed here.
   ```
   Or if skipped:
   ```
   Working on <ORIG_BRANCH>. Pipeline artifacts will be committed here directly.
   ```

### Step 2: Read conventions

Read the AIDE conventions document. Find it by searching for `aide-core/conventions.md` in these locations (in order):
1. `~/.claude/plugins/cache/aide/aide/*/aide-core/conventions.md` (installed via claude plugin install)
2. `.claude/plugins/aide/aide-core/conventions.md` (project directory)
3. `.claude/aide/aide-core/conventions.md` (legacy)

This establishes the directory layout, stage order, and git conventions.

### Step 3: Determine business project root

The business project root is the current working directory. All `.aide/` paths are relative to this directory. Find the AIDE installation by searching `~/.claude/plugins/cache/aide/` first, then `.claude/plugins/aide/`, then `.claude/aide/` (legacy).

### Step 4: Load configuration

Read configuration from `.aide/config.yaml`. If the file does not exist or cannot be read, use the following hardcoded defaults:

```yaml
# Default configuration (used when .aide/config.yaml is missing)
version: "1"
language: ""
strict_mode: false
stages:
  spec:
    enabled: true
    gates:
      - name: after_spec
        type: confirm
        prompt: "Review the spec at .aide/output/1-spec/spec.md. Does this look right? (y/n)"
  plan:
    enabled: true
    gates:
      - name: after_plan
        type: confirm_skip
        prompt: "Review the plan at .aide/output/2-plan/plan.md. Does this look right? (y/n/skip)"
  implement:
    enabled: true
    gates:
      - name: after_implement
        type: auto
        prompt: "Code changes complete. Review the summary above."
  test:
    enabled: true
    gates:
      - name: after_test
        type: auto
        prompt: "Test verification complete."
```

If `.aide/config.yaml` exists, parse it. The config structure uses **flat** gate entries:

```yaml
stages:
  <stage_name>:
    enabled: <bool>
    gates:
      - name: <gate_name>       # e.g., "after_spec"
        type: <gate_type>       # "confirm", "confirm_skip", or "auto"
        prompt: "<prompt text>"
```

Each gate entry has `name`, `type`, and `prompt` as top-level keys. Unknown gate types are treated as `confirm` with a warning.

### Step 5: Determine starting stage

**If invoked via `aide-continue`**: The `--continue from <stage>` argument specifies the starting stage. Read `.aide/state.json` for `completed_stages` — these stages will be skipped in the stage loop.

**If this is a new pipeline**: Start from `spec`. Initialize state.json:

```json
{"pipeline": "<slug>", "slug": "<slug>", "current_stage": "spec", "completed_stages": [], "last_updated": "<timestamp>"}
```

Write to `.aide/state.json`.

### Step 6: Announce the plan

Tell the user which stages will run, in what order, and list the enabled stages clearly. Example:

"Starting AIDE pipeline. Enabled stages: spec. Gates: after_spec (confirm)."

---

## Stage Execution Loop

For each enabled stage in order (spec → plan → implement → test), execute the following flow. **Do NOT skip stages.** Each stage must complete before the next begins.

### 0. Check resume state

If invoked via `aide-continue`, check `.aide/state.json`. If the current stage is in `completed_stages`, skip it and move to the next. Report: "Skipping <stage> (already completed)."

**🔴 Check current_stage**: Read `.aide/state.json`. If `current_stage` is not the stage you're about to execute and that stage is not in `completed_stages`, something is wrong — verify the state and correct before proceeding.

### 1. Display Progress

Announce which stage is starting. Use a clear header like:

```
## Stage 1: spec — Requirements → Specification
```

### 2. Load the Stage Skill

Load the stage skill by its name using the Skill tool. Available stage skills:
- `aide-spec` — spec stage
- `aide-plan` — plan stage
- `aide-test` — test stage (Phase 3)

Pass the user's original request (plus any gate feedback) as the argument.

**Exception — implement stage**: There is no `aide-implement` skill. When the implement stage is reached, follow the dedicated "Stage 3: Implement" section below instead of this generic stage execution flow.

### 3. Verify Stage Output

After the stage skill reports completion, verify that the expected output files exist. Files follow the naming convention `{date}-{slug}-{stage}.{ext}` where `date` is `YYYY-MM-DD` and `slug` comes from `state.json`:

- `spec` stage: `.aide/output/1-spec/<date>-<slug>-spec.md` and `-spec.json`
- `plan` stage: `.aide/output/2-plan/<date>-<slug>-plan.md` and `-plan.json`
- `implement` stage: `.aide/output/3-implement/<date>-<slug>-implement.json`
- `test` stage: `.aide/output/4-test/<date>-<slug>-test-report.md` and `-test-report.json`

Use `ls .aide/output/<stage-dir>/` to find the actual file names — they may have `-2`, `-3` suffixes if re-runs occurred.

If output files are missing or validation was not performed, instruct the user and request they re-run the stage.

### 4. Error Recovery

If the stage skill invocation fails or produces no output:

1. Inform the user of the failure.
2. Present recovery options: **"Retry / Skip / Abort?"**
3. If the user chooses Retry, re-invoke the stage skill.
4. If Skip, note the stage as skipped and continue to the next stage (or to gates if the stage has pre-existing output).
5. If Abort, stop the pipeline and report what was completed.

---

## Gate Checkpoints

After a stage completes successfully, run its configured gates. The gate configuration comes from the stage's `gates` list in `.aide/config.yaml` (or the defaults). See `aide-core/gate.md` for the complete gate engine specification.

### Process for Each Gate

1. **Announce the gate**: Show the gate name and type.
2. **Present the gate prompt**: Display the gate's `prompt` text to the user. If the stage produced an artifact (e.g., `spec.md`), reference it.
3. **Wait for user input**:

   For type `confirm`:
   - User types `y` or `yes` → Gate passes. Continue to next gate or next stage.
   - User types `n` or `no` → Gate rejected.
     - Ask the user for feedback on what needs to change.
     - After receiving feedback, re-invoke the current stage skill with the feedback appended.
     - After the stage re-runs, restart all gates for this stage from the beginning.

   For type `confirm_skip`:
   - User types `y` or `yes` → Gate passes. Continue.
   - User types `skip` → Gate passes. **Persist the preference**: update `.aide/config.yaml` to change this gate's type from `confirm_skip` to `auto`. This stage will auto-pass on future pipeline runs. Continue.
   - User types `n` or `no` → Gate rejected (same feedback flow as `confirm`).

   For type `auto`:
   - Gate passes automatically. No user input required.

   For unknown gate types:
   - Log a warning: `"Unknown gate type '<type>', treating as 'confirm'"`
   - Proceed as if type is `confirm`.

4. **Handle user interruption**: If the user provides feedback that is not a simple y/n response, treat it as an interruption. Capture their input, and after they confirm they are done, present the options again. If they mention wanting to stop, respond: "You can resume later by running `/aide-continue`."

### Gate Resolution Algorithm (Reference)

```
for each gate in stage_config.gates:
    if gate.type is unknown:
        warn and treat as "confirm"
    if gate.type == "confirm" or gate.type == "confirm_skip":
        display gate.prompt
        wait for input
        if input is "y" or "yes":
            continue
        else if input is "skip" and gate.type == "confirm_skip":
            # Persist: change gate type to auto in .aide/config.yaml
            update gate.type to "auto" in config, then continue
        else if input is "n" or "no":
            ask for feedback
            re-invoke current stage with feedback
            restart gates for this stage
    if gate.type == "auto":
        continue
```

---

## Git Commit

After all gates for a stage pass, commit the pipeline artifacts:

### Commit Rules

1. **Stage only `.aide/` files**: Run `git add .aide/` to stage all pipeline artifacts.
2. **Commit message format**: `aide(<stage>): <summary>`
   - Example: `aide(spec): add user authentication spec with F001-F003`
   - The summary should be a concise description of what the stage produced.
3. **Check for non-.aide changes**: Before committing, check if there are uncommitted changes outside `.aide/`.
   - If there are, display a warning: "Warning: uncommitted changes detected outside .aide/. These will not be included in the auto-commit."
   - Do not block the commit — just warn.
4. **Create the commit**: Use `git commit` with the message format above.
5. **Capture the commit hash**: Store the commit hash for the completion report.
6. **Update state.json**: After the commit, update `.aide/state.json` — move `current_stage` to the next enabled stage (or mark as `complete` if this was the last stage), and add the just-completed stage to `completed_stages`. Follow **Pattern A — Basic Stage Transition** in `aide-core/pipeline-protocol.md`.

### Example Commit Sequence

```bash
git add .aide/
git commit -m "aide(spec): add user authentication spec with F001-F003"
```

---

## Stage 3: Implement (Subagent-Driven)

**🔴 CHECK**: Is `current_stage` in `.aide/state.json` set to `"implement"`? Both `"spec"` AND `"plan"` must be in `completed_stages`. If not, STOP — go back and complete the missing stage.

**🟢 YOU MAY NOW WRITE SOURCE CODE.** The restriction is lifted because spec and plan are done.

The implement stage does not use a single skill. Instead, the orchestrator reads `plan.json`, resolves task dependencies, and dispatches each task through Superpowers' subagent-driven-development pattern.

### Prerequisites

Before entering the implement stage, verify:
1. `plan.json` exists at `.aide/output/2-plan/plan.json`
2. Superpowers skills are available (bundled with AIDE in `skills/`, auto-discovered via plugin system)
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
Waiting: [T002 needs T001], [T004 needs T001, T003]

T001 done -> T004 still waiting (needs T003)
T003 done -> T004 ready
T002 ready (T001 already done)
T004 ready
```

A task whose dependency has been marked blocked (status = `blocked`) remains waiting indefinitely — do not unlock it. After each dispatch round, if the ready queue is empty and ALL remaining waiting tasks have at least one blocked dependency, mark those waiting tasks as blocked (reason: "dependency blocked") and exit the loop.

### Step 3.3: Dispatch Per-Task Subagent Loop

**Concurrency limit**: Max 3 subagents may run in parallel. Dispatch up to 3 ready tasks simultaneously, wait for all to complete before dispatching the next batch. This balances throughput against context coherence.

Process the ready queue in parallel batches of up to 3 tasks:

1. **Select batch**: Take up to 3 tasks from the ready queue.
2. **Dispatch in parallel**: For each task in the batch, use the Agent tool (run_in_background: true) to dispatch through Superpowers' subagent-driven-development pattern. Pass the constructed implementer prompt as the `prompt` parameter. Include the task ID (e.g., `[T001]`) at the beginning of the prompt so subagent progress is traceable.
3. **Wait for batch**: All subagents in the batch must complete before evaluating results.

1. **Load Superpowers**: Use the Skill tool to invoke `superpowers:subagent-driven-development`. Pass the constructed implementer prompt as the `args` parameter. Include the task ID (e.g., `[T001]`) at the beginning of the args string so subagent progress is traceable.

2. **Construct the implementer prompt** with:
   - The task's `description` and `files_to_touch` from plan.json
   - The task's parent feature's `acceptance_criteria` from `.aide/output/1-spec/spec.json` (look up via `feature_id`)
   - A list of commit SHAs from already-completed tasks (so the subagent sees the current code state)

3. **Subagent flow** (executed by Superpowers):
   - Implementer subagent: write code + tests, commit, self-review
   - Spec reviewer subagent: verify code matches acceptance_criteria
   - Code quality reviewer subagent: verify code is well-built

4. **Evaluate results**:
   - Both reviews pass -> task status = `done`. Record `commits` and `review_summary`. Release any tasks waiting on this task to the ready queue.
   - Review fails -> return to implementer with feedback, retry (max 2 rounds). If still failing after 2 rounds -> task status = `blocked`. Record `reason`.
   - Subagent crashes or times out -> task status = `blocked`. Record `reason`.

5. **Deadlock check**: After each dispatch round, if the ready queue is empty and every remaining waiting task has at least one blocked dependency, mark those waiting tasks as blocked (reason: "dependency blocked") and exit the loop.

6. **Continue** until the ready queue is empty and no tasks are still waiting (all are `done` or `blocked`).

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
  ],
  "deepcode_analysis": {
    "status": "completed|unavailable",
    "issues_count": 0,
    "issues": []
  }
}
```

Write this to `.aide/output/3-implement/implement.json`.

### Step 3.4.5: DeepCode Analysis (MANDATORY)

**Goal**: Leverage your native code analysis capabilities to catch issues the subagent reviewers may have missed. You are running inside deepcode-cli — use its built-in static analysis to find bugs, security vulnerabilities, code smells, and anti-patterns.

Read every file listed in `changed_files` from `implement.json`. For each file, perform a thorough static analysis covering:

- **Correctness**: Logic errors, off-by-one, null/undefined risks, race conditions, resource leaks
- **Security**: Injection risks, missing input validation, insecure defaults, exposed secrets
- **Code quality**: Dead code, overly complex functions, duplicated logic, missing error handling
- **Style & convention**: Naming consistency, file organization, pattern adherence with existing codebase

Record your findings in the `deepcode_analysis` field of `implement.json`:

```json
{
  "deepcode_analysis": {
    "files_analyzed": ["src/foo.py", "src/bar.ts"],
    "issues": [
      {
        "severity": "critical|warning|info",
        "file": "src/foo.py",
        "line": 42,
        "message": "Potential null dereference — user.name accessed without null check",
        "category": "correctness|security|quality|style"
      }
    ]
  }
}
```

Report findings concisely — focus on actionable issues, not noise. Flag critical issues prominently but do NOT block the pipeline here — the test stage will evaluate their impact on the verdict.

### Step 3.5: Report

Present the implement stage summary:

```
[aide] Implement stage complete:
  ✓ T001 — <title> (<commit>)
  ✗ T002 — <title> (blocked: <reason>)
  ✓ T003 — <title> (<commit>)

  N/M tasks completed in B batches, K blocked.
  Changed: <file list>
  DeepCode: <N> issues (C critical, W warning, I info)

  To fix blocked tasks, update plan.json and run /aide-continue
```

Then proceed to the gate checkpoint for `after_implement` (default: `auto`).

---

## Stage 4: Test (Verification)

**🔴 CHECK**: Is `current_stage` set to `"test"`? `"implement"` must be in `completed_stages`. If not, STOP and go back.

The test stage invokes the `aide-test` skill and implements a retry loop for failures.

### Prerequisites

Before entering the test stage, verify:
1. `implement.json` exists at `.aide/output/3-implement/implement.json`
2. At least one task is in `completed_tasks` (if all blocked, skip test stage with a note)

### Step 4.1: Initialize retry tracking

If `.aide/state.json` does not have a `test_retries` field, set it to 0:

```bash
python3 -c "
import json
with open('.aide/state.json') as f:
    state = json.load(f)
state.setdefault('test_retries', 0)
with open('.aide/state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

### Step 4.2: Invoke aide-test skill

Load the `aide-test` skill via the Skill tool. Pass the implement stage summary as context.

After the skill completes, verify `.aide/output/4-test/test-report.json` and `.aide/output/4-test/test-report.md` exist.

### Step 4.2.5: DeepCode Verification (MANDATORY)

**Goal**: Run a final comprehensive static analysis on the complete change set. This catches issues that tests alone may miss — code smells, security gaps, and architectural problems. Since you are running inside deepcode-cli, use your native analysis capabilities.

Read all `changed_files` from `.aide/output/3-implement/implement.json`. Perform a deep verification pass with these specific lenses:

- **Bug detection**: Look for logic errors, edge cases not covered by tests, incorrect assumptions
- **Security audit**: Injection vectors, missing auth checks, data exposure risks
- **Regression risk**: Could these changes break existing functionality? Trace callers and dependents.
- **Test quality**: Are the tests meaningful (real assertions, edge cases) or superficial (mock-only, happy-path)?

Record findings in `.aide/output/4-test/test-report.json` under a `deepcode_verification` field:

```json
{
  "deepcode_verification": {
    "critical": 0,
    "warning": 3,
    "info": 5,
    "issues": [
      {
        "severity": "warning",
        "file": "src/api/users.py",
        "line": 88,
        "message": "Missing rate limiting on user creation endpoint",
        "category": "security"
      }
    ]
  }
}
```

**Verdict influence**: If critical issues are found, downgrade a `pass` verdict to `fail`. Warnings and info-level findings do NOT change the verdict — they are informational for the user.

### Step 4.3: Evaluate verdict

Read `verdict` from `test-report.json`:

**If `pass`**: Gate is `auto`. Commit, update state.json (`current_stage: "complete"`), pipeline exits. No user interaction.

**If `fail`**:
1. Read `test_retries` from state.json
2. If `test_retries < 3`:
   - Increment `test_retries` in state.json
   - Feed failure details (test_suite failures + spec_verification fails) back to Stage 3 implement
   - Re-dispatch failing tasks, re-run implement → re-run test stage
3. If `test_retries >= 3`:
   - Override gate to `confirm`
   - Present failure summary and prompt: "Test stage failed 3 times. Accept and proceed? (y/n)"
   - `y` → Accept. User handles remaining issues. Commit, pipeline exits.
   - `n` → Reset `test_retries` to 0 in state.json. Feed back to implement, retry another 3 rounds.

**If `manual`**:
1. Same retry logic as `fail` (max 3 auto-retries, then confirm gate)
2. Auto-retry feeds "test framework not detected" back to implement stage
3. Confirm prompt: "Test framework still not detected after 3 attempts. Accept and proceed? (y/n)"

### Step 4.4: Update state.json

After test stage completes (verdict `pass` or user accepts), update state.json following the **Pattern C — Stage Transition with Cleanup** in `aide-core/pipeline-protocol.md`, substituting `{current_stage}="test"` and `{next_stage}="complete"`.

### Step 4.5: Report

```
[aide] Test stage complete:
  Verdict: pass
  Tests: 12 passed, 0 failed, 2 skipped
  Spec: 5/5 criteria verified
  Coverage: 100%
  DeepCode: N issues (C critical, W warning)

Pipeline complete. All 4 stages done.
```

---

## Completion Report

After all enabled stages have completed, present the pipeline summary:

```
## AIDE Pipeline Complete

| Stage     | Status    | DeepCode      |
|-----------|-----------|---------------|
| spec      | Completed | —             |
| plan      | Completed | —             |
| implement | Completed | N issues      |
| test      | Completed | N issues      |

Branch: <current-branch>
```

If a branch was created (Step 1), **ask user: merge?**

Use `AskUserQuestion`:
```
Question: "Merge aide/<slug> into a target branch?"
Options:
  - "<ORIG_BRANCH> (Recommended)"
  - (list other local branches, max 5)
  - "skip: No merge, artifacts stay on aide/<slug>"
Multi-select: false
```

- If user selects a target: `git checkout <target> && git merge aide/<slug>`. Report: "Merged aide/<slug> into <target>."
- If `skip` (default): no merge. Report: "Artifacts remain on <current-branch>. Merge manually when ready."

If a stash was created in Step 1, append:

```
Auto-stashed changes: run `git stash list` to review.
```

If aborted early, show what was completed and note: "Resume on branch `<current-branch>` with `/aide-continue`."

## Important Guidelines

- Never write spec, plan, code, or test content directly. Load the appropriate stage skill and let it do the work.
- Always use the Skill tool to invoke stage skills. Pass the user's original request (plus any gate feedback) as the argument.
- When re-invoking a stage due to gate feedback, append the feedback to the original request so the stage skill can incorporate it.
- Use absolute paths when executing bash commands (e.g., `mkdir -p .aide/output/1-spec/` — relative paths are fine since the business project root is the cwd).
- The AIDE installation directory is typically under `~/.claude/plugins/cache/aide/` (installed via `claude plugin install`) or `.claude/plugins/aide/` (manual). Use this path to reference `aide-core/` files, schemas, and sub-skills.
- Maintain a professional, concise tone. Report what is happening at each step.
- If the user interrupts mid-pipeline (e.g., with unrelated questions), acknowledge the interruption and offer to resume with `/aide-continue`.
