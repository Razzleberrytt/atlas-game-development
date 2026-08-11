from __future__ import annotations

from pathlib import Path

OUT = Path(__file__).resolve().parent
OBJ_PATH = OUT / "vigil_service_pistol.obj"

COMPONENTS = [
    ("Frame", (0.92, 0.38, 0.44), (0.04, 0.0, -0.02)),
    ("DustCover", (0.52, 0.40, 0.24), (0.50, 0.0, -0.22)),
    ("AccessoryRail", (0.45, 0.42, 0.08), (0.48, 0.0, -0.39)),
    ("GripCore", (0.46, 0.40, 0.92), (-0.30, 0.0, -0.67)),
    ("Backstrap", (0.17, 0.42, 0.74), (-0.54, 0.0, -0.67)),
    ("Frontstrap", (0.13, 0.42, 0.64), (-0.08, 0.0, -0.69)),
    ("Trigger", (0.08, 0.07, 0.28), (0.10, 0.0, -0.35)),
    ("SlideStop", (0.20, 0.07, 0.10), (-0.12, -0.23, 0.08)),
    ("TakeDownLever", (0.15, 0.08, 0.10), (0.25, -0.23, -0.02)),
    ("Bolt", (1.24, 0.42, 0.42), (0.12, 0.0, 0.32)),
    ("SlideTop", (1.05, 0.34, 0.10), (0.12, 0.0, 0.57)),
    ("BarrelHood", (0.34, 0.31, 0.12), (0.24, 0.0, 0.57)),
    ("Barrel", (0.92, 0.14, 0.14), (0.42, 0.0, 0.29)),
    ("MuzzleCrown", (0.11, 0.25, 0.25), (0.80, 0.0, 0.29)),
    ("RearSight", (0.18, 0.28, 0.22), (-0.33, 0.0, 0.67)),
    ("FrontSight", (0.12, 0.19, 0.20), (0.62, 0.0, 0.67)),
    ("Magazine", (0.32, 0.30, 0.76), (-0.30, 0.0, -0.72)),
    ("MagazineBase", (0.48, 0.43, 0.13), (-0.30, 0.0, -1.16)),
    ("WeaponLightBody", (0.46, 0.34, 0.26), (0.46, 0.0, -0.55)),
    ("WeaponLightLens", (0.09, 0.28, 0.28), (0.74, 0.0, -0.55)),
    ("WeaponLightSwitch", (0.10, 0.38, 0.12), (0.20, 0.0, -0.48)),
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
    faces = ((1, 2, 3, 4), (5, 8, 7, 6), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 8, 4), (5, 1, 4, 8))
    for face in faces:
        lines.append("f " + " ".join(str(base + index - 1) for index in face))
    return base + 8


def build_obj() -> str:
    lines = ["# Living Kingdoms - Vigil Service Pistol v2", "# Project-original presentation-only source candidate"]
    base = 1
    for name, size, center in COMPONENTS:
        base = emit_box(lines, name, size, center, base)
    return "\n".join(lines) + "\n"


def main() -> None:
    source = build_obj()
    for required in ("o Frame", "o Bolt", "o Magazine", "o WeaponLightBody", "o FrontSight"):
        if required not in source:
            raise RuntimeError(f"generated model missing {required}")
    if len(COMPONENTS) < 20:
        raise RuntimeError("Vigil source candidate lost required silhouette complexity")
    OBJ_PATH.write_text(source, encoding="utf-8")
    print(f"wrote {OBJ_PATH} ({OBJ_PATH.stat().st_size} bytes, {len(COMPONENTS)} components)")


if __name__ == "__main__":
    main()
