#!/usr/bin/env python3
"""Fail-closed verifier for a downloaded Living Kingdoms Main World CI artifact bundle."""

from __future__ import annotations

import argparse
import hashlib
import tempfile
from pathlib import Path

from _console import use_utf8_output

ARTIFACT_NAME = "LivingKingdomsMainWorld.rbxlx"
CHECKSUM_NAME = "LivingKingdomsMainWorld.rbxlx.sha256"
IDENTITY_NAME = "LivingKingdomsMainWorld.identity.txt"
PROJECT_PATH = "games/living-kingdoms/main-world.project.json"


def parse_identity(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        key, separator, value = line.partition("=")
        if separator != "=" or not key or not value:
            raise RuntimeError(f"malformed identity line: {raw_line!r}")
        if key in values:
            raise RuntimeError(f"duplicate identity key: {key}")
        values[key] = value
    return values


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify(bundle_dir: Path, expected_commit: str) -> str:
    if len(expected_commit) != 40 or any(char not in "0123456789abcdef" for char in expected_commit.lower()):
        raise RuntimeError("expected commit must be a full 40-character hexadecimal SHA")

    artifact = bundle_dir / ARTIFACT_NAME
    checksum = bundle_dir / CHECKSUM_NAME
    identity = bundle_dir / IDENTITY_NAME
    for required in (artifact, checksum, identity):
        if not required.is_file():
            raise RuntimeError(f"missing artifact bundle file: {required.name}")

    identity_values = parse_identity(identity)
    expected_identity = {
        "commit": expected_commit,
        "project": PROJECT_PATH,
        "artifact": ARTIFACT_NAME,
    }
    if identity_values != expected_identity:
        raise RuntimeError(
            f"identity mismatch: expected {expected_identity!r}, got {identity_values!r}"
        )

    checksum_line = checksum.read_text(encoding="utf-8").strip()
    fields = checksum_line.split()
    if len(fields) != 2:
        raise RuntimeError("checksum sidecar must contain exactly one SHA-256 and one filename")
    expected_digest, recorded_name = fields
    recorded_name = recorded_name.lstrip("*")
    if recorded_name != ARTIFACT_NAME:
        raise RuntimeError(
            f"checksum sidecar must name {ARTIFACT_NAME!r}, got {recorded_name!r}"
        )
    if "/" in recorded_name or "\\" in recorded_name:
        raise RuntimeError("checksum sidecar filename must be portable and relative")
    if len(expected_digest) != 64 or any(char not in "0123456789abcdef" for char in expected_digest.lower()):
        raise RuntimeError("checksum sidecar does not contain a valid SHA-256")

    actual_digest = sha256(artifact)
    if actual_digest.lower() != expected_digest.lower():
        raise RuntimeError(
            f"artifact SHA-256 mismatch: sidecar={expected_digest}, actual={actual_digest}"
        )

    return actual_digest


def write_test_bundle(root: Path, commit: str, payload: bytes = b"main-world-test-artifact") -> None:
    artifact = root / ARTIFACT_NAME
    artifact.write_bytes(payload)
    digest = sha256(artifact)
    (root / CHECKSUM_NAME).write_text(f"{digest}  {ARTIFACT_NAME}\n", encoding="utf-8")
    (root / IDENTITY_NAME).write_text(
        f"commit={commit}\nproject={PROJECT_PATH}\nartifact={ARTIFACT_NAME}\n",
        encoding="utf-8",
    )


def self_test() -> None:
    commit = "a" * 40
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        write_test_bundle(root, commit)
        verify(root, commit)

        (root / ARTIFACT_NAME).write_bytes(b"tampered")
        try:
            verify(root, commit)
        except RuntimeError as exc:
            if "SHA-256 mismatch" not in str(exc):
                raise
        else:
            raise RuntimeError("self-test expected tampered artifact rejection")

        write_test_bundle(root, commit)
        try:
            verify(root, "b" * 40)
        except RuntimeError as exc:
            if "identity mismatch" not in str(exc):
                raise
        else:
            raise RuntimeError("self-test expected wrong-commit rejection")

        (root / CHECKSUM_NAME).write_text(
            f"{sha256(root / ARTIFACT_NAME)}  /tmp/{ARTIFACT_NAME}\n",
            encoding="utf-8",
        )
        try:
            verify(root, commit)
        except RuntimeError as exc:
            if "must name" not in str(exc):
                raise
        else:
            raise RuntimeError("self-test expected non-portable checksum rejection")

    print("[main-world-artifact-bundle] self-test OK")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle_dir", nargs="?", type=Path)
    parser.add_argument("expected_commit", nargs="?")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    if args.bundle_dir is None or args.expected_commit is None:
        parser.error("bundle_dir and expected_commit are required unless --self-test is used")

    digest = verify(args.bundle_dir, args.expected_commit.lower())
    print(f"[main-world-artifact-bundle] OK commit={args.expected_commit.lower()} sha256={digest}")
    return 0


if __name__ == "__main__":
    use_utf8_output()
    raise SystemExit(main())
