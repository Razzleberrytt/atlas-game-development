#!/usr/bin/env python3
"""Restore and verify the direct 2026-08-07 RBXL re-extraction bundle.

This package is archival/build-ahead input only. It does not activate legacy
Studio services or modify the canonical Rojo runtime tree.
"""

from __future__ import annotations

import base64
import hashlib
import io
import json
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MANIFEST_PATH = ROOT / "REEXTRACTION-MANIFEST.json"
OUT = ROOT / "restored-reextraction"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    expected_parts = manifest["bundle"]["base64_parts"]
    parts = [ROOT / f"studio-reextraction-complete.tar.gz.b64.part{i:02d}" for i in range(1, expected_parts + 1)]
    missing = [str(path.name) for path in parts if not path.is_file()]
    if missing:
        raise SystemExit(f"missing bundle parts: {', '.join(missing)}")

    encoded = "".join(path.read_text(encoding="ascii").strip() for path in parts)
    bundle = base64.b64decode(encoded, validate=True)
    actual_bundle_sha = sha256(bundle)
    expected_bundle_sha = manifest["bundle"]["sha256"]
    if actual_bundle_sha != expected_bundle_sha:
        raise SystemExit(
            f"bundle SHA mismatch: expected {expected_bundle_sha}, got {actual_bundle_sha}"
        )

    if OUT.exists():
        import shutil

        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    with tarfile.open(fileobj=io.BytesIO(bundle), mode="r:gz") as archive:
        archive.extractall(OUT, filter="data")

    failures: list[str] = []
    for record in manifest["remaining_source_files"]:
        path = OUT / "legacy-src" / record["path"]
        if not path.is_file():
            failures.append(f"missing source: {record['path']}")
            continue
        data = path.read_bytes()
        if len(data) != record["bytes"]:
            failures.append(
                f"size mismatch {record['path']}: expected {record['bytes']}, got {len(data)}"
            )
        actual = sha256(data)
        if actual != record["sha256"]:
            failures.append(
                f"SHA mismatch {record['path']}: expected {record['sha256']}, got {actual}"
            )

    workspace = OUT / "workspace-index.json"
    workspace_record = manifest["workspace_index"]
    if not workspace.is_file():
        failures.append("missing workspace-index.json")
    else:
        data = workspace.read_bytes()
        if len(data) != workspace_record["bytes"]:
            failures.append(
                f"workspace size mismatch: expected {workspace_record['bytes']}, got {len(data)}"
            )
        actual = sha256(data)
        if actual != workspace_record["sha256"]:
            failures.append(
                f"workspace SHA mismatch: expected {workspace_record['sha256']}, got {actual}"
            )
        rows = json.loads(data)
        if len(rows) != workspace_record["rows"]:
            failures.append(
                f"workspace row mismatch: expected {workspace_record['rows']}, got {len(rows)}"
            )

    if failures:
        raise SystemExit("re-extraction verification failed:\n- " + "\n- ".join(failures))

    print(f"REEXTRACTION_OK bundle_sha={actual_bundle_sha}")
    print(f"verified_sources={len(manifest['remaining_source_files'])}")
    print(f"workspace_rows={workspace_record['rows']}")
    print(f"restored_to={OUT}")


if __name__ == "__main__":
    main()
