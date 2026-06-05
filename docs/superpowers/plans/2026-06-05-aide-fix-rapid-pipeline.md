# /aide-fix Rapid Bug-Fix Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `/aide-fix` orchestrator skill — a lightweight pipeline for bug fixes and small optimizations.

**Architecture:** A single self-contained orchestrator SKILL.md in `skills/aide-fix/`. Unlike `/aide` which delegates to separate stage skills, `/aide-fix` handles analyze and implement directly (single-agent operations), invokes `aide-test` for test verification, and uses the same gate engine and conventions as the main pipeline. Independent state file, branch prefix, and output directory keep it isolated from `/aide`.

**Tech Stack:** Markdown (SKILL.md), Bash (git/test commands), JSON (state tracking). No code — orchestrator works through prompts and tool calls.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `skills/aide-fix/SKILL.md` | Create | Orchestrator: startup, analyze, implement, test, gates, commit |
| `templates/aide.config.yaml` | Modify | Add `fix` pipeline gate defaults |
| `aide-core/conventions.md` | Modify | Add `fix` pipeline entry to stage order and output structure |

---

### Task 1: Create `skills/aide-fix/SKILL.md` — Metadata and Startup Sequence

**Files:**
- Create: `skills/aide-fix/SKILL.md`

- [ ] **Step 1: Create directory and file header**

```bash
mkdir -p skills/aide-fix
```

Write to `skills/aide-fix/SKILL.md`:

```markdown
---
name: aide-fix
description: >-
  AIDE rapid fix orchestrator. Lightweight pipeline for bug fixes and small
  optimizations — analyze → implement → test with 3 human gates and scope-fenced
  code changes. Invoke via /aide-fix "<bug description or error log>".
---

# AIDE Fix — Rapid Bug-Fix Pipeline

You are the **orchestrator** of the AIDE-FIX rapid pipeline. Your job is to coordinate a lightweight analyze → implement → test flow for bug fixes and small optimizations. You do NOT delegate to separate stage skills for analyze and implement — you handle them directly. For test verification, you invoke the `aide-test` skill.

## Permissions

Request these permissions up front at the start:

- **Bash**: Run commands, manage git, run tests
- **Write/Edit**: Create and modify all project files
- **Read**: Read any file in the project
- **Skill**: Invoke `aide-test` for verification

## ⛔ CRITICAL — Pipeline Discipline

You are a **strict sequential pipeline state machine**. Your current stage is tracked in `.aide/fix-state.json`.

**The ONLY files you may create before Stage 2 (implement):**
- `.aide/fix-state.json`
- `.aide/fix/output/1-analyze/*-analyze.md`

**You MAY NOT write source code until Stage 2 (implement) begins.**

**Each stage transition requires:**
1. Completing the stage work EXACTLY as specified below
2. Validating output artifacts exist
3. Passing the gate (AskUserQuestion per config)
4. Updating `.aide/fix-state.json`

**You are in exactly ONE stage at a time. Complete it fully before proceeding.**

If `.aide/fix-state.json` exists at startup with `completed_stages`, respect it — do NOT re-run completed stages.

## Core Principle

**Orchestrate, do not over-engineer.** This is a rapid pipeline. Analyze concisely, implement minimally, verify thoroughly. Don't turn a null-pointer fix into a refactoring project.
```

- [ ] **Step 2: Add Startup Sequence section**

Append to `skills/aide-fix/SKILL.md`:

```markdown
---
## Startup Sequence

When the user invokes the `aide-fix` skill, follow this startup sequence.

### Step 0: Parse input and generate slug

Extract 3-5 keywords from the user's bug description, lowercase, hyphenate.
Example: `"登录页 NPE at UserService.java:42"` → `login-npe`

Store as `FIX_SLUG`.

### Step 0.5: Analyze project context (MANDATORY)

**You MUST ground all decisions in the existing project.** Follow the same context analysis as the main AIDE pipeline:

1. **Map the project structure**:
   ```bash
   find . -maxdepth 1 -type f \( -name "*.json" -o -name "*.yaml" -o -name "*.toml" -o -name "*.cfg" -o -name "Makefile" -o -name "Dockerfile" \) 2>/dev/null | head -20
   ls -la
   ```

2. **Identify tech stack**: Read `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `Gemfile`, `pom.xml`, `build.gradle`, etc. Determine: language, framework, build system, test framework, package manager.

3. **Understand directory conventions**:
   ```bash
   find . -maxdepth 3 -type d ! -path './.git/*' ! -path './node_modules/*' ! -path './.aide/*' ! -path './venv/*' ! -path './__pycache__/*' | sort
   ```

4. **Identify existing patterns**: Read key source files (entry points, config, a few representative components/modules). Note: naming conventions, file organization patterns, code style.

5. **Check for existing tests**:
   ```bash
   find . -path '*/test*' -o -path '*/__test*' -o -path '*/spec*' | head -20
   ```

6. **Summarize findings** in a brief project context memo. This informs analyze and implement stages.

### Step 1: Branch Preparation

1. **Record current branch**:
   ```bash
   git branch --show-current
   ```
   Store as `ORIG_BRANCH`. If detached HEAD, record commit hash.

2. **Gate 1 — confirm branch creation**:
   Use `AskUserQuestion`:
   ```
   Question: "Create aide-fix/<slug> branch for this fix?"
   Header: "Branch"
   Options:
     - "Create aide-fix/<slug> (Recommended)" — isolates fix work from current branch
     - "skip: Stay on <ORIG_BRANCH>, no isolation"
   Multi-select: false
   ```

   If `skip`: set `FIX_BRANCH=""`, skip to Step 3. Work directly on `ORIG_BRANCH`.

3. **Check for existing branches**:
   ```bash
   git branch --list "aide-fix/${FIX_SLUG}*"
   ```
   If exact name exists, append `-2`, `-3`, etc.

4. **Handle uncommitted changes**:
   ```bash
   git status --porcelain
   ```
   If dirty: `git stash push -m "AIDE-FIX: auto-stash before aide-fix/${FIX_SLUG}"`. Record stash.

5. **Create and switch**:
   ```bash
   git checkout -b aide-fix/${FIX_SLUG}
   ```
   If fails: restore stash, report, abort.

6. **Report**:
   ```
   Branch: aide-fix/<slug> created. Fix pipeline starting.
   ```

### Step 2: Read conventions

Read `aide-core/conventions.md`. Find it by searching:
1. `~/.claude/plugins/cache/aide/aide/*/aide-core/conventions.md`
2. `.claude/plugins/aide/aide-core/conventions.md`
3. `.claude/aide/aide-core/conventions.md`

### Step 3: Load configuration

Read `.aide/config.yaml`. If the file does not exist, use hardcoded defaults:

```yaml
fix:
  enabled: true
  gates:
    - name: after_analyze
      type: confirm_skip
      prompt: "Review the analyze result above. Does the diagnosis look correct? (y/n/skip)"
    - name: after_fix
      type: confirm
      prompt: "Review the changes and test results above. Accept the fix? (y/n)"
```

### Step 4: Initialize state

Write to `.aide/fix-state.json`:

```json
{
  "slug": "<FIX_SLUG>",
  "branch": "aide-fix/<FIX_SLUG>",
  "description": "<user's original input>",
  "current_stage": "analyze",
  "completed_stages": [],
  "scope_fence": [],
  "test_retries": 0,
  "last_updated": "<ISO 8601 timestamp>"
}
```

### Step 5: Create output directories

```bash
mkdir -p .aide/fix/output/1-analyze
mkdir -p .aide/fix/output/2-implement
mkdir -p .aide/fix/output/3-test
```

### Step 6: Announce

```
Starting AIDE-FIX pipeline for: <user's description>
Enabled stages: analyze → implement → test
Gates: after_analyze (confirm_skip), after_fix (confirm)
Branch: aide-fix/<slug>
```
```

- [ ] **Step 3: Commit startup sequence**

```bash
git add skills/aide-fix/SKILL.md
git commit -m "feat(aide-fix): add metadata and startup sequence to orchestrator skill"
```
```

---

### Task 2: Add Stage 1 — Analyze to SKILL.md

**Files:**
- Modify: `skills/aide-fix/SKILL.md`

- [ ] **Step 1: Append Analyze stage instructions**

Append to `skills/aide-fix/SKILL.md`:

```markdown
---
## Stage 1: Analyze — Root Cause Diagnosis

**Goal:** Identify the root cause, determine which files need modification, and produce a scope fence.

### Step 1.1: Understand the issue

Read the user's bug description or error log. Identify:
- The symptom (what went wrong)
- The context (when/where it happens)
- Any stack traces, error codes, or reproduction steps provided

### Step 1.2: Search and trace

Use `Grep` to search for relevant code:
- Search for error messages, class names, method names from the description
- Search for function/variable names mentioned in stack traces

Read the most relevant files to understand the code flow. Trace call chains to identify the root cause.

### Step 1.3: Determine scope fence

List every file that needs to be modified. For each file, verify:
- The file actually exists at that path
- The change is directly necessary to fix the bug (YAGNI — no opportunistic refactoring)

### Step 1.4: Assess risk

Evaluate risk level:
- **low** — modified files have good test coverage; changes are local and don't affect public APIs
- **medium** — modified files have some tests; changes touch interfaces used by other modules
- **high** — modified files have no tests; changes affect critical paths or public APIs

### Step 1.5: Write analyze output

Determine today's date: run `date +%Y-%m-%d`.

Write to `.aide/fix/output/1-analyze/{date}-{slug}-analyze.md`. Check if file exists; if so, append `-2`, `-3`, etc.

```markdown
## Analyze Result: <brief summary>

**Root cause:** <one sentence explaining the root cause>

**Files to modify:**
- `path/to/file1.ext` — <one sentence describing the change>
- `path/to/file2.ext` — <one sentence describing the change>

**Risk:** low | medium | high

**Reasoning:** <1-2 sentences explaining the risk assessment>
```

### Step 1.6: Update state

Update `.aide/fix-state.json` — set `scope_fence` to the list of file paths. Use:

```bash
python3 -c "
import json
with open('.aide/fix-state.json') as f:
    state = json.load(f)
state['scope_fence'] = ['path/to/file1.ext', 'path/to/file2.ext']
state['current_stage'] = 'analyze'
with open('.aide/fix-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

### Step 1.7: Gate 2 — confirm_skip

Use `AskUserQuestion`:
```
Question: "Review the analyze result. Does the diagnosis look correct?"
Header: "Analyze"
Options:
  - "yes (y) — proceed to implement"
  - "skip (s) — skip review, execute directly"
  - "no (n) — reject, provide feedback for re-analysis"
Multi-select: false
```

- `y` → proceed to Stage 2
- `s` → proceed to Stage 2; persist preference by updating gate type to `auto` in `.aide/config.yaml`
- `n` → ask user for feedback, re-run Step 1.2–1.5 with feedback, increment output file sequence, re-present gate

### Step 1.8: Commit analyze artifacts

```bash
git add .aide/fix/
git commit -m "aide-fix(analyze): <summary of diagnosis>"
```

### Step 1.9: Advance state

```bash
python3 -c "
import json
with open('.aide/fix-state.json') as f:
    state = json.load(f)
state['current_stage'] = 'implement'
state['completed_stages'].append('analyze')
state['last_updated'] = '$(date -Iseconds)'
with open('.aide/fix-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/aide-fix/SKILL.md
git commit -m "feat(aide-fix): add Stage 1 analyze with scope fence and gate"
```
```

---

### Task 3: Add Stage 2 — Implement to SKILL.md

**Files:**
- Modify: `skills/aide-fix/SKILL.md`

- [ ] **Step 1: Append Implement stage instructions**

Append to `skills/aide-fix/SKILL.md`:

```markdown
---
## Stage 2: Implement — Scope-Fenced Code Changes

**Goal:** Apply minimal code changes within the scope fence to fix the bug.

**🔴 CHECK**: Is `current_stage` set to `"implement"`? Is `"analyze"` in `completed_stages`? If not, STOP and go back.

**🟢 YOU MAY NOW WRITE SOURCE CODE.** The analyze stage has produced a confirmed scope fence.

### Step 2.1: Load context

Read `.aide/fix-state.json` to get the `scope_fence` and `slug`.
Read `.aide/fix/output/1-analyze/{date}-{slug}-analyze.md` for the diagnosis and file list.

### Step 2.2: Read all files in scope fence

Read every file listed in `scope_fence`. Understand:
- The current code around the bug location
- Existing code style, naming conventions, patterns in each file
- Test files associated with these source files (if any)

### Step 2.3: Apply changes

For each file in the scope fence, apply the minimal change needed to fix the bug.

**Hard constraint — SCOPE FENCE:**
- ONLY modify files listed in `scope_fence`
- If you discover a change needed outside the fence, STOP — report to user and ask whether to expand the fence
- NEVER touch files outside the fence without explicit user approval

**Soft constraint — MINIMAL DIFF:**
- Only change lines directly related to the fix
- Do NOT refactor unrelated code
- Do NOT reformat existing code
- Do NOT add "defensive" checks unrelated to the bug
- Do NOT change variable names, extract methods, or reorganize imports unless required by the fix
- Follow the existing code style and naming conventions exactly

**Preservation property:**
When the bug condition does NOT hold, the patched code MUST behave identically to the original. The fix should only change behavior for the failing case.

### Step 2.4: Write implement summary

Determine today's date: run `date +%Y-%m-%d`.

Write to `.aide/fix/output/2-implement/{date}-{slug}-implement.md`. If exists, append `-2`, `-3`.

```markdown
## Implement Summary: <brief summary>

### Changes Made

**`path/to/file1.ext`:**
- <specific change 1>
- <specific change 2>

**`path/to/file2.ext`:**
- <specific change 1>

### Scope fence compliance
All changes are within the approved file list: <list files>

### Test status
Pending — Stage 3 will verify
```

### Step 2.5: No gate here

Stage 2 has no independent gate. Proceed immediately to Stage 3 (test). The gate after test serves as the combined review point for both implement and test.

### Step 2.6: Advance state

```bash
python3 -c "
import json
with open('.aide/fix-state.json') as f:
    state = json.load(f)
state['current_stage'] = 'test'
state['completed_stages'].append('implement')
state['last_updated'] = '$(date -Iseconds)'
with open('.aide/fix-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/aide-fix/SKILL.md
git commit -m "feat(aide-fix): add Stage 2 implement with scope fence enforcement"
```
```

---

### Task 4: Add Stage 3 — Test to SKILL.md

**Files:**
- Modify: `skills/aide-fix/SKILL.md`

- [ ] **Step 1: Append Test stage instructions**

Append to `skills/aide-fix/SKILL.md`:

```markdown
---
## Stage 3: Test — Verify and Retry

**Goal:** Run tests, automatically retry on failure (max 2 retries), and present results for final confirmation.

**🔴 CHECK**: Is `current_stage` set to `"test"`? Is `"implement"` in `completed_stages`? If not, STOP.

### Step 3.1: Determine test command

From the project context analysis (Step 0.5), identify the test command. Common patterns:
- Node/JS: `npm test`, `npx jest`, `npx vitest`
- Python: `pytest`, `python -m pytest`, `tox`
- Java: `mvn test`, `./gradlew test`
- Go: `go test ./...`
- Rust: `cargo test`

If the test framework is unclear, run:
```bash
grep -r '"test"' package.json 2>/dev/null | head -3
```

### Step 3.2: Run tests

```bash
<TEST_COMMAND> 2>&1
```

If tests pass (exit code 0) → proceed to Step 3.5 (write report).

### Step 3.3: Retry loop (on failure)

Read `test_retries` from `.aide/fix-state.json`.

**While `test_retries < 2`:**

1. Increment counter:
   ```bash
   python3 -c "
   import json
   with open('.aide/fix-state.json') as f:
       state = json.load(f)
   state['test_retries'] += 1
   with open('.aide/fix-state.json', 'w') as f:
       json.dump(state, f, indent=2)
       f.write('\n')
   "
   ```

2. Analyze the failure:
   - Read test failure output
   - Identify which test(s) failed and why
   - Determine if the root cause is within the scope fence

3. **Scope fence check**: If the failure root cause is OUTSIDE the scope fence:
   - STOP immediately
   - Report: "Test failure at <file:line> is outside the scope fence. Manual intervention needed."
   - Do NOT expand the fence — let the user decide

4. Fix the issue:
   - Apply minimal fix within the scope fence
   - Follow the same constraints as Stage 2 (scope fence, minimal diff, preservation)

5. Re-run tests:
   ```bash
   <TEST_COMMAND> 2>&1
   ```
   If pass → break loop, proceed to Step 3.5
   If fail → continue loop (back to step 1)

6. **If `test_retries >= 2` and still failing:**
   - Report: "Tests still failing after 2 auto-retry attempts. Manual intervention required."
   - Present the failure details and current diff

### Step 3.4: Handle retry exhaustion

If tests pass after retry N → proceed to Step 3.5.

If tests still fail after 2 retries:
- Present failure summary to user
- Gate 3 will prompt: "Tests are failing. Review the changes and decide how to proceed."

### Step 3.5: Write test report

Determine today's date: run `date +%Y-%m-%d`.

Write to `.aide/fix/output/3-test/{date}-{slug}-test-report.md`:

```markdown
## Test Report: <brief summary>

**Result:** pass | fail (after N retries)

**Test output:**
```
<paste test output summary>
```

**Retries used:** <N> / 2

**Scope fence compliance:** <confirmed or issues>
```

### Step 3.6: Gate 3 — confirm

Use `AskUserQuestion`:
```
Question: "Fix complete. Review the changes and test results. Accept?"
Header: "Fix Review"
Options:
  - "y — accept the fix"
  - "n — reject, provide feedback for revision"
Multi-select: false
```

If `y` → proceed to completion.
If `n` → ask user for feedback, return to Stage 2 (implement) with feedback, reset `test_retries` to 0, re-run implement → test.

### Step 3.7: Commit artifacts

```bash
git add .aide/fix/
git commit -m "aide-fix(test): <test result summary>"
```

### Step 3.8: Mark complete

```bash
python3 -c "
import json
with open('.aide/fix-state.json') as f:
    state = json.load(f)
state['current_stage'] = 'complete'
state['completed_stages'].append('test')
state['last_updated'] = '$(date -Iseconds)'
with open('.aide/fix-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

### Step 3.9: Report completion

```
## AIDE-FIX Pipeline Complete

Fix: <description>
Branch: aide-fix/<slug>
Result: <pass/fail>
Files changed: <list>

The fix is on branch aide-fix/<slug>. Merge manually when ready:
  git checkout <target-branch>
  git merge aide-fix/<slug>
```

- [ ] **Step 2: Commit**

```bash
git add skills/aide-fix/SKILL.md
git commit -m "feat(aide-fix): add Stage 3 test with auto-retry loop and final gate"
```

---

### Task 5: Update `templates/aide.config.yaml` — Add Fix Pipeline Gates

**Files:**
- Modify: `templates/aide.config.yaml`

- [ ] **Step 1: Read current template**

```bash
cat templates/aide.config.yaml
```

- [ ] **Step 2: Append fix pipeline gate defaults**

Append to `templates/aide.config.yaml`:

```yaml

# Fix pipeline (rapid bug-fix / small optimization)
fix:
  enabled: true
  gates:
    - name: after_analyze
      type: confirm_skip
      prompt: "Review the analyze result above. Does the diagnosis look correct? (y/n/skip)"
    - name: after_fix
      type: confirm
      prompt: "Review the changes and test results above. Accept the fix? (y/n)"
```

- [ ] **Step 3: Commit**

```bash
git add templates/aide.config.yaml
git commit -m "feat(aide-fix): add fix pipeline gate defaults to config template"
```

---

### Task 6: Update `aide-core/conventions.md` — Add Fix Pipeline Conventions

**Files:**
- Modify: `aide-core/conventions.md`

- [ ] **Step 1: Read current conventions**

```bash
cat aide-core/conventions.md
```

- [ ] **Step 2: Add fix pipeline to stage order table**

Locate the Stage Order table and add a row for the fix pipeline. Append after the existing table:

```markdown
## Fix Pipeline Stage Order

| Order | Stage     | Description                         | Executor                |
|-------|-----------|-------------------------------------|-------------------------|
| 0     | init      | Project context + branch creation   | Orchestrator            |
| 1     | analyze   | Root cause → scope fence            | Orchestrator            |
| 2     | implement | Scope-fenced code changes           | Orchestrator (1 agent)  |
| 3     | test      | Verify + auto-retry (max 2)        | Orchestrator + aide-test|

The fix pipeline is a lightweight alternative to the full pipeline, designed for bug fixes and small optimizations. It is invoked via `/aide-fix` and uses independent state tracking (`.aide/fix-state.json`), branch prefix (`aide-fix/`), and output directory (`.aide/fix/output/`).
```

- [ ] **Step 3: Add fix pipeline output structure**

Append after the existing output structure:

```markdown
## Fix Pipeline Output Structure

```
.aide/fix/
├── fix-state.json
└── output/
    ├── 1-analyze/
    │   └── {date}-{slug}-analyze.md
    ├── 2-implement/
    │   └── {date}-{slug}-implement.md
    └── 3-test/
        └── {date}-{slug}-test-report.md
```

File naming follows the same convention: `{date}-{slug}-{stage}.md`. Re-runs append `-2`, `-3`, etc.
```

- [ ] **Step 4: Add fix pipeline to git conventions**

Append after existing git conventions:

```markdown
### Fix Pipeline

- Branch naming: `aide-fix/<slug>`
- Auto-commit `.aide/fix/` artifacts after each stage with message: `aide-fix(<stage>): <summary>`
- Business code changes are never auto-committed
- After pipeline completes, the branch is left as-is; merging back is a manual user decision
```

- [ ] **Step 5: Commit**

```bash
git add aide-core/conventions.md
git commit -m "docs(aide-core): add fix pipeline conventions"
```

---

### Task 7: End-to-End Verification

**Files:**
- Verify: `skills/aide-fix/SKILL.md`
- Verify: `templates/aide.config.yaml`
- Verify: `aide-core/conventions.md`

- [ ] **Step 1: Verify file structure**

```bash
echo "=== Skills ==="
ls -la skills/aide-fix/
echo ""
echo "=== SKILL.md size ==="
wc -l skills/aide-fix/SKILL.md
echo ""
echo "=== Template gates ==="
grep -A 6 "fix:" templates/aide.config.yaml
echo ""
echo "=== Conventions fix entries ==="
grep -n "fix" aide-core/conventions.md
```

Expected:
- `skills/aide-fix/SKILL.md` exists and is non-empty
- `templates/aide.config.yaml` contains `fix:` section with `after_analyze` and `after_fix` gates
- `aide-core/conventions.md` contains fix pipeline references

- [ ] **Step 2: Verify SKILL.md structure — check all required sections**

```bash
echo "=== Required sections check ==="
for section in "AIDE Fix" "Startup Sequence" "Stage 1: Analyze" "Stage 2: Implement" "Stage 3: Test" "Pipeline Discipline" "Gate" "scope fence" "fix-state.json" "aide-fix/"; do
  if grep -q "$section" skills/aide-fix/SKILL.md; then
    echo "✓ Found: $section"
  else
    echo "✗ MISSING: $section"
  fi
done
```

Expected: All sections found.

- [ ] **Step 3: Verify spec coverage**

Manual checklist — verify each spec requirement has a corresponding section in SKILL.md:

| Spec Requirement | SKILL.md Section |
|---|---|
| /aide-fix command | Metadata (name: aide-fix) |
| 3 stages (analyze→implement→test) | Stage 1/2/3 sections |
| 3 gates (branch, analyze, fix) | Step 1 (Gate 1), Step 1.7 (Gate 2), Step 3.6 (Gate 3) |
| Scope fence (file whitelist) | Step 1.3 + Stage 2 hard constraint |
| Minimal diff | Stage 2 soft constraint |
| Preservation property | Stage 2 preservation property |
| Auto-retry (max 2) | Stage 3 retry loop |
| Independent state file | Step 4 (fix-state.json) |
| Branch prefix aide-fix/ | Step 1 (branch creation) |
| Output dir .aide/fix/output/ | Step 5 (mkdir) |
| confirm_skip on analyze | Step 1.7 (Gate 2) |
| confirm on final | Step 3.6 (Gate 3) |
| No auto-merge | Completion report (manual merge) |

- [ ] **Step 4: Self-consistency check**

Run consistency validation:

```bash
echo "=== Gate types consistency ==="
echo "Config template:"
grep -A 2 "after_analyze\|after_fix" templates/aide.config.yaml
echo ""
echo "SKILL.md gates:"
grep -A 3 "Gate 2\|Gate 3\|confirm_skip\|confirm" skills/aide-fix/SKILL.md | head -20
```

Gate types should match between config template and SKILL.md references.

- [ ] **Step 5: Commit verification results**

```bash
git add -A
git diff --cached --stat
```

Review the final diff summary. All changes should be in `skills/aide-fix/`, `templates/`, and `aide-core/` only.

---

## Spec Coverage Self-Review

| Spec Section | Covered By |
|---|---|
| Pipeline Flow (3 stages + 3 gates) | SKILL.md: Startup, Stage 1, Stage 2, Stage 3 |
| Scope Fence (hard + soft constraints) | SKILL.md: Stage 1.3, Stage 2.3 |
| Anti-Overfix Constraints (4 rules) | SKILL.md: Stage 2.3 |
| Stage 0: Init (slug, context, branch, gate) | SKILL.md: Startup Sequence |
| Stage 1: Analyze (root cause, files, risk, gate) | SKILL.md: Stage 1 |
| Stage 2: Implement (scope fence, minimal diff, output) | SKILL.md: Stage 2 |
| Stage 3: Test (run, retry, gate) | SKILL.md: Stage 3 |
| Output Directory Structure | SKILL.md: Step 5 + conventions.md |
| Gate Summary (3 gates, types, positions) | SKILL.md: Gates embedded in stages |
| State File Schema | SKILL.md: Step 4 |
| Git Conventions | conventions.md update |
| Config defaults | templates/aide.config.yaml update |
| Conventions document | aide-core/conventions.md update |

No gaps. All spec requirements map to implementation tasks.

