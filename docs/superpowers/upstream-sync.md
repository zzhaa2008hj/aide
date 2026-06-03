# Upstream Superpowers Sync

How the AIDE maintainer syncs new Superpowers releases into AIDE's `skills/` directory.

## Background

AIDE ships Superpowers skills directly in `skills/`. There is no git submodule. The `SUPERSPOWERS_VERSION` file at the repo root records the upstream baseline commit.

## Quick Sync

```bash
./aide-core/scripts/sync-superpowers.sh <tag-or-commit>
```

Example:
```bash
./aide-core/scripts/sync-superpowers.sh v5.2.0
```

The script compares the baseline commit against the target, then auto-routes each changed skill:

| Category | Detection | Action |
|---|---|---|
| **New** | Upstream has it, AIDE doesn't | Auto-copy |
| **Unchanged** | AIDE matches baseline exactly | Auto-overwrite |
| **Modified** | AIDE diverged from baseline | Interactive [o/d/m/s] |

### Interactive options for modified skills

- `[o]`verwrite — replace with upstream version
- `[d]`iff — show the difference
- `[m]`erge — copy to `.tmp/superpowers-merge/` for manual merge
- `[s]`kip — keep AIDE version, record in `SUPERSPOWERS_PENDING`

## Manual Sync

If you prefer to review every change manually:

```bash
# 1. Clone a fresh copy of upstream
git clone https://github.com/obra/superpowers /tmp/sp

# 2. Show what changed since our baseline
cd /tmp/sp
git diff $(cat /path/to/AIDE/SUPERSPOWERS_VERSION)..<target> -- skills/

# 3. For each changed skill, decide:
#    - Copy new/unchanged skills directly
#    - Manually merge skills AIDE has customized

# 4. Update the baseline
cd /path/to/AIDE
cd /tmp/sp && git rev-parse HEAD > /path/to/AIDE/SUPERSPOWERS_VERSION
git add skills/ SUPERSPOWERS_VERSION
git commit -m "chore: sync superpowers skills to <version>"
```

## Identifying AIDE-customized Skills

To check if AIDE has modified a skill since the baseline:

```bash
# Clone a bare reference copy (one-time setup)
git clone --bare https://github.com/obra/superpowers /tmp/sp-bare

# Compare a skill against the baseline
git --git-dir=/tmp/sp-bare show $(cat SUPERSPOWERS_VERSION):skills/<skill-name>/ \
  | diff -r - skills/<skill-name>/
```

No output = identical (safe to overwrite). Output = AIDE has customizations.
