from __future__ import annotations

from pathlib import Path

OUT = Path(__file__).resolve().parent
OBJ_PATH = OUT / "longwatch_sniper_rifle.obj"

COMPONENTS = [
    ("Receiver", (1.44, 0.54, 0.60), (0.08, 0.0, 0.05)),
    ("ReceiverCrown", (1.12, 0.47, 0.14), (0.10, 0.0, 0.43)),
    ("FreeFloatHandguard", (1.72, 0.48, 0.48), (1.58, 0.0, 0.05)),
    ("HeavyBarrel", (3.05, 0.18, 0.18), (3.62, 0.0, 0.14)),
    ("BarrelCollar", (0.34, 0.31, 0.31), (2.12, 0.0, 0.14)),
    ("MuzzleBrakeCore", (0.52, 0.34, 0.34), (5.40, 0.0, 0.14)),
    ("StockSpine", (1.12, 0.38, 0.36), (-1.02, 0.0, 0.09)),
    ("PrecisionStock", (1.18, 0.58, 0.82), (-1.70, 0.0, -0.02)),
    ("ButtPad", (0.18, 0.62, 0.84), (-2.34, 0.0, -0.03)),
    ("CheekRest", (0.82, 0.46, 0.18), (-1.49, 0.0, 0.52)),
    ("PistolGrip", (0.34, 0.31, 0.80), (-0.36, 0.0, -0.68)),
    ("Trigger", (0.08, 0.06, 0.25), (-0.02, 0.0, -0.40)),
    ("Magazine", (0.48, 0.38, 0.80), (0.35, 0.0, -0.76)),
    ("MagazineBase", (0.58, 0.42, 0.14), (0.35, 0.0, -1.22)),
    ("Bolt", (0.66, 0.10, 0.22), (0.15, -0.35, 0.15)),
    ("BoltHandleStem", (0.13, 0.40, 0.13), (0.29, -0.57, 0.13)),
    ("TopRail", (1.76, 0.12, 0.09), (0.32, 0.0, 0.62)),
    ("ScopeTube", (1.72, 0.28, 0.28), (0.28, 0.0, 0.97)),
    ("ScopeObjective", (0.38, 0.48, 0.48), (1.28, 0.0, 0.97)),
    ("ScopeEyepiece", (0.34, 0.39, 0.39), (-0.70, 0.0, 0.97)),
    ("ObjectiveLens", (0.06, 0.42, 0.42), (1.50, 0.0, 0.97)),
    ("BipodHinge", (0.26, 0.34, 0.20), (2.02, 0.0, -0.24)),
    ("BipodLeftLeg", (0.90, 0.10, 0.10), (2.13, 0.30, -0.62)),
    ("BipodRightLeg", (0.90, 0.10, 0.10), (2.13, -0.30, -0.62)),
    ("RangeAccent", (0.20, 0.07, 0.34), (1.02, 0.275, 0.02)),
]


def emit_box(lines: list[str], name: str, size: tuple[float, float, float], center: tuple[float, float, float], base: int) -> int:
    sx, sy, sz = (value / 2.0 for value in size)
    cx, cy, cz = center
    vertices = [
        (cx - sx, cy - sy, cz - sz), (cx + sx, cy - sy, cz - sz),
        (cx + sx, cy + sy, cz - sz), (cx - sx, cy + sy, cz - sz),
        (cx - sx, cy - sy, cz + sz), (cx + sx, cy - sy, cz + sz),
        (cx + sx, cy + sy, cz + sz), (cx - sx, cy + sy, cz + sz),
    ]
    lines.append(f"o {name}")
    lines.extend(f"v {x:.6f} {y:.6f} {z:.6f}" for x, y, z in vertices)
    for face in ((1, 2, 3, 4), (5, 8, 7, 6), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 8, 4), (5, 1, 4, 8)):
        lines.append("f " + " ".join(str(base + index - 1) for index in face))
    return base + 8


def build_obj() -> str:
    lines = ["# Living Kingdoms - Longwatch Sniper Rifle v2", "# Project-original presentation-only source candidate"]
    base = 1
    for name, size, center in COMPONENTS:
        base = emit_box(lines, name, size, center, base)
    return "\n".join(lines) + "\n"


def main() -> None:
    source = build_obj()
    for required in ("o Receiver", "o HeavyBarrel", "o ScopeTube", "o Magazine", "o Bolt", "o BipodLeftLeg"):
        if required not in source:
            raise RuntimeError(f"generated model missing {required}")
    if len(COMPONENTS) < 24:
        raise RuntimeError("Longwatch source candidate lost required silhouette complexity")
    OBJ_PATH.write_text(source, encoding="utf-8")
    print(f"wrote {OBJ_PATH} ({OBJ_PATH.stat().st_size} bytes, {len(COMPONENTS)} components)")


if __name__ == "__main__":
    main()
