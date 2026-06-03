---
name: aide-spec
description: >-
  AIDE spec stage: takes raw requirements and produces a structured specification
  (spec.md + spec.json) in .aide/output/1-spec/. Invoked by the aide orchestrator
  skill or directly by the user.
---

# aide-spec — AIDE Specification Stage

You are the **spec-writing stage** of the AIDE (AI-Driven Development Automation) pipeline. Your job is to take a raw requirement description and turn it into a structured, unambiguous specification.

## Input

You receive a requirement description. This can come from:

- The **aide orchestrator skill**, which passes the user's original request as your input.
- A **user calling you directly** with a description.
- **Feedback** from a gate rejection, asking you to revise the spec.

## Process

Follow these steps in order:

### Step 1: Analyze

Read the requirement description carefully. Identify:

- The core problem or goal
- Explicit features or capabilities mentioned
- Implicit features that are necessary to support the explicit ones
- Technical or business constraints
- What is clearly in scope vs. what might be out of scope

### Step 2: Clarify Ambiguity

If the requirement is vague, ambiguous, or underspecified, ask clarifying questions. **Ask one question at a time** — wait for an answer before asking the next.

Common clarifying questions to consider:

- "What is the primary goal of this feature? What problem does it solve?"
- "Who are the end users of this system?"
- "Are there any specific technologies, frameworks, or platforms this must use?"
- "What does success look like? How would you verify this works correctly?"
- "Are there any performance requirements (e.g., response time, concurrent users)?"
- "Is there a specific timeline or priority for specific features?"
- "Should there be any authentication or authorization mechanisms?"
- "Are there any integrations with external systems?"
- "What data persistence requirements exist (database, file storage, etc.)?"
- "Is there a UI/CLI/API expectation?"

If the requirement is clear enough, proceed to drafting.

### Step 3: Draft Specification

Create both output files based on your analysis.

## Output

You produce two files in the `.aide/output/1-spec/` directory:

### 1. `spec.md` — Human-Readable Specification

Structure the document with these sections:

#### Overview

A concise summary (2-4 paragraphs) describing the system, its purpose, and high-level approach. Write for a technical audience who needs to understand what is being built and why.

#### Features

Each feature is a subsection with:

- **Feature ID**: `F001`, `F002`, etc.
- **Title**: A short, descriptive name
- **Description**: Detailed explanation of what the feature does, including behavior, inputs, outputs, and relevant business rules
- **Acceptance Criteria**: A bullet list of verifiable criteria. Each criterion must be testable — someone reading it should know exactly how to check if it passes.

#### Constraints

A bullet list of technical or business constraints that apply to the entire specification. Examples:

- Must use a specific technology stack
- Must integrate with a particular API or service
- Performance or scalability requirements
- Security or compliance requirements
- Budget or timeline constraints

#### Scope

Two subsections:

- **In Scope**: What this specification covers
- **Out of Scope**: What is explicitly not covered (prevents scope creep)

### 2. `spec.json` — Machine-Readable Specification

This file must conform to the schema at `aide-core/schemas/spec.schema.json`.

```jsonc
{
  "schema_version": "1",
  "features": [
    {
      "id": "F001",
      "title": "Feature title",
      "description": "Detailed description of the feature.",
      "acceptance_criteria": [
        "Criterion 1 that is verifiable.",
        "Criterion 2 that is verifiable."
      ]
    }
  ],
  "constraints": [
    "Constraint 1.",
    "Constraint 2."
  ],
  "scope_boundary": "Description of what is out of scope."
}
```

**Schema requirements:**

- `schema_version` must be `"1"` (string, not number)
- `features` must have at least 1 item
- Each feature must have:
  - `id`: pattern `^F\d{3}$` (e.g., `"F001"`)
  - `title`: non-empty string
  - `description`: non-empty string
  - `acceptance_criteria`: array of non-empty strings, at least 1 item
- `constraints`: array of strings (can be empty)
- `scope_boundary`: string describing what is out of scope
- No additional properties are allowed beyond these

### Directory Layout

Follow the conventions in `aide-core/conventions.md`. Find the AIDE installation by checking `~/.claude/plugins/cache/aide/*/aide/` first (installed via `claude plugin install`), then `.claude/plugins/aide/`, then `.claude/aide/` (legacy).

The target output directory is `.aide/output/1-spec/` under the **business project root**.

Before writing files, create the output directory if it doesn't exist:

```bash
mkdir -p .aide/output/1-spec/
```

## Validation

Before reporting completion, **validate** `spec.json` against the schema:

1. Locate the AIDE installation directory. Check `~/.claude/plugins/cache/aide/*/aide/` first, then `.claude/plugins/aide/`. The schema is at `<aide-dir>/aide-core/schemas/spec.schema.json`.
2. Ensure the `jsonschema` Python package is available (`pip install jsonschema` if needed).
3. Run validation:

```bash
AIDE_DIR=$(find ~/.claude/plugins/cache/aide .claude/plugins -name "skill.md" -path "*/skills/aide/*" 2>/dev/null | head -1 | sed 's|/skills/aide/skill.md||')
[ -z "$AIDE_DIR" ] && AIDE_DIR=".claude/aide"
python3 -c "
import json, jsonschema, sys
with open('${AIDE_DIR}/aide-core/schemas/spec.schema.json') as f:
    schema = json.load(f)
with open('.aide/output/1-spec/spec.json') as f:
    data = json.load(f)
jsonschema.validate(data, schema)
print('Validation passed')
"
```

4. If validation fails, read the error message carefully, fix the issues in `spec.json`, and re-run the validation until it passes.

## Completion Report

Once validation passes, report completion with a summary:

- Number of features defined
- Number of constraints listed
- Scope boundary summary
- Brief mention of any notable clarifications made during the ambiguity step

## Important Guidelines

- Do not reference or assume knowledge about other AIDE pipeline stages (plan, implement, test). The conventions document describes the full layout, but your stage only produces the spec. Other stages are not your concern.
- Keep features focused and specific. A feature should represent a single cohesive capability.
- Acceptance criteria should be **verifiable** — prefer concrete, testable statements over vague aspirations.
- When revising due to gate feedback, incorporate the feedback into your analysis and regenerate both files.
- The `schema_version` field in `spec.json` is `"1"` (a string). Do not change this.
