# AIDE Pipeline Protocol

Shared pipeline rules and procedures referenced by all AIDE orchestrators (Claude Code and DeepCode CLI). Each orchestrator provides its own stage-specific workflows; this file defines the universal constraints.

---

## CRITICAL Pipeline Discipline

**ALL pipeline output MUST be grounded in the existing project.** Project context analysis is MANDATORY before any stage work. Every spec feature, plan task, and code change must respect the existing tech stack, directory conventions, code patterns, and naming style. If the project is empty, establish architecture first.

**ABSOLUTELY FORBIDDEN until Stage 3 (implement) begins:**
- Writing, editing, or creating ANY source code file
- Using Write/Edit on anything outside `.aide/output/`
- Touching `src/`, `lib/`, `app/`, or any project source directory
- Running build commands, `npm install`, or similar

**The ONLY files you may create before Stage 3:**
- `.aide/state.json`
- `.aide/output/1-spec/*-spec.md` and `*-spec.json`
- `.aide/output/2-plan/*-plan.md` and `*-plan.json`

Violating these rules breaks the pipeline's resumability (`/aide-continue`) and leaves incomplete artifacts.

**You are in exactly ONE stage at a time. Complete it fully before proceeding.**

If `.aide/state.json` exists at startup with `completed_stages`, respect it — do NOT re-run completed stages.

---

## Project Context Analysis

**You MUST ground all pipeline decisions in the existing project.** Before any stage work, build a thorough understanding of the codebase.

### If the project has existing code:

1. **Map the project structure**:
   ```bash
   find . -maxdepth 1 -type f \( -name "*.json" -o -name "*.yaml" -o -name "*.toml" -o -name "*.cfg" -o -name "Makefile" -o -name "Dockerfile" \) 2>/dev/null | head -20
   ls -la
   ```

2. **Identify tech stack**: Read the project manifest (`package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `Gemfile`, `pom.xml`, `build.gradle`, etc.). Determine: language, framework, build system, test framework, package manager.

3. **Understand directory conventions**:
   ```bash
   find . -maxdepth 3 -type d ! -path './.git/*' ! -path './node_modules/*' ! -path './.aide/*' ! -path './venv/*' ! -path './__pycache__/*' ! -path './.venv/*' 2>/dev/null | sort
   ```

4. **Identify existing patterns**: Read key source files (entry points, config, a few representative components/modules). Note: naming conventions, file organization, code style, framework usage, routing patterns, state management, existing abstractions.

5. **Check for existing tests**:
   ```bash
   find . -path '*/test*' -o -path '*/__test*' -o -path '*/spec*' 2>/dev/null | head -20
   ```

6. **Summarize findings** in a brief project context memo. This memo informs ALL subsequent stages — spec features, plan tasks, and implementation decisions MUST respect existing patterns.

### If the project is empty or new:

1. **Architecture first**: Before writing any spec, establish:
   - Technology choices (language, framework, build tool)
   - Directory structure conventions
   - Key architectural decisions (state management, routing, data layer, component pattern)

2. **Use AskUserQuestion** to confirm key architecture decisions if not obvious from context.

3. **Document** architecture decisions. These become the `constraints` in spec.json.

**This context analysis is NOT optional.** Skipping it produces specs and code that don't fit the project.

---

## State Update Patterns

Use these Python one-liners to update `.aide/state.json`. Standard timestamp format: `$(date -u +%Y-%m-%dT%H:%M:%SZ)`.

### Pattern A — Basic Stage Transition

Replace `{current_stage}` and `{next_stage}` with the actual stage names:

```bash
python3 -c "
import json
with open('.aide/state.json') as f:
    state = json.load(f)
state['completed_stages'].append('{current_stage}')
state['current_stage'] = '{next_stage}'
state['last_updated'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
with open('.aide/state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

### Pattern B — test_retries Initialization

Use at the start of the test stage if `test_retries` is not yet set:

```bash
python3 -c "
import json
with open('.aide/state.json') as f:
    state = json.load(f)
state.setdefault('test_retries', 0)
with open('.aide/state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```

### Pattern C — Stage Transition with Cleanup

Replace `{current_stage}` and `{next_stage}`, and adjust the `pop()` key as needed:

```bash
python3 -c "
import json
with open('.aide/state.json') as f:
    state = json.load(f)
state['completed_stages'].append('{current_stage}')
state['current_stage'] = '{next_stage}'
state['last_updated'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
state.pop('test_retries', None)
with open('.aide/state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
```
