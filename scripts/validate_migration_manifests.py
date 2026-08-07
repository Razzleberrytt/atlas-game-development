#!/usr/bin/env python3
"""Validate the prepared combined-game migration manifests.

Build-ahead task BA-072. The manifests under ``docs/migration`` are the bridge
between the preserved Studio place and the canonical architecture, so they are
only useful if their references are real. This validator checks them against
the evidence they claim to be derived from:

* every legacy instance path and id must exist in the recovered Workspace index;
* every legacy script path must exist in the import ``manifest.json``;
* every canonical owner module must exist on disk;
* every dependency must resolve to a manifest entry, a declared gap, or a real
  build-ahead task id parsed from ``AGENT-BUILD-AHEAD-QUEUE.md``;
* dependencies between entries must not form a cycle;
* a manifest that declares a ``path_scope`` must claim every recovered row under
  that scope exactly once.

The manifests are inert data. Nothing here reads or changes runtime behavior.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MIGRATION_DIR = ROOT / "docs" / "migration"
QUEUE_PATH = ROOT / "docs" / "roadmap" / "AGENT-BUILD-AHEAD-QUEUE.md"
IMPORT_DIR = ROOT / "games" / "living-kingdoms" / "imports" / "studio-2026-08-07"
RECOVERED_WORKSPACE = IMPORT_DIR / "recovered" / "workspace-index-recovered.json"
IMPORT_MANIFEST = IMPORT_DIR / "manifest.json"

ALLOWED_DISPOSITIONS = {"KEEP", "MIGRATE", "REPLACE", "ARCHIVE"}
ALLOWED_KINDS = {"instance_group", "script"}
ALLOWED_EXTRACTION = {"recovered", "requires_studio_extraction"}
ENTRY_ID_PATTERN = re.compile(r"^[a-z0-9]+(?:[.-][a-z0-9]+)*$")
TASK_ID_PATTERN = re.compile(r"\bBA-\d{3}\b")


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def fail(self, manifest: str, message: str) -> None:
        self.errors.append(f"{manifest}: {message}")


def load_known_tasks() -> set[str]:
    if not QUEUE_PATH.is_file():
        return set()
    return set(TASK_ID_PATTERN.findall(QUEUE_PATH.read_text(encoding="utf-8")))


def load_recovered_rows() -> dict[str, list[dict[str, Any]]]:
    document = json.loads(RECOVERED_WORKSPACE.read_text(encoding="utf-8"))
    rows: dict[str, list[dict[str, Any]]] = {}
    for row in document["instances"]:
        rows.setdefault(row["path"], []).append(row)
    return rows


def load_known_scripts() -> set[str]:
    manifest = json.loads(IMPORT_MANIFEST.read_text(encoding="utf-8"))
    return {entry["path"] for entry in manifest["unique_files"]}


def check_entry_shape(report: Report, name: str, entry: dict[str, Any]) -> None:
    entry_id = entry.get("id", "<missing id>")
    if not ENTRY_ID_PATTERN.match(str(entry_id)):
        report.fail(name, f"entry id is not a stable lowercase id: {entry_id!r}")
    if entry.get("kind") not in ALLOWED_KINDS:
        report.fail(name, f"{entry_id}: kind must be one of {sorted(ALLOWED_KINDS)}")
    if entry.get("disposition") not in ALLOWED_DISPOSITIONS:
        report.fail(
            name, f"{entry_id}: disposition must be one of {sorted(ALLOWED_DISPOSITIONS)}"
        )
    if entry.get("extraction_status") not in ALLOWED_EXTRACTION:
        report.fail(
            name, f"{entry_id}: extraction_status must be one of {sorted(ALLOWED_EXTRACTION)}"
        )
    if not str(entry.get("summary", "")).strip():
        report.fail(name, f"{entry_id}: summary is empty")
    if not str(entry.get("canonical_representation", "")).strip():
        report.fail(name, f"{entry_id}: canonical_representation is empty")
    if not str(entry.get("runtime_gate", "")).strip():
        report.fail(name, f"{entry_id}: runtime_gate is empty")


def check_legacy_references(
    report: Report,
    name: str,
    entry: dict[str, Any],
    rows: dict[str, list[dict[str, Any]]],
    scripts: set[str],
) -> list[str]:
    """Return the recovered paths this entry legitimately claims."""
    entry_id = entry.get("id", "<missing id>")
    legacy = entry.get("legacy") or {}
    paths = legacy.get("paths") or []
    claimed: list[str] = []

    if not paths:
        report.fail(name, f"{entry_id}: legacy.paths is empty")
        return claimed

    if entry.get("kind") == "script":
        for path in paths:
            if path not in scripts:
                report.fail(name, f"{entry_id}: script path is not in the import manifest: {path}")
        return claimed

    declared_ids = list(legacy.get("instance_ids") or [])
    if len(declared_ids) != len(set(declared_ids)):
        report.fail(name, f"{entry_id}: legacy.instance_ids contains duplicates")
    if legacy.get("instance_count") != len(declared_ids):
        report.fail(
            name,
            f"{entry_id}: instance_count {legacy.get('instance_count')} does not match "
            f"{len(declared_ids)} instance ids",
        )

    observed_ids: list[int] = []
    for path in paths:
        matches = rows.get(path)
        if not matches:
            report.fail(name, f"{entry_id}: no recovered Workspace row for path {path}")
            continue
        claimed.append(path)
        observed_ids.extend(row["id"] for row in matches)

    if observed_ids and sorted(observed_ids) != sorted(declared_ids):
        report.fail(
            name,
            f"{entry_id}: instance ids {sorted(declared_ids)} do not match the recovered "
            f"rows {sorted(observed_ids)}",
        )

    return claimed


def check_canonical_owner(report: Report, name: str, entry: dict[str, Any]) -> None:
    entry_id = entry.get("id", "<missing id>")
    owner = entry.get("canonical_owner") or {}
    for module in owner.get("modules") or []:
        if not (ROOT / module).is_file():
            report.fail(name, f"{entry_id}: canonical owner module does not exist: {module}")
    created_by = owner.get("created_by")
    if not owner.get("modules") and created_by is None:
        report.fail(
            name,
            f"{entry_id}: entry has neither an existing canonical owner nor a created_by task",
        )


def check_dependencies(
    report: Report,
    name: str,
    entries: list[dict[str, Any]],
    gap_ids: set[str],
    known_tasks: set[str],
) -> None:
    entry_ids = {entry.get("id") for entry in entries}
    graph: dict[str, set[str]] = {}

    for entry in entries:
        entry_id = entry.get("id")
        local: set[str] = set()
        for dependency in entry.get("depends_on") or []:
            if dependency in entry_ids:
                local.add(dependency)
            elif dependency in gap_ids:
                continue
            elif TASK_ID_PATTERN.fullmatch(dependency):
                if known_tasks and dependency not in known_tasks:
                    report.fail(
                        name, f"{entry_id}: depends on unknown build-ahead task {dependency}"
                    )
            else:
                report.fail(name, f"{entry_id}: unresolved dependency {dependency!r}")
            if dependency == entry_id:
                report.fail(name, f"{entry_id}: entry depends on itself")
        graph[str(entry_id)] = local

    visiting: set[str] = set()
    done: set[str] = set()

    def walk(node: str, trail: list[str]) -> None:
        if node in done:
            return
        if node in visiting:
            cycle = " -> ".join(trail + [node])
            report.fail(name, f"dependency cycle: {cycle}")
            return
        visiting.add(node)
        for child in sorted(graph.get(node, ())):
            walk(child, trail + [node])
        visiting.discard(node)
        done.add(node)

    for node in sorted(graph):
        walk(node, [])


def check_coverage(
    report: Report,
    name: str,
    manifest: dict[str, Any],
    rows: dict[str, list[dict[str, Any]]],
    claims: dict[str, list[str]],
) -> None:
    scopes = (manifest.get("coverage") or {}).get("path_scope") or []
    if not scopes:
        return

    in_scope = {
        path
        for path in rows
        if any(path == scope or path.startswith(f"{scope}/") for scope in scopes)
    }

    seen: dict[str, str] = {}
    for entry_id, paths in claims.items():
        for path in paths:
            if path not in in_scope:
                continue
            if path in seen:
                report.fail(name, f"path claimed twice: {path} by {seen[path]} and {entry_id}")
            else:
                seen[path] = entry_id

    for path in sorted(in_scope - set(seen)):
        report.fail(name, f"recovered row in scope is not claimed by any entry: {path}")

    # A path can name several instances, so coverage counts rows, not paths.
    rows_in_scope = sum(len(rows[path]) for path in in_scope)
    declared = (manifest.get("coverage") or {}).get("rows_in_scope")
    if declared is not None and declared != rows_in_scope:
        report.fail(
            name, f"coverage claims {declared} rows in scope but {rows_in_scope} were recovered"
        )


def validate(path: Path, rows: dict[str, list[dict[str, Any]]], scripts: set[str],
             known_tasks: set[str], report: Report) -> None:
    name = str(path.relative_to(ROOT))
    manifest = json.loads(path.read_text(encoding="utf-8"))

    entries = manifest.get("entries")
    if not isinstance(entries, list) or not entries:
        report.fail(name, "manifest has no entries")
        return

    seen_ids: set[str] = set()
    claims: dict[str, list[str]] = {}
    for entry in entries:
        entry_id = str(entry.get("id"))
        if entry_id in seen_ids:
            report.fail(name, f"duplicate entry id: {entry_id}")
        seen_ids.add(entry_id)
        check_entry_shape(report, name, entry)
        claims[entry_id] = check_legacy_references(report, name, entry, rows, scripts)
        check_canonical_owner(report, name, entry)

    gaps = manifest.get("open_gaps") or []
    gap_ids: set[str] = set()
    for gap in gaps:
        gap_id = str(gap.get("id"))
        if gap_id in gap_ids:
            report.fail(name, f"duplicate gap id: {gap_id}")
        gap_ids.add(gap_id)
        for blocked in gap.get("blocks") or []:
            if known_tasks and TASK_ID_PATTERN.fullmatch(blocked) and blocked not in known_tasks:
                report.fail(name, f"{gap_id}: blocks unknown build-ahead task {blocked}")

    check_dependencies(report, name, entries, gap_ids, known_tasks)
    check_coverage(report, name, manifest, rows, claims)

    print(f"[migration] {name}: {len(entries)} entries, {len(gaps)} open gaps")


def main() -> int:
    if not MIGRATION_DIR.is_dir():
        print("[migration] ERROR: docs/migration is missing", file=sys.stderr)
        return 1

    manifests = sorted(MIGRATION_DIR.glob("*.json"))
    if not manifests:
        print("[migration] ERROR: no manifests found under docs/migration", file=sys.stderr)
        return 1

    rows = load_recovered_rows()
    scripts = load_known_scripts()
    known_tasks = load_known_tasks()
    report = Report()

    for path in manifests:
        validate(path, rows, scripts, known_tasks, report)

    if report.errors:
        for error in report.errors:
            print(f"[migration] ERROR: {error}", file=sys.stderr)
        print(f"[migration] FAILED with {len(report.errors)} error(s)", file=sys.stderr)
        return 1

    print(f"[migration] OK: {len(manifests)} manifest(s) validated against recovered evidence")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
