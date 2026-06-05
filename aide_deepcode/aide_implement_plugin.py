"""
AideImplementPlugin — BEFORE_IMPLEMENTATION hook.
Reads plan.json, resolves task dependencies, dispatches to DeepCode Agent.
"""

import json
import sys
from collections import deque
from pathlib import Path
from typing import Any, Dict, List, Set

from workflows.plugins.base import InteractionPlugin, InteractionPoint, InteractionRequest, InteractionResponse


class AideImplementPlugin(InteractionPlugin):
    name = "aide_implement"
    description = "AIDE implement stage: plan.json → code via DeepCode Agent with review gates"
    hook_point = InteractionPoint.BEFORE_IMPLEMENTATION
    priority = 50

    def __init__(self, enabled: bool = True, config: Dict = None):
        super().__init__(enabled=enabled, config=config)
        self.max_review_rounds = 2
        config_path = Path(__file__).parent / "aide_deepcode_config.json"
        if config_path.exists():
            with open(config_path) as f:
                cfg = json.load(f)
            self.max_review_rounds = cfg.get("review", {}).get("max_rounds", 2)

    async def should_trigger(self, context: Dict[str, Any]) -> bool:
        return context.get("aide_plan") is not None

    async def create_interaction(self, context: Dict[str, Any]) -> InteractionRequest:
        plan = context["aide_plan"]
        spec = context.get("aide_spec", {})

        tasks = plan.get("tasks", [])
        ready_queue, waiting = self._resolve_dependencies(tasks)
        completed, blocked = await self._dispatch_tasks(ready_queue, waiting, spec)

        implement_result = {
            "completed_tasks": list(completed),
            "blocked_tasks": [{"task_id": tid, "reason": reason} for tid, reason in blocked],
            "changed_files": self._collect_changed_files(tasks, completed),
            "task_results": self._build_task_results(completed, blocked)
        }
        context["aide_implement"] = implement_result
        return None  # auto gate — no interaction

    def _resolve_dependencies(self, tasks: List[Dict]) -> tuple:
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
                await self._implement_task(task, spec)
                completed.add(task.get("id", "unknown"))
                for tid, wtask in list(waiting.items()):
                    if self._are_deps_met(wtask.get("depends_on", []), completed):
                        ready_queue.append(wtask)
                        del waiting[tid]
            except Exception as e:
                task_id = task.get("id", "unknown")
                print(f"ERROR: aide_implement_plugin: Task {task_id} failed: {e}", file=sys.stderr)
                blocked.add((task_id, str(e)))

        for tid, task in waiting.items():
            blocked.add((tid, "dependency blocked"))

        return completed, blocked

    async def _implement_task(self, task: Dict, spec: Dict) -> None:
        from core.compat import Agent
        from core.llm_runtime import get_workflow_provider

        provider = get_workflow_provider()
        description = task.get("description", "")
        files_to_touch = task.get("files_to_touch", [])

        for round_num in range(self.max_review_rounds + 1):
            agent = Agent()
            await agent.run(f"""Implement the following task:

{description}

Files to create/modify: {', '.join(files_to_touch)}

Spec context: {json.dumps(spec.get('features', []))}""")

            spec_ok = await self._spec_review(task, spec, provider)
            if not spec_ok and round_num < self.max_review_rounds:
                continue

            quality_ok = await self._quality_review(task, provider)
            if not quality_ok and round_num < self.max_review_rounds:
                continue

            if spec_ok and quality_ok:
                return

        raise Exception(f"Task {task.get('id', 'unknown')} failed after {self.max_review_rounds} review rounds")

    async def _spec_review(self, task: Dict, spec: Dict, provider) -> bool:
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

    async def _quality_review(self, task: Dict, provider) -> bool:
        prompt = f"""Review code quality for task: {task.get('title', '')}
Files: {json.dumps(task.get('files_to_touch', []))}

Check: error handling, edge cases, code patterns, test coverage.
Reply only "pass" or "fail: <reason>"."""
        result = await provider.generate(prompt)
        return result.strip().lower().startswith("pass")

    def _collect_changed_files(self, tasks: List[Dict], completed: Set[str]) -> List[str]:
        files = []
        for task in tasks:
            if task.get("id") in completed:
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
        return context
