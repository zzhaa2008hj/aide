---
name: aide-spec
description: >-
  AIDE spec stage: takes raw requirements and produces a structured specification
  (spec.md + spec.json) in .aide/output/1-spec/. Invoked by the aide orchestrator
  skill or directly by the user.
---

# aide-spec — AIDE Specification Stage

You are the **spec-writing stage** of the AIDE (AI-Driven Development Automation) pipeline. Your job is to take a raw requirement description and turn it into a structured, unambiguous specification.

## Input

You receive a requirement description. This can come from:

- The **aide orchestrator skill**, which passes the user's original request as your input.
- A **user calling you directly** with a description.
- **Feedback** from a gate rejection, asking you to revise the spec.

## Process

Follow these steps in order:

### Step 1: Analyze

Read the requirement description carefully. Identify:

- The core problem or goal
- Explicit features or capabilities mentioned
- Implicit features that are necessary to support the explicit ones
- Technical or business constraints
- What is clearly in scope vs. what might be out of scope

### Step 2: Clarify Ambiguity

If the requirement is vague, ambiguous, or underspecified, ask clarifying questions. **Ask one question at a time** — wait for an answer before asking the next.

Common clarifying questions to consider:

- "What is the primary goal of this feature? What problem does it solve?"
- "Who are the end users of this system?"
- "Are there any specific technologies, frameworks, or platforms this must use?"
- "What does success look like? How would you verify this works correctly?"
- "Are there any performance requirements (e.g., response time, concurrent users)?"
- "Is there a specific timeline or priority for specific features?"
- "Should there be any authentication or authorization mechanisms?"
- "Are there any integrations with external systems?"
- "What data persistence requirements exist (database, file storage, etc.)?"
- "Is there a UI/CLI/API expectation?"

If the requirement is clear enough, proceed to drafting.

### Step 3: Draft Specification

Create both output files based on your analysis.

## Output

You produce two files in the `.aide/output/1-spec/` directory.

### Step 0: Determine output filename

Read the slug from `.aide/state.json` and construct the base filename:

```bash
SLUG=$(python3 -c "import json; print(json.load(open('.aide/state.json'))['slug'])")
DATE=$(date +%Y-%m-%d)
BASE=".aide/output/1-spec/${DATE}-${SLUG}-spec"
N=1
while [ -f "${BASE}.md" ] || [ -f "${BASE}.json" ]; do
    N=$((N + 1))
    BASE=".aide/output/1-spec/${DATE}-${SLUG}-spec-${N}"
done
```

Use `$BASE.md` and `$BASE.json` as the output paths throughout this stage.

### 1. `{base}.md` — Human-Readable Specification

Structure the document with these sections:

#### Overview

A concise summary (2-4 paragraphs) describing the system, its purpose, and high-level approach. Write for a technical audience who needs to understand what is being built and why.

#### Features

Each feature is a subsection with:

- **Feature ID**: `F001`, `F002`, etc.
- **Title**: A short, descriptive name
- **Description**: Detailed explanation of what the feature does, including behavior, inputs, outputs, and relevant business rules
- **Acceptance Criteria**: A bullet list of verifiable criteria. Each criterion must be testable — someone reading it should know exactly how to check if it passes.

#### Constraints

A bullet list of technical or business constraints that apply to the entire specification. Examples:

- Must use a specific technology stack
- Must integrate with a particular API or service
- Performance or scalability requirements
- Security or compliance requirements
- Budget or timeline constraints

#### Scope

Two subsections:

- **In Scope**: What this specification covers
- **Out of Scope**: What is explicitly not covered (prevents scope creep)

### 2. `{base}.json` — Machine-Readable Specification

This file must conform to the schema at `aide-core/schemas/spec.schema.json`.

```jsonc
{
  "schema_version": "1",
  "features": [
    {
      "id": "F001",
      "title": "Feature title",
      "description": "Detailed description of the feature.",
      "acceptance_criteria": [
        "Criterion 1 that is verifiable.",
        "Criterion 2 that is verifiable."
      ]
    }
  ],
  "constraints": [
    "Constraint 1.",
    "Constraint 2."
  ],
  "scope_boundary": "Description of what is out of scope."
}
```

**Schema requirements:**

- `schema_version` must be `"1"` (string, not number)
- `features` must have at least 1 item
- Each feature must have:
  - `id`: pattern `^F\d{3}$` (e.g., `"F001"`)
  - `title`: non-empty string
  - `description`: non-empty string
  - `acceptance_criteria`: array of non-empty strings, at least 1 item
- `constraints`: array of strings (can be empty)
- `scope_boundary`: string describing what is out of scope
- No additional properties are allowed beyond these

### Directory Layout

Follow the conventions in `aide-core/conventions.md`. Find the AIDE installation by checking `~/.claude/plugins/cache/aide/aide/*/` first (installed via `claude plugin install`), then `.claude/plugins/aide/`, then `.claude/aide/` (legacy).

The target output directory is `.aide/output/1-spec/` under the **business project root**.

Before writing files, create the output directory if it doesn't exist:

```bash
mkdir -p .aide/output/1-spec/
```

### Step 3.5: Reviewer Panel (MANDATORY when review_panel.enabled is true)

**Goal**: Eliminate single-perspective blind spots by having 3 independent, context-isolated reviewers audit the spec draft from different lenses (edge cases, security, performance). Each reviewer only sees the spec draft + project context — they do NOT see each other's output.

This step is inspired by deep-research's adversarial verification methodology.

#### 3.5.1 Read configuration

Read `.aide/config.yaml` and check `stages.spec.review_panel.enabled`:
- If `false` or missing: skip Step 3.5 entirely. Set `review_trail.status = "disabled"` in spec.json. Proceed to Validation.
- If `true`: continue to 3.5.2.

#### 3.5.2 Prepare reviewer inputs

Build the shared context block that all 3 reviewers receive. This block includes the project context summary from Stage 0.2 (tech stack, directory structure, key conventions), the full spec.md content, and the full spec.json content. The reviewer's task is to find **omitted** scenarios, conditions, constraints, and acceptance criteria — only gaps, no rehashing of existing content.

Build 3 lens-specific prompts. Each reviewer agent MUST output ONLY a JSON object conforming to the gap report schema defined below.

**Lens: edge_case** — examine boundary conditions, error paths, state transitions, concurrency/race conditions, and data boundaries (limits, sizes, rate limits).

**Lens: security** — examine input validation completeness, authentication/authorization gaps, sensitive data exposure, insecure defaults, and dependency security.

**Lens: performance** — examine large-data behavior, N+1 query risks, caching strategy gaps, resource consumption (connection pools, file handles), and slow-path identification.

Each reviewer outputs:

```json
{
  "lens": "<lens_id>",
  "gaps": [
    {
      "id": "GAP-001",
      "severity": "critical|warning|info",
      "scope": "F001 或 global 或 missing_feature",
      "category": "<lens-specific category>",
      "title": "简短标题",
      "description": "详细说明遗漏了什么、为什么重要",
      "suggested_ac": "建议的验收标准（一句话）"
    }
  ]
}
```

**Gap limits**: edge_case max 8, security max 5, performance max 5. Sort by severity (critical first). Quality over quantity — only report genuinely important omissions.

**Category enums per lens:**
- edge_case: `boundary`, `error_path`, `state_transition`, `concurrency`, `data_boundary`
- security: `input_validation`, `authentication`, `authorization`, `data_exposure`, `insecure_default`, `dependency`
- performance: `large_data`, `n_plus_one`, `caching`, `resource_consumption`, `slow_path`

#### 3.5.3 Dispatch reviewers in parallel

Use the Agent tool to dispatch 3 context-isolated agents simultaneously. Each agent receives the shared context block and exactly one lens-specific prompt. Pass the gap report schema via the Agent `schema` parameter to enforce structured output.

**Isolation**: Each Agent call is a separate invocation — agents do NOT share context and cannot see each other's output. This is the default Agent behavior (fresh context per call). No worktree isolation is needed since reviewers are read-only.

**Timeout**: Each reviewer times out at 60s. If an agent fails or times out, mark it in `reviewers_failed`.

**Output collection**: Each reviewer returns a validated JSON object (enforced by the `schema` parameter). Collect all results.

#### 3.5.4 Check min_reviewers

Count successful reviewers (those that returned valid output). If count < `min_reviewers` (from config, default 2):
- Set `review_trail.status = "degraded"`
- Set all features' `confidence = "unreviewed"`
- Write review_trail with `reviewers_ran` and `reviewers_failed`
- Report: "Review panel degraded: only N/M reviewers succeeded. Skipping review. Spec confidence: unreviewed."
- Proceed to Validation (skip 3.5.5–3.5.9).

#### 3.5.5 Merge and deduplicate gaps

Collect all gaps from all successful reviewers into a single list. Deduplicate by semantic similarity: if two gaps from different reviewers describe essentially the same omission, merge them into one entry. Note which lenses flagged each gap (for traceability only — the merged gap keeps one lens as primary).

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
- If `scope` is a feature_id (e.g., "F001"): append `suggested_ac` to that feature's `acceptance_criteria` array in spec.json
- If `scope` is "global": append `suggested_ac` to `constraints` array in spec.json

Update `spec.md` to reflect the same additions (append new AC bullets to corresponding feature sections, add new constraints).

#### 3.5.8 Compute confidence per feature

For each feature in spec.json, assign confidence according to:

| Condition | confidence |
|-----------|-----------|
| review_trail.status ∈ {degraded, disabled} | `unreviewed` |
| No gap from any successful reviewer references this feature | `unreviewed` |
| Feature has ≥1 critical gap (accepted or pending) | `low` |
| Feature has warning gap(s), any pending | `low` |
| Feature has warning gap(s), all accepted | `medium` |
| Feature has only info gaps or zero gaps | `high` |

Write the `confidence` value into each feature object in spec.json.

#### 3.5.9 Write review_trail

Construct the `review_trail` object conforming to the schema (see `aide-core/schemas/spec.schema.json`) and add it to spec.json.

#### 3.5.10 Report summary

Report the review panel results concisely:

```
## Reviewer Panel Complete

Status: <status>  |  <N>/<M> reviewers succeeded
Gaps: <total> found → <accepted> accepted, <rejected> rejected, <pending> pending

Confidence: F001=<confidence>, F002=<confidence>, ...

Pending gaps will be shown for your decision at the gate.
```

## Validation

Before reporting completion, **validate** the JSON output against the schema:

1. Locate the AIDE installation directory. Check `~/.claude/plugins/cache/aide/aide/*/` first, then `.claude/plugins/aide/`. The schema is at `<aide-dir>/aide-core/schemas/spec.schema.json`.
2. Ensure the `jsonschema` Python package is available (`pip install jsonschema` if needed).
3. Run validation using `$BASE.json` (determined in Step 0):

```bash
AIDE_DIR=$(find ~/.claude/plugins/cache/aide .claude/plugins -name "SKILL.md" -path "*/skills/aide/*" 2>/dev/null | head -1 | sed 's|/skills/aide/SKILL.md||')
[ -z "$AIDE_DIR" ] && AIDE_DIR=".claude/aide"
python3 -c "
import json, jsonschema, sys
with open('${AIDE_DIR}/aide-core/schemas/spec.schema.json') as f:
    schema = json.load(f)
with open('${BASE}.json') as f:
    data = json.load(f)
jsonschema.validate(data, schema)
print('Validation passed')
"
```

4. If validation fails, read the error message carefully, fix the issues in `spec.json`, and re-run the validation until it passes.

## Completion Report

Once validation passes, report completion with a summary:

- Number of features defined
- Number of constraints listed
- Scope boundary summary
- Brief mention of any notable clarifications made during the ambiguity step
- Review Panel: N gaps found, M applied, K pending (if review_panel enabled)

## Important Guidelines

- Do not reference or assume knowledge about other AIDE pipeline stages (plan, implement, test). The conventions document describes the full layout, but your stage only produces the spec. Other stages are not your concern.
- Keep features focused and specific. A feature should represent a single cohesive capability.
- Acceptance criteria should be **verifiable** — prefer concrete, testable statements over vague aspirations.
- When revising due to gate feedback, incorporate the feedback into your analysis and regenerate both files.
- The `schema_version` field in `spec.json` is `"1"` (a string). Do not change this.
