# AIDE 放弃 Git 分支控制

**日期：** 2026-06-17
**状态：** Draft
**来源：** Brainstorming — AIDE 不再控制用户项目的 git 版本

## 动机

AIDE 当前在用户业务项目中自动创建 `aide/<slug>` 分支、auto-stash、切换分支、完成时询问 merge。这些操作侵入了用户的 git 工作流，增加了不必要的复杂性。用户应该完全控制自己的分支策略。

## 设计概览

**核心原则：AIDE 只提交 `.aide/` 文件到当前分支，不创建、切换、合并任何分支。**

### 移除项

| 位置 | 移除内容 |
|------|---------|
| `skills/aide/SKILL.md` | Step 1（slug 生成、分支创建、auto-stash、checkout） |
| `skills/aide/SKILL.md` | 完成时的 merge 询问 + `git merge` 逻辑 |
| `skills/aide/SKILL.md` | auto-stash 恢复提示 |
| `skills/aide-deepcode/SKILL.md` | Step 0.3-0.4（分支创建）、merge 逻辑 |
| `skills/aide-codewhale/SKILL.md` | Step 0.3-0.4（分支创建）、merge 逻辑 |
| `skills/aide-fix/SKILL.md` | 分支创建逻辑（如有） |
| `aide-core/conventions.md` | "Branch Isolation" 整节、branch naming 规则 |
| `aide-core/pipeline-protocol.md` | 分支相关约束描述 |

### 保留项

| 位置 | 保留内容 |
|------|---------|
| `skills/aide/SKILL.md` | Git Commit：每阶段后 auto-commit `.aide/`，直接提交到当前分支 |
| `skills/aide/SKILL.md` | `/aide-continue`：当前分支检测 `.aide/state.json` 即恢复 |
| `hooks/` | 全部保留（AIDE 项目自身工具，非用户项目） |
| `aide-core/scripts/` | 全部保留 |

### 行为变化

| 场景 | 原来 | 现在 |
|------|------|------|
| 启动 `/aide` | 创建 `aide/<slug>` 分支 + stash + checkout | 直接在当前分支工作，生成 slug 仅用于文件命名 |
| 每阶段结束 | `git add .aide/ && git commit` 到 `aide/<slug>` | 同上，提交到当前分支 |
| 完成时 | 询问 merge 回原始分支 | 直接报告完成 |
| `/aide-continue` | 检测 `aide/<slug>` 分支 + state.json | 检测当前分支 `.aide/state.json` |
| `/aide-fix` | 创建 `aide-fix/<slug>` 分支 | 直接在当前分支工作 |

### state.json 简化

```jsonc
// 原来
{"pipeline": "<slug>", "slug": "<slug>", "current_stage": "spec", "completed_stages": [], ...}

// 现在 — 去掉 pipeline（与 slug 重复）、去掉 ORIG_BRANCH 追踪
{"slug": "<slug>", "current_stage": "spec", "completed_stages": [], "last_updated": "<ts>"}
```

### `/aide-continue` 简化

原来：验证 `aide/<slug>` 分支存在 → 读取 state.json → 跳过已完成 stage → 恢复执行

现在：直接读取 `.aide/state.json` → 跳过已完成 stage → 恢复执行（不需要分支验证步骤）

### 涉及文件

```
skills/aide/SKILL.md           — 移除 Step 1 分支逻辑、merge 询问
skills/aide-deepcode/SKILL.md  — 同上
skills/aide-codewhale/SKILL.md — 同上
skills/aide-fix/SKILL.md       — 移除 fix 分支逻辑（如有）
skills/aide-continue/SKILL.md  — 更新 resume 检测（去掉分支验证）
aide-core/conventions.md       — 移除 Branch Isolation 节、更新 Git 节
aide-core/pipeline-protocol.md — 移除分支相关约束
README.md                      — 更新 Pipeline 描述 + Feature Status
```

### 不在范围

- git hooks 的修改（属于 AIDE 项目自身，不影响用户）
- `.aide/` 目录结构的变更
- auto-commit 行为本身的修改

### 兼容性

已存在的 `aide/<slug>` 分支不受影响。`/aide-continue` 如果在旧分支上运行：
- 检测到 `.aide/state.json` 且分支名匹配旧模式 → 正常恢复，但完成后不询问 merge
- 恢复完成后用户自行决定分支处理
