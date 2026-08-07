from __future__ import annotations

import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import trimesh
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

OUT = Path(__file__).resolve().parent
OBJ_PATH = OUT / "exclusion_walker.obj"
PREVIEW_PATH = OUT / "exclusion_walker_preview.svg"


def transform(translation=(0.0, 0.0, 0.0), rotation_xyz=(0.0, 0.0, 0.0)) -> np.ndarray:
    matrix = trimesh.transformations.euler_matrix(*rotation_xyz, axes="sxyz")
    matrix[:3, 3] = np.asarray(translation, dtype=float)
    return matrix


def box(extents, translation, name, color, rotation_xyz=(0.0, 0.0, 0.0)):
    mesh = trimesh.creation.box(extents=extents)
    mesh.visual.face_colors = np.array(color, dtype=np.uint8)
    return name, mesh, transform(translation, rotation_xyz)


def cylinder(radius, height, translation, name, color, rotation_xyz=(0.0, 0.0, 0.0), sections=12):
    mesh = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    mesh.visual.face_colors = np.array(color, dtype=np.uint8)
    return name, mesh, transform(translation, rotation_xyz)


def build_scene() -> trimesh.Scene:
    scene = trimesh.Scene(base_frame="HumanoidRootPart")
    bone = [113, 119, 113, 255]
    armor = [58, 65, 62, 255]
    armor_dark = [30, 35, 34, 255]
    flesh = [104, 45, 48, 255]
    claw = [132, 128, 110, 255]
    sensor = [218, 78, 53, 255]
    canister = [75, 87, 68, 255]

    components = [
        box((1.75, 1.15, 2.20), (0.0, 0.0, 0.35), "TorsoCore", flesh),
        box((2.25, 1.30, 0.42), (0.0, 0.0, 0.95), "RibCage", armor),
        box((1.55, 1.05, 0.50), (0.0, 0.0, 1.42), "ChestPlate", armor_dark),
        box((0.95, 0.90, 0.62), (0.0, -0.10, 2.05), "Head", bone),
        box((0.56, 0.30, 0.18), (0.0, -0.50, 2.10), "Sensor", sensor),
        cylinder(
            0.18,
            1.05,
            (0.0, 0.25, 1.95),
            "DorsalSpine",
            claw,
            rotation_xyz=(math.pi / 2, 0.0, 0.0),
        ),
        box((0.65, 0.80, 0.65), (-1.35, 0.0, 1.02), "ShoulderLeft", armor),
        box((0.65, 0.80, 0.65), (1.35, 0.0, 1.02), "ShoulderRight", armor),
        box(
            (0.46, 0.50, 1.55),
            (-1.45, 0.0, 0.05),
            "ForearmLeft",
            bone,
            rotation_xyz=(0.0, -0.16, 0.12),
        ),
        box(
            (0.46, 0.50, 1.55),
            (1.45, 0.0, 0.05),
            "ForearmRight",
            bone,
            rotation_xyz=(0.0, 0.16, -0.12),
        ),
        box(
            (0.34, 0.32, 0.78),
            (-1.55, -0.12, -0.95),
            "ClawLeft",
            claw,
            rotation_xyz=(0.20, 0.0, 0.10),
        ),
        box(
            (0.34, 0.32, 0.78),
            (1.55, -0.12, -0.95),
            "ClawRight",
            claw,
            rotation_xyz=(0.20, 0.0, -0.10),
        ),
        box((1.35, 0.92, 0.52), (0.0, 0.0, -0.95), "HipGuard", armor_dark),
        box(
            (0.55, 0.68, 1.65),
            (-0.52, 0.05, -2.00),
            "LegLeft",
            bone,
            rotation_xyz=(0.0, 0.08, 0.03),
        ),
        box(
            (0.55, 0.68, 1.65),
            (0.52, 0.05, -2.00),
            "LegRight",
            bone,
            rotation_xyz=(0.0, -0.08, -0.03),
        ),
        box((0.70, 1.25, 0.34), (-0.52, -0.28, -3.00), "FootLeft", armor),
        box((0.70, 1.25, 0.34), (0.52, -0.28, -3.00), "FootRight", armor),
        cylinder(
            0.32,
            0.95,
            (0.0, 0.72, 0.28),
            "BackCanister",
            canister,
            rotation_xyz=(math.pi / 2, 0.0, 0.0),
        ),
    ]

    for name, mesh, matrix in components:
        scene.add_geometry(mesh, node_name=name, geom_name=name, parent_node_name="HumanoidRootPart", transform=matrix)
    return scene


def render_preview(scene: trimesh.Scene) -> None:
    combined = scene.to_geometry()
    figure = plt.figure(figsize=(8, 10))
    axis = figure.add_subplot(111, projection="3d")
    polygons = combined.vertices[combined.faces]
    colors = combined.visual.face_colors / 255.0
    axis.add_collection3d(
        Poly3DCollection(
            polygons,
            facecolors=colors,
            linewidths=0.08,
            edgecolors=(0.08, 0.08, 0.08, 0.38),
        )
    )
    bounds = combined.bounds
    extents = bounds[1] - bounds[0]
    padding = np.maximum(extents * 0.12, np.array([0.05, 0.05, 0.05]))
    axis.set_xlim(bounds[0, 0] - padding[0], bounds[1, 0] + padding[0])
    axis.set_ylim(bounds[0, 1] - padding[1], bounds[1, 1] + padding[1])
    axis.set_zlim(bounds[0, 2] - padding[2], bounds[1, 2] + padding[2])
    axis.set_box_aspect(extents + padding * 2.0)
    axis.view_init(elev=18, azim=-52)
    axis.set_axis_off()
    axis.set_title("Exclusion Walker — Living Kingdoms Source Candidate", pad=18)
    figure.tight_layout()
    figure.savefig(PREVIEW_PATH, bbox_inches="tight")
    plt.close(figure)


def main() -> None:
    scene = build_scene()
    OBJ_PATH.write_text(scene.export(file_type="obj"), encoding="utf-8")
    render_preview(scene)
    source = OBJ_PATH.read_text(encoding="utf-8")
    for required in (
        "o TorsoCore",
        "o Head",
        "o Sensor",
        "o ForearmLeft",
        "o ClawRight",
        "o LegLeft",
        "o BackCanister",
    ):
        if required not in source:
            raise RuntimeError(f"generated model missing {required}")
    print(f"wrote {OBJ_PATH} ({OBJ_PATH.stat().st_size} bytes)")
    print(f"wrote {PREVIEW_PATH} ({PREVIEW_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
