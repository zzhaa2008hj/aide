# AIDE DeepCode Integration

## Overview

Package AIDE's pipeline logic (spec → plan → implement → test) as DeepCode InteractionPlugins, enabling DeepCode users to run AIDE's structured workflow without Claude Code. Zero changes to existing AIDE code or DeepCode source.

## Architecture

```
DeepCode Workflow                    AIDE Plugins
═══════════════════════════════════════════════════════
user input
    │
    ├─ BEFORE_PLANNING ──────────→ AideSpecPlugin
    │                               • 需求分析 → spec.md + spec.json
    │                               • Gate: confirm_skip
    │
plan generation (DeepCode native)
    │
    ├─ AFTER_PLANNING ───────────→ AidePlanPlugin
    │                               • spec.json → plan.json
    │                               • 依赖拆解 + estimated_order
    │                               • Gate: confirm_skip
    │
    ├─ BEFORE_IMPLEMENTATION ────→ AideImplementPlugin
    │                               • 读 plan.json → 拓扑排序 → 就绪队列
    │                               • Per-task 调用 DeepCode Agent 生成代码
    │                               • Spec compliance review
    │                               • Code quality review
    │                               • Review 失败 → 修复（最多 2 轮）→ blocked
    │                               • 汇总 → implement.json
    │
    ├─ AFTER_IMPLEMENTATION ─────→ AideTestPlugin
    │                               • 运行测试套件
    │                               • Spec 验收（对照 spec.json）
    │                               • 覆盖率检查
    │                               • 判定 verdict（pass/fail/manual）
    │                               • Retry loop（fail/manual → 回 implement）
    │
complete
```

### Principle

- **Core logic shared**: schemas (spec/plan/implement/test) are the single source of truth
- **Platform-specific**: git features, state persistence, file naming are handled by each platform natively
- **Zero invasion**: AIDE plugins register via DeepCode's PluginRegistry, disable and workflow runs as normal

## Deliverables

```
aide_deepcode/
├── __init__.py                  # Plugin registration entry
├── aide_spec_plugin.py          # BEFORE_PLANNING: requirements → spec
├── aide_plan_plugin.py          # AFTER_PLANNING: spec → plan.json
├── aide_implement_plugin.py     # BEFORE_IMPLEMENTATION: plan.json → code
├── aide_test_plugin.py          # AFTER_IMPLEMENTATION: test + verify
└── aide_deepcode_config.json    # AIDE-specific settings (optional)
```

Each plugin extends `InteractionPlugin` and uses DeepCode's `InteractionRequest` for gates.

## Gate Mapping

| AIDE Gate | DeepCode Implementation |
|-----------|------------------------|
| `confirm` | `InteractionRequest(required=True)` — must respond |
| `confirm_skip` | `InteractionRequest(required=False)` — can skip |
| `auto` | No `InteractionRequest` — passes silently |
| skip → persist auto | Write preference to `aide_deepcode_config.json` |

## Test Retry Logic

Implemented in `AideTestPlugin`:

```
test 完成 → 读 verdict
  │
  ├─ pass ──→ 无 InteractionRequest，直接完成 ✅
  │
  ├─ fail / manual
  │     │
  │     ├─ retries < 3 ──→ 自动回 CodeImplementationWorkflow 修复 → 重跑 test
  │     │
  │     └─ retries >= 3 ──→ InteractionRequest(required=True)
  │                           "Test stage failed 3 times. Accept and proceed? (y/n)"
  │                           ├─ y → Accept，流水线结束
  │                           └─ n → retries 归零，回 implement 再 3 轮
```

## Installation

```bash
# Claude Code user（unchanged）
claude plugin install aide@aide --scope project

# DeepCode user（new）
cp -r aide_deepcode/ deepcode_lab/workflows/plugins/aide/
# Plugin auto-registers on next DeepCode startup
```

## Shared Assets

`aide-core/schemas/` — both distributions share the same JSON schemas:
- `spec.schema.json`
- `plan.schema.json`  
- `implement.schema.json`
- `test.schema.json`

## Out of Scope

- Git branch isolation （DeepCode 有自有 workspace 管理）
- state.json persistence （DeepCode 有 session 系统）
- Dynamic file naming （DeepCode workspace 管理）
- Version bump hooks （DeepCode 无此概念）
- `aide-init`, `aide-update`, `aide-continue` （DeepCode 有等价机制）
