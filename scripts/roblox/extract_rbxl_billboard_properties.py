#!/usr/bin/env python3
"""Add BillboardGui recovery to the BA-005 presentation decoder.

BillboardGui uses only value types already verified by
extract_rbxl_presentation_properties.py. Keeping this as a thin overlay makes
that fact explicit and avoids duplicating binary decoding logic.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

PRESENTATION_PATH = Path(__file__).with_name("extract_rbxl_presentation_properties.py")
SPEC = importlib.util.spec_from_file_location("_rbxl_presentation_base", PRESENTATION_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load presentation decoder: {PRESENTATION_PATH}")
presentation = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(presentation)

presentation.base.PROPERTY_ALLOWLIST["BillboardGui"] = {
    "Name",
    "Active",
    "Adornee",
    "AlwaysOnTop",
    "Brightness",
    "ClipsDescendants",
    "DistanceLowerLimit",
    "DistanceUpperLimit",
    "Enabled",
    "ExtentsOffset",
    "ExtentsOffsetWorldSpace",
    "LightInfluence",
    "MaxDistance",
    "PlayerToHideFrom",
    "ResetOnSpawn",
    "SelectionBehaviorDown",
    "SelectionBehaviorLeft",
    "SelectionBehaviorRight",
    "SelectionBehaviorUp",
    "SelectionGroup",
    "Size",
    "SizeOffset",
    "StudsOffset",
    "StudsOffsetWorldSpace",
    "ZIndexBehavior",
}


def run_self_test() -> None:
    presentation.run_self_test()
    allowlist = presentation.base.PROPERTY_ALLOWLIST.get("BillboardGui")
    if allowlist is None or "Size" not in allowlist or "StudsOffset" not in allowlist:
        raise AssertionError("BillboardGui recovery allowlist is incomplete")
    print("[rbxl-billboard] self-test OK")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("place", nargs="?", help="path to a binary .rbxl place")
    parser.add_argument("--out", default="rbxl-billboard-properties.json")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--verify-bootstrap-fixtures", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        if args.place is None:
            return 0
    if args.place is None:
        parser.error("place is required unless --self-test is used")

    document = presentation.base.parse_place(Path(args.place))
    if args.verify_bootstrap_fixtures:
        presentation.base.verify_bootstrap_fixtures(document)
        print("[rbxl-billboard] bootstrap fixtures OK")
    Path(args.out).write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"[rbxl-billboard] wrote {args.out}: "
        f"{document['metadata']['workspace_property_rows']} Workspace property rows"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
