"""
AideTestPlugin — AFTER_IMPLEMENTATION hook.
Runs test suite, verifies spec compliance, checks coverage, with retry loop.
"""

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List

from workflows.plugins.base import InteractionPlugin, InteractionPoint, InteractionRequest, InteractionResponse


class AideTestPlugin(InteractionPlugin):
    name = "aide_test"
    description = "AIDE test stage: run tests, verify spec, check coverage, auto-retry"
    hook_point = InteractionPoint.AFTER_IMPLEMENTATION
    priority = 50

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

        result = await self._run_test_pipeline(implement, spec)
        context["aide_test"] = result
        context.setdefault("aide_retries", 0)

        verdict = result.get("verdict", "manual")

        if verdict == "pass":
            return None  # auto-complete

        retries = context["aide_retries"]

        if retries < self.max_retries:
            context["aide_retries"] += 1
            if verdict == "fail":
                context["retry_reason"] = self._format_failures(result)
            else:
                context["retry_reason"] = "Test framework not detected. Add test setup."
            context["aide_retry_needed"] = True
            return None  # auto-retry without interaction

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
        test_suite = await self._run_test_suite()
        spec_verification = await self._verify_spec(spec, implement)
        coverage = self._check_coverage(implement)
        verdict = self._determine_verdict(test_suite, spec_verification)

        return {
            "test_suite": test_suite,
            "spec_verification": spec_verification,
            "coverage": coverage,
            "verdict": verdict
        }

    async def _run_test_suite(self) -> Dict:
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
        passed = failed = skipped = 0
        if framework == "pytest":
            m = re.search(r'(\d+) passed', output)
            if m: passed = int(m.group(1))
            m = re.search(r'(\d+) failed', output)
            if m: failed = int(m.group(1))
            m = re.search(r'(\d+) skipped', output)
            if m: skipped = int(m.group(1))
        return passed, failed, skipped

    async def _verify_spec(self, spec: Dict, implement: Dict) -> List[Dict]:
        from core.llm_runtime import get_workflow_provider
        provider = get_workflow_provider()

        features = spec.get("features", [])
        results = []

        for feature in features:
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
                feature_id = feature.get('id', 'unknown')
                print(f"WARNING: aide_test_plugin._verify_spec: JSON decode failed for feature '{feature_id}'. Criteria not verified.", file=sys.stderr)
                print(f"WARNING: Raw output (first 300 chars): {result[:300]}", file=sys.stderr)

        return results

    def _check_coverage(self, implement: Dict) -> Dict:
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
            context["aide_retry_needed"] = False
        elif response.action == "n":
            context["aide_retries"] = 0
            context["aide_retry_needed"] = True
        return context

    async def on_skip(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return context
