---
name: aide-continue
description: >-
  Resume an interrupted AIDE pipeline. Validates you're on the correct
  aide/* branch, reads state.json to find where you left off, skips
  completed stages, and invokes the orchestrator to continue.
---

# aide-continue — Resume Pipeline

You resume an interrupted AIDE pipeline. Your job is to determine where the pipeline left off and hand control to the orchestrator to continue execution.

## Process

### Step 1: Validate branch

```bash
BRANCH=$(git branch --show-current)
```

If the current branch does NOT start with `aide/`:
- Report: "Not on an `aide/*` branch. Current branch: `$BRANCH`. Switch to the correct branch and try again."
- Stop.

Report: "Resuming pipeline on branch `$BRANCH`."

### Step 2: Read pipeline state

```bash
cat .aide/state.json
```

If `.aide/state.json` does not exist:
- Report: "No pipeline state found. Start a new pipeline with `/aide \"<description>\"`."
- Stop.

Parse `current_stage` and `completed_stages`. If `current_stage` is `"complete"`:
- Report: "Pipeline is already complete. All 4 stages finished."
- Stop.

### Step 3: Skip completed stages

List which stages are already done (from `completed_stages`). Report:

```
Resuming AIDE pipeline.
  Completed: spec, plan
  Current:   implement
  Remaining: implement, test
```

### Step 4: Invoke orchestrator

Invoke the `aide` skill via the Skill tool. Pass this as the argument:

```
--continue from <current_stage>
Completed stages: <completed_stages>
Original request: (read from state.json pipeline field)
```

The orchestrator will pick up from `current_stage`, skip stages in `completed_stages`, and continue through the remaining pipeline.

## Important Guidelines

- This skill only handles resumption — never start a new pipeline from here.
- If state.json is corrupted or unreadable, report the error and stop.
- Never modify state.json — the orchestrator handles state updates during execution.
- If the user wants to start fresh, tell them to use `/aide "<description>"` instead.
