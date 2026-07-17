from __future__ import annotations

import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import trimesh
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

OUT = Path(__file__).resolve().parent
OBJ_PATH = OUT / "blackwater_service_carbine.obj"
PREVIEW_PATH = OUT / "blackwater_service_carbine_preview.svg"


def transform(translation=(0.0, 0.0, 0.0), rotation_xyz=(0.0, 0.0, 0.0)) -> np.ndarray:
    matrix = trimesh.transformations.euler_matrix(*rotation_xyz, axes="sxyz")
    matrix[:3, 3] = np.asarray(translation, dtype=float)
    return matrix


def box(extents, translation, name, color):
    mesh = trimesh.creation.box(extents=extents)
    mesh.visual.face_colors = np.array(color, dtype=np.uint8)
    return name, mesh, transform(translation)


def cylinder(radius, height, translation, name, color, rotation_xyz=(0.0, math.pi / 2, 0.0), sections=16):
    mesh = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    mesh.visual.face_colors = np.array(color, dtype=np.uint8)
    return name, mesh, transform(translation, rotation_xyz)


def wedge_like(extents, translation, name, color, shear=0.25):
    mesh = trimesh.creation.box(extents=extents)
    vertices = mesh.vertices.copy()
    minimum_x = vertices[:, 0].min()
    ratio = (vertices[:, 0] - minimum_x) / (vertices[:, 0].max() - minimum_x)
    vertices[:, 2] += (ratio - 0.5) * shear
    mesh.vertices = vertices
    mesh.visual.face_colors = np.array(color, dtype=np.uint8)
    return name, mesh, transform(translation)


def build_scene() -> trimesh.Scene:
    scene = trimesh.Scene(base_frame="WeaponRoot")
    charcoal = [44, 48, 49, 255]
    dark = [29, 32, 33, 255]
    olive = [85, 91, 65, 255]
    olive_dark = [62, 67, 49, 255]
    rubber = [34, 35, 32, 255]
    steel = [93, 98, 96, 255]
    brass = [154, 119, 50, 255]
    warning = [192, 85, 38, 255]

    components = [
        box((0.42, 0.16, 0.20), (0.05, 0.0, 0.0), "Receiver", charcoal),
        box((0.38, 0.14, 0.16), (0.43, 0.0, 0.01), "Handguard", olive_dark),
        box((0.26, 0.12, 0.13), (-0.28, 0.0, 0.015), "StockCore", olive),
        wedge_like((0.22, 0.14, 0.22), (-0.47, 0.0, 0.005), "Buttstock", olive, shear=-0.07),
        cylinder(0.038, 0.43, (0.76, 0.0, 0.03), "Barrel", dark),
        cylinder(0.052, 0.10, (1.025, 0.0, 0.03), "MuzzleDevice", steel),
        wedge_like((0.10, 0.09, 0.24), (-0.02, 0.0, -0.20), "PistolGrip", rubber, shear=0.08),
        wedge_like((0.17, 0.105, 0.26), (0.19, 0.0, -0.23), "Magazine", olive, shear=-0.08),
        box((0.17, 0.025, 0.06), (0.07, -0.095, 0.02), "Bolt", steel),
        box((0.31, 0.03, 0.025), (0.07, 0.0, 0.125), "TopRail", dark),
        box((0.07, 0.07, 0.095), (0.21, 0.0, 0.19), "RearSight", dark),
        box((0.055, 0.065, 0.11), (0.72, 0.0, 0.16), "FrontSight", dark),
        cylinder(0.052, 0.035, (0.02, 0.0, -0.13), "TriggerGuardFront", dark, rotation_xyz=(math.pi / 2, 0.0, 0.0), sections=12),
        box((0.025, 0.02, 0.08), (0.02, 0.0, -0.12), "Trigger", brass),
        box((0.05, 0.035, 0.035), (-0.37, 0.0, 0.10), "StockLatch", steel),
        box((0.06, 0.035, 0.035), (0.55, 0.0, -0.075), "HandStop", rubber),
        box((0.04, 0.022, 0.10), (0.40, 0.081, 0.015), "WarningStripe", warning),
        cylinder(0.024, 0.035, (-0.53, 0.0, -0.08), "RearSlingMount", steel, rotation_xyz=(math.pi / 2, 0.0, 0.0), sections=12),
        cylinder(0.022, 0.035, (0.59, 0.0, -0.06), "FrontSlingMount", steel, rotation_xyz=(math.pi / 2, 0.0, 0.0), sections=12),
    ]
    for name, mesh, matrix in components:
        scene.add_geometry(mesh, node_name=name, geom_name=name, parent_node_name="WeaponRoot", transform=matrix)
    return scene


def render_preview(scene: trimesh.Scene) -> None:
    combined = scene.to_geometry()
    figure = plt.figure(figsize=(12, 7))
    axis = figure.add_subplot(111, projection="3d")
    polygons = combined.vertices[combined.faces]
    colors = combined.visual.face_colors / 255.0
    axis.add_collection3d(Poly3DCollection(polygons, facecolors=colors, linewidths=0.08, edgecolors=(0.1, 0.1, 0.1, 0.35)))
    bounds = combined.bounds
    center = bounds.mean(axis=0)
    span = (bounds[1] - bounds[0]).max()
    for setter, coordinate in [(axis.set_xlim, center[0]), (axis.set_ylim, center[1]), (axis.set_zlim, center[2])]:
        setter(coordinate - span * 0.58, coordinate + span * 0.58)
    axis.view_init(elev=18, azim=-58)
    axis.set_axis_off()
    axis.set_title("Blackwater Service Carbine — VIS-0102 Source Candidate", pad=18)
    figure.tight_layout()
    figure.savefig(PREVIEW_PATH, bbox_inches="tight")
    plt.close(figure)


def main() -> None:
    scene = build_scene()
    OBJ_PATH.write_text(scene.export(file_type="obj"), encoding="utf-8")
    render_preview(scene)
    source = OBJ_PATH.read_text(encoding="utf-8")
    for required in ("o Receiver", "o Magazine", "o Bolt", "o MuzzleDevice", "o PistolGrip"):
        if required not in source:
            raise RuntimeError(f"generated model missing {required}")
    print(f"wrote {OBJ_PATH} ({OBJ_PATH.stat().st_size} bytes)")
    print(f"wrote {PREVIEW_PATH} ({PREVIEW_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
