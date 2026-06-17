# Spec Reviewer Panel — 多角度对抗性审查

**日期：** 2026-06-17
**状态：** Draft
**来源：** Brainstorming session — 借鉴 deep-research 方法论优化 AIDE spec 准确性

## 动机

AIDE 当前 spec 阶段由单一 agent 编写 specification，存在**单一视角盲区**：边缘情况、异常路径、安全威胁、性能瓶颈等非核心功能路径容易被遗漏。Spec 是 pipeline 的根基 —— spec 不准确会导致 plan 和 implement 全部跑偏。

Deep-research 的核心方法论中，"多角度分解 + 对抗性验证"已被证明能有效消除单一视角盲区。本设计将这一思想引入 AIDE spec 阶段。

## 设计概览

在 spec 初稿生成之后、gate 之前，插入一个 **Reviewer Panel** 子阶段：3 个独立 agent（各自隔离的上下文）从不同审查镜头审视 spec 初稿，只找遗漏不修改。Spec writer 汇总 gap 后统一修补 spec。

### 审查流程

```
spec 初稿完成 (.md + .json)
     │
     ├─→ 边界/异常审查员 ──→ gap report      \
     ├─→ 安全审查员     ──→ gap report       |  并行 Agent(isolation="worktree")
     ├─→ 性能/规模审查员 ──→ gap report      /
     │
     ▼
  语义去重 → Spec writer 逐条处理 gap → 修补 spec → 写 review_trail → Schema 验证 → Gate
```

### 核心原则

1. **上下文隔离** — 每个 reviewer 是独立 Agent（`isolation: "worktree"`），互不知道其他 reviewer 的存在和输出，避免锚定效应和上下文污染
2. **只找遗漏，不改写** — reviewer 输出 gap list，修补由 spec writer 统一做
3. **并行执行，可降级** — 3 个 reviewer 同时跑；任一失败不影响其他；总数不足 `min_reviewers` 时降级为跳过审查
4. **可追溯** — 所有 gap 的处理决策记录在 `review_trail` 中

## Reviewer 定义

### 边界/异常审查员 (`edge_case`)

检查维度：
- **边界条件**：极端输入（空值、超长、负数、零值、并发）下的行为是否已定义
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

## Gap 输出格式

每个 reviewer 输出统一的 JSON（通过 `schema` 参数强制）：

```json
{
  "reviewer": "edge_case",
  "gaps": [
    {
      "id": "GAP-001",
      "severity": "critical|warning|info",
      "feature_id": "F001",
      "category": "boundary|error_path|state|concurrency|data_boundary",
      "title": "登录失败重试未定义频率限制",
      "description": "F001 定义了登录流程，但未说明连续失败 N 次后是否锁定账户、锁定多久。缺少暴力破解防护。",
      "suggested_ac": "用户连续 5 次登录失败后，账户锁定 15 分钟。"
    }
  ]
}
```

## 合并与处理规则

### 语义去重

标题和描述高度相似的 gap 合并为一条（由 spec writer 进行语义判断，标注来自哪些 reviewer，如 `["edge_case", "security"]`）。

### 严重度排序

处理顺序：critical → warning → info。critical gap 必须处理（接受或明确拒绝并记录原因）。

### 自动应用

配置项 `auto_apply` 控制：warning 及以下级别自动接受（直接追加 AC），critical 保留在 gate 中展示。

### 拒绝记录

Spec writer 拒绝某个 gap 时必须记录原因，写入 `review_trail.decisions`。

## 配置

### .aide/config.yaml

```yaml
stages:
  spec:
    enabled: true
    gates:
      - name: after_spec
        type: confirm
        prompt: "Review the spec. Does this look right? (y/n)"
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
      auto_apply: warning
      min_reviewers: 2
```

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `enabled` | `true` | 关闭后回退到原 spec 流程 |
| `reviewers[].enabled` | `true` | 可单独禁用某个镜头 |
| `reviewers[].max_gaps` | 8/5/5 | 单个 reviewer 产出上限，防泛滥 |
| `auto_apply` | `warning` | critical 需 gate 确认；warning/info 自动应用 |
| `min_reviewers` | `2` | 最少成功 reviewer 数，低于此值降级跳过 |

### 降级策略

| 场景 | 行为 |
|------|------|
| `min_reviewers` 不满足 | 跳过审查，`review_trail` 标注 `degraded` |
| 单个 reviewer 超时/崩溃 | 标记 `failed`，其他结果正常使用 |
| 合并后 0 个 gap | 正常通过，记录 `total_gaps_found: 0` |

## spec.json Schema 变更

在现有 spec.schema.json 基础上新增两个字段：

### features[].confidence

```json
{
  "confidence": "high|medium|low|unreviewed"
}
```

标记每个 feature 的置信度。Reviewer panel 运行后，若某个 feature 未收到任何 gap，标记为 `high`；收到 warning 及以下级别的 gap 并已修补，标记为 `medium`；收到 critical gap，标记为 `low`。

### review_trail

```json
{
  "review_trail": {
    "reviewers_ran": ["edge_case", "security", "performance"],
    "reviewers_failed": [],
    "total_gaps_found": 12,
    "gaps_applied": 10,
    "gaps_rejected": 2,
    "decisions": [
      {
        "gap_id": "GAP-001",
        "reviewer": "edge_case",
        "decision": "accepted",
        "new_ac_index": 3
      },
      {
        "gap_id": "GAP-005",
        "reviewer": "performance",
        "decision": "rejected",
        "reason": "不适用于当前项目规模，目标用户 < 100"
      }
    ]
  }
}
```

## 实现涉及文件

```
aide-core/schemas/spec.schema.json    — 新增 review_trail、confidence 字段
skills/aide-spec/SKILL.md            — 核心改动：Step 3.5 Review Panel 流程
skills/aide/SKILL.md                 — spec 阶段输出验证增加 review_trail 检查
templates/aide.config.yaml           — 默认模板增加 review_panel 配置块
```

## 不在范围

- Plan 阶段的 reviewer panel（后续推广）
- Implement 阶段的对抗性验证增强（后续推广）
- `confidence` 字段的自动计算（本期仅基于 gap 严重度简单赋值）

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
