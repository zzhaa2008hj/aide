# AIDE — AI-Driven Development Automation

A Claude Code skill collection for structured, AI-driven development workflows. Business projects reference AIDE via git submodule to add `/aide` — a pipeline that takes a requirement and runs it through spec → plan → implement → test with human gates at each stage.

## Quick Start

### Add AIDE to your project

```bash
cd your-project/
git submodule add <AIDE-repo-url> .claude/aide
```

Then run the init skill to set up your project:

```
/aide-init
```

This creates `.aide/`, copies the config template, and adds `extra_skill_dirs: [.claude/aide/skills]` to your `CLAUDE.md` (creating it if needed). Safe to re-run — skips already-configured steps.

### Run the pipeline

```bash
/aide "Add user login with OAuth support"
```

AIDE will:
1. Generate a structured spec (`.aide/output/1-spec/`)
2. Pause for your review
3. On confirm, commit the spec and proceed to planning

### Updating AIDE

When AIDE releases new features or fixes, update the submodule in your project and re-run init:

```bash
git -C .claude/aide pull origin master
```

Then re-run `/aide-init` to apply any new configuration. It's safe to re-run — it only adds what's missing and never overwrites your existing `CLAUDE.md` content or `.aide/config.yaml`.

### Customize gates

Edit `.aide/config.yaml` to change gate types per stage:

- `confirm` — requires explicit y/n
- `confirm_skip` — can be skipped (y/n/skip)
- `auto` — no pause

## Project Structure

```
AIDE/
├── skills/
│   ├── aide/                          # Pipeline orchestrator
│   ├── aide-init/                     # Project initialization
│   ├── aide-spec/                     # Stage 1: Requirements → Spec
│   ├── aide-plan/                     # Stage 2: Spec → Plan (Phase 2)
│   ├── aide-test/                     # Stage 4: Verification (Phase 3)
│   ├── brainstorming/                 # Idea → design (superpowers)
│   ├── dispatching-parallel-agents/   # Parallel task dispatch (superpowers)
│   ├── executing-plans/               # Plan execution (superpowers)
│   ├── finishing-a-development-branch/# Branch completion (superpowers)
│   ├── receiving-code-review/         # Code review response (superpowers)
│   ├── requesting-code-review/        # Code review request (superpowers)
│   ├── subagent-driven-development/   # Subagent implementation (superpowers)
│   ├── systematic-debugging/          # Bug investigation (superpowers)
│   ├── test-driven-development/       # TDD workflow (superpowers)
│   ├── using-git-worktrees/           # Worktree isolation (superpowers)
│   ├── using-superpowers/             # Usage guide (superpowers)
│   ├── verification-before-completion/# Completion verification (superpowers)
│   ├── writing-plans/                 # Implementation planning (superpowers)
│   └── writing-skills/                # Skill authoring (superpowers)
├── aide-core/             # Shared infrastructure
│   ├── schemas/           # JSON Schema per stage (spec, plan, implement)
│   ├── gate.md            # Gate engine specification
│   ├── conventions.md     # Directory, naming, branch, and git conventions
│   └── scripts/
│       └── sync-superpowers.sh  # Upstream sync tool (maintainer use)
├── templates/             # Business project templates
│   ├── aide.config.yaml
│   └── CLAUDE.md.partial
├── SUPERSPOWERS_VERSION   # Tracked upstream baseline commit
├── docs/                  # Design specs and implementation plans
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

AIDE ships Superpowers skills directly in `skills/` — no nested submodule required. For the upstream source, see [Superpowers](https://github.com/obra/superpowers).

## Requirements

- Claude Code with skill support
- Git (for submodule and auto-commits)
