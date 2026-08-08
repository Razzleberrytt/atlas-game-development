#!/usr/bin/env python3
"""Extract reviewable world properties from a Roblox binary place (RBXL).

BA-005 support tool. This does not write Roblox source or activate recovered
content. It decodes a deliberately bounded set of binary PROP types so authored
world geometry can be reconstructed from evidence instead of guesses.

The decoder follows the public RBXL binary format used by rbx-dom/RobloxAPI.
`lz4` is required only when parsing a real RBXL; `--self-test` stays dependency
free so CI can exercise the primitive decoders.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

RBXL_MAGIC = b"<roblox!\x89\xff\r\n\x1a\n"

ROTATION_MATRICES: dict[int, tuple[float, ...]] = {
    0x02: (1, 0, 0, 0, 1, 0, 0, 0, 1),
    0x03: (1, 0, 0, 0, 0, -1, 0, 1, 0),
    0x05: (1, 0, 0, 0, -1, 0, 0, 0, -1),
    0x06: (1, 0, 0, 0, 0, 1, 0, -1, 0),
    0x07: (0, 1, 0, 1, 0, 0, 0, 0, -1),
    0x09: (0, 0, 1, 1, 0, 0, 0, 1, 0),
    0x0A: (0, -1, 0, 1, 0, 0, 0, 0, 1),
    0x0C: (0, 0, -1, 1, 0, 0, 0, -1, 0),
    0x0D: (0, 1, 0, 0, 0, 1, 1, 0, 0),
    0x0E: (0, 0, -1, 0, 1, 0, 1, 0, 0),
    0x10: (0, -1, 0, 0, 0, -1, 1, 0, 0),
    0x11: (0, 0, 1, 0, -1, 0, 1, 0, 0),
    0x14: (-1, 0, 0, 0, 1, 0, 0, 0, -1),
    0x15: (-1, 0, 0, 0, 0, 1, 0, 1, 0),
    0x17: (-1, 0, 0, 0, -1, 0, 0, 0, 1),
    0x18: (-1, 0, 0, 0, 0, -1, 0, -1, 0),
    0x19: (0, 1, 0, -1, 0, 0, 0, 0, 1),
    0x1B: (0, 0, -1, -1, 0, 0, 0, 1, 0),
    0x1C: (0, -1, 0, -1, 0, 0, 0, 0, -1),
    0x1E: (0, 0, 1, -1, 0, 0, 0, -1, 0),
    0x1F: (0, 1, 0, 0, 0, -1, -1, 0, 0),
    0x20: (0, 0, 1, 0, 1, 0, -1, 0, 0),
    0x22: (0, -1, 0, 0, 0, 1, -1, 0, 0),
    0x23: (0, 0, -1, 0, -1, 0, -1, 0, 0),
}

TYPE_NAMES = {
    0x01: "String",
    0x02: "Bool",
    0x03: "Int32",
    0x04: "Float32",
    0x05: "Float64",
    0x0B: "BrickColor",
    0x0C: "Color3",
    0x0E: "Vector3",
    0x10: "CFrame",
    0x12: "Token",
    0x13: "Reference",
    0x17: "NumberRange",
    0x1A: "Color3uint8",
    0x1C: "SharedString",
}

# Scope is intentionally conservative. Unsupported properties are counted in
# metadata so expanding coverage is a deliberate follow-up, not silent loss.
PROPERTY_ALLOWLIST: dict[str, set[str]] = {
    "Part": {
        "Name", "Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow",
        "CFrame", "Color3uint8", "Material", "Reflectance", "Transparency", "size", "shape",
    },
    "SpawnLocation": {
        "Name", "Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow",
        "CFrame", "Color3uint8", "Material", "Reflectance", "Transparency", "size", "shape",
        "Neutral", "Enabled", "TeamColor",
    },
    "PointLight": {"Name", "Brightness", "Color", "Enabled", "Range", "Shadows"},
    "Fire": {"Name", "Color", "SecondaryColor", "Enabled", "TimeScale", "heat_xml", "size_xml"},
    "Attachment": {"Name", "CFrame"},
    "ProximityPrompt": {
        "Name", "ActionText", "ObjectText", "Enabled", "ClickablePrompt", "HoldDuration",
        "MaxActivationDistance", "RequiresLineOfSight", "KeyboardKeyCode", "GamepadKeyCode",
    },
    "Model": {"Name", "ModelMeshCFrame", "ModelMeshSize", "PrimaryPart", "ScaleFactor"},
}


def u32le(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def i32le(data: bytes, offset: int) -> int:
    return struct.unpack_from("<i", data, offset)[0]


def read_string(data: bytes, offset: int) -> tuple[bytes, int]:
    length = u32le(data, offset)
    offset += 4
    return data[offset : offset + length], offset + length


def deinterleave(data: bytes, count: int, width: int) -> list[bytes]:
    needed = count * width
    if len(data) < needed:
        raise ValueError(f"interleaved array is short: {len(data)} < {needed}")
    values = [bytearray(width) for _ in range(count)]
    cursor = 0
    for byte_index in range(width):
        for value_index in range(count):
            values[value_index][byte_index] = data[cursor]
            cursor += 1
    return [bytes(value) for value in values]


def deinterleaved_u32_be(data: bytes, count: int) -> list[int]:
    return [int.from_bytes(value, "big", signed=False) for value in deinterleave(data, count, 4)]


def zigzag32(value: int) -> int:
    return (value >> 1) ^ -(value & 1)


def decode_refs(data: bytes, offset: int, count: int) -> tuple[list[int], int]:
    words = deinterleaved_u32_be(data[offset : offset + 4 * count], count)
    offset += 4 * count
    previous = 0
    result: list[int] = []
    for word in words:
        previous += zigzag32(word)
        result.append(previous)
    return result, offset


def decode_roblox_float_word(word: int) -> float:
    # Roblox moves the IEEE-754 sign bit to the least-significant bit before
    # interleaving. Undo that one-bit rotation, then reinterpret the bits.
    ieee = (word >> 1) | ((word & 1) << 31)
    return struct.unpack(">f", ieee.to_bytes(4, "big"))[0]


def decode_float_array(data: bytes, count: int) -> list[float]:
    return [decode_roblox_float_word(word) for word in deinterleaved_u32_be(data, count)]


def decode_vector3(data: bytes, offset: int, count: int) -> tuple[list[list[float]], int]:
    xs = decode_float_array(data[offset : offset + 4 * count], count)
    offset += 4 * count
    ys = decode_float_array(data[offset : offset + 4 * count], count)
    offset += 4 * count
    zs = decode_float_array(data[offset : offset + 4 * count], count)
    offset += 4 * count
    return [[x, y, z] for x, y, z in zip(xs, ys, zs)], offset


def decode_color3uint8(data: bytes, offset: int, count: int) -> tuple[list[list[float]], int]:
    red = data[offset : offset + count]
    offset += count
    green = data[offset : offset + count]
    offset += count
    blue = data[offset : offset + count]
    offset += count
    return [[r / 255.0, g / 255.0, b / 255.0] for r, g, b in zip(red, green, blue)], offset


def decode_cframes(data: bytes, offset: int, count: int) -> tuple[list[dict[str, Any]], int]:
    rotations: list[tuple[int, list[float]]] = []
    for _ in range(count):
        rotation_id = data[offset]
        offset += 1
        if rotation_id == 0:
            matrix = list(struct.unpack_from("<9f", data, offset))
            offset += 36
        else:
            special = ROTATION_MATRICES.get(rotation_id)
            if special is None:
                raise ValueError(f"undefined CFrame rotation id {rotation_id:#x}")
            matrix = list(special)
        rotations.append((rotation_id, matrix))
    positions, offset = decode_vector3(data, offset, count)
    values = [
        {"position": position, "rotation_id": rotation_id, "rotation": matrix}
        for (rotation_id, matrix), position in zip(rotations, positions)
    ]
    return values, offset


def decode_number_ranges(data: bytes, offset: int, count: int) -> tuple[list[list[float]], int]:
    result = []
    for _ in range(count):
        minimum, maximum = struct.unpack_from("<ff", data, offset)
        offset += 8
        result.append([minimum, maximum])
    return result, offset


def iter_chunks(blob: bytes) -> Iterable[tuple[bytes, bytes]]:
    try:
        import lz4.block  # type: ignore
    except ModuleNotFoundError as exc:
        raise RuntimeError("Parsing a real RBXL requires the Python 'lz4' package") from exc

    offset = 32
    while offset + 16 <= len(blob):
        signature = blob[offset : offset + 4]
        compressed, uncompressed, _reserved = struct.unpack_from("<III", blob, offset + 4)
        offset += 16
        stored = compressed if compressed else uncompressed
        raw = blob[offset : offset + stored]
        offset += stored
        payload = lz4.block.decompress(raw, uncompressed_size=uncompressed) if compressed else raw
        if len(payload) != uncompressed:
            raise ValueError(f"chunk {signature!r} length mismatch")
        yield signature, payload
        if signature == b"END\x00":
            break


def decode_property_values(
    payload: bytes, offset: int, type_id: int, count: int, shared_strings: list[bytes]
) -> tuple[list[Any] | None, int]:
    if type_id == 0x01:
        values = []
        for _ in range(count):
            value, offset = read_string(payload, offset)
            values.append(value.decode("utf-8", "replace"))
        return values, offset
    if type_id == 0x02:
        return [bool(value) for value in payload[offset : offset + count]], offset + count
    if type_id == 0x04:
        return decode_float_array(payload[offset : offset + 4 * count], count), offset + 4 * count
    if type_id == 0x05:
        values = list(struct.unpack_from(f"<{count}d", payload, offset))
        return values, offset + 8 * count
    if type_id == 0x0B:
        return deinterleaved_u32_be(payload[offset : offset + 4 * count], count), offset + 4 * count
    if type_id == 0x0C:
        return decode_vector3(payload, offset, count)
    if type_id == 0x0E:
        return decode_vector3(payload, offset, count)
    if type_id == 0x10:
        return decode_cframes(payload, offset, count)
    if type_id == 0x12:
        return deinterleaved_u32_be(payload[offset : offset + 4 * count], count), offset + 4 * count
    if type_id == 0x13:
        return decode_refs(payload, offset, count)
    if type_id == 0x17:
        return decode_number_ranges(payload, offset, count)
    if type_id == 0x1A:
        return decode_color3uint8(payload, offset, count)
    if type_id == 0x1C:
        indices = deinterleaved_u32_be(payload[offset : offset + 4 * count], count)
        offset += 4 * count
        values = [
            shared_strings[index].decode("utf-8", "replace")
            if 0 <= index < len(shared_strings)
            else f"<SSTR:{index}>"
            for index in indices
        ]
        return values, offset
    return None, offset


def parse_place(path: Path) -> dict[str, Any]:
    blob = path.read_bytes()
    if blob[:14] != RBXL_MAGIC:
        raise ValueError("not a Roblox binary place")
    version = struct.unpack_from("<H", blob, 14)[0]
    declared_classes, declared_instances = struct.unpack_from("<II", blob, 16)
    chunks = list(iter_chunks(blob))

    classes: dict[int, dict[str, Any]] = {}
    instances: dict[int, dict[str, Any]] = {}
    shared_strings: list[bytes] = []
    prop_chunks: list[bytes] = []
    parent_payload: bytes | None = None

    for signature, payload in chunks:
        if signature == b"INST":
            offset = 0
            class_id = i32le(payload, offset)
            offset += 4
            class_name_raw, offset = read_string(payload, offset)
            class_name = class_name_raw.decode("utf-8", "replace")
            has_service_markers = bool(payload[offset])
            offset += 1
            count = u32le(payload, offset)
            offset += 4
            ids, offset = decode_refs(payload, offset, count)
            if has_service_markers:
                offset += count
            classes[class_id] = {"name": class_name, "ids": ids, "count": count}
            for instance_id in ids:
                instances[instance_id] = {
                    "id": instance_id,
                    "class": class_name,
                    "class_id": class_id,
                    "properties": {},
                }
        elif signature == b"SSTR":
            offset = 4  # version
            count = u32le(payload, offset)
            offset += 4
            for _ in range(count):
                offset += 16  # MD5 hash
                value, offset = read_string(payload, offset)
                shared_strings.append(value)
        elif signature == b"PROP":
            prop_chunks.append(payload)
        elif signature == b"PRNT":
            parent_payload = payload

    unsupported = Counter()
    decoded_properties = Counter()
    for payload in prop_chunks:
        class_id = i32le(payload, 0)
        offset = 4
        property_raw, offset = read_string(payload, offset)
        property_name = property_raw.decode("utf-8", "replace")
        type_id = payload[offset]
        offset += 1
        class_info = classes.get(class_id)
        if class_info is None:
            continue
        class_name = class_info["name"]
        wants_name = property_name == "Name"
        if not wants_name and property_name not in PROPERTY_ALLOWLIST.get(class_name, set()):
            continue
        values, _ = decode_property_values(payload, offset, type_id, class_info["count"], shared_strings)
        if values is None:
            unsupported[(class_name, property_name, type_id)] += class_info["count"]
            continue
        decoded_properties[(class_name, property_name, type_id)] += class_info["count"]
        for instance_id, value in zip(class_info["ids"], values):
            instances[instance_id]["properties"][property_name] = value

    if parent_payload is None:
        raise ValueError("RBXL has no PRNT chunk")
    offset = 1
    count = u32le(parent_payload, offset)
    offset += 4
    children, offset = decode_refs(parent_payload, offset, count)
    parents, offset = decode_refs(parent_payload, offset, count)
    for child, parent in zip(children, parents):
        if child in instances:
            instances[child]["parent_id"] = parent

    def instance_name(instance_id: int) -> str:
        instance = instances[instance_id]
        name = instance["properties"].get("Name")
        return name if isinstance(name, str) and name else instance["class"]

    path_cache: dict[int, str] = {}

    def instance_path(instance_id: int) -> str:
        if instance_id in path_cache:
            return path_cache[instance_id]
        parts: list[str] = []
        seen: set[int] = set()
        current = instance_id
        while current in instances and current not in seen:
            seen.add(current)
            parts.append(instance_name(current))
            current = instances[current].get("parent_id", -1)
        value = "/".join(reversed(parts))
        path_cache[instance_id] = value
        return value

    rows = []
    for instance_id, instance in instances.items():
        path_value = instance_path(instance_id)
        if path_value != "Workspace" and not path_value.startswith("Workspace/"):
            continue
        if instance["class"] not in PROPERTY_ALLOWLIST:
            continue
        properties = dict(instance["properties"])
        properties.pop("Name", None)
        rows.append({
            "id": instance_id,
            "path": path_value,
            "class": instance["class"],
            "parent_id": instance.get("parent_id", -1),
            "properties": properties,
        })
    rows.sort(key=lambda row: (row["path"].count("/"), row["path"], row["id"]))

    return {
        "metadata": {
            "source_file": path.name,
            "source_bytes": len(blob),
            "source_sha256": hashlib.sha256(blob).hexdigest(),
            "rbxl_version": version,
            "declared_class_count": declared_classes,
            "declared_instance_count": declared_instances,
            "workspace_property_rows": len(rows),
            "decoded_property_kinds": [
                {
                    "class": key[0],
                    "property": key[1],
                    "type_id": key[2],
                    "type": TYPE_NAMES.get(key[2], hex(key[2])),
                    "values": value,
                }
                for key, value in sorted(decoded_properties.items())
            ],
            "unsupported_allowed_properties": [
                {
                    "class": key[0],
                    "property": key[1],
                    "type_id": key[2],
                    "type": TYPE_NAMES.get(key[2], hex(key[2])),
                    "values": value,
                }
                for key, value in sorted(unsupported.items())
            ],
        },
        "instances": rows,
    }


def nearly_equal(actual: float, expected: float, epsilon: float = 1e-5) -> bool:
    return math.isclose(actual, expected, abs_tol=epsilon, rel_tol=0.0)


def verify_vec(actual: Any, expected: list[float], label: str) -> None:
    if not isinstance(actual, list) or len(actual) != len(expected):
        raise AssertionError(f"{label}: invalid vector {actual!r}")
    for index, (left, right) in enumerate(zip(actual, expected)):
        if not nearly_equal(float(left), right):
            raise AssertionError(f"{label}[{index}]: expected {right}, got {left}")


def verify_bootstrap_fixtures(document: dict[str, Any]) -> None:
    by_path = {row["path"]: row for row in document["instances"]}
    floor = by_path.get("Workspace/BootstrapSafetyFloor")
    spawn = by_path.get("Workspace/BootstrapSafetySpawn")
    if floor is None or spawn is None:
        raise AssertionError("bootstrap fixture instances are missing")

    verify_vec(floor["properties"]["CFrame"]["position"], [-224.0, -3.0, -208.0], "floor position")
    verify_vec(floor["properties"]["size"], [48.0, 6.0, 48.0], "floor size")
    if floor["properties"].get("Anchored") is not True or floor["properties"].get("CanCollide") is not True:
        raise AssertionError("bootstrap floor anchoring/collision mismatch")

    verify_vec(spawn["properties"]["CFrame"]["position"], [-224.0, 0.5, -208.0], "spawn position")
    verify_vec(spawn["properties"]["size"], [12.0, 1.0, 12.0], "spawn size")
    if not nearly_equal(float(spawn["properties"].get("Transparency", -1)), 1.0):
        raise AssertionError("bootstrap spawn transparency mismatch")
    if spawn["properties"].get("Neutral") is not True:
        raise AssertionError("bootstrap spawn Neutral mismatch")


def encode_roblox_float(value: float) -> bytes:
    bits = int.from_bytes(struct.pack(">f", value), "big")
    transformed = ((bits << 1) & 0xFFFFFFFF) | (bits >> 31)
    return transformed.to_bytes(4, "big")


def interleave(values: list[bytes]) -> bytes:
    if not values:
        return b""
    width = len(values[0])
    return bytes(values[index][byte] for byte in range(width) for index in range(len(values)))


def run_self_test() -> None:
    samples = [-224.0, -3.0, -0.0, 0.0, 0.5, 1.0, 48.0, 1500.0]
    encoded = interleave([encode_roblox_float(value) for value in samples])
    decoded = decode_float_array(encoded, len(samples))
    for actual, expected in zip(decoded, samples):
        if not nearly_equal(actual, expected):
            raise AssertionError(f"float round trip failed: {expected} -> {actual}")

    x = interleave([encode_roblox_float(-224.0), encode_roblox_float(12.0)])
    y = interleave([encode_roblox_float(0.5), encode_roblox_float(1.0)])
    z = interleave([encode_roblox_float(-208.0), encode_roblox_float(12.0)])
    vectors, offset = decode_vector3(x + y + z, 0, 2)
    if offset != 24:
        raise AssertionError("vector decoder offset mismatch")
    verify_vec(vectors[0], [-224.0, 0.5, -208.0], "self-test vector 0")
    verify_vec(vectors[1], [12.0, 1.0, 12.0], "self-test vector 1")

    if ROTATION_MATRICES[0x02] != (1, 0, 0, 0, 1, 0, 0, 0, 1):
        raise AssertionError("identity CFrame rotation mapping is wrong")
    if len(ROTATION_MATRICES) != 24:
        raise AssertionError("expected 24 predefined CFrame rotations")
    print("[rbxl-properties] self-test OK")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("place", nargs="?", help="path to a binary .rbxl place")
    parser.add_argument("--out", default="rbxl-world-properties.json")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--verify-bootstrap-fixtures", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        if args.place is None:
            return 0
    if args.place is None:
        parser.error("place is required unless --self-test is used")

    document = parse_place(Path(args.place))
    if args.verify_bootstrap_fixtures:
        verify_bootstrap_fixtures(document)
        print("[rbxl-properties] bootstrap fixtures OK")
    Path(args.out).write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"[rbxl-properties] wrote {args.out}: "
        f"{document['metadata']['workspace_property_rows']} Workspace property rows"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
