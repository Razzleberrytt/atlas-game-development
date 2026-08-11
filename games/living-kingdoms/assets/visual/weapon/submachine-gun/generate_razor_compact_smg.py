from __future__ import annotations

from pathlib import Path

OUT = Path(__file__).resolve().parent
OBJ_PATH = OUT / "razor_compact_smg.obj"

COMPONENTS = [
    ("Receiver", (1.12, 0.56, 0.58), (0.08, 0.0, 0.05)),
    ("UpperReceiver", (1.00, 0.50, 0.16), (0.10, 0.0, 0.43)),
    ("LowerReceiver", (0.78, 0.50, 0.24), (-0.02, 0.0, -0.33)),
    ("Handguard", (0.82, 0.59, 0.54), (0.98, 0.0, 0.03)),
    ("Barrel", (0.84, 0.16, 0.16), (1.69, 0.0, 0.13)),
    ("BarrelShroud", (0.62, 0.34, 0.34), (1.52, 0.0, 0.13)),
    ("MuzzleDevice", (0.30, 0.31, 0.31), (2.23, 0.0, 0.13)),
    ("PistolGrip", (0.36, 0.32, 0.78), (-0.29, 0.0, -0.68)),
    ("GripAccent", (0.22, 0.34, 0.36), (-0.31, 0.0, -0.76)),
    ("StockHinge", (0.26, 0.44, 0.42), (-0.66, 0.0, 0.03)),
    ("StockTopRail", (1.02, 0.10, 0.10), (-1.18, 0.18, 0.20)),
    ("StockBottomRail", (1.02, 0.10, 0.10), (-1.18, -0.18, -0.14)),
    ("StockBrace", (0.12, 0.42, 0.54), (-1.70, 0.0, 0.02)),
    ("StockPad", (0.18, 0.48, 0.64), (-1.82, 0.0, 0.02)),
    ("Magazine", (0.38, 0.34, 0.72), (0.20, 0.0, -0.78)),
    ("MagazineLower", (0.34, 0.32, 0.58), (0.10, 0.0, -1.34)),
    ("MagazineFoot", (0.46, 0.38, 0.14), (0.02, 0.0, -1.70)),
    ("Bolt", (0.52, 0.09, 0.20), (0.16, -0.34, 0.15)),
    ("TopRail", (1.28, 0.12, 0.09), (0.28, 0.0, 0.61)),
    ("ReflexBody", (0.42, 0.38, 0.34), (0.20, 0.0, 0.94)),
    ("ReflexWindow", (0.08, 0.30, 0.26), (0.43, 0.0, 0.96)),
    ("VerticalForegrip", (0.28, 0.28, 0.66), (0.99, 0.0, -0.53)),
    ("ForegripStop", (0.36, 0.34, 0.15), (0.99, 0.0, -0.88)),
    ("IdentityPanel", (0.45, 0.025, 0.28), (0.02, -0.292, 0.07)),
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
    lines = ["# Living Kingdoms - Razor Compact SMG v2", "# Project-original presentation-only source candidate"]
    base = 1
    for name, size, center in COMPONENTS:
        base = emit_box(lines, name, size, center, base)
    return "\n".join(lines) + "\n"


def main() -> None:
    source = build_obj()
    for required in ("o Receiver", "o BarrelShroud", "o Magazine", "o Bolt", "o ReflexBody", "o VerticalForegrip"):
        if required not in source:
            raise RuntimeError(f"generated model missing {required}")
    if len(COMPONENTS) < 22:
        raise RuntimeError("Razor source candidate lost required silhouette complexity")
    OBJ_PATH.write_text(source, encoding="utf-8")
    print(f"wrote {OBJ_PATH} ({OBJ_PATH.stat().st_size} bytes, {len(COMPONENTS)} components)")


if __name__ == "__main__":
    main()
