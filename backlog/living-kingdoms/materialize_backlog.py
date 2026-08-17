#!/usr/bin/env python3
"""Materialize the Living Kingdoms 1,000-ticket candidate backlog.

This backlog is a planning inventory subordinate to:
1. accepted runtime evidence/current Roblox behavior,
2. docs/roadmap/EXECUTION-DASHBOARD.md,
3. the repository AGENTS contracts.

Agents update status.csv. They do not edit the compressed ticket-definition seed.

Usage:
    python backlog/living-kingdoms/materialize_backlog.py
"""

from __future__ import annotations

import base64
import csv
import io
import lzma
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SEED_PATH = HERE / "master_backlog.csv.xz.b64"
STATUS_PATH = HERE / "status.csv"
OUTPUT_PATH = HERE / "master_backlog.csv"

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
AUTHORIZATIONS = {
    "CANDIDATE",
    "AUTHORIZED",
    "DEFERRED",
    "SUPERSEDED",
}


def load_seed() -> tuple[list[str], list[dict[str, str]]]:
    encoded = SEED_PATH.read_text(encoding="utf-8").strip()
    raw = lzma.decompress(base64.b64decode(encoded)).decode("utf-8")
    reader = csv.DictReader(io.StringIO(raw))
    if not reader.fieldnames:
        raise SystemExit("Backlog seed has no header.")
    rows = list(reader)
    if len(rows) != 1000:
        raise SystemExit(f"Expected exactly 1000 Living Kingdoms tickets, found {len(rows)}.")
    ids = [row.get("ID", "") for row in rows]
    if len(set(ids)) != len(ids):
        raise SystemExit("Backlog seed contains duplicate ticket IDs.")
    return list(reader.fieldnames), rows


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

            source_execution = status in {
                "BUILDING",
                "BUILT — VERIFICATION PENDING",
                "VERIFIED",
            }
            if source_execution:
                if authorization != "AUTHORIZED":
                    raise SystemExit(
                        f"{ticket_id} is {status} but is not AUTHORIZED by current execution authority."
                    )
                if not authority_reference:
                    raise SystemExit(
                        f"{ticket_id} is {status} but has no Authority Reference."
                    )
                if not owner:
                    raise SystemExit(f"{ticket_id} is {status} but has no Owner.")
                if not branch:
                    raise SystemExit(f"{ticket_id} is {status} but has no Branch.")

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
                    raise SystemExit(
                        f"{ticket_id} uses BLOCKED status but lacks a concrete Blocker reason."
                    )

            result[ticket_id] = {field: (row.get(field) or "") for field in MUTABLE_FIELDS}

        # Preserve the repo's deliberately low implementation WIP.
        # If current work becomes externally blocked, mark it BLOCKED before
        # authorizing/claiming the next implementation ticket.
        if len(building_ids) > 1:
            raise SystemExit(
                "Living Kingdoms backlog permits at most one BUILDING ticket at a time; "
                f"found {building_ids}."
            )

        return result


def main() -> int:
    fieldnames, rows = load_seed()
    status_by_id = load_status()
    seed_ids = {row["ID"] for row in rows}

    unknown = sorted(set(status_by_id).difference(seed_ids))
    if unknown:
        raise SystemExit(f"status.csv contains unknown ticket IDs: {unknown[:10]}")

    for field in MUTABLE_FIELDS:
        if field not in fieldnames:
            fieldnames.append(field)

    for row in rows:
        # Defaults in the seed are intentionally non-authorizing.
        row.setdefault("Status", row.get("Default Execution Status", "NOT STARTED"))
        row.setdefault("Authorization", "CANDIDATE")
        row.setdefault("Authority Reference", "")
        row.setdefault("Owner", "")
        row.setdefault("Claimed At", "")
        row.setdefault("Branch", "")
        row.setdefault("PR / Commit", "")
        row.setdefault("Blocker", "")
        row.setdefault("Proof / Notes", "")

        overlay = status_by_id.get(row["ID"])
        if overlay is not None:
            row.update(overlay)

    with OUTPUT_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    counts: dict[str, int] = {}
    auth_counts: dict[str, int] = {}
    for row in rows:
        status = row.get("Status") or "NOT STARTED"
        auth = row.get("Authorization") or "CANDIDATE"
        counts[status] = counts.get(status, 0) + 1
        auth_counts[auth] = auth_counts.get(auth, 0) + 1

    print(f"Wrote {len(rows)} tickets to {OUTPUT_PATH.relative_to(HERE.parent.parent)}")
    print("Status:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print("Authorization:", ", ".join(f"{k}={v}" for k, v in sorted(auth_counts.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
