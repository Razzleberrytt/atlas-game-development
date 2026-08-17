#!/usr/bin/env python3
"""Materialize the Living Kingdoms 1,000-ticket candidate backlog.

The 1,000 definitions are generated deterministically from 40 auditable
workstreams x 25 auditable implementation dimensions. Live execution state
is overlaid from status.csv.

This inventory is subordinate to accepted runtime evidence,
docs/roadmap/EXECUTION-DASHBOARD.md, and the repository AGENTS contracts.
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WORKSTREAMS_PATH = HERE / "workstreams.json"
DIMENSIONS_PATH = HERE / "dimensions.json"
STATUS_PATH = HERE / "status.csv"
OUTPUT_PATH = HERE / "master_backlog.csv"

DEFINITION_FIELDS = [
    "ID",
    "Planning Priority",
    "Roadmap Layer",
    "Workstream",
    "Agent Lane",
    "Risk Tier",
    "Dimension",
    "Title",
    "Scope / Implementation",
    "Why It Matters",
    "Canonical Owner Hint",
    "Acceptance Criteria",
    "Minimum Validation",
    "Studio / Runtime Evidence",
    "Depends On",
    "Taxonomy Tags",
    "Impact",
    "Confidence",
    "Effort",
    "ROI Score",
    "Default Execution Status",
    "Default Authorization",
    "Open PR Overlap Guard",
    "Authority Note",
]

MUTABLE_FIELDS = (
    "Status",
    "Authorization",
    "Authority Reference",
    "Owner",
    "Claimed At",
    "Branch",
    "PR / Commit",
    "Blocker",
    "Proof / Notes",
)

EXACT_STATUSES = {
    "NOT STARTED",
    "BUILDING",
    "BUILT — VERIFICATION PENDING",
    "VERIFIED",
    "DEFERRED",
    "HISTORICAL",
}
AUTHORIZATIONS = {"CANDIDATE", "AUTHORIZED", "DEFERRED", "SUPERSEDED"}
IMPACT_BY_PRIORITY = {"P0": 5, "P1": 4, "P2": 3, "P3": 2}
VALIDATION_BY_RISK = {
    "R0": "python scripts/validate.py docs",
    "R1": "python scripts/validate.py fast; use full if CI/risk scope expands",
    "R2": "python scripts/validate.py full",
    "R3": "python scripts/validate.py full + focused targeted checks for persistence/security/value boundaries",
}
# These dimensions incur one additional planning-effort point for R3 workstreams.
# This mirrors the human XLSX planning model exactly.
R3_EFFORT_BUMP_DIMENSIONS = {4, 5, 10, 11, 12, 17, 20, 21, 25}


def load_json(path: Path) -> list[dict]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, list):
        raise SystemExit(f"{path.name} must contain a JSON list.")
    return value


def generate_definitions() -> list[dict[str, object]]:
    workstreams = load_json(WORKSTREAMS_PATH)
    dimensions = load_json(DIMENSIONS_PATH)
    if len(workstreams) != 40:
        raise SystemExit(f"Expected 40 workstreams, found {len(workstreams)}.")
    if len(dimensions) != 25:
        raise SystemExit(f"Expected 25 dimensions, found {len(dimensions)}.")

    rows: list[dict[str, object]] = []
    for workstream_index, workstream in enumerate(workstreams):
        priority = workstream["priority"]
        risk = workstream["risk"]
        if priority not in IMPACT_BY_PRIORITY:
            raise SystemExit(f"Unknown priority {priority!r} in workstream {workstream['name']!r}.")
        if risk not in VALIDATION_BY_RISK:
            raise SystemExit(f"Unknown risk tier {risk!r} in workstream {workstream['name']!r}.")

        base = workstream_index * len(dimensions)
        for dimension_index, dimension in enumerate(dimensions, start=1):
            ticket_number = base + dimension_index
            ticket_id = f"LKB-{ticket_number:04d}"
            dependencies = [
                f"LKB-{base + int(relative_dimension):04d}"
                for relative_dimension in dimension.get("depends_on", [])
            ]
            impact = IMPACT_BY_PRIORITY[priority]
            confidence = int(dimension["confidence"])
            effort = int(dimension["effort"])
            if risk == "R3" and dimension_index in R3_EFFORT_BUMP_DIMENSIONS:
                effort += 1
            roi_score = round((impact * confidence) / effort, 2)

            if dimension["name"] == "Studio evidence packet":
                runtime_evidence = (
                    f"Required evidence is defined by this ticket for {workstream['subject']}; "
                    "do not claim VERIFIED until that packet is captured."
                )
            else:
                runtime_evidence = (
                    "None by default; record BUILT — VERIFICATION PENDING if the ticket changes "
                    "engine/player-facing facts that require Studio/device evidence."
                )

            rows.append(
                {
                    "ID": ticket_id,
                    "Planning Priority": priority,
                    "Roadmap Layer": workstream["phase"],
                    "Workstream": workstream["name"],
                    "Agent Lane": workstream["lane"],
                    "Risk Tier": risk,
                    "Dimension": dimension["name"],
                    "Title": dimension["title"].format(subject=workstream["subject"]),
                    "Scope / Implementation": dimension["scope"].format(subject=workstream["subject"]),
                    "Why It Matters": (
                        f"Strengthens {workstream['subject']} while preserving the repository's "
                        "canonical-owner, low-WIP, server-authoritative development model."
                    ),
                    "Canonical Owner Hint": workstream["owner"],
                    "Acceptance Criteria": dimension["acceptance"].format(subject=workstream["subject"]),
                    "Minimum Validation": VALIDATION_BY_RISK[risk],
                    "Studio / Runtime Evidence": runtime_evidence,
                    "Depends On": "; ".join(dependencies),
                    "Taxonomy Tags": workstream["tags"],
                    "Impact": impact,
                    "Confidence": confidence,
                    "Effort": effort,
                    "ROI Score": roi_score,
                    "Default Execution Status": "NOT STARTED",
                    "Default Authorization": "CANDIDATE — DASHBOARD ACTIVATION REQUIRED",
                    "Open PR Overlap Guard": workstream["overlap"],
                    "Authority Note": (
                        "Candidate inventory only. EXECUTION-DASHBOARD.md and accepted runtime evidence "
                        "remain execution authority."
                    ),
                }
            )

    if len(rows) != 1000:
        raise SystemExit(f"Expected exactly 1000 Living Kingdoms tickets, generated {len(rows)}.")
    ids = [str(row["ID"]) for row in rows]
    if len(set(ids)) != len(ids) or ids[0] != "LKB-0001" or ids[-1] != "LKB-1000":
        raise SystemExit("Generated ticket IDs are not the expected unique LKB-0001..LKB-1000 sequence.")
    return rows


def valid_status(value: str) -> bool:
    return value in EXACT_STATUSES or value.startswith("BLOCKED — ")


def load_status() -> dict[str, dict[str, str]]:
    if not STATUS_PATH.exists():
        return {}

    with STATUS_PATH.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            return {}
        expected = {"ID", *MUTABLE_FIELDS}
        missing = expected.difference(reader.fieldnames)
        if missing:
            raise SystemExit(f"status.csv is missing columns: {sorted(missing)}")

        result: dict[str, dict[str, str]] = {}
        building_ids: list[str] = []
        for line_no, row in enumerate(reader, start=2):
            ticket_id = (row.get("ID") or "").strip()
            if not ticket_id:
                continue
            if ticket_id in result:
                raise SystemExit(f"Duplicate status row for {ticket_id} at line {line_no}.")

            status = (row.get("Status") or "").strip()
            authorization = (row.get("Authorization") or "").strip()
            authority_reference = (row.get("Authority Reference") or "").strip()
            owner = (row.get("Owner") or "").strip()
            claimed_at = (row.get("Claimed At") or "").strip()
            branch = (row.get("Branch") or "").strip()
            pr_commit = (row.get("PR / Commit") or "").strip()
            blocker = (row.get("Blocker") or "").strip()
            proof = (row.get("Proof / Notes") or "").strip()

            if status and not valid_status(status):
                raise SystemExit(f"Invalid Living Kingdoms Status {status!r} for {ticket_id}.")
            if authorization and authorization not in AUTHORIZATIONS:
                raise SystemExit(f"Invalid Authorization {authorization!r} for {ticket_id}.")

            if status in {"BUILDING", "BUILT — VERIFICATION PENDING", "VERIFIED"}:
                if authorization != "AUTHORIZED":
                    raise SystemExit(f"{ticket_id} is {status} but is not AUTHORIZED.")
                if not authority_reference:
                    raise SystemExit(f"{ticket_id} is {status} but has no Authority Reference.")
                if not owner or not branch:
                    raise SystemExit(f"{ticket_id} is {status} but lacks Owner or Branch.")

            if status == "BUILDING":
                building_ids.append(ticket_id)
                if not claimed_at:
                    raise SystemExit(f"{ticket_id} is BUILDING but has no Claimed At timestamp.")
            if status in {"BUILT — VERIFICATION PENDING", "VERIFIED"} and not pr_commit:
                raise SystemExit(f"{ticket_id} is {status} but has no PR / Commit proof.")
            if status == "VERIFIED" and not proof:
                raise SystemExit(f"{ticket_id} is VERIFIED but has no Proof / Notes.")
            if status.startswith("BLOCKED — "):
                reason = status.removeprefix("BLOCKED — ").strip()
                if not reason or not blocker:
                    raise SystemExit(f"{ticket_id} is BLOCKED but lacks a concrete Blocker reason.")

            result[ticket_id] = {field: (row.get(field) or "") for field in MUTABLE_FIELDS}

        if len(building_ids) > 1:
            raise SystemExit(
                "Living Kingdoms backlog permits at most one BUILDING ticket at a time; "
                f"found {building_ids}."
            )
        return result


def main() -> int:
    rows = generate_definitions()
    status_by_id = load_status()
    seed_ids = {str(row["ID"]) for row in rows}
    unknown = sorted(set(status_by_id).difference(seed_ids))
    if unknown:
        raise SystemExit(f"status.csv contains unknown ticket IDs: {unknown[:10]}")

    fieldnames = [*DEFINITION_FIELDS, *MUTABLE_FIELDS]
    for row in rows:
        row.update(
            {
                "Status": "NOT STARTED",
                "Authorization": "CANDIDATE",
                "Authority Reference": "",
                "Owner": "",
                "Claimed At": "",
                "Branch": "",
                "PR / Commit": "",
                "Blocker": "",
                "Proof / Notes": "",
            }
        )
        overlay = status_by_id.get(str(row["ID"]))
        if overlay is not None:
            row.update(overlay)

    with OUTPUT_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    counts: dict[str, int] = {}
    auth_counts: dict[str, int] = {}
    for row in rows:
        status = str(row.get("Status") or "NOT STARTED")
        authorization = str(row.get("Authorization") or "CANDIDATE")
        counts[status] = counts.get(status, 0) + 1
        auth_counts[authorization] = auth_counts.get(authorization, 0) + 1

    print(f"Wrote {len(rows)} tickets to {OUTPUT_PATH.relative_to(HERE.parent.parent)}")
    print("Status:", ", ".join(f"{key}={value}" for key, value in sorted(counts.items())))
    print("Authorization:", ", ".join(f"{key}={value}" for key, value in sorted(auth_counts.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
