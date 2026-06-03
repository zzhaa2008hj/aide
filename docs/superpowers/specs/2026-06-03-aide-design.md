# AIDE — AI-Driven Development Automation Design

## Overview

AIDE is a Claude Code skill collection that provides AI-driven full-flow development automation. Business projects reference AIDE via git submodule to gain structured development workflows covering requirements → spec → plan → implementation → testing.

## Core Decisions

| Decision | Choice |
|----------|--------|
| Scope | 需求 → 设计(Spec) → 计划(Plan) → 编码(Implement) → 测试(Test), 5-stage closed loop |
| Architecture | Skills-as-Stages: each stage is an independent Claude Code skill, plus an orchestrator skill |
| Reference method | Git submodule into `.claude/aide/`, discovered via `extra_skill_dirs` |
| Automation mode | Semi-auto serial pipeline with configurable human gates (confirm / confirm_skip / auto) |
| Tech stack target | Language-agnostic |
| Info flow | Structured JSON (machine-verifiable) + Markdown (human-readable), dual-track |
| Version control | Auto git-commit after each stage, deducated commit message format, rollback via git revert |
| MVP strategy | Phase 1: framework (aide-core + aide + aide-spec), verify the full pipeline, then add stages incrementally |

## Project Structure

```
AIDE/
├── skills/
│   ├── aide/                  # Orchestrator entry skill
│   ├── aide-spec/             # Stage 1: Requirements → Spec
│   ├── aide-plan/             # Stage 2: Spec → Plan
│   ├── aide-implement/        # Stage 3: Plan → Code
│   └── aide-test/             # Stage 4: Test verification
├── aide-core/                 # Shared infrastructure
│   ├── schemas/               # JSON Schema for each stage's output
│   ├── gate.md                # Gate engine logic (skill prompt)
│   └── conventions.md         # File naming and directory conventions
├── templates/                 # Business project reference templates
│   ├── aide.config.yaml       # Config template (gates, settings)
│   └── CLAUDE.md.partial      # CLAUDE.md reference snippet
└── README.md
```

## Business Project Integration

After integration, a business project looks like:

```
business-project/
├── .claude/
│   └── aide/                  # git submodule → AIDE repo
├── .aide/                     # Workflow artifacts (in .gitignore)
│   ├── config.yaml            # Project-specific config
│   ├── state.json             # Pipeline state tracker
│   └── output/
│       ├── 1-spec/
│       │   ├── spec.md
│       │   └── spec.json
│       ├── 2-plan/
│       │   ├── plan.md
│       │   └── plan.json
│       ├── 3-implement/
│       │   └── implement.json
│       └── 4-test/
│           ├── test-report.md
│           └── test-report.json
└── CLAUDE.md                  # Includes extra_skill_dirs: [.claude/aide/skills]
```

### Setup Steps

```bash
git submodule add <AIDE-repo-url> .claude/aide
cp .claude/aide/templates/aide.config.yaml .aide/config.yaml
# Add "extra_skill_dirs: [.claude/aide/skills]" to CLAUDE.md
```

## Stage Data Contracts

### spec.json

```json
{
  "features": [
    {
      "id": "F001",
      "title": "...",
      "description": "...",
      "acceptance_criteria": ["..."]
    }
  ],
  "constraints": ["..."],
  "scope_boundary": "..."
}
```

### plan.json

```json
{
  "tasks": [
    {
      "id": "T001",
      "feature_id": "F001",
      "description": "...",
      "depends_on": [],
      "files_to_touch": ["src/auth.ts"],
      "estimated_order": 1
    }
  ],
  "estimated_order": ["T001", "T002"]
}
```

### implement.json

```json
{
  "completed_tasks": ["T001", "T002"],
  "changed_files": ["src/auth.ts", "src/api.ts"],
  "unresolved_items": []
}
```

### test-report.json

```json
{
  "test_results": [
    {"task_id": "T001", "passed": true, "details": "..."}
  ],
  "coverage_delta": "+2%",
  "regressions": [],
  "verdict": "pass"
}
```

### state.json

```json
{
  "current_stage": "plan",
  "stages": {
    "spec": {"status": "done", "output_hash": "abc123", "commit": "ghi789"},
    "plan": {"status": "in_progress", "output_hash": null, "commit": null},
    "implement": {"status": "pending", "output_hash": null, "commit": null},
    "test": {"status": "pending", "output_hash": null, "commit": null}
  }
}
```

Traceability: plan.task.feature_id → spec.feature.id; implement.completed_tasks → plan.task.id; test.test_results.task_id → plan.task.id.

## Gate System

### Gate Types

| Type | Behavior |
|------|----------|
| `confirm` | Must wait for user (y/n), used at critical nodes |
| `confirm_skip` | Can skip and continue, used at non-critical nodes |
| `auto` | No pause, log only, suitable for CI/trusted scenarios |

### Configuration (aide.config.yaml)

```yaml
version: "1"
language: ""                   # Optional, for language-aware skill prompts
strict_mode: false

stages:
  spec:
    enabled: true
    gates:
      - after_spec:
          type: confirm
          prompt: "Review spec .aide/output/1-spec/spec.md, confirm to continue?"
  plan:
    enabled: true
    gates:
      - after_plan:
          type: confirm
  implement:
    enabled: true
    gates:
      - after_implement:
          type: confirm_skip
          prompt: "Code generated. Skip review and proceed to testing?"
  test:
    enabled: true
    gates:
      - after_test:
          type: confirm
          prompt: "Test report ready. Verification passed?"
```

### Gate Engine Behavior

Implemented as skill prompt logic in `aide` skill:

1. Read config.yaml for current stage's gates
2. For each gate: display artifact summary + prompt, wait for user response
3. confirm → wait for y/n; confirm_skip → allow skip; auto → log only
4. All gates passed → proceed to next stage
5. User rejects (n) → stay at current stage, accept feedback for re-run

## Orchestration Flow

```
/aide "implement user login with OAuth..."
           │
           ▼
      ┌─────────────┐
      │  Load config │
      └──────┬──────┘
             │
             ▼
      ┌─────────────┐
      │  spec stage  │ → spec.md + spec.json → git commit
      └──────┬──────┘
             │
             ▼        gate: after_spec (confirm)
      ┌─────────────┐
      │  Gate check  │ → user reviews → y / n / feedback
      └──────┬──────┘
             │ y
             ▼
      ┌─────────────┐
      │  plan stage  │ → plan.md + plan.json → git commit
      └──────┬──────┘
             │
             ▼        gate: after_plan (confirm)
      ┌─────────────┐
      │  Gate check  │
      └──────┬──────┘
             │ y
      ┌─────────────┐
      │ implement    │ → implement.json → git commit
      └──────┬──────┘
             │
             ▼        gate: after_implement (confirm_skip)
      ┌─────────────┐
      │  Gate check  │
      └──────┬──────┘
             │ y/skip
      ┌─────────────┐
      │  test stage  │ → test-report.md + test-report.json → git commit
      └──────┬──────┘
             │
             ▼        gate: after_test (confirm)
             Done
```

Key interaction principles:
- Each stage start displays progress (completed X/5, current: stage name)
- Gate pauses show structured artifact summary, not full text
- User rejection with feedback → current stage skill re-invoked with feedback
- Individual stage re-run: `/aide --stage plan`
- Mid-interruption recovery: `/aide --continue` from breakpoint via state.json

## Git Integration

### Auto-Commit

After each stage completes, `aide` performs:

1. Check working tree (warn if non-.aide files have uncommitted changes)
2. `git add .aide/output/<stage>/ .aide/state.json`
3. `git commit -m "aide(<stage>): <summary>"`

Commit message format by stage:

| Stage | Format |
|-------|--------|
| spec | `aide(spec): <feature summary>` |
| plan | `aide(plan): <task count> tasks` |
| implement | `aide(implement): <N> files changed` |
| test | `aide(test): <pass>/<total> pass` |

### Rollback

```bash
git log --oneline | grep aide
# abc123 aide(implement): 3 files changed
# def456 aide(plan): 4 tasks
# ghi789 aide(spec): user login with OAuth

git revert abc123 --no-edit    # Rollback implement stage
/aide --continue                # Resume from plan completion
```

### Safety

- Only `.aide/` files are auto-committed
- Business code changes are never auto-committed
- Uncommitted non-.aide changes produce a warning but do not block

## Error Handling

| Scenario | Handling |
|----------|----------|
| Stage execution fails | Detect missing output or schema mismatch → report stage + error, stay at stage, allow retry |
| Schema validation fails | Print diff summary, suggest fixes, wait for retry / skip / abort |
| User cancels mid-stage | Write state.json with partial marker, resume via `/aide --continue` |
| config.yaml missing | Use built-in defaults (all gates = confirm), prompt to generate config file |

## MVP Phases

### Phase 1 (current)

Deliverables:
- `skills/aide/skill.md` — orchestrator entry point
- `skills/aide-spec/skill.md` — requirements → spec stage
- `aide-core/gate.md` — gate engine skill prompt
- `aide-core/schemas/spec.schema.json` — spec output schema
- `aide-core/conventions.md` — artifact directory and naming conventions
- `templates/aide.config.yaml` — config template
- `templates/CLAUDE.md.partial` — CLAUDE.md snippet
- `README.md` — setup instructions

Scope: spec stage only, confirm gate only, state tracked via file existence (no state.json persistence yet).

### Phase 2

Add `aide-plan` + `aide-implement` skills, full state.json persistence, confirm_skip gate type.

### Phase 3

Add `aide-test` skill, auto gate type, strict_mode support, schema cross-stage validation.

## Testing Strategy

- **Schema compliance** — each stage's .json output validated against its JSON Schema
- **End-to-end scenarios** — 2-3 demo requirements in `examples/` directory, manually run full pipeline to verify
- **Gate behavior** — verify pause/skip behavior for each gate type by modifying config
- No automated test framework in Phase 1 — lightweight manual verification
