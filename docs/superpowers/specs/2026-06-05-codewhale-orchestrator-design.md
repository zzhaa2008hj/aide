# AIDE CodeWhale Orchestrator — Design Spec

Date: 2026-06-05
Status: Approved
Topic: Add CodeWhale-compatible pipeline orchestrator to AIDE

## Overview

Add a self-contained CodeWhale orchestrator skill (`skills/aide-codewhale/SKILL.md`) that lets CodeWhale users run the full AIDE pipeline (spec → plan → implement → test) via `$aide` or `/aide`.

CodeWhale takes priority over deepcode-cli for new feature development going forward.

## Source Authority

All CodeWhale compatibility decisions are grounded in the [CodeWhale source code](https://github.com/Hmbown/CodeWhale). Key files referenced:

| Source File | Content Used |
|-------------|-------------|
| `crates/tui/src/skills/mod.rs` | Skill discovery, format parsing, registry |
| `crates/tui/src/skills/install.rs` | Native install mechanism, tarball scanning |
| `crates/tui/src/skills/system.rs` | Bundled system skills pattern |
| `docs/SKILL_INVOCATION_DESIGN.md` | `$skill-name` invocation syntax |
| `README.md` | Sub-agents (`agent_open`/`agent_eval`), approval gates, tool surface |

## Architecture

### Relationship to existing orchestrators

```
                   ┌─────────────────┐
                   │  Shared schemas  │  aide-core/schemas/
                   │  conventions     │  aide-core/*.md
                   └────────┬────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌─────────────────┐ ┌───────────────┐ ┌─────────────────────┐
│ aide (CC)       │ │ aide-deepcode │ │ aide-codewhale  🆕  │
│ Skill tool      │ │ Reads external │ │ Fully self-contained│
│ subagent-driven │ │ SKILL files    │ │ agent_open parallel │
└─────────────────┘ └───────────────┘ └─────────────────────┘
                            ▲                   ▲
                            │                   │
                    reads aide-core/    all rules inlined
                    at runtime          (no external deps)
```

### Why self-contained

CodeWhale's native install (`/skill install`) installs exactly ONE skill per invocation. The tarball scanner (`install.rs:1066-1175`) picks the best SKILL.md match by rank and installs only that skill directory. Therefore the orchestrator must embed all stage workflows, protocol rules, state update patterns, and output schemas inline — it cannot depend on separately installed stage skill files or `aide-core/` references.

The orchestrator frontmatter uses `name: aide` so users invoke it as `$aide` or `/aide`.

## Pipeline Stages

### Stage 0: Initialize

- Parse user request → generate slug (3-5 hyphenated keywords)
- Analyze project context (mandatory, inline procedure: map structure, identify tech stack, understand directory conventions, detect existing patterns, check for tests, summarize findings)
- Branch decision: create `aide/<slug>` or stay on current branch
- Initialize `.aide/state.json` and output directories
- Load gate configuration from `.aide/config.yaml`
- All protocols and state update patterns are described inline in the SKILL.md body

### Stage 1: spec

Inline workflow:
- Analyze requirements against project context
- Generate `.aide/output/1-spec/<date>-<slug>-spec.md` (human-readable)
- Generate `.aide/output/1-spec/<date>-<slug>-spec.json` (structured, matches existing schema)
- Gate: per `.aide/config.yaml` (confirm / confirm_skip / auto)

### Stage 2: plan

Inline workflow:
- Decompose spec features into discrete implementation tasks
- Each task: `id`, `feature_id`, `title`, `description`, `files_to_touch`, `depends_on`, `order_hint`
- Generate `.aide/output/2-plan/<date>-<slug>-plan.md` + `.json`
- Gate: per `.aide/config.yaml`

### Stage 3: implement

Uses CodeWhale's sub-agent system for parallel task execution with dependency ordering:

```
Task queue (topological sort by depends_on)
    │
    ├─ Batch 1: tasks with no unmet dependencies
    │   ├── agent_open("T001") ─┐
    │   ├── agent_open("T002") ─┤ parallel (mutually independent)
    │   └── agent_open("T003") ─┘
    │       │ agent_eval collects results
    │       ▼ unlock tasks dependent on T001/T002/T003
    │
    ├─ Batch 2: tasks whose deps are all satisfied
    │   ├── agent_open("T004") ─┐
    │   └── agent_open("T005") ─┘
    │
    └─ ...repeat until all tasks done or blocked
```

**Dependency rule**: Tasks within the same batch must have zero `depends_on` intersection. Any task that depends on another task waits for the next batch. This is compatible with the existing `plan.json` `depends_on` field.

**CodeWhale source basis**: `agent_open` is non-blocking (returns immediately), concurrent cap is 10 (configurable to 20), and `agent_eval` provides bounded result retrieval (`README.md` sub-agents section).

- Max 3 sub-agents per batch to maintain quality
- Each sub-agent receives: task description + acceptance criteria + project context
- Results aggregated into `.aide/output/3-implement/<date>-<slug>-implement.json`
- Code analysis pass on changed files (correctness, security, quality, style)
- Gate: `auto` (no user interaction)

### Stage 4: test

Inline workflow:
- Execute test suite against changes
- Verify implementation against spec acceptance criteria
- Code verification pass (bug detection, security audit, regression risk, test quality)
- Retry on failure: up to 3 rounds, feeding failures back to Stage 3
- Generate `.aide/output/4-test/<date>-<slug>-test-report.md` + `.json`
- Gate: per `.aide/config.yaml`

### Pipeline Complete

Same merge decision flow as other orchestrators: offer to merge `aide/<slug>` back to original branch.

## Installation

Pure CodeWhale native install:

```
/skill install github:zzhaa2008hj/aide
```

CodeWhale's installer (`install.rs:scan_tarball`) matches `skills/aide-codewhale/SKILL.md` via the `skills/<name>/SKILL.md` pattern (rank 1 candidate). The skill is installed to `~/.codewhale/skills/aide/SKILL.md` and auto-discovered on next session start.

No install script needed. No separate stage skill installation needed.

## Resume

If `.aide/state.json` exists with `current_stage` not equal to `"complete"`, resume from that stage. Check `completed_stages` array to skip finished stages.

## Files Changed

| Action | File | Description |
|--------|------|-------------|
| Create | `skills/aide-codewhale/SKILL.md` | Self-contained orchestrator, `name: aide` |
| Edit | `README.md` | Add CodeWhale install/usage docs, update Feature Status |
| Edit | `CLAUDE.md` | Update priority: CodeWhale first, then deepcode-cli |

No changes to `skills/aide/`, `skills/aide-deepcode/`, `aide_deepcode/`, or `aide-core/`.

## Feature Status Update

Add to README Feature Status table:

| Feature | Status |
|---------|--------|
| CodeWhale orchestrator (`aide-codewhale`) | Done |

## Constraints

1. **Source-grounded**: All CodeWhale-specific behavior must reference actual source files in `https://github.com/Hmbown/CodeWhale`. No guessing.
2. **Backward compatible**: Existing CC and deepcode-cli orchestrators and install scripts must continue working unchanged.
3. **Schema compatible**: Output artifacts (spec.json, plan.json, implement.json, test-report.json) must match the same logical structure as existing artifacts. Schema formats are described inline in the orchestrator body since `aide-core/schemas/` is not available at runtime.
4. **State compatible**: `.aide/state.json` format must remain compatible across all orchestrators. State update patterns are inlined.
5. **Self-contained**: The orchestrator SKILL.md must contain ALL necessary protocols, procedures, schemas, and workflows inline. It must work after a single `/skill install` with no other AIDE skills present.

## Non-goals

- Unifying the three orchestrators into one (deferred per existing TODO)
- CodeWhale-specific MCP tool integration (can be added later)
- `$aide` syntax optimization beyond basic `name: aide` frontmatter
- Multi-skill install via single `/skill install` command (CodeWhale limitation)
