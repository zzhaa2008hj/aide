# AIDE CodeWhale Stage Flow Optimization — Design Spec

Date: 2026-06-05
Status: Approved
Topic: Optimize CodeWhale orchestrator with checklist_write progress tracking and agent_eval smart result collection

## Overview

Two targeted optimizations to the CodeWhale AIDE orchestrator that leverage CodeWhale-native features:

1. **`checklist_write`** — Replace manual stage tracking with CodeWhale's native progress checklist, giving users a visible progress bar in the UI
2. **`agent_eval` + `handle_read`** — Replace full-subagent-output reading with summary-first result collection, keeping orchestrator context lean

Also removes the Pipeline Discipline text-based write ban (~15 lines) since the mode switching (`/agent` → `/yolo`) already enforces this at the CodeWhale level.

## Optimization 1: checklist_write Progress Tracking

### Current State

The orchestrator tracks progress via `.aide/state.json` (internal) and manual text output (user-facing). The user sees raw text like "Stage 1 complete. Proceed to Stage 2" but has no persistent visual indicator.

### Target State

Each stage transition updates a `checklist_write` call. CodeWhale renders this as a visible progress bar in the UI.

Stage 0 (start of pipeline):
```
checklist_write([
  {id: "0", label: "Initialize", checked: false},
  {id: "1", label: "Spec", checked: false},
  {id: "2", label: "Plan", checked: false},
  {id: "3", label: "Implement", checked: false},
  {id: "4", label: "Test", checked: false}
])
```

Stage 0 complete → mark "Initialize" checked, set "Spec" as active (checked: false but cursor on it).

### CodeWhale Source Basis

CodeWhale README mode table: "Agent 🤖 — Default interactive mode — multi-step tool use with approval gates; substantial work is tracked with `checklist_write`". The `checklist_write` tool is available in Agent mode and renders as a visible checklist in the TUI.

## Optimization 2: agent_eval Smart Result Collection

### Current State

Stage 3 waits for `<codewhale:subagent.done>` sentinels, then reads the full sub-agent output. This pollutes the orchestrator context with implementation details.

### Target State

When a sentinel arrives:
1. Read the **summary line** that precedes the sentinel (CodeWhale injects this automatically)
2. If summary clearly indicates DONE → skip full transcript, mark task complete
3. If summary indicates BLOCKED → use `agent_eval` + `handle_read` to fetch the blocker reason only
4. If summary is ambiguous → `handle_read` with a slice of the transcript for clarification

```
Summary: "T001 DONE — implemented login endpoint, 3 files changed"
→ No handle_read needed, mark complete

Summary: "T002 BLOCKED — dependency on user model not yet defined"
→ handle_read to get the specific blocker context
```

### CodeWhale Source Basis

CodeWhale README sub-agents section: "The full child transcript lives behind a `transcript_handle` accessible through `agent_eval`. When the summary isn't enough, the parent calls `handle_read` for slices, line ranges, or JSONPath projections — keeping the parent context lean without losing access to the details."

## Optimization 3: Remove Redundant Pipeline Discipline

### Current State

The "Pipeline Discipline" section (~15 lines) lists forbidden actions before Stage 3. This is a text-based suggestion that the model must remember to follow.

### Target State

Remove the section. The mode switching already enforces this:
- Agent mode (Stages 0-2, 4): edits require approval → user gates accidental writes
- YOLO mode (Stage 3): auto-approve all writes → intended behavior

The write ban is now enforced by CodeWhale's mode system, not by model memory.

## Files Changed

| Action | File | Description |
|--------|------|-------------|
| Edit | `skills/aide-codewhale/SKILL.md` | Add checklist_write calls, agent_eval logic, remove Pipeline Discipline section |

## Non-goals

- Plan mode integration (incompatible with output file writing)
- MCP tool integration (deferred)
- RLM project context caching (deferred)
- LSP diagnostics guidance (deferred)
