#!/usr/bin/env python3
"""Validate the finite MVP 0.1 end-to-end chain audit."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAIN = ROOT / "config" / "coverage" / "mvp-0.1-chain.json"

VALID_STATUS = {"SOURCE_PRESENT", "PARTIAL", "UNMEASURED", "BLOCKED", "NOT_REQUIRED"}
VALID_EVIDENCE = {"source", "automated", "studio", "pr-candidate", "none"}


def fail(message: str) -> None:
    raise ValueError(message)


def main() -> int:
    try:
        data = json.loads(CHAIN.read_text(encoding="utf-8"))
        if data.get("schema_version") != 1:
            fail("schema_version must be 1")
        nodes = data.get("nodes")
        if not isinstance(nodes, list) or not nodes:
            fail("nodes must be a non-empty list")

        expected_ids = [f"MVP01-{number:02d}" for number in range(1, len(nodes) + 1)]
        actual_ids = [node.get("id") for node in nodes]
        if actual_ids != expected_ids:
            fail("MVP chain IDs must be contiguous and ordered")

        names: set[str] = set()
        for node in nodes:
            name = node.get("name")
            status = node.get("status")
            evidence = node.get("evidence")
            refs = node.get("evidence_refs")
            exit_condition = node.get("exit_condition")

            if not isinstance(name, str) or not name.strip():
                fail(f"{node.get('id')} must have a name")
            if name in names:
                fail(f"duplicate MVP chain name: {name}")
            names.add(name)

            if status not in VALID_STATUS:
                fail(f"{node['id']} has invalid status {status!r}")
            if evidence not in VALID_EVIDENCE:
                fail(f"{node['id']} has invalid evidence {evidence!r}")
            if not isinstance(refs, list) or not all(isinstance(ref, str) and ref for ref in refs):
                fail(f"{node['id']} evidence_refs must be a list of non-empty strings")
            if not isinstance(exit_condition, str) or not exit_condition.strip():
                fail(f"{node['id']} must define an observable exit_condition")

            if status == "SOURCE_PRESENT" and evidence == "none":
                fail(f"{node['id']} cannot claim SOURCE_PRESENT without evidence")
            if evidence in {"source", "automated", "studio", "pr-candidate"} and not refs:
                fail(f"{node['id']} evidence={evidence} requires evidence_refs")
            if evidence == "studio" and status == "UNMEASURED":
                fail(f"{node['id']} cannot be UNMEASURED when Studio evidence exists")
            if status == "NOT_REQUIRED" and node["id"] in {"MVP01-01", "MVP01-13"}:
                fail(f"{node['id']} is part of the MVP boundary and cannot be NOT_REQUIRED")

        blockers = [node for node in nodes if node["status"] in {"PARTIAL", "BLOCKED"}]
        unmeasured = [node for node in nodes if node["status"] == "UNMEASURED"]
        print(
            f"[mvp-chain] OK — {len(nodes)} links, "
            f"{len(blockers)} implementation blockers, {len(unmeasured)} unmeasured experience links"
        )
        for node in blockers:
            print(f"[mvp-chain] implementation: {node['id']} {node['name']}")
        for node in unmeasured:
            print(f"[mvp-chain] prove: {node['id']} {node['name']}")
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f"[mvp-chain] FAILED\n{exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
