#!/usr/bin/env python3
"""Validate the machine-readable Patch 0.7 acceptance matrix.

A matrix that names fixtures nobody runs, or claims rows nothing holds, is worse
than no matrix: it reports acceptance it cannot demonstrate. So this checks the
binding in both directions.

  - every Satisfied row names at least one fixture, and every fixture it names
    exists on disk;
  - every fixture a row names is actually executed by the persistence-hardening
    profile, so a green matrix corresponds to something that ran;
  - every Deferred row carries the reason it was not built, because an
    unexplained deferral is indistinguishable from an oversight.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from _console import use_utf8_output

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games" / "living-kingdoms"
MATRIX = ROOT / "docs" / "production" / "PATCH-0.7-ACCEPTANCE-MATRIX.json"


def load_profile_fixtures() -> set[str]:
    """Read the persistence-hardening fixture list out of the validator itself."""
    import validate  # noqa: PLC0415 - intentional local import; validate.py is the authority

    return set(validate.PERSISTENCE_HARDENING_FIXTURES)


def main() -> int:
    if not MATRIX.is_file():
        print(f"[patch-0.7-acceptance] missing matrix: {MATRIX}", file=sys.stderr)
        return 1

    document = json.loads(MATRIX.read_text(encoding="utf-8"))
    rows = document.get("rows")
    if not isinstance(rows, list) or not rows:
        print("[patch-0.7-acceptance] matrix has no rows", file=sys.stderr)
        return 1

    profile_fixtures = load_profile_fixtures()
    failures: list[str] = []
    seen_ids: set[str] = set()
    satisfied = 0
    deferred = 0
    bound_fixtures: set[str] = set()

    for row in rows:
        row_id = row.get("id")
        if not isinstance(row_id, str) or not row_id:
            failures.append("a row is missing its id")
            continue
        if row_id in seen_ids:
            failures.append(f"{row_id}: duplicate row id")
        seen_ids.add(row_id)

        statement = row.get("statement")
        if not isinstance(statement, str) or len(statement) < 20:
            failures.append(f"{row_id}: statement must say what is guaranteed")

        status = row.get("status")
        fixtures = row.get("fixtures")
        if not isinstance(fixtures, list):
            failures.append(f"{row_id}: fixtures must be a list")
            continue

        if status == "Satisfied":
            satisfied += 1
            if not fixtures:
                failures.append(f"{row_id}: a satisfied row must name at least one fixture")
            for name in fixtures:
                path = GAME / "tests" / f"{name}.test.luau"
                if not path.is_file():
                    failures.append(f"{row_id}: names a fixture that does not exist: {name}")
                    continue
                if name not in profile_fixtures:
                    failures.append(
                        f"{row_id}: names {name}, which the persistence-hardening profile does not run"
                    )
                bound_fixtures.add(name)
        elif status == "Deferred":
            deferred += 1
            note = row.get("note")
            if not isinstance(note, str) or len(note) < 30:
                failures.append(f"{row_id}: a deferred row must record why it was not built")
            if fixtures:
                failures.append(f"{row_id}: a deferred row must not claim fixtures")
        else:
            failures.append(f"{row_id}: unknown status {status!r}")

    unbound = sorted(profile_fixtures - bound_fixtures)
    if unbound:
        failures.append(
            "persistence-hardening runs fixtures no acceptance row claims: " + ", ".join(unbound)
        )

    if failures:
        for failure in failures:
            print(f"[patch-0.7-acceptance] {failure}", file=sys.stderr)
        return 1

    print(
        f"[patch-0.7-acceptance] OK: {satisfied} satisfied rows bound to "
        f"{len(bound_fixtures)} fixtures, {deferred} deferred rows with recorded reasons"
    )
    return 0


if __name__ == "__main__":
    use_utf8_output()
    raise SystemExit(main())
