---
name: aide-update
description: >-
  Update AIDE to the latest version: pulls the .claude/aide submodule and
  re-runs bootstrap init to sync configuration. Safe to run anytime.
---

# aide-update — Update AIDE

You update the AIDE installation in a business project. Your job is to pull the latest AIDE code from the submodule and re-run the bootstrap init to sync any new configuration.

## Process

### Step 1: Pull the submodule

```bash
git -C .claude/aide pull origin master
```

If this fails (e.g., network error, merge conflict), report the error and stop.

### Step 2: Re-run bootstrap init

```bash
bash .claude/aide/aide-core/scripts/init.sh
```

This is the same idempotent bootstrap script used during initial install. It syncs `.aide/config.yaml` template changes and ensures `.claude/aide/skills` is registered via `extraSkillDirs` in settings.

### Step 3: Report

Show what changed:

```
AIDE updated to <new-commit-short>.
  .aide/config.yaml         — up to date (or: updated)
  .claude/settings.local.json — up to date (or: updated extraSkillDirs)
```

If the working tree has uncommitted changes in `.claude/aide/` after the pull, warn the user:
"Warning: uncommitted changes in .claude/aide/. This may indicate a merge conflict. Review with `git -C .claude/aide status`."

## Important Guidelines

- Always pull before running init.sh. Never skip the pull.
- If the user is mid-pipeline (on an `aide/*` branch), warn them but proceed — updating AIDE won't affect their current branch's pipeline state.
