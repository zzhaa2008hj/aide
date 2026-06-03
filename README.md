# AIDE — AI-Driven Development Automation

A Claude Code skill collection for structured, AI-driven development workflows. Business projects reference AIDE via git submodule to add `/aide` — a pipeline that takes a requirement and runs it through spec → plan → implement → test with human gates at each stage.

## Quick Start

### Add AIDE to your project

```bash
cd your-project/
git submodule add <AIDE-repo-url> .claude/aide
git -C .claude/aide submodule update --init --recursive
mkdir -p .aide/
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
│   └── aide-test/         # Stage 4: Verification (Phase 3)
├── aide-core/             # Shared infrastructure
│   ├── schemas/           # JSON Schema per stage (spec, plan, implement)
│   ├── gate.md            # Gate engine specification
│   └── conventions.md     # Directory, naming, branch, and git conventions
├── superpowers/           # Git submodule — Superpowers skills for subagent-driven development
├── templates/             # Business project templates
│   ├── aide.config.yaml
│   └── CLAUDE.md.partial
├── docs/                  # Design specs and implementation plans
└── .gitmodules
```

**Note**: There is no `aide-implement` skill. Stage 3 (implement) is driven by the orchestrator using Superpowers' `subagent-driven-development` — each task in `plan.json` is dispatched to a fresh subagent with spec compliance and code quality review.

## Current Phase

**Phase 1** — Framework + spec stage, branch isolation, and implement stage design.

| Feature | Status |
|---------|--------|
| Orchestrator (`aide` skill) | Done |
| Spec stage (`aide-spec` skill) | Done |
| Gate engine (confirm gate) | Done |
| Branch isolation (per-pipeline `aide/<slug>` branch) | Done |
| Auto-stash on dirty working tree | Done |
| Implement stage design (subagent-driven via Superpowers) | Done |
| Superpowers submodule integration | Done |
| Plan stage (`aide-plan` skill) | Phase 2 |
| Implement stage (execution) | Phase 2 |
| Test stage (`aide-test` skill) | Phase 3 |

## Dependencies

AIDE bundles [Superpowers](https://github.com/obra/superpowers) as a git submodule for subagent-driven development, TDD, debugging, and code review patterns. Business projects must run `git submodule update --init --recursive` after adding AIDE to pull in both AIDE and Superpowers.

## Requirements

- Claude Code with skill support
- Git (for submodule and auto-commits)
