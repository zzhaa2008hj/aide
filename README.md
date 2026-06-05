# AIDE — AI-Driven Development Automation

A structured, AI-driven development pipeline: give `/aide` a requirement and it runs **spec → plan → implement → test** with human gates at each stage.

Built for [deepcode-cli](https://github.com/HKUDS/DeepCode). Also available as a [Claude Code](https://claude.ai/code) plugin — see [README-cc.md](README-cc.md).

## Quick Start

### Install

```bash
cd your-project/
curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/aide_deepcode/install-deepcode-cli.sh | bash
```

Installs skills to `.agents/skills/` (deepcode-cli discovers them automatically), schemas to `.aide/schemas/`, and the update script to `.aide/update-deepcode-cli.sh`.

### Run

```
/aide "Add user login with OAuth support"
```

### Resume

```
/aide-continue
```

### Update

```bash
bash .aide/update-deepcode-cli.sh
```

### Customize gates

Edit `.aide/config.yaml`:

| Gate | Behavior |
|------|----------|
| `confirm` | Requires explicit y/n |
| `confirm_skip` | y/n/skip; skip upgrades to `auto` permanently |
| `auto` | No pause |

## How It Works

### Pipeline stages

| Order | Stage     | Skill          | Description                            |
|-------|-----------|----------------|----------------------------------------|
| 0.2   | context   | Orchestrator   | Project analysis: tech stack, patterns |
| 1     | spec      | `aide-spec`    | Requirements → Specification           |
| 2     | plan      | `aide-plan`    | Specification → Task plan              |
| 3     | implement | Orchestrator   | Tasks → Code (serial, per plan order)  |
| 4     | test      | `aide-test`    | Test suite + spec verification + retry |

**Stage 0.2 is mandatory.** Before any spec or code, the orchestrator maps the existing project structure, tech stack, conventions, and patterns — all subsequent stages must respect these findings.

### State machine

AIDE is a strict sequential state machine tracked in `.aide/state.json`:

```json
{
  "pipeline": "add-user-login",
  "slug": "add-user-login",
  "current_stage": "spec",
  "completed_stages": [],
  "test_retries": 0,
  "last_updated": "2026-06-05T12:00:00Z"
}
```

Each stage transition: read stage skill → follow workflow → validate output → pass gate → update state. Completed stages are never re-run — `/aide-continue` picks up exactly where it left off.

### Implement stage

Reads `plan.json`, resolves task dependencies via topological sort, executes tasks in order. Each task is self-reviewed against the parent feature's acceptance criteria from the spec.

### Test stage

Runs the project's test suite, verifies output against spec acceptance criteria. On failure, auto-retries up to 3 rounds. After 3 failures, prompts for manual decision.

### Branch isolation

By default, AIDE creates an `aide/<slug>` branch and stashes uncommitted changes before starting. When the pipeline completes, you choose whether to merge the branch back.

## Project Structure

```
AIDE/
├── aide_deepcode/                         # Install & update scripts for deepcode-cli
│   ├── install-deepcode-cli.sh
│   └── update-deepcode-cli.sh
├── skills/
│   ├── aide-deepcode/                     # Orchestrator (deepcode-cli)
│   ├── aide/                              # Orchestrator (Claude Code)
│   ├── aide-spec/                         # Stage 1: Requirements → Spec
│   ├── aide-plan/                         # Stage 2: Spec → Plan
│   ├── aide-test/                         # Stage 4: Test suite + verification
│   ├── aide-fix/                          # Rapid bug-fix pipeline
│   ├── aide-continue/                     # Pipeline resume
│   ├── aide-init/                         # Bootstrap .aide/ and CLAUDE.md
│   └── .../                               # Superpowers skills
├── aide-core/                             # Shared infrastructure
│   ├── schemas/                           # JSON Schema per stage
│   ├── pipeline-protocol.md               # Shared pipeline rules
│   ├── conventions.md                     # Directory, naming, branch conventions
│   ├── gate.md                            # Gate engine specification
│   └── scripts/
│       ├── bump-version.sh
│       ├── init.sh
│       ├── install-hooks.sh
│       └── sync-superpowers.sh
├── hooks/
│   ├── pre-commit                         # Auto-bump version on functional changes
│   └── pre-push                           # Enforce version bump before push
├── templates/
│   ├── aide.config.yaml
│   └── CLAUDE.md.partial
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
└── docs/
```

### Shared pipeline protocol

Both orchestrators reference [`aide-core/pipeline-protocol.md`](aide-core/pipeline-protocol.md) for:

- **CRITICAL Pipeline Discipline** — forbidden actions before Stage 3, permitted files, grounding rules
- **Project Context Analysis** — mandatory 6-step procedure for existing projects, architecture-first for new projects
- **State Update Patterns** — reusable `state.json` update templates

This eliminates ~180 lines of duplication between the two orchestrators.

## Version Management

Semver with automatic enforcement via git hooks:

| Change type | Version | Trigger |
|-------------|---------|---------|
| Same branch fix | patch `x.y.Z` | `bump-version.sh` (auto via pre-commit) |
| New feature branch | minor `x.Y.z` | `bump-version.sh` (auto via pre-commit) |
| Breaking change | major `X.y.z` | `bump-version.sh --major` (manual) |

## Feature Status

### Done

### Done

### Done

| Feature | Status |
|---------|--------|
| Orchestrator (deepcode-cli + CC) | Done |
| deepcode-cli install & update | Done |
| Spec stage (`aide-spec`) | Done |
| Plan stage (`aide-plan`) | Done |
| Implement stage (serial for deepcode, parallel for CC) | Done |
| Test stage (`aide-test`, auto-retry 3 rounds) | Done |
| Rapid bug-fix (`/aide-fix`) | Done |
| Gate engine (confirm / confirm_skip / auto) | Done |
| Project context analysis (Stage 0.2, mandatory) | Done |
| Branch isolation (`aide/<slug>`) | Done |
| Auto-stash on dirty working tree | Done |
| Pipeline resume (`/aide-continue`) | Done |
| Pipeline discipline guards (state machine enforcement) | Done |
| Shared pipeline protocol | Done |
| Version management (pre-commit + pre-push) | Done |

### Planned / TODO

| Feature | Priority | Notes |
|---------|----------|-------|
| Automated tests (bump-version, hooks, plugin deps) | Medium | Toolchain has zero test coverage |
| Pure-bash version parser fallback | Low | Remove python3 dependency from version scripts |
| install.sh path safety guard | Low | Validate `$PLUGIN_DIR` before `rm -rf` |
| Long-term orchestrator unification | Low | Single pipeline definition for both runtimes |

### Planned / TODO

| Feature | Priority | Notes |
|---------|----------|-------|
| Automated tests (bump-version, hooks, plugin deps) | Medium | Toolchain has zero test coverage |
| Pure-bash version parser fallback | Low | Remove python3 dependency from version scripts |
| install.sh path safety guard | Low | Validate `$PLUGIN_DIR` before `rm -rf` |
| Long-term orchestrator unification | Low | Single pipeline definition driving both CC and deepcode-cli |

## Dependencies

AIDE ships [Superpowers](https://github.com/obra/superpowers) skills directly in `skills/` — no submodule required.

## Requirements

- [deepcode-cli](https://github.com/HKUDS/DeepCode) (primary) or [Claude Code](https://claude.ai/code) — see [README-cc.md](README-cc.md)
- Git
- Python 3
- Bash 4+
