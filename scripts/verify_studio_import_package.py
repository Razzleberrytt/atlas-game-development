#!/usr/bin/env python3
"""Verify the complete preserved 2026-08-07 Studio import.

The first archive upload was partially damaged in transit. PR #228 repaired the
preservation set by keeping every exact plain-text source that had already been
recovered and adding a checksum-pinned direct re-extraction bundle for the
remaining sources plus the complete 1,775-row Workspace identity/hierarchy
index.

This verifier treats that repaired preservation set as authoritative evidence.
The older damaged chunks remain historical artifacts, but are no longer the
ceiling for what CI considers valid recovery.
"""

from __future__ import annotations

import base64
import hashlib
import io
import json
import sys
import tarfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
IMPORT_DIR = ROOT / "games" / "living-kingdoms" / "imports" / "studio-2026-08-07"
MANIFEST_PATH = IMPORT_DIR / "manifest.json"
RECOVERED_SRC_DIR = IMPORT_DIR / "recovered" / "legacy-src"
REEXTRACTED_DIR = IMPORT_DIR / "reextracted"
REEXTRACTION_MANIFEST_PATH = REEXTRACTED_DIR / "REEXTRACTION-MANIFEST.json"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(message: str) -> None:
    print(f"[import] ERROR: {message}", file=sys.stderr)


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(path)
    return json.loads(path.read_text(encoding="utf-8"))


def expected_sources(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {entry["path"]: entry for entry in manifest["unique_files"]}


def verify_plain_sources(expected: dict[str, dict[str, Any]]) -> tuple[set[str], list[str]]:
    verified: set[str] = set()
    errors: list[str] = []
    if not RECOVERED_SRC_DIR.is_dir():
        return verified, [f"missing recovered source tree: {RECOVERED_SRC_DIR.relative_to(ROOT)}"]

    for path in RECOVERED_SRC_DIR.rglob("*"):
        if not path.is_file():
            continue
        relative = str(path.relative_to(RECOVERED_SRC_DIR)).replace("\\", "/")
        record = expected.get(relative)
        if record is None:
            errors.append(f"unexpected recovered source: {relative}")
            continue
        data = path.read_bytes()
        if len(data) != record["bytes"]:
            errors.append(
                f"recovered/{relative} size mismatch: expected {record['bytes']}, got {len(data)}"
            )
            continue
        actual = sha256(data)
        if actual != record["sha256"]:
            errors.append(
                f"recovered/{relative} SHA mismatch: expected {record['sha256']}, got {actual}"
            )
            continue
        verified.add(relative)

    return verified, errors


def load_reextraction_bundle(reextract: dict[str, Any]) -> tuple[bytes | None, list[str]]:
    errors: list[str] = []
    part_names = reextract["bundle"]["base64_files"]
    parts = [REEXTRACTED_DIR / name for name in part_names]
    missing = [path.name for path in parts if not path.is_file()]
    if missing:
        return None, [f"missing re-extraction bundle parts: {', '.join(missing)}"]

    try:
        encoded = "".join(path.read_text(encoding="ascii").strip() for path in parts)
        bundle = base64.b64decode(encoded, validate=True)
    except Exception as exc:
        return None, [f"re-extraction base64 decode failed: {exc}"]

    expected_bytes = reextract["bundle"]["bytes"]
    if len(bundle) != expected_bytes:
        errors.append(
            f"re-extraction bundle size mismatch: expected {expected_bytes}, got {len(bundle)}"
        )
    actual_sha = sha256(bundle)
    expected_sha = reextract["bundle"]["sha256"]
    if actual_sha != expected_sha:
        errors.append(
            f"re-extraction bundle SHA mismatch: expected {expected_sha}, got {actual_sha}"
        )
    return bundle, errors


def verify_reextraction(
    expected: dict[str, dict[str, Any]], manifest: dict[str, Any], reextract: dict[str, Any]
) -> tuple[set[str], list[str], int]:
    verified: set[str] = set()
    errors: list[str] = []
    workspace_rows = 0

    source = reextract["source_rbxl"]
    if source["sha256"] != manifest["source"]["sha256"]:
        errors.append("re-extraction source RBXL SHA does not match import manifest")
    if source["bytes"] != manifest["source"]["size"]:
        errors.append("re-extraction source RBXL byte count does not match import manifest")

    bundle, bundle_errors = load_reextraction_bundle(reextract)
    errors.extend(bundle_errors)
    if bundle is None or bundle_errors:
        return verified, errors, workspace_rows

    try:
        with tarfile.open(fileobj=io.BytesIO(bundle), mode="r:gz") as archive:
            members = {member.name: member for member in archive.getmembers() if member.isfile()}
            for record in reextract["remaining_source_files"]:
                relative = record["path"]
                original = expected.get(relative)
                if original is None:
                    errors.append(f"re-extraction contains source not declared by import manifest: {relative}")
                    continue
                if record["bytes"] != original["bytes"] or record["sha256"] != original["sha256"]:
                    errors.append(f"re-extraction manifest disagrees with original manifest: {relative}")
                    continue
                member = members.get(f"legacy-src/{relative}")
                if member is None:
                    errors.append(f"re-extraction bundle missing source: {relative}")
                    continue
                stream = archive.extractfile(member)
                data = stream.read() if stream is not None else b""
                if len(data) != record["bytes"] or sha256(data) != record["sha256"]:
                    errors.append(f"re-extraction bundle source failed hash/size verification: {relative}")
                    continue
                verified.add(relative)

            workspace_record = reextract["workspace_index"]
            member = members.get("workspace-index.json")
            if member is None:
                errors.append("re-extraction bundle missing workspace-index.json")
            else:
                stream = archive.extractfile(member)
                data = stream.read() if stream is not None else b""
                if len(data) != workspace_record["bytes"]:
                    errors.append(
                        "workspace index size mismatch: "
                        f"expected {workspace_record['bytes']}, got {len(data)}"
                    )
                if sha256(data) != workspace_record["sha256"]:
                    errors.append("workspace index SHA mismatch")
                try:
                    rows = json.loads(data)
                    workspace_rows = len(rows)
                except Exception as exc:
                    errors.append(f"workspace index JSON decode failed: {exc}")
                if workspace_rows != workspace_record["rows"]:
                    errors.append(
                        f"workspace row mismatch: expected {workspace_record['rows']}, got {workspace_rows}"
                    )
    except (tarfile.TarError, OSError) as exc:
        errors.append(f"re-extraction tar verification failed: {exc}")

    return verified, errors, workspace_rows


def main() -> int:
    try:
        manifest = load_json(MANIFEST_PATH)
        reextract = load_json(REEXTRACTION_MANIFEST_PATH)
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        fail(f"cannot load preservation manifests: {exc}")
        return 1

    expected = expected_sources(manifest)
    plain_verified, plain_errors = verify_plain_sources(expected)
    bundle_verified, bundle_errors, workspace_rows = verify_reextraction(expected, manifest, reextract)

    errors = [*plain_errors, *bundle_errors]
    covered = plain_verified | bundle_verified
    missing = sorted(set(expected) - covered)
    if missing:
        errors.append("preservation set does not cover source files: " + ", ".join(missing))

    declared_workspace = manifest["counts"]["workspace_instances"]
    if workspace_rows != declared_workspace:
        errors.append(
            f"complete workspace coverage mismatch: manifest declares {declared_workspace}, verified {workspace_rows}"
        )

    if len(expected) != 28:
        errors.append(f"unexpected Studio-only source count: expected 28, manifest declares {len(expected)}")

    for message in errors:
        fail(message)
    if errors:
        print(f"[import] FAILED with {len(errors)} error(s)", file=sys.stderr)
        return 1

    print(
        "[import] OK: complete preservation verified "
        f"({len(covered)}/{len(expected)} Studio-only sources, {workspace_rows} Workspace rows)"
    )
    print(f"[import] exact plain-text sources: {len(plain_verified)}")
    print(f"[import] exact re-extraction bundle sources: {len(bundle_verified)}")
    print(f"[import] source RBXL SHA-256: {manifest['source']['sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
