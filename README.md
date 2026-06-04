# AIDE — AI-Driven Development Automation

A Claude Code skill collection for structured, AI-driven development workflows. Business projects install AIDE via `claude plugin install` to add `/aide` — a pipeline that takes a requirement and runs it through spec → plan → implement → test with human gates at each stage.

## Quick Start

### Add AIDE to your project

```bash
cd your-project/
claude plugin marketplace add https://github.com/zzhaa2008hj/aide.git
claude plugin install aide@aide --scope project
```

That's it. AIDE is now installed as a project plugin — skills are auto-discovered by Claude Code. `/aide`, `/aide-init`, and `/aide-update` are available.

Optional: run `/aide-init` to explicitly bootstrap `.aide/` and the config template (the pipeline will auto-create these on first run regardless).

### Run the pipeline

```bash
/aide "Add user login with OAuth support"
```

AIDE will:
1. Create an `aide/<slug>` branch and stash uncommitted changes
2. Generate a structured spec (`.aide/output/1-spec/`)
3. Pause for your review (gate: confirm / confirm_skip / auto)
4. On confirm, commit and proceed to plan → implement stages
5. Plan stage decomposes the spec into dependency-tracked tasks
6. Implement stage dispatches tasks to subagents with review gates

### Resume an interrupted pipeline

```bash
/aide --continue
```

State is persisted in `.aide/state.json`. Completed stages are skipped automatically. Requires you to be on the original `aide/*` branch.

### Updating AIDE

When AIDE releases new features or fixes:

```
/aide-update
```

This runs `claude plugin marketplace update aide` then `claude plugin update aide@aide --scope project`. Safe to run mid-pipeline.

### Customize gates

Edit `.aide/config.yaml` to change gate types per stage:

- `confirm` — requires explicit y/n
- `confirm_skip` — can be skipped (y/n/skip)
- `auto` — no pause

## Pipeline

| Order | Stage     | Skill          | Description                         |
|-------|-----------|----------------|-------------------------------------|
| 1     | spec      | `aide-spec`    | Requirements → Specification        |
| 2     | plan      | `aide-plan`    | Specification → Task plan           |
| 3     | implement | Orchestrator   | Tasks → Code (subagent per task)    |
| 4     | test      | `aide-test`    | Verification → Test report (Phase 3) |

The implement stage has no standalone skill. The orchestrator reads `plan.json`, resolves task dependencies via topological sort, and dispatches each task as a subagent with spec compliance + code quality reviews. Up to 3 independent tasks run in parallel.

## Project Structure

```
AIDE/
├── skills/
│   ├── aide/                          # Pipeline orchestrator
│   ├── aide-init/                     # Bootstrap .aide/ and CLAUDE.md
│   ├── aide-update/                   # Update AIDE installation
│   ├── aide-spec/                     # Stage 1: Requirements → Spec
│   ├── aide-plan/                     # Stage 2: Spec → Plan
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
│       ├── bump-version.sh        # Version bump (pre-commit auto-trigger)
│       ├── install-hooks.sh       # Git hook deployment
│       └── sync-superpowers.sh    # Upstream sync tool (maintainer)
├── hooks/                 # Git hooks
│   ├── pre-commit         # Auto-bump version on functional changes
│   └── pre-push           # Enforce version bump before push
├── .claude-plugin/        # Plugin manifest
│   ├── plugin.json        # Plugin identity + version
│   └── marketplace.json   # Self-hosted marketplace definition
├── templates/             # Business project templates
│   ├── aide.config.yaml
│   └── CLAUDE.md.partial
├── docs/                  # Design specs and implementation plans
└── SUPERSPOWERS_VERSION   # Tracked upstream baseline commit
```

## Version Management

AIDE versions follow semver with automatic enforcement via git hooks:

| Change type | Version | Trigger |
|-------------|---------|---------|
| Same branch fix | patch `x.y.Z` | `bump-version.sh` (auto via pre-commit) |
| New feature branch | minor `x.Y.z` | `bump-version.sh` (auto via pre-commit) |
| Breaking change | major `X.y.z` | `bump-version.sh --major` (manual) |

The pre-commit hook automatically bumps `plugin.json` + `marketplace.json` when functional files are staged. The pre-push hook verifies versions are in sync before allowing push.

## Current Phase

**Phase 2** — Plan stage + implement execution.

| Feature | Status |
|---------|--------|
| Orchestrator (`aide` skill) | Done |
| Spec stage (`aide-spec` skill) | Done |
| Plan stage (`aide-plan` skill) | Done |
| Implement stage (subagent dispatch) | Done |
| Gate engine (confirm / confirm_skip / auto) | Done |
| Branch isolation (per-pipeline `aide/<slug>` branch) | Done |
| Auto-stash on dirty working tree | Done |
| Pipeline resume (`--continue` with state.json) | Done |
| Concurrent subagent dispatch (max 3) | Done |
| Version management (pre-commit + pre-push hooks) | Done |
| Test stage (`aide-test` skill) | Phase 3 |

## Dependencies

AIDE ships Superpowers skills directly in `skills/` — no nested submodule required. For the upstream source, see [Superpowers](https://github.com/obra/superpowers).

## Requirements

- Claude Code with skill support
- Git (for clone and auto-commits)
