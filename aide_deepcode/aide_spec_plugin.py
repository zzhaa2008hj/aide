"""
AideSpecPlugin — BEFORE_PLANNING hook.
Transforms user requirements into a structured specification.
"""

import json
from pathlib import Path
from typing import Any, Dict

from workflows.plugins.base import InteractionPlugin, InteractionPoint, InteractionRequest, InteractionResponse


class AideSpecPlugin(InteractionPlugin):
    name = "aide_spec"
    description = "AIDE spec stage: requirements → structured specification"
    hook_point = InteractionPoint.BEFORE_PLANNING
    priority = 50

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
            return None

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
        from core.llm_runtime import get_workflow_provider
        provider = get_workflow_provider()

        prompt = f"""You are a requirements analyst. Transform the following user input into a structured specification.

User input: {user_input}

Output a JSON object with these fields:
- title: string
- summary: string (2-4 paragraphs)
- features: array of {{id: "F001", title: string, description: string, acceptance_criteria: [string]}}

Return ONLY valid JSON."""

        result = await provider.generate(prompt)
        return json.loads(result)

    async def process_response(self, response: InteractionResponse, context: Dict[str, Any]) -> Dict[str, Any]:
        if response.action == "n":
            feedback = response.data.get("feedback", "")
            context["user_input"] = f"{context['user_input']}\n\nFeedback: {feedback}"
            spec = await self._generate_spec(context["user_input"])
            context["aide_spec"] = spec
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
            cfg.setdefault("gates", {})["spec"] = "auto"
            with open(config_path, "w") as f:
                json.dump(cfg, f, indent=2)
