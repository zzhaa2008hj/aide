---
name: aide-update
description: >-
  Update AIDE to the latest version. Refreshes marketplace definition first,
  then updates the plugin. Safe to run anytime.
---

# aide-update — Update AIDE

You update the AIDE installation in a business project. The update requires two steps: refresh the marketplace to get the latest plugin definition, then update the plugin itself.

## Process

### Step 1: Refresh marketplace

This pulls the latest `marketplace.json` from the AIDE source repo:

```bash
claude plugin marketplace update aide
```

If this fails (e.g., network error), report the error and stop.

### Step 2: Update the plugin

```bash
claude plugin update aide@aide --scope project
```

This checks the refreshed marketplace definition and pulls the latest plugin code if a newer version is available.

If already at the latest version, report that and skip the remaining steps.

### Step 3: Re-bootstrap config

Invoke the aide-init skill to sync `.aide/` and config template:

```
Use the Skill tool to invoke aide-init
```

### Step 4: Report

Show what changed:

```
AIDE updated to latest.
  Marketplace           — refreshed from source
  Plugin                — updated to <version>
  .aide/config.yaml     — up to date (or: updated via aide-init)

Restart Claude Code for updated skills to take effect.
```

## Important Guidelines

- Always refresh the marketplace BEFORE updating the plugin. The marketplace contains the version info.
- If the user is mid-pipeline (on an `aide/*` branch), warn them but proceed — updating AIDE won't affect their current branch's pipeline state.
- A restart of Claude Code is required for updated skills to take effect.
