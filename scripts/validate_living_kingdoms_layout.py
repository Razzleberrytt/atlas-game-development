#!/usr/bin/env python3
"""Validate the GitHub-first Living Kingdoms repository contract."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games" / "living-kingdoms"

REQUIRED_FILES = (
    ROOT / "AGENTS.md",
    ROOT / "rokit.toml",
    ROOT / "stylua.toml",
    ROOT / "selene.toml",
    GAME / "AGENTS.md",
    GAME / "README.md",
    GAME / "default.project.json",
    GAME / "src" / "client" / "init.client.luau",
    GAME / "src" / "server" / "init.server.luau",
    ROOT / "docs" / "production" / "RBXL-IMPORT-MIGRATION.md",
)

FORBIDDEN_SOURCE_SUFFIXES = {
    ".rbxl",
    ".rbxlx",
    ".rbxm",
    ".rbxmx",
}

EXPECTED_PATHS = {
    ("ReplicatedStorage", "Shared"): "src/shared",
    ("ServerScriptService", "Server"): "src/server",
    ("StarterPlayer", "StarterPlayerScripts", "Client"): "src/client",
}


def fail(message: str) -> None:
    print(f"[layout] ERROR: {message}", file=sys.stderr)


def nested(tree: dict[str, object], keys: tuple[str, ...]) -> object | None:
    current: object = tree
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def main() -> int:
    errors = 0

    for path in REQUIRED_FILES:
        if not path.is_file():
            fail(f"missing required file: {path.relative_to(ROOT)}")
            errors += 1

    project_path = GAME / "default.project.json"
    if project_path.is_file():
        try:
            project = json.loads(project_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            fail(f"cannot parse {project_path.relative_to(ROOT)}: {exc}")
            errors += 1
        else:
            tree = project.get("tree")
            if not isinstance(tree, dict):
                fail("default.project.json must contain an object-valued 'tree'")
                errors += 1
            else:
                for keys, expected_path in EXPECTED_PATHS.items():
                    node = nested(tree, keys)
                    actual_path = node.get("$path") if isinstance(node, dict) else None
                    if actual_path != expected_path:
                        fail(
                            f"Rojo mapping {'/'.join(keys)} expected "
                            f"{expected_path!r}, found {actual_path!r}"
                        )
                        errors += 1

    src_root = GAME / "src"
    source_files = sorted(src_root.rglob("*.luau")) if src_root.is_dir() else []
    test_root = GAME / "tests"
    test_files = sorted(test_root.rglob("*.test.luau")) if test_root.is_dir() else []

    if not source_files:
        fail("no Luau source files found under games/living-kingdoms/src")
        errors += 1

    if not test_files:
        fail("no Lune fixtures found under games/living-kingdoms/tests")
        errors += 1

    if src_root.is_dir():
        for path in src_root.rglob("*"):
            if path.is_file() and path.suffix.lower() in FORBIDDEN_SOURCE_SUFFIXES:
                fail(
                    "generated Roblox place/model file committed inside source tree: "
                    f"{path.relative_to(ROOT)}"
                )
                errors += 1

    if errors:
        print(f"[layout] FAILED with {errors} error(s)", file=sys.stderr)
        return 1

    print(
        "[layout] OK: "
        f"{len(source_files)} Luau source files, "
        f"{len(test_files)} Lune fixtures, "
        "canonical Rojo mappings present"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
