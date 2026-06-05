# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

## Before Dispatching: Perform DeepCode Quality Scan

Before sending the code quality reviewer, use your native analysis capabilities (you are running inside deepcode-cli) to scan the task's changed files. This gives the reviewer a head start with concrete issues to verify.

Read the task's changed files from the implementer's report. Perform a focused quality scan covering:
- **Correctness**: Logic errors, missing edge cases, null/undefined risks
- **Code quality**: Overly complex functions, duplicated logic, missing error handling, poorly named identifiers
- **Structure**: Does the implementation follow the file structure from the plan? Are new files appropriately sized?
- **Test quality**: Are tests meaningful (real assertions, edge cases) or superficial?

Compile your findings into a structured summary. Pass this as `{DEEPCODE_RESULTS}` in the reviewer prompt below.

## Reviewer Prompt

```
Task tool (general-purpose):
  Use template at requesting-code-review/code-reviewer.md

  DESCRIPTION: [task summary, from implementer's report]
  PLAN_OR_REQUIREMENTS: Task N from [plan-file]
  BASE_SHA: [commit before task]
  HEAD_SHA: [current commit]
  DEEPCODE_RESULTS: [structured pre-review findings, or "No pre-review performed — full manual review required."]
```

**In addition to standard code quality concerns, the reviewer should check:**
- Does each file have one clear responsibility with a well-defined interface?
- Are units decomposed so they can be understood and tested independently?
- Is the implementation following the file structure from the plan?
- Did this implementation create new files that are already large, or significantly grow existing files? (Don't flag pre-existing file sizes — focus on what this change contributed.)
- **Verify pre-review findings**: For each finding in the pre-review, check if it's a true positive in context. Filter noise, keep signal. Mark verified findings with source "Pre-review (verified)".

**Code reviewer returns:** Strengths, Issues (Critical/Important/Minor), Assessment
