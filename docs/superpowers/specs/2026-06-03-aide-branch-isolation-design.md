# AIDE Branch Isolation Design

## Overview

每次 `/aide "需求"` 新流程启动时，自动从当前 HEAD 创建 `aide/<slug>` 分支，将 pipeline artifacts 和后续业务代码变更隔离在独立分支上，防止污染用户的工作分支。

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| 分支命名 | `aide/<slug>` | 简洁、可读、易检索 |
| 创建时机 | 新流程自动创建，`--continue` 复用现有分支 | 命令语义已表达用户意图 |
| 基准分支 | 当前 `HEAD` | 保持开发连续性 |
| 脏工作区处理 | `git stash push -m "AIDE: auto-stash before <branch>"` | 保护用户数据，可追溯 |
| Pipeline 完成后 | 留在分支，不自动合并 | 合并是业务决策，留给用户 |
| Slug 生成 | LLM 从需求描述提取 | 自然语言任务，无需额外工具 |
| 分支名冲突 | 追加数字后缀 `-2`, `-3` | 简单可靠 |

## Core Flow

```
/aide "Add user login"
       │
       ▼
  ┌─────────────────┐
  │ 检测运行模式     │
  │ --continue?     │──yes──▶ 验证当前在 aide/* 分支 → 跳到 Step 1
  └──────┬──────────┘
         │ no (新流程)
         ▼
  ┌─────────────────┐
  │ 生成 slug       │  "user-login"
  │ 分支名 =        │
  │ aide/user-login │
  └──────┬──────────┘
         │
         ▼
  ┌─────────────────┐
  │ 检查工作区       │──dirty──▶ git stash push -m "AIDE: auto-stash before aide/user-login"
  │ git status      │
  └──────┬──────────┘
         │ clean
         ▼
  ┌─────────────────┐
  │ 记录原始分支     │  git branch --show-current → ORIG_BRANCH
  └──────┬──────────┘
         │
         ▼
  ┌─────────────────┐
  │ 创建并切换分支   │  git checkout -b aide/user-login
  └──────┬──────────┘
         │
         ▼
     现有 Step 1-5 → Stage Loop → Gate → Git Commit
         │
         ▼
  ┌─────────────────┐
  │ 完成报告         │  分支名, 原始分支, stash, 建议合并命令
  └─────────────────┘
```

## --continue Flow

```
/aide --continue
       │
       ▼
  ┌────────────────────────┐
  │ git branch --show-current │
  └──────┬─────────────────┘
         │
    ┌────┴────┐
    │ 是 aide/* │──no──▶ 错误提示，引导用户切换到对应分支
    │ 分支?    │
    └────┬────┘
         │ yes
         ▼
   在现有分支上继续 pipeline
```

## Slug Generation

Orchestrator (LLM) 从需求描述中提取简短英文标识：
- 抓取核心关键词（3-5 词），小写，`-` 连接
- Example: `"Add user login with OAuth support"` → `user-login-oauth`
- 冲突处理：`git branch --list aide/<slug>*` 检查存在则追加 `-2`, `-3`

## Completion Report Additions

```
Branch: aide/user-login-oauth
Original branch: feature/auth

Next steps:
  git checkout feature/auth && git merge aide/user-login-oauth

Auto-stashed changes: 1 stash(es) — run `git stash list` to review
```

## Files Changed

| File | Change |
|------|--------|
| `skills/aide/skill.md` | Startup Sequence: 增加分支准备步骤（slug 生成、stash、checkout -b、冲突处理）；Completion Report: 增加分支/原始分支/stash 信息 |
| `aide-core/conventions.md` | Git 章节追加分支命名规范 `aide/<slug>` |

## Error Handling

| Scenario | Handling |
|----------|----------|
| 分支名已存在 | 追加 `-2`, `-3` 后缀直到找到可用名 |
| 脏工作区 + stash 失败 | 报错并提示用户手动处理（如权限问题） |
| `--continue` 不在 aide 分支 | 报错，提示切换到正确的 `aide/*` 分支 |
| checkout -b 失败 | 报错并 abort，恢复 stash（如果之前 stash 了） |

## Testing

手动端到端测试：
1. 干净工作区启动 `/aide "test feature"` → 验证分支创建、commit 在 `aide/test-feature` 上
2. 脏工作区启动 → 验证 stash 创建和恢复提示
3. `/aide --continue` 在非 aide 分支 → 验证错误提示
4. 分支名冲突 → 验证 `-2` 后缀
5. Pipeline 完成后切回原始分支 → 验证原始分支无 `.aide/` commits
