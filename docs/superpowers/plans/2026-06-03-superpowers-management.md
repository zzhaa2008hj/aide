# Superpowers Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace nested superpowers git submodule with flat-shipped skills in AIDE's `skills/` directory, plus an automated upstream sync script for the AIDE maintainer.

**Architecture:** 14 superpowers skills are copied into `skills/` alongside AIDE's custom skills. A `SUPERSPOWERS_VERSION` file tracks the upstream baseline commit. `aide-core/scripts/sync-superpowers.sh` automates future upstream merges by comparing the baseline to a target commit and auto-routing each skill as "new", "unchanged" (auto-overwrite), or "modified" (interactive confirm).

**Tech Stack:** Bash (sync script), git plumbing commands

---

### File Structure

| File | What it does |
|---|---|
| `skills/*/` (14 new dirs) | Superpowers skills copied from removed submodule |
| `SUPERSPOWERS_VERSION` | One-line file containing the upstream baseline commit SHA |
| `superpowers/` | REMOVED — previous git submodule directory |
| `.gitmodules` | REMOVED — no more submodules |
| `skills/aide/skill.md:282` | MODIFY — change superpowers path reference |
| `README.md` | MODIFY — simplify install/update commands, update project structure, update dependencies |
| `aide-core/scripts/sync-superpowers.sh` | CREATE — upstream sync automation script |
| `docs/superpowers/upstream-sync.md` | CREATE — developer-facing sync process documentation |

---

### Task 1: Copy superpowers skills and record baseline

**Files:**
- Create: `skills/brainstorming/`, `skills/dispatching-parallel-agents/`, ..., `skills/writing-skills/` (14 skill dirs copied recursively)
- Create: `SUPERSPOWERS_VERSION`

- [ ] **Step 1: Copy all 14 superpowers skill directories**

```bash
cp -r superpowers/skills/brainstorming skills/
cp -r superpowers/skills/dispatching-parallel-agents skills/
cp -r superpowers/skills/executing-plans skills/
cp -r superpowers/skills/finishing-a-development-branch skills/
cp -r superpowers/skills/receiving-code-review skills/
cp -r superpowers/skills/requesting-code-review skills/
cp -r superpowers/skills/subagent-driven-development skills/
cp -r superpowers/skills/systematic-debugging skills/
cp -r superpowers/skills/test-driven-development skills/
cp -r superpowers/skills/using-git-worktrees skills/
cp -r superpowers/skills/using-superpowers skills/
cp -r superpowers/skills/verification-before-completion skills/
cp -r superpowers/skills/writing-plans skills/
cp -r superpowers/skills/writing-skills skills/
```

- [ ] **Step 2: Verify all 14 skill dirs were copied**

```bash
ls -d skills/brainstorming skills/dispatching-parallel-agents skills/executing-plans skills/finishing-a-development-branch skills/receiving-code-review skills/requesting-code-review skills/subagent-driven-development skills/systematic-debugging skills/test-driven-development skills/using-git-worktrees skills/using-superpowers skills/verification-before-completion skills/writing-plans skills/writing-skills
```

Expected: 14 directories listed, no errors.

- [ ] **Step 3: Record the current superpowers baseline commit**

```bash
git -C superpowers rev-parse HEAD > SUPERSPOWERS_VERSION
```

- [ ] **Step 4: Verify the version file content**

```bash
cat SUPERSPOWERS_VERSION
```

Expected: `6fd4507659784c351abbd2bc264c7162cfd386dc` (v5.1.0)

- [ ] **Step 5: Commit**

```bash
git add skills/brainstorming/ skills/dispatching-parallel-agents/ skills/executing-plans/ skills/finishing-a-development-branch/ skills/receiving-code-review/ skills/requesting-code-review/ skills/subagent-driven-development/ skills/systematic-debugging/ skills/test-driven-development/ skills/using-git-worktrees/ skills/using-superpowers/ skills/verification-before-completion/ skills/writing-plans/ skills/writing-skills/ SUPERSPOWERS_VERSION
git commit -m "$(cat <<'EOF'
feat: flatten superpowers skills into AIDE skills directory

Copy 14 superpowers skills from the nested submodule into skills/,
alongside AIDE's custom skills. Add SUPERSPOWERS_VERSION to track
the upstream baseline commit (v5.1.0). This eliminates the nested
submodule and enables single-command install/update for users.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Remove superpowers submodule

**Files:**
- Delete: `superpowers/`
- Delete: `.gitmodules`

- [ ] **Step 1: Deinitialize the submodule**

```bash
git submodule deinit -f superpowers
```

- [ ] **Step 2: Remove the submodule directory from git tracking**

```bash
git rm -f superpowers
```

- [ ] **Step 3: Remove .gitmodules**

```bash
git rm -f .gitmodules
```

- [ ] **Step 4: Remove the .git/modules/superpowers internal directory**

```bash
rm -rf .git/modules/superpowers
```

- [ ] **Step 5: Verify no submodule references remain**

```bash
git submodule status
```

Expected: no output (or empty).

- [ ] **Step 6: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore: remove superpowers git submodule

Superpowers skills are now shipped flat in skills/. No nested
submodule init needed by users.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Update aide/skill.md path references

**Files:**
- Modify: `skills/aide/skill.md:282`

- [ ] **Step 1: Update the prerequisites section — superpowers path reference**

Change line 282 from:
```
2. Superpowers skills are available at `.claude/aide/superpowers/skills/`
```
to:
```
2. Superpowers skills are available at `.claude/aide/skills/`
```

Use the Edit tool:
```
old_string: 2. Superpowers skills are available at `.claude/aide/superpowers/skills/`
new_string: 2. Superpowers skills are available at `.claude/aide/skills/`
```

- [ ] **Step 2: Verify the change**

```bash
grep "superpowers/skills" skills/aide/skill.md
```

Expected: no matches (the old path should be gone).

- [ ] **Step 3: Commit**

```bash
git add skills/aide/skill.md
git commit -m "$(cat <<'EOF'
fix: update superpowers skills path reference in aide orchestrator

Skills now live in skills/ alongside AIDE's own skills, not in a
nested superpowers/skills/ subdirectory.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Update README.md

**Files:**
- Modify: `README.md`

Four changes needed in README.md:

- [ ] **Step 1: Remove `--recursive` from install command**

Line 12 currently:
```
git -C .claude/aide submodule update --init --recursive
```
Remove this line entirely (no more nested submodule to init).

Use the Edit tool:
```
old_string: git submodule add <AIDE-repo-url> .claude/aide
git -C .claude/aide submodule update --init --recursive
new_string: git submodule add <AIDE-repo-url> .claude/aide
```

- [ ] **Step 2: Simplify update command**

Lines 38-41 currently:
```
git -C .claude/aide pull origin master
git -C .claude/aide submodule update --init --recursive
```
Remove the second line (no more nested submodule to update).

Use the Edit tool:
```
old_string: git -C .claude/aide pull origin master
git -C .claude/aide submodule update --init --recursive
new_string: git -C .claude/aide pull origin master
```

- [ ] **Step 3: Update project structure — replace the superpowers line + add new files**

Lines 55-73 (Project Structure block), replace:
```
├── superpowers/           # Git submodule — Superpowers skills for subagent-driven development
├── templates/             # Business project templates
│   ├── aide.config.yaml
│   └── CLAUDE.md.partial
├── docs/                  # Design specs and implementation plans
└── .gitmodules
```
with:
```
├── templates/             # Business project templates
│   ├── aide.config.yaml
│   └── CLAUDE.md.partial
├── aide-core/
│   └── scripts/
│       └── sync-superpowers.sh  # Upstream sync tool (maintainer use)
├── SUPERSPOWERS_VERSION   # Tracked upstream baseline commit
├── docs/                  # Design specs and implementation plans
```
And also add the 14 superpowers skill entries under `skills/`. Replace the skills section:
```
├── skills/
│   ├── aide/              # Pipeline orchestrator
│   ├── aide-init/         # Project initialization
│   ├── aide-spec/         # Stage 1: Requirements → Spec
│   ├── aide-plan/         # Stage 2: Spec → Plan (Phase 2)
│   └── aide-test/         # Stage 4: Verification (Phase 3)
```
with:
```
├── skills/
│   ├── aide/                          # Pipeline orchestrator
│   ├── aide-init/                     # Project initialization
│   ├── aide-spec/                     # Stage 1: Requirements → Spec
│   ├── aide-plan/                     # Stage 2: Spec → Plan (Phase 2)
│   ├── aide-test/                     # Stage 4: Verification (Phase 3)
│   ├── brainstorming/                 # Idea → design (superpowers)
│   ├── dispatching-parallel-agents/   # Parallel task dispatch (superpowers)
│   ├── executing-plans/               # Plan execution engine (superpowers)
│   ├── finishing-a-development-branch/# Branch completion workflow (superpowers)
│   ├── receiving-code-review/         # Code review response (superpowers)
│   ├── requesting-code-review/        # Code review request (superpowers)
│   ├── subagent-driven-development/   # Subagent-based implementation (superpowers)
│   ├── systematic-debugging/          # Bug investigation (superpowers)
│   ├── test-driven-development/       # TDD workflow (superpowers)
│   ├── using-git-worktrees/           # Worktree isolation (superpowers)
│   ├── using-superpowers/             # Superpowers usage guide (superpowers)
│   ├── verification-before-completion/# Completion verification (superpowers)
│   ├── writing-plans/                 # Implementation planning (superpowers)
│   └── writing-skills/                # Skill authoring (superpowers)
```

Use the Edit tool — perform these two edits sequentially on README.md.

- [ ] **Step 4: Update Dependencies section**

Lines 94-96 currently:
```
AIDE bundles [Superpowers](https://github.com/obra/superpowers) as a git submodule for subagent-driven development, TDD, debugging, and code review patterns. Business projects must run `git submodule update --init --recursive` after adding AIDE to pull in both AIDE and Superpowers.
```
Replace with:
```
AIDE ships Superpowers skills directly in `skills/` — no nested submodule required. For the upstream source, see [Superpowers](https://github.com/obra/superpowers).
```

Use the Edit tool.

- [ ] **Step 5: Verify the README changes**

```bash
grep -n "recursive\|superpowers/skills\|git submodule.*superpowers" README.md
```

Expected: no matches (all nested submodule references removed). Then:
```bash
grep -c "extra_skill_dirs: \[.claude/aide/skills\]" README.md
```
Expected: `1` (the single CLAUDE.md entry is documented).

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: update README for flattened superpowers structure

Remove --recursive submodule init steps. Document the single
extra_skill_dirs entry. Show all 14 superpowers skills in the
project structure.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Create upstream sync documentation

**Files:**
- Create: `docs/superpowers/upstream-sync.md`

- [ ] **Step 1: Write the developer sync doc**

```bash
mkdir -p docs/superpowers
```

Write `docs/superpowers/upstream-sync.md`:

```markdown
# Upstream Superpowers Sync

This document describes how the AIDE maintainer syncs new Superpowers releases into AIDE's `skills/` directory.

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

The script compares the baseline commit (from `SUPERSPOWERS_VERSION`) against the target, then auto-routes each changed skill:

| Category | Detection | Action |
|---|---|---|
| **New** skill | Upstream has it, AIDE doesn't | Auto-copy |
| **Unchanged** skill | AIDE matches baseline exactly | Auto-overwrite |
| **Modified** skill | AIDE diverged from baseline | Interactive prompt |

For modified skills, the prompt offers:
- `[o]`verwrite — replace with upstream version
- `[d]`iff — show the difference
- `[m]`erge — copy to `.tmp/` for manual merge
- `[s]`kip — keep AIDE version, record in `SUPERSPOWERS_PENDING`

## Manual Sync

If you prefer to review every change manually:

1. Clone a fresh copy of upstream:
   ```bash
   git clone https://github.com/obra/superpowers /tmp/sp
   ```

2. Show what changed since our baseline:
   ```bash
   cd /tmp/sp
   git diff $(cat /path/to/AIDE/SUPERSPOWERS_VERSION)..<target> -- skills/
   ```

3. For each changed skill, decide:
   - Copy new/unchanged skills directly
   - Manually merge skills AIDE has customized

4. Update the baseline:
   ```bash
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/upstream-sync.md
git commit -m "$(cat <<'EOF'
docs: add upstream sync guide for AIDE maintainers

Documents the sync-superpowers.sh script usage and manual sync
process for inheriting new Superpowers releases.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Create sync-superpowers.sh script

**Files:**
- Create: `aide-core/scripts/sync-superpowers.sh`

- [ ] **Step 1: Create the scripts directory and write the script**

```bash
mkdir -p aide-core/scripts
```

Write `aide-core/scripts/sync-superpowers.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# sync-superpowers.sh — Merge upstream Superpowers skill updates into AIDE.
#
# Usage: ./aide-core/scripts/sync-superpowers.sh <tag-or-commit>
#
# Compares the baseline commit (SUPERSPOWERS_VERSION) against the target,
# then auto-routes each changed skill:
#   NEW        — auto-copy
#   UNCHANGED  — auto-overwrite
#   MODIFIED   — interactive [o/d/m/s]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
VERSION_FILE="$REPO_ROOT/SUPERSPOWERS_VERSION"
PENDING_FILE="$REPO_ROOT/SUPERSPOWERS_PENDING"
UPSTREAM_URL="https://github.com/obra/superpowers"
TMP_DIR="${TMPDIR:-/tmp}/superpowers-sync-$$"

# ---- helpers ----

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "  $*"; }

cleanup() {
    rm -rf "$TMP_DIR"
}

# ---- argument parsing ----

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <tag-or-commit>"
    echo "Example: $0 v5.2.0"
    exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
    die "SUPERSPOWERS_VERSION not found at $VERSION_FILE"
fi

BASELINE=$(cat "$VERSION_FILE" | tr -d '\n')
if [ -z "$BASELINE" ]; then
    die "SUPERSPOWERS_VERSION is empty"
fi

# ---- clone upstream ----

info "Cloning upstream superpowers..."
trap cleanup EXIT
git clone --depth 50 "$UPSTREAM_URL" "$TMP_DIR" 2>&1 | sed 's/^/    /'

# Resolve target to a commit SHA
TARGET_SHA=$(git -C "$TMP_DIR" rev-list -n1 "$TARGET" 2>/dev/null) || die "Cannot resolve '$TARGET' to a commit"

# Verify baseline exists in the clone
git -C "$TMP_DIR" cat-file -e "$BASELINE" 2>/dev/null || die "Baseline commit $BASELINE not found in upstream (shallow clone too shallow?)"

info "Baseline: ${BASELINE:0:7} → Target: ${TARGET_SHA:0:7}"

# ---- discover changed skills ----

UPSTREAM_SKILLS=$(git -C "$TMP_DIR" ls-tree --name-only "$TARGET_SHA":skills/ 2>/dev/null || true)
BASELINE_SKILLS=$(git -C "$TMP_DIR" ls-tree --name-only "$BASELINE":skills/ 2>/dev/null || true)

declare -a NEW=()
declare -a UNCHANGED=()
declare -a MODIFIED=()

for skill in $UPSTREAM_SKILLS; do
    if ! echo "$BASELINE_SKILLS" | grep -qxF "$skill"; then
        NEW+=("$skill")
    elif diff -rq "$SKILLS_DIR/$skill" <(git -C "$TMP_DIR" show "$BASELINE:skills/$skill") >/dev/null 2>&1; then
        UNCHANGED+=("$skill")
    else
        MODIFIED+=("$skill")
    fi
done

# ---- auto-copy unchanged skills ----

if [ ${#NEW[@]} -gt 0 ] || [ ${#UNCHANGED[@]} -gt 0 ]; then
    echo ""
    echo "--- Auto-apply ---"
fi

for skill in "${NEW[@]}"; do
    echo "[new]  $skill — copying from upstream"
    rm -rf "$SKILLS_DIR/$skill"
    git -C "$TMP_DIR" show "$TARGET_SHA:skills/$skill" | tar -C "$SKILLS_DIR" -xf - 2>/dev/null || {
        # tar extraction from git show can be tricky; fallback to per-file copy
        mkdir -p "$SKILLS_DIR/$skill"
        git -C "$TMP_DIR" ls-tree --name-only "$TARGET_SHA:skills/$skill" | while read -r f; do
            git -C "$TMP_DIR" show "$TARGET_SHA:skills/$skill/$f" > "$SKILLS_DIR/$skill/$f"
        done
    }
done

for skill in "${UNCHANGED[@]}"; do
    echo "[auto] $skill — unchanged, overwriting"
    rm -rf "$SKILLS_DIR/$skill"
    mkdir -p "$SKILLS_DIR/$skill"
    git -C "$TMP_DIR" ls-tree --name-only "$TARGET_SHA:skills/$skill" | while read -r f; do
        git -C "$TMP_DIR" show "$TARGET_SHA:skills/$skill/$f" > "$SKILLS_DIR/$skill/$f"
    done
done

# ---- interactive modified skills ----

if [ ${#MODIFIED[@]} -gt 0 ]; then
    echo ""
    echo "--- Interactive (AIDE modified since baseline) ---"

    for skill in "${MODIFIED[@]}"; do
        echo ""
        echo "[mod]  $skill — AIDE modified since baseline"
        while true; do
            read -r -p "       [o]verwrite / [d]iff / [m]erge / [s]kip? " choice
            case "$choice" in
                o|O)
                    rm -rf "$SKILLS_DIR/$skill"
                    mkdir -p "$SKILLS_DIR/$skill"
                    git -C "$TMP_DIR" ls-tree --name-only "$TARGET_SHA:skills/$skill" | while read -r f; do
                        git -C "$TMP_DIR" show "$TARGET_SHA:skills/$skill/$f" > "$SKILLS_DIR/$skill/$f"
                    done
                    echo "       Overwritten with upstream version."
                    break
                    ;;
                d|D)
                    echo ""
                    echo "--- diff for $skill (baseline → target) ---"
                    diff -ruN "$SKILLS_DIR/$skill" <(git -C "$TMP_DIR" show "$TARGET_SHA:skills/$skill" | tar -C /tmp -xf - -O 2>/dev/null || true) || true
                    echo "--- end diff ---"
                    ;;
                m|M)
                    MERGE_DIR="$REPO_ROOT/.tmp/superpowers-merge/$skill"
                    mkdir -p "$MERGE_DIR"
                    git -C "$TMP_DIR" ls-tree --name-only "$TARGET_SHA:skills/$skill" | while read -r f; do
                        git -C "$TMP_DIR" show "$TARGET_SHA:skills/$skill/$f" > "$MERGE_DIR/$f"
                    done
                    echo "       Upstream copied to $MERGE_DIR"
                    echo "       AIDE version at: $SKILLS_DIR/$skill"
                    echo "       Manually merge, then press Enter to continue."
                    read -r
                    break
                    ;;
                s|S)
                    echo "       Skipped."
                    echo "$skill: $TARGET_SHA ($TARGET) — skipped $(date +%Y-%m-%d)" >> "$PENDING_FILE"
                    break
                    ;;
                *)
                    echo "       Invalid choice. Enter o, d, m, or s."
                    ;;
            esac
        done
    done
fi

# ---- update version ----

echo ""
echo "$TARGET_SHA" > "$VERSION_FILE"
info "Updated SUPERSPOWERS_VERSION: ${BASELINE:0:7} → ${TARGET_SHA:0:7}"

if [ -f "$PENDING_FILE" ]; then
    info "Pending manual review (see SUPERSPOWERS_PENDING):"
    cat "$PENDING_FILE" | sed 's/^/    /'
fi

echo ""
info "Review the changes, then commit:"
info "  git add skills/ SUPERSPOWERS_VERSION"
info "  git commit -m \"chore: sync superpowers skills to $TARGET\""
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x aide-core/scripts/sync-superpowers.sh
```

- [ ] **Step 3: Verify script is syntactically valid**

```bash
bash -n aide-core/scripts/sync-superpowers.sh
```

Expected: no output (no syntax errors).

- [ ] **Step 4: Dry-run test with current baseline (should detect zero changes)**

```bash
./aide-core/scripts/sync-superpowers.sh $(cat SUPERSPOWERS_VERSION)
```

Expected output: no new/unchanged/modified skills listed, version file updates to same SHA.

- [ ] **Step 5: Commit**

```bash
git add aide-core/scripts/sync-superpowers.sh
git commit -m "$(cat <<'EOF'
feat: add sync-superpowers.sh for upstream skill inheritance

Automates merging new Superpowers releases into AIDE's skills/.
Auto-routes skills as new (copy), unchanged (overwrite), or
modified (interactive diff/merge/skip). Used by the AIDE maintainer,
not by end users.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Final verification

**Files:** (none — verification only)

- [ ] **Step 1: Verify no submodule references remain in the repo**

```bash
grep -r "superpowers/skills\|superpowers.*submodule\|git submodule.*superpowers" skills/ README.md docs/ 2>/dev/null || true
```

Expected: no matches (or only matches in the sync doc that refer to the upstream URL, which is fine).

- [ ] **Step 2: Verify the skills/ directory contains all expected skill dirs**

```bash
ls -d skills/*/ | wc -l
```

Expected: 17 (3 AIDE + 14 superpowers).

- [ ] **Step 3: Verify SUPERSPOWERS_VERSION exists and is non-empty**

```bash
test -s SUPERSPOWERS_VERSION && cat SUPERSPOWERS_VERSION
```

Expected: a 40-character SHA.

- [ ] **Step 4: Verify CLAUDE.md path entry is correct (single path)**

```bash
grep "extra_skill_dirs" README.md
```

Expected: shows only `extra_skill_dirs: [.claude/aide/skills]`.

- [ ] **Step 5: Check git log for the migration commits**

```bash
git log --oneline -6
```

Expected: 6 commits in order — skills copy, submodule removal, path fix, README update, sync doc, sync script.

- [ ] **Step 6: Commit any remaining changes**

```bash
git status
```

If clean, no action needed. If there are untracked or modified files from verification, stage and commit them.
