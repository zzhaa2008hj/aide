# Superpowers Dependency Management Design

Date: 2026-06-03

## Problem

AIDE bundles Superpowers as a nested git submodule (`superpowers/`). This adds friction:

- **Install**: users need `git submodule update --init --recursive` — two levels of submodule init
- **Update**: users need `git pull` + `git submodule update` — easy to miss the nested step
- **CLAUDE.md**: needs `extra_skill_dirs: [.claude/aide/skills, .claude/aide/superpowers/skills]` — two paths
- **Breakage risk**: Superpowers version bumps can rename skills or change interfaces, silently breaking AIDE at install time
- **Customization cost**: AIDE extends Superpowers (not just consumes it), so submodule version-locking provides limited value — the code is already "owned" by AIDE

Goal: one-command install/update for users, manual version control for the AIDE maintainer, no surprise breakage.

## Design

### Directory Layout

```
AIDE/
├── skills/
│   ├── aide/                          # AIDE orchestrator (custom)
│   ├── aide-init/                     # AIDE initialization (custom)
│   ├── aide-spec/                     # AIDE spec stage (custom)
│   ├── brainstorming/                 # from superpowers
│   ├── dispatching-parallel-agents/   # from superpowers
│   ├── executing-plans/               # from superpowers
│   ├── finishing-a-development-branch/# from superpowers
│   ├── receiving-code-review/         # from superpowers
│   ├── requesting-code-review/        # from superpowers
│   ├── subagent-driven-development/   # from superpowers (AIDE-customized)
│   ├── systematic-debugging/          # from superpowers
│   ├── test-driven-development/       # from superpowers
│   ├── using-git-worktrees/           # from superpowers
│   ├── using-superpowers/             # from superpowers
│   ├── verification-before-completion/# from superpowers
│   ├── writing-plans/                 # from superpowers
│   └── writing-skills/                # from superpowers
├── aide-core/
│   └── scripts/
│       └── sync-superpowers.sh        # upstream sync tool
├── SUPERSPOWERS_VERSION               # baseline commit SHA from upstream
├── docs/superpowers/
│   └── upstream-sync.md               # developer-facing sync process doc
└── .gitmodules                        # REMOVED
```

### Changes

1. **Remove** `superpowers/` submodule and `.gitmodules` entry
2. **Copy** all 14 superpowers skills into `skills/` as flat directories
3. **Add** `SUPERSPOWERS_VERSION` containing the baseline commit: `6fd4507659784c351abbd2bc264c7162cfd386dc`
4. **Add** `aide-core/scripts/sync-superpowers.sh` for upstream inheritance
5. **Remove** `superpowers/skills` from AIDE's internal path references; all skills live under `skills/`

### User Experience

Install (one command):
```bash
git submodule add <AIDE-url> .claude/aide
/aide-init
```

Update (one command):
```bash
git -C .claude/aide pull
/aide-init
```

CLAUDE.md entry:
```yaml
extra_skill_dirs: [.claude/aide/skills]
```

`/aide-init` handles only user-facing setup: `.aide/` directory, config template, CLAUDE.md entry. Upstream sync is a separate developer concern.

### Upstream Sync Script

`aide-core/scripts/sync-superpowers.sh` automates merging superpowers updates.

#### Usage

```bash
./aide-core/scripts/sync-superpowers.sh <tag-or-commit>
# Example: ./aide-core/scripts/sync-superpowers.sh v5.2.0
```

#### Algorithm

```
1. Clone superpowers upstream to a temp directory (or use cached bare repo)
2. Read baseline commit from SUPERSPOWERS_VERSION
3. git diff <baseline>..<target> -- skills/ to discover changed skills
4. For each upstream skill:
   a. NEW (upstream has it, AIDE doesn't)       → auto-copy
   b. UNCHANGED (AIDE matches baseline exactly)  → auto-overwrite
   c. MODIFIED (AIDE diverged from baseline)     → interactive prompt:
      [o] overwrite — replace with upstream version
      [d] diff     — show the difference
      [m] merge    — copy to .tmp/ and let user manually merge
      [s] skip     — keep AIDE version, record as pending
5. Update SUPERSPOWERS_VERSION to new commit
6. Report summary: what was auto-copied, auto-overwritten, interactive-handled, skipped
```

#### Detection of "AIDE modified"

For each skill directory present in both upstream baseline and AIDE:

```
baseline_content = git show <baseline_commit>:skills/<skill>/
aide_content     = skills/<skill>/

if identical → UNCHANGED, safe to auto-overwrite
if different  → MODIFIED, needs manual decision
```

A temporary clone or bare repo provides the baseline. No persistent git history required in AIDE.

#### Interactive Workflow Example

```bash
$ ./aide-core/scripts/sync-superpowers.sh v5.2.0

Pulling upstream superpowers v5.2.0...
Baseline: 6fd4507 (v5.1.0) → Target: a1b2c3d (v5.2.0)

Changed skills: 3 new, 5 modified, 2 unchanged

[auto] brainstorming                 — unchanged, overwritten
[auto] systematic-debugging          — unchanged, overwritten
[new]  security-review               — copied from upstream
[new]  code-review                   — copied from upstream
[new]  fewer-permission-prompts      — copied from upstream

[mod]  subagent-driven-development   — AIDE modified since baseline
       [o]verwrite / [d]iff / [m]erge / [s]kip? d
       --- diff ---
       (diff output shown)
       [o]verwrite / [d]iff / [m]erge / [s]kip? m
       Copied to .tmp/superpowers-merge/subagent-driven-development/
       Edit manually, then press enter to continue.

[mod]  writing-skills                — AIDE modified since baseline
       [o]verwrite / [d]iff / [m]erge / [s]kip? s
       Skipped. Recorded in SUPERSPOWERS_PENDING.

Done. Updated SUPERSPOWERS_VERSION: 6fd4507 → a1b2c3d
Pending manual review: writing-skills
```

### Pending Review Tracking

Skipped skills are recorded in `SUPERSPOWERS_PENDING`:

```
writing-skills: a1b2c3d (v5.2.0) — skipped 2026-06-03
```

This file acts as a TODO list. Once manually merged, remove the entry. If empty, the file can be absent.

### aide-init Scope

`/aide-init` remains focused on end-user setup and does NOT touch superpowers sync:

- Create `.aide/` directory
- Copy `aide.config.yaml` template
- Add `extra_skill_dirs: [.claude/aide/skills]` to CLAUDE.md

Upstream sync is invoked by the AIDE maintainer, not by end users.

## Migration Path

1. Copy `superpowers/skills/*` into `skills/`
2. Write `SUPERSPOWERS_VERSION` with current submodule HEAD
3. Remove `superpowers/` directory and `.gitmodules` entry
4. Update `skills/aide/skill.md` — change superpowers path references from `.claude/aide/superpowers/skills/` to `.claude/aide/skills/`
5. Update `README.md` — remove `--recursive` from install, update project structure
6. Create `aide-core/scripts/sync-superpowers.sh`
7. Commit as a single changeset
