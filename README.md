# AIDE — AI-Driven Development Automation

A Claude Code skill collection for structured, AI-driven development workflows. Business projects reference AIDE via git submodule to add `/aide` — a pipeline that takes a requirement and runs it through spec → plan → implement → test with human gates at each stage.

## Quick Start

### Add AIDE to your project

```bash
cd your-project/
git submodule add <AIDE-repo-url> .claude/aide
cp .claude/aide/templates/aide.config.yaml .aide/config.yaml
```

Then add this line to your project's `CLAUDE.md`:

```yaml
extra_skill_dirs: [.claude/aide/skills]
```

### Run the pipeline

```bash
/aide "Add user login with OAuth support"
```

AIDE will:
1. Generate a structured spec (`.aide/output/1-spec/`)
2. Pause for your review
3. On confirm, commit the spec and proceed to planning

### Customize gates

Edit `.aide/config.yaml` to change gate types per stage:

- `confirm` — requires explicit y/n
- `confirm_skip` — can be skipped (y/n/skip)
- `auto` — no pause

## Project Structure

```
AIDE/
├── skills/
│   ├── aide/              # Pipeline orchestrator
│   ├── aide-spec/         # Stage 1: Requirements → Spec
│   ├── aide-plan/         # Stage 2: Spec → Plan (Phase 2)
│   ├── aide-implement/    # Stage 3: Plan → Code (Phase 2)
│   └── aide-test/         # Stage 4: Verification (Phase 3)
├── aide-core/             # Shared infrastructure
│   ├── schemas/           # JSON Schema per stage
│   ├── gate.md            # Gate engine specification
│   └── conventions.md     # Directory and naming conventions
└── templates/             # Business project templates
    ├── aide.config.yaml
    └── CLAUDE.md.partial
```

## Current Phase

**Phase 1** — Framework + spec stage. The spec stage is fully functional. Plan, implement, and test stages come in Phase 2 and 3.

## Requirements

- Claude Code with skill support
- Git (for submodule and auto-commits)
