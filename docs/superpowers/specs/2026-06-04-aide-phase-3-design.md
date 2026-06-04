# AIDE Phase 3 — Test Stage

## Overview

Phase 3 adds the final pipeline stage: test verification. A new `aide-test` skill runs the project's test suite, verifies implementation against spec acceptance criteria, checks test coverage of changed files, and produces a structured test report.

## aide-test Skill

### Input

- `.aide/output/1-spec/spec.json` — features with `acceptance_criteria`
- `.aide/output/2-plan/plan.json` — tasks with `files_to_touch`
- `.aide/output/3-implement/implement.json` — `completed_tasks`, `changed_files`, `task_results`

### Output

- `.aide/output/4-test/test-report.json` — conforms to `test.schema.json`
- `.aide/output/4-test/test-report.md` — human-readable summary

### Workflow

1. **Read inputs** — load spec.json, plan.json, implement.json
2. **Run test suite** — auto-detect test command (pytest, npm test, go test, cargo test), run it, capture output
3. **Spec verification** — for each `completed_tasks` feature, match acceptance_criteria against test output evidence
4. **Coverage check** — compare `changed_files` against test files, report uncovered files
5. **Verdict** — determined by test results + spec compliance + coverage

### Verdict Rules

| Test Suite | Spec Verification | Coverage | Verdict |
|-----------|-------------------|----------|---------|
| All passed | All pass | Adequate | `pass` |
| Any failure | — | — | `fail` |
| All passed | Has failures | — | `fail` |
| Cannot run | — | — | `manual` |

### Test Command Detection

Try in order:
1. Check for standard config files: `pytest` (setup.cfg/pyproject.toml), `npm test` (package.json), `go test` (go.mod), `cargo test` (Cargo.toml)
2. Fall back: ask the user which test command to use via the language field in `.aide/config.yaml`

## test.schema.json

New schema at `aide-core/schemas/test.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Test Report",
  "type": "object",
  "required": ["test_suite", "spec_verification", "verdict"],
  "properties": {
    "test_suite": {
      "type": "object",
      "required": ["passed", "failed", "skipped"],
      "properties": {
        "passed":  { "type": "integer", "minimum": 0 },
        "failed":  { "type": "integer", "minimum": 0 },
        "skipped": { "type": "integer", "minimum": 0 },
        "command": { "type": "string" },
        "output":  { "type": "string" }
      }
    },
    "spec_verification": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["feature_id", "criteria", "status"],
        "properties": {
          "feature_id": { "type": "string", "pattern": "^F\\d{3}$" },
          "criteria":   { "type": "string" },
          "status":     { "type": "string", "enum": ["pass", "fail", "untestable"] },
          "evidence":   { "type": "string" }
        },
        "additionalProperties": false
      }
    },
    "coverage": {
      "type": "object",
      "properties": {
        "files_with_tests":    { "type": "array", "items": { "type": "string" } },
        "files_without_tests": { "type": "array", "items": { "type": "string" } },
        "overall":             { "type": "string" }
      }
    },
    "verdict": {
      "type": "string",
      "enum": ["pass", "fail", "manual"]
    }
  },
  "additionalProperties": false
}
```

## Orchestrator Integration

### Stage 4 Execution

```
Stage 3 (implement) → gate → commit
  │
  ▼
Stage 4: test
  ├─ Load aide-test skill via Skill tool
  ├─ Verify output: test-report.json + test-report.md
  ├─ Run after_test gate (default: confirm_skip)
  └─ Gate pass → commit → state.json: current_stage = "complete"
```

### Config Defaults

```yaml
test:
  enabled: true
  gates:
    - name: after_test
      type: confirm_skip
      prompt: "Test report ready. Verification passed? (y/n/skip)"
```

## Pipeline Completion

When `state.json` reaches `current_stage: "complete"`, the orchestrator presents the final completion report with all four stages and exits. No `--continue` needed — the pipeline is done.

## Edge Cases

- **No test framework detected**: Report `verdict: manual`, prompt user to add `language` or test command to config
- **All tasks blocked in implement stage**: Skip test stage (nothing to verify), report `verdict: manual`
- **Test suite timeout**: Kill after 5 minutes, report `verdict: fail` with timeout detail
- **Empty spec_verification**: If no completed features found, report `verdict: manual`

## Out of Scope

- Test generation (the test stage verifies, does not write tests)
- Performance/load testing
- Integration test orchestration across services
