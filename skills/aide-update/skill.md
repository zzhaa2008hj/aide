---
name: aide-update
description: >-
  Update AIDE to the latest version via claude plugin update. Safe to run anytime.
---

# aide-update — Update AIDE

You update the AIDE installation in a business project. Your job is to run `claude plugin update aide` and re-run bootstrap init.

## Process

### Step 1: Update the plugin

```bash
claude plugin update aide
```

If this fails (e.g., network error), report the error and stop.

### Step 2: Re-run bootstrap init

Locate the updated AIDE installation and run init.sh:

```bash
# Find AIDE and run init
AIDE_DIR=$(find ~/.claude/plugins/cache/aide -name "skill.md" -path "*/skills/aide/*" 2>/dev/null | head -1 | sed 's|/skills/aide/skill.md||')
if [ -n "$AIDE_DIR" ] && [ -f "$AIDE_DIR/aide-core/scripts/init.sh" ]; then
    bash "$AIDE_DIR/aide-core/scripts/init.sh"
fi
```

This syncs `.aide/config.yaml` template changes.

### Step 3: Report

Show what changed:

```
AIDE updated to latest.
  .aide/config.yaml     — up to date (or: updated)
```

## Important Guidelines

- Always run `claude plugin update aide` before running init.sh. Never skip the update.
- If the user is mid-pipeline (on an `aide/*` branch), warn them but proceed — updating AIDE won't affect their current branch's pipeline state.
- A restart of Claude Code may be required for updated skills to take effect.
