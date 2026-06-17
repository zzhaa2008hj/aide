---
name: aide-continue
description: >-
  Resume an interrupted AIDE pipeline. Reads .aide/state.json to find
  where you left off, skips completed stages, and invokes the orchestrator
  to continue on the current branch.
---

# aide-continue — Resume Pipeline

You resume an interrupted AIDE pipeline. Your job is to determine where the pipeline left off and hand control to the orchestrator to continue execution.

## Process

### Step 1: Read pipeline state

```bash
cat .aide/state.json
```

If `.aide/state.json` does not exist:
- Report: "No pipeline state found in current directory. Start a new pipeline with `/aide \"<description>\"`."
- Stop.

Parse `current_stage` and `completed_stages`. If `current_stage` is `"complete"`:
- Report: "Pipeline is already complete. All stages finished."
- Stop.

### Step 2: Skip completed stages

List which stages are already done (from `completed_stages`). Report:

```
Resuming AIDE pipeline.
  Completed: spec, plan
  Current:   implement
  Remaining: implement, test
```

### Step 3: Invoke orchestrator

Invoke the `aide` skill via the Skill tool. Pass this as the argument:

```
--continue from <current_stage>
Completed stages: <completed_stages>
Original request: (read from state.json slug field)
```

The orchestrator will pick up from `current_stage`, skip stages in `completed_stages`, and continue through the remaining pipeline.

## Important Guidelines

- This skill only handles resumption — never start a new pipeline from here.
- If state.json is corrupted or unreadable, report the error and stop.
- Never modify state.json — the orchestrator handles state updates during execution.
- If the user wants to start fresh, tell them to use `/aide "<description>"` instead.
