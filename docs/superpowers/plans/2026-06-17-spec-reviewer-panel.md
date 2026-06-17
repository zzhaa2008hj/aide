# Spec Reviewer Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 AIDE spec 阶段插入多角度 Reviewer Panel（边界/安全/性能），借鉴 deep-research 的对抗性验证方法论提升 spec 准确性。

**Architecture:** 在 aide-spec 流程中新增 Step 3.5，spec 初稿完成后并行拉起 3 个 context-isolated Agent（每个带不同的审查镜头），收集 gap reports 后由 spec writer 逐条决策（accept/reject/pending），修补 spec 后写 review_trail。Orchestrator gate 展示审查摘要，有 pending gap 时交互式确认。

**Tech Stack:** YAML/Markdown（SKILL.md 指令文件）、JSON Schema（spec.schema.json）、Agent tool（context-isolated subagent）

---

## File Structure

| 文件 | 职责 | 改动类型 |
|------|------|---------|
| `aide-core/schemas/spec.schema.json` | spec.json 的数据契约：新增 review_trail + confidence | Modify |
| `skills/aide-spec/SKILL.md` | spec 阶段核心流程：插入 Step 3.5 Review Panel | Modify |
| `skills/aide/SKILL.md` | CC orchestrator：gate 展示审查摘要 + pending gap 交互 | Modify |
| `skills/aide-deepcode/SKILL.md` | deepcode-cli orchestrator：spec gate 对齐 CC 行为 | Modify |
| `skills/aide-codewhale/SKILL.md` | CodeWhale orchestrator：spec gate 对齐 CC 行为 | Modify |
| `templates/aide.config.yaml` | 默认配置模板：新增 review_panel 配置块 | Modify |
| `README.md` | Feature Status 更新 + Project Structure 更新 | Modify |

---

### Task 1: spec.schema.json — 新增 review_trail 和 confidence 字段

**Files:**
- Modify: `aide-core/schemas/spec.schema.json`

- [ ] **Step 1: 在 features items 中新增 confidence 字段**

在 `features.items.properties` 中，`acceptance_criteria` 之后添加 `confidence`：

```json
"confidence": {
  "type": "string",
  "enum": ["high", "medium", "low", "unreviewed"],
  "description": "Confidence level for this feature after review panel assessment. 'unreviewed' when review_panel is disabled or degraded."
}
```

同时将 features items 的 `required` 保持不变（`["id", "title", "description", "acceptance_criteria"]`），confidence 是可选的。

- [ ] **Step 2: 移除 features items 的 additionalProperties: false，改为显式列出允许属性**

因为新增了 confidence，原来的 `"additionalProperties": false` 会拒绝它。改为不设置 additionalProperties（或设为 false 但确保 confidence 在 properties 中）。由于已显式添加 confidence 到 properties，保留 `"additionalProperties": false` 即可——confidence 已在 properties 中声明。

- [ ] **Step 3: 在顶层 properties 中新增 review_trail 字段**

在 `scope_boundary` 之后添加：

```json
"review_trail": {
  "type": "object",
  "description": "Review panel audit trail. Present only when review_panel ran.",
  "required": ["status", "reviewers_ran", "reviewers_failed", "total_gaps_found", "gaps_accepted", "gaps_rejected", "gaps_pending", "decisions"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["completed", "partial", "degraded", "disabled"],
      "description": "Review completeness status."
    },
    "reviewers_ran": {
      "type": "array",
      "items": { "type": "string" },
      "description": "IDs of reviewers that completed successfully."
    },
    "reviewers_failed": {
      "type": "array",
      "items": { "type": "string" },
      "description": "IDs of reviewers that failed or timed out."
    },
    "total_gaps_found": {
      "type": "integer",
      "minimum": 0,
      "description": "Total unique gaps found across all reviewers (after dedup)."
    },
    "gaps_accepted": {
      "type": "integer",
      "minimum": 0,
      "description": "Number of gaps accepted and applied to spec."
    },
    "gaps_rejected": {
      "type": "integer",
      "minimum": 0,
      "description": "Number of gaps rejected with reason."
    },
    "gaps_pending": {
      "type": "integer",
      "minimum": 0,
      "description": "Number of gaps deferred to user decision in gate."
    },
    "decisions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["gap_id", "lens", "severity", "scope", "decision", "decision_source"],
        "properties": {
          "gap_id": { "type": "string", "pattern": "^GAP-\\d{3}$" },
          "lens": { "type": "string", "enum": ["edge_case", "security", "performance"] },
          "severity": { "type": "string", "enum": ["critical", "warning", "info"] },
          "scope": { "type": "string" },
          "title": { "type": "string" },
          "decision": { "type": "string", "enum": ["accepted", "rejected", "pending"] },
          "decision_source": { "type": "string", "enum": ["auto", "writer", "user"] },
          "reason": { "type": "string" },
          "new_ac_index": { "type": "integer", "minimum": 0 }
        },
        "additionalProperties": false
      }
    }
  },
  "additionalProperties": false
}
```

- [ ] **Step 4: 更新顶层 required 和 additionalProperties**

顶层 `required` 保持 `["schema_version", "features", "constraints", "scope_boundary"]`——review_trail 是可选的（review_panel 未运行时不存在）。

顶层 `additionalProperties` 需要允许 review_trail。当前是 `"additionalProperties": false`，需要改为显式列出 review_trail。由于 review_trail 已添加到 properties，`additionalProperties: false` 已允许它——无需更改。

- [ ] **Step 5: 验证 schema 自身合法性**

```bash
python3 -c "
import json
with open('aide-core/schemas/spec.schema.json') as f:
    schema = json.load(f)
# Validate it's valid JSON and has expected structure
assert 'review_trail' in schema['properties'], 'review_trail missing'
assert 'confidence' in schema['properties']['features']['items']['properties'], 'confidence missing'
print('Schema structure OK')
"
```

Expected: `Schema structure OK`

- [ ] **Step 6: Commit**

```bash
git add aide-core/schemas/spec.schema.json
git commit -m "feat(schema): add review_trail and confidence fields to spec schema

- features[].confidence: high|medium|low|unreviewed
- review_trail: full audit trail with status, decisions, decision_source"
```

---

### Task 2: templates/aide.config.yaml — 新增 review_panel 配置块

**Files:**
- Modify: `templates/aide.config.yaml`

- [ ] **Step 1: 在 stages.spec 下新增 review_panel 配置**

在 `stages.spec.gates` 和 `stages.plan` 之间插入：

```yaml
    review_panel:
      enabled: true
      reviewers:
        - id: edge_case
          enabled: true
          max_gaps: 8
        - id: security
          enabled: true
          max_gaps: 5
        - id: performance
          enabled: true
          max_gaps: 5
      min_reviewers: 2
```

最终 spec 段应为：

```yaml
stages:
  spec:
    enabled: true
    gates:
      - name: after_spec
        type: confirm
        prompt: "Review the spec at .aide/output/1-spec/spec.md. Does this look right? (y/n)"
    review_panel:
      enabled: true
      reviewers:
        - id: edge_case
          enabled: true
          max_gaps: 8
        - id: security
          enabled: true
          max_gaps: 5
        - id: performance
          enabled: true
          max_gaps: 5
      min_reviewers: 2
```

- [ ] **Step 2: Commit**

```bash
git add templates/aide.config.yaml
git commit -m "feat(config): add review_panel configuration block to spec stage"
```

---

### Task 3: skills/aide-spec/SKILL.md — 核心：插入 Step 3.5 Review Panel 流程

**Files:**
- Modify: `skills/aide-spec/SKILL.md`

这是最核心的改动。当前 SKILL.md 流程是：Step 1 分析 → Step 2 澄清 → Step 3 生成初稿 → 验证 → 报告。需要在 Step 3 和验证之间插入 Step 3.5。

- [ ] **Step 1: 在 Step 3 "Draft Specification" 末尾添加过渡说明**

在 Step 3 的末尾（Output 小节之后、"## Validation" 之前）添加：

```markdown
### Step 3.5: Reviewer Panel (MANDATORY when review_panel.enabled is true)

**Goal**: Eliminate single-perspective blind spots by having 3 independent, context-isolated reviewers audit the spec draft from different lenses (edge cases, security, performance). Each reviewer only sees the spec draft + project context — they do NOT see each other's output.

This step is inspired by deep-research's adversarial verification methodology.

#### 3.5.1 Read configuration

Read `.aide/config.yaml` and check `stages.spec.review_panel.enabled`:
- If `false` or missing: skip Step 3.5 entirely. Set `review_trail.status = "disabled"` in spec.json. Proceed to Validation.
- If `true`: continue to 3.5.2.

#### 3.5.2 Prepare reviewer inputs

Build the shared context block that all 3 reviewers receive:

```
## 项目背景
<Project context summary from Step 0.2: tech stack, directory structure, key conventions>

## Spec 初稿
<Full spec.md content>

## Spec JSON
<Full spec.json content>

## 你的任务
找出这份 spec 中**遗漏的**场景、条件、约束和验收标准。只找缺失项，不重复已有内容，不修改 spec。
```

Build the 3 lens-specific prompts. Each lens definition follows the table below. The reviewer agent must be instructed to output ONLY a JSON object conforming to the gap report schema.

**Lens: edge_case**
```
## 审查镜头：边界情况与异常路径

从以下维度审视 spec，只关注**缺失的**内容：

1. **边界条件**：极端输入（空值、超长、负数、零值）下的行为是否已定义
2. **错误路径**：失败时（网络超时、依赖服务挂、写入失败）的行为是否已描述
3. **状态转换**：涉及状态变化的 feature，所有状态转换路径是否完整
4. **并发/竞态**：多用户/多进程同时操作同一资源时是否考虑了冲突
5. **数据边界**：数量限制、大小限制、频率限制是否已明确

输出格式：
{
  "lens": "edge_case",
  "gaps": [
    {
      "id": "GAP-001",
      "severity": "critical|warning|info",
      "scope": "F001 或 global 或 missing_feature",
      "category": "boundary|error_path|state_transition|concurrency|data_boundary",
      "title": "简短标题",
      "description": "详细说明遗漏了什么、为什么重要",
      "suggested_ac": "建议的验收标准（一句话）"
    }
  ]
}

最多输出 8 个 gap。按严重度排序（critical 在前）。宁缺毋滥——真正重要的才报。
```

**Lens: security**
```
## 审查镜头：安全

从以下维度审视 spec，只关注**缺失的**内容：

1. **输入校验**：类型、范围、格式、注入防护是否已定义
2. **认证/授权**：未登录可访问、越权操作是否已有防护
3. **敏感数据暴露**：日志、错误消息、API 响应中的敏感字段是否已考虑
4. **默认不安全配置**：debug 模式、开放端口、弱密码策略是否已提及
5. **依赖安全**：第三方库版本、已知漏洞是否有关注

输出格式：
{
  "lens": "security",
  "gaps": [
    {
      "id": "GAP-001",
      "severity": "critical|warning|info",
      "scope": "F001 或 global 或 missing_feature",
      "category": "input_validation|authentication|authorization|data_exposure|insecure_default|dependency",
      "title": "简短标题",
      "description": "详细说明遗漏了什么、为什么重要",
      "suggested_ac": "建议的验收标准（一句话）"
    }
  ]
}

最多输出 5 个 gap。按严重度排序（critical 在前）。宁缺毋滥。
```

**Lens: performance**
```
## 审查镜头：性能与规模

从以下维度审视 spec，只关注**缺失的**内容：

1. **大数据量**：无分页列表、全量加载、内存溢出风险是否已考虑
2. **N+1 查询**：循环内数据库调用是否已有防护
3. **缓存策略**：热点数据、重复计算是否已有缓存考虑
4. **资源消耗**：启动初始化、连接池、文件句柄是否已关注
5. **慢路径**：同步阻塞、串行化瓶颈是否已识别

输出格式：
{
  "lens": "performance",
  "gaps": [
    {
      "id": "GAP-001",
      "severity": "critical|warning|info",
      "scope": "F001 或 global 或 missing_feature",
      "category": "large_data|n_plus_one|caching|resource_consumption|slow_path",
      "title": "简短标题",
      "description": "详细说明遗漏了什么、为什么重要",
      "suggested_ac": "建议的验收标准（一句话）"
    }
  ]
}

最多输出 5 个 gap。按严重度排序（critical 在前）。宁缺毋滥。
```

#### 3.5.3 Dispatch reviewers in parallel

Use the Agent tool to dispatch 3 context-isolated agents simultaneously. Each agent receives:
- The shared context block
- One lens-specific prompt
- The gap report output schema (via Agent `schema` parameter)

**Isolation**: Each Agent call is a separate invocation — agents do NOT share context and cannot see each other's output. This is the default Agent behavior (fresh context per call).

**Timeout**: Each reviewer has a 60s implicit timeout. If an agent fails or times out, mark it in `reviewers_failed`.

**Output collection**: Each reviewer returns a validated JSON object (enforced by the `schema` parameter). Collect all 3 results.

#### 3.5.4 Check min_reviewers

Count successful reviewers (those that returned valid output). If count < `min_reviewers` (from config, default 2):
- Set `review_trail.status = "degraded"`
- Set all features' `confidence = "unreviewed"`
- Write review_trail with `reviewers_ran` and `reviewers_failed`
- Report: "Review panel degraded: only N/M reviewers succeeded. Skipping review. Spec confidence: unreviewed."
- Proceed to Validation (skip 3.5.5–3.5.8).

#### 3.5.5 Merge and deduplicate gaps

Collect all gaps from all successful reviewers into a single list.

Deduplicate by semantic similarity: if two gaps from different reviewers describe essentially the same omission, merge them into one entry. Record all source lenses in a `sources` note (not in output — informational for the spec writer).

Sort merged gaps by severity: critical → warning → info.

Set `review_trail.status = "completed"` if all 3 reviewers succeeded, `"partial"` otherwise.

#### 3.5.6 Process each gap — spec writer decisions

For each gap in the merged list (sorted by severity):

**If gap.severity == "info"**:
- Auto-accept. Append `suggested_ac` to the target feature's `acceptance_criteria` array (if `scope` is a feature_id). For `scope: global`, add to `constraints`. For `scope: missing_feature`, note as a potential new feature but do NOT auto-create it — flag for gate.
- Record: `decision: "accepted"`, `decision_source: "auto"`, `new_ac_index: <index>`.

**If gap.severity == "warning"**:
- Evaluate the gap. Decide: accept or pending.
- If accepted: same as above, but `decision_source: "writer"`.
- If pending: `decision: "pending"`, `decision_source: "writer"`. Do NOT modify spec yet.
- Warning gaps should NOT be rejected unless factually wrong — the reviewer is flagging real risks.

**If gap.severity == "critical"**:
- Evaluate the gap. Decide: accept, reject, or pending.
- If accepted: apply to spec, `decision_source: "writer"`.
- If rejected: record `reason`, `decision_source: "writer"`.
- If pending: `decision: "pending"`, `decision_source: "writer"`.

**Constraint**: After processing all gaps, every gap must have one of {accepted, rejected, pending}. No gap may be left undecided.

#### 3.5.7 Update spec files with applied gaps

For all accepted gaps:
- If `scope` is a feature_id (e.g., "F001"): append `suggested_ac` to that feature's `acceptance_criteria` array
- If `scope` is "global": append `suggested_ac` to `constraints` array

Update `spec.md` to reflect the same additions (append new AC bullets to corresponding feature sections, add new constraints).

#### 3.5.8 Compute confidence per feature

For each feature in spec.json:

| Condition | confidence |
|-----------|-----------|
| review_trail.status ∈ {degraded, disabled} | `unreviewed` |
| No gap from any successful reviewer references this feature | `unreviewed` |
| Feature has ≥1 critical gap (accepted or pending) | `low` |
| Feature has warning gap(s), any pending | `low` |
| Feature has warning gap(s), all accepted | `medium` |
| Feature has only info gaps or zero gaps | `high` |

#### 3.5.9 Write review_trail

Construct the `review_trail` object and add it to spec.json. Use the format defined in the schema (Task 1).

#### 3.5.10 Report summary

```
## Reviewer Panel Complete

Status: completed  |  3/3 reviewers succeeded
Gaps: 8 found → 5 accepted, 2 rejected, 1 pending

Confidence: F001=high, F002=medium, F003=low

Pending gaps will be shown for your decision at the gate.
```
```

- [ ] **Step 2: 更新 Validation 步骤**

在原有的 Step 0（确定文件名）之后、原有的 "## Validation" 之前，确认 Step 3 和 Step 3.5 的内容已按顺序排列。原来的流程是：

```
Step 1: Analyze
Step 2: Clarify Ambiguity
Step 3: Draft Specification
## Output (Step 0: Determine filename, 1: spec.md, 2: spec.json)
## Validation
## Completion Report
```

新流程应为：

```
Step 1: Analyze
Step 2: Clarify Ambiguity
Step 3: Draft Specification
## Output (Step 0: Determine filename, 1: spec.md, 2: spec.json)
### Step 3.5: Reviewer Panel   ← 新插入
## Validation                  ← 保持不变
## Completion Report           ← 保持不变
```

- [ ] **Step 3: 更新 Completion Report**

在 Completion Report 中增加审查摘要行。在原有的报告内容末尾添加：

```markdown
- Review Panel status and gap summary (if enabled)
```

即报告变为：
```markdown
- Number of features defined
- Number of constraints listed
- Scope boundary summary
- Brief mention of any notable clarifications made during the ambiguity step
- Review Panel: N gaps found, M applied, K pending (if review_panel enabled)
```

- [ ] **Step 4: Commit**

```bash
git add skills/aide-spec/SKILL.md
git commit -m "feat(aide-spec): add Step 3.5 Reviewer Panel with 3-lens adversarial review

- 3 context-isolated reviewer agents (edge_case, security, performance)
- Gap dedup, severity-sorted processing
- Auto-accept info, writer-decide warning/critical
- review_trail with decision_source tracking
- Per-feature confidence scoring
- Degraded mode when min_reviewers not met"
```

---

### Task 4: skills/aide/SKILL.md — Gate 增强 + pending gap 交互

**Files:**
- Modify: `skills/aide/SKILL.md`

- [ ] **Step 1: 在 spec gate 段落中新增 review_trail 检查**

在 `## Stage 1: spec` → `### Gate` 部分，在原有的 gate type 判断之前，插入 review_panel 摘要检查。

找到 Gate 段落的开头（在 `### Gate` 标题之后、"Read the gate config" 之前），插入：

```markdown
### Gate

**If `review_panel.enabled` is true in config**: Read `review_trail` from the spec JSON output.

1. **Display review summary** regardless of gate type:

```
## Spec Review Summary

Review status: <review_trail.status>  |  <N> reviewers ran, <M> failed
Gaps found: <total>  |  Accepted: <accepted>  |  Rejected: <rejected>  |  Pending: <pending>

Confidence: F001=<confidence>, F002=<confidence>, ...
```

2. **If gaps_pending > 0**: Present pending gaps for user decision BEFORE the normal gate prompt.

Use AskUserQuestion (one per pending gap, or batch if only 1-2):

```
Question: "Spec review found a gap. Accept the suggested fix?"
Header: "Spec Gap"
Options:
  - "y: Accept — add to spec (Recommended)"
  - "n: Reject — skip this suggestion"
```

After the user decides on ALL pending gaps:
- For accepted: set `decision: "accepted"`, `decision_source: "user"`, apply to spec
- For rejected: set `decision: "rejected"`, `decision_source: "user"`, ask for brief reason
- Update review_trail counts and decisions
- Regenerate spec.md + spec.json with applied changes
- Re-run schema validation

3. **If gaps_pending == 0** or after all pending gaps are resolved: proceed to the normal gate flow below.
```

然后保持原有的 gate type 判断逻辑不变（confirm/confirm_skip/auto）。

- [ ] **Step 2: 更新默认配置中的 review_panel**

在 `### Step 4: Load configuration` 段落的默认配置中（当 `.aide/config.yaml` 不存在时使用的硬编码默认值），spec 段增加 `review_panel`:

```yaml
  spec:
    enabled: true
    gates:
      - name: after_spec
        type: confirm
        prompt: "Review the spec at .aide/output/1-spec/spec.md. Does this look right? (y/n)"
    review_panel:          # ← 新增
      enabled: true         # ← 新增
      reviewers:            # ← 新增
        - id: edge_case     # ← 新增
          enabled: true     # ← 新增
          max_gaps: 8       # ← 新增
        - id: security      # ← 新增
          enabled: true     # ← 新增
          max_gaps: 5       # ← 新增
        - id: performance   # ← 新增
          enabled: true     # ← 新增
          max_gaps: 5       # ← 新增
      min_reviewers: 2      # ← 新增
```

- [ ] **Step 3: 在 spec gate confirm 选项中增加审查摘要引用**

对于 confirm 和 confirm_skip 的 gate prompt，在 Question 文本中引用审查摘要。将：

```
Question: "Review the spec at .aide/output/1-spec/. Does this look right?"
```

改为：

```
Question: "Review the spec. <gaps_found> gaps found, <gaps_pending> pending your decision. Does this look right?"
```

（如果 review_panel 未启用，回退到原始措辞。）

- [ ] **Step 4: Commit**

```bash
git add skills/aide/SKILL.md
git commit -m "feat(aide): add review panel summary to spec gate with pending gap resolution

- Gate displays review_trail summary (status, gaps, confidence)
- Interactive pending gap resolution before gate confirm
- Default config includes review_panel block
- Backward compatible: no review_panel → original gate behavior"
```

---

### Task 5: skills/aide-deepcode/SKILL.md — deepcode-cli 入口对齐

**Files:**
- Modify: `skills/aide-deepcode/SKILL.md`

deepcode-cli 的 orchestrator 是自包含的（内联所有规则），Spec gate 部分需要对齐 CC 版本的审查摘要行为。

- [ ] **Step 1: 在 Stage 1 spec gate 段落增加 review_trail 检查**

在 `## Stage 1: spec` → gate 处理部分（约第 167-193 行），在 gate 判断逻辑之前插入审查摘要展示。

deepcode-cli orchestrator 的 gate 流程较 CC 版本更内联（不引用外部 gate.md），行为应一致。插入内容与 Task 4 Step 1 相同（适配 deepcode-cli 的 gate 段落结构）。

在 `### Gate` 部分开头（"Read the gate config for `after_spec`" 之前）插入相同的 review_trail 检查逻辑。

- [ ] **Step 2: 同步默认配置中的 review_panel**

检查 Stage 0.6 中的硬编码默认配置是否包含 `review_panel`。如果不包含，添加与 Task 4 Step 2 相同的 review_panel 块。

- [ ] **Step 3: Commit**

```bash
git add skills/aide-deepcode/SKILL.md
git commit -m "feat(aide-deepcode): align spec gate with review panel summary display

Mirrors CC orchestrator behavior: review_trail summary + pending gap resolution.
Maintains deepcode-cli as primary compatibility target per CLAUDE.md."
```

---

### Task 6: skills/aide-codewhale/SKILL.md — CodeWhale 入口对齐

**Files:**
- Modify: `skills/aide-codewhale/SKILL.md`

CodeWhale orchestrator 也是自包含的。Spec gate 需要展示审查摘要。CodeWhale 使用 checklist_write 追踪进度。

- [ ] **Step 1: 在 Stage 1 spec gate 段落增加 review_trail 检查**

在 `## Stage 1: spec` → `### Gate` 段落（约第 254-256 行），当前只有一行 "Process the `after_spec` gate per the loaded configuration."。

在此处插入审查摘要展示逻辑。CodeWhale 没有 AskUserQuestion 工具，改用其内置的交互方式（参考 CodeWhale 源码确认）。

实质内容与 Task 4 Step 1 相同——展示审查摘要、处理 pending gap、然后进入正常 gate 流程。

- [ ] **Step 2: 同步默认配置中的 review_panel**

检查 Stage 0.6 中的默认配置（约第 143-170 行）。如果不包含 review_panel，添加与 Task 4 Step 2 相同的块。

- [ ] **Step 3: Commit**

```bash
git add skills/aide-codewhale/SKILL.md
git commit -m "feat(aide-codewhale): align spec gate with review panel summary display

Mirrors CC/deepcode-cli behavior. Maintains CodeWhale compatibility per CLAUDE.md."
```

---

### Task 7: README.md — Feature Status + Project Structure 更新

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 在 Feature Status → Done 表格中新增条目**

在 Done 表格末尾（CodeWhale orchestrator 之后）添加：

```markdown
| Spec Reviewer Panel (3-lens adversarial review) | Done |
```

- [ ] **Step 2: 在 Project Structure 中更新 aide-spec 描述**

将：
```
│   ├── aide-spec/                     # Stage 1: Requirements → Spec
```

更新为：
```
│   ├── aide-spec/                     # Stage 1: Requirements → Spec (+ Reviewer Panel)
```

- [ ] **Step 3: 在 Pipeline 表格中更新 spec 行描述**

将 Pipeline 表格中 spec 的描述从 `Requirements → Specification` 更新为 `Requirements → Specification (+ adversarial review)`。

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): add Spec Reviewer Panel to Feature Status and Project Structure"
```

---

## Execution Order

```
Task 1 (schema)  ──┐
                   ├──→ Task 3 (aide-spec) ──→ Task 4 (aide) ──┬──→ Task 5 (aide-deepcode)
Task 2 (config)  ──┘                                           └──→ Task 6 (aide-codewhale)
                                                                     │
                                                                     ▼
                                                                Task 7 (README)
```

Tasks 1-2 无依赖可并行。Task 3 依赖 1-2 了解 schema 和配置结构。Task 4 依赖 3 了解审查流程。Tasks 5-6 依赖 4 了解 gate 行为。Task 7 最后。
