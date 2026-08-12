#!/usr/bin/env python3
"""Materialize losslessly packed Main World Studio model groups for Rojo."""

from __future__ import annotations

import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "games" / "living-kingdoms"
MANIFEST = GAME / "imports" / "studio-2026-08-11-main-world" / "revision-manifest.json"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    snapshot = manifest["mainWorldSnapshot"]
    model_root = GAME / snapshot["modelRoot"]
    component_meta = {name: (size, digest) for name, size, digest in snapshot["components"]}
    materialized = 0

    for name, packed_rel, packed_size, packed_digest in snapshot.get("packed", []):
        packed = (GAME / packed_rel).read_bytes()
        if len(packed) != packed_size or sha256(packed) != packed_digest:
            raise RuntimeError(f"packed Main World source failed integrity check: {name}")

        raw = gzip.decompress(packed)
        expected_size, expected_digest = component_meta[name]
        if len(raw) != expected_size or sha256(raw) != expected_digest:
            raise RuntimeError(f"materialized Main World source failed integrity check: {name}")

        output = model_root / f"MainWorld-{name}.model.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        if not output.exists() or output.read_bytes() != raw:
            output.write_bytes(raw)
        materialized += 1

    print(f"[main-world-materialize] verified/materialized {materialized} packed Studio groups")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
