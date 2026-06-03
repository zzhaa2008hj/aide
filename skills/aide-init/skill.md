---
name: aide-init
description: >-
  AIDE initialization: sets up .aide/ directory, copies config templates, and
  configures CLAUDE.md with extra_skill_dirs. Safe to run repeatedly — skips
  already-configured steps.
---

# aide-init — AIDE Project Initialization

You initialize a business project for AIDE usage. Your job is to set up the `.aide/` directory, copy configuration templates, and ensure `CLAUDE.md` has the required `extra_skill_dirs` entry. Every step is idempotent — safe to run on an already-initialized project.

## Process

Follow these steps in order.

### Step 1: Determine paths

The business project root is the current working directory (`$CWD`). All paths are relative to it:

- AIDE installation: `.claude/aide/`
- Templates: `.claude/aide/templates/`
- Output directory: `.aide/`
- Config file: `.aide/config.yaml`
- Project CLAUDE.md: `./CLAUDE.md`

### Step 2: Create .aide/ directory

```bash
mkdir -p .aide/
```

### Step 3: Copy config template

Check if `.aide/config.yaml` already exists. If it does, skip this step and report: "`.aide/config.yaml` already exists, skipping."

If it does not exist:

```bash
cp .claude/aide/templates/aide.config.yaml .aide/config.yaml
```

Report: "Created `.aide/config.yaml` from template."

### Step 4: Ensure extra_skill_dirs in CLAUDE.md

This step ensures `CLAUDE.md` contains:

```yaml
extra_skill_dirs: [.claude/aide/skills]
```

Handle three cases:

**Case A — CLAUDE.md does not exist:**

Create `CLAUDE.md` with the following content:

```
extra_skill_dirs: [.claude/aide/skills]
```

Report: "Created `CLAUDE.md` with AIDE skill directory configured."

**Case B — CLAUDE.md exists but does NOT contain `extra_skill_dirs`:**

Append this line to the end of the file:

```
extra_skill_dirs: [.claude/aide/skills]
```

If the file does not end with a trailing newline, add one before this line.

Report: "Added `extra_skill_dirs` to existing `CLAUDE.md`."

**Case C — CLAUDE.md exists and already contains `extra_skill_dirs`:**

Check whether `.claude/aide/skills` is already in the list:

- If it is → report: "`CLAUDE.md` already configured with AIDE skill directory, skipping."
- If it is not → the file has `extra_skill_dirs` pointing elsewhere (e.g., `extra_skill_dirs: [.claude/other]`). Append `.claude/aide/skills` to the existing list:

  Before: `extra_skill_dirs: [.claude/other]`
  After:  `extra_skill_dirs: [.claude/other, .claude/aide/skills]`

  Use Edit to perform this replacement. Report: "Added `.claude/aide/skills` to existing `extra_skill_dirs` in `CLAUDE.md`."

### Step 5: Summary

Report a summary of what was done:

```
AIDE initialization complete:

  .aide/                    — created (or: already exists)
  .aide/config.yaml         — created from template (or: already exists, skipped)
  CLAUDE.md                — created with extra_skill_dirs (or: updated, or: already configured)
```

## Important Guidelines

- Every step is idempotent. Never overwrite existing user content in CLAUDE.md — only add what's missing.
- Use absolute paths or paths relative to the business project root (cwd) consistently.
- If any step fails, report the error clearly and stop. Do not leave the project in a half-initialized state.
- The AIDE installation must already exist at `.claude/aide/` before running init. If it doesn't, tell the user to run the submodule setup first:
  ```
  git submodule add <AIDE-repo-url> .claude/aide
  git -C .claude/aide submodule update --init --recursive
  ```
