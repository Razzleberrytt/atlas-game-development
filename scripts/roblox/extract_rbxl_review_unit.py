#!/usr/bin/env python3
"""Extract one checksum-gated review unit directly from a canonical RBXL.

This composes the existing binary property decoder with the bounded subtree
selector. It exists so Patch 0.5 recovery does not require committing or manually
handling the historical full 1.5 MB decoder artifact just to review one civic
landmark.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from extract_rbxl_world_properties import parse_place
from select_rbxl_subtree_evidence import select_subtree


def extract_review_unit(place: Path, subtree: str, expected_source_sha256: str | None) -> dict:
    document = parse_place(place)
    return select_subtree(document, subtree, expected_source_sha256)


def run_self_test() -> None:
    if not callable(parse_place) or not callable(select_subtree):
        raise AssertionError("review-unit extraction dependencies must be callable")
    print("[rbxl-review-unit] self-test OK")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place", nargs="?", help="path to the canonical binary .rbxl place")
    parser.add_argument("--subtree", help="exact Workspace subtree path to emit")
    parser.add_argument("--out", help="bounded review artifact path")
    parser.add_argument(
        "--expected-source-sha256",
        help="canonical source checksum; extraction fails closed on mismatch",
    )
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        if args.place is None:
            return 0

    if args.place is None or args.subtree is None or args.out is None:
        parser.error("place, --subtree, and --out are required unless --self-test is used alone")

    selected = extract_review_unit(
        Path(args.place),
        args.subtree,
        args.expected_source_sha256,
    )
    output = Path(args.out)
    output.write_text(json.dumps(selected, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"[rbxl-review-unit] wrote {output}: "
        f"{selected['review_unit']['property_rows']} rows from {selected['subtree_path']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
