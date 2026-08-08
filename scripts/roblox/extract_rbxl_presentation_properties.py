#!/usr/bin/env python3
"""Extend the BA-005 RBXL decoder with UI and particle presentation types.

This module deliberately layers on top of extract_rbxl_world_properties.py so
geometry decoding keeps one tested implementation. It adds the binary types and
allowlists needed for recovered SurfaceGui, TextLabel and ParticleEmitter data.

Binary layouts follow the public rbx-dom binary format documentation:
UDim2 (0x07), Vector2 (0x0D), NumberSequence (0x15), ColorSequence (0x16),
and transformed/interleaved Int32 (0x03).
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import struct
from pathlib import Path
from typing import Any

BASE_PATH = Path(__file__).with_name("extract_rbxl_world_properties.py")
SPEC = importlib.util.spec_from_file_location("_rbxl_world_properties_base", BASE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load base decoder: {BASE_PATH}")
base = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(base)

base.TYPE_NAMES.update(
    {
        0x06: "UDim",
        0x07: "UDim2",
        0x0D: "Vector2",
        0x15: "NumberSequence",
        0x16: "ColorSequence",
    }
)

base.PROPERTY_ALLOWLIST.update(
    {
        "SurfaceGui": {
            "Name",
            "Active",
            "AlwaysOnTop",
            "Brightness",
            "CanvasSize",
            "ClipsDescendants",
            "Enabled",
            "Face",
            "LightInfluence",
            "MaxDistance",
            "PixelsPerStud",
            "ResetOnSpawn",
            "SizingMode",
            "ToolPunchThroughDistance",
            "ZIndexBehavior",
            "ZOffset",
        },
        "TextLabel": {
            "Name",
            "Active",
            "AnchorPoint",
            "AutomaticSize",
            "BackgroundColor3",
            "BackgroundTransparency",
            "BorderColor3",
            "BorderMode",
            "BorderSizePixel",
            "ClipsDescendants",
            "Interactable",
            "LayoutOrder",
            "LineHeight",
            "Position",
            "RichText",
            "Rotation",
            "Selectable",
            "SelectionGroup",
            "SelectionOrder",
            "Size",
            "SizeConstraint",
            "Text",
            "TextColor3",
            "TextDirection",
            "TextScaled",
            "TextSize",
            "TextStrokeColor3",
            "TextStrokeTransparency",
            "TextTransparency",
            "TextTruncate",
            "TextWrapped",
            "TextXAlignment",
            "TextYAlignment",
            "Visible",
            "ZIndex",
        },
        "ParticleEmitter": {
            "Name",
            "Acceleration",
            "Brightness",
            "Color",
            "Drag",
            "EmissionDirection",
            "Enabled",
            "FlipbookBlendFrames",
            "FlipbookFramerate",
            "FlipbookLayout",
            "FlipbookMode",
            "FlipbookSizeX",
            "FlipbookSizeY",
            "FlipbookStartRandom",
            "Lifetime",
            "LightEmission",
            "LightInfluence",
            "LockedToPart",
            "Orientation",
            "Rate",
            "RotSpeed",
            "Rotation",
            "Shape",
            "ShapeInOut",
            "ShapePartial",
            "ShapeStyle",
            "Size",
            "Speed",
            "SpreadAngle",
            "Squash",
            "Texture",
            "TimeScale",
            "Transparency",
            "VelocityInheritance",
            "WindAffectsDrag",
            "ZOffset",
        },
    }
)

BASE_DECODE_PROPERTY_VALUES = base.decode_property_values


def decode_int32_array(data: bytes, count: int) -> list[int]:
    return [base.zigzag32(word) for word in base.deinterleaved_u32_be(data, count)]


def decode_udim2(
    data: bytes, offset: int, count: int
) -> tuple[list[dict[str, dict[str, float | int]]], int]:
    x_scales = base.decode_float_array(data[offset : offset + 4 * count], count)
    offset += 4 * count
    y_scales = base.decode_float_array(data[offset : offset + 4 * count], count)
    offset += 4 * count
    x_offsets = decode_int32_array(data[offset : offset + 4 * count], count)
    offset += 4 * count
    y_offsets = decode_int32_array(data[offset : offset + 4 * count], count)
    offset += 4 * count
    return [
        {
            "x": {"scale": x_scale, "offset": x_offset},
            "y": {"scale": y_scale, "offset": y_offset},
        }
        for x_scale, y_scale, x_offset, y_offset in zip(x_scales, y_scales, x_offsets, y_offsets)
    ], offset


def decode_vector2(data: bytes, offset: int, count: int) -> tuple[list[list[float]], int]:
    xs = base.decode_float_array(data[offset : offset + 4 * count], count)
    offset += 4 * count
    ys = base.decode_float_array(data[offset : offset + 4 * count], count)
    offset += 4 * count
    return [[x, y] for x, y in zip(xs, ys)], offset


def decode_number_sequences(
    data: bytes, offset: int, count: int
) -> tuple[list[list[dict[str, float]]], int]:
    sequences: list[list[dict[str, float]]] = []
    for _ in range(count):
        keypoint_count = base.u32le(data, offset)
        offset += 4
        keypoints: list[dict[str, float]] = []
        for _ in range(keypoint_count):
            time, value, envelope = struct.unpack_from("<fff", data, offset)
            offset += 12
            keypoints.append({"time": time, "value": value, "envelope": envelope})
        sequences.append(keypoints)
    return sequences, offset


def decode_color_sequences(
    data: bytes, offset: int, count: int
) -> tuple[list[list[dict[str, Any]]], int]:
    sequences: list[list[dict[str, Any]]] = []
    for _ in range(count):
        keypoint_count = base.u32le(data, offset)
        offset += 4
        keypoints: list[dict[str, Any]] = []
        for _ in range(keypoint_count):
            time, red, green, blue, envelope = struct.unpack_from("<fffff", data, offset)
            offset += 20
            keypoints.append(
                {
                    "time": time,
                    "color": [red, green, blue],
                    "envelope": envelope,
                }
            )
        sequences.append(keypoints)
    return sequences, offset


def decode_property_values(
    payload: bytes, offset: int, type_id: int, count: int, shared_strings: list[bytes]
) -> tuple[list[Any] | None, int]:
    if type_id == 0x03:
        return decode_int32_array(payload[offset : offset + 4 * count], count), offset + 4 * count
    if type_id == 0x07:
        return decode_udim2(payload, offset, count)
    if type_id == 0x0D:
        return decode_vector2(payload, offset, count)
    if type_id == 0x15:
        return decode_number_sequences(payload, offset, count)
    if type_id == 0x16:
        return decode_color_sequences(payload, offset, count)
    return BASE_DECODE_PROPERTY_VALUES(payload, offset, type_id, count, shared_strings)


base.decode_property_values = decode_property_values


def encode_transformed_int32(value: int) -> bytes:
    transformed = ((value << 1) ^ (value >> 31)) & 0xFFFFFFFF
    return transformed.to_bytes(4, "big")


def run_self_test() -> None:
    base.run_self_test()

    integer_samples = [-30, 0, 60]
    encoded_ints = base.interleave([encode_transformed_int32(value) for value in integer_samples])
    if decode_int32_array(encoded_ints, len(integer_samples)) != integer_samples:
        raise AssertionError("presentation Int32 decoder failed")

    udim2_raw = b"".join(
        [
            base.interleave([base.encode_roblox_float(0.75)]),
            base.interleave([base.encode_roblox_float(-1.5)]),
            base.interleave([encode_transformed_int32(-30)]),
            base.interleave([encode_transformed_int32(60)]),
        ]
    )
    udim2_values, udim2_offset = decode_udim2(udim2_raw, 0, 1)
    if udim2_offset != 16:
        raise AssertionError("UDim2 decoder offset mismatch")
    udim2 = udim2_values[0]
    if not base.nearly_equal(float(udim2["x"]["scale"]), 0.75) or udim2["x"]["offset"] != -30:
        raise AssertionError(f"UDim2 X decode failed: {udim2!r}")
    if not base.nearly_equal(float(udim2["y"]["scale"]), -1.5) or udim2["y"]["offset"] != 60:
        raise AssertionError(f"UDim2 Y decode failed: {udim2!r}")

    vector2_raw = base.interleave([base.encode_roblox_float(-100.8)]) + base.interleave(
        [base.encode_roblox_float(200.55)]
    )
    vector2_values, vector2_offset = decode_vector2(vector2_raw, 0, 1)
    if vector2_offset != 8:
        raise AssertionError("Vector2 decoder offset mismatch")
    base.verify_vec(vector2_values[0], [-100.8, 200.55], "presentation Vector2")

    number_sequence_raw = struct.pack("<Iffffff", 2, 0.0, 0.0, 0.0, 1.0, 1.0, 0.5)
    number_sequences, number_offset = decode_number_sequences(number_sequence_raw, 0, 1)
    if number_offset != len(number_sequence_raw) or len(number_sequences[0]) != 2:
        raise AssertionError("NumberSequence decoder failed")

    color_sequence_raw = struct.pack(
        "<Iffffffffff",
        2,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        1.0,
        0.0,
    )
    color_sequences, color_offset = decode_color_sequences(color_sequence_raw, 0, 1)
    if color_offset != len(color_sequence_raw) or len(color_sequences[0]) != 2:
        raise AssertionError("ColorSequence decoder failed")

    print("[rbxl-presentation] self-test OK")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("place", nargs="?", help="path to a binary .rbxl place")
    parser.add_argument("--out", default="rbxl-presentation-properties.json")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--verify-bootstrap-fixtures", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        if args.place is None:
            return 0
    if args.place is None:
        parser.error("place is required unless --self-test is used")

    document = base.parse_place(Path(args.place))
    if args.verify_bootstrap_fixtures:
        base.verify_bootstrap_fixtures(document)
        print("[rbxl-presentation] bootstrap fixtures OK")
    Path(args.out).write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"[rbxl-presentation] wrote {args.out}: "
        f"{document['metadata']['workspace_property_rows']} Workspace property rows"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
