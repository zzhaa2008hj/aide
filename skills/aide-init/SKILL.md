---
name: aide-init
description: >-
  Bootstrap AIDE configuration in a project. Creates .aide/ directory and
  config template. Run once after claude plugin install aide@aide --scope project.
---

# aide-init — Bootstrap AIDE Config

You bootstrap AIDE configuration in a business project. Your job is to locate the installed AIDE plugin and create the initial project configuration.

## Process

### Step 1: Locate the AIDE installation

Find the AIDE plugin installation directory. Search in order:

```bash
AIDE_DIR=$(find ~/.claude/plugins/cache/aide -name "SKILL.md" -path "*/skills/aide/*" 2>/dev/null | head -1 | sed 's|/skills/aide/SKILL.md||')
[ -z "$AIDE_DIR" ] && AIDE_DIR=".claude/plugins/aide"
[ -z "$AIDE_DIR" ] && AIDE_DIR=".claude/aide"
```

If no AIDE installation is found, report:
"AIDE plugin not found. Install it first: `claude plugin install aide@aide --scope project`"
and stop.

### Step 2: Create .aide/ directory

```bash
mkdir -p .aide
```

Report: `.aide/` ready.

### Step 3: Copy config template

If `.aide/config.yaml` already exists, skip this step.

Otherwise:

```bash
cp "$AIDE_DIR/templates/aide.config.yaml" .aide/config.yaml
```

Report: `.aide/config.yaml` created from template.

### Step 4: Report

Show a summary:

```
AIDE bootstrap complete.
  .aide/               — ready
  .aide/config.yaml     — created (or: already exists)

Now you can use:
  /aide "<desc>"        — start the pipeline
  /aide-update          — update AIDE to latest
```

## Important Guidelines

- This skill is idempotent. Safe to re-run anytime.
- Never overwrite an existing `.aide/config.yaml`. Always skip if it exists.
- If the AIDE plugin is installed but the config template is missing, report the version mismatch and suggest reinstalling: `claude plugin uninstall aide@aide && claude plugin install aide@aide --scope project`
