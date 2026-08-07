#!/usr/bin/env python3
"""Verify the preserved Studio RBXL import package.

The 2026-08-07 import package stores two archives as chunked base64 text:

* ``legacy-src.tar.gz.b64.part*``      -- the 28 Studio-only Luau sources
* ``workspace-index.json.gz.b64.part*`` -- the 1,775-instance Workspace hierarchy

Both archives are damaged as committed (see
``docs/production/RBXL-IMPORT-INTEGRITY-2026-08-07.md``). This script measures
exactly how much of each archive still decodes, checks the recovered material
that has been re-preserved as plain text, and fails when either number gets
worse than the recorded baseline.

It never rewrites the baseline on its own; ``--update-baseline`` is explicit so
a shrinking recovery set cannot be laundered into a green run.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import sys
import zlib
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
IMPORT_DIR = ROOT / "games" / "living-kingdoms" / "imports" / "studio-2026-08-07"
MANIFEST_PATH = IMPORT_DIR / "manifest.json"
BASELINE_PATH = IMPORT_DIR / "INTEGRITY-BASELINE.json"
RECOVERED_DIR = IMPORT_DIR / "recovered"
RECOVERED_SRC_DIR = RECOVERED_DIR / "legacy-src"
RECOVERED_WORKSPACE = RECOVERED_DIR / "workspace-index-recovered.json"

GZIP_WBITS = 16 + zlib.MAX_WBITS
TAR_BLOCK = 512

INSTANCE_PATTERN = re.compile(
    r'\{"id":\d+,"class":"[^"]*","name":"[^"]*","parent_id":-?\d+,"path":"[^"]*"\}'
)


def problem(message: str) -> None:
    print(f"[import] ERROR: {message}", file=sys.stderr)


def note(message: str) -> None:
    print(f"[import] {message}")


def join_chunks(pattern: str) -> str:
    """Concatenate the chunk files exactly the way ``restore-import.py`` does."""
    chunks = sorted(IMPORT_DIR.glob(pattern))
    return "".join(chunk.read_text(encoding="utf-8").strip() for chunk in chunks)


def decode_base64_prefix(text: str) -> bytes:
    """Decode as much of ``text`` as forms whole base64 quadruplets."""
    usable = len(text) - (len(text) % 4)
    return base64.b64decode(text[:usable])


def inflate_prefix(compressed: bytes) -> tuple[bytes, bool]:
    """Inflate a gzip member, returning whatever was produced before failure."""
    engine = zlib.decompressobj(GZIP_WBITS)
    recovered = bytearray()
    try:
        for offset in range(0, len(compressed), 4096):
            recovered += engine.decompress(compressed[offset : offset + 4096])
        recovered += engine.flush()
    except zlib.error:
        return bytes(recovered), False
    return bytes(recovered), True


def walk_tar(blob: bytes) -> dict[str, bytes]:
    """Read every complete member from a possibly truncated ustar stream."""
    members: dict[str, bytes] = {}
    offset = 0
    while offset + TAR_BLOCK <= len(blob):
        header = blob[offset : offset + TAR_BLOCK]
        raw_name = header[:100].rstrip(b"\0")
        if not raw_name.strip(b"\0"):
            break
        try:
            name = raw_name.decode("utf-8")
            size = int(header[124:136].rstrip(b"\0 ").decode("ascii") or "0", 8)
        except (UnicodeDecodeError, ValueError):
            break
        body = blob[offset + TAR_BLOCK : offset + TAR_BLOCK + size]
        if len(body) == size:
            members[name] = body
        offset += TAR_BLOCK + ((size + TAR_BLOCK - 1) // TAR_BLOCK) * TAR_BLOCK
    return members


def manifest_entries(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {entry["path"]: entry for entry in manifest["unique_files"]}


def inspect_legacy_archive(expected: dict[str, dict[str, Any]]) -> dict[str, Any]:
    joined = join_chunks("legacy-src.tar.gz.b64.part*")
    compressed = decode_base64_prefix(joined)
    blob, complete = inflate_prefix(compressed)

    verified: list[str] = []
    for name, body in walk_tar(blob).items():
        _, _, relative = name.partition("legacy-src/")
        entry = expected.get(relative)
        if entry is None:
            continue
        if entry["bytes"] == len(body) and entry["sha256"] == hashlib.sha256(body).hexdigest():
            verified.append(relative)

    return {
        "chunk_count": len(sorted(IMPORT_DIR.glob("legacy-src.tar.gz.b64.part*"))),
        "joined_base64_length": len(joined),
        "joined_base64_sha256": hashlib.sha256(joined.encode("ascii")).hexdigest(),
        "restores_completely": complete,
        "recovered_stream_bytes": len(blob),
        "hash_verified_files": sorted(verified),
        "unrecoverable_files": sorted(set(expected) - set(verified)),
    }


def inspect_workspace_archive() -> dict[str, Any]:
    joined = join_chunks("workspace-index.json.gz.b64.part*")
    compressed = decode_base64_prefix(joined)
    blob, complete = inflate_prefix(compressed)

    text = blob.decode("utf-8", "replace")
    instances: list[dict[str, Any]] = []
    marker = '"instances":['
    if marker in text:
        cursor = text.index(marker) + len(marker)
        while True:
            match = INSTANCE_PATTERN.match(text, cursor)
            if match is None:
                break
            instances.append(json.loads(match.group(0)))
            cursor = match.end()
            if cursor < len(text) and text[cursor] == ",":
                cursor += 1
            else:
                break

    payload = json.dumps(instances, separators=(",", ":"), sort_keys=True).encode("utf-8")
    return {
        "chunk_count": len(sorted(IMPORT_DIR.glob("workspace-index.json.gz.b64.part*"))),
        "joined_base64_length": len(joined),
        "joined_base64_sha256": hashlib.sha256(joined.encode("ascii")).hexdigest(),
        "restores_completely": complete,
        "recovered_stream_bytes": len(blob),
        "recovered_instance_count": len(instances),
        "recovered_instances_sha256": hashlib.sha256(payload).hexdigest(),
        "instances": instances,
    }


def check_recovered_tree(expected: dict[str, dict[str, Any]], verified: list[str]) -> int:
    """The plain-text re-preservation must stay byte-identical to the manifest."""
    errors = 0
    if not RECOVERED_SRC_DIR.is_dir():
        problem(f"missing recovered source tree: {RECOVERED_SRC_DIR.relative_to(ROOT)}")
        return 1

    present = {
        str(path.relative_to(RECOVERED_SRC_DIR)).replace("\\", "/")
        for path in RECOVERED_SRC_DIR.rglob("*")
        if path.is_file()
    }

    for relative in verified:
        if relative not in present:
            problem(f"recoverable file is not re-preserved as plain text: {relative}")
            errors += 1
            continue
        body = (RECOVERED_SRC_DIR / relative).read_bytes()
        entry = expected[relative]
        if len(body) != entry["bytes"]:
            problem(
                f"recovered/{relative} is {len(body)} bytes, manifest says {entry['bytes']}"
            )
            errors += 1
        elif hashlib.sha256(body).hexdigest() != entry["sha256"]:
            problem(f"recovered/{relative} does not match its manifest SHA-256")
            errors += 1

    for relative in sorted(present - set(verified)):
        problem(f"recovered tree holds a file the archive cannot verify: {relative}")
        errors += 1

    return errors


def check_recovered_workspace(observed: dict[str, Any]) -> int:
    if not RECOVERED_WORKSPACE.is_file():
        problem(f"missing recovered index: {RECOVERED_WORKSPACE.relative_to(ROOT)}")
        return 1

    document = json.loads(RECOVERED_WORKSPACE.read_text(encoding="utf-8"))
    committed = document.get("instances")
    if committed != observed["instances"]:
        problem(
            "recovered workspace index does not match what the archive currently decodes"
        )
        return 1
    return 0


def compare_to_baseline(observed: dict[str, Any], baseline: dict[str, Any]) -> int:
    errors = 0
    for name in ("legacy-src", "workspace-index"):
        current = observed["archives"][name]
        recorded = baseline["archives"][name]

        if current["joined_base64_sha256"] != recorded["joined_base64_sha256"]:
            problem(
                f"{name}: chunk contents changed; rerun with --update-baseline only when "
                "the change is an intentional, reviewed repair"
            )
            errors += 1

        if recorded["restores_completely"] and not current["restores_completely"]:
            problem(f"{name}: archive used to restore completely and no longer does")
            errors += 1

    legacy_now = set(observed["archives"]["legacy-src"]["hash_verified_files"])
    legacy_before = set(baseline["archives"]["legacy-src"]["hash_verified_files"])
    for lost in sorted(legacy_before - legacy_now):
        problem(f"legacy-src: {lost} no longer verifies against the manifest")
        errors += 1

    instances_now = observed["archives"]["workspace-index"]["recovered_instance_count"]
    instances_before = baseline["archives"]["workspace-index"]["recovered_instance_count"]
    if instances_now < instances_before:
        problem(
            "workspace-index: recoverable instance rows dropped from "
            f"{instances_before} to {instances_now}"
        )
        errors += 1

    return errors


def build_report(manifest: dict[str, Any]) -> dict[str, Any]:
    expected = manifest_entries(manifest)
    legacy = inspect_legacy_archive(expected)
    workspace = inspect_workspace_archive()
    return {
        "format_version": 1,
        "source_place_sha256": manifest["source"]["sha256"],
        "declared_unique_files": len(expected),
        "declared_workspace_instances": manifest["counts"]["workspace_instances"],
        "archives": {"legacy-src": legacy, "workspace-index": workspace},
    }


def strip_volatile(report: dict[str, Any]) -> dict[str, Any]:
    """Baseline stores counts and hashes, never the recovered payload itself."""
    trimmed = json.loads(json.dumps(report))
    trimmed["archives"]["workspace-index"].pop("instances", None)
    return trimmed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--update-baseline",
        action="store_true",
        help="rewrite INTEGRITY-BASELINE.json from the current measurement",
    )
    parser.add_argument(
        "--extract-to",
        type=Path,
        help="write every hash-verified legacy source into this directory",
    )
    args = parser.parse_args()

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    expected = manifest_entries(manifest)
    report = build_report(manifest)
    legacy = report["archives"]["legacy-src"]
    workspace = report["archives"]["workspace-index"]

    if args.extract_to is not None:
        blob, _ = inflate_prefix(decode_base64_prefix(join_chunks("legacy-src.tar.gz.b64.part*")))
        members = walk_tar(blob)
        for relative in legacy["hash_verified_files"]:
            destination = args.extract_to / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(members[f"legacy-src/{relative}"])
        note(f"extracted {len(legacy['hash_verified_files'])} verified files to {args.extract_to}")

    if args.update_baseline:
        BASELINE_PATH.write_text(
            json.dumps(strip_volatile(report), indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        note(f"baseline rewritten: {BASELINE_PATH.relative_to(ROOT)}")
        return 0

    if not BASELINE_PATH.is_file():
        problem(f"missing baseline: {BASELINE_PATH.relative_to(ROOT)}")
        return 1

    baseline = json.loads(BASELINE_PATH.read_text(encoding="utf-8"))
    errors = compare_to_baseline(report, baseline)
    errors += check_recovered_tree(expected, legacy["hash_verified_files"])
    errors += check_recovered_workspace(workspace)

    note(
        f"legacy-src: {len(legacy['hash_verified_files'])}/{len(expected)} files hash-verified, "
        f"{len(legacy['unrecoverable_files'])} unrecoverable"
    )
    note(
        f"workspace-index: {workspace['recovered_instance_count']}/"
        f"{report['declared_workspace_instances']} instance rows recoverable"
    )
    if not legacy["restores_completely"] or not workspace["restores_completely"]:
        note(
            "archives remain damaged; full fidelity needs re-extraction from the source "
            "place in Studio (see docs/production/RBXL-IMPORT-INTEGRITY-2026-08-07.md)"
        )

    if errors:
        print(f"[import] FAILED with {errors} error(s)", file=sys.stderr)
        return 1

    note("OK: recovered material matches the manifest and no recovery was lost")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
