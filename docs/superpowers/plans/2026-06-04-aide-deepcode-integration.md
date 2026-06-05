# AIDE DeepCode Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package AIDE pipeline logic as 4 DeepCode InteractionPlugins so DeepCode users can run AIDE's structured workflow without Claude Code.

**Architecture:** Each AIDE stage becomes a DeepCode plugin extending `InteractionPlugin`. Gates map to `InteractionRequest` (confirm/confirm_skip/auto). Schemas are shared from `aide-core/schemas/`. Zero changes to existing AIDE or DeepCode code.

**Tech Stack:** Python 3.13+, DeepCode plugin system (`workflows.plugins`), JSON Schema for validation

**Design spec:** `docs/superpowers/specs/2026-06-04-aide-deepcode-integration-design.md`

---

## File Map

| File | Role |
|------|------|
| `aide_deepcode/__init__.py` | **Create** — Plugin registration entry, imports all 4 plugins |
| `aide_deepcode/aide_spec_plugin.py` | **Create** — BEFORE_PLANNING: requirements → spec.json + gate |
| `aide_deepcode/aide_plan_plugin.py` | **Create** — AFTER_PLANNING: spec → plan.json + gate |
| `aide_deepcode/aide_implement_plugin.py` | **Create** — BEFORE_IMPLEMENTATION: plan → code via DeepCode Agent |
| `aide_deepcode/aide_test_plugin.py` | **Create** — AFTER_IMPLEMENTATION: test + spec verify + retry |
| `aide_deepcode/aide_deepcode_config.json` | **Create** — AIDE gate type defaults (optional override) |

No modifications to existing AIDE files. No modifications to DeepCode source.

---

### Task 1: Create package skeleton and config

**Files:**
- Create: `aide_deepcode/__init__.py`
- Create: `aide_deepcode/aide_deepcode_config.json`

- [ ] **Step 1: Write `__init__.py`**

```python
"""
AIDE — AI-Driven Development Automation for DeepCode

Usage:
    from aide_deepcode import register_aide_plugins
    register_aide_plugins()  # Call once during DeepCode startup
"""

from .aide_spec_plugin import AideSpecPlugin
from .aide_plan_plugin import AidePlanPlugin
from .aide_implement_plugin import AideImplementPlugin
from .aide_test_plugin import AideTestPlugin


def register_aide_plugins(registry=None):
    """Register all AIDE plugins with the DeepCode PluginRegistry.

    Args:
        registry: DeepCode PluginRegistry instance. If None, uses the
                  default registry from workflows.plugins.
    """
    if registry is None:
        from workflows.plugins import get_default_registry
        registry = get_default_registry(auto_register=False)

    for plugin_cls in [AideSpecPlugin, AidePlanPlugin, AideImplementPlugin, AideTestPlugin]:
        plugin = plugin_cls()
        registry.register(plugin)

    return registry
```

- [ ] **Step 2: Write `aide_deepcode_config.json`**

```json
{
  "gates": {
    "spec": "confirm_skip",
    "plan": "confirm_skip",
    "implement": "auto",
    "test": "auto"
  },
  "test": {
    "max_retries": 3
  },
  "review": {
    "max_rounds": 2
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add aide_deepcode/__init__.py aide_deepcode/aide_deepcode_config.json
git commit -m "feat(deepcode): add package skeleton and config"
```

---

### Task 2: Create AideSpecPlugin

**Files:**
- Create: `aide_deepcode/aide_spec_plugin.py`

- [ ] **Step 1: Write plugin class**

```python
"""
AideSpecPlugin — BEFORE_PLANNING hook.
Transforms user requirements into a structured specification.
"""

import json
import logging
from pathlib import Path
from typing import Any, Dict

from workflows.plugins.base import InteractionPlugin, InteractionPoint, InteractionRequest, InteractionResponse


class AideSpecPlugin(InteractionPlugin):
    name = "aide_spec"
    description = "AIDE spec stage: requirements → structured specification"
    hook_point = InteractionPoint.BEFORE_PLANNING
    priority = 50  # Run before DeepCode's own RequirementAnalysisPlugin (priority 100)

    SPEC_SCHEMA_PATH = Path(__file__).parent.parent / "aide-core" / "schemas" / "spec.schema.json"

    def __init__(self, enabled: bool = True, config: Dict = None):
        super().__init__(enabled=enabled, config=config)
        self._load_gate_config()

    def _load_gate_config(self):
        config_path = Path(__file__).parent / "aide_deepcode_config.json"
        if config_path.exists():
            with open(config_path) as f:
                cfg = json.load(f)
            self.gate_type = cfg.get("gates", {}).get("spec", "confirm_skip")
        else:
            self.gate_type = "confirm_skip"

    async def should_trigger(self, context: Dict[str, Any]) -> bool:
        return context.get("user_input") is not None

    async def create_interaction(self, context: Dict[str, Any]) -> InteractionRequest:
        user_input = context["user_input"]

        spec = await self._generate_spec(user_input)
        context["aide_spec"] = spec

        if self.gate_type == "auto":
            return None  # Skip interaction

        required = self.gate_type == "confirm"
        return InteractionRequest(
            interaction_type="aide_spec_review",
            title="Review Specification",
            description=f"Review the generated spec:\n\n{spec.get('summary', '')}",
            data={"spec": spec},
            options={
                "y": "Approve",
                "skip": "Skip review",
                "n": "Reject — provide feedback"
            },
            required=required
        )

    async def _generate_spec(self, user_input: str) -> Dict[str, Any]:
        """Generate spec from user requirements using LLM."""
        # Load spec schema
        schema = json.loads(self.SPEC_SCHEMA_PATH.read_text()) if self.SPEC_SCHEMA_PATH.exists() else {}

        # Call LLM to generate spec (delegated to DeepCode's LLM runtime)
        from core.llm_runtime import get_workflow_provider
        provider = get_workflow_provider()

        prompt = f"""You are a requirements analyst. Transform the following user input into a structured specification.

User input: {user_input}

Output a JSON object with these fields:
- title: string
- summary: string (2-4 paragraphs)
- features: array of {{id: "F001", title: string, description: string, acceptance_criteria: [string]}}

Schema reference: {json.dumps(schema, indent=2)}

Return ONLY valid JSON."""

        result = await provider.generate(prompt)
        return json.loads(result)

    async def process_response(self, response: InteractionResponse, context: Dict[str, Any]) -> Dict[str, Any]:
        if response.action == "n":
            feedback = response.data.get("feedback", "")
            context["user_input"] = f"{context['user_input']}\n\nFeedback: {feedback}"
            # Re-generate spec with feedback
            spec = await self._generate_spec(context["user_input"])
            context["aide_spec"] = spec
        elif response.action == "skip":
            # Persist: upgrade gate to auto for future runs
            self._persist_gate_auto()
        return context

    async def on_skip(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return context

    def _persist_gate_auto(self):
        config_path = Path(__file__).parent / "aide_deepcode_config.json"
        if config_path.exists():
            with open(config_path) as f:
                cfg = json.load(f)
            cfg.setdefault("gates", {})["spec"] = "auto"
            with open(config_path, "w") as f:
                json.dump(cfg, f, indent=2)
```

- [ ] **Step 2: Commit**

```bash
git add aide_deepcode/aide_spec_plugin.py
git commit -m "feat(deepcode): add AideSpecPlugin for requirements → spec"
```

---

### Task 3: Create AidePlanPlugin

**Files:**
- Create: `aide_deepcode/aide_plan_plugin.py`

- [ ] **Step 1: Write plugin class**

```python
"""
AidePlanPlugin — AFTER_PLANNING hook.
Decomposes spec features into dependency-tracked implementation tasks.
"""

import json
import logging
from pathlib import Path
from typing import Any, Dict, List

from workflows.plugins.base import InteractionPlugin, InteractionPoint, InteractionRequest, InteractionResponse


class AidePlanPlugin(InteractionPlugin):
    name = "aide_plan"
    description = "AIDE plan stage: spec → implementation plan with dependency tracking"
    hook_point = InteractionPoint.AFTER_PLANNING
    priority = 50

    PLAN_SCHEMA_PATH = Path(__file__).parent.parent / "aide-core" / "schemas" / "plan.schema.json"

    def __init__(self, enabled: bool = True, config: Dict = None):
        super().__init__(enabled=enabled, config=config)
        self._load_gate_config()

    def _load_gate_config(self):
        config_path = Path(__file__).parent / "aide_deepcode_config.json"
        if config_path.exists():
            with open(config_path) as f:
                cfg = json.load(f)
            self.gate_type = cfg.get("gates", {}).get("plan", "confirm_skip")
        else:
            self.gate_type = "confirm_skip"

    async def should_trigger(self, context: Dict[str, Any]) -> bool:
        return context.get("aide_spec") is not None or context.get("planning_result") is not None

    async def create_interaction(self, context: Dict[str, Any]) -> InteractionRequest:
        spec = context.get("aide_spec", {})
        plan = await self._decompose_to_plan(spec)
        context["aide_plan"] = plan

        if self.gate_type == "auto":
            return None

        required = self.gate_type == "confirm"
        task_count = len(plan.get("tasks", []))
        feature_count = len(spec.get("features", []))
        return InteractionRequest(
            interaction_type="aide_plan_review",
            title="Review Implementation Plan",
            description=f"Implementation plan: {task_count} tasks across {feature_count} features.",
            data={"plan": plan},
            options={
                "y": "Approve",
                "skip": "Skip review",
                "n": "Reject — provide feedback"
            },
            required=required
        )

    async def _decompose_to_plan(self, spec: Dict[str, Any]) -> Dict[str, Any]:
        """Decompose spec features into implementation tasks with dependencies."""
        from core.llm_runtime import get_workflow_provider
        provider = get_workflow_provider()

        schema = json.loads(self.PLAN_SCHEMA_PATH.read_text()) if self.PLAN_SCHEMA_PATH.exists() else {}
        features = spec.get("features", [])

        prompt = f"""You are a technical planner. Decompose the following features into implementation tasks.

Features: {json.dumps(features, indent=2)}

For each task, specify:
- id: "T001", "T002"... (global sequence)
- feature_id: which feature this belongs to
- title: short summary
- description: detailed implementation instructions
- files_to_touch: exact file paths
- depends_on: task IDs that must complete first (empty array if none)
- order_hint: integer for ordering within the feature

Rules:
- Bottom-up decomposition: data/model → business logic → API/UI → tests
- Each task targets 2-5 minutes of work
- depends_on only for real dependencies (e.g., "need DB schema before API")
- No circular dependencies

Schema reference: {json.dumps(schema, indent=2)}

Return: {{"tasks": [...], "estimated_order": [...]}}"""

        result = await provider.generate(prompt)
        return json.loads(result)

    async def process_response(self, response: InteractionResponse, context: Dict[str, Any]) -> Dict[str, Any]:
        if response.action == "n":
            feedback = response.data.get("feedback", "")
            spec = context.get("aide_spec", {})
            spec["_feedback"] = feedback
            context["aide_spec"] = spec
            plan = await self._decompose_to_plan(spec)
            context["aide_plan"] = plan
        elif response.action == "skip":
            self._persist_gate_auto()
        return context

    async def on_skip(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return context

    def _persist_gate_auto(self):
        config_path = Path(__file__).parent / "aide_deepcode_config.json"
        if config_path.exists():
            with open(config_path) as f:
                cfg = json.load(f)
            cfg.setdefault("gates", {})["plan"] = "auto"
            with open(config_path, "w") as f:
                json.dump(cfg, f, indent=2)
```

- [ ] **Step 2: Commit**

```bash
git add aide_deepcode/aide_plan_plugin.py
git commit -m "feat(deepcode): add AidePlanPlugin for spec → plan.json decomposition"
```

---

### Task 4: Create AideImplementPlugin

**Files:**
- Create: `aide_deepcode/aide_implement_plugin.py`

- [ ] **Step 1: Write plugin class**

```python
"""
AideImplementPlugin — BEFORE_IMPLEMENTATION hook.
Reads plan.json, resolves task dependencies, dispatches to DeepCode Agent.
"""

import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Set
from collections import deque

from workflows.plugins.base import InteractionPlugin, InteractionPoint, InteractionRequest, InteractionResponse


class AideImplementPlugin(InteractionPlugin):
    name = "aide_implement"
    description = "AIDE implement stage: plan.json → code via DeepCode Agent with review gates"
    hook_point = InteractionPoint.BEFORE_IMPLEMENTATION
    priority = 50

    def __init__(self, enabled: bool = True, config: Dict = None):
        super().__init__(enabled=enabled, config=config)
        config_path = Path(__file__).parent / "aide_deepcode_config.json"
        if config_path.exists():
            with open(config_path) as f:
                cfg = json.load(f)
        self.max_review_rounds = (config or {}).get("review", {}).get("max_rounds", 2)

    async def should_trigger(self, context: Dict[str, Any]) -> bool:
        return context.get("aide_plan") is not None

    async def create_interaction(self, context: Dict[str, Any]) -> InteractionRequest:
        plan = context["aide_plan"]
        spec = context.get("aide_spec", {})

        # 1. Topological sort → ready queue
        tasks = plan.get("tasks", [])
        ready_queue, waiting = self._resolve_dependencies(tasks)

        # 2. Dispatch loop
        completed, blocked = await self._dispatch_tasks(ready_queue, waiting, spec)

        # 3. Aggregate results
        implement_result = {
            "completed_tasks": list(completed),
            "blocked_tasks": [{"task_id": tid, "reason": reason} for tid, reason in blocked],
            "changed_files": self._collect_changed_files(tasks, completed),
            "task_results": self._build_task_results(completed, blocked)
        }
        context["aide_implement"] = implement_result

        # Gate is auto — no interaction needed
        return None

    def _resolve_dependencies(self, tasks: List[Dict]) -> tuple:
        """Topological sort: return (ready_queue, waiting_set)."""
        ready = deque()
        waiting = {}

        for task in tasks:
            deps = task.get("depends_on", [])
            if not deps:
                ready.append(task)
            else:
                waiting[task["id"]] = task

        return ready, waiting

    def _are_deps_met(self, task_deps: List[str], completed: Set[str]) -> bool:
        return all(dep in completed for dep in task_deps)

    async def _dispatch_tasks(self, ready_queue: deque, waiting: Dict, spec: Dict) -> tuple:
        completed = set()
        blocked = set()

        while ready_queue:
            task = ready_queue.popleft()
            try:
                # Dispatch to DeepCode Agent for implementation
                await self._implement_task(task, spec)
                completed.add(task["id"])

                # Release waiting tasks
                for tid, wtask in list(waiting.items()):
                    if self._are_deps_met(wtask.get("depends_on", []), completed):
                        ready_queue.append(wtask)
                        del waiting[tid]

            except Exception as e:
                blocked.add((task["id"], str(e)))

        # Mark remaining waiting tasks as blocked
        for tid, task in waiting.items():
            blocked.add((tid, "dependency blocked"))

        return completed, blocked

    async def _implement_task(self, task: Dict, spec: Dict) -> None:
        """Dispatch single task to DeepCode Agent with review loop."""
        from core.compat import Agent

        description = task.get("description", "")
        files_to_touch = task.get("files_to_touch", [])

        for round_num in range(self.max_review_rounds + 1):
            # Implement
            agent = Agent()
            await agent.run(f"""Implement the following task:

{description}

Files to create/modify: {', '.join(files_to_touch)}

Spec context: {json.dumps(spec.get('features', []))}""")

            # Spec compliance review
            spec_ok = await self._spec_review(task, spec)
            if not spec_ok and round_num < self.max_review_rounds:
                continue

            # Code quality review
            quality_ok = await self._quality_review(task)
            if not quality_ok and round_num < self.max_review_rounds:
                continue

            if spec_ok and quality_ok:
                return

        raise Exception(f"Task {task['id']} failed after {self.max_review_rounds} review rounds")

    async def _spec_review(self, task: Dict, spec: Dict) -> bool:
        from core.llm_runtime import get_workflow_provider
        provider = get_workflow_provider()

        feature_id = task.get("feature_id", "")
        feature = next((f for f in spec.get("features", []) if f.get("id") == feature_id), {})

        prompt = f"""Review whether the implementation meets these acceptance criteria:

Feature: {feature.get('title', feature_id)}
Criteria: {json.dumps(feature.get('acceptance_criteria', []))}

Task: {task.get('title', '')}
Files: {json.dumps(task.get('files_to_touch', []))}

Does the implementation satisfy ALL criteria? Reply only "pass" or "fail: <reason>"."""

        result = await provider.generate(prompt)
        return result.strip().lower().startswith("pass")

    async def _quality_review(self, task: Dict) -> bool:
        from core.llm_runtime import get_workflow_provider
        provider = get_workflow_provider()

        prompt = f"""Review code quality for task: {task.get('title', '')}
Files: {json.dumps(task.get('files_to_touch', []))}

Check: error handling, edge cases, code patterns, test coverage.
Reply only "pass" or "fail: <reason>"."""

        result = await provider.generate(prompt)
        return result.strip().lower().startswith("pass")

    def _collect_changed_files(self, tasks: List[Dict], completed: Set[str]) -> List[str]:
        files = []
        for task in tasks:
            if task["id"] in completed:
                files.extend(task.get("files_to_touch", []))
        return list(set(files))

    def _build_task_results(self, completed: Set[str], blocked: set) -> List[Dict]:
        results = []
        for tid in completed:
            results.append({"task_id": tid, "status": "done"})
        for tid, reason in blocked:
            results.append({"task_id": tid, "status": "blocked", "reason": reason})
        return results

    async def process_response(self, response: InteractionResponse, context: Dict[str, Any]) -> Dict[str, Any]:
        return context  # No interaction for implement stage (auto gate)
```

- [ ] **Step 2: Commit**

```bash
git add aide_deepcode/aide_implement_plugin.py
git commit -m "feat(deepcode): add AideImplementPlugin for plan → code with review gates"
```

---

### Task 5: Create AideTestPlugin（含 retry overflow confirm）

**Files:**
- Create: `aide_deepcode/aide_test_plugin.py`

- [ ] **Step 1: Write plugin class**

```python
"""
AideTestPlugin — AFTER_IMPLEMENTATION hook.
Runs test suite, verifies spec compliance, checks coverage, with retry loop.
"""

import json
import logging
import subprocess
from pathlib import Path
from typing import Any, Dict, List

from workflows.plugins.base import InteractionPlugin, InteractionPoint, InteractionRequest, InteractionResponse


class AideTestPlugin(InteractionPlugin):
    name = "aide_test"
    description = "AIDE test stage: run tests, verify spec, check coverage, auto-retry"
    hook_point = InteractionPoint.AFTER_IMPLEMENTATION
    priority = 50

    TEST_SCHEMA_PATH = Path(__file__).parent.parent / "aide-core" / "schemas" / "test.schema.json"

    def __init__(self, enabled: bool = True, config: Dict = None):
        super().__init__(enabled=enabled, config=config)
        self.max_retries = 3
        config_path = Path(__file__).parent / "aide_deepcode_config.json"
        if config_path.exists():
            with open(config_path) as f:
                cfg = json.load(f)
            self.max_retries = cfg.get("test", {}).get("max_retries", 3)

    async def should_trigger(self, context: Dict[str, Any]) -> bool:
        impl = context.get("aide_implement")
        return impl is not None and len(impl.get("completed_tasks", [])) > 0

    async def create_interaction(self, context: Dict[str, Any]) -> InteractionRequest:
        implement = context["aide_implement"]
        spec = context.get("aide_spec", {})

        # Run test pipeline
        result = await self._run_test_pipeline(implement, spec)
        context["aide_test"] = result
        context.setdefault("aide_retries", 0)

        verdict = result.get("verdict", "manual")

        if verdict == "pass":
            return None  # Auto-complete, no interaction

        retries = context["aide_retries"]

        if retries < self.max_retries:
            # Auto-retry: feed back to implement stage
            context["aide_retries"] += 1

            if verdict == "fail":
                context["retry_reason"] = self._format_failures(result)
            else:
                context["retry_reason"] = "Test framework not detected. Add test setup."

            # Signal to re-run implement → test
            context["aide_retry_needed"] = True
            return None

        # retries >= max_retries: confirm gate
        summary = self._format_failure_summary(result, retries)
        return InteractionRequest(
            interaction_type="aide_test_confirm",
            title=f"Test Stage Failed ({retries} retries)",
            description=summary,
            data={"verdict": verdict, "result": result},
            options={
                "y": "Accept — I'll handle remaining issues",
                "n": "Retry — go back to implement and try 3 more rounds"
            },
            required=True
        )

    async def _run_test_pipeline(self, implement: Dict, spec: Dict) -> Dict[str, Any]:
        """Run complete test pipeline: tests + spec verify + coverage."""
        # 1. Detect and run test command
        test_suite = await self._run_test_suite()

        # 2. Spec verification
        spec_verification = await self._verify_spec(spec, implement)

        # 3. Coverage check
        coverage = self._check_coverage(implement)

        # 4. Determine verdict
        verdict = self._determine_verdict(test_suite, spec_verification)

        return {
            "test_suite": test_suite,
            "spec_verification": spec_verification,
            "coverage": coverage,
            "verdict": verdict
        }

    async def _run_test_suite(self) -> Dict:
        """Auto-detect and run project test command."""
        detectors = [
            (["pytest", "-v"], lambda: Path("pyproject.toml").exists() or Path("setup.cfg").exists()),
            (["npm", "test"], lambda: Path("package.json").exists()),
            (["go", "test", "./..."], lambda: Path("go.mod").exists()),
            (["cargo", "test"], lambda: Path("Cargo.toml").exists()),
            (["make", "test"], lambda: Path("Makefile").exists()),
        ]

        for cmd, detector in detectors:
            if detector():
                try:
                    output = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
                    passed, failed, skipped = self._parse_test_output(output.stdout, cmd[0])
                    return {
                        "passed": passed, "failed": failed, "skipped": skipped,
                        "command": " ".join(cmd), "output": output.stdout[-2000:]
                    }
                except Exception as e:
                    return {"passed": 0, "failed": 0, "skipped": 0, "command": " ".join(cmd), "output": str(e)}

        return {"passed": 0, "failed": 0, "skipped": 0, "command": "none", "output": "No test framework detected"}

    def _parse_test_output(self, output: str, framework: str) -> tuple:
        """Parse test output to count passed/failed/skipped."""
        passed = failed = skipped = 0
        if framework == "pytest":
            for line in output.split("\n"):
                if " passed" in line and "failed" in line:
                    import re
                    m = re.search(r'(\d+) passed', line)
                    if m: passed = int(m.group(1))
                    m = re.search(r'(\d+) failed', line)
                    if m: failed = int(m.group(1))
                    m = re.search(r'(\d+) skipped', line)
                    if m: skipped = int(m.group(1))
        return passed, failed, skipped

    async def _verify_spec(self, spec: Dict, implement: Dict) -> List[Dict]:
        """Verify completed features against acceptance criteria."""
        from core.llm_runtime import get_workflow_provider
        provider = get_workflow_provider()

        completed_ids = implement.get("completed_tasks", [])
        features = spec.get("features", [])
        results = []

        for feature in features:
            # Check if any task for this feature was completed
            prompt = f"""Review whether the implementation satisfies these criteria:

Feature: {feature.get('title', feature.get('id', ''))}
Acceptance Criteria: {json.dumps(feature.get('acceptance_criteria', []))}

For each criterion, reply: "pass", "fail", or "untestable" with evidence.
Return JSON: [{{"feature_id": "{feature.get('id', '')}", "criteria": "<criterion>", "status": "pass|fail|untestable", "evidence": "<reason>"}}]"""

            result = await provider.generate(prompt)
            try:
                items = json.loads(result)
                results.extend(items)
            except json.JSONDecodeError:
                pass

        return results

    def _check_coverage(self, implement: Dict) -> Dict:
        """Check which changed files have corresponding test files."""
        changed = implement.get("changed_files", [])
        with_tests, without_tests = [], []

        for f in changed:
            p = Path(f)
            test_patterns = [
                p.parent / "tests" / f"test_{p.name}",
                p.parent / f"__tests__" / f"{p.stem}.test{p.suffix}",
                Path(f"tests/test_{p.stem}{p.suffix}"),
                Path(f"{p.stem}_test{p.suffix}"),
            ]
            if any(tp.exists() for tp in test_patterns):
                with_tests.append(f)
            else:
                without_tests.append(f)

        total = len(changed)
        covered = len(with_tests)
        return {
            "files_with_tests": with_tests,
            "files_without_tests": without_tests,
            "overall": f"{int(covered/total*100)}% of changed files have test coverage" if total > 0 else "N/A"
        }

    def _determine_verdict(self, test_suite: Dict, spec_verification: List[Dict]) -> str:
        if test_suite.get("command") == "none":
            return "manual"
        if test_suite.get("failed", 0) > 0:
            return "fail"
        if any(v.get("status") == "fail" for v in spec_verification):
            return "fail"
        if all(v.get("status") == "pass" for v in spec_verification):
            return "pass"
        return "manual"

    def _format_failures(self, result: Dict) -> str:
        ts = result.get("test_suite", {})
        sv = result.get("spec_verification", [])
        fails = [v for v in sv if v.get("status") == "fail"]
        return f"Tests: {ts.get('failed', 0)} failed. Spec: {len(fails)} criteria not met."

    def _format_failure_summary(self, result: Dict, retries: int) -> str:
        ts = result.get("test_suite", {})
        sv = result.get("spec_verification", [])
        fails = [v for v in sv if v.get("status") == "fail"]
        return (
            f"Test stage failed after {retries} auto-retries.\n\n"
            f"Test suite: {ts.get('passed', 0)} passed, {ts.get('failed', 0)} failed, {ts.get('skipped', 0)} skipped\n"
            f"Spec verification: {len(fails)} criteria not met\n\n"
            f"Accept and proceed? (y/n)"
        )

    async def process_response(self, response: InteractionResponse, context: Dict[str, Any]) -> Dict[str, Any]:
        if response.action == "y":
            # User accepts — pipeline exits
            context["aide_retry_needed"] = False
        elif response.action == "n":
            # User wants more retries — reset counter
            context["aide_retries"] = 0
            context["aide_retry_needed"] = True
        return context

    async def on_skip(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return context
```

- [ ] **Step 2: Commit**

```bash
git add aide_deepcode/aide_test_plugin.py
git commit -m "feat(deepcode): add AideTestPlugin with retry loop and overflow confirm"
```

---

### Task 6: Verify and finalize

**Files:**
- None (verification only)

- [ ] **Step 1: Verify package structure**

```bash
ls aide_deepcode/__init__.py aide_deepcode/aide_spec_plugin.py aide_deepcode/aide_plan_plugin.py aide_deepcode/aide_implement_plugin.py aide_deepcode/aide_test_plugin.py aide_deepcode/aide_deepcode_config.json
```

Run: `python3 -c "import sys; sys.path.insert(0, '.'); from aide_deepcode import register_aide_plugins; print('Import: PASS')"`
Expected: "Import: PASS"

- [ ] **Step 2: Verify schemas are shared**

```bash
python3 -c "
import json
for name in ['spec', 'plan', 'implement', 'test']:
    path = f'aide-core/schemas/{name}.schema.json'
    schema = json.load(open(path))
    print(f'{name}.schema.json: {schema[\"title\"]}')
"
```
Expected: All 4 schemas load successfully

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(deepcode): add AIDE DeepCode integration — 4 plugins

- AideSpecPlugin: BEFORE_PLANNING — requirements → spec.json
- AidePlanPlugin: AFTER_PLANNING — spec → plan.json with dependencies
- AideImplementPlugin: BEFORE_IMPLEMENTATION — plan → code with review
- AideTestPlugin: AFTER_IMPLEMENTATION — test + spec verify + retry

All plugins extend DeepCode InteractionPlugin. Gates map to InteractionRequest.
Schemas shared from aide-core/. Zero changes to existing AIDE or DeepCode code.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```