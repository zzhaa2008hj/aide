---
name: aide-test
description: >-
  AIDE test stage: runs project test suite, verifies implementation against
  spec acceptance criteria, checks test coverage, produces test-report.json +
  test-report.md. Invoked by the aide orchestrator after implement stage.
---

# AIDE Test Stage

You are the **test stage** of the AIDE pipeline. Your job is to verify that the implemented code passes tests, meets spec criteria, and has adequate test coverage. Produce structured results in `test-report.json` and a human-readable `test-report.md`.

## Input

Find the latest files from previous stages:

```bash
SPEC=$(ls -t .aide/output/1-spec/*-spec.json 2>/dev/null | head -1)
PLAN=$(ls -t .aide/output/2-plan/*-plan.json 2>/dev/null | head -1)
IMPL=$(ls -t .aide/output/3-implement/*-implement.json 2>/dev/null | head -1)
```

- `$SPEC` — features with `acceptance_criteria`
- `$PLAN` — tasks with `files_to_touch`
- `$IMPL` — `completed_tasks`, `changed_files`, `task_results`

Only verify features for which tasks are in `completed_tasks`. Skip features whose tasks were all blocked.

## Output

### Step 0: Determine output filename

Read the slug from `.aide/state.json`:

```bash
SLUG=$(python3 -c "import json; print(json.load(open('.aide/state.json'))['slug'])")
DATE=$(date +%Y-%m-%d)
BASE=".aide/output/4-test/${DATE}-${SLUG}-test-report"
N=1
while [ -f "${BASE}.md" ] || [ -f "${BASE}.json" ]; do
    N=$((N + 1))
    BASE=".aide/output/4-test/${DATE}-${SLUG}-test-report-${N}"
done
```

Use `$BASE.md` and `$BASE.json` as the output paths.

## Workflow

### Step 1: Read inputs

```bash
mkdir -p .aide/output/4-test
cat "$SPEC"
cat "$PLAN"
cat "$IMPL"
```

Parse all three. If implement.json has no `completed_tasks`, report `verdict: manual` with reason "No completed tasks to verify" and skip to Step 6.

### Step 2: Detect and run test command

Detect the test framework by checking for config files in order:

| Config File | Test Command |
|-------------|-------------|
| `pyproject.toml` with `[tool.pytest]` | `pytest -v` |
| `setup.cfg` with `[tool:pytest]` | `pytest -v` |
| `package.json` with `"test"` script | `npm test` |
| `go.mod` | `go test ./...` |
| `Cargo.toml` | `cargo test` |
| `Makefile` with `test` target | `make test` |

If `.aide/config.yaml` has a `language` field set, use that as a hint. If no framework is detected, report `verdict: manual` with reason "No test framework detected" and skip to Step 6.

Run the detected command:

```bash
TEST_CMD="<detected command>"
$TEST_CMD 2>&1 | tee /tmp/aide-test-output.txt
TEST_EXIT=$?
```

Parse the output to count passed/failed/skipped tests. Store the full output for the report.

### Step 3: Spec verification

For each feature referenced by `completed_tasks`, look up its `acceptance_criteria` from spec.json:

1. For each criterion, scan the test output for matching test names or descriptions
2. If a matching test passed → `status: pass`, record the test name as `evidence`
3. If a matching test failed → `status: fail`, record failure details
4. If no matching test found → `status: untestable`, note "No test found"

Match heuristics:
- Test name contains keywords from the criteria (split criteria into words, filter stop words)
- Test file name matches feature title keywords
- For pytest: parse `test_name PASSED/FAILED` lines
- For npm/go/cargo: parse test output for pass/fail patterns

### Step 4: Coverage check

Compare `changed_files` from implement.json against known test file patterns:

```bash
CHANGED=$(python3 -c "import json; d=json.load(open('.aide/output/3-implement/implement.json')); print('\n'.join(d.get('changed_files', [])))")
```

For each changed file, check if a corresponding test file exists:
- `src/foo.py` → check for `tests/test_foo.py`, `src/foo_test.py`, `src/__tests__/foo.js`
- Files already in test directories count as tests

Classify each changed file:
- `files_with_tests`: has a matching test file
- `files_without_tests`: no matching test file found

### Step 4.5: DeepCode Test Quality Analysis (MANDATORY)

**Goal**: Augment the coverage check with deep analysis of both source and test files. The coverage check (Step 4) only verifies that test files *exist* — this step checks whether they are actually *good*. Catch weak assertions, missing edge case coverage, and test anti-patterns that a file-existence check misses.

Use your native analysis capabilities to examine both the changed files and their corresponding test files:

**Source file analysis** — for each changed source file without a test match, look for:
- Complex logic that should be tested but isn't
- Error handling paths with no coverage
- Public API surfaces without test coverage

**Test file analysis** — for each test file found, check for:
- **Weak assertions**: Tests that don't actually verify behavior (e.g., `assert true`, no assertions at all)
- **Missing edge cases**: Happy-path only, no error/edge/boundary coverage
- **Test anti-patterns**: Disabled tests, focused tests (`.only`), console.log in tests, empty test bodies
- **Over-mocking**: Tests that only verify mock behavior, not real behavior

Store findings in the `deepcode_test_quality` field of `test-report.json`:

```json
{
  "deepcode_test_quality": {
    "source_issues": 2,
    "test_issues": 1,
    "test_anti_patterns": 0,
    "details": [
      {
        "severity": "warning",
        "file": "src/utils/parser.py",
        "message": "parse() has 3 error branches with no corresponding test cases"
      }
    ]
  }
}
```

### Step 5: Determine verdict

Apply the verdict rules:

| Test Suite | Spec Verification | Coverage | Verdict |
|-----------|-------------------|----------|---------|
| All passed | All pass | Adequate | `pass` |
| Any failed | — | — | `fail` |
| All passed | Has fails | — | `fail` |
| Cannot run | — | — | `manual` |

### Step 6: Write output

Write `$BASE.json` conforming to `test.schema.json`:

```json
{
  "test_suite": {
    "passed": 12, "failed": 0, "skipped": 2,
    "command": "pytest -v",
    "output": "<full test output>"
  },
  "spec_verification": [
    {
      "feature_id": "F001",
      "criteria": "GET /health returns 200 with {status: ok}",
      "status": "pass",
      "evidence": "test_health.py::test_get_health PASSED"
    }
  ],
  "coverage": {
    "files_with_tests": ["src/routes/health.py"],
    "files_without_tests": [],
    "overall": "100% of changed files have test coverage"
  },
  "deepcode_test_quality": {
    "status": "completed|unavailable",
    "source_issues": 0,
    "test_issues": 0,
    "test_anti_patterns": 0,
    "details": []
  },
  "verdict": "pass"
}
```

Validate against the schema:

```bash
AIDE_DIR=$(find ~/.claude/plugins/cache/aide .claude/plugins -name "SKILL.md" -path "*/skills/aide/*" 2>/dev/null | head -1 | sed 's|/skills/aide/SKILL.md||')
[ -z "$AIDE_DIR" ] && AIDE_DIR=".claude/aide"

python3 -c "
import json, jsonschema
with open('${AIDE_DIR}/aide-core/schemas/test.schema.json') as f:
    schema = json.load(f)
with open('${BASE}.json') as f:
    data = json.load(f)
jsonschema.validate(data, schema)
print('test-report.json is valid')
"
```

Write `$BASE.md` — human-readable summary with test results table, spec verification status, coverage report, and verdict.

### Step 7: Report

```
## Stage 4: test — Verification

Test suite: 12 passed, 0 failed, 2 skipped
Spec verification: 5/5 criteria passed
Coverage: 100%
DeepCode test quality: N source issues, M test issues (K anti-patterns)
Verdict: pass
```

## Important Guidelines

- Always validate test-report.json against the schema before reporting completion.
- If no test framework is detected, don't fabricate test results — report `verdict: manual`.
- Match tests to criteria conservatively — a false match is worse than `untestable`.
- The `output` field in test_suite should be truncated to the last 200 lines if very long, to avoid bloating the JSON.
