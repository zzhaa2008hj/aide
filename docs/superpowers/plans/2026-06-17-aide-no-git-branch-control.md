# AIDE 放弃 Git 分支控制 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除 AIDE 对用户项目 git 分支的自动控制（创建/切换/stash/merge），保留 auto-commit 和 resume 功能。

**Architecture:** 纯删除 + 少量替换。3 个 orchestrator 各自移除分支创建和 merge 逻辑，auto-commit 路径从 `aide/<slug>` 改为当前分支，`/aide-continue` 简化为直接检测 `.aide/state.json`。

**Tech Stack:** Markdown（SKILL.md 文件编辑）

---

## File Structure

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `skills/aide/SKILL.md` | 删除 + 替换 | CC orchestrator：移除 Step 1、merge 询问 |
| `skills/aide-deepcode/SKILL.md` | 删除 + 替换 | deepcode-cli orchestrator：同上 |
| `skills/aide-codewhale/SKILL.md` | 删除 + 替换 | CodeWhale orchestrator：同上 |
| `skills/aide-fix/SKILL.md` | 删除 | 移除 fix 分支逻辑（如有） |
| `skills/aide-continue/SKILL.md` | 替换 | 简化 resume 检测逻辑 |
| `aide-core/conventions.md` | 删除 | 移除 Branch Isolation 节 |
| `aide-core/pipeline-protocol.md` | 删除 | 移除分支相关约束 |
| `README.md` | 替换 | 更新 Pipeline 描述 |

---

### Task 1: skills/aide/SKILL.md — 移除分支控制

**Files:**
- Modify: `skills/aide/SKILL.md`

- [ ] **Step 1: 重写 Step 1（分支准备 → 简化为仅生成 slug）**

找到 `### Step 1: Branch Preparation` 段落（约第 88-141 行）。整个替换为：

```markdown
### Step 1: Generate slug

Extract 3-5 core keywords from the user's requirement description, convert to lowercase, join with `-`. Example: `"Add user login with OAuth support"` → `user-login-oauth`.

This slug is used ONLY for naming pipeline output files (e.g., `2026-06-17-user-login-oauth-spec.md`). No branch is created.
```

移除原段落中所有内容（`--continue` 检测、`git branch --show-current`、`AskUserQuestion` 分支选择、stash、`git checkout -b` 等）。

- [ ] **Step 2: 简化 state.json 初始化**

找到 `### Step 5: Determine starting stage` 中的 state.json 初始化代码。将：

```json
{"pipeline": "<slug>", "slug": "<slug>", "current_stage": "spec", "completed_stages": [], "last_updated": "<timestamp>"}
```

改为：

```json
{"slug": "<slug>", "current_stage": "spec", "completed_stages": [], "last_updated": "<timestamp>"}
```

去掉 `pipeline` 字段。

- [ ] **Step 3: 移除 Completion Report 中的 merge 询问**

找到 `## Completion Report` 段落末尾的 merge 询问逻辑（约第 646-666 行）。移除以下整段：
- `AskUserQuestion` merge 选择
- `git checkout <target> && git merge`
- stash 恢复提示

替换为简洁的完成报告：

```markdown
### Completion Report

Display summary:

```
╔══════════════════════════════════════╗
║     AIDE Pipeline Complete           ║
╠══════════════════════════════════════╣
║ Stage     │ Status                   ║
║───────────┼──────────────────────────║
║ spec      │ ✓ Completed              ║
║ plan      │ ✓ Completed              ║
║ implement │ ✓ Completed              ║
║ test      │ ✓ Completed              ║
╚══════════════════════════════════════╝

Output: .aide/output/
```

Pipeline artifacts committed to the current branch. No merge needed — you control your own branching.
```

- [ ] **Step 4: 移除 "If aborted early" 中的分支引用**

找到完成报告末尾的 abort 说明。将：

```
If aborted early, show what was completed and note: "Resume on branch `<current-branch>` with `/aide-continue`."
```

改为：

```
If aborted early, show what was completed and note: "Resume with `/aide-continue`."
```

- [ ] **Step 5: 更新 Step 6 (Announce the plan) 中的分支引用**

找到 `### Step 6: Announce the plan`。确保不再提及分支创建。

- [ ] **Step 6: Commit**

```bash
git add skills/aide/SKILL.md
git commit -m "refactor(aide): remove git branch control from CC orchestrator

- Remove Step 1 branch creation, stash, checkout
- Remove merge inquiry at completion
- Simplify state.json (drop 'pipeline' field)
- Auto-commit still works — commits to current branch"
```

---

### Task 2: skills/aide-deepcode/SKILL.md — 移除分支控制

**Files:**
- Modify: `skills/aide-deepcode/SKILL.md`

- [ ] **Step 1: 重写 Step 0.3-0.4（分支决策 → 简化为仅生成 slug）**

找到 `### 0.3 Record current branch` 和 `### 0.4 Branch decision` 段落。替换为：

```markdown
### 0.3 Generate slug

Extract 3-5 keywords from the user's request, lowercase, hyphenate. Used ONLY for naming pipeline output files.
```

- [ ] **Step 2: 更新 Step 0.5 中的 state.json**

将 state.json 初始化中的 `"pipeline": "<slug>",` 行移除。

- [ ] **Step 3: 移除 Pipeline Complete 中的 merge 询问**

找到 `## Pipeline Complete` 段落的 `### Merge decision` 子节。整段移除。

- [ ] **Step 4: Commit**

```bash
git add skills/aide-deepcode/SKILL.md
git commit -m "refactor(aide-deepcode): remove git branch control"
```

---

### Task 3: skills/aide-codewhale/SKILL.md — 移除分支控制

**Files:**
- Modify: `skills/aide-codewhale/SKILL.md`

- [ ] **Step 1: 重写 Step 0.3-0.4**

与 Task 2 Step 1 相同。找到 `### 0.3 Record current branch` 和 `### 0.4 Branch decision`，替换为 slug 生成。

- [ ] **Step 2: 更新 state.json**

与 Task 2 Step 2 相同，移除 `pipeline` 字段。

- [ ] **Step 3: 移除 merge 询问**

与 Task 2 Step 3 相同，移除 `### Merge decision` 子节。

- [ ] **Step 4: Commit**

```bash
git add skills/aide-codewhale/SKILL.md
git commit -m "refactor(aide-codewhale): remove git branch control"
```

---

### Task 4: skills/aide-fix/SKILL.md — 移除 fix 分支逻辑

**Files:**
- Modify: `skills/aide-fix/SKILL.md`

- [ ] **Step 1: 检查是否有分支创建逻辑**

```bash
grep -n "aide-fix/\|git checkout\|git stash\|branch" skills/aide-fix/SKILL.md
```

如果有分支创建或切换逻辑，移除。fix pipeline 直接在当前分支工作。

- [ ] **Step 2: Commit**

```bash
git add skills/aide-fix/SKILL.md
git commit -m "refactor(aide-fix): remove git branch control"
```

---

### Task 5: skills/aide-continue/SKILL.md — 简化 resume 检测

**Files:**
- Modify: `skills/aide-continue/SKILL.md`

- [ ] **Step 1: 移除分支验证逻辑**

找到分支验证步骤（检查 `aide/<slug>` 分支是否存在）。替换为简洁的 state.json 检测：

```markdown
### Resume Detection

Check if `.aide/state.json` exists in the current directory:
```bash
test -f .aide/state.json && echo "found" || echo "not found"
```

If found: read `current_stage` and `completed_stages`. Skip completed stages, resume from `current_stage`.
If not found: report "No pipeline state found. Start a new pipeline with `/aide`."
```

移除原有的分支名验证、`git branch --list` 等逻辑。

- [ ] **Step 2: Commit**

```bash
git add skills/aide-continue/SKILL.md
git commit -m "refactor(aide-continue): simplify resume — detect state.json directly"
```

---

### Task 6: aide-core/conventions.md + pipeline-protocol.md — 清理文档

**Files:**
- Modify: `aide-core/conventions.md`
- Modify: `aide-core/pipeline-protocol.md`

- [ ] **Step 1: conventions.md — 移除 Branch Isolation 节**

找到 `## Branch Isolation` 节（约第 78-86 行）。整节移除。

- [ ] **Step 2: conventions.md — 移除 Fix Pipeline 分支命名**

在 `## Fix Pipeline Git Conventions` 中，移除 `- Branch naming: aide-fix/<slug>` 行。

- [ ] **Step 3: conventions.md — 更新 Git 节**

在 `## Git` 节中，确认 auto-commit 规则保留，确保不再引用 `aide/<slug>` 分支名。

- [ ] **Step 4: pipeline-protocol.md — 移除分支相关约束**

搜索并移除所有引用分支创建、分支隔离的段落。

```bash
grep -n "branch\|Branch\|stash\|merge" aide-core/pipeline-protocol.md
```

- [ ] **Step 5: Commit**

```bash
git add aide-core/conventions.md aide-core/pipeline-protocol.md
git commit -m "docs(aide-core): remove branch isolation and branch naming rules"
```

---

### Task 7: README.md — 更新文档

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 更新 Pipeline 描述**

将 Pipeline 表格中关于分支创建的说明移除。将：

```
AIDE will:
1. Create an aide/<slug> branch and stash uncommitted changes
2. Analyze the existing project context
3. Generate a structured spec
...
```

改为：

```
AIDE will:
1. Analyze the existing project context (tech stack, conventions, patterns)
2. Generate a structured spec (.aide/output/1-spec/)
3. Pause for your review (gate: confirm / confirm_skip / auto)
4. Proceed through plan → implement → test stages
5. Implement stage dispatches tasks to subagents with spec + quality reviews
6. Test stage auto-retries failures up to 3 rounds
7. Auto-commit .aide/ artifacts after each stage to the current branch
```

- [ ] **Step 2: 移除 Branch isolation 相关条目**

在 Feature Status 表格中，将 Branch isolation 行的状态改为 `Removed` 或直接移除，添加新条目：

```markdown
| Git branch control removed (user-managed branching) | Done |
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(readme): remove branch isolation references, add git simplification note"
```

---

## Execution Order

```
Task 1 (aide) ──→ Task 2 (aide-deepcode) ──→ Task 3 (aide-codewhale)
                                                      │
Task 4 (aide-fix) ────────────────────────────────────┤
Task 5 (aide-continue) ───────────────────────────────┤
                                                      ▼
                                              Task 6 (conventions)
                                                      │
                                                      ▼
                                              Task 7 (README)
```

Tasks 1-5 互相独立可并行。Task 6-7 建议最后执行（确认所有改动一致后更新文档）。
