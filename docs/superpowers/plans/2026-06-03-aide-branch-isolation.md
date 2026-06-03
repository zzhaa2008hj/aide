# AIDE Branch Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add automatic branch-per-workflow isolation — each new `/aide` pipeline creates an `aide/<slug>` branch from HEAD, auto-stashes dirty working trees, and keeps pipeline artifacts off the user's working branch.

**Architecture:** Two files changed. `aide-core/conventions.md` gets branch naming rules in its Git section. `skills/aide/skill.md` gets a new "Branch Preparation" block inserted before the existing Startup Sequence, plus branch info in the Completion Report.

**Tech Stack:** Markdown (skill prompt), bash (git commands)

---

## File Map

| File | Responsibility |
|------|---------------|
| `aide-core/conventions.md` | Git 节追加分支命名规范 `aide/<slug>` |
| `skills/aide/skill.md` | 新流程：分支准备步骤；--continue：分支验证；完成报告：分支信息 |

---

### Task 1: Update conventions.md — add branch naming rules

**Files:**
- Modify: `aide-core/conventions.md`

- [ ] **Step 1: Append branch naming convention to Git section**

The current Git section in `conventions.md` ends with:

```markdown
Business code changes are never auto-committed. Working-tree changes outside `.aide/` produce a warning but do not block the commit.
```

Replace that final paragraph with:

```markdown
Business code changes are never auto-committed. Working-tree changes outside `.aide/` produce a warning but do not block the commit.

## Branch Isolation

Each new AIDE pipeline run creates a dedicated branch to isolate workflow artifacts from the user's working branch:

- **Naming**: `aide/<slug>` where `<slug>` is a short kebab-case identifier derived from the feature description (e.g., `aide/user-login-oauth`)
- **Base**: The branch is created from the current `HEAD`
- **Auto-stash**: If the working tree has uncommitted changes, they are stashed before branch creation with message `AIDE: auto-stash before aide/<slug>`
- **--continue**: Recovery runs reuse the existing `aide/*` branch — no new branch is created
- **Post-pipeline**: The branch is left as-is; merging back is a manual user decision
```

- [ ] **Step 2: Verify the change**

```bash
grep -A 8 "Branch Isolation" aide-core/conventions.md
```

Expected: Shows the new section.

- [ ] **Step 3: Commit**

```bash
git add aide-core/conventions.md
git commit -m "docs: add branch isolation conventions to aide-core"
```

---

### Task 2: Update orchestrator — add Branch Preparation to Startup Sequence

**Files:**
- Modify: `skills/aide/skill.md`

- [ ] **Step 1: Insert Branch Preparation section before existing Step 1**

In `skills/aide/skill.md`, find the `## Startup Sequence` section header. Insert a new `### Step 0: Branch Preparation` section **before** `### Step 1: Read conventions`. The existing Step 1 becomes the first step after branch preparation completes.

Replace the entire `## Startup Sequence` section with the updated version below.

Old text to replace (from `## Startup Sequence` through the end of Step 5):

```
## Startup Sequence

When the user invokes the `aide` skill, follow this startup sequence:

### Step 1: Read conventions

Read the AIDE conventions document at `.claude/aide/aide-core/conventions.md` (relative to the business project root, which is the current working directory). This establishes the directory layout, stage order, and git conventions.

### Step 2: Determine business project root
...
```

New text (insert Step 0 before Step 1):

```markdown
## Startup Sequence

When the user invokes the `aide` skill, follow this startup sequence.

### Step 0: Branch Preparation (new pipeline) or Branch Validation (--continue)

**If the user passed `--continue`:**

1. Get the current branch name:
   ```bash
   git branch --show-current
   ```
2. If the current branch does NOT start with `aide/`:
   - Report: "`--continue` requires you to be on an `aide/*` branch. Current branch: `<name>`. Please switch to the correct branch and try again."
   - Abort.
3. If the current branch IS an `aide/*` branch:
   - Report: "Resuming pipeline on branch `<current-branch>`."
   - Skip the rest of Step 0 and proceed to Step 1.

**If this is a new pipeline (no `--continue`):**

1. **Generate a slug** from the user's requirement description. Follow these rules:
   - Extract 3-5 core keywords, convert to lowercase, join with `-`
   - Use only letters, numbers, and hyphens
   - Example: `"Add user login with OAuth support"` → `user-login-oauth`
   - Example: `"Build a REST API for orders"` → `rest-api-orders`

2. **Construct the branch name**: `aide/<slug>`

3. **Check for existing branches with the same name**:
   ```bash
   git branch --list "aide/<slug>*"
   ```
   - If the exact name exists, append `-2`, `-3`, etc. until a free name is found.
   - Example: `aide/user-login-oauth` exists → try `aide/user-login-oauth-2`, then `aide/user-login-oauth-3`, etc.

4. **Record the original branch**:
   ```bash
   git branch --show-current
   ```
   Store this as `ORIG_BRANCH`. If the user is in detached HEAD state, record the commit hash instead.

5. **Check for uncommitted changes**:
   ```bash
   git status --porcelain
   ```
   - If there are uncommitted changes (dirty working tree):
     ```bash
     git stash push -m "AIDE: auto-stash before aide/<slug>"
     ```
     Record that a stash was created so it can be reported later.
   - If stash fails, report the error and abort.

6. **Create and switch to the new branch**:
   ```bash
   git checkout -b aide/<slug>
   ```
   - If this fails: restore the stash (if one was created) with `git stash pop`, report the error, and abort.

7. **Report**:
   ```
   Created branch aide/<slug> (from <ORIG_BRANCH>). Pipeline artifacts will be committed here.
   ```
   If a stash was created:
   ```
   Uncommitted changes stashed. Restore with: git stash pop
   ```

### Step 1: Read conventions

Read the AIDE conventions document at `.claude/aide/aide-core/conventions.md` (relative to the business project root, which is the current working directory). This establishes the directory layout, stage order, and git conventions.

### Step 2: Determine business project root
...
```

- [ ] **Step 2: Verify the inserted section exists**

```bash
grep -c "Step 0: Branch Preparation" skills/aide/skill.md
```

Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add skills/aide/skill.md
git commit -m "feat(aide): add branch preparation step to orchestrator startup"
```

---

### Task 3: Update orchestrator — add branch info to Completion Report

**Files:**
- Modify: `skills/aide/skill.md`

- [ ] **Step 1: Update the Completion Report section**

Find the `## Completion Report` section. Replace the existing table template with the version that includes branch/stash info.

Old text to replace:

```
## Completion Report

After all enabled stages have completed (or the pipeline was aborted), present a summary:

```
## AIDE Pipeline Complete

| Stage   | Status     | Commit                                   |
|---------|------------|------------------------------------------|
| spec    | Completed  | abc1234 (aide(spec): add auth spec)      |
| plan    | Skipped    | —                                        |
| implement | Skipped  | —                                        |
| test    | Skipped    | —                                        |

Pipeline artifacts are in .aide/output/.
```

If aborted early, show what was completed and note: "Resume with `/aide --continue`."
```

Replace with:

```markdown
## Completion Report

After all enabled stages have completed (or the pipeline was aborted), present a summary:

```
## AIDE Pipeline Complete

| Stage   | Status     | Commit                                   |
|---------|------------|------------------------------------------|
| spec    | Completed  | abc1234 (aide(spec): add auth spec)      |
| plan    | Skipped    | —                                        |
| implement | Skipped  | —                                        |
| test    | Skipped    | —                                        |

Branch: aide/<slug>
Original branch: <ORIG_BRANCH>

Next steps:
  git checkout <ORIG_BRANCH> && git merge aide/<slug>
```

If a stash was created in Step 0, append:

```
Auto-stashed changes: run `git stash list` to review.
```

If aborted early, show what was completed and note: "Resume on branch `aide/<slug>` with `/aide --continue`."
```

- [ ] **Step 2: Verify the updated section**

```bash
grep -A 5 "Branch:" skills/aide/skill.md
```

Expected: Shows the branch info lines in the completion report template.

- [ ] **Step 3: Commit**

```bash
git add skills/aide/skill.md
git commit -m "feat(aide): add branch info to completion report"
```

---

### Task 4: End-to-end verification

- [ ] **Step 1: Verify conventions.md is complete**

```bash
grep -c "Branch Isolation" aide-core/conventions.md
```

Expected: `1`

- [ ] **Step 2: Verify aide skill has all branch-related content**

```bash
grep -c "Step 0" skills/aide/skill.md
grep -c "ORIG_BRANCH" skills/aide/skill.md
grep -c "git stash push" skills/aide/skill.md
grep -c "checkout -b aide" skills/aide/skill.md
```

Expected: all return at least `1`

- [ ] **Step 3: Verify orchestrator skill frontmatter is still valid**

```bash
head -5 skills/aide/skill.md
```

Expected: YAML frontmatter with `name: aide` and `description:`.

- [ ] **Step 4: Verify no broken references in the orchestrator**

Read through the file once to confirm no orphaned references to deleted content.

- [ ] **Step 5: Manual test — clean workspace new pipeline**

In a business project with AIDE configured:

```bash
git checkout feature/some-branch
/aide "test branch isolation"
```

Verify:
- Branch `aide/test-branch-isolation` is created
- `.aide/` commits land on the new branch
- Original branch has no `.aide/` commits

- [ ] **Step 6: Manual test — dirty workspace**

```bash
echo "temp" >> some-file.txt
/aide "dirty workspace test"
```

Verify:
- Stash is created with message "AIDE: auto-stash before aide/dirty-workspace-test"
- Pipeline runs on the new branch
- Completion report mentions the stash

- [ ] **Step 7: Manual test — --continue from wrong branch**

```bash
git checkout main
/aide --continue
```

Verify: Error message says you must be on an `aide/*` branch.

- [ ] **Step 8: Commit verification results**

```bash
git add -A
git commit -m "test: manual E2E verification of branch isolation"
```
```

---

## Self-Review

1. **Spec coverage**:
   - Branch naming `aide/<slug>` → Task 1 conventions, Task 2 Step 0.2
   - New pipeline creates branch → Task 2 Step 0 (steps 1-7)
   - --continue reuses branch → Task 2 Step 0 (first block)
   - Base from HEAD → Task 1 conventions, Task 2 Step 0.6
   - Dirty workspace → stash → Task 2 Step 0.5
   - Completion report → Task 3
   - Slug generation (LLM) → Task 2 Step 0.1
   - Branch conflict → append -2 → Task 2 Step 0.3
   - Error handling (stash fail, checkout fail, --continue wrong branch) → Task 2 Step 0

2. **Placeholder scan**: No TBD, TODO, or incomplete steps. All code is concrete.

3. **Type consistency**: `ORIG_BRANCH` used consistently across Task 2 and Task 3. Slug rules match spec.
