#!/usr/bin/env python3
"""Validate Atlas roadmap/authority documentation integrity.

Checks:
- relative Markdown links in current authority documents resolve;
- current authority documents do not directly link to roadmap files classified as historical;
- backticked commit hashes cited by authority documents resolve when git is available.

This is documentation validation only; it never proves runtime behavior.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROADMAP_INDEX = ROOT / "docs" / "roadmap" / "README.md"

AUTHORITY_FILES = (
    ROOT / "AGENTS.md",
    ROOT / "README.md",
    ROOT / "docs" / "README.md",
    ROOT / "games" / "living-kingdoms" / "AGENTS.md",
    ROOT / "games" / "living-kingdoms" / "CANONICAL-RUNTIME.md",
    ROOT / "docs" / "bible" / "00-current-product-authority.md",
    ROOT / "docs" / "bible" / "00-project-charter.md",
    ROADMAP_INDEX,
    ROOT / "docs" / "roadmap" / "PARALLEL-DEVELOPMENT-POLICY.md",
    ROOT / "docs" / "roadmap" / "AUTOMATED-FIRST-EXECUTION-POLICY.md",
    ROOT / "docs" / "roadmap" / "EXECUTION-DASHBOARD.md",
    ROOT / "docs" / "roadmap" / "MVP-BUILD-THROUGH-TESTING-POLICY.md",
    ROOT / "docs" / "roadmap" / "PLAYABLE-MVP-PATCH-EXECUTION.md",
    ROOT / "docs" / "roadmap" / "MASTER-ROADMAP.md",
    ROOT / "docs" / "roadmap" / "AGENT-BUILD-AHEAD-QUEUE.md",
    ROOT / "docs" / "roadmap" / "BLUEPRINT-V2.7-EXECUTION.md",
    ROOT / "docs" / "roadmap" / "PRODUCTION-CORE-V2.7.md",
    ROOT / "docs" / "roadmap" / "ACTIVE-PLACE-ROLLOUT-V2.7.md",
    ROOT / "docs" / "roadmap" / "CROSS-SYSTEM-TRACEABILITY-V2.7.md",
    ROOT / "docs" / "architecture" / "DEVELOPMENT_TAXONOMY.md",
    ROOT / "docs" / "architecture" / "DEVELOPMENT-ATLAS.md",
    ROOT / "docs" / "production" / "DEVELOPMENT-COVERAGE-REPORT.md",
    ROOT / "docs" / "production" / "V2.7-CUTOVER-LEDGER.md",
    ROOT / "docs" / "specifications" / "main-world-environment-audit.md",
    ROOT / "docs" / "specifications" / "main-world-source-representation-strategy.md",
    ROOT / "docs" / "specifications" / "canonical-hub-interaction-registry.md",
    ROOT / "docs" / "specifications" / "main-world-environment-production-plan.md",
    ROOT / "docs" / "specifications" / "main-world-acceptance-matrix.md",
)

LINK_PATTERN = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
HISTORICAL_SECTION_PATTERN = re.compile(
    r"## Historical documents\s*\n(.*?)(?:\n##|\Z)", re.DOTALL
)
BACKTICK_FILENAME_PATTERN = re.compile(r"`([A-Za-z0-9_.\-]+\.md)`")
COMMIT_HASH_PATTERN = re.compile(r"`([0-9a-f]{7,40})`")


def display(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def historical_files() -> set[str]:
    if not ROADMAP_INDEX.is_file():
        return set()
    text = ROADMAP_INDEX.read_text(encoding="utf-8")
    match = HISTORICAL_SECTION_PATTERN.search(text)
    return set(BACKTICK_FILENAME_PATTERN.findall(match.group(1))) if match else set()


def resolve_link(source: Path, target: str) -> Path | None:
    if target.startswith(("http://", "https://", "mailto:")):
        return None
    path_part = target.split("#", 1)[0].strip()
    if not path_part:
        return None
    return (source.parent / path_part).resolve()


def commit_exists(commit_hash: str) -> bool | None:
    try:
        result = subprocess.run(
            ["git", "cat-file", "-e", f"{commit_hash}^{{commit}}"],
            cwd=ROOT,
            capture_output=True,
            check=False,
        )
    except OSError:
        return None
    if result.returncode == 0:
        return True
    probe = subprocess.run(
        ["git", "rev-parse", "--is-inside-work-tree"],
        cwd=ROOT,
        capture_output=True,
        check=False,
    )
    return False if probe.returncode == 0 else None


def validate(files: tuple[Path, ...]) -> int:
    errors: list[str] = []
    historical = historical_files()
    link_count = 0
    hash_count = 0
    hash_checks_skipped = False

    for path in files:
        if not path.is_file():
            errors.append(f"missing authority document: {display(path)}")
            continue
        text = path.read_text(encoding="utf-8")

        for target in LINK_PATTERN.findall(text):
            resolved = resolve_link(path, target)
            if resolved is None:
                continue
            link_count += 1
            if not resolved.exists():
                errors.append(f"broken link in {display(path)}: {target!r}")
                continue
            if path != ROADMAP_INDEX and resolved.name in historical:
                errors.append(
                    f"authority leak in {display(path)}: direct link to historical {resolved.name!r}"
                )

        for commit_hash in set(COMMIT_HASH_PATTERN.findall(text)):
            hash_count += 1
            exists = commit_exists(commit_hash)
            if exists is None:
                hash_checks_skipped = True
            elif not exists:
                errors.append(
                    f"dangling commit reference in {display(path)}: `{commit_hash}`"
                )

    if errors:
        for error in errors:
            print(f"[roadmap-authority] ERROR: {error}", file=sys.stderr)
        print(
            f"[roadmap-authority] FAILED with {len(errors)} error(s)",
            file=sys.stderr,
        )
        return 1

    note = " (commit checks skipped: git unavailable)" if hash_checks_skipped else ""
    print(
        f"[roadmap-authority] OK: {len(files)} documents, "
        f"{link_count} links, {hash_count} commit references{note}"
    )
    return 0


def self_test() -> int:
    # Parser smoke test; real repository checks are exercised by normal invocation.
    assert resolve_link(ROOT / "docs" / "x.md", "https://example.com") is None
    assert resolve_link(ROOT / "docs" / "x.md", "#section") is None
    assert LINK_PATTERN.findall("[x](a.md)") == ["a.md"]
    assert COMMIT_HASH_PATTERN.findall("`abcdef1`") == ["abcdef1"]
    print("[roadmap-authority] self-test OK")
    return 0


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        return self_test()
    return validate(AUTHORITY_FILES)


if __name__ == "__main__":
    raise SystemExit(main())
