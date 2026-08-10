#!/usr/bin/env python3
"""Strict validation for the compounding-development efficiency construct."""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EFFICIENCY = ROOT / "scripts" / "efficiency.py"
EXTENSION_TOOL = ROOT / "scripts" / "extension_cost.py"
EFFECT_ROUTE_TOOL = ROOT / "scripts" / "effect_routes.py"
REGISTRY = ROOT / "config" / "efficiency" / "capabilities.json"
EXTENSION_CONTRACTS = ROOT / "config" / "efficiency" / "extension-contracts.json"
EFFECT_ROUTES = ROOT / "config" / "efficiency" / "effect-owner-routes.json"
FLYWHEEL = ROOT / "docs" / "roadmap" / "DEVELOPMENT-FLYWHEEL.md"
OPS = ROOT / "docs" / "production" / "ENGINEERING-EFFICIENCY-OPS.md"
EXTENSION_MODEL = ROOT / "docs" / "production" / "EXTENSION-COST-MODEL.md"
EFFECT_ROUTE_MODEL = ROOT / "docs" / "production" / "EFFECT-OWNER-ROUTING.md"
AGENTS = ROOT / "AGENTS.md"
GAME_AGENTS = ROOT / "games" / "living-kingdoms" / "AGENTS.md"
PR_TEMPLATE = ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md"


def fail(message: str) -> None:
    raise RuntimeError(message)


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        fail(f"could not load {path.relative_to(ROOT)}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    try:
        required_paths = (
            EFFICIENCY,
            EXTENSION_TOOL,
            EFFECT_ROUTE_TOOL,
            REGISTRY,
            EXTENSION_CONTRACTS,
            EFFECT_ROUTES,
            FLYWHEEL,
            OPS,
            EXTENSION_MODEL,
            EFFECT_ROUTE_MODEL,
            AGENTS,
            GAME_AGENTS,
            PR_TEMPLATE,
        )
        for path in required_paths:
            if not path.exists():
                fail(f"required efficiency artifact missing: {path.relative_to(ROOT)}")

        efficiency_module = load_module("atlas_efficiency", EFFICIENCY)
        registry_data = json.loads(REGISTRY.read_text(encoding="utf-8"))
        registry_errors = efficiency_module.validate_registry(registry_data)
        if registry_errors:
            fail("capability registry invalid:\n- " + "\n- ".join(registry_errors))

        extension_module = load_module("atlas_extension_cost", EXTENSION_TOOL)
        extension_data = json.loads(EXTENSION_CONTRACTS.read_text(encoding="utf-8"))
        extension_errors = extension_module.validate_contracts(extension_data)
        if extension_errors:
            fail("extension contracts invalid:\n- " + "\n- ".join(extension_errors))

        capability_ids = {item["id"] for item in registry_data["capabilities"]}
        for contract in extension_data["contracts"]:
            if contract["capability_id"] not in capability_ids:
                fail(
                    f"extension contract {contract['id']!r} references unknown capability "
                    f"{contract['capability_id']!r}"
                )

        effect_route_module = load_module("atlas_effect_routes", EFFECT_ROUTE_TOOL)
        effect_route_data = json.loads(EFFECT_ROUTES.read_text(encoding="utf-8"))
        effect_route_errors = effect_route_module.validate_routes(effect_route_data)
        if effect_route_errors:
            fail("effect owner routes invalid:\n- " + "\n- ".join(effect_route_errors))

        agent_text = AGENTS.read_text(encoding="utf-8")
        required_agent_markers = (
            "scripts/efficiency.py audit",
            "scripts/efficiency.py registry",
            "DEVELOPMENT-FLYWHEEL.md",
        )
        for marker in required_agent_markers:
            if marker not in agent_text:
                fail(f"AGENTS.md does not wire efficiency construct: missing {marker!r}")

        game_agent_text = GAME_AGENTS.read_text(encoding="utf-8")
        for marker in (
            "scripts/extension_cost.py show",
            "scripts/extension_cost.py check",
            "scripts/effect_routes.py show",
            "scripts/effect_routes.py next",
            "EXTENSION-COST-MODEL.md",
            "EFFECT-OWNER-ROUTING.md",
        ):
            if marker not in game_agent_text:
                fail(f"game AGENTS.md does not wire compounding controls: missing {marker!r}")

        ops_text = OPS.read_text(encoding="utf-8")
        for command in (
            "python scripts/efficiency.py audit",
            "python scripts/efficiency.py bootstrap",
            "python scripts/dev_metrics.py",
        ):
            if command not in ops_text:
                fail(f"efficiency ops doc missing command: {command}")

        extension_model_text = EXTENSION_MODEL.read_text(encoding="utf-8")
        for command in (
            "python scripts/extension_cost.py list",
            "python scripts/extension_cost.py show",
            "python scripts/extension_cost.py check",
        ):
            if command not in extension_model_text:
                fail(f"extension-cost model missing command: {command}")

        effect_model_text = EFFECT_ROUTE_MODEL.read_text(encoding="utf-8")
        for command in (
            "python scripts/effect_routes.py validate",
            "python scripts/effect_routes.py list",
            "python scripts/effect_routes.py show",
            "python scripts/effect_routes.py next",
        ):
            if command not in effect_model_text:
                fail(f"effect-owner-routing model missing command: {command}")

        pr_text = PR_TEMPLATE.read_text(encoding="utf-8")
        for marker in ("Extension contract:", "extension_cost.py check", "REVIEW REQUIRED"):
            if marker not in pr_text:
                fail(f"PR template does not surface extension cost: missing {marker!r}")

        live_effects = sum(1 for route in effect_route_data["routes"] if route["status"] == "live")
        print(
            "Efficiency construct OK — "
            f"{len(registry_data['capabilities'])} capabilities, "
            f"{len(extension_data['contracts'])} extension contracts, "
            f"{len(effect_route_data['routes'])} effect routes ({live_effects} live)"
        )
        return 0
    except (RuntimeError, OSError, json.JSONDecodeError) as exc:
        print(f"Efficiency construct FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
