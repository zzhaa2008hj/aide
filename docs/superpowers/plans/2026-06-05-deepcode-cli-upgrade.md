# deepcode-cli Upgrade Mechanism — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add version tracking to install and a standalone update script for deepcode-cli users.

**Architecture:** Two shell scripts in `aide_deepcode/`. `install-deepcode-cli.sh` gets a minor modification to record the installed version. `update-deepcode-cli.sh` (new) fetches the latest `plugin.json` from GitHub raw, compares with `.aide/version`, and re-runs a sparse checkout if a newer version exists.

**Tech Stack:** bash, git sparse-checkout, python3 (JSON parsing, same as existing scripts), curl

---

### Task 1: Modify `install-deepcode-cli.sh` — track installed version

**Files:**
- Modify: `aide_deepcode/install-deepcode-cli.sh`

- [ ] **Step 1: Update sparse-checkout to include plugin.json**

Change the sparse-checkout set line to include `.claude-plugin/plugin.json` so the version source is available during install.

Edit `aide_deepcode/install-deepcode-cli.sh` line 44:

```diff
-	git sparse-checkout set skills aide-core/schemas >/dev/null 2>&1
+	git sparse-checkout set skills aide-core/schemas .claude-plugin/plugin.json >/dev/null 2>&1
```

- [ ] **Step 2: Add version write step after schema copy**

Insert a new step after the schema copy block (after the `echo "Schemas: ..."` line, before the final `echo "=== Installation complete ==="`):

```bash
	# Step 4b: Record installed version from plugin.json
	VERSION=$(python3 -c "
import json
data = json.load(open('$TMP_DIR/.claude-plugin/plugin.json'))
print(data['version'])
" 2>/dev/null || echo "unknown")
	echo "$VERSION" > .aide/version
	echo ""
	echo "  Version: $VERSION written to .aide/version"
```

Full context — the end of the script before the final summary should become:

```bash
	# Step 4: Copy shared schemas
	SCHEMAS_DST=".aide/schemas"
	mkdir -p "$SCHEMAS_DST"
	SCHEMAS_SRC="$TMP_DIR/aide-core/schemas"
	if [ -d "$SCHEMAS_SRC" ]; then
	    for schema in "$SCHEMAS_SRC"/*.json; do
	        if [ -f "$schema" ]; then
	            cp "$schema" "$SCHEMAS_DST/"
	        fi
	    done
	    echo ""
	    echo "  Schemas: $(ls "$SCHEMAS_DST"/*.json 2>/dev/null | wc -l) copied to $SCHEMAS_DST"
	fi

	# Step 4b: Record installed version from plugin.json
	VERSION=$(python3 -c "
import json
data = json.load(open('$TMP_DIR/.claude-plugin/plugin.json'))
print(data['version'])
" 2>/dev/null || echo "unknown")
	echo "$VERSION" > .aide/version
	echo ""
	echo "  Version: $VERSION written to .aide/version"

	echo ""
	echo "=== Installation complete ==="
```

- [ ] **Step 3: Verify install script still works**

Run a test install and confirm `.aide/version` is created:

```bash
cd /tmp && rm -rf test-install-version && mkdir test-install-version && cd test-install-version
bash /home/hui/ai/AIDE/aide_deepcode/install-deepcode-cli.sh
cat .aide/version
```

Expected: `.aide/version` exists and contains a version like `1.0.26`.

- [ ] **Step 4: Commit**

```bash
git add aide_deepcode/install-deepcode-cli.sh
git commit -m "feat(deepcode-cli): record installed version during install"
```

---

### Task 2: Create `update-deepcode-cli.sh`

**Files:**
- Create: `aide_deepcode/update-deepcode-cli.sh`
- Make executable with `chmod +x`

- [ ] **Step 1: Write the update script**

Create `aide_deepcode/update-deepcode-cli.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# update-deepcode-cli.sh — Check for and apply AIDE updates for deepcode-cli.
#
# Compares the locally installed version (.aide/version) against the latest
# version in the AIDE repo's plugin.json. If a newer version is available,
# updates skills and schemas via sparse checkout.
#
# Usage:
#   bash update-deepcode-cli.sh
#
#   # Custom repo or branch:
#   AIDE_REPO=https://github.com/zzhaa2008hj/aide.git AIDE_REF=dev bash update-deepcode-cli.sh

AIDE_REPO="${AIDE_REPO:-https://github.com/zzhaa2008hj/aide.git}"
AIDE_REF="${AIDE_REF:-master}"

echo "=== AIDE Update for deepcode-cli ==="
echo "  Repo: $AIDE_REPO"
echo "  Ref:  $AIDE_REF"
echo ""

# Step 0: Preflight — verify we're in a deepcode-cli project
if [ ! -f ".agents/skills/aide/SKILL.md" ]; then
    echo "[error] No deepcode-cli AIDE install detected."
    echo "        Run install-deepcode-cli.sh first:"
    echo "        curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/master/aide_deepcode/install-deepcode-cli.sh | bash"
    exit 1
fi
echo "[ok]    deepcode-cli AIDE install detected"

# Step 1: Read local version
if [ -f ".aide/version" ]; then
    LOCAL_VERSION=$(cat .aide/version)
    if [ "$LOCAL_VERSION" = "unknown" ]; then
        LOCAL_VERSION="0.0.0"
    fi
else
    LOCAL_VERSION="0.0.0"
fi
echo "        Local version: $LOCAL_VERSION"

# Step 2: Fetch latest version from repo
PLUGIN_JSON_URL=$(echo "$AIDE_REPO" | sed 's|git@github.com:|https://raw.githubusercontent.com/|' | sed 's|\.git$||')/$AIDE_REF/.claude-plugin/plugin.json

REMOTE_VERSION=$(curl -sSL "$PLUGIN_JSON_URL" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['version'])
" 2>/dev/null || echo "")

if [ -z "$REMOTE_VERSION" ]; then
    echo "[error] Cannot fetch version info from $PLUGIN_JSON_URL"
    echo "        Check your network connection or AIDE_REPO/AIDE_REF settings."
    exit 1
fi
echo "        Remote version: $REMOTE_VERSION"

# Step 3: Compare versions
version_greater() {
    # Returns 0 (true) if $1 > $2, 1 (false) otherwise
    python3 -c "
a = tuple(map(int, '$1'.split('.')))
b = tuple(map(int, '$2'.split('.')))
exit(0 if a > b else 1)
"
}

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo ""
    echo "=== AIDE is already at the latest version ($LOCAL_VERSION) ==="
    exit 0
fi

if version_greater "$LOCAL_VERSION" "$REMOTE_VERSION"; then
    echo ""
    echo "=== Local version ($LOCAL_VERSION) is ahead of remote ($REMOTE_VERSION) ==="
    echo "    Nothing to update."
    exit 0
fi

echo ""
echo "[info]  Update available: $LOCAL_VERSION → $REMOTE_VERSION"
echo ""

# Step 4: Update via sparse checkout
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "[info]  Fetching skills/ and schemas from $AIDE_REPO ($AIDE_REF)..."

cd "$TMP_DIR"
git init -q
git remote add origin "$AIDE_REPO" 2>/dev/null || git remote set-url origin "$AIDE_REPO"
git sparse-checkout init --cone >/dev/null 2>&1
git sparse-checkout set skills aide-core/schemas >/dev/null 2>&1
git fetch origin "$AIDE_REF" --depth 1 -q 2>/dev/null || git fetch origin "$AIDE_REF" --depth 1
git checkout FETCH_HEAD >/dev/null 2>&1
cd - > /dev/null

if [ ! -d "$TMP_DIR/skills" ]; then
    echo "[error] Update failed. Your existing install is unchanged."
    exit 1
fi

# Step 4a: Update skills
declare -A SKILL_MAP=(
    ["aide-deepcode"]="aide"
    ["aide-spec"]="aide-spec"
    ["aide-plan"]="aide-plan"
    ["aide-test"]="aide-test"
    ["aide-continue"]="aide-continue"
    ["aide-init"]="aide-init"
)

UPDATED=0
SKIPPED=0
for src_name in "${!SKILL_MAP[@]}"; do
    dst_name="${SKILL_MAP[$src_name]}"
    src="$TMP_DIR/skills/$src_name/SKILL.md"
    dst_dir=".agents/skills/$dst_name"

    if [ -f "$src" ]; then
        mkdir -p "$dst_dir"
        cp "$src" "$dst_dir/SKILL.md"
        echo "  [done]  $dst_name (from $src_name)"
        UPDATED=$((UPDATED + 1))
    else
        echo "  [skip]  $src_name (not found in repo, keeping existing)"
        SKIPPED=$((SKIPPED + 1))
    fi
done

# Step 4b: Update schemas
SCHEMAS_DST=".aide/schemas"
mkdir -p "$SCHEMAS_DST"
SCHEMAS_SRC="$TMP_DIR/aide-core/schemas"
if [ -d "$SCHEMAS_SRC" ]; then
    SCHEMA_COUNT=0
    for schema in "$SCHEMAS_SRC"/*.json; do
        if [ -f "$schema" ]; then
            cp "$schema" "$SCHEMAS_DST/"
            SCHEMA_COUNT=$((SCHEMA_COUNT + 1))
        fi
    done
    echo ""
    echo "  Schemas: $SCHEMA_COUNT updated"
fi

# Step 5: Write new version
echo "$REMOTE_VERSION" > .aide/version

# Step 6: Report
echo ""
echo "=== Update complete ==="
echo "  Version:  $LOCAL_VERSION → $REMOTE_VERSION"
echo "  Skills:   $UPDATED updated, $SKIPPED skipped"
echo ""
echo "AIDE skills have been updated. Restart deepcode-cli for changes to take effect."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x aide_deepcode/update-deepcode-cli.sh
```

- [ ] **Step 3: Test with a real project**

Use the existing test project to verify the update flow:

```bash
# First verify the test project has an install
ls /home/hui/temp/20260603/aide-test-project/.agents/skills/aide/SKILL.md

# Copy update script to test project and run
cp /home/hui/ai/AIDE/aide_deepcode/update-deepcode-cli.sh /home/hui/temp/20260603/aide-test-project/
cd /home/hui/temp/20260603/aide-test-project

# Ensure .aide/version exists (or run install first if needed)
if [ ! -f ".aide/version" ]; then
    bash /home/hui/ai/AIDE/aide_deepcode/install-deepcode-cli.sh
fi

# Run update
bash update-deepcode-cli.sh
```

Expected: Reports "already at the latest version" (test project was just installed from same ref).

- [ ] **Step 4: Test "no install" error path**

```bash
cd /tmp && mkdir -p test-no-install && cd test-no-install
bash /home/hui/ai/AIDE/aide_deepcode/update-deepcode-cli.sh
```

Expected: Error "No deepcode-cli AIDE install detected" and exit code 1.

- [ ] **Step 5: Test "same version" path**

```bash
cd /home/hui/temp/20260603/aide-test-project
echo "1.0.26" > .aide/version
bash update-deepcode-cli.sh
```

Expected: Reports "already at the latest version."

- [ ] **Step 6: Test "older version triggers update" path**

```bash
cd /home/hui/temp/20260603/aide-test-project
echo "0.1.0" > .aide/version
bash update-deepcode-cli.sh
```

Expected: Reports available update, downloads and applies it, writes new version.

- [ ] **Step 7: Cleanup test artifacts**

```bash
rm -f /home/hui/temp/20260603/aide-test-project/update-deepcode-cli.sh
cd /home/hui/temp/20260603/aide-test-project && bash /home/hui/ai/AIDE/aide_deepcode/install-deepcode-cli.sh
```

- [ ] **Step 8: Commit**

```bash
git add aide_deepcode/update-deepcode-cli.sh
git commit -m "feat(deepcode-cli): add update script with version checking

Supports AIDE_REPO and AIDE_REF env vars for custom sources.
Compares local .aide/version against repo's plugin.json."
```
