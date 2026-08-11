#!/usr/bin/env python3
"""Living Kingdoms engineering-efficiency toolkit.

Commands:
  audit      Scan the repo for leverage opportunities and emit a ranked report.
  score      Score a roadmap/task candidate using the development-flywheel rubric.
  bootstrap  Print the smallest useful context bundle for the next coding agent.
  registry   Validate and summarize the capability registry.

The audit is advisory by design: heuristics identify candidates for human/agent
inspection; they do not prove a refactor is desirable. Registry validation is
strict and is used by repository validation/CI.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

from _console import use_utf8_output

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games" / "living-kingdoms"
SRC = GAME / "src"
TESTS = GAME / "tests"
REGISTRY = ROOT / "config" / "efficiency" / "capabilities.json"
DASHBOARD = ROOT / "docs" / "roadmap" / "EXECUTION-DASHBOARD.md"
FLYWHEEL = ROOT / "docs" / "roadmap" / "DEVELOPMENT-FLYWHEEL.md"

ALLOWED_STATUS = {"prepared", "active", "mature", "deprecated"}
ALLOWED_OWNER = {"client", "server", "shared", "server/shared-contract", "tooling"}
LUau_SUFFIXES = {".luau", ".lua"}


@dataclass(frozen=True)
class Finding:
    priority: int
    kind: str
    location: str
    message: str
    recommendation: str


def load_registry() -> dict:
    if not REGISTRY.exists():
        raise RuntimeError(f"missing capability registry: {REGISTRY.relative_to(ROOT)}")
    try:
        return json.loads(REGISTRY.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"invalid capability registry JSON: {exc}") from exc


def validate_registry(data: dict) -> list[str]:
    errors: list[str] = []
    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    if data.get("project") != "living-kingdoms":
        errors.append("project must be 'living-kingdoms'")
    capabilities = data.get("capabilities")
    if not isinstance(capabilities, list) or not capabilities:
        return errors + ["capabilities must be a non-empty list"]

    seen: set[str] = set()
    required = {"id", "name", "owner", "status", "extension_points", "consumers", "tests_glob", "data_driven", "notes"}
    for index, capability in enumerate(capabilities):
        label = f"capabilities[{index}]"
        if not isinstance(capability, dict):
            errors.append(f"{label} must be an object")
            continue
        missing = required - capability.keys()
        if missing:
            errors.append(f"{label} missing keys: {', '.join(sorted(missing))}")
            continue
        cid = capability["id"]
        if not isinstance(cid, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", cid):
            errors.append(f"{label}.id must be kebab-case")
        elif cid in seen:
            errors.append(f"duplicate capability id: {cid}")
        else:
            seen.add(cid)
        if capability["owner"] not in ALLOWED_OWNER:
            errors.append(f"{cid}: unsupported owner {capability['owner']!r}")
        if capability["status"] not in ALLOWED_STATUS:
            errors.append(f"{cid}: unsupported status {capability['status']!r}")
        if not isinstance(capability["data_driven"], bool):
            errors.append(f"{cid}: data_driven must be boolean")
        for key in ("extension_points", "consumers"):
            value = capability[key]
            if not isinstance(value, list) or not value or not all(isinstance(item, str) and item for item in value):
                errors.append(f"{cid}: {key} must be a non-empty string list")
        for point in capability["extension_points"]:
            if any(ch in point for ch in "*?[]"):
                continue
            candidate = ROOT / point
            if not candidate.exists():
                errors.append(f"{cid}: extension point does not exist: {point}")
    return errors


def luau_files() -> list[Path]:
    return sorted(path for path in SRC.rglob("*") if path.is_file() and path.suffix in LUau_SUFFIXES)


def normalized_lines(path: Path) -> list[str]:
    output = []
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = re.sub(r"--.*$", "", raw).strip()
        if len(line) < 28:
            continue
        if line in {"end", "else", "then"}:
            continue
        output.append(re.sub(r"\s+", " ", line))
    return output


def audit_findings() -> list[Finding]:
    files = luau_files()
    findings: list[Finding] = []

    # Large source files are not automatically bad; they are useful hotspots for ownership/reuse review.
    for path in files:
        lines = path.read_text(encoding="utf-8", errors="replace").count("\n") + 1
        if lines >= 700:
            findings.append(Finding(2, "hotspot", str(path.relative_to(ROOT)), f"large source owner ({lines} lines)", "Review whether stable sub-capabilities can be extracted without splitting authority."))
        elif lines >= 450:
            findings.append(Finding(1, "hotspot", str(path.relative_to(ROOT)), f"growing source owner ({lines} lines)", "Watch for a proven repeated shape before the next content expansion."))

    # Cross-file repeated substantial lines. This intentionally ignores short/common syntax.
    occurrences: dict[str, set[str]] = defaultdict(set)
    for path in files:
        rel = str(path.relative_to(ROOT))
        for line in set(normalized_lines(path)):
            occurrences[line].add(rel)
    duplicate_groups = [(line, paths) for line, paths in occurrences.items() if len(paths) >= 3]
    duplicate_groups.sort(key=lambda item: (-len(item[1]), item[0]))
    for line, paths in duplicate_groups[:20]:
        sample = line[:110] + ("…" if len(line) > 110 else "")
        findings.append(Finding(2 if len(paths) >= 5 else 1, "repeat", ", ".join(sorted(paths)[:4]), f"substantial line repeated across {len(paths)} files: {sample}", "Check for a shared resolver/config/helper only if semantics truly match."))

    # Network/remote construction outside the canonical networking area is a high-value audit target.
    remote_pattern = re.compile(r"Instance\.new\([\"']Remote(?:Event|Function)[\"']\)")
    for path in files:
        rel = str(path.relative_to(ROOT))
        if "/Networking/" in f"/{rel}/":
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if remote_pattern.search(text):
            findings.append(Finding(3, "authority", rel, "creates a RemoteEvent/RemoteFunction outside canonical Networking", "Verify this is an intentional owner; otherwise consolidate transport creation/registration."))

    # Tests-to-source ratio is a directional signal for regression-defense opportunity.
    source_count = len(files)
    test_count = len(list(TESTS.rglob("*.test.luau"))) if TESTS.exists() else 0
    if source_count and test_count < max(8, source_count // 5):
        findings.append(Finding(2, "coverage", "games/living-kingdoms/tests", f"{test_count} fixtures for {source_count} Luau source files", "Prioritize focused regression fixtures for recurring gameplay/lifecycle failure classes."))

    # Capability registry gaps: top-level architecture directories without any extension point coverage.
    registry = load_registry()
    covered = "\n".join(point for cap in registry.get("capabilities", []) for point in cap.get("extension_points", []))
    for directory in sorted(path for path in SRC.rglob("*") if path.is_dir()):
        rel = str(directory.relative_to(ROOT))
        depth = len(directory.relative_to(SRC).parts)
        if depth <= 2 and rel not in covered and any(directory.iterdir()):
            findings.append(Finding(1, "registry-gap", rel, "architecture area is not represented by a capability extension point", "Add it to an existing capability or register a new stable capability when ownership is understood."))

    findings.sort(key=lambda f: (-f.priority, f.kind, f.location, f.message))
    return findings


def print_audit(as_json: bool) -> int:
    registry = load_registry()
    errors = validate_registry(registry)
    findings = audit_findings() if not errors else []
    if as_json:
        print(json.dumps({"registry_errors": errors, "findings": [f.__dict__ for f in findings]}, indent=2))
    else:
        if errors:
            print("Capability registry errors:")
            for error in errors:
                print(f"  - {error}")
            return 1
        print(f"Capability registry: {len(registry['capabilities'])} capabilities — valid")
        print(f"Leverage audit: {len(findings)} advisory findings")
        for finding in findings[:40]:
            print(f"\n[P{finding.priority}] {finding.kind} — {finding.location}")
            print(f"  {finding.message}")
            print(f"  → {finding.recommendation}")
        if len(findings) > 40:
            print(f"\n… {len(findings) - 40} additional findings omitted")
    return 1 if errors else 0


def score_task(args: argparse.Namespace) -> int:
    values = {
        "player_value": args.player_value,
        "dependency_removal": args.dependency_removal,
        "near_term_reuse": args.near_term_reuse,
        "future_effort_reduction": args.future_effort_reduction,
        "risk_reduction": args.risk_reduction,
        "data_scalability": args.data_scalability,
        "agent_autonomy": args.agent_autonomy,
    }
    if any(value not in {0, 1, 2} for value in values.values()):
        print("all score dimensions must be 0, 1, or 2", file=sys.stderr)
        return 2
    # Player/dependency value dominates; leverage breaks ties rather than hijacking priority.
    primary = 3 * values["player_value"] + 3 * values["dependency_removal"]
    leverage = sum(values[key] for key in ("near_term_reuse", "future_effort_reduction", "risk_reduction", "data_scalability", "agent_autonomy"))
    total = primary * 10 + leverage
    payload = {"name": args.name, "primary": primary, "leverage": leverage, "priority_score": total, "dimensions": values}
    print(json.dumps(payload, indent=2) if args.json else f"{args.name}: priority={total} (primary={primary}, leverage={leverage}/10)")
    return 0


def print_registry(as_json: bool) -> int:
    data = load_registry()
    errors = validate_registry(data)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    if as_json:
        print(json.dumps(data, indent=2))
    else:
        print(f"{len(data['capabilities'])} registered capabilities")
        for cap in data["capabilities"]:
            print(f"- {cap['id']}: {cap['status']} / owner={cap['owner']} / consumers={len(cap['consumers'])} / data_driven={cap['data_driven']}")
    return 0


def bootstrap() -> int:
    print("Living Kingdoms agent bootstrap")
    print("1. Read docs/roadmap/EXECUTION-DASHBOARD.md")
    print("2. Read games/living-kingdoms/AGENTS.md")
    print("3. Inspect open PRs before implementing overlapping work")
    print("4. For reuse/friction decisions: python scripts/efficiency.py audit")
    print("5. For known extension points: python scripts/efficiency.py registry")
    print("6. Load docs/roadmap/DEVELOPMENT-FLYWHEEL.md only when a leverage decision is non-obvious")
    if DASHBOARD.exists():
        text = DASHBOARD.read_text(encoding="utf-8", errors="replace")
        now = re.search(r"### NOW\s+(.*?)(?=\n### |\Z)", text, flags=re.S)
        if now:
            compact = " ".join(now.group(1).strip().split())
            print(f"\nCurrent NOW: {compact[:500]}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    audit = sub.add_parser("audit")
    audit.add_argument("--json", action="store_true")
    registry = sub.add_parser("registry")
    registry.add_argument("--json", action="store_true")
    sub.add_parser("bootstrap")
    score = sub.add_parser("score")
    score.add_argument("name")
    score.add_argument("--player-value", type=int, required=True)
    score.add_argument("--dependency-removal", type=int, required=True)
    score.add_argument("--near-term-reuse", type=int, required=True)
    score.add_argument("--future-effort-reduction", type=int, required=True)
    score.add_argument("--risk-reduction", type=int, required=True)
    score.add_argument("--data-scalability", type=int, required=True)
    score.add_argument("--agent-autonomy", type=int, required=True)
    score.add_argument("--json", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.command == "audit":
        return print_audit(args.json)
    if args.command == "registry":
        return print_registry(args.json)
    if args.command == "bootstrap":
        return bootstrap()
    if args.command == "score":
        return score_task(args)
    return 2


if __name__ == "__main__":
    use_utf8_output()
    raise SystemExit(main())
