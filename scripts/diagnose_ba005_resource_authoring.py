#!/usr/bin/env python3
"""Temporary CI diagnostic for BA-005 recovered resource-authoring evidence."""

from __future__ import annotations

import io
import json
import tarfile
from pathlib import Path

from verify_studio_import_package import REEXTRACTION_MANIFEST_PATH, load_reextraction_bundle

TOKENS = ("IronOre", "OreDeposit", "createResource", "resourcePositions", "spawnResource")
CONTEXT = 8


def main() -> int:
    reextract = json.loads(Path(REEXTRACTION_MANIFEST_PATH).read_text(encoding="utf-8"))
    bundle, errors = load_reextraction_bundle(reextract)
    if bundle is None or errors:
        for error in errors:
            print(f"[ba005-diagnostic] ERROR: {error}")
        return 1

    print(
        "[ba005-diagnostic] bundle verified: "
        f"{len(bundle)} bytes / {reextract['bundle']['sha256']}"
    )

    match_count = 0
    with tarfile.open(fileobj=io.BytesIO(bundle), mode="r:gz") as archive:
        for member in archive.getmembers():
            if not member.isfile() or not member.name.endswith(".luau"):
                continue
            stream = archive.extractfile(member)
            data = stream.read() if stream is not None else b""
            try:
                text = data.decode("utf-8")
            except UnicodeDecodeError:
                continue
            lines = text.splitlines()
            matching = [
                index
                for index, line in enumerate(lines)
                if any(token in line for token in TOKENS)
            ]
            if not matching:
                continue

            match_count += len(matching)
            print(f"[ba005-diagnostic] source={member.name} matches={len(matching)}")
            emitted: set[tuple[int, int]] = set()
            for index in matching:
                start = max(0, index - CONTEXT)
                end = min(len(lines), index + CONTEXT + 1)
                window = (start, end)
                if window in emitted:
                    continue
                emitted.add(window)
                print(f"[ba005-diagnostic] --- lines {start + 1}-{end} ---")
                for line_index in range(start, end):
                    print(f"{line_index + 1:04d}: {lines[line_index]}")

    print(f"[ba005-diagnostic] total token matches: {match_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
