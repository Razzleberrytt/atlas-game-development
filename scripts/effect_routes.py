#!/usr/bin/env python3
"""Inspect and validate canonical gameplay-effect owner routes."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from _console import use_utf8_output

ROOT = Path(__file__).resolve().parents[1]
ROUTES_PATH = ROOT / "config" / "efficiency" / "effect-owner-routes.json"
CAPABILITIES_PATH = ROOT / "config" / "efficiency" / "capabilities.json"
ALLOWED_STATUSES = {"live", "owner-confirmed", "unresolved"}
ALLOWED_RISK_TIERS = {"R0", "R1", "R2", "R3"}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def contract_effect_ids(source_path: Path) -> list[str]:
    text = source_path.read_text(encoding="utf-8")
    match = re.search(r"export type EquipmentAffixEffectId\s*=\s*(.*?)(?:\n\n|export type)", text, re.S)
    if match is None:
        raise RuntimeError(f"could not parse EquipmentAffixEffectId from {source_path.relative_to(ROOT)}")
    return re.findall(r'"([A-Za-z0-9_]+)"', match.group(1))


def validate_routes(data: dict) -> list[str]:
    errors: list[str] = []
    if data.get("schema_version") != 1:
        errors.append("schema_version must equal 1")
    if data.get("project") != "living-kingdoms":
        errors.append("project must equal 'living-kingdoms'")

    source_value = data.get("source_contract")
    if not isinstance(source_value, str) or not source_value:
        errors.append("source_contract must be a non-empty path")
        return errors
    source_path = ROOT / source_value
    if not source_path.exists():
        errors.append(f"source_contract does not exist: {source_value}")
        return errors

    routes = data.get("routes")
    if not isinstance(routes, list) or not routes:
        errors.append("routes must be a non-empty list")
        return errors

    capability_ids: set[str] = set()
    if CAPABILITIES_PATH.exists():
        capability_data = load_json(CAPABILITIES_PATH)
        capability_ids = {item.get("id") for item in capability_data.get("capabilities", []) if isinstance(item, dict)}

    seen: set[str] = set()
    for index, route in enumerate(routes):
        prefix = f"routes[{index}]"
        if not isinstance(route, dict):
            errors.append(f"{prefix} must be an object")
            continue
        effect_id = route.get("effect_id")
        if not isinstance(effect_id, str) or not effect_id:
            errors.append(f"{prefix}.effect_id must be a non-empty string")
            continue
        if effect_id in seen:
            errors.append(f"duplicate effect_id: {effect_id}")
        seen.add(effect_id)

        status = route.get("status")
        if status not in ALLOWED_STATUSES:
            errors.append(f"{effect_id}: invalid status {status!r}")
        risk_tier = route.get("risk_tier")
        if risk_tier not in ALLOWED_RISK_TIERS:
            errors.append(f"{effect_id}: invalid risk_tier {risk_tier!r}")
        capability_id = route.get("capability_id")
        if capability_ids and capability_id not in capability_ids:
            errors.append(f"{effect_id}: unknown capability_id {capability_id!r}")
        if route.get("owner_kind") == "client":
            errors.append(f"{effect_id}: consequential effect owner may not be client")
        if not isinstance(route.get("extension_rule"), str) or not route.get("extension_rule"):
            errors.append(f"{effect_id}: extension_rule is required")

        selection = route.get("selection_resolver")
        if not isinstance(selection, str) or not (ROOT / selection).exists():
            errors.append(f"{effect_id}: selection_resolver missing or invalid: {selection!r}")

        canonical_owner = route.get("canonical_owner")
        composition_seam = route.get("composition_seam")
        shared_adapter = route.get("shared_adapter")
        tests = route.get("focused_tests")
        if not isinstance(tests, list):
            errors.append(f"{effect_id}: focused_tests must be a list")
            tests = []

        if status in {"live", "owner-confirmed"}:
            if not isinstance(canonical_owner, str) or not (ROOT / canonical_owner).exists():
                errors.append(f"{effect_id}: {status} route requires existing canonical_owner")
            if not isinstance(composition_seam, str) or not (ROOT / composition_seam).exists():
                errors.append(f"{effect_id}: {status} route requires existing composition_seam")
        if status == "live":
            if not isinstance(shared_adapter, str) or not (ROOT / shared_adapter).exists():
                errors.append(f"{effect_id}: live route requires existing shared_adapter")
            if not tests:
                errors.append(f"{effect_id}: live route requires focused_tests")
            for test in tests:
                if not isinstance(test, str) or not (ROOT / test).exists():
                    errors.append(f"{effect_id}: focused test does not exist: {test!r}")
        if status == "unresolved" and canonical_owner is not None:
            errors.append(f"{effect_id}: unresolved route must keep canonical_owner null until confirmed")

    expected = set(contract_effect_ids(source_path))
    missing = expected - seen
    extra = seen - expected
    if missing:
        errors.append("effect contract IDs missing routes: " + ", ".join(sorted(missing)))
    if extra:
        errors.append("route IDs not present in effect contract: " + ", ".join(sorted(extra)))
    return errors


def get_route(data: dict, effect_id: str) -> dict:
    for route in data["routes"]:
        if route["effect_id"] == effect_id:
            return route
    raise KeyError(effect_id)


def print_route(route: dict) -> None:
    print(f"{route['effect_id']}: {route['status']} ({route['risk_tier']})")
    print(f"  capability: {route['capability_id']}")
    print(f"  owner: {route['canonical_owner'] or 'UNRESOLVED'}")
    print(f"  composition: {route['composition_seam'] or 'UNRESOLVED'}")
    print(f"  adapter: {route['shared_adapter'] or 'NOT YET CREATED'}")
    print(f"  selector: {route['selection_resolver']}")
    print(f"  rule: {route['extension_rule']}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("validate")
    sub.add_parser("list")
    show = sub.add_parser("show")
    show.add_argument("effect_id")
    sub.add_parser("next")
    args = parser.parse_args()

    try:
        data = load_json(ROUTES_PATH)
        errors = validate_routes(data)
        if errors:
            print("Effect owner routes INVALID:", file=sys.stderr)
            for error in errors:
                print(f"- {error}", file=sys.stderr)
            return 1

        if args.command == "validate":
            counts = {status: 0 for status in sorted(ALLOWED_STATUSES)}
            for route in data["routes"]:
                counts[route["status"]] += 1
            print(
                "Effect owner routes OK — "
                + ", ".join(f"{status}={count}" for status, count in counts.items())
            )
            return 0
        if args.command == "list":
            for route in data["routes"]:
                print(f"{route['effect_id']:<24} {route['status']:<15} {route['risk_tier']}  {route['canonical_owner'] or 'UNRESOLVED'}")
            return 0
        if args.command == "show":
            try:
                route = get_route(data, args.effect_id)
            except KeyError:
                print(f"unknown effect_id: {args.effect_id}", file=sys.stderr)
                return 2
            print_route(route)
            return 0
        if args.command == "next":
            confirmed = [route for route in data["routes"] if route["status"] == "owner-confirmed"]
            unresolved = [route for route in data["routes"] if route["status"] == "unresolved"]
            if confirmed:
                print_route(confirmed[0])
                return 0
            if unresolved:
                print_route(unresolved[0])
                return 0
            print("All registered effect routes are live.")
            return 0
    except (OSError, json.JSONDecodeError, RuntimeError) as exc:
        print(f"effect_routes failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    use_utf8_output()
    raise SystemExit(main())
