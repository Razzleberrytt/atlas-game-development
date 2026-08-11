#!/usr/bin/env python3
"""Select one reviewable Workspace subtree from full RBXL decoder output.

Patch 0.5 Main World recovery must admit one coherent authored group at a time.
The base/presentation RBXL decoders already produce exact per-instance rows, but
historical recovery summarized those outputs manually. This tool makes the
selection step deterministic, prefix-safe, checksum-gated, and reusable.

It never reads Roblox runtime state and never creates geometry. Its input is the
JSON emitted by an existing checksum-pinned decoder; its output is a bounded
review artifact containing only one exact Workspace subtree.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
from typing import Any

FORMAT_VERSION = 1
STATUS = "REVIEWABLE_SUBTREE_EVIDENCE_V1"


def normalized_subtree(value: str) -> str:
    subtree = value.strip().rstrip("/")
    if not subtree or subtree == "Workspace" or not subtree.startswith("Workspace/"):
        raise ValueError("subtree must be a concrete path below Workspace")
    if "//" in subtree:
        raise ValueError("subtree must not contain empty path segments")
    return subtree


def row_is_in_subtree(path: str, subtree: str) -> bool:
    return path == subtree or path.startswith(subtree + "/")


def validate_decoder_document(document: Any) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    if not isinstance(document, dict):
        raise ValueError("decoder document must be a JSON object")
    metadata = document.get("metadata")
    instances = document.get("instances")
    if not isinstance(metadata, dict) or not isinstance(instances, list):
        raise ValueError("decoder document must contain metadata and instances")

    seen_ids: set[int] = set()
    for row in instances:
        if not isinstance(row, dict):
            raise ValueError("every decoder instance row must be an object")
        instance_id = row.get("id")
        path = row.get("path")
        class_name = row.get("class")
        properties = row.get("properties")
        if not isinstance(instance_id, int) or instance_id in seen_ids:
            raise ValueError("decoder instance IDs must be unique integers")
        if not isinstance(path, str) or not path.startswith("Workspace/"):
            raise ValueError("decoder instance paths must be concrete Workspace paths")
        if not isinstance(class_name, str) or not class_name:
            raise ValueError("decoder instance classes must be nonempty strings")
        if not isinstance(properties, dict):
            raise ValueError("decoder instance properties must be objects")
        seen_ids.add(instance_id)
    return metadata, instances


def select_subtree(
    document: Any,
    raw_subtree: str,
    expected_source_sha256: str | None = None,
) -> dict[str, Any]:
    metadata, instances = validate_decoder_document(document)
    subtree = normalized_subtree(raw_subtree)

    source_sha = metadata.get("source_sha256")
    if not isinstance(source_sha, str) or not source_sha:
        raise ValueError("decoder metadata must include source_sha256")
    if expected_source_sha256 is not None and source_sha != expected_source_sha256:
        raise ValueError(
            f"source SHA mismatch: expected {expected_source_sha256}, got {source_sha}"
        )

    selected = [row for row in instances if row_is_in_subtree(row["path"], subtree)]
    selected.sort(key=lambda row: (row["path"].count("/"), row["path"], row["id"]))
    if not selected:
        raise ValueError(f"no decoded property rows found for subtree {subtree}")

    class_counts = Counter(row["class"] for row in selected)
    direct_children = sorted(
        {
            row["path"]
            for row in selected
            if row["path"] != subtree
            and row["path"].count("/") == subtree.count("/") + 1
        }
    )
    exact_root_rows = sum(1 for row in selected if row["path"] == subtree)

    source = {
        "file": metadata.get("source_file"),
        "bytes": metadata.get("source_bytes"),
        "sha256": source_sha,
        "rbxl_version": metadata.get("rbxl_version"),
    }
    return {
        "format_version": FORMAT_VERSION,
        "status": STATUS,
        "subtree_path": subtree,
        "source_rbxl": source,
        "decoder_scope": {
            "workspace_property_rows": metadata.get("workspace_property_rows"),
            "decoded_property_kinds": metadata.get("decoded_property_kinds", []),
            "unsupported_allowed_properties": metadata.get("unsupported_allowed_properties", []),
        },
        "review_unit": {
            "property_rows": len(selected),
            "exact_root_rows": exact_root_rows,
            "class_counts": dict(sorted(class_counts.items())),
            "direct_child_paths": direct_children,
        },
        "instances": selected,
    }


def run_self_test() -> None:
    document = {
        "metadata": {
            "source_file": "fixture.rbxl",
            "source_bytes": 123,
            "source_sha256": "abc123",
            "rbxl_version": 0,
            "workspace_property_rows": 4,
            "decoded_property_kinds": [],
            "unsupported_allowed_properties": [],
        },
        "instances": [
            {
                "id": 4,
                "path": "Workspace/HubTown/CentralFountainExtra/Stone",
                "class": "Part",
                "parent_id": 3,
                "properties": {"Anchored": True},
            },
            {
                "id": 2,
                "path": "Workspace/HubTown/CentralFountain/Water",
                "class": "Part",
                "parent_id": 1,
                "properties": {"Transparency": 0.4},
            },
            {
                "id": 1,
                "path": "Workspace/HubTown/CentralFountain",
                "class": "Model",
                "parent_id": 9,
                "properties": {},
            },
            {
                "id": 3,
                "path": "Workspace/HubTown/CentralFountain/Water/Glow",
                "class": "PointLight",
                "parent_id": 2,
                "properties": {"Brightness": 2.0},
            },
        ],
    }
    selected = select_subtree(
        document,
        "Workspace/HubTown/CentralFountain/",
        expected_source_sha256="abc123",
    )
    rows = selected["instances"]
    if [row["id"] for row in rows] != [1, 2, 3]:
        raise AssertionError("subtree selection must include exact descendants and exclude prefix lookalikes")
    if selected["review_unit"]["property_rows"] != 3:
        raise AssertionError("subtree row count mismatch")
    if selected["review_unit"]["exact_root_rows"] != 1:
        raise AssertionError("subtree root count mismatch")
    if selected["review_unit"]["class_counts"] != {"Model": 1, "Part": 1, "PointLight": 1}:
        raise AssertionError("subtree class counts must be deterministic")
    if selected["review_unit"]["direct_child_paths"] != ["Workspace/HubTown/CentralFountain/Water"]:
        raise AssertionError("direct child paths must not include deeper descendants")

    try:
        select_subtree(document, "Workspace/HubTown/Missing", expected_source_sha256="abc123")
    except ValueError as exc:
        if "no decoded property rows" not in str(exc):
            raise
    else:
        raise AssertionError("missing subtrees must fail closed")

    try:
        select_subtree(document, "Workspace/HubTown/CentralFountain", expected_source_sha256="wrong")
    except ValueError as exc:
        if "source SHA mismatch" not in str(exc):
            raise
    else:
        raise AssertionError("source checksum mismatches must fail closed")

    try:
        normalized_subtree("Workspace")
    except ValueError:
        pass
    else:
        raise AssertionError("the selector must refuse whole-Workspace review units")

    print("[rbxl-subtree] self-test OK")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", nargs="?", help="full JSON output from an RBXL property decoder")
    parser.add_argument("--subtree", help="exact Workspace subtree path to select")
    parser.add_argument("--out", help="review artifact path")
    parser.add_argument("--expected-source-sha256", help="optional canonical source checksum gate")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        if args.input is None:
            return 0

    if args.input is None or args.subtree is None or args.out is None:
        parser.error("input, --subtree, and --out are required unless --self-test is used alone")

    document = json.loads(Path(args.input).read_text(encoding="utf-8"))
    selected = select_subtree(document, args.subtree, args.expected_source_sha256)
    output = Path(args.out)
    output.write_text(json.dumps(selected, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"[rbxl-subtree] wrote {output}: "
        f"{selected['review_unit']['property_rows']} rows from {selected['subtree_path']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
