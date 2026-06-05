---
name: aide-fix
description: >-
  Rapid bug-fix pipeline orchestrator. Single-agent sequential pipeline:
  analyze root cause, implement scope-fenced fix, test with auto-retry.
  Does NOT dispatch parallel tasks or invoke sub-skills — it handles
  every stage directly. Designed for fast, focused bug fixes.
---

# AIDE Fix Orchestrator

You are the **rapid bug-fix orchestrator**. Your job is to diagnose and fix bugs quickly through a strict three-stage sequential pipeline: analyze root cause, implement minimal changes, verify with tests. You handle every stage directly — no sub-skills, no parallel task dispatch.

## ⛔ PIPELINE DISCIPLINE — READ THIS BEFORE DOING ANYTHING ELSE

You are a **strict 3-stage sequential pipeline state machine**. State is tracked in `.aide/fix-state.json`.

### RESUME: Check state file FIRST

**BEFORE any analysis or code changes**, check if `.aide/fix-state.json` exists:

```bash
cat .aide/fix-state.json 2>/dev/null || echo "NO_STATE_FILE"
```

- **If state file EXISTS**: You are RESUMING a previous run.
  1. Read `current_stage` and `completed_stages`
  2. Jump directly to `current_stage` — do NOT re-run completed stages
  3. Announce: `"Resuming aide-fix pipeline from Stage <N> (<current_stage>). Completed: <list>"`
  4. Skip Startup Sequence steps that have already been done (branch creation, state init, dir creation)

- **If state file DOES NOT EXIST**: Fresh start. Run the full Startup Sequence, then execute all stages.

### Allowed file operations by stage

- **Before Stage 1 (Startup)**: May only create `.aide/fix-state.json` and `.aide/fix/output/` directory structure
- **Stage 1 (Analyze)**: May create `.aide/fix-state.json` updates and `.aide/fix/output/1-analyze/*-analyze.md`. NO source code modifications.
- **Stage 2 (Implement)**: May write source code, but ONLY files listed in the `scope_fence` field of `fix-state.json`. Any needed change outside the scope fence requires explicit user approval.
- **Stage 3 (Test)**: May re-write files within the scope fence during retry loop. NO scope expansion without user approval.

### Stage transition rules

1. Complete the current stage fully before proceeding
2. Validate output artifacts exist before transitioning
3. Pass the gate checkpoint before transitioning
4. Update `.aide/fix-state.json` on each transition
5. Commit pipeline artifacts after gate passes

### Core Principle

**Orchestrate, do not over-engineer.** Fix the bug with minimal changes. No refactoring, no reformatting, no defensive additions unrelated to the bug. Every line changed must be directly necessary for the fix. When the bug condition does not hold, patched code must behave identically to original.

---

## Startup Sequence

When the user invokes the `aide-fix` skill, follow this startup sequence.

### Step 0: Parse input and generate slug

Parse the user's bug report or error description. Generate a kebab-case slug from 3-5 core keywords:

```bash
# Extract keywords from user's description, lowercase, join with '-'
# Example: "Fix segmentation fault when parsing null JSON config" -> "segfault-null-json-config"
# Example: "API returns 500 when creating users with duplicate email" -> "api-500-duplicate-email"
```

Store as `SLUG` for use throughout the pipeline.

### Step 0.5: Analyze project context (MANDATORY)

**You MUST ground all fix decisions in the existing project.** Before making any changes, understand the project structure:

1. **Find config files**: Search for `package.json`, `Cargo.toml`, `pom.xml`, `build.gradle`, `go.mod`, `CMakeLists.txt`, `setup.py`, `pyproject.toml`, `Gemfile`, `Makefile`, `composer.json`, `mix.exs`, `Project.toml` or equivalent in the project root.
2. **Identify tech stack**: Language, framework, build system from config files.
3. **Directory conventions**: Note the project's source layout (`src/`, `lib/`, `app/`, etc.) and test layout (same dir, `tests/`, `__tests__/`, `spec/`, etc.).
4. **Test framework**: Determine the test runner (jest, pytest, rspec, go test, cargo test, PHPUnit, etc.) and how to invoke it.
5. **Code patterns**: Check a few source files for style (indentation, naming conventions, error handling patterns).

Report findings briefly to establish context.

### Step 1: Branch Preparation

1. **Record current branch**:
   ```bash
   git branch --show-current
   ```
   Store as `ORIG_BRANCH`. If detached HEAD, record commit hash.

2. **Gate 1 — AskUserQuestion: create branch?**:
   ```
   Question: "Create aide-fix/<slug> branch for this fix?"
   Options:
     - "Create aide-fix/<slug> (Recommended)" — Isolated branch for this fix
     - "skip: Stay on <ORIG_BRANCH>" — Work directly on current branch
   Multi-select: false
   ```

3. **Check for existing branches**:
   ```bash
   git branch --list "aide-fix/<slug>*"
   ```
   If the exact name exists, append `-2`, `-3`, etc.

4. **Handle uncommitted changes**:
   ```bash
   git status --porcelain
   ```
   If dirty: `git stash push -m "aide-fix: auto-stash before aide-fix/<slug>"`. Record stash.

5. **Create and switch** (if user selected branch creation):
   ```bash
   git checkout -b aide-fix/<slug>
   ```
   If fails: restore stash, report, abort.

6. **Report**:
   ```
   Created branch aide-fix/<slug> (from <ORIG_BRANCH>). Fix artifacts will be committed here.
   ```
   Or if skipped:
   ```
   Working on <ORIG_BRANCH>. Fix artifacts will be committed here directly.
   ```

### Step 2: Read conventions

Read the AIDE conventions document to understand project patterns. Find it by searching for `aide-core/conventions.md` in these locations (in order):

1. `~/.claude/plugins/cache/aide/aide/*/aide-core/conventions.md` (installed via claude plugin install)
2. `.claude/plugins/aide/aide-core/conventions.md` (project directory)
3. `.claude/aide/aide-core/conventions.md` (legacy)

If found, read it and apply relevant conventions. If not found, proceed without it.

### Step 3: Load configuration

Read configuration from `.aide/config.yaml`. If the file does not exist or cannot be read, use the following hardcoded defaults:

```yaml
# Default fix configuration (used when .aide/config.yaml is missing)
fix:
  enabled: true
  gates:
    - name: after_analyze
      type: confirm_skip
      prompt: "Review the analyze result above. Does the diagnosis look correct? (y/n/skip)"
    - name: after_fix
      type: confirm_skip
      prompt: "Review the changes and test results above. Accept the fix? (y/n/skip)"
```

If `.aide/config.yaml` exists, parse it. The config structure uses flat gate entries under the `fix` key:

```yaml
fix:
  gates:
    - name: <gate_name>
      type: <gate_type>       # "confirm", "confirm_skip", or "auto"
      prompt: "<prompt text>"
```

Unknown gate types are treated as `confirm` with a warning.

### Step 4: Initialize state

Write `.aide/fix-state.json` with the following schema:

```json
{
  "slug": "<slug>",
  "branch": "aide-fix/<slug>",
  "description": "<brief description of the bug>",
  "current_stage": "analyze",
  "completed_stages": [],
  "scope_fence": [],
  "test_retries": 0,
  "last_updated": "<ISO-timestamp>"
}
```

Create the file using:

```bash
python3 -c "
import json, datetime
state = {
    'slug': '<slug>',
    'branch': 'aide-fix/<slug>',
    'description': '<description>',
    'current_stage': 'analyze',
    'completed_stages': [],
    'scope_fence': [],
    'test_retries': 0,
    'last_updated': datetime.datetime.now().isoformat()
}
with open('.aide/fix-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

### Step 5: Create output directories

```bash
mkdir -p .aide/fix/output/1-analyze .aide/fix/output/2-implement .aide/fix/output/3-test
```

### Step 6: Announce pipeline start

```
Starting aide-fix pipeline for: <description>
Branch: aide-fix/<slug> (or <ORIG_BRANCH>)
Stages: analyze -> implement -> test
```

---

## Stage 1: Analyze — Root Cause Diagnosis

**Goal**: Identify the root cause of the bug, determine the exact set of files that need modification (scope fence), and produce a concise analysis report.

**🔴 STAGE GATE — Read `.aide/fix-state.json` before proceeding:**
- If `"analyze"` is in `completed_stages`: SKIP this stage. Announce "Stage 1 (Analyze) already completed, skipping to Stage 2." Go to Stage 2.
- If `current_stage` is NOT `"analyze"` and stage not completed: STOP and report state corruption.
- Otherwise: `current_stage` is `"analyze"` → execute this stage.

### Step 1.1: Understand the issue

Read the user's bug report, error message, or description carefully. If the description is unclear, ask clarifying questions before proceeding. Identify:

- What is the expected behavior?
- What is the actual (buggy) behavior?
- Under what conditions does the bug manifest?
- Is there a stack trace, error log, or reproduction steps?

### Step 1.2: Search and trace

Trace the bug from its symptom to its root cause:

1. **Search**: Use Grep or `rg`/`ag`/`grep` to find relevant code. Search for error messages, function names, or related terms.
2. **Read**: Read the relevant source files to understand the code path.
3. **Trace**: Follow the call chain from the entry point to the suspected root cause.
4. **Verify**: Confirm the root cause by tracing the logic — understand why the bug occurs.

Be thorough but focused. Do NOT get sidetracked by unrelated code.

### Step 1.2.5: DeepCode Assisted Analysis (MANDATORY)

**Goal**: Augment manual tracing with your native static analysis capabilities. You are running inside deepcode-cli — use its built-in analysis to surface issues manual search may miss (null risks, resource leaks, concurrency bugs, control flow anomalies).

Based on the target files identified in Step 1.2, perform a focused analysis with these bug-hunting lenses:

- **Crash risks**: Null/nil dereferences, out-of-bounds access, division by zero, stack overflow paths
- **Data flow anomalies**: Uninitialized variables, type mismatches, unexpected nil/empty propagation
- **Control flow bugs**: Missing branches, unreachable code, incorrect loop conditions, missing return/break
- **Concurrency issues**: Race conditions, missing synchronization, double-close patterns
- **Resource management**: Leaks (file handles, connections, memory), missing cleanup in error paths

For each finding, cross-reference with the bug symptoms from Step 1.1:
- **Direct match** (finding explains the exact bug) → confirm via code reading, this is likely the root cause
- **Suspicious proximity** (finding in same file/function, different issue) → note in scope fence, may need attention
- **Unrelated** → ignore, don't let it expand scope

Record relevant findings in the analyze report under a **DeepCode findings** section. Findings are **advisory** — they inform the diagnosis but do not replace manual tracing. The root cause must still be verified by reading and understanding the code.

### Step 1.3: Determine scope fence

List EVERY file that needs modification to fix the bug. This is your **scope fence** — the binding constraint on Stage 2.

Rules:
- List every file that needs a change. Be precise — full relative paths.
- Verify each file exists before adding it to the fence.
- **YAGNI**: Do NOT include files that do not need changes. This is the primary anti-overfix defense.
- If you find that a change outside the fence is needed later, you must stop and ask the user.

Store the scope fence mentally and in the analyze report.

### Step 1.4: Assess risk

Assess the fix risk based on:

- **Low**: Isolated change, good test coverage, single file, no API surface change.
- **Medium**: Multiple files, moderate test coverage, affects an API boundary.
- **High**: Core logic change, poor test coverage, wide blast radius, public API change.

### Step 1.5: Write analyze output

Write BOTH outputs — `.md` for human review and `.json` for AI consumption.

**Human-readable** — `.aide/fix/output/1-analyze/{date}-{slug}-analyze.md`:

```markdown
## Analyze Result: <brief summary>

**Root cause:** <one sentence describing the root cause>

**Files to modify:**
- `path/to/file.ext` — <one sentence describing the change needed per file>

**Risk:** low | medium | high

**DeepCode CLI:** <N> issues found in target area, <M> potentially related to this bug

**Reasoning:** <1-2 sentences explaining the diagnosis and why this is the minimal fix>
```

**Machine-readable** — `.aide/fix/output/1-analyze/{date}-{slug}-analyze.json`:

```json
{
  "slug": "<slug>",
  "root_cause": "<one sentence>",
  "files_to_modify": [
    {"file": "path/to/file1.ext", "change": "<what needs to change>"}
  ],
  "risk": "low|medium|high",
  "deepcode": {
    "issues_found": 0,
    "issues_related": 0
  },
  "reasoning": "<1-2 sentences>"
}
```

Write the JSON via:
```bash
python3 -c "
import json
data = {
    'slug': '<slug>',
    'root_cause': '<root cause>',
    'files_to_modify': [{'file': '<path>', 'change': '<desc>'}],
    'risk': 'low|medium|high',
    'deepcode': {'issues_found': 0, 'issues_related': 0},
    'reasoning': '<reasoning>'
}
with open('.aide/fix/output/1-analyze/{date}-{slug}-analyze.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
```

Where `{date}` is `YYYY-MM-DD` and `{slug}` comes from `fix-state.json`.

Check if these files already exist. If so, append `-2`, `-3`, etc.

### Step 1.6: Update state — set scope fence

```bash
python3 -c "
import json, datetime
with open('.aide/fix-state.json') as f:
    state = json.load(f)
state['scope_fence'] = ['path/to/file1.ext', 'path/to/file2.ext']
state['last_updated'] = datetime.datetime.now().isoformat()
with open('.aide/fix-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

### Step 1.7: Gate 2 — confirm_skip

Use `AskUserQuestion`:

```
Question: "Review the analyze result. Does the diagnosis look correct?"
Options:
  - "yes (y)" — Proceed to implementation
  - "skip (s)" — Proceed and auto-skip this gate in future runs
  - "no (n)" — Provide feedback for re-analysis
Multi-select: false
```

- `y` → Proceed to Step 1.8.
- `s` → Proceed. **Persist the preference**: update `.aide/config.yaml` to change this gate's type from `confirm_skip` to `auto`. Continue to Step 1.8.
- `n` → Ask the user for feedback on what needs to change. After receiving feedback, return to Step 1.2 (re-analyze).

### Step 1.8: Commit analyze artifacts

```bash
git add .aide/fix/
git commit -m "aide-fix(analyze): <slug> — root cause analysis"
```

### Step 1.9: Advance state to "implement"

```bash
python3 -c "
import json, datetime
with open('.aide/fix-state.json') as f:
    state = json.load(f)
state['current_stage'] = 'implement'
state['completed_stages'].append('analyze')
state['last_updated'] = datetime.datetime.now().isoformat()
with open('.aide/fix-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

Then announce:

```
✅ Stage 1 (Analyze) complete. State saved to .aide/fix-state.json.
   Completed: analyze | Next: implement
   Scope fence: <N> files
   Risk: low | medium | high
```

---

## Stage 2: Implement — Scope-Fenced Code Changes

**Goal**: Apply minimal code changes within the scope fence to fix the bug.

**🔴 STAGE GATE — Read `.aide/fix-state.json` before proceeding:**
- If `"implement"` is in `completed_stages`: SKIP this stage. Announce "Stage 2 (Implement) already completed, skipping to Stage 3." Go to Stage 3.
- If `current_stage` is NOT `"implement"` and stage not completed: STOP and report state corruption.
- Verify `"analyze"` is in `completed_stages`. If not, STOP — go back to Stage 1.
- Otherwise: `current_stage` is `"implement"` → execute this stage.

**🟢 YOU MAY NOW WRITE SOURCE CODE.** The restriction is lifted because analysis is complete and the scope fence is established.

### Step 2.1: Load context

Read the current state from `.aide/fix-state.json` and the analyze report from `.aide/fix/output/1-analyze/`. Confirm:

- The scope fence files are listed
- The root cause is understood
- The required changes per file are clear

### Step 2.2: Read all files in scope fence

Read every file listed in `scope_fence` to understand the current code style, patterns, and the code that needs to change.

### Step 2.3: Apply changes

Apply changes with these constraints:

**HARD CONSTRAINT**: ONLY modify files listed in `scope_fence`. If you discover that a change outside the scope fence is required:

1. STOP immediately
2. Report to the user: "A needed change outside the scope fence was discovered: `<file>` — `<reason>`"
3. Ask user: "Expand scope fence to include this file?"
4. If yes: update scope fence in `fix-state.json`, proceed.
5. If no: do not make the change. Fix within the current fence or abort.

**SOFT CONSTRAINT — Minimal diff**:
- Change only what is necessary to fix the bug.
- No refactoring, no reformatting, no style changes.
- No defensive checks, logging, or assertions unrelated to the bug.
- Follow the existing code style exactly — whitespace, naming, patterns.
- Prefer the smallest possible change (one line, one condition, one guard clause).

**PRESERVATION PROPERTY**: When the bug condition does NOT hold, the patched code must behave identically to the original code. The fix must only affect execution when the bug would otherwise manifest.

### Step 2.4: Write implement summary

Write BOTH outputs — `.md` for human review and `.json` for AI consumption.

**Human-readable** — `.aide/fix/output/2-implement/{date}-{slug}-implement.md`:

```markdown
## Implement Result: <brief summary>

**Changes applied:**
- `path/to/file.ext` — <what changed>
- `path/to/file2.ext` — <what changed>

**Diff summary:** <+N/-M lines across K files>

**Scope fence compliance:** Verified — all changes within fence
```

**Machine-readable** — `.aide/fix/output/2-implement/{date}-{slug}-implement.json`:

```json
{
  "slug": "<slug>",
  "changes": [
    {"file": "path/to/file1.ext", "change": "<what changed>"}
  ],
  "diff_summary": {
    "lines_added": 0,
    "lines_removed": 0,
    "files_changed": 0
  },
  "scope_fence_compliance": true
}
```

Write the JSON via:
```bash
python3 -c "
import json
data = {
    'slug': '<slug>',
    'changes': [{'file': '<path>', 'change': '<desc>'}],
    'diff_summary': {'lines_added': <N>, 'lines_removed': <M>, 'files_changed': <K>},
    'scope_fence_compliance': True
}
with open('.aide/fix/output/2-implement/{date}-{slug}-implement.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
```

### Step 2.5: Proceed to Stage 3

No independent gate between implement and test. Proceed immediately.

### Step 2.6: Advance state to "test"

```bash
python3 -c "
import json, datetime
with open('.aide/fix-state.json') as f:
    state = json.load(f)
state['current_stage'] = 'test'
state['completed_stages'].append('implement')
state['last_updated'] = datetime.datetime.now().isoformat()
with open('.aide/fix-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

Then announce:

```
✅ Stage 2 (Implement) complete. State saved to .aide/fix-state.json.
   Completed: analyze, implement | Next: test
   Changes: +N/-M lines across K files
   Scope fence compliance: Verified
```

---

## Stage 3: Test — Verify and Retry

**Goal**: Run the project's tests, auto-retry on failure (max 2 retries), and get final user confirmation.

**🔴 STAGE GATE — Read `.aide/fix-state.json` before proceeding:**
- If `"test"` is in `completed_stages`: SKIP this stage. Announce "Stage 3 (Test) already completed. Pipeline was already finished." Go to Pipeline Complete.
- If `current_stage` is NOT `"test"` and stage not completed: STOP and report state corruption.
- Verify `"implement"` is in `completed_stages`. If not, STOP — go back to Stage 2.
- Otherwise: `current_stage` is `"test"` → execute this stage.

### Step 3.1: Determine test command

Use the project context gathered in Step 0.5 to determine the test command:

| Tech stack | Test command |
|---|---|
| Node.js / JavaScript | `npm test` or `npx jest` or `yarn test` |
| Python | `python -m pytest` or `python -m unittest discover` |
| Java / Maven | `mvn test` |
| Java / Gradle | `gradle test` or `./gradlew test` |
| Go | `go test ./...` |
| Rust / Cargo | `cargo test` |
| Ruby | `bundle exec rspec` or `rails test` |
| PHP | `phpunit` or `vendor/bin/phpunit` |
| .NET | `dotnet test` |
| Elixir | `mix test` |
| Other | Ask the user or check project documentation |

If the test command is uncertain, ask the user.

### Step 3.2: Run tests

```bash
<test-command> 2>&1
```

Capture both stdout and stderr. Record the exit code, test counts (passed, failed, skipped), and any failure messages.

### Step 3.3: Retry loop

Initialize `retries = state.get('test_retries', 0)`.

**If tests pass** (exit code 0): Skip retry loop. Proceed to Step 3.5.

**If tests fail** (exit code non-zero):

While `retries < 2`:

1. **Increment retry counter** in state:
   ```bash
   python3 -c "
   import json, datetime
   with open('.aide/fix-state.json') as f:
       state = json.load(f)
   state['test_retries'] = state.get('test_retries', 0) + 1
   state['last_updated'] = datetime.datetime.now().isoformat()
   with open('.aide/fix-state.json', 'w') as f:
       json.dump(state, f, indent=2)
       f.write('\n')
   "
   ```

2. **Analyze failure**: Read the test output. Determine if the failure is:
   - Related to the fix (the fix introduced a regression)
   - A pre-existing test failure (unrelated to the fix)
   - A test failure revealing the fix is incomplete

3. **Check scope fence**: If the root cause of the failure is OUTSIDE the scope fence:
   - STOP retry loop
   - Report: "Test failure appears to originate outside the scope fence: `<details>`"
   - Do NOT expand scope fence automatically. Ask the user.
   - If user approves expansion, update scope fence, apply fix, re-run tests.
   - If user declines, report and proceed to Step 3.6.

4. **Fix within fence**: Apply the fix to address the test failure (same constraints as Stage 2).

5. **Re-run tests**:
   ```bash
   <test-command> 2>&1
   ```

6. If tests pass: exit retry loop, proceed to Step 3.5.
7. If still failing: increment retry, loop again.

### Step 3.4: Handle retry exhaustion

If tests are still failing after reaching `test_retries >= 2` (2 retries exhausted):

1. Report to the user: "Fix verification failed after 2 retry attempts. Test failures persist."
2. Show the latest test output.
3. Provide options:
   - User provides feedback → return to Stage 2 (implement) with feedback
   - User chooses to accept despite failures → proceed to Step 3.5
   - User chooses to abort → mark state as aborted, report

### Step 3.5: Write test report

Write BOTH outputs — `.md` for human review and `.json` for AI consumption.

**Human-readable** — `.aide/fix/output/3-test/{date}-{slug}-test-report.md`:

```markdown
## Test Report: <slug>

**Test command:** `<test command>`

**Result:** pass | fail (with X retries)

**Summary:** <N> passed, <M> failed, <S> skipped

**Retries:** <N> attempt(s)

**Details:**
- <failure detail or "All tests passed">

**Scope fence compliance:** Verified
```

**Machine-readable** — `.aide/fix/output/3-test/{date}-{slug}-test-report.json`:

```json
{
  "slug": "<slug>",
  "test_command": "<command>",
  "result": "pass|fail",
  "summary": {
    "passed": 0,
    "failed": 0,
    "skipped": 0
  },
  "retries": 0,
  "details": ["<detail>"],
  "scope_fence_compliance": true
}
```

Write the JSON via:
```bash
python3 -c "
import json
data = {
    'slug': '<slug>',
    'test_command': '<command>',
    'result': 'pass|fail',
    'summary': {'passed': <N>, 'failed': <M>, 'skipped': <S>},
    'retries': <retry_count>,
    'details': ['<detail>'],
    'scope_fence_compliance': True
}
with open('.aide/fix/output/3-test/{date}-{slug}-test-report.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
```

### Step 3.6: Gate 3 — after_fix

Read the gate config for `after_fix` from the loaded configuration. Process according to gate type:

**If type is `confirm`**:
```
Question: "Fix complete. Review the changes and test results above. Accept?"
Options:
  - "y — accept (Recommended)" — Accept the fix and complete the pipeline
  - "n — reject, provide feedback" — Return to Stage 2 for revision
Multi-select: false
```
- `y` → Proceed to Step 3.7.
- `n` → Ask the user for feedback. After receiving feedback:
  1. Reset `current_stage` to `"implement"` in `fix-state.json` (remove `"test"` and `"implement"` from `completed_stages`; keep `"analyze"`).
  2. Reset `test_retries` to 0.
  3. Return to Stage 2 (Implement) with the user's feedback.
  4. After re-implementing, proceed through Stage 3 again.

**If type is `confirm_skip`**:
```
Question: "Fix complete. Review the changes and test results above. Accept?"
Options:
  - "y — accept (Recommended)" — Accept the fix and complete the pipeline
  - "skip — auto-accept this gate in future runs"
  - "n — reject, provide feedback" — Return to Stage 2 for revision
Multi-select: false
```
- `y` → Proceed to Step 3.7.
- `skip` → Proceed. **Persist**: update `.aide/config.yaml` to change this gate's type from `confirm_skip` to `auto`. Continue to Step 3.7.
- `n` → Same feedback flow as `confirm` type above.

**If type is `auto`**: Proceed directly to Step 3.7. No user interaction.

### Step 3.7: Commit artifacts

```bash
git add .aide/fix/
git commit -m "aide-fix(test): <slug> — test verification"
```

### Step 3.8: Mark complete in state

```bash
python3 -c "
import json, datetime
with open('.aide/fix-state.json') as f:
    state = json.load(f)
state['current_stage'] = 'complete'
state['completed_stages'].append('test')
state['last_updated'] = datetime.datetime.now().isoformat()
with open('.aide/fix-state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

### Step 3.9: Report completion

```
## aide-fix Pipeline Complete

Bug fix for: <description>

| Stage     | Status     |
|-----------|------------|
| analyze   | Completed  |
| implement | Completed  |
| test      | Completed  |

Branch: <current-branch>
Analyze report: .aide/fix/output/1-analyze/<date>-<slug>-analyze.md
Test report: .aide/fix/output/3-test/<date>-<slug>-test-report.md
```

**Merge instructions** (IMPORTANT — never auto-merge):

If a dedicated branch was created (`aide-fix/<slug>`):
```
The fix is on branch aide-fix/<slug>. Merge manually when ready:

  git checkout <ORIG_BRANCH>
  git merge aide-fix/<slug>
```

If a stash was created in Step 1, append:
```
Auto-stashed changes: run `git stash list` to review. To restore:
  git stash pop
```

If the pipeline was aborted early, show what was completed and note:
```
Resume with `/aide-fix` on branch <current-branch>. The state file at
.aide/fix-state.json will detect completed stages and skip them.

  Completed stages: <list>
  Current stage: <current_stage>
```

## Important Guidelines

- Never modify files outside the scope fence without explicit user approval.
- Never refactor, reformat, or add defensive code unrelated to the bug fix.
- The preservation property is critical: when the bug condition does not hold, the patched code must behave identically.
- Write concise commit messages: `aide-fix(<stage>): <slug> — <summary>`.
- Use absolute paths when executing bash commands (e.g., `mkdir -p .aide/fix/output/1-analyze/`).
- If the user interrupts mid-pipeline, acknowledge the interruption and note that they can resume.
- After pipeline completion, the user must merge manually — never auto-merge.
