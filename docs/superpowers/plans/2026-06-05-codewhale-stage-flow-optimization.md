# CodeWhale Stage Flow Optimization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `checklist_write` progress tracking and `agent_eval` smart result collection to the CodeWhale AIDE orchestrator, and remove the redundant Pipeline Discipline section.

**Architecture:** Single-file edit to `skills/aide-codewhale/SKILL.md`. Three changes: (1) add `checklist_write` calls at stage boundaries for visible progress, (2) replace "wait for sentinel + read full output" with summary-first `agent_eval` logic in Stage 3, (3) remove the text-based Pipeline Discipline section since mode switching enforces the write ban.

**Tech Stack:** Markdown (SKILL.md with YAML frontmatter)

---

### Task 1: Apply all three optimizations to SKILL.md

**Files:**
- Modify: `skills/aide-codewhale/SKILL.md`

- [ ] **Step 1: Remove Pipeline Discipline section**

Delete lines 56-68 (the entire `## Pipeline Discipline` section including the forbidden actions list and permitted files list).

In `skills/aide-codewhale/SKILL.md`, replace:
```markdown
## Pipeline Discipline

**ABSOLUTELY FORBIDDEN until Stage 3 (implement) begins:**
- Writing, editing, or creating ANY source code file
- Writing/editing anything outside `.aide/output/`
- Running build commands, package installs, or similar

**The ONLY files you may create before Stage 3:**
- `.aide/state.json`
- `.aide/output/1-spec/*-spec.md` and `*-spec.json`
- `.aide/output/2-plan/*-plan.md` and `*-plan.json`

Violating these rules breaks resumability and leaves incomplete artifacts.

## Stage 0: Initialize
```

with:
```markdown
## Stage 0: Initialize
```

- [ ] **Step 2: Add checklist_write initialization at Stage 0 start**

After the `## Stage 0: Initialize` heading, add as the first action:

In `skills/aide-codewhale/SKILL.md`, after `### 0.1 Parse request and generate slug` section (after the "Extract 3-5 keywords..." line), insert:

```markdown
### 0.0 Initialize progress checklist

Use `checklist_write` to create a visible progress tracker:
```
checklist_write([
  {id: "0", label: "Initialize", checked: false},
  {id: "1", label: "Spec", checked: false},
  {id: "2", label: "Plan", checked: false},
  {id: "3", label: "Implement", checked: false},
  {id: "4", label: "Test", checked: false}
])
```
```

- [ ] **Step 3: Add checklist_write updates at each stage transition**

After each stage's State update block, add a `checklist_write` call marking the completed stage.

After Stage 0 state update (the JSON block that sets `current_stage: "spec"`), add:
```markdown
**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: false},
  {id: "2", label: "Plan", checked: false},
  {id: "3", label: "Implement", checked: false},
  {id: "4", label: "Test", checked: false}
])
```
```

After Stage 1 state update (the JSON block that sets `current_stage: "plan"`), add:
```markdown
**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: true},
  {id: "2", label: "Plan", checked: false},
  {id: "3", label: "Implement", checked: false},
  {id: "4", label: "Test", checked: false}
])
```
```

After Stage 2 state update (the JSON block that sets `current_stage: "implement"`), add:
```markdown
**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: true},
  {id: "2", label: "Plan", checked: true},
  {id: "3", label: "Implement", checked: false},
  {id: "4", label: "Test", checked: false}
])
```
```

After Stage 3 state update (the JSON block that sets `current_stage: "test"`), add:
```markdown
**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: true},
  {id: "2", label: "Plan", checked: true},
  {id: "3", label: "Implement", checked: true},
  {id: "4", label: "Test", checked: false}
])
```
```

After Stage 4 state update (the JSON block that sets `current_stage: "complete"`), add:
```markdown
**Progress**:
```
checklist_write([
  {id: "0", label: "Initialize", checked: true},
  {id: "1", label: "Spec", checked: true},
  {id: "2", label: "Plan", checked: true},
  {id: "3", label: "Implement", checked: true},
  {id: "4", label: "Test", checked: true}
])
```
```

- [ ] **Step 4: Replace sentinel-based result collection with agent_eval smart reading**

In Stage 3, replace the existing "CodeWhale source basis" and "Batching algorithm" step 3 text.

Find:
```markdown
3. Wait for all in the batch to complete via notification sentinels
```

Replace the paragraph starting with **CodeWhale source basis** through the batching algorithm (the line "6. Repeat until `ready` is empty or all remaining are blocked") with:

```markdown
3. Wait for `<codewhale:subagent.done>` sentinels. When a sentinel arrives:
   a. Read the **summary line** that precedes the sentinel (CodeWhale injects this automatically)
   b. If summary indicates **DONE**: mark task complete, no further reading needed
   c. If summary indicates **BLOCKED**: use `agent_eval` + `handle_read` to fetch the blocker reason
   d. If summary is **ambiguous**: use `handle_read` with a line-range slice for clarification
4. For each completed task: add to `completed`, move dependent tasks from `waiting` to `ready`
5. If a task fails/errors: mark as `blocked` with reason, block tasks that depend on it
6. Repeat until `ready` is empty or all remaining are blocked

**CodeWhale source basis**: `agent_open` is non-blocking (returns immediately). The runtime injects a `<codewhale:subagent.done>` sentinel with a human-readable summary line. `agent_eval` provides a `transcript_handle`, and `handle_read` supports slices, line ranges, or JSONPath projections for bounded retrieval. (CodeWhale README, Sub-agents section)
```

- [ ] **Step 5: Verify the changes**

```bash
grep -c "checklist_write" skills/aide-codewhale/SKILL.md
```
Expected: 7 (1 init + 6 transitions)

```bash
grep -c "agent_eval\|handle_read" skills/aide-codewhale/SKILL.md
```
Expected: at least 3

```bash
grep "Pipeline Discipline" skills/aide-codewhale/SKILL.md
```
Expected: no matches (section removed)

```bash
grep -n "TBD\|TODO\|FIXME" skills/aide-codewhale/SKILL.md
```
Expected: no matches

- [ ] **Step 6: Commit**

```bash
git add skills/aide-codewhale/SKILL.md
git commit -m "feat: add checklist_write progress tracking and agent_eval smart reading

- Add checklist_write calls at each stage transition for visible progress
- Replace sentinel full-read with summary-first agent_eval + handle_read
- Remove Pipeline Discipline section (mode switching enforces write ban)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
