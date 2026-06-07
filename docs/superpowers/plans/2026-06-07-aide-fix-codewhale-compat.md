# aide-fix CodeWhale 兼容改造 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `skills/aide-fix/SKILL.md` 改造为后端无关（backend-agnostic），移除 deepcode-cli 品牌化语言和外部 `aide-core/` 引用，使 CodeWhale 用户可原生使用 `/aide-fix`。

**Architecture:** 单文件变更，8 处精确编辑。删除外部引用 Step 2（~10行），6 处 "DeepCode"/"deepcode" 替换，1 处步骤序号重编号。零代码逻辑变更。

**Tech Stack:** 纯文本编辑（Markdown），验证用 `grep`。

**Spec:** [2026-06-07-aide-fix-codewhale-compat-design.md](../specs/2026-06-07-aide-fix-codewhale-compat-design.md)

---

### Task 1: 删除外部引用 Step 2

**Files:**
- Modify: `skills/aide-fix/SKILL.md:127-136`

- [ ] **Step 1: 删除 Step 2: Read conventions 段落**

删除 lines 127-136（`### Step 2: Read conventions` 到空行）。使用 Edit 工具：

```
old_string:
### Step 2: Read conventions

Read the AIDE conventions document to understand project patterns. Find it by searching for `aide-core/conventions.md` in these locations (in order):

1. `~/.claude/plugins/cache/aide/aide/*/aide-core/conventions.md` (installed via claude plugin install)
2. `.claude/plugins/aide/aide-core/conventions.md` (project directory)
3. `.claude/aide/aide-core/conventions.md` (legacy)

If found, read it and apply relevant conventions. If not found, proceed without it.

new_string:
(empty — delete the block entirely)
```

- [ ] **Step 2: 重编号后续步骤**

将后续 4 个步骤重编号（Edit 按内容匹配，无视行号偏移）：
- `### Step 3: Load configuration` → `### Step 2: Load configuration`
- `### Step 4: Initialize state` → `### Step 3: Initialize state`
- `### Step 5: Create output directories` → `### Step 4: Create output directories`
- `### Step 6: Announce pipeline start` → `### Step 5: Announce pipeline start`

```bash
# 验证：确认不再有 Step 3/4/5/6 的旧编号
grep -n "^### Step [3-6]:" skills/aide-fix/SKILL.md
# 预期：无结果
```

- [ ] **Step 3: 验证无 aide-core 残留引用**

```bash
grep -n "aide-core" skills/aide-fix/SKILL.md
```

预期输出：无结果（exit code 1）。

- [ ] **Step 4: Commit**

```bash
git add skills/aide-fix/SKILL.md
git commit -m "fix(aide-fix): remove external aide-core/conventions.md reference

Delete Step 2 (Read conventions) — key rules already inlined in SKILL.md.
Renumber subsequent startup steps (3→2, 4→3, 5→4, 6→5).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: 分析步骤去品牌化（Step 1.2.5）

**Files:**
- Modify: `skills/aide-fix/SKILL.md` (Step 1.2.5 区域)

- [ ] **Step 1: 重命名 Step 1.2.5 标题**

Line 249，替换：
```
old_string: ### Step 1.2.5: DeepCode Assisted Analysis (MANDATORY)
new_string: ### Step 1.2.5: Code Analysis (MANDATORY)
```

- [ ] **Step 2: 重写正文首句**

Lines 251，替换：
```
old_string: **Goal**: Augment manual tracing with your native static analysis capabilities. You are running inside deepcode-cli — use its built-in analysis to surface issues manual search may miss (null risks, resource leaks, concurrency bugs, control flow anomalies).
new_string: **Goal**: Augment manual tracing with static analysis. Use your code analysis capabilities to surface issues manual search may miss (null risks, resource leaks, concurrency bugs, control flow anomalies).
```

- [ ] **Step 3: 重命名 findings 子标题**

Line 266，替换：
```
old_string: Record relevant findings in the analyze report under a **DeepCode findings** section. Findings are **advisory** — they inform the diagnosis but do not replace manual tracing. The root cause must still be verified by reading and understanding the code.
new_string: Record relevant findings in the analyze report under a **Code Analysis findings** section. Findings are **advisory** — they inform the diagnosis but do not replace manual tracing. The root cause must still be verified by reading and understanding the code.
```

- [ ] **Step 4: Commit**

```bash
git add skills/aide-fix/SKILL.md
git commit -m "fix(aide-fix): replace DeepCode branding with backend-agnostic Code Analysis

Rename Step 1.2.5 title, body text, and findings section to use
neutral 'Code Analysis' instead of 'DeepCode'/'deepcode-cli'.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: 更新分析阶段输出模板

**Files:**
- Modify: `skills/aide-fix/SKILL.md` (Step 1.5 输出模板区域)

- [ ] **Step 1: 更新 markdown 报告模板**

Line 304，替换：
```
old_string: **DeepCode CLI:** <N> issues found in target area, <M> potentially related to this bug
new_string: **Code Analysis:** <N> issues found in target area, <M> potentially related to this bug
```

- [ ] **Step 2: 更新 JSON schema 字段名**

Line 319，替换：
```
old_string:   "deepcode": {
new_string:   "code_analysis": {
```

- [ ] **Step 3: 更新 Python dict key**

Line 336，替换：
```
old_string:     'deepcode': {'issues_found': 0, 'issues_related': 0},
new_string:     'code_analysis': {'issues_found': 0, 'issues_related': 0},
```

- [ ] **Step 4: Commit**

```bash
git add skills/aide-fix/SKILL.md
git commit -m "fix(aide-fix): rename deepcode JSON field to code_analysis

Update analyze output templates (markdown, JSON schema, Python dict)
to use backend-agnostic 'code_analysis' key.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: 最终验证

**Files:**
- 无文件修改（纯验证）

- [ ] **Step 1: 确认零 deepcode 残留**

```bash
grep -n -i "deepcode" skills/aide-fix/SKILL.md
```

预期输出：无结果（exit code 1）。

- [ ] **Step 2: 确认零 aide-core 残留**

```bash
grep -n "aide-core" skills/aide-fix/SKILL.md
```

预期输出：无结果（exit code 1）。

- [ ] **Step 3: 确认新字段名存在且一致**

```bash
grep -n "code_analysis" skills/aide-fix/SKILL.md
```

预期输出：至少 2 行（JSON 模板行 + Python dict 行），拼写一致。

```bash
grep -n "Code Analysis" skills/aide-fix/SKILL.md
```

预期输出：至少 3 行（Step 1.2.5 标题、正文、markdown 模板），大小写一致。

- [ ] **Step 4: 确认启动步骤编号连续**

```bash
grep -n "^### Step [0-9]" skills/aide-fix/SKILL.md
```

预期输出：Step 0, Step 0.5, Step 1, Step 2, Step 3, Step 4, Step 5（无空洞、无重复）。

- [ ] **Step 5: 确认 MANDATORY 步骤完整**

```bash
grep -c "MANDATORY" skills/aide-fix/SKILL.md
```

预期输出：`2`（Step 0.5: Project context analysis + Step 1.2.5: Code Analysis）。

- [ ] **Step 6: 确认 frontmatter 未变**

```bash
head -8 skills/aide-fix/SKILL.md
```

预期输出：`name: aide-fix` 保持不变。

- [ ] **Step 7: Commit（如有 README 更新）**

如果设计规范要求更新 README Feature Status 表标注 "backend-agnostic"：

```bash
# 编辑 README.md Feature Status 表中 Fix pipeline 行
# "Fix pipeline (`/aide-fix`, analyze→implement→test)" 
# → "Fix pipeline (`/aide-fix`, analyze→implement→test, backend-agnostic)"
git add README.md
git commit -m "docs: mark aide-fix as backend-agnostic in Feature Status

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
