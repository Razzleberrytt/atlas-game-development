#!/usr/bin/env python3
"""Restore preserved Studio-only source and Workspace hierarchy beside this script.

Both chunked archives are damaged in the committed blobs, so a full restore is
no longer possible from this repository. This script now restores everything
that still decodes and says plainly what is missing, instead of failing with a
base64 padding traceback.

The verified material is already committed as plain text under `recovered/`.
Use `python scripts/verify_studio_import_package.py` from the repository root
for the authoritative check. See
`docs/production/RBXL-IMPORT-INTEGRITY-2026-08-07.md` for the finding and the
Studio re-extraction steps that would make this package whole again.
"""

import base64
import json
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
GZIP_WBITS = 16 + zlib.MAX_WBITS
TAR_BLOCK = 512


def joined(pattern):
    return "".join(p.read_text().strip() for p in sorted(HERE.glob(pattern)))


def decode_prefix(text):
    """Decode as much of the concatenated base64 as forms whole quadruplets."""
    usable = len(text) - (len(text) % 4)
    return base64.b64decode(text[:usable])


def inflate_prefix(compressed):
    engine = zlib.decompressobj(GZIP_WBITS)
    out = bytearray()
    try:
        for offset in range(0, len(compressed), 4096):
            out += engine.decompress(compressed[offset : offset + 4096])
        out += engine.flush()
        return bytes(out), True
    except zlib.error:
        return bytes(out), False


def extract_tar_prefix(blob, destination):
    written = 0
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
        if len(body) == size and not name.endswith("/"):
            target = destination / name
            if destination.resolve() in target.resolve().parents:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(body)
                written += 1
        offset += TAR_BLOCK + ((size + TAR_BLOCK - 1) // TAR_BLOCK) * TAR_BLOCK
    return written


def main():
    manifest = json.loads((HERE / "manifest.json").read_text())
    declared_files = len(manifest["unique_files"])
    declared_instances = manifest["counts"]["workspace_instances"]

    src_blob, src_complete = inflate_prefix(decode_prefix(joined("legacy-src.tar.gz.b64.part*")))
    written = extract_tar_prefix(src_blob, HERE)
    print(f"restored {written}/{declared_files} sources to {HERE / 'legacy-src'}")

    ws_blob, ws_complete = inflate_prefix(
        decode_prefix(joined("workspace-index.json.gz.b64.part*"))
    )
    (HERE / "workspace-index.partial.json").write_bytes(ws_blob)
    print(f"restored partial hierarchy index to {HERE / 'workspace-index.partial.json'}")

    if src_complete and ws_complete:
        return

    print()
    print("WARNING: the chunked archives are damaged and did not restore completely.")
    print(f"  legacy-src archive complete:      {src_complete}")
    print(f"  workspace-index archive complete: {ws_complete}")
    print(f"  declared Workspace instances:     {declared_instances}")
    print("  workspace-index.partial.json is truncated and NOT valid JSON.")
    print()
    print("Use the verified plain-text copies instead:")
    print("  recovered/legacy-src/**")
    print("  recovered/workspace-index-recovered.json")
    print("Check them with: python scripts/verify_studio_import_package.py")
    print("Finding: docs/production/RBXL-IMPORT-INTEGRITY-2026-08-07.md")


if __name__ == "__main__":
    main()
