#!/usr/bin/env python3
"""Generate a derived project-reality view from the canonical LK coverage registry.

This tool intentionally does NOT create a second source of truth. It reads
config/coverage/living-kingdoms-development.json and converts coverage/evidence
facts into a smaller execution-facing vocabulary:

KEEP      proven/substantial implementation that should be preserved
HARDEN    substantial source implementation that still needs stronger evidence
COMPLETE  partial implementation that needs coherent completion
PROVE     experiential or unknown behavior that needs runtime/play evidence
LATER     not-started/deferred work that is not current implementation reality

Product-level CUT/non-goal decisions remain owned by current product authority.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "config" / "coverage" / "living-kingdoms-development.json"
REPORT = ROOT / "docs" / "production" / "PROJECT-REALITY-MAP.md"


def load_registry() -> dict:
    return json.loads(REGISTRY.read_text(encoding="utf-8"))


def item_id(registry: dict, number: int) -> str:
    return f"{registry['id_prefix']}-{number:0{registry['id_width']}d}"


def expand(registry: dict) -> list[dict]:
    overrides = registry.get("overrides", {})
    rows: list[dict] = []
    for section in registry["sections"]:
        for offset, title in enumerate(section["items"]):
            number = section["start"] + offset
            row = {
                "id": item_id(registry, number),
                "number": number,
                "title": title,
                "section_code": section["code"],
                "section_title": section["title"],
                "coverage_state": section["coverage_state"],
                "evidence_level": section["evidence_level"],
                "priority": section["priority"],
                "owner_hints": list(section.get("owner_hints", [])),
                "note": "",
            }
            override = overrides.get(row["id"], {})
            for key in ("coverage_state", "evidence_level", "priority", "owner_hints", "note"):
                if key in override:
                    row[key] = override[key]
            row["reality_action"] = classify(row)
            rows.append(row)
    return rows


def classify(row: dict) -> str:
    coverage = row["coverage_state"]
    evidence = row["evidence_level"]

    if coverage in {"not-started", "deferred", "not-applicable"}:
        return "LATER"
    if coverage == "blocked":
        return "HARDEN"
    if coverage == "unknown" or evidence == "none":
        return "PROVE"
    if coverage == "complete":
        return "KEEP"
    if coverage == "substantial":
        return "KEEP" if evidence in {"automated", "studio"} else "HARDEN"
    if coverage == "partial":
        return "COMPLETE"
    return "PROVE"


def render(registry: dict, rows: list[dict]) -> str:
    counts = Counter(row["reality_action"] for row in rows)
    lines = [
        "# Living Kingdoms — Project Reality Map",
        "",
        "**Status:** GENERATED DERIVED VIEW — NOT AN INDEPENDENT AUTHORITY  ",
        f"**Registry refreshed:** {registry['updated']}  ",
        "**Canonical source:** `config/coverage/living-kingdoms-development.json`  ",
        "**Generate:** `python scripts/project_reality.py sync`",
        "",
        "This report answers a narrower execution question: **what kind of work does current evidence imply?** It does not replace product authority, the execution dashboard, the patch roadmap, or the 300-area coverage registry.",
        "",
        "## Reality vocabulary",
        "",
        "- **KEEP** — preserve accepted/proven substantial implementation; do not casually rewrite it.",
        "- **HARDEN** — substantial source exists, but stronger validation/reliability evidence is still needed.",
        "- **COMPLETE** — partial implementation exists; finish the coherent player/system path before adding breadth.",
        "- **PROVE** — runtime/player-experience truth is unknown or unsupported; measure it instead of inventing more code.",
        "- **LATER** — not-started/deferred concern; it is not evidence that the current slice needs a new system.",
        "- **CUT** — intentionally absent here. Product-level cuts/non-goals belong to `docs/bible/00-current-product-authority.md`, not an inferred coverage heuristic.",
        "",
        "## Portfolio summary",
        "",
        "| Action | Concerns |",
        "|---|---:|",
    ]
    for action in ("KEEP", "HARDEN", "COMPLETE", "PROVE", "LATER"):
        lines.append(f"| **{action}** | {counts.get(action, 0)} |")

    lines.extend([
        "",
        "## Section reality",
        "",
        "| Section | Range | Coverage | Evidence | Derived action |",
        "|---|---:|---|---|---|",
    ])
    for section in registry["sections"]:
        srows = [row for row in rows if row["section_code"] == section["code"]]
        action_counts = Counter(row["reality_action"] for row in srows)
        dominant = action_counts.most_common(1)[0][0]
        lines.append(
            f"| {section['code']}. {section['title']} | {section['start']}–{section['end']} | "
            f"`{section['coverage_state']}` | `{section['evidence_level']}` | **{dominant}** |"
        )

    lines.extend([
        "",
        "## Highest-value unresolved reality",
        "",
        "The rows below are ordered to surface unknown player truth first, then partial P0/P1 implementation. This is still a diagnostic view; the execution dashboard decides NOW/NEXT.",
        "",
        "| ID | Concern | Section | Priority | Coverage | Evidence | Action |",
        "|---|---|---|---|---|---|---|",
    ])

    priority_rank = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
    action_rank = {"PROVE": 0, "COMPLETE": 1, "HARDEN": 2, "LATER": 3, "KEEP": 4}
    unresolved = sorted(
        (row for row in rows if row["reality_action"] != "KEEP"),
        key=lambda row: (action_rank[row["reality_action"]], priority_rank[row["priority"]], row["number"]),
    )
    for row in unresolved[:40]:
        lines.append(
            f"| {row['id']} | {row['title']} | {row['section_code']} | {row['priority']} | "
            f"`{row['coverage_state']}` | `{row['evidence_level']}` | **{row['reality_action']}** |"
        )

    lines.extend([
        "",
        "## AI/session routing rule",
        "",
        "Before changing code, an agent should resolve the target LK concern and use this decision order:",
        "",
        "```text",
        "KEEP     → reuse the canonical owner; change only for a demonstrated defect/accepted migration",
        "HARDEN   → strengthen reliability/evidence before redesigning",
        "COMPLETE → close the smallest coherent missing path",
        "PROVE    → obtain runtime/play evidence before speculative expansion",
        "LATER    → backlog unless the dashboard/product authority explicitly activates it",
        "CUT      → obey product authority; do not resurrect implicitly",
        "```",
        "",
        "## Anti-forever-project rule",
        "",
        "A low coverage score is **not** permission to implement everything. The project advances when the current playable slice meets its exit condition. Coverage identifies blind spots; it does not become the task queue.",
        "",
    ])
    return "\n".join(lines)


def expected() -> str:
    registry = load_registry()
    return render(registry, expand(registry))


def sync() -> None:
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(expected(), encoding="utf-8")
    print(f"[project-reality] wrote {REPORT.relative_to(ROOT)}")


def check() -> None:
    wanted = expected()
    if not REPORT.exists():
        raise ValueError(f"missing generated report: {REPORT.relative_to(ROOT)}")
    actual = REPORT.read_text(encoding="utf-8")
    if actual != wanted:
        raise ValueError(f"stale generated report: {REPORT.relative_to(ROOT)}")
    print("[project-reality] OK")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("report", "sync", "check"))
    args = parser.parse_args()
    try:
        if args.command == "report":
            print(expected())
        elif args.command == "sync":
            sync()
        else:
            check()
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f"[project-reality] FAILED\n{exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
