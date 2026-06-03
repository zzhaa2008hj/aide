# Gate Engine

The gate engine controls pipeline checkpoints — points where AIDE pauses for human confirmation before proceeding to the next stage.

## How It Works

1. After a stage completes, the orchestrator reads the gate configuration for that stage from `.aide/config.yaml`.
2. For each configured gate, it presents the stage's artifact summary and the gate's prompt.
3. The user responds, and the engine resolves the gate.

## Gate Types

### confirm

The pipeline halts. The user must explicitly approve by typing `y` or `yes`. If the user types `n` or `no`, the pipeline stays at the current stage. The user can provide feedback (e.g., "no, the acceptance criteria for F002 are too vague"), and the orchestrator will re-invoke the stage skill with that feedback.

### confirm_skip (Phase 2)

The pipeline pauses but the user can type `skip` or `s` to bypass without approving. Typing `y`/`yes` approves; `n`/`no` rejects with feedback.

### auto (Phase 3)

No pause. The gate is logged and the pipeline proceeds immediately. Useful for CI or high-trust stages.

## Gate Naming Convention

Gate names follow the pattern `after_{stage_name}` (e.g., `after_spec`, `after_plan`). Multiple gates per stage are supported — just use distinct names.

## Gate Config Structure

Each gate in `aide.config.yaml` is a flat object:

```yaml
gates:
  - name: after_spec
    type: confirm
    prompt: "Review the spec. Does this look right? (y/n)"
```

The `name`, `type`, and `prompt` fields are always top-level keys in each gate entry.

## Gate Resolution Algorithm

```
for each gate in stage_config.gates:
    if gate.type == "confirm":
        display gate.prompt
        wait for input
        if input is "y" or "yes":
            continue to next gate (or next stage if last gate)
        else if input is "n" or "no":
            ask for feedback
            re-invoke current stage with feedback
            restart gates for this stage
    elif gate.type == "confirm_skip":
        display gate.prompt
        wait for input
        if input is "y" or "yes": continue
        else if input is "skip" or "s": continue
        else if input is "n" or "no": ask feedback, re-invoke stage
    elif gate.type == "auto":
        log "Gate: {gate.name} (auto) - passed"
        continue
```

## Phase 1 Scope

Only the `confirm` gate type is implemented. The `confirm_skip` and `auto` types are documented here for forward reference but the orchestrator treats unknown types as `confirm` with a warning.
