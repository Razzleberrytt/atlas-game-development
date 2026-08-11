from __future__ import annotations

from pathlib import Path

OUT = Path(__file__).resolve().parent
OBJ_PATH = OUT / "morrow_breach_shotgun.obj"


def box(name: str, center: tuple[float, float, float], size: tuple[float, float, float], start: int):
    cx, cy, cz = center
    sx, sy, sz = (value / 2.0 for value in size)
    vertices = [
        (cx - sx, cy - sy, cz - sz), (cx + sx, cy - sy, cz - sz),
        (cx + sx, cy + sy, cz - sz), (cx - sx, cy + sy, cz - sz),
        (cx - sx, cy - sy, cz + sz), (cx + sx, cy - sy, cz + sz),
        (cx + sx, cy + sy, cz + sz), (cx - sx, cy + sy, cz + sz),
    ]
    faces = [(1,2,3,4),(5,8,7,6),(1,5,6,2),(2,6,7,3),(3,7,8,4),(5,1,4,8)]
    lines = [f"o {name}"]
    lines.extend(f"v {x:.5f} {y:.5f} {z:.5f}" for x, y, z in vertices)
    lines.extend("f " + " ".join(str(start + index - 1) for index in face) for face in faces)
    return lines, start + 8


def build() -> str:
    components = [
        ("Receiver", (0.05,0.0,0.04), (1.42,0.62,0.66)),
        ("ReceiverTop", (0.12,0.0,0.46), (1.15,0.54,0.16)),
        ("EjectionHousing", (0.18,-0.36,0.17), (0.56,0.10,0.30)),
        ("Handguard", (1.33,0.0,0.01), (1.18,0.55,0.54)),
        ("HeatShield", (1.62,0.0,0.47), (1.52,0.58,0.12)),
        ("HeatVent01", (1.31,0.0,0.545), (0.16,0.61,0.045)),
        ("HeatVent02", (1.54,0.0,0.545), (0.16,0.61,0.045)),
        ("HeatVent03", (1.77,0.0,0.545), (0.16,0.61,0.045)),
        ("HeatVent04", (2.00,0.0,0.545), (0.16,0.61,0.045)),
        ("HeatVent05", (2.23,0.0,0.545), (0.16,0.61,0.045)),
        ("Barrel", (2.42,0.0,0.19), (2.18,0.22,0.22)),
        ("MagazineTube", (2.17,0.0,-0.16), (1.76,0.20,0.20)),
        ("MuzzleCollar", (3.66,0.0,0.19), (0.34,0.34,0.34)),
        ("StockNeck", (-0.89,0.0,0.02), (0.64,0.40,0.40)),
        ("StockBody", (-1.55,0.0,0.01), (1.12,0.58,0.76)),
        ("ButtPad", (-2.14,0.0,-0.01), (0.18,0.64,0.78)),
        ("PistolGrip", (-0.30,0.0,-0.69), (0.34,0.31,0.78)),
        ("Magazine", (0.40,0.0,-0.88), (0.54,0.46,0.92)),
        ("MagazineFrontRib", (0.67,0.0,-0.88), (0.10,0.49,0.72)),
        ("MagazineBase", (0.40,0.0,-1.40), (0.64,0.50,0.14)),
        ("Bolt", (0.18,-0.37,0.17), (0.58,0.09,0.24)),
        ("ChargingHandle", (0.28,-0.52,0.17), (0.18,0.25,0.12)),
        ("Pump", (1.50,0.0,-0.02), (0.78,0.61,0.52)),
        ("TopRail", (0.22,0.0,0.61), (1.18,0.12,0.09)),
        ("SideLight", (1.74,0.38,-0.08), (0.62,0.23,0.23)),
        ("ShellRack", (-0.05,0.38,0.06), (0.78,0.10,0.35)),
        ("RackShell01", (-0.15,0.44,0.08), (0.30,0.12,0.12)),
        ("RackShell02", (0.01,0.44,0.08), (0.30,0.12,0.12)),
        ("RackShell03", (0.17,0.44,0.08), (0.30,0.12,0.12)),
        ("RackShell04", (0.33,0.44,0.08), (0.30,0.12,0.12)),
    ]
    lines = ["# Living Kingdoms Morrow Breach Shotgun source candidate"]
    index = 1
    for name, center, size in components:
        chunk, index = box(name, center, size, index)
        lines.extend(chunk)
    return "\n".join(lines) + "\n"


def main() -> None:
    source = build()
    OBJ_PATH.write_text(source, encoding="utf-8")
    for required in ("o Receiver", "o HeatShield", "o Pump", "o Magazine", "o Bolt", "o ShellRack", "o SideLight"):
        if required not in source:
            raise RuntimeError(f"generated model missing {required}")
    print(f"wrote {OBJ_PATH} ({OBJ_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
