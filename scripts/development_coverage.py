#!/usr/bin/env python3
"""Validate and render the Living Kingdoms 300-area development coverage ontology."""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "config" / "coverage" / "living-kingdoms-development.json"
TAXONOMY = ROOT / "docs" / "architecture" / "DEVELOPMENT_TAXONOMY.md"
ATLAS = ROOT / "docs" / "architecture" / "DEVELOPMENT-ATLAS.md"
REPORT = ROOT / "docs" / "production" / "DEVELOPMENT-COVERAGE-REPORT.md"

VALID_COVERAGE = {
    "unknown",
    "not-started",
    "partial",
    "substantial",
    "complete",
    "deferred",
    "blocked",
    "not-applicable",
}
VALID_EVIDENCE = {"none", "section-inferred", "source-mapped", "automated", "studio"}
VALID_PRIORITIES = {"P0", "P1", "P2", "P3"}

COVERAGE_WEIGHT = {
    "unknown": 0.0,
    "not-started": 0.10,
    "partial": 0.50,
    "substantial": 0.80,
    "complete": 1.00,
    "deferred": 0.20,
    "blocked": 0.0,
    "not-applicable": 1.00,
}
EVIDENCE_WEIGHT = {
    "none": 0.0,
    "section-inferred": 0.25,
    "source-mapped": 0.60,
    "automated": 0.85,
    "studio": 1.00,
}


def load_registry() -> dict:
    return json.loads(REGISTRY.read_text(encoding="utf-8"))


def item_id(registry: dict, number: int) -> str:
    return f"{registry['id_prefix']}-{number:0{registry['id_width']}d}"


def expand(registry: dict) -> list[dict]:
    overrides = registry.get("overrides", {})
    rows: list[dict] = []
    for section in registry["sections"]:
        expected = section["end"] - section["start"] + 1
        if len(section["items"]) != expected:
            raise ValueError(
                f"section {section['code']} has {len(section['items'])} item titles; expected {expected}"
            )
        for offset, title in enumerate(section["items"]):
            number = section["start"] + offset
            row = {
                "id": item_id(registry, number),
                "number": number,
                "title": title,
                "section_code": section["code"],
                "section_title": section["title"],
                "engines": list(section["engines"]),
                "coverage_state": section["coverage_state"],
                "evidence_level": section["evidence_level"],
                "priority": section["priority"],
                "owner_hints": list(section.get("owner_hints", [])),
                "note": "",
            }
            override = overrides.get(row["id"], {})
            for key in (
                "engines",
                "coverage_state",
                "evidence_level",
                "priority",
                "owner_hints",
                "note",
            ):
                if key in override:
                    row[key] = override[key]
            rows.append(row)
    return rows


def validate_registry(registry: dict) -> list[dict]:
    errors: list[str] = []
    if registry.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    if registry.get("project") != "living-kingdoms":
        errors.append("project must be living-kingdoms")

    engines = registry.get("canonical_engines")
    if not isinstance(engines, list) or len(engines) != 12 or len(set(engines)) != 12:
        errors.append("canonical_engines must contain exactly 12 unique engine names")
        engines = engines or []

    sections = registry.get("sections", [])
    if len(sections) != 31:
        errors.append(f"expected 31 taxonomy sections; found {len(sections)}")

    expected_start = 1
    seen_codes: set[str] = set()
    for section in sections:
        code = section.get("code")
        if code in seen_codes:
            errors.append(f"duplicate section code: {code}")
        seen_codes.add(code)

        start = section.get("start")
        end = section.get("end")
        if start != expected_start:
            errors.append(f"section {code} starts at {start}; expected contiguous start {expected_start}")
        if not isinstance(start, int) or not isinstance(end, int) or end < start:
            errors.append(f"section {code} has invalid range")
            continue
        expected_start = end + 1

        if section.get("coverage_state") not in VALID_COVERAGE:
            errors.append(f"section {code} has invalid coverage_state")
        if section.get("evidence_level") not in VALID_EVIDENCE:
            errors.append(f"section {code} has invalid evidence_level")
        if section.get("priority") not in VALID_PRIORITIES:
            errors.append(f"section {code} has invalid priority")

        unknown_engines = set(section.get("engines", [])) - set(engines)
        if unknown_engines:
            errors.append(f"section {code} references unknown engines: {sorted(unknown_engines)}")
        if not section.get("owner_hints"):
            errors.append(f"section {code} must include owner_hints")

        items = section.get("items")
        if not isinstance(items, list) or not all(isinstance(title, str) and title.strip() for title in items):
            errors.append(f"section {code} has invalid item titles")
        elif len(items) != end - start + 1:
            errors.append(f"section {code} item count does not match its range")

    if expected_start != 301:
        errors.append(f"taxonomy must end at 300; next expected number is {expected_start}")

    try:
        rows = expand(registry)
    except ValueError as exc:
        errors.append(str(exc))
        rows = []

    ids = [row["id"] for row in rows]
    expected_ids = [item_id(registry, number) for number in range(1, 301)]
    if ids != expected_ids:
        errors.append("expanded taxonomy IDs are not exactly LK-001 through LK-300 in order")
    if len(set(ids)) != len(ids):
        errors.append("expanded taxonomy contains duplicate IDs")

    for key, override in registry.get("overrides", {}).items():
        if key not in expected_ids:
            errors.append(f"override references unknown item {key}")
        if "coverage_state" in override and override["coverage_state"] not in VALID_COVERAGE:
            errors.append(f"override {key} has invalid coverage_state")
        if "evidence_level" in override and override["evidence_level"] not in VALID_EVIDENCE:
            errors.append(f"override {key} has invalid evidence_level")
        if "priority" in override and override["priority"] not in VALID_PRIORITIES:
            errors.append(f"override {key} has invalid priority")
        unknown = set(override.get("engines", [])) - set(engines)
        if unknown:
            errors.append(f"override {key} references unknown engines: {sorted(unknown)}")

    for row in rows:
        if row["coverage_state"] == "complete" and row["evidence_level"] in {
            "none",
            "section-inferred",
            "source-mapped",
        }:
            errors.append(f"{row['id']} cannot be complete without automated or studio evidence")

    if errors:
        raise ValueError("\n".join(f"- {error}" for error in errors))
    return rows


def render_taxonomy(registry: dict, rows: list[dict]) -> str:
    lines = [
        "# Living Kingdoms — Development Taxonomy",
        "",
        "**Status:** CURRENT COVERAGE ONTOLOGY  ",
        f"**Registry refreshed:** {registry['updated']}  ",
        "**Machine source:** `config/coverage/living-kingdoms-development.json`  ",
        "**Generated by:** `python scripts/development_coverage.py sync`",
        "",
        "This is the canonical 300-area development taxonomy for Living Kingdoms. It is a **coverage ontology, not a module list**: an LK concern should normally map to an existing canonical owner/engine rather than create a competing runtime system.",
        "",
        "## Rules",
        "",
        "1. Preserve IDs `LK-001` through `LK-300`; rename only when meaning is preserved and the registry changes in the same commit.",
        "2. A taxonomy row describes a concern to cover, test, measure, or deliberately defer. It does not authorize a new service.",
        "3. Extend existing canonical owners first. Never use taxonomy completeness as justification for duplicate combat, progression, loot, persistence, networking, world, or presentation authority.",
        "4. Coverage state and evidence are separate. `substantial` does not mean `VERIFIED`, and `section-inferred` is not row-level proof.",
        "5. Product truth comes from current product authority; execution truth comes from the dashboard; runtime truth comes from canonical source plus accepted evidence.",
        "6. Update the registry during the same coherent change when implementation materially changes coverage.",
        "",
        "## Canonical engine chain",
        "",
        "```text",
        " → ".join(registry["canonical_engines"]),
        "```",
        "",
        "The chain is conceptual. A concern may map to multiple engines, and engines remain compositions of existing server/shared/client owners rather than mandatory one-service-per-engine objects.",
        "",
    ]
    by_section: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        by_section[row["section_code"]].append(row)

    for section in registry["sections"]:
        lines.extend(
            [
                f"## {section['code']}. {section['title']} ({section['start']}–{section['end']})",
                "",
                f"**Default coverage:** `{section['coverage_state']}` · **Evidence:** `{section['evidence_level']}` · **Priority:** `{section['priority']}`  ",
                f"**Engine map:** {' · '.join(section['engines'])}",
                "",
            ]
        )
        for row in by_section[section["code"]]:
            suffix = ""
            if row["id"] in registry.get("overrides", {}):
                suffix = f" — *override: {row['coverage_state']}, {row['evidence_level']}*"
            lines.append(f"- **{row['id']}** — {row['title']}{suffix}")
        lines.append("")

    lines.extend(
        [
            "## Working workflow",
            "",
            "```text",
            "detect gap or regression",
            "→ classify LK concern(s)",
            "→ identify canonical engine + real owner",
            "→ inspect dependencies / open PR overlap",
            "→ implement the smallest coherent change",
            "→ test at the correct risk tier",
            "→ measure player/runtime/system effect where applicable",
            "→ update coverage evidence/state",
            "→ validate generated taxonomy/report/atlas",
            "→ merge",
            "```",
            "",
            "Use `python scripts/development_coverage.py report` for the current gap summary and `python scripts/development_coverage.py atlas` for the engine/section map.",
            "",
        ]
    )
    return "\n".join(lines)


def score(row: dict) -> float:
    return 100.0 * (
        0.70 * COVERAGE_WEIGHT[row["coverage_state"]]
        + 0.30 * EVIDENCE_WEIGHT[row["evidence_level"]]
    )


def render_report(registry: dict, rows: list[dict]) -> str:
    state_counts = Counter(row["coverage_state"] for row in rows)
    evidence_counts = Counter(row["evidence_level"] for row in rows)
    avg = sum(score(row) for row in rows) / len(rows)
    section_rows: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        section_rows[row["section_code"]].append(row)

    lines = [
        "# Living Kingdoms — Development Coverage Report",
        "",
        "**Status:** GENERATED CURRENT-SNAPSHOT REPORT  ",
        f"**Registry refreshed:** {registry['updated']}  ",
        "**Source:** `config/coverage/living-kingdoms-development.json`  ",
        "**Regenerate:** `python scripts/development_coverage.py sync`",
        "",
        f"**Coverage health index:** **{avg:.1f}/100** across **{len(rows)}** taxonomy concerns.",
        "",
        "The index is a prioritization signal, not a release-readiness score. It intentionally discounts section-level inference and rewards attached evidence.",
        "",
        "## State distribution",
        "",
        "| State | Items |",
        "|---|---:|",
    ]
    for key in ("complete", "substantial", "partial", "not-started", "unknown", "deferred", "blocked", "not-applicable"):
        lines.append(f"| `{key}` | {state_counts.get(key, 0)} |")

    lines.extend(["", "## Evidence distribution", "", "| Evidence | Items |", "|---|---:|"])
    for key in ("studio", "automated", "source-mapped", "section-inferred", "none"):
        lines.append(f"| `{key}` | {evidence_counts.get(key, 0)} |")

    lines.extend(
        [
            "",
            "## Section health",
            "",
            "| Section | Range | Coverage | Evidence | Health | Engines |",
            "|---|---:|---|---|---:|---|",
        ]
    )
    for section in registry["sections"]:
        srows = section_rows[section["code"]]
        savg = sum(score(row) for row in srows) / len(srows)
        lines.append(
            f"| {section['code']}. {section['title']} | {section['start']}–{section['end']} | "
            f"`{section['coverage_state']}` | `{section['evidence_level']}` | {savg:.1f} | "
            f"{', '.join(section['engines'])} |"
        )

    gap_order = sorted(
        rows,
        key=lambda row: (
            score(row),
            {"P0": 0, "P1": 1, "P2": 2, "P3": 3}[row["priority"]],
            row["number"],
        ),
    )
    lines.extend(
        [
            "",
            "## Highest-evidence gaps",
            "",
            "The first gaps below are the lowest-health concerns after priority tie-breaking. They are **audit candidates**, not automatic implementation orders; dashboard dependencies and player value still decide execution.",
            "",
            "| ID | Concern | Section | Priority | Coverage | Evidence |",
            "|---|---|---|---|---|---|",
        ]
    )
    for row in gap_order[:25]:
        lines.append(
            f"| {row['id']} | {row['title']} | {row['section_code']} | {row['priority']} | "
            f"`{row['coverage_state']}` | `{row['evidence_level']}` |"
        )

    lines.extend(
        [
            "",
            "## Current interpretation",
            "",
            "- The registry is deliberately conservative: section-level inference must be replaced with row-level source/evidence mapping over time.",
            "- Active Main World topology/metrics work is represented in AB/AE without turning every metric into a new gameplay authority.",
            "- Current combat, architecture, security, testing, Roblox, infrastructure, and auditing surfaces are mapped as substantial but are not declared universally complete.",
            "- Player-psychology/game-feel rows remain unknown until play evidence supports stronger claims.",
            "- Housing and monetization remain not-started at taxonomy level rather than being inferred from roadmap prose.",
            "",
            "## Update discipline",
            "",
            "When a coherent change materially moves one or more LK rows, add an item override with the stronger/weaker state, evidence level, owner hints, and a short note. Do not mass-upgrade a section because one implementation exists.",
            "",
        ]
    )
    return "\n".join(lines)


def render_atlas(registry: dict, rows: list[dict]) -> str:
    engine_sections: dict[str, list[str]] = defaultdict(list)
    for section in registry["sections"]:
        for engine in section["engines"]:
            engine_sections[engine].append(section["code"])

    lines = [
        "# Living Kingdoms — Development Atlas",
        "",
        "**Status:** GENERATED ENGINE/COVERAGE MAP  ",
        f"**Registry refreshed:** {registry['updated']}  ",
        "**Source:** `config/coverage/living-kingdoms-development.json`  ",
        "**Regenerate:** `python scripts/development_coverage.py sync`",
        "",
        "The Development Atlas answers: **which canonical engine should absorb a development concern?** It prevents the 300-area taxonomy from becoming 300 bespoke systems.",
        "",
        "## Engine chain",
        "",
        "```text",
        " → ".join(registry["canonical_engines"]),
        "```",
        "",
        "These are conceptual responsibility engines. The real implementation owners remain the existing server/shared/client modules, registries, configs, tests, and tools.",
        "",
        "## Engine → taxonomy sections",
        "",
        "| Engine | Primary/related sections |",
        "|---|---|",
    ]
    for engine in registry["canonical_engines"]:
        labels = []
        for code in engine_sections[engine]:
            section = next(s for s in registry["sections"] if s["code"] == code)
            labels.append(f"{code} ({section['start']}–{section['end']})")
        lines.append(f"| {engine} | {', '.join(labels)} |")

    lines.extend(
        [
            "",
            "## Section → owner map",
            "",
            "| Section | Coverage | Evidence | Owner hints |",
            "|---|---|---|---|",
        ]
    )
    for section in registry["sections"]:
        lines.append(
            f"| {section['code']}. {section['title']} | `{section['coverage_state']}` | "
            f"`{section['evidence_level']}` | {'<br>'.join(section['owner_hints'])} |"
        )

    lines.extend(
        [
            "",
            "## Routing rule",
            "",
            "For any new feature, bug, metric, or polish request:",
            "",
            "1. classify the relevant `LK-###` concern(s);",
            "2. route through the listed engine(s);",
            "3. locate the existing real owner using `owner_hints`, capability/extension registries, tests, and source search;",
            "4. extend that owner or its stable data seam;",
            "5. create a new owner only when no canonical responsibility exists and the new boundary is explicit;",
            "6. attach evidence back to the registry instead of creating another status document.",
            "",
            "The Atlas is intentionally many-to-many: one owner can satisfy many taxonomy concerns, and one concern may cross several engines.",
            "",
        ]
    )
    return "\n".join(lines)


def generated_documents(registry: dict, rows: list[dict]) -> dict[Path, str]:
    # Every renderer ends with a deliberate blank line, so join() already emits
    # the canonical single final newline. Do not append a second newline here.
    return {
        TAXONOMY: render_taxonomy(registry, rows),
        ATLAS: render_atlas(registry, rows),
        REPORT: render_report(registry, rows),
    }


def check_generated(registry: dict, rows: list[dict]) -> None:
    mismatches = []
    for path, expected in generated_documents(registry, rows).items():
        if not path.exists():
            mismatches.append(f"missing generated document: {path.relative_to(ROOT)}")
            continue
        actual = path.read_text(encoding="utf-8")
        if actual != expected:
            mismatches.append(f"stale generated document: {path.relative_to(ROOT)}")
    if mismatches:
        raise ValueError("\n".join(mismatches))


def write_generated(registry: dict, rows: list[dict]) -> None:
    for path, content in generated_documents(registry, rows).items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        print(f"[development-coverage] wrote {path.relative_to(ROOT)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    validate_parser = sub.add_parser("validate")
    validate_parser.add_argument("--check-generated", action="store_true")
    sub.add_parser("report")
    sub.add_parser("atlas")
    sub.add_parser("taxonomy")
    sub.add_parser("sync")
    args = parser.parse_args()

    try:
        registry = load_registry()
        rows = validate_registry(registry)
        if args.command == "validate":
            if args.check_generated:
                check_generated(registry, rows)
            print(
                f"[development-coverage] OK — {len(rows)} items, "
                f"{len(registry['sections'])} sections, "
                f"{len(registry['canonical_engines'])} engines"
            )
        elif args.command == "sync":
            write_generated(registry, rows)
        elif args.command == "report":
            print(render_report(registry, rows))
        elif args.command == "atlas":
            print(render_atlas(registry, rows))
        elif args.command == "taxonomy":
            print(render_taxonomy(registry, rows))
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f"[development-coverage] FAILED\n{exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
