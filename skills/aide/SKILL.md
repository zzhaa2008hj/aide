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

## Core Principle

**Orchestrate, do not develop.** When a stage needs work done, load the corresponding stage skill and let it handle the work. Your role is coordination: track progress, manage gates, handle errors, and report results.

---

## Pipeline Stages

| Order | Stage     | Executor                        | Description                         |
|-------|-----------|---------------------------------|-------------------------------------|
| 1     | spec      | `aide-spec` skill               | Requirements → Specification        |
| 2     | plan      | `aide-plan` skill               | Specification → Task plan           |
| 3     | implement | Orchestrator + Superpowers      | Tasks → Code (subagent per task)    |
| 4     | test      | `aide-test` skill (Phase 3)     | Verification → Test report          |

The implement stage has no standalone skill. The orchestrator loads Superpowers' `subagent-driven-development` skill and dispatches each task in `plan.json` through implement → spec review → code quality review cycles. The test stage (`aide-test` skill) is planned for Phase 3 — it is not yet implemented.

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

### Step 1: Branch Preparation (new pipeline) or Branch Validation (--continue)

**If the user passed `--continue`:**

1. Get the current branch name:
   ```bash
   git branch --show-current
   ```
2. If the current branch does NOT start with `aide/`:
   - Report: "`--continue` requires you to be on an `aide/*` branch. Current branch: `<name>`. Please switch to the correct branch and try again."
   - Abort.
3. If the current branch IS an `aide/*` branch:
   - Report: "Resuming pipeline on branch `<current-branch>`."
   - Skip the rest of Step 1 and proceed to Step 2.

**If this is a new pipeline (no `--continue`):**

1. **Generate a slug** from the user's requirement description. Follow these rules:
   - Extract 3-5 core keywords, convert to lowercase, join with `-`
   - Use only letters, numbers, and hyphens
   - Example: `"Add user login with OAuth support"` → `user-login-oauth`
   - Example: `"Build a REST API for orders"` → `rest-api-orders`

2. **Construct the branch name**: `aide/<slug>`

3. **Check for existing branches with the same name**:
   ```bash
   git branch --list "aide/<slug>*"
   ```
   - If the exact name exists, append `-2`, `-3`, etc. until a free name is found.
   - Example: `aide/user-login-oauth` exists → try `aide/user-login-oauth-2`, then `aide/user-login-oauth-3`, etc.

4. **Record the original branch**:
   ```bash
   git branch --show-current
   ```
   Store this as `ORIG_BRANCH`. If the user is in detached HEAD state, record the commit hash instead.

5. **Check for uncommitted changes**:
   ```bash
   git status --porcelain
   ```
   - If there are uncommitted changes (dirty working tree):
     ```bash
     git stash push -m "AIDE: auto-stash before aide/<slug>"
     ```
     Record that a stash was created so it can be reported later.
   - If stash fails, report the error and abort.

6. **Create and switch to the new branch**:
   ```bash
   git checkout -b aide/<slug>
   ```
   - If this fails: restore the stash (if one was created) with `git stash pop`, report the error, and abort.

7. **Report**:
   ```
   Created branch aide/<slug> (from <ORIG_BRANCH>). Pipeline artifacts will be committed here.
   ```
   If a stash was created:
   ```
   Uncommitted changes stashed. Restore with: git stash pop
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
    enabled: false
    gates: []
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

Start from the `spec` stage by default. If `.aide/state.json` exists, read it to determine where to resume (future: state persistence for `--continue` across sessions).

### Step 6: Announce the plan

Tell the user which stages will run, in what order, and list the enabled stages clearly. Example:

"Starting AIDE pipeline. Enabled stages: spec. Gates: after_spec (confirm)."

---

## Stage Execution Loop

For each enabled stage in order (spec → plan → implement → test), execute the following flow:

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

After the stage skill reports completion, verify that the expected output files exist:

- `spec` stage: `.aide/output/1-spec/spec.md` and `.aide/output/1-spec/spec.json`
- `plan` stage: `.aide/output/2-plan/plan.md` and `.aide/output/2-plan/plan.json`

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
   - User types `skip` → Gate passes (skipped). Continue.
   - User types `n` or `no` → Gate rejected (same feedback flow as `confirm`).

   For type `auto`:
   - Gate passes automatically. No user input required.

   For unknown gate types:
   - Log a warning: `"Unknown gate type '<type>', treating as 'confirm'"`
   - Proceed as if type is `confirm`.

4. **Handle user interruption**: If the user provides feedback that is not a simple y/n response, treat it as an interruption. Capture their input, and after they confirm they are done, present the options again. If they mention wanting to stop, respond: "You can resume later by running `/aide --continue`."

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
            continue
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

### Example Commit Sequence

```bash
git add .aide/
git commit -m "aide(spec): add user authentication spec with F001-F003"
```

---

## Stage 3: Implement (Subagent-Driven)

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

  N/M tasks completed in B batches, K blocked.
  Changed: <file list>

  To fix blocked tasks, update plan.json and run /aide --continue
```

Then proceed to the gate checkpoint for `after_implement` (default: `auto`).

---

## Completion Report

After all enabled stages have completed (or the pipeline was aborted), present a summary:

```
## AIDE Pipeline Complete

| Stage   | Status     | Commit                                   |
|---------|------------|------------------------------------------|
| spec    | Completed  | abc1234 (aide(spec): add auth spec)      |
| plan    | Skipped    | —                                        |
| implement | Skipped  | —                                        |
| test    | Skipped    | —                                        |

Branch: aide/<slug>
Original branch: <ORIG_BRANCH>

Next steps:
  git checkout <ORIG_BRANCH> && git merge aide/<slug>
```

If a stash was created in Step 0, append:

```
Auto-stashed changes: run `git stash list` to review.
```

If aborted early, show what was completed and note: "Resume on branch `aide/<slug>` with `/aide --continue`."

## Important Guidelines

- Never write spec, plan, code, or test content directly. Load the appropriate stage skill and let it do the work.
- Always use the Skill tool to invoke stage skills. Pass the user's original request (plus any gate feedback) as the argument.
- When re-invoking a stage due to gate feedback, append the feedback to the original request so the stage skill can incorporate it.
- Use absolute paths when executing bash commands (e.g., `mkdir -p .aide/output/1-spec/` — relative paths are fine since the business project root is the cwd).
- The AIDE installation directory is typically under `~/.claude/plugins/cache/aide/` (installed via `claude plugin install`) or `.claude/plugins/aide/` (manual). Use this path to reference `aide-core/` files, schemas, and sub-skills.
- Maintain a professional, concise tone. Report what is happening at each step.
- If the user interrupts mid-pipeline (e.g., with unrelated questions), acknowledge the interruption and offer to resume with `/aide --continue`.
