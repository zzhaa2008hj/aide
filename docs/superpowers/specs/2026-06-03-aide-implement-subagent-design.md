# AIDE Implement Stage — Subagent-Driven Mode

## Overview

Implement 阶段不再使用单体 `aide-implement` skill。Orchestrator 读取 `plan.json` 的 task 列表，通过 Superpowers 的 `subagent-driven-development` 逐个派发实现，每个 task 经过 spec compliance review 和 code quality review。Superpowers 作为 submodule 随 AIDE 分发，始终可用。

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| 执行模型 | Subagent-driven，per-task 派发 + 两阶段 review | Superpowers 已验证的模式，避免重复造轮子 |
| Task 粒度 | plan 阶段产出 subagent 粒度的 task（2-5 分钟完成） | plan 设计时就知道 implement 的执行方式 |
| 依赖处理 | 拓扑排序 + 就绪队列，无依赖 task 可并行 | 最大化并行度，blocked task 不阻塞独立 task |
| 失败处理 | Blocked task 跳过，继续无依赖的其他 task，最终汇总 | 不阻塞独立 task，用户集中处理 blocked |
| Gate | auto — 仅输出汇总报告 | task 级 review 已足够，不需要整体暂停 |
| Skill 结构 | 无 `aide-implement` skill，逻辑在 orchestrator 中 | implement 是编排，不是单 skill |

## Core Flow

```
plan 阶段完成 (plan.json)
       │
       ▼
  ┌──────────────────────────┐
  │ Orchestrator 读取         │
  │ plan.json tasks + 依赖    │
  └──────┬───────────────────┘
         │
         ▼
  ┌──────────────────────────┐
  │ 拓扑排序 → 就绪队列        │
  │ 无 depends_on = 立即派发   │
  │ 有 depends_on = 等待完成   │
  └──────┬───────────────────┘
         │
         ▼
  ┌──────────────────────────┐
  │ Subagent-driven loop      │
  │                            │
  │ 1. 从就绪队列取 task       │
  │ 2. 派发 implement subagent │
  │ 3. 自检 → 提交             │
  │ 4. 派发 spec review agent  │
  │ 5. 派发 quality review     │
  │ 6. review 通过 → done      │
  │    review 失败 → 修复 →    │
  │    重检 (最多 2 轮)        │
  │ 7. 释放被该 task 阻塞的    │
  │    task 到就绪队列          │
  │                            │
  │ 异常: 标记 blocked, 继续   │
  └──────┬───────────────────┘
         │ 队列空 (done + blocked)
         ▼
  ┌──────────────────────────┐
  │ 产出 implement.json       │
  │ gate: auto → 报告 + 提交   │
  └──────────────────────────┘
```

## Dependency Resolution

plan.json 的 tasks 携带 `depends_on` 字段:

```json
{
  "tasks": [
    {"id": "T001", "depends_on": []},
    {"id": "T002", "depends_on": ["T001"]},
    {"id": "T003", "depends_on": []},
    {"id": "T004", "depends_on": ["T001", "T003"]}
  ]
}
```

Orchestrator 做拓扑排序：
- 初始就绪队列: T001, T003
- T001 完成 → 释放 T002, T004（但 T004 还等 T003）
- T003 完成 → 释放 T004
- T002 → T004
- 结束条件: 就绪队列为空且无等待中的 task

被 blocked task 阻塞的 task 自动被阻塞（不解锁等待中的 task）。

## Task Execution (per task)

Orchestrator 通过 Skill tool 加载 `subagent-driven-development`，传入:

1. task 描述（来自 plan.json 的 description + files_to_touch）
2. spec 上下文（feature 的 acceptance_criteria）
3. 已完成 task 的提交 SHA（作为代码上下文）

Subagent 流程（由 Superpowers 执行）:
1. Implementer subagent → 实现代码 + 测试 + 提交 + 自检
2. Spec reviewer → 验证代码是否符合 acceptance_criteria
3. Quality reviewer → 代码质量检查

Orchestrator 只负责派发和汇总结果，不参与 review 逻辑。

Review 不通过时，implementer 修复后重检，最多 2 轮。2 轮仍未通过 → 标记 blocked。

## implement.json Schema

```json
{
  "completed_tasks": ["T001", "T003"],
  "blocked_tasks": [
    {
      "task_id": "T002",
      "reason": "review 2 轮未通过: acceptance_criteria 第二条未满足"
    }
  ],
  "changed_files": ["src/models/user.py", "src/api/auth.py"],
  "task_results": [
    {
      "task_id": "T001",
      "status": "done",
      "commits": ["abc123"],
      "review_summary": "spec ✅, quality approved"
    },
    {
      "task_id": "T002",
      "status": "blocked",
      "reason": "spec review failed: missing password hashing"
    },
    {
      "task_id": "T003",
      "status": "done",
      "commits": ["def456"],
      "review_summary": "spec ✅, quality approved"
    }
  ]
}
```

Schema 要求:
- `completed_tasks`: string array，引用的 task ID
- `blocked_tasks`: object array，每项含 `task_id` + `reason`
- `changed_files`: string array
- `task_results`: object array，每项含 `task_id`, `status` (done|blocked), `commits` (仅 done), `review_summary` (仅 done), `reason` (仅 blocked)

## Gate

`after_implement` gate 默认类型为 `auto` — 不暂停，输出汇总报告（done/blocked counts, changed files, 有 blocked 时提示用户手动处理）。

用户在 `.aide/config.yaml` 中可以将 gate 类型改为 `confirm` 来强制暂停审核。

## Completion Report

```
[aide] Implement stage complete:
  ✓ T001 — User model (abc123)
  ✗ T002 — Login API (blocked: spec review failed)
  ✓ T003 — User repository (def456)

  2/3 tasks completed, 1 blocked.
  Changed: src/models/user.py, src/repo/user.py

  To fix blocked tasks, update plan.json and run /aide --continue
```

## Files To Create / Modify

| File | Change |
|------|--------|
| `skills/aide/skill.md` | Stage 3 (implement) 替换为 subagent-driven 流程；移除 `aide-implement` 引用 |
| `aide-core/conventions.md` | Stage skill 列表从 4 变为 3；更新 implement 描述 |
| `aide-core/schemas/implement.schema.json` | 新增 implement.json schema |
| `aide-core/schemas/plan.schema.json` | Phase 2 新增，task 含 depends_on |
| `skills/aide-plan/skill.md` | Phase 2 新增，产出含 depends_on 的 plan.json |

## Testing

集成测试（需要完整 AIDE + Superpowers + 业务项目环境）:
1. plan.json 含 3 个独立 task → 验证并行派发
2. plan.json 含依赖链 T001→T002→T003 → 验证串行依赖
3. 1 个 task spec review 故意失败 → 验证 blocked 处理和汇总报告
4. 所有 task 完成 → 验证 implement.json 格式正确
5. gateway auto → 验证不暂停
6. gateway confirm → 验证暂停
