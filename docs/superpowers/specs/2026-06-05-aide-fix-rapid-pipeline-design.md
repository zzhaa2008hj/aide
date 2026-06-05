# AIDE Fix — Rapid Bug-Fix and Small-Optimization Pipeline

## Overview

`/aide-fix` is a lightweight companion to `/aide`, designed for bug fixes and small optimizations that don't warrant the full spec → plan → implement → test pipeline. It follows an analyze → implement → test flow with 3 human gates, scope-fenced code changes, and automatic test-retry loops.

Independent from `/aide` — separate command, state file, branch prefix, and output directory. The two pipelines can run concurrently without interference.

## Pipeline Flow

```
/aide-fix "<bug description or error log>"
                    │
      ┌─────────────┴─────────────┐
      │  Stage 0: Init            │
      │  → 项目上下文分析           │
      │  Gate 1: 分支确认 (confirm) │
      └─────────────┬─────────────┘
                    │
      ┌─────────────┴─────────────┐
      │  Stage 1: Analyze         │
      │  → 定位根因                │
      │  → 确定文件列表 (scope fence)│
      │  → 风险评估                │
      │  Gate 2: confirm_skip     │
      └─────────────┬─────────────┘
                    │
      ┌─────────────┴─────────────┐
      │  Stage 2: Implement       │
      │  → scope fence 内修改      │
      │  → 最小 diff 约束          │
      │  → 生成 implement.md      │
      │  无独立 gate               │
      └─────────────┬─────────────┘
                    │
      ┌─────────────┴─────────────┐
      │  Stage 3: Test            │
      │  → 跑测试 → 失败自动重试    │
      │  → 最多重试 2 次           │
      │  Gate 3: confirm          │
      └─────────────┬─────────────┘
                    │
                完成 ✅
       改动留在 aide-fix/<slug> 分支
```

## Scope Fence

Defense against AI over-fixing. The analyze stage produces a file whitelist; the implement stage is hard-constrained to modify only those files.

- **Hard constraint:** Agent cannot touch any file outside the whitelist.
- **Soft constraint:** Within whitelisted files, use minimal diffs — no refactoring unrelated code, no reformatting, no style changes to existing code.
- If a test failure during Stage 3 reveals a root cause outside the fence, stop immediately and report to user — do not expand the fence autonomously.

## Anti-Overfix Constraints

Drawn from production best practices (Elastic self-healing PRs, aiheal scope-fencing, Kiro's preservation property):

1. Scope fence — file-level hard boundary (above)
2. Minimal diff — `"Do not change what is not strictly necessary to fix the issue."`
3. Preservation property — when the bug condition does NOT hold, patched code MUST behave identically to the original
4. No version downgrades, no permission widening, no new dependencies unless explicitly required by the fix

## Stages

### Stage 0: Init

| Step | Action |
|------|--------|
| 0.1 | Parse user input, generate kebab-case slug (3-5 keywords) |
| 0.2 | Analyze project context (reuse AIDE's mandatory context analysis: tech stack, directory conventions, test framework, code patterns) |
| Gate 1 | **confirm** — "即将在 `aide-fix/<slug>` 分支上进行修改，是否继续？" User must explicitly approve before branch creation. |

Branch created from current HEAD. If working tree is clean, no stash. If dirty, stash before branch creation with message `AIDE-FIX: auto-stash before aide-fix/<slug>`.

State tracked in `.aide/fix-state.json`.

### Stage 1: Analyze

Agent performs root cause analysis and produces a concise report for user review.

**Input:** User's bug description, error log, or optimization requirement.

**Agent actions:**
1. Search and read relevant files to understand the issue
2. Trace call chains to identify root cause
3. Determine which files need modification
4. Assess risk level (low / medium / high)

**Output format (markdown, shown to user at gate):**

```markdown
## Analyze Result: <brief summary>

**Root cause:** <one sentence>

**Files to modify:**
- `path/to/file1.java` — <one sentence per file describing the change>
- `path/to/file2.java` — <one sentence per file>

**Risk:** low | medium | high (<reasoning>)

**Scope fence:** only the files listed above
```

**Output file:** `.aide/fix/output/1-analyze/{date}-{slug}-analyze.md`

Naming follows AIDE conventions: `{date}-{slug}-{stage}.md`. If a file with the same name exists, append `-2`, `-3`, etc.

**Gate 2: confirm_skip** — User can:
- `y` — approve and proceed to implement
- `s` — skip review, execute directly
- `n` — reject with feedback, agent re-analyzes

### Stage 2: Implement

Single agent executes all code changes within the scope fence.

**Input:**
- User's original bug description
- Analyze stage output (root cause, file whitelist, risk)
- Project context (tech stack, conventions)

**Agent constraints:**
- **Hard:** Only modify files in the scope fence whitelist
- **Soft:** Minimal diff — only lines related to the fix; no unrelated refactoring, no reformatting
- Follow existing code style, naming conventions, and patterns

**Output file:** `.aide/fix/output/2-implement/{date}-{slug}-implement.md`

Content: list of modified files with per-file change summary, test status.

No independent gate between Stage 2 and Stage 3 — the test stage immediately follows.

### Stage 3: Test

Automatically run tests and retry on failure.

**Flow:**
1. Run project test suite (prioritize affected test files, then full suite)
2. All pass → proceed to Gate 3
3. Any failure → feed failure log to agent, agent attempts fix (within scope fence), rerun tests
   - Attempt 1: auto-fix → rerun tests
   - Attempt 2: auto-fix → rerun tests
   - Still failing after 2 retries → stop, present failure to user, request manual intervention
4. If root cause of failure is outside scope fence at any retry step → stop immediately, report to user

**Output file:** `.aide/fix/output/3-test/{date}-{slug}-test-report.md`

**Gate 3: confirm** — "改动已完成。是否确认？" User reviews the final diff and test results. Explicit y/n required.

## Output Directory Structure

```
.aide/fix/
├── fix-state.json
└── output/
    ├── 1-analyze/
    │   └── {date}-{slug}-analyze.md
    ├── 2-implement/
    │   └── {date}-{slug}-implement.md
    └── 3-test/
        └── {date}-{slug}-test-report.md
```

## Gate Summary

| Gate | Position | Type | Question |
|------|----------|------|----------|
| Gate 1 | After init, before branch creation | confirm | 确认创建 `aide-fix/<slug>` 分支？ |
| Gate 2 | After analyze | confirm_skip | 分析结果是否正确？可以 y/s/n |
| Gate 3 | After test | confirm | 改动确认？ |

## Comparison: `/aide` vs `/aide-fix`

| Dimension | `/aide` (full) | `/aide-fix` (rapid) |
|-----------|---------------|---------------------|
| Stages | spec → plan → implement → test | analyze → implement → test |
| Stage count | 4 | 2 (implement+test merged) |
| Gate count | 4 | 3 |
| Output root | `.aide/output/` | `.aide/fix/output/` |
| State file | `.aide/state.json` | `.aide/fix-state.json` |
| Branch prefix | `aide/` | `aide-fix/` |
| Parallel tasks | Yes (≤3, dependency-resolved) | No (single agent) |
| Scope fence | Implicit (plan.json tasks) | Explicit (file whitelist from analyze) |
| Test retry | Phase 3 | Yes (max 2 retries) |

## State File Schema

```json
{
  "slug": "login-npe",
  "branch": "aide-fix/login-npe",
  "description": "登录页 NPE at UserService.java:42",
  "current_stage": "implement",
  "completed_stages": ["init", "analyze"],
  "scope_fence": [
    "src/service/UserService.java",
    "src/controller/LoginController.java"
  ],
  "test_retries": 0,
  "created_at": "2026-06-05T10:00:00Z"
}
```

## Git Conventions

- Branch naming: `aide-fix/<slug>`
- Auto-commit `.aide/fix/` artifacts after each stage with message: `aide-fix(<stage>): <summary>`
- Business code changes are never auto-committed
- After pipeline completes, the branch is left as-is; merging back is a manual user decision

## Success Criteria

1. A user with a bug description or error log can run `/aide-fix` and get a scoped, tested fix
2. The analyze gate lets the user catch incorrect diagnoses before any code is written
3. The scope fence prevents AI from modifying unrelated files
4. The auto-retry loop handles simple test failures without user intervention
5. The pipeline can run concurrently with a `/aide` pipeline for the same project

## Non-Goals

- Automatic merge to main — always manual
- Multi-task parallel execution — single agent is sufficient for small changes
- Complexity auto-classification — user decides which pipeline to use
- Worktree isolation — branch isolation is sufficient for small changes
