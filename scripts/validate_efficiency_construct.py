#!/usr/bin/env python3
"""Strict validation for the compounding-development efficiency construct."""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EFFICIENCY = ROOT / "scripts" / "efficiency.py"
REGISTRY = ROOT / "config" / "efficiency" / "capabilities.json"
FLYWHEEL = ROOT / "docs" / "roadmap" / "DEVELOPMENT-FLYWHEEL.md"
OPS = ROOT / "docs" / "production" / "ENGINEERING-EFFICIENCY-OPS.md"
AGENTS = ROOT / "AGENTS.md"


def fail(message: str) -> None:
    raise RuntimeError(message)


def main() -> int:
    try:
        for path in (EFFICIENCY, REGISTRY, FLYWHEEL, OPS, AGENTS):
            if not path.exists():
                fail(f"required efficiency artifact missing: {path.relative_to(ROOT)}")

        spec = importlib.util.spec_from_file_location("atlas_efficiency", EFFICIENCY)
        if spec is None or spec.loader is None:
            fail("could not load scripts/efficiency.py")
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)

        data = json.loads(REGISTRY.read_text(encoding="utf-8"))
        errors = module.validate_registry(data)
        if errors:
            fail("capability registry invalid:\n- " + "\n- ".join(errors))

        agent_text = AGENTS.read_text(encoding="utf-8")
        required_agent_markers = (
            "scripts/efficiency.py audit",
            "scripts/efficiency.py registry",
            "DEVELOPMENT-FLYWHEEL.md",
        )
        for marker in required_agent_markers:
            if marker not in agent_text:
                fail(f"AGENTS.md does not wire efficiency construct: missing {marker!r}")

        ops_text = OPS.read_text(encoding="utf-8")
        for command in (
            "python scripts/efficiency.py audit",
            "python scripts/efficiency.py bootstrap",
            "python scripts/dev_metrics.py",
        ):
            if command not in ops_text:
                fail(f"efficiency ops doc missing command: {command}")

        print(f"Efficiency construct OK — {len(data['capabilities'])} capabilities registered")
        return 0
    except (RuntimeError, OSError, json.JSONDecodeError) as exc:
        print(f"Efficiency construct FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
