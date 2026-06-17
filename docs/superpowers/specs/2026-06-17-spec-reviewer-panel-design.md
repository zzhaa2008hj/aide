# Spec Reviewer Panel — 多角度对抗性审查

**日期：** 2026-06-17
**状态：** Draft（已通过设计审查，已修订）
**来源：** Brainstorming session — 借鉴 deep-research 方法论优化 AIDE spec 准确性

## 动机

AIDE 当前 spec 阶段由单一 agent 编写 specification，存在**单一视角盲区**：边缘情况、异常路径、安全威胁、性能瓶颈等非核心功能路径容易被遗漏。Spec 是 pipeline 的根基 —— spec 不准确会导致 plan 和 implement 全部跑偏。

Deep-research 的核心方法论中，"多角度分解 + 对抗性验证"已被证明能有效消除单一视角盲区。本设计将这一思想引入 AIDE spec 阶段。

## 设计概览

在 spec 初稿生成之后、gate 之前，插入一个 **Reviewer Panel** 子阶段：3 个独立 agent（各自隔离的上下文）从不同审查镜头审视 spec 初稿，只找遗漏不修改。Spec writer 汇总 gap 后逐条决策（接受/拒绝/提交用户），统一修补 spec。

### 审查流程

```
spec 初稿完成 (.md + .json)
     │
     ├─→ 边界/异常审查员 ──→ gap report      \
     ├─→ 安全审查员     ──→ gap report       |  并行 context-isolated Agent(只读)
     ├─→ 性能/规模审查员 ──→ gap report      /
     │
     ▼
  语义去重 → Spec writer 逐条决策 gap → 修补 spec → 写 review_trail
     │
     ├─ 全部 accepted|rejected → 常规 Gate（展示审查摘要）
     └─ 有 pending gap → Gate 展示待确认项，用户逐个决策 → 补写 review_trail
```

### 核心原则

1. **上下文隔离** — 每个 reviewer 是独立的 context-isolated Agent，互不知道其他 reviewer 的存在和输出，避免锚定效应和上下文污染
2. **只找遗漏，不改写** — reviewer 输出 gap list，修补由 spec writer 统一做
3. **并行执行，可降级** — 3 个 reviewer 同时跑；任一失败不影响其他；通过 `review_trail.status` 明确标记审查完整性
4. **可追溯** — 所有 gap 的处理决策记录在 `review_trail.decisions`，标注决策来源

---

## Reviewer 定义

### 边界/异常审查员 (`edge_case`)

检查维度：
- **边界条件**：极端输入（空值、超长、负数、零值）下的行为是否已定义
- **错误路径**：失败时（网络超时、依赖服务挂、写入失败）的行为是否已描述
- **状态转换**：涉及状态变化的 feature，所有状态转换路径是否完整
- **并发/竞态**：多用户/多进程同时操作同一资源时是否考虑了冲突
- **数据边界**：数量限制、大小限制、频率限制是否已明确

### 安全审查员 (`security`)

检查维度：
- 输入校验完整性（类型、范围、格式、注入防护）
- 认证/授权缺失（未登录可访问、越权操作）
- 敏感数据暴露（日志、错误消息、API 响应中的敏感字段）
- 默认不安全配置（debug 模式、开放端口、弱密码策略）
- 依赖安全（第三方库版本、已知漏洞）

### 性能/规模审查员 (`performance`)

检查维度：
- 大数据量下的行为（无分页列表、全量加载、内存溢出风险）
- N+1 查询风险（循环内数据库调用）
- 缓存策略缺失（热点数据、重复计算）
- 资源消耗（启动初始化、连接池、文件句柄）
- 慢路径识别（同步阻塞、串行化瓶颈）

---

## Gap 输出格式

每个 reviewer 输出统一的 JSON（通过 Agent `schema` 参数强制）：

```json
{
  "lens": "edge_case",
  "gaps": [
    {
      "id": "GAP-001",
      "severity": "critical|warning|info",
      "scope": "F001",
      "category": "boundary",
      "title": "登录失败重试未定义频率限制",
      "description": "F001 定义了登录流程，但未说明连续失败 N 次后是否锁定账户、锁定多久。缺少暴力破解防护。",
      "suggested_ac": "用户连续 5 次登录失败后，账户锁定 15 分钟。"
    }
  ]
}
```

### lens 与 category 对应关系

| lens | 可用 category |
|------|--------------|
| `edge_case` | `boundary`, `error_path`, `state_transition`, `concurrency`, `data_boundary` |
| `security` | `input_validation`, `authentication`, `authorization`, `data_exposure`, `insecure_default`, `dependency` |
| `performance` | `large_data`, `n_plus_one`, `caching`, `resource_consumption`, `slow_path` |

### scope 字段

| scope 值 | 含义 |
|----------|------|
| `"F001"` 等 feature_id | 针对特定 feature 的 gap |
| `"global"` | 跨 feature 或 spec 整体层面的 gap |
| `"missing_feature"` | 缺少一个完整 feature（不属于已有 feature 的范围） |

---

## Gap 决策状态机

Spec writer 对每个 gap 做出以下三种决策之一：

```
gap → spec writer 审查
  ├─ accepted   — 接受建议，修补 spec，追加/修改 AC
  ├─ rejected   — 拒绝建议，记录原因
  └─ pending    — 无法判断，提交 gate 让用户决策
```

### 决策规则

| 条件 | 行为 |
|------|------|
| gap.severity = `info` | spec writer 自动接受（`decision_source: auto`），可批量处理 |
| gap.severity = `warning` | spec writer 逐条判断，accept 或 pending（`decision_source: writer`） |
| gap.severity = `critical` | spec writer 逐条判断，accept / reject / pending（`decision_source: writer`） |
| spec writer 无法判断 | 标记 `pending`（`decision_source: writer`） |

**关键约束：进入 gate 前，每条 gap 都必须有明确决策。不允许"未处理"状态。**

### 已废弃：auto_apply 配置项

原设计中的 `auto_apply` 配置因可能导致 reviewer 建议静默升级为业务需求而被移除。上述决策规则替代此配置。

---

## review_trail Schema

```json
{
  "review_trail": {
    "status": "completed|partial|degraded|disabled",
    "reviewers_ran": ["edge_case", "security"],
    "reviewers_failed": ["performance"],
    "total_gaps_found": 8,
    "gaps_accepted": 5,
    "gaps_rejected": 2,
    "gaps_pending": 1,
    "decisions": [
      {
        "gap_id": "GAP-001",
        "lens": "edge_case",
        "severity": "critical",
        "scope": "F001",
        "decision": "pending",
        "decision_source": "writer",
        "reason": null
      },
      {
        "gap_id": "GAP-002",
        "lens": "security",
        "severity": "warning",
        "scope": "F001",
        "decision": "accepted",
        "decision_source": "writer",
        "new_ac_index": 3
      },
      {
        "gap_id": "GAP-003",
        "lens": "edge_case",
        "severity": "info",
        "scope": "F002",
        "decision": "accepted",
        "decision_source": "auto",
        "new_ac_index": 5
      },
      {
        "gap_id": "GAP-004",
        "lens": "performance",
        "severity": "warning",
        "scope": "F001",
        "title": "建议对列表接口增加 Redis 缓存层",
        "decision": "rejected",
        "decision_source": "writer",
        "reason": "当前用户量 < 100，缓存层引入不必要的复杂性"
      }
    ]
  }
}
```

### status 取值

| status | 条件 | 对 confidence 的影响 |
|--------|------|---------------------|
| `completed` | 全部 reviewer 成功，gap 全部决策完成 | 正常计算 |
| `partial` | 部分 reviewer 失败但仍满足 `min_reviewers`，或审查流程正常但部分 feature 未被覆盖 | 失败 reviewer 的 lens 不计入 |
| `degraded` | `min_reviewers` 不满足，审查被跳过 | 所有 feature 标记 `unreviewed` |
| `disabled` | `review_panel.enabled: false` | 所有 feature 标记 `unreviewed` |

### decision_source 取值

| 值 | 含义 |
|----|------|
| `auto` | info 级别自动接受 |
| `writer` | spec writer 做出的决策 |
| `user` | 用户在 gate 中确认的决策 |

---

## features[].confidence 计算规则

| 条件 | confidence |
|------|-----------|
| review_trail.status ∈ {degraded, disabled} | `unreviewed` |
| feature 未被任何 successful reviewer 的 gap 覆盖 | `unreviewed` |
| feature 收到 ≥1 个 critical gap（accepted 或 pending） | `low` |
| feature 收到 warning gap，已全部 accepted | `medium` |
| feature 收到 warning gap，有 pending 项 | `low` |
| feature 仅收到 info gap 或无任何 gap | `high` |

---

## 配置

### .aide/config.yaml

```yaml
stages:
  spec:
    enabled: true
    gates:
      - name: after_spec
        type: confirm
        prompt: "Review the spec at .aide/output/1-spec/. Does this look right? (y/n)"
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

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `enabled` | `true` | 关闭后 `status: disabled`，回退原 spec 流程 |
| `reviewers[].enabled` | `true` | 可单独禁用某个镜头 |
| `reviewers[].max_gaps` | 8/5/5 | 单个 reviewer 产出上限，防泛滥 |
| `min_reviewers` | `2` | 最少成功 reviewer 数，低于此值 → `status: degraded` |

### 降级策略

| 场景 | 行为 | status |
|------|------|--------|
| `min_reviewers` 不满足 | 跳过审查，**gate prompt 中明确告知**"spec 未通过 reviewer panel 审查" | `degraded` |
| 单个 reviewer 超时/崩溃 | 标记 `reviewers_failed`，其他结果正常使用 | `partial` |
| 合并后 0 个 gap | 正常通过，confidence 全部 `high` | `completed` |
| `review_panel.enabled: false` | 完全跳过审查 | `disabled` |

### Gate 增强

当 `review_panel.enabled: true` 时，gate prompt 追加审查摘要：

```
## Spec Review Summary

Review status: completed  |  3 reviewers ran, 0 failed
Gaps found: 12  |  Accepted: 10  |  Rejected: 1  |  Pending: 1

Confidence: F001=high, F002=medium, F003=low

[仅当 gaps_pending > 0]
The following critical gaps need your decision:

  [GAP-007] (security/critical) F003 缺少 API 认证机制
    Suggested: 所有 /api/* 端点需 JWT Bearer token 验证
    Accept? (y/n)

  [GAP-012] (edge_case/warning) F001 未定义并发编辑冲突策略
    Suggested: 采用乐观锁 (version 字段)
    Accept? (y/n)

After deciding, the spec will be regenerated.
```

用户对每个 pending gap 回复 y/n 后：
- accepted → `decision: accepted`, `decision_source: user`
- rejected → `decision: rejected`, `decision_source: user`（需提供 reason）
- 补写 `review_trail`，重新生成 spec，再次经过常规 gate confirm

---

## 实现涉及文件

```
aide-core/schemas/spec.schema.json       — 新增 review_trail、confidence 字段
skills/aide-spec/SKILL.md               — 核心改动：Step 3.5 Review Panel 流程
skills/aide/SKILL.md                    — spec gate 增加审查摘要 + pending gap 交互
skills/aide-deepcode/SKILL.md           — deepcode-cli 入口，对齐审查流程
skills/aide-codewhale/SKILL.md          — CodeWhale 入口，对齐审查流程
templates/aide.config.yaml              — 默认模板增加 review_panel 配置块
README.md                               — Feature Status 更新
```

### 兼容性要求（CLAUDE.md 强制）

- **deepcode-cli（首要）**：`skills/aide-deepcode/SKILL.md` 必须包含 Reviewer Panel 子阶段，或以 delegate-to-skill 方式复用 `aide-spec`
- **CodeWhale**：`skills/aide-codewhale/SKILL.md` 同步更新，保持三个入口行为一致
- **不破坏现有集成**：`review_panel.enabled: false` 时行为与原流程完全一致

### Agent 隔离说明

Reviewer agent 只读取 spec 文件，不写入任何文件。隔离的关键需求是**上下文隔离**（互不感知），而非文件系统隔离。使用 Agent 工具默认行为即可满足 —— 每个 Agent 调用获得独立的上下文窗口。若未来 deepcode-cli 路径需要更强的沙箱隔离，再引入 worktree 作为可选实现。

---

## 不在范围

- Plan 阶段的 reviewer panel（后续推广）
- Implement 阶段的对抗性验证增强（后续推广）
- `confidence` 自动计算中的跨 reviewer 交叉验证（本期仅按规则表赋值）
- Reviewer prompt 的自动调优（本期硬编码镜头定义）

## 演进路线

```
Phase 1 (本期): Spec Reviewer Panel
      │
      ▼
Phase 2: Plan Reviewer Panel — 审查任务分解是否遗漏、依赖是否正确
      │
      ▼
Phase 3: Full Adversarial Pipeline — deep-research 五阶段完整镜像
         (分解→并行探索→声明提取→对抗验证→置信度合成)
```
