#!/usr/bin/env python3
"""Materialize and validate the Living Kingdoms 1,000-ticket candidate backlog.

The 1,000 definitions are generated deterministically from 40 auditable
workstreams x 25 auditable implementation dimensions. Live execution state
is overlaid from status.csv.

Coordination state is guarded by active_claim.json. The single shared claim
file is intentionally a contention point: a claim/release transaction must
update it together with status.csv and land on main before implementation
ownership changes. This gives concurrent agents one merge-conflicting/CAS-like
mutex instead of relying on everyone noticing separate ticket rows.

This inventory is subordinate to accepted runtime evidence,
docs/roadmap/EXECUTION-DASHBOARD.md, and the repository AGENTS contracts.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
WORKSTREAMS_PATH = HERE / "workstreams.json"
DIMENSIONS_PATH = HERE / "dimensions.json"
STATUS_PATH = HERE / "status.csv"
ACTIVE_CLAIM_PATH = HERE / "active_claim.json"
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
STATUS_FIELDS = ("ID", *MUTABLE_FIELDS)
CLAIM_FIELDS = {
    "schema_version",
    "state",
    "ticket_id",
    "owner",
    "claimed_at",
    "branch",
    "authority_reference",
}

EXACT_STATUSES = {
    "NOT STARTED",
    "BUILDING",
    "BUILT — VERIFICATION PENDING",
    "VERIFIED",
    "DEFERRED",
    "HISTORICAL",
}
AUTHORIZATIONS = {"CANDIDATE", "AUTHORIZED", "DEFERRED", "SUPERSEDED"}
CLAIM_STATES = {"LOCKED", "UNLOCKED"}
SPECIALIST_LANES = {
    "QA & Performance",
    "Runtime & Networking",
    "Persistence & Security",
    "Combat",
    "Enemies & Encounters",
    "Expeditions & Procedural",
    "Loot & Progression",
    "World & Main World",
    "Co-op & Sessions",
    "UX & Input",
    "Presentation",
    "Content & Live Ops",
    "Release & Live Ops",
}
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
    if not all(isinstance(item, dict) for item in value):
        raise SystemExit(f"{path.name} must contain only JSON objects.")
    return value


def require_keys(item: dict, keys: set[str], *, source: str, label: str) -> None:
    missing = sorted(keys.difference(item))
    if missing:
        raise SystemExit(f"{source} {label} is missing required keys: {missing}")


def generate_definitions() -> list[dict[str, object]]:
    workstreams = load_json(WORKSTREAMS_PATH)
    dimensions = load_json(DIMENSIONS_PATH)
    if len(workstreams) != 40:
        raise SystemExit(f"Expected 40 workstreams, found {len(workstreams)}.")
    if len(dimensions) != 25:
        raise SystemExit(f"Expected 25 dimensions, found {len(dimensions)}.")

    workstream_keys = {
        "name",
        "phase",
        "lane",
        "risk",
        "priority",
        "subject",
        "owner",
        "tags",
        "overlap",
    }
    dimension_keys = {
        "name",
        "title",
        "scope",
        "acceptance",
        "effort",
        "confidence",
        "depends_on",
    }

    workstream_names: set[str] = set()
    for index, workstream in enumerate(workstreams, start=1):
        require_keys(workstream, workstream_keys, source=WORKSTREAMS_PATH.name, label=f"row {index}")
        name = str(workstream["name"]).strip()
        if not name:
            raise SystemExit(f"{WORKSTREAMS_PATH.name} row {index} has an empty name.")
        if name in workstream_names:
            raise SystemExit(f"Duplicate workstream name {name!r}.")
        workstream_names.add(name)
        if workstream["lane"] not in SPECIALIST_LANES:
            raise SystemExit(f"Unknown specialist lane {workstream['lane']!r} in workstream {name!r}.")

    dimension_names: set[str] = set()
    for index, dimension in enumerate(dimensions, start=1):
        require_keys(dimension, dimension_keys, source=DIMENSIONS_PATH.name, label=f"row {index}")
        name = str(dimension["name"]).strip()
        if not name:
            raise SystemExit(f"{DIMENSIONS_PATH.name} row {index} has an empty name.")
        if name in dimension_names:
            raise SystemExit(f"Duplicate dimension name {name!r}.")
        dimension_names.add(name)
        for relative_dimension in dimension.get("depends_on", []):
            try:
                dependency = int(relative_dimension)
            except (TypeError, ValueError) as exc:
                raise SystemExit(
                    f"{DIMENSIONS_PATH.name} row {index} has invalid dependency {relative_dimension!r}."
                ) from exc
            if dependency < 1 or dependency > len(dimensions) or dependency == index:
                raise SystemExit(
                    f"{DIMENSIONS_PATH.name} row {index} has invalid dependency dimension {dependency}."
                )

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
            if confidence < 1 or confidence > 5:
                raise SystemExit(
                    f"{DIMENSIONS_PATH.name} row {dimension_index} confidence must be 1..5, found {confidence}."
                )
            if effort < 1:
                raise SystemExit(
                    f"{DIMENSIONS_PATH.name} row {dimension_index} effort must be positive, found {effort}."
                )
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


def validate_timestamp(ticket_id: str, value: str) -> None:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise SystemExit(f"{ticket_id} has invalid Claimed At timestamp {value!r}.") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise SystemExit(f"{ticket_id} Claimed At must be timezone-aware ISO-8601, found {value!r}.")


def validate_branch(ticket_id: str, branch: str) -> None:
    if re.fullmatch(rf"lk/{re.escape(ticket_id)}-[a-z0-9][a-z0-9-]*", branch) is None:
        raise SystemExit(
            f"{ticket_id} branch {branch!r} violates required convention "
            f"'lk/{ticket_id}-short-description'."
        )


def load_status() -> dict[str, dict[str, str]]:
    if not STATUS_PATH.exists():
        raise SystemExit(f"{STATUS_PATH.name} is required for coordinated backlog execution.")

    with STATUS_PATH.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise SystemExit(f"{STATUS_PATH.name} has no header.")
        if tuple(reader.fieldnames) != STATUS_FIELDS:
            raise SystemExit(
                f"{STATUS_PATH.name} columns must exactly equal {list(STATUS_FIELDS)!r}; "
                f"found {reader.fieldnames!r}."
            )

        result: dict[str, dict[str, str]] = {}
        building_ids: list[str] = []
        for line_no, row in enumerate(reader, start=2):
            ticket_id = (row.get("ID") or "").strip()
            if not ticket_id:
                continue
            if re.fullmatch(r"LKB-\d{4}", ticket_id) is None:
                raise SystemExit(f"Invalid ticket ID {ticket_id!r} at {STATUS_PATH.name}:{line_no}.")
            if ticket_id in result:
                raise SystemExit(f"Duplicate status row for {ticket_id} at line {line_no}.")

            cleaned = {field: (row.get(field) or "").strip() for field in MUTABLE_FIELDS}
            status = cleaned["Status"]
            authorization = cleaned["Authorization"]
            authority_reference = cleaned["Authority Reference"]
            owner = cleaned["Owner"]
            claimed_at = cleaned["Claimed At"]
            branch = cleaned["Branch"]
            pr_commit = cleaned["PR / Commit"]
            blocker = cleaned["Blocker"]
            proof = cleaned["Proof / Notes"]

            if not status:
                raise SystemExit(f"{ticket_id} status row has no Status.")
            if not valid_status(status):
                raise SystemExit(f"Invalid Living Kingdoms Status {status!r} for {ticket_id}.")
            if not authorization:
                raise SystemExit(f"{ticket_id} status row has no Authorization.")
            if authorization not in AUTHORIZATIONS:
                raise SystemExit(f"Invalid Authorization {authorization!r} for {ticket_id}.")

            claimed_states = {"BUILDING", "BUILT — VERIFICATION PENDING", "VERIFIED"}
            if status in claimed_states or status.startswith("BLOCKED — "):
                if authorization != "AUTHORIZED":
                    raise SystemExit(f"{ticket_id} is {status} but is not AUTHORIZED.")
                if not authority_reference:
                    raise SystemExit(f"{ticket_id} is {status} but has no Authority Reference.")
                if not owner or not branch:
                    raise SystemExit(f"{ticket_id} is {status} but lacks Owner or Branch.")
                if not claimed_at:
                    raise SystemExit(f"{ticket_id} is {status} but has no Claimed At timestamp.")
                validate_timestamp(ticket_id, claimed_at)
                validate_branch(ticket_id, branch)

            if status == "BUILDING":
                building_ids.append(ticket_id)
            if status in {"BUILT — VERIFICATION PENDING", "VERIFIED"} and not pr_commit:
                raise SystemExit(f"{ticket_id} is {status} but has no PR / Commit proof.")
            if status == "VERIFIED" and not proof:
                raise SystemExit(f"{ticket_id} is VERIFIED but has no Proof / Notes.")
            if status.startswith("BLOCKED — "):
                reason = status.removeprefix("BLOCKED — ").strip()
                if not reason or not blocker:
                    raise SystemExit(f"{ticket_id} is BLOCKED but lacks a concrete Blocker reason.")
            elif blocker:
                raise SystemExit(f"{ticket_id} has Blocker metadata but status is {status!r}.")
            if status == "DEFERRED" and authorization != "DEFERRED":
                raise SystemExit(f"{ticket_id} is DEFERRED but Authorization is not DEFERRED.")

            result[ticket_id] = cleaned

        if len(building_ids) > 1:
            raise SystemExit(
                "Living Kingdoms backlog permits at most one BUILDING ticket at a time; "
                f"found {building_ids}."
            )
        return result


def load_active_claim() -> dict[str, object]:
    if not ACTIVE_CLAIM_PATH.exists():
        raise SystemExit(
            f"{ACTIVE_CLAIM_PATH.name} is required. Claims must use the shared coordination lock."
        )

    value = json.loads(ACTIVE_CLAIM_PATH.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"{ACTIVE_CLAIM_PATH.name} must contain one JSON object.")
    fields = set(value)
    if fields != CLAIM_FIELDS:
        missing = sorted(CLAIM_FIELDS.difference(fields))
        extra = sorted(fields.difference(CLAIM_FIELDS))
        raise SystemExit(
            f"{ACTIVE_CLAIM_PATH.name} schema mismatch; missing={missing}, extra={extra}."
        )
    if value["schema_version"] != 1:
        raise SystemExit(
            f"{ACTIVE_CLAIM_PATH.name} schema_version must be 1, found {value['schema_version']!r}."
        )
    state = value["state"]
    if state not in CLAIM_STATES:
        raise SystemExit(f"{ACTIVE_CLAIM_PATH.name} has invalid state {state!r}.")

    if state == "UNLOCKED":
        populated = [
            field
            for field in ("ticket_id", "owner", "claimed_at", "branch", "authority_reference")
            if value[field] not in (None, "")
        ]
        if populated:
            raise SystemExit(
                f"{ACTIVE_CLAIM_PATH.name} is UNLOCKED but still has claim data in {populated}."
            )
    else:
        for field in ("ticket_id", "owner", "claimed_at", "branch", "authority_reference"):
            raw = value[field]
            if not isinstance(raw, str) or not raw.strip():
                raise SystemExit(
                    f"{ACTIVE_CLAIM_PATH.name} is LOCKED but {field!r} is empty or not a string."
                )
            value[field] = raw.strip()
        ticket_id = str(value["ticket_id"])
        if re.fullmatch(r"LKB-\d{4}", ticket_id) is None:
            raise SystemExit(f"{ACTIVE_CLAIM_PATH.name} has invalid ticket_id {ticket_id!r}.")
        validate_timestamp(ticket_id, str(value["claimed_at"]))
        validate_branch(ticket_id, str(value["branch"]))
    return value


def validate_coordination(
    definitions: list[dict[str, object]],
    status_by_id: dict[str, dict[str, str]],
    active_claim: dict[str, object],
) -> None:
    seed_ids = {str(row["ID"]) for row in definitions}
    unknown = sorted(set(status_by_id).difference(seed_ids))
    if unknown:
        raise SystemExit(f"status.csv contains unknown ticket IDs: {unknown[:10]}")

    state = str(active_claim["state"])
    building = [
        (ticket_id, row)
        for ticket_id, row in status_by_id.items()
        if row["Status"] == "BUILDING"
    ]

    if state == "UNLOCKED":
        if building:
            raise SystemExit(
                f"{ACTIVE_CLAIM_PATH.name} is UNLOCKED but status.csv has BUILDING ticket "
                f"{building[0][0]}."
            )
        return

    claim_ticket_id = str(active_claim["ticket_id"])
    if claim_ticket_id not in seed_ids:
        raise SystemExit(
            f"{ACTIVE_CLAIM_PATH.name} references unknown ticket {claim_ticket_id!r}."
        )
    if len(building) != 1:
        raise SystemExit(
            f"{ACTIVE_CLAIM_PATH.name} is LOCKED for {claim_ticket_id} but status.csv has "
            f"{len(building)} BUILDING tickets."
        )

    building_ticket_id, building_row = building[0]
    if building_ticket_id != claim_ticket_id:
        raise SystemExit(
            f"Active claim locks {claim_ticket_id}, but status.csv BUILDING ticket is "
            f"{building_ticket_id}."
        )

    mirrors = {
        "owner": "Owner",
        "claimed_at": "Claimed At",
        "branch": "Branch",
        "authority_reference": "Authority Reference",
    }
    for claim_field, status_field in mirrors.items():
        claim_value = str(active_claim[claim_field])
        status_value = building_row[status_field]
        if claim_value != status_value:
            raise SystemExit(
                f"Active claim {claim_field}={claim_value!r} does not match "
                f"{building_ticket_id} {status_field}={status_value!r}."
            )


def overlay_status(
    definitions: list[dict[str, object]],
    status_by_id: dict[str, dict[str, str]],
) -> list[dict[str, object]]:
    for row in definitions:
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
    return definitions


def print_counts(rows: list[dict[str, object]]) -> None:
    counts: dict[str, int] = {}
    auth_counts: dict[str, int] = {}
    for row in rows:
        status = str(row.get("Status") or "NOT STARTED")
        authorization = str(row.get("Authorization") or "CANDIDATE")
        counts[status] = counts.get(status, 0) + 1
        auth_counts[authorization] = auth_counts.get(authorization, 0) + 1

    print("Status:", ", ".join(f"{key}={value}" for key, value in sorted(counts.items())))
    print(
        "Authorization:",
        ", ".join(f"{key}={value}" for key, value in sorted(auth_counts.items())),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate definitions, ledger, and active claim without writing master_backlog.csv",
    )
    args = parser.parse_args()

    rows = generate_definitions()
    status_by_id = load_status()
    active_claim = load_active_claim()
    validate_coordination(rows, status_by_id, active_claim)
    rows = overlay_status(rows, status_by_id)

    if args.check:
        print(
            "[living-kingdoms-backlog] OK — "
            f"{len(rows)} tickets; active_claim={active_claim['state']}; "
            f"building={sum(1 for row in rows if row['Status'] == 'BUILDING')}"
        )
        print_counts(rows)
        return 0

    fieldnames = [*DEFINITION_FIELDS, *MUTABLE_FIELDS]
    with OUTPUT_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} tickets to {OUTPUT_PATH.relative_to(HERE.parent.parent)}")
    print_counts(rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
