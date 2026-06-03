---
name: aide-update
description: >-
  Update AIDE to the latest version via claude plugin update. Safe to run anytime.
---

# aide-update — Update AIDE

You update the AIDE installation in a business project. Your job is to run `claude plugin update aide` and then re-bootstrap config via `/aide-init`.

## Process

### Step 1: Update the plugin

```bash
claude plugin update aide
```

If this fails (e.g., network error), report the error and stop.

### Step 2: Re-bootstrap config

Invoke the aide-init skill to sync `.aide/` and config template:

```
Use the Skill tool to invoke aide-init
```

### Step 3: Report

Show what changed:

```
AIDE updated to latest.
  Plugin               — updated via claude plugin update
  .aide/config.yaml     — up to date (or: updated via aide-init)
```

## Important Guidelines

- Always run `claude plugin update aide` before invoking aide-init. Never skip the update.
- If the user is mid-pipeline (on an `aide/*` branch), warn them but proceed — updating AIDE won't affect their current branch's pipeline state.
- A restart of Claude Code may be required for updated skills to take effect.
