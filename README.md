# AIDE — AI-Driven Development Automation

A Claude Code plugin for structured, AI-driven development workflows. Business projects install AIDE via `claude plugin install` to add `/aide` — a pipeline that takes a requirement and runs it through **spec → plan → implement → test** with human gates at each stage.

Also supports [deepcode-cli](https://github.com/HKUDS/DeepCode) (primary) and [CodeWhale](https://github.com/Hmbown/CodeWhale) via skills-based installation. See [README-cw.md](README-cw.md) for CodeWhale and [Install for deepcode-cli](#install-for-deepcode-cli) for deepcode-cli.

## Quick Start

### Add AIDE to your project

```bash
cd your-project/
claude plugin marketplace add https://github.com/zzhaa2008hj/aide.git
claude plugin install aide@aide --scope project
```

That's it. AIDE is now installed as a project plugin — skills are auto-discovered by Claude Code. `/aide`, `/aide-continue`, `/aide-init`, and `/aide-update` are available.

Optional: run `/aide-init` to explicitly bootstrap `.aide/` and the config template (the pipeline will auto-create these on first run regardless).

### Run the pipeline

```bash
/aide "Add user login with OAuth support"
```

AIDE will:
1. Create an `aide/<slug>` branch and stash uncommitted changes
2. Analyze the existing project context (tech stack, conventions, patterns)
3. Generate a structured spec (`.aide/output/1-spec/`)
4. Pause for your review (gate: confirm / confirm_skip / auto)
5. Proceed through plan → implement → test stages
6. Implement stage dispatches tasks to subagents with spec + quality reviews
7. Test stage auto-retries failures up to 3 rounds

### Resume an interrupted pipeline

```bash
/aide-continue
```

Validates branch, reads `.aide/state.json` to find where you left off, skips completed stages, and resumes execution.

### Updating AIDE

```
/aide-update
```

Runs `claude plugin marketplace update aide` then `claude plugin update aide@aide --scope project`. Safe to run mid-pipeline.

### Customize gates

Edit `.aide/config.yaml` to change gate types per stage:

- `confirm` — requires explicit y/n
- `confirm_skip` — can be skipped (y/n/skip); skip upgrades to `auto` permanently
- `auto` — no pause

## Pipeline

| Order | Stage     | Skill          | Description                            |
|-------|-----------|----------------|----------------------------------------|
| 0.2   | context   | Orchestrator   | Project analysis: tech stack, patterns |
| 1     | spec      | `aide-spec`    | Requirements → Specification (+ adversarial review) |
| 2     | plan      | `aide-plan`    | Specification → Task plan              |
| 3     | implement | Orchestrator   | Tasks → Code (subagent per task)       |
| 4     | test      | `aide-test`    | Test suite + spec verification + retry |

**Stage 0.2 (project context analysis) is mandatory.** Before any spec or code, the orchestrator maps the existing project structure, tech stack, conventions, and patterns. All subsequent stages must respect these findings.

The implement stage reads `plan.json`, resolves task dependencies via topological sort, and dispatches each task through Superpowers' `subagent-driven-development` pattern (implement → spec review → quality review). Up to 3 independent tasks run in parallel.

### Fix Pipeline (`/aide-fix`)

A lightweight alternative for bug fixes and small optimizations:

| Order | Stage     | Description                         |
|-------|-----------|-------------------------------------|
| 1     | analyze   | Root cause → scope fence            |
| 2     | implement | Scope-fenced code changes           |
| 3     | test      | Verify + auto-retry (max 2)        |

Uses independent state tracking (`.aide/fix-state.json`), branch prefix (`aide-fix/`), and output directory (`.aide/fix/output/`). Each stage produces paired outputs: `.md` for human review and `.json` for AI consumption. Supports resume via state file detection. Invoke via `/aide-fix "<bug description>"`.

### Code Analysis Integration

All orchestrators include mandatory code analysis stages:

- **Stage 3 (implement)**: Code Analysis scans all changed files for correctness, security, code quality, and style issues
- **Stage 4 (test)**: Code Verification performs final comprehensive analysis — critical findings downgrade the test verdict from pass to fail

## Project Structure

```
AIDE/
├── skills/
│   ├── aide/                          # Pipeline orchestrator (Claude Code)
│   ├── aide-deepcode/                 # Pipeline orchestrator (deepcode-cli)
│   ├── aide-codewhale/                 # Pipeline orchestrator (CodeWhale)
│   │   └── install.sh                 # One-line install for CodeWhale
│   ├── aide-fix/                      # Bug-fix pipeline (analyze → implement → test)
│   ├── aide-spec/                     # Stage 1: Requirements → Spec (+ Reviewer Panel)
│   ├── aide-plan/                     # Stage 2: Spec → Plan
│   ├── aide-test/                     # Stage 4: Verification → Test report
│   ├── aide-continue/                 # Pipeline resume
│   ├── aide-init/                     # Bootstrap .aide/ and CLAUDE.md
│   ├── aide-update/                   # Update AIDE installation
│   └── .../                           # 14 Superpowers skills
├── aide-core/                         # Shared infrastructure
│   ├── schemas/                       # JSON Schema per stage (spec, plan, implement, test)
│   ├── conventions.md                 # Directory, naming, branch, and git conventions
│   ├── gate.md                        # Gate engine specification
│   ├── pipeline-protocol.md           # Shared pipeline rules (both orchestrators)
│   └── scripts/
│       ├── bump-version.sh            # Version bump (pre-commit auto-trigger)
│       ├── install-hooks.sh           # Git hook deployment
│       └── sync-superpowers.sh        # Upstream sync tool (maintainer)
├── aide_deepcode/
│   └── install-deepcode-cli.sh        # One-line install for deepcode-cli
├── commands/
│   └── aide.md                        # CodeWhale user command (slash autocomplete)
├── hooks/
│   ├── pre-commit                     # Auto-bump version on functional changes
│   └── pre-push                       # Enforce version bump before push
├── .claude-plugin/
│   ├── plugin.json                    # Plugin identity + version
│   └── marketplace.json               # Self-hosted marketplace definition
├── templates/                         # Business project templates
│   ├── aide.config.yaml
│   └── CLAUDE.md.partial
├── docs/                              # Design specs and implementation plans
└── SUPERSPOWERS_VERSION               # Tracked upstream baseline commit
```

### Shared pipeline protocol

Both orchestrators (`skills/aide/SKILL.md` and `skills/aide-deepcode/SKILL.md`) reference [`aide-core/pipeline-protocol.md`](aide-core/pipeline-protocol.md) for:

- **CRITICAL Pipeline Discipline** — forbidden actions before Stage 3, permitted files, grounding rules
- **Project Context Analysis** — mandatory 6-step procedure for existing projects, architecture-first for new projects
- **State Update Patterns** — reusable `state.json` update templates (basic transition, retry init, cleanup)

This eliminates ~180 lines of duplication while keeping orchestrator-specific logic inline.

### Install for deepcode-cli

```bash
# 从 master 分支安装（稳定版）
curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/aide_deepcode/install-deepcode-cli.sh | bash

# 从 develop 分支安装（开发版）
curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/aide_deepcode/install-deepcode-cli.sh | AIDE_REF=develop bash

# 也可以切换仓库源
AIDE_REPO=https://github.com/zzhaa2008hj/aide.git AIDE_REF=develop bash aide_deepcode/install-deepcode-cli.sh
```

Installs skills into `.agents/skills/` — deepcode-cli discovers them automatically. Stage-specific skills (spec, plan, test) are shared between Claude Code and deepcode-cli.

**Update:**

```bash
# 更新到当前分支最新
bash .aide/update-deepcode-cli.sh

# 从 develop 分支更新
AIDE_REF=develop bash .aide/update-deepcode-cli.sh
```

## Version Management

AIDE versions follow semver with automatic enforcement via git hooks:

| Change type | Version | Trigger |
|-------------|---------|---------|
| Same branch fix | patch `x.y.Z` | `bump-version.sh` (auto via pre-commit) |
| New feature branch | minor `x.Y.z` | `bump-version.sh` (auto via pre-commit) |
| Breaking change | major `X.y.z` | `bump-version.sh --major` (manual) |

The pre-commit hook automatically bumps `plugin.json` + `marketplace.json` when functional files are staged. The pre-push hook verifies versions are in sync before allowing push.

## Feature Status

### Done

### Done

### Done

| Feature | Status |
|---------|--------|
| Orchestrator (CC + deepcode-cli + CodeWhale) | Done |
| Spec stage (`aide-spec` skill) | Done |
| Plan stage (`aide-plan` skill) | Done |
| Implement stage (subagent dispatch, max 3 parallel) | Done |
| Test stage (`aide-test` skill, auto-retry 3 rounds) | Done |
| Gate engine (confirm / confirm_skip / auto) | Done |
| Project context analysis (Stage 0.2, mandatory) | Done |
| Branch isolation (per-pipeline `aide/<slug>` branch) | Done |
| Auto-stash on dirty working tree | Done |
| Pipeline resume (`/aide-continue` with state.json) | Done |
| Pipeline discipline guards (state machine enforcement) | Done |
| Shared pipeline protocol (deduplicated orchestrators) | Done |
| Version management (pre-commit + pre-push hooks) | Done |
| Fix pipeline (`/aide-fix`, analyze→implement→test, backend-agnostic) | Done |
| Fix pipeline resume (state file detection) | Done |
| Code Analysis in implement stage (all orchestrators) | Done |
| Code Verification in test stage (all orchestrators) | Done |
| CodeWhale orchestrator (`aide-codewhale`) | Done |
| Spec Reviewer Panel (3-lens adversarial review) | Done |

### Planned / TODO

| Feature | Priority | Notes |
|---------|----------|-------|
| Automated tests (bump-version, hooks, plugin deps) | Medium | Toolchain has zero test coverage |
| Pure-bash version parser fallback | Low | Remove python3 dependency from version scripts |
| install.sh path safety guard | Low | Validate `$PLUGIN_DIR` before `rm -rf` |
| Long-term orchestrator unification | Low | Single pipeline definition driving both CC and deepcode-cli |

## Dependencies

AIDE ships Superpowers skills directly in `skills/` — no nested submodule required. For the upstream source, see [Superpowers](https://github.com/obra/superpowers).

## Requirements

- Claude Code with skill support
- Git (for clone and auto-commits)
- Python 3 (for `bump-version.sh` and state management scripts)
