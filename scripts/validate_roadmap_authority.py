#!/usr/bin/env python3
"""Validate Atlas roadmap/authority documentation integrity.

Checks:
- relative Markdown links in current authority documents resolve;
- current authority documents do not directly link to roadmap files classified as historical;
- backticked commit hashes cited by authority documents resolve when the full history is available.

Commit checks are skipped rather than failed when the history cannot answer them -- git missing,
not a work tree, or a shallow clone. CI checks out with fetch-depth 0, but agents and contributors
routinely work in shallow checkouts, where every cited hash older than the truncation point would
otherwise be reported as dangling: a red gate that CI never reproduces and that says nothing about
the documents.

This is documentation validation only; it never proves runtime behavior.
"""

from __future__ import annotations

import functools
import re
import subprocess
import sys
import tempfile
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


def git(args: list[str], cwd: Path = ROOT) -> subprocess.CompletedProcess[bytes] | None:
    """Run a git command, or return None when git itself is unavailable."""
    try:
        return subprocess.run(["git", *args], cwd=cwd, capture_output=True, check=False)
    except OSError:
        return None


@functools.lru_cache(maxsize=None)
def repository_is_shallow(cwd: Path = ROOT) -> bool:
    probe = git(["rev-parse", "--is-shallow-repository"], cwd)
    if probe is not None and probe.returncode == 0:
        return probe.stdout.decode().strip() == "true"
    # git older than 2.15 has no --is-shallow-repository; the marker file is the
    # same signal that flag reports.
    git_dir = git(["rev-parse", "--git-dir"], cwd)
    if git_dir is None or git_dir.returncode != 0:
        return False
    return (cwd / git_dir.stdout.decode().strip() / "shallow").is_file()


def hash_check_skip_reason(cwd: Path = ROOT) -> str:
    if repository_is_shallow(cwd):
        return "shallow clone"
    return "git unavailable"


def commit_exists(commit_hash: str, cwd: Path = ROOT) -> bool | None:
    """True if the hash resolves, False if it is genuinely dangling, None if unanswerable."""
    result = git(["cat-file", "-e", f"{commit_hash}^{{commit}}"], cwd)
    if result is None:
        return None
    if result.returncode == 0:
        return True
    probe = git(["rev-parse", "--is-inside-work-tree"], cwd)
    if probe is None or probe.returncode != 0:
        return None
    # A shallow clone is missing history, not citing a bad hash. Reporting these
    # as dangling produces a failure CI cannot reproduce.
    if repository_is_shallow(cwd):
        return None
    return False


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

    note = f" (commit checks skipped: {hash_check_skip_reason()})" if hash_checks_skipped else ""
    print(
        f"[roadmap-authority] OK: {len(files)} documents, "
        f"{link_count} links, {hash_count} commit references{note}"
    )
    return 0


def shallow_clone_self_test() -> None:
    """A shallow clone must skip commit checks, not report truncated history as dangling."""
    probe = git(["--version"], ROOT)
    if probe is None or probe.returncode != 0:
        print("[roadmap-authority] self-test: git unavailable, shallow case not exercised")
        return

    with tempfile.TemporaryDirectory() as workspace:
        root = Path(workspace)
        origin = root / "origin"
        origin.mkdir()

        def run(args: list[str], cwd: Path) -> subprocess.CompletedProcess[bytes]:
            result = git(args, cwd)
            assert result is not None and result.returncode == 0, (args, result)
            return result

        run(["init", "--quiet", "--initial-branch=main"], origin)
        run(["config", "user.email", "self-test@example.invalid"], origin)
        run(["config", "user.name", "Atlas self-test"], origin)
        run(["commit", "--quiet", "--allow-empty", "-m", "first"], origin)
        first = run(["rev-parse", "HEAD"], origin).stdout.decode().strip()
        run(["commit", "--quiet", "--allow-empty", "-m", "second"], origin)
        run(["commit", "--quiet", "--allow-empty", "-m", "third"], origin)
        third = run(["rev-parse", "HEAD"], origin).stdout.decode().strip()

        full = root / "full"
        run(["clone", "--quiet", origin.as_uri(), str(full)], root)
        assert repository_is_shallow(full) is False
        assert commit_exists(first, full) is True, "a full clone must resolve its own history"
        assert commit_exists("0" * 40, full) is False, "a full clone must still catch a bad hash"

        shallow = root / "shallow"
        run(["clone", "--quiet", "--depth", "1", origin.as_uri(), str(shallow)], root)
        assert repository_is_shallow(shallow) is True, "depth-1 clone must be detected as shallow"
        assert commit_exists(third, shallow) is True, "a shallow clone still answers for kept history"
        assert commit_exists(first, shallow) is None, (
            "history truncated by depth must be skipped, not reported as a dangling reference"
        )
        assert hash_check_skip_reason(shallow) == "shallow clone"


def self_test() -> int:
    # Parser smoke test; real repository checks are exercised by normal invocation.
    assert resolve_link(ROOT / "docs" / "x.md", "https://example.com") is None
    assert resolve_link(ROOT / "docs" / "x.md", "#section") is None
    assert LINK_PATTERN.findall("[x](a.md)") == ["a.md"]
    assert COMMIT_HASH_PATTERN.findall("`abcdef1`") == ["abcdef1"]
    shallow_clone_self_test()
    print("[roadmap-authority] self-test OK")
    return 0


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        return self_test()
    return validate(AUTHORITY_FILES)


if __name__ == "__main__":
    raise SystemExit(main())
