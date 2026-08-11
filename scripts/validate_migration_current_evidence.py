#!/usr/bin/env python3
"""Validate the current/re-extracted migration evidence stack.

Build-ahead task BA-006. The migration evidence under ``docs/migration`` is
split into two generations:

* ``docs/migration/*.json`` — historical damaged-archive manifests that are
  validated by ``validate_migration_manifests.py`` against the frozen 122-row
  recovered Workspace index. A green result proves those manifests are
  internally consistent, **not** that their evidence base is the latest
  preservation truth.
* ``docs/migration/current/*.json`` — the post-PR #228 re-extraction evidence
  that is the actual current source of truth for reconstruction planning.
  This file validates that stack.

What this script checks:

* every required current-evidence JSON file exists and parses;
* each current-evidence file uses the expected ``format_version`` / ``status``
  / ``evidence_level`` (where present);
* the ``source_rbxl.sha256`` recorded by every current-evidence file matches
  the canonical SHA-256 printed by ``verify_studio_import_package.py``;
* the workspace-index row count recorded in ``reextracted-world-evidence.json``
  matches the 1,775-row post-repair total the historical manifests are
  explicitly superseded by;
* each current-evidence file carries an explicit ``supersedes_for_current_planning``
  pointer (or its equivalent) when it claims to supersede historical evidence;
* the human-readable ``REEXTRACTED-WORLD-EVIDENCE.md`` reference agrees with
  the JSON on the headline numbers (28/28 sources, 1,775/1,775 rows).

Nothing here reads or changes runtime behavior. The current-evidence files are
inert data describing the verified re-extraction from the original RBXL.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from _console import use_utf8_output

ROOT = Path(__file__).resolve().parents[1]
CURRENT_DIR = ROOT / "docs" / "migration" / "current"
IMPORT_MANIFEST = (
    ROOT
    / "games"
    / "living-kingdoms"
    / "imports"
    / "studio-2026-08-07"
    / "manifest.json"
)
# Human-readable summary lives next to the README.md so it is found by anyone
# browsing docs/migration/, not buried inside current/. It must still agree
# with the current-evidence JSON.
SUMMARY_MD = ROOT / "docs" / "migration" / "REEXTRACTED-WORLD-EVIDENCE.md"

# Current post-repair totals. Historical damaged-archive evidence is 122 rows
# and 17/28 sources; these are the numbers every current-planning document
# must agree with.
POST_REPAIR_SOURCES = 28
POST_REPAIR_WORKSPACE_ROWS = 1775

# Required files and the schema they must satisfy.
REQUIRED_FILES: dict[str, dict[str, object]] = {
    "reextracted-world-evidence.json": {
        "status": "CURRENT_POST_REPAIR_EVIDENCE",
        "format_version": 1,
        "must_have_supersedes": True,
        "required_paths": {
            "workspace_index.rows": POST_REPAIR_WORKSPACE_ROWS,
        },
        "top_level_required": [
            "HubTown",
            "WorldStructures",
            "WorldPath",
            "Resources",
        ],
    },
    "reextracted-property-evidence.json": {
        "status": "BA-005_PROPERTY_EVIDENCE_V1",
        "format_version": 1,
        "must_have_supersedes": False,
    },
    "reextracted-property-evidence-manifest.json": {
        "status": "BA-005_PROPERTY_EVIDENCE_V1",
        "format_version": 1,
        "must_have_supersedes": False,
    },
    "reextracted-presentation-evidence.json": {
        "status": "BA-005_PRESENTATION_EVIDENCE_V1",
        "format_version": 1,
        "must_have_supersedes": False,
    },
}


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def fail(self, where: str, message: str) -> None:
        self.errors.append(f"{where}: {message}")


def _get(obj: object, dotted: str) -> object:
    cur: object = obj
    for part in re.findall(r"[^\.\[\]]+|\[\d+\]", dotted):
        if part.startswith("[") and part.endswith("]"):
            cur = cur[int(part[1:-1])]  # type: ignore[index]
        else:
            if not isinstance(cur, dict) or part not in cur:  # type: ignore[operator]
                return None
            cur = cur[part]  # type: ignore[index]
    return cur


def check_file(
    report: Report,
    name: str,
    spec: dict[str, object],
    canonical_rbxl_sha: str,
    canonical_rbxl_bytes: int,
) -> None:
    path = CURRENT_DIR / name
    label = f"docs/migration/current/{name}"
    if not path.is_file():
        report.fail(label, "required current-evidence file is missing")
        return

    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.fail(label, f"invalid JSON: {exc}")
        return

    fmt_version = document.get("format_version")
    if fmt_version != spec["format_version"]:
        report.fail(
            label,
            f"format_version must be {spec['format_version']!r}, got {fmt_version!r}",
        )

    status = document.get("status")
    if status != spec["status"]:
        report.fail(label, f"status must be {spec['status']!r}, got {status!r}")

    source = document.get("source_rbxl")
    if not isinstance(source, dict):
        report.fail(label, "source_rbxl block is missing or not an object")
    else:
        actual_sha = source.get("sha256")
        if actual_sha != canonical_rbxl_sha:
            report.fail(
                label,
                f"source_rbxl.sha256 must be {canonical_rbxl_sha!r}, got {actual_sha!r}",
            )
        actual_bytes = source.get("bytes")
        if actual_bytes != canonical_rbxl_bytes:
            report.fail(
                label,
                f"source_rbxl.bytes must be {canonical_rbxl_bytes}, got {actual_bytes!r}",
            )

    for dotted, expected in spec.get("required_paths", {}).items():  # type: ignore[union-attr]
        actual = _get(document, dotted)
        if actual != expected:
            report.fail(
                label,
                f"{dotted} must be {expected!r}, got {actual!r}",
            )

    if spec.get("must_have_supersedes") and "supersedes_for_current_planning" not in document:
        report.fail(
            label,
            "supersedes_for_current_planning block is required so historical "
            "evidence cannot be mistaken for current truth",
        )

    top_level_required = spec.get("top_level_required") or []
    if top_level_required:
        present = {entry.get("name") for entry in document.get("top_level") or []}
        for required_name in top_level_required:
            if required_name not in present:
                report.fail(
                    label,
                    f"top_level is missing required subtree {required_name!r}",
                )

    print(f"[migration-current] {label}: status={status!r}, source_sha=verified")


def check_human_readable(report: Report) -> None:
    """Confirm the markdown summary agrees with the current-evidence JSON."""
    label = "docs/migration/REEXTRACTED-WORLD-EVIDENCE.md"
    if not SUMMARY_MD.is_file():
        report.fail(label, "human-readable current evidence summary is missing")
        return

    text = SUMMARY_MD.read_text(encoding="utf-8")
    if "CURRENT_POST_REPAIR_EVIDENCE" not in text:
        report.fail(
            label,
            "must reference the CURRENT_POST_REPAIR_EVIDENCE status so "
            "agents reading only the markdown cannot mistake it for historical",
        )
    if f"{POST_REPAIR_SOURCES} / {POST_REPAIR_SOURCES}" not in text and \
       f"{POST_REPAIR_SOURCES}/{POST_REPAIR_SOURCES}" not in text:
        report.fail(
            label,
            f"must state the {POST_REPAIR_SOURCES}/{POST_REPAIR_SOURCES} source count",
        )
    if f"{POST_REPAIR_WORKSPACE_ROWS} / {POST_REPAIR_WORKSPACE_ROWS}" not in text and \
       f"{POST_REPAIR_WORKSPACE_ROWS}/{POST_REPAIR_WORKSPACE_ROWS}" not in text and \
       f"{POST_REPAIR_WORKSPACE_ROWS:,} / {POST_REPAIR_WORKSPACE_ROWS:,}" not in text:
        report.fail(
            label,
            f"must state the {POST_REPAIR_WORKSPACE_ROWS}/{POST_REPAIR_WORKSPACE_ROWS} "
            "Workspace row count",
        )
    if "122" not in text:
        report.fail(
            label,
            "must reference the historical 122-row figure so readers know the "
            "damaged-archive baseline is being explicitly superseded",
        )
    if "PR #228" not in text and "PR 228" not in text and "PR-228" not in text:
        report.fail(
            label,
            "must cite PR #228 (the preservation repair) so the supersession "
            "chain is auditable",
        )

    print(f"[migration-current] {label}: summary agrees with current evidence")


def main() -> int:
    if not CURRENT_DIR.is_dir():
        print(
            "[migration-current] ERROR: docs/migration/current is missing",
            file=sys.stderr,
        )
        return 1

    report = Report()
    try:
        import_manifest = json.loads(IMPORT_MANIFEST.read_text(encoding="utf-8"))
        canonical_rbxl_sha = import_manifest["source"]["sha256"]
        canonical_rbxl_bytes = import_manifest["source"]["size"]
        declared_sources = import_manifest["counts"]["unique_legacy_source_files_preserved"]
        declared_workspace_rows = import_manifest["counts"]["workspace_instances"]
    except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError) as exc:
        print(
            f"[migration-current] ERROR: cannot load canonical import manifest: {exc}",
            file=sys.stderr,
        )
        return 1

    if declared_sources != POST_REPAIR_SOURCES:
        report.fail(
            str(IMPORT_MANIFEST.relative_to(ROOT)),
            f"must declare {POST_REPAIR_SOURCES} preserved sources, got {declared_sources!r}",
        )
    if declared_workspace_rows != POST_REPAIR_WORKSPACE_ROWS:
        report.fail(
            str(IMPORT_MANIFEST.relative_to(ROOT)),
            "must declare the 1,775-row post-repair Workspace baseline, "
            f"got {declared_workspace_rows!r}",
        )

    for name, spec in REQUIRED_FILES.items():
        check_file(
            report,
            name,
            spec,
            canonical_rbxl_sha,
            canonical_rbxl_bytes,
        )
    check_human_readable(report)

    if report.errors:
        for error in report.errors:
            print(f"[migration-current] ERROR: {error}", file=sys.stderr)
        print(
            f"[migration-current] FAILED with {len(report.errors)} error(s)",
            file=sys.stderr,
        )
        return 1

    print(
        f"[migration-current] OK: {len(REQUIRED_FILES)} current-evidence file(s) "
        f"validated against canonical RBXL SHA and post-repair totals "
        f"({POST_REPAIR_SOURCES}/{POST_REPAIR_SOURCES} sources, "
        f"{POST_REPAIR_WORKSPACE_ROWS}/{POST_REPAIR_WORKSPACE_ROWS} Workspace rows)"
    )
    return 0


if __name__ == "__main__":
    use_utf8_output()
    raise SystemExit(main())
