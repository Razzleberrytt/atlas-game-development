#!/usr/bin/env python3
"""Inspect and enforce low-cost extension paths for repeated Atlas feature families.

Commands:
  list                 List registered extension contracts.
  show <id>            Print the canonical recipe for extending one feature family.
  check <id> [--base]  Compare the current branch with a base ref and flag change-surface creep.

The budgets are review thresholds, not permission to bypass a real product/safety
requirement. If a legitimate change exceeds a budget, escalate deliberately and
improve the reusable seam when that will lower future marginal cost.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from _console import use_utf8_output

ROOT = Path(__file__).resolve().parents[1]
CONTRACTS = ROOT / "config" / "efficiency" / "extension-contracts.json"

ALLOWED_MATURITY = {"bespoke", "shared-owner", "registry-first", "data-first", "generated"}
ALLOWED_CHANGE_TYPE = {"code", "data", "data-plus-resolver", "registry-data"}
ALLOWED_VALIDATION = {"docs", "fast", "full"}


def load_contracts() -> dict[str, Any]:
    if not CONTRACTS.is_file():
        raise RuntimeError(f"missing extension contracts: {CONTRACTS.relative_to(ROOT)}")
    try:
        return json.loads(CONTRACTS.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"invalid extension-contract JSON: {exc}") from exc


def _valid_string_list(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(isinstance(item, str) and item for item in value)


def validate_contracts(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    if data.get("project") != "living-kingdoms":
        errors.append("project must be 'living-kingdoms'")
    contracts = data.get("contracts")
    if not isinstance(contracts, list) or not contracts:
        return errors + ["contracts must be a non-empty list"]

    required = {
        "id",
        "capability_id",
        "maturity",
        "goal",
        "preferred_change_type",
        "canonical_paths",
        "support_paths",
        "test_paths",
        "metadata_paths",
        "target_changed_files",
        "review_threshold_files",
        "authority_file_budget",
        "validation_profile",
        "steps",
        "escalate_when",
    }
    seen: set[str] = set()
    for index, contract in enumerate(contracts):
        label = f"contracts[{index}]"
        if not isinstance(contract, dict):
            errors.append(f"{label} must be an object")
            continue
        missing = required - contract.keys()
        if missing:
            errors.append(f"{label} missing keys: {', '.join(sorted(missing))}")
            continue
        cid = contract["id"]
        if not isinstance(cid, str) or not cid or cid in seen:
            errors.append(f"{label}.id must be a unique non-empty string")
        else:
            seen.add(cid)
        if contract["maturity"] not in ALLOWED_MATURITY:
            errors.append(f"{cid}: unsupported maturity {contract['maturity']!r}")
        if contract["preferred_change_type"] not in ALLOWED_CHANGE_TYPE:
            errors.append(f"{cid}: unsupported preferred_change_type {contract['preferred_change_type']!r}")
        if contract["validation_profile"] not in ALLOWED_VALIDATION:
            errors.append(f"{cid}: unsupported validation profile {contract['validation_profile']!r}")
        for key in ("canonical_paths", "support_paths", "test_paths", "metadata_paths", "steps", "escalate_when"):
            if not _valid_string_list(contract[key]):
                errors.append(f"{cid}: {key} must be a non-empty string list")
        for key in ("target_changed_files", "review_threshold_files", "authority_file_budget"):
            value = contract[key]
            if not isinstance(value, int) or value < 0:
                errors.append(f"{cid}: {key} must be a non-negative integer")
        if isinstance(contract["target_changed_files"], int) and isinstance(contract["review_threshold_files"], int):
            if contract["review_threshold_files"] < contract["target_changed_files"]:
                errors.append(f"{cid}: review threshold cannot be below target")
        for path_text in contract["canonical_paths"]:
            candidate = ROOT / path_text.rstrip("/")
            if not candidate.exists():
                errors.append(f"{cid}: canonical path does not exist: {path_text}")
    return errors


def contracts_by_id(data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {contract["id"]: contract for contract in data["contracts"]}


def matches(path: str, patterns: list[str]) -> bool:
    for pattern in patterns:
        if pattern.endswith("/"):
            if path.startswith(pattern):
                return True
        elif path == pattern:
            return True
    return False


def changed_files(base: str) -> list[str]:
    commands = (
        ["git", "diff", "--name-only", f"{base}...HEAD"],
        ["git", "diff", "--name-only", f"{base}..HEAD"],
    )
    for command in commands:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
        if result.returncode == 0:
            return sorted({line.strip() for line in result.stdout.splitlines() if line.strip()})
    raise RuntimeError(f"could not diff base ref {base!r}; fetch/update the base branch first")


def implementation_surface(paths: list[str]) -> list[str]:
    prefixes = ("games/living-kingdoms/src/", "games/living-kingdoms/tests/")
    return [path for path in paths if path.startswith(prefixes)]


def evaluate(contract: dict[str, Any], base: str) -> dict[str, Any]:
    changed = changed_files(base)
    surface = implementation_surface(changed)
    expected_patterns = (
        contract["canonical_paths"]
        + contract["support_paths"]
        + contract["test_paths"]
        + contract["metadata_paths"]
    )
    unexpected = [path for path in surface if not matches(path, expected_patterns)]
    support_touched = [path for path in surface if matches(path, contract["support_paths"])]
    authority_touched = [path for path in surface if path.startswith("games/living-kingdoms/src/server/")]

    reasons: list[str] = []
    if len(surface) > contract["review_threshold_files"]:
        reasons.append(
            f"implementation surface is {len(surface)} files; review threshold is {contract['review_threshold_files']}"
        )
    if len(authority_touched) > contract["authority_file_budget"]:
        reasons.append(
            f"server-authority surface is {len(authority_touched)} files; budget is {contract['authority_file_budget']}"
        )
    if unexpected:
        reasons.append(f"{len(unexpected)} implementation file(s) fall outside the registered extension path")

    return {
        "contract": contract["id"],
        "base": base,
        "maturity": contract["maturity"],
        "preferred_change_type": contract["preferred_change_type"],
        "target_changed_files": contract["target_changed_files"],
        "review_threshold_files": contract["review_threshold_files"],
        "authority_file_budget": contract["authority_file_budget"],
        "changed_files": changed,
        "implementation_surface": surface,
        "support_files_touched": support_touched,
        "authority_files_touched": authority_touched,
        "unexpected_implementation_files": unexpected,
        "within_budget": not reasons,
        "review_reasons": reasons,
    }


def print_contract(contract: dict[str, Any]) -> None:
    print(f"{contract['id']} — {contract['goal']}")
    print(f"maturity: {contract['maturity']} | preferred: {contract['preferred_change_type']}")
    print(
        "surface target: "
        f"{contract['target_changed_files']} files; review above {contract['review_threshold_files']}; "
        f"server-authority budget {contract['authority_file_budget']}"
    )
    print(f"validation: python scripts/validate.py {contract['validation_profile']}")
    print("\nCanonical paths:")
    for path in contract["canonical_paths"]:
        print(f"  - {path}")
    print("\nRecipe:")
    for index, step in enumerate(contract["steps"], start=1):
        print(f"  {index}. {step}")
    print("\nEscalate instead of forcing the cheap path when:")
    for reason in contract["escalate_when"]:
        print(f"  - {reason}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list")
    show = sub.add_parser("show")
    show.add_argument("contract_id")
    check = sub.add_parser("check")
    check.add_argument("contract_id")
    check.add_argument("--base", default="main")
    check.add_argument("--json", action="store_true")
    args = parser.parse_args()

    try:
        data = load_contracts()
        errors = validate_contracts(data)
        if errors:
            raise RuntimeError("extension contracts invalid:\n- " + "\n- ".join(errors))
        indexed = contracts_by_id(data)

        if args.command == "list":
            for contract in data["contracts"]:
                print(
                    f"{contract['id']}: {contract['maturity']} / target={contract['target_changed_files']} "
                    f"/ review>{contract['review_threshold_files']} / {contract['preferred_change_type']}"
                )
            return 0

        contract = indexed.get(args.contract_id)
        if contract is None:
            raise RuntimeError(f"unknown extension contract {args.contract_id!r}; run: python scripts/extension_cost.py list")

        if args.command == "show":
            print_contract(contract)
            return 0

        result = evaluate(contract, args.base)
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print_contract(contract)
            print("\nCurrent branch surface:")
            print(
                f"  {len(result['implementation_surface'])} implementation file(s); "
                f"{len(result['authority_files_touched'])} server-authority file(s)"
            )
            if result["support_files_touched"]:
                print("  support/seam code touched:")
                for path in result["support_files_touched"]:
                    print(f"    - {path}")
            if result["unexpected_implementation_files"]:
                print("  outside registered path:")
                for path in result["unexpected_implementation_files"]:
                    print(f"    - {path}")
            if result["within_budget"]:
                print("\nEXTENSION COST: WITHIN BUDGET")
                if len(result["implementation_surface"]) > contract["target_changed_files"]:
                    print("Note: above the preferred target but below the review threshold.")
            else:
                print("\nEXTENSION COST: REVIEW REQUIRED")
                for reason in result["review_reasons"]:
                    print(f"  - {reason}")
                print("Do not blindly shrink the diff; decide whether this is a legitimate semantic escalation or a reusable-seam problem.")
        return 0 if result["within_budget"] else 1
    except (RuntimeError, OSError) as exc:
        print(f"extension-cost FAILED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    use_utf8_output()
    raise SystemExit(main())
