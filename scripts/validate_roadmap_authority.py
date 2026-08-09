#!/usr/bin/env python3
"""Validate the v2.8 roadmap/authority documentation stack.

Build-ahead task BA-074. The roadmap stack (``AGENTS.md`` files, the current
product authority, ``MASTER-ROADMAP.md``, the v2.7 execution documents, and
the build-ahead queue) is only trustworthy if it is internally consistent.
This is a documentation-only check: it never inspects or changes runtime
behavior, and it does not replace Studio/runtime evidence.

It checks three things:

* every relative Markdown link inside the authority stack resolves to a real
  file, so agents are not sent to a document that no longer exists;
* no authority document links directly to a file the roadmap index itself
  classifies as historical, so an agent cannot be routed to a superseded
  checkpoint as if it were current execution authority;
* every commit hash cited in the authority stack (client-bootstrap fixes,
  roadmap checkpoint pins, rollback checkpoints, and similar) resolves to a
  real commit in this repository, so a stale/typo'd hash cannot silently
  become an unverifiable evidence claim.

Run with ``--self-test`` to exercise the parsing logic against a small
in-memory fixture instead of the real repository tree.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

AUTHORITY_FILES = (
    ROOT / "AGENTS.md",
    ROOT / "README.md",
    ROOT / "games" / "living-kingdoms" / "AGENTS.md",
    ROOT / "games" / "living-kingdoms" / "CANONICAL-RUNTIME.md",
    ROOT / "docs" / "bible" / "00-current-product-authority.md",
    ROOT / "docs" / "bible" / "00-project-charter.md",
    ROOT / "docs" / "roadmap" / "README.md",
    ROOT / "docs" / "roadmap" / "MASTER-ROADMAP.md",
    ROOT / "docs" / "roadmap" / "AGENT-BUILD-AHEAD-QUEUE.md",
    ROOT / "docs" / "roadmap" / "BLUEPRINT-V2.7-EXECUTION.md",
    ROOT / "docs" / "roadmap" / "PRODUCTION-CORE-V2.7.md",
    ROOT / "docs" / "roadmap" / "ACTIVE-PLACE-ROLLOUT-V2.7.md",
    ROOT / "docs" / "roadmap" / "CROSS-SYSTEM-TRACEABILITY-V2.7.md",
    ROOT / "docs" / "production" / "V2.7-CUTOVER-LEDGER.md",
    ROOT / "docs" / "specifications" / "main-world-environment-audit.md",
    ROOT / "docs" / "specifications" / "main-world-source-representation-strategy.md",
    ROOT / "docs" / "specifications" / "canonical-hub-interaction-registry.md",
    ROOT / "docs" / "specifications" / "main-world-environment-production-plan.md",
    ROOT / "docs" / "specifications" / "main-world-acceptance-matrix.md",
)

# The roadmap index is the single place allowed to point at historical
# checkpoints; every other authority document must reach them only through it.
ROADMAP_INDEX = ROOT / "docs" / "roadmap" / "README.md"

LINK_PATTERN = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
HISTORICAL_SECTION_PATTERN = re.compile(
    r"## Historical checkpoints\s*\n(.*?)(?:\n##|\Z)", re.DOTALL
)
BACKTICK_FILENAME_PATTERN = re.compile(r"`([A-Za-z0-9_.\-]+\.md)`")
COMMIT_HASH_PATTERN = re.compile(r"`([0-9a-f]{7,40})`")


def fail(message: str) -> None:
    print(f"[roadmap-authority] ERROR: {message}", file=sys.stderr)


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def extract_links(text: str) -> list[str]:
    return LINK_PATTERN.findall(text)


def resolve_relative_link(source_file: Path, target: str) -> Path | None:
    if target.startswith(("http://", "https://", "mailto:")):
        return None
    path_part = target.split("#", 1)[0].strip()
    if not path_part:
        return None
    return (source_file.parent / path_part).resolve()


def historical_filenames(roadmap_index_text: str) -> set[str]:
    match = HISTORICAL_SECTION_PATTERN.search(roadmap_index_text)
    if not match:
        return set()
    return set(BACKTICK_FILENAME_PATTERN.findall(match.group(1)))


def commit_hashes(text: str) -> set[str]:
    # Commit-ish hex tokens only; exclude short tokens that are almost
    # certainly not hashes (semantic keys, IDs) by requiring >= 7 hex chars,
    # which the pattern already enforces.
    return set(COMMIT_HASH_PATTERN.findall(text))


def commit_exists(commit_hash: str) -> bool | None:
    """Return True/False if git can answer, None if git is unavailable here."""
    try:
        result = subprocess.run(
            ["git", "cat-file", "-e", f"{commit_hash}^{{commit}}"],
            cwd=ROOT,
            capture_output=True,
            check=False,
        )
    except (OSError, FileNotFoundError):
        return None
    if result.returncode == 0:
        return True
    # Distinguish "git is fine but this isn't a commit" from "git is broken".
    probe = subprocess.run(
        ["git", "rev-parse", "--is-inside-work-tree"],
        cwd=ROOT,
        capture_output=True,
        check=False,
    )
    if probe.returncode != 0:
        return None
    return False


def run(files: tuple[Path, ...]) -> int:
    errors = 0
    checked_links = 0
    checked_hashes = 0
    git_unavailable = False

    roadmap_index_text = (
        ROADMAP_INDEX.read_text(encoding="utf-8") if ROADMAP_INDEX.is_file() else ""
    )
    historical = historical_filenames(roadmap_index_text)

    for path in files:
        if not path.is_file():
            fail(f"missing authority document: {display_path(path)}")
            errors += 1
            continue

        text = path.read_text(encoding="utf-8")

        for target in extract_links(text):
            resolved = resolve_relative_link(path, target)
            if resolved is None:
                continue
            checked_links += 1
            if not resolved.exists():
                fail(
                    f"broken link in {display_path(path)}: "
                    f"target {target!r} does not resolve to a file"
                )
                errors += 1
                continue

            if path != ROADMAP_INDEX and resolved.name in historical:
                fail(
                    f"authority leak in {display_path(path)}: links directly to "
                    f"historical checkpoint {resolved.name!r}; route through "
                    f"docs/roadmap/README.md instead"
                )
                errors += 1

        for candidate_hash in commit_hashes(text):
            checked_hashes += 1
            exists = commit_exists(candidate_hash)
            if exists is None:
                git_unavailable = True
                continue
            if not exists:
                fail(
                    f"dangling commit reference in {display_path(path)}: "
                    f"`{candidate_hash}` does not resolve to a commit in this repository"
                )
                errors += 1

    if errors:
        print(f"[roadmap-authority] FAILED with {errors} error(s)", file=sys.stderr)
        return 1

    note = " (commit-hash checks skipped: git unavailable)" if git_unavailable else ""
    print(
        "[roadmap-authority] OK: "
        f"{len(files)} authority documents, "
        f"{checked_links} relative links, "
        f"{checked_hashes} commit-hash references checked{note}"
    )
    return 0


def self_test() -> int:
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        tmp_root = Path(tmp)
        roadmap_dir = tmp_root / "docs" / "roadmap"
        roadmap_dir.mkdir(parents=True)

        index = roadmap_dir / "README.md"
        index.write_text(
            "# Index\n\n"
            "## Historical checkpoints\n\n"
            "- `OLD-BLUEPRINT.md`\n",
            encoding="utf-8",
        )
        (roadmap_dir / "OLD-BLUEPRINT.md").write_text("# Old\n", encoding="utf-8")

        good = roadmap_dir / "GOOD.md"
        good.write_text(
            "[index](README.md)\n[old, via index only](README.md#historical-checkpoints)\n",
            encoding="utf-8",
        )

        broken_link = roadmap_dir / "BROKEN.md"
        broken_link.write_text("[missing](DOES-NOT-EXIST.md)\n", encoding="utf-8")

        leak = roadmap_dir / "LEAK.md"
        leak.write_text("[old direct](OLD-BLUEPRINT.md)\n", encoding="utf-8")

        global ROADMAP_INDEX  # noqa: PLW0603 - intentional for the isolated fixture
        original_index = ROADMAP_INDEX
        ROADMAP_INDEX = index
        try:
            ok_result = run((index, good))
            bad_result = run((index, broken_link, leak))
        finally:
            ROADMAP_INDEX = original_index

        if ok_result != 0:
            fail("self-test: expected the clean fixture to pass")
            return 1
        if bad_result == 0:
            fail("self-test: expected the broken-link/authority-leak fixture to fail")
            return 1

    print("[roadmap-authority] self-test OK")
    return 0


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        return self_test()
    return run(AUTHORITY_FILES)


if __name__ == "__main__":
    raise SystemExit(main())
