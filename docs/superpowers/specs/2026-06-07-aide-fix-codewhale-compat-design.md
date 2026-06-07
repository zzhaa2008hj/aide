# aide-fix CodeWhale 兼容 — Design Spec

Date: 2026-06-07
Status: Approved
Topic: 让 aide-fix 在符合 CodeWhale 设计规范的前提下，在 CodeWhale 中可用

## Overview

将 `skills/aide-fix/SKILL.md` 改造为后端无关（backend-agnostic），同时服务 deepcode-cli 和 CodeWhale。移除 deepcode-cli 品牌化语言和外部文件引用，使 CodeWhale 用户通过 `/skill install` 安装后可直接使用 `/aide-fix`。

## Motivation

- 当前 aide-fix 有 deepcode-cli 烙印：分析步骤叫 "DeepCode Assisted Analysis"，输出 JSON 含 `deepcode` 字段
- 引用了外部 `aide-core/conventions.md` — 违反 CodeWhale 自包含规范
- aide-fix 是单 agent 串行流水线，不像主流水线的 implement 阶段在 deepcode（串行）和 CodeWhale（`agent_open` 并行）之间有实质性差异。两个后端在 fix 场景下行为一致，无需维护两份 SKILL.md

## Design Decision

选择 **方案 A：改为后端无关的单一 skill**，而非仿照主流水线创建 `aide-fix-codewhale` 副本。

理由：aide-fix 全程单 agent 串行，deepcode-cli 和 CodeWhale 在 fix 场景无行为差异。维护一份 700+ 行的 SKILL.md 即可覆盖两个后端。

## Changes

### 文件范围

单文件变更：`skills/aide-fix/SKILL.md`

### 1. 删除外部引用（Step 2: Read conventions）

**位置**：第 127–135 行

**当前**：搜索并读取外部 `aide-core/conventions.md` 文件（~10行逻辑，含3个搜索路径分支）。

**改为**：删除整个 Step 2。Conventions 中的关键规则已内联在 SKILL.md 中：
- 分支命名 `aide-fix/<slug>` — Step 1 已定义
- Commit 格式 `aide-fix(<stage>):` — 各阶段 commit 步骤已定义

后续步骤序号顺延（Step 3 → Step 2, Step 4 → Step 3, Step 5 → Step 4, Step 6 → Step 5）。

### 2. 分析步骤去品牌化（Step 1.2.5）

| 元素 | 当前 | 改为 |
|------|------|------|
| 标题 | `DeepCode Assisted Analysis (MANDATORY)` | `Code Analysis (MANDATORY)` |
| 正文首句 | `You are running inside deepcode-cli — use its built-in static analysis...` | `Use your static analysis capabilities to surface issues...` |
| 子标题 | `DeepCode findings` | `Code Analysis findings` |
| 报告模板行 | `**DeepCode CLI:** <N> issues found...` | `**Code Analysis:** <N> issues found...` |
| JSON 字段 | `"deepcode": {"issues_found": N, "issues_related": M}` | `"code_analysis": {"issues_found": N, "issues_related": M}` |
| Python dict key | `'deepcode'` | `'code_analysis'` |

### 3. 其他 DeepCode 引用清理

对全文件执行 `grep -i deepcode`，确保无残留引用。当前确认涉及位置：
- Step 1.2.5（主变更区）
- Step 1.5 分析输出模板（markdown + JSON + Python）
- 不涉及 `.aide/fix-state.json`、scope fence 逻辑、gates、retry 逻辑

### 不变的部分

- `.aide/fix-state.json` 结构 — 已是后端无关
- 分支命名 `aide-fix/<slug>` — 不变
- Commit 格式 `aide-fix(<stage>): <slug> — <summary>` — 不变
- 三阶段流程（analyze → implement → test）— 不变
- Scope fence 机制 — 不变
- Gate 系统（confirm / confirm_skip / auto）— 不变
- Retry 逻辑（max 2）— 不变
- 前端元数据 `name: aide-fix` — 不变
- 安装路径 `skills/aide-fix/SKILL.md` — 不变

## Verification

| # | 验证项 | 方法 | 预期 |
|---|--------|------|------|
| 1 | 无 `aide-core` 引用 | `grep -n "aide-core" skills/aide-fix/SKILL.md` | 无结果 |
| 2 | 无 `DeepCode`/`deepcode` | `grep -in "deepcode" skills/aide-fix/SKILL.md` | 无结果 |
| 3 | 所有 MANDATORY 步骤完整 | 人工检查 Step 0.5, 1.2.5 | 存在且完整 |
| 4 | JSON schema 键名一致 | 人工检查 `code_analysis` 在模板和脚本中拼写一致 | 一致 |
| 5 | CodeWhale 可发现 | frontmatter `name: aide-fix` 不变 | 可发现 |
| 6 | 现有用户不受影响 | 分析步骤语义不变 | 向后兼容 |

## Edge Cases

- **旧 analyze JSON**：用户仓库中可能有旧 `.aide/fix/output/*-analyze.json` 包含 `deepcode` 字段。新的 analyze 生成 `code_analysis` 格式，两边不会冲突（analyze 不读取旧 JSON）。
- **Resume**：`.aide/fix-state.json` 结构未变，resume 行为完全不受影响。
- **README**：Feature Status 表中 "Fix pipeline" 条目可标注 "backend-agnostic"，无需新增行。

## Constraints

1. **Source-grounded**：CodeWhale 兼容性以 [CodeWhale source](https://github.com/Hmbown/CodeWhale) 和已批准的 [codewhale-orchestrator-design](2026-06-05-codewhale-orchestrator-design.md) 为依据
2. **Backward compatible**：现有 deepcode-cli 用户的 aide-fix 行为不变
3. **Schema compatible**：JSON 输出字段重命名（`deepcode` → `code_analysis`），但语义等价
4. **Self-contained**：移除所有外部文件引用，SKILL.md 完全自包含

## Non-goals

- 不做 aide-fix 的 subagent 并行化（单 agent 串行是 fix 场景的正确设计）
- 不做 CodeWhale 特有的 `agent_open` 集成（fix 不涉及多任务并行）
- 不创建独立的 `aide-fix-codewhale` 副本
