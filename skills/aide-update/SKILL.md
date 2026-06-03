---
name: aide-update
description: >-
  Update AIDE to the latest version via claude plugin update with project scope
  priority. Safe to run anytime.
---

# aide-update — Update AIDE

You update the AIDE installation in a business project. AIDE defaults to project scope — try project-scoped update first, then fall back to user scope.

## Process

### Step 1: Update the plugin

Try project scope first, fall back to user scope:

```bash
claude plugin update aide --scope project 2>/dev/null || claude plugin update aide
```

If both fail (e.g., network error), report the error and stop.

### Step 2: Re-bootstrap config

Invoke the aide-init skill to sync `.aide/` and config template:

```
Use the Skill tool to invoke aide-init
```

### Step 3: Report

Show what changed:

```
AIDE updated to latest.
  Plugin               — updated via claude plugin update (project scope)
  .aide/config.yaml     — up to date (or: updated via aide-init)
```

## Important Guidelines

- Always try `--scope project` first — AIDE is installed as a project plugin by default.
- If the user is mid-pipeline (on an `aide/*` branch), warn them but proceed — updating AIDE won't affect their current branch's pipeline state.
- A restart of Claude Code may be required for updated skills to take effect.
