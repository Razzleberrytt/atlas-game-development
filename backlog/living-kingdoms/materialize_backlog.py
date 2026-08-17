#!/usr/bin/env python3
"""Materialize and validate the Living Kingdoms 1,000-ticket candidate backlog."""

from __future__ import annotations

import base64
import csv
import io
import lzma
from pathlib import Path

HERE = Path(__file__).resolve().parent
SEED_GLOB = "master_backlog.csv.xz.b64.part*"
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
AUTHORIZATIONS = {"CANDIDATE", "AUTHORIZED", "DEFERRED", "SUPERSEDED"}


def fail(message: str) -> None:
    raise SystemExit(message)


def load_seed() -> tuple[list[str], list[dict[str, str]]]:
    parts = sorted(HERE.glob(SEED_GLOB))
    if len(parts) != 4:
        fail(f"Expected 4 backlog seed parts, found {len(parts)}.")

    encoded = "".join(path.read_text(encoding="utf-8").strip() for path in parts)
    try:
        raw = lzma.decompress(base64.b64decode(encoded)).decode("utf-8")
    except Exception as exc:
        fail(f"Unable to decode Living Kingdoms backlog seed: {exc}")

    reader = csv.DictReader(io.StringIO(raw))
    if not reader.fieldnames:
        fail("Backlog seed has no header.")

    rows = list(reader)
    if len(rows) != 1000:
        fail(f"Expected exactly 1000 Living Kingdoms tickets, found {len(rows)}.")

    ids = [row.get("ID", "") for row in rows]
    if len(set(ids)) != 1000 or ids[0] != "LKB-0001" or ids[-1] != "LKB-1000":
        fail("Backlog seed ticket IDs are missing, duplicated, or out of bounds.")

    return list(reader.fieldnames), rows


def valid_status(value: str) -> bool:
    return value in EXACT_STATUSES or value.startswith("BLOCKED — ")


def load_status(seed_ids: set[str]) -> dict[str, dict[str, str]]:
    if not STATUS_PATH.exists():
        return {}

    with STATUS_PATH.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            return {}

        missing = {"ID", *MUTABLE_FIELDS}.difference(reader.fieldnames)
        if missing:
            fail(f"status.csv is missing columns: {sorted(missing)}")

        result: dict[str, dict[str, str]] = {}
        building: list[str] = []

        for line_no, row in enumerate(reader, start=2):
            ticket_id = (row.get("ID") or "").strip()
            if not ticket_id:
                continue
            if ticket_id not in seed_ids:
                fail(f"Unknown ticket ID {ticket_id!r} in status.csv line {line_no}.")
            if ticket_id in result:
                fail(f"Duplicate status row for {ticket_id} at line {line_no}.")

            values = {field: (row.get(field) or "").strip() for field in MUTABLE_FIELDS}
            status = values["Status"]
            authorization = values["Authorization"]

            if status and not valid_status(status):
                fail(f"Invalid Status {status!r} for {ticket_id}.")
            if authorization and authorization not in AUTHORIZATIONS:
                fail(f"Invalid Authorization {authorization!r} for {ticket_id}.")

            source_execution = status in {
                "BUILDING",
                "BUILT — VERIFICATION PENDING",
                "VERIFIED",
            }
            if source_execution:
                if authorization != "AUTHORIZED":
                    fail(f"{ticket_id} is {status} but is not AUTHORIZED.")
                for required in ("Authority Reference", "Owner", "Branch"):
                    if not values[required]:
                        fail(f"{ticket_id} is {status} but has no {required}.")

            if status == "BUILDING":
                building.append(ticket_id)
                if not values["Claimed At"]:
                    fail(f"{ticket_id} is BUILDING but has no Claimed At timestamp.")

            if status in {"BUILT — VERIFICATION PENDING", "VERIFIED"} and not values["PR / Commit"]:
                fail(f"{ticket_id} is {status} but has no PR / Commit proof.")
            if status == "VERIFIED" and not values["Proof / Notes"]:
                fail(f"{ticket_id} is VERIFIED but has no Proof / Notes.")
            if status.startswith("BLOCKED — ") and not values["Blocker"]:
                fail(f"{ticket_id} is BLOCKED but has no concrete Blocker field.")

            result[ticket_id] = values

    if len(building) > 1:
        fail(
            "Living Kingdoms backlog permits at most one BUILDING ticket at a time; "
            f"found {building}. Mark blocked work BLOCKED before activating another ticket."
        )
    return result


def main() -> int:
    fieldnames, rows = load_seed()
    seed_ids = {row["ID"] for row in rows}
    overlays = load_status(seed_ids)

    for field in MUTABLE_FIELDS:
        if field not in fieldnames:
            fieldnames.append(field)

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
        if row["ID"] in overlays:
            row.update(overlays[row["ID"]])

    with OUTPUT_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    status_counts: dict[str, int] = {}
    auth_counts: dict[str, int] = {}
    for row in rows:
        status_counts[row["Status"]] = status_counts.get(row["Status"], 0) + 1
        auth_counts[row["Authorization"]] = auth_counts.get(row["Authorization"], 0) + 1

    print(f"Wrote {len(rows)} tickets to {OUTPUT_PATH}")
    print("Status:", ", ".join(f"{k}={v}" for k, v in sorted(status_counts.items())))
    print("Authorization:", ", ".join(f"{k}={v}" for k, v in sorted(auth_counts.items())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
