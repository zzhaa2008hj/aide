"""
AidePlanPlugin — AFTER_PLANNING hook.
Decomposes spec features into dependency-tracked implementation tasks.
"""

import json
import sys
from pathlib import Path
from typing import Any, Dict

from workflows.plugins.base import InteractionPlugin, InteractionPoint, InteractionRequest, InteractionResponse


class AidePlanPlugin(InteractionPlugin):
    name = "aide_plan"
    description = "AIDE plan stage: spec → implementation plan with dependency tracking"
    hook_point = InteractionPoint.AFTER_PLANNING
    priority = 50

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
        return context.get("aide_spec") is not None

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
        from core.llm_runtime import get_workflow_provider
        provider = get_workflow_provider()

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
- depends_on only for real dependencies
- No circular dependencies

Return ONLY valid JSON: {{"tasks": [...], "estimated_order": [...]}}"""

        result = await provider.generate(prompt)
        try:
            return json.loads(result)
        except json.JSONDecodeError:
            print("ERROR: aide_plan_plugin: LLM returned non-JSON for plan decomposition. Falling back to empty plan.", file=sys.stderr)
            print(f"ERROR: Raw output (first 500 chars): {result[:500]}", file=sys.stderr)
            return {"tasks": [], "estimated_order": []}

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
