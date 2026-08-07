from __future__ import annotations

import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import trimesh
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

OUT = Path(__file__).resolve().parent
OBJ_PATH = OUT / "blackwater_support_lmg.obj"
PREVIEW_PATH = OUT / "blackwater_support_lmg_preview.svg"


def transform(translation=(0.0, 0.0, 0.0), rotation_xyz=(0.0, 0.0, 0.0)) -> np.ndarray:
    matrix = trimesh.transformations.euler_matrix(*rotation_xyz, axes="sxyz")
    matrix[:3, 3] = np.asarray(translation, dtype=float)
    return matrix


def box(extents, translation, name, color, rotation_xyz=(0.0, 0.0, 0.0)):
    mesh = trimesh.creation.box(extents=extents)
    mesh.visual.face_colors = np.array(color, dtype=np.uint8)
    return name, mesh, transform(translation, rotation_xyz)


def cylinder(
    radius,
    height,
    translation,
    name,
    color,
    rotation_xyz=(0.0, math.pi / 2, 0.0),
    sections=16,
):
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
    link = [79, 75, 63, 255]
    warning = [192, 85, 38, 255]

    components = [
        box((0.52, 0.19, 0.23), (0.05, 0.0, 0.01), "Receiver", charcoal),
        box((0.36, 0.17, 0.05), (0.03, 0.0, 0.16), "FeedCover", dark),
        box((0.41, 0.16, 0.18), (0.50, 0.0, 0.01), "Handguard", olive_dark),
        box((0.34, 0.18, 0.04), (0.50, 0.0, 0.13), "HeatShield", dark),
        box((0.23, 0.13, 0.14), (-0.31, 0.0, 0.01), "StockCore", olive),
        wedge_like((0.28, 0.15, 0.24), (-0.51, 0.0, -0.01), "Buttstock", olive, shear=-0.06),
        cylinder(0.032, 0.50, (0.91, 0.0, 0.04), "Barrel", dark),
        cylinder(0.022, 0.38, (0.69, 0.0, -0.035), "GasTube", steel),
        cylinder(0.050, 0.13, (1.22, 0.0, 0.04), "MuzzleDevice", steel),
        wedge_like((0.105, 0.095, 0.26), (-0.03, 0.0, -0.225), "PistolGrip", rubber, shear=0.08),
        box((0.26, 0.16, 0.30), (0.14, 0.0, -0.275), "Magazine", olive),
        box((0.27, 0.17, 0.045), (0.14, 0.0, -0.105), "AmmoBoxLid", olive_dark),
        box((0.17, 0.015, 0.14), (0.14, -0.087, -0.275), "AmmoBoxPanel", olive_dark),
        box((0.045, 0.025, 0.06), (0.22, -0.097, -0.205), "AmmoBoxLatch", steel),
        box((0.19, 0.025, 0.065), (0.09, -0.112, 0.025), "Bolt", steel),
        box((0.41, 0.035, 0.028), (0.04, 0.0, 0.19), "TopRail", dark),
        box((0.075, 0.075, 0.10), (0.19, 0.0, 0.25), "RearSight", dark),
        box((0.06, 0.07, 0.13), (0.80, 0.0, 0.21), "FrontSight", dark),
        box((0.04, 0.05, 0.16), (0.25, 0.0, 0.30), "CarryHandleStem", steel, rotation_xyz=(0.0, -0.28, 0.0)),
        cylinder(0.025, 0.18, (0.33, 0.0, 0.37), "CarryHandle", rubber),
        cylinder(0.052, 0.036, (0.0, 0.0, -0.14), "TriggerGuardFront", dark, rotation_xyz=(math.pi / 2, 0.0, 0.0), sections=12),
        box((0.025, 0.02, 0.08), (0.0, 0.0, -0.13), "Trigger", brass),
        box((0.055, 0.038, 0.038), (-0.39, 0.0, 0.11), "StockLatch", steel),
        box((0.065, 0.04, 0.055), (0.59, 0.0, -0.09), "HandStop", rubber),
        box((0.048, 0.024, 0.11), (0.39, 0.092, 0.01), "WarningStripe", warning),
        cylinder(0.025, 0.038, (-0.59, 0.0, -0.09), "RearSlingMount", steel, rotation_xyz=(math.pi / 2, 0.0, 0.0), sections=12),
        cylinder(0.023, 0.038, (0.64, 0.0, -0.065), "FrontSlingMount", steel, rotation_xyz=(math.pi / 2, 0.0, 0.0), sections=12),
        box((0.08, 0.115, 0.06), (0.74, 0.0, -0.07), "BipodHinge", steel),
        box((0.24, 0.035, 0.035), (0.78, 0.085, -0.19), "BipodLeftLeg", dark, rotation_xyz=(0.0, -1.08, 0.07)),
        box((0.24, 0.035, 0.035), (0.78, -0.085, -0.19), "BipodRightLeg", dark, rotation_xyz=(0.0, -1.08, -0.07)),
        box((0.07, 0.055, 0.028), (0.68, 0.095, -0.29), "BipodLeftFoot", rubber),
        box((0.07, 0.055, 0.028), (0.68, -0.095, -0.29), "BipodRightFoot", rubber),
        box((0.19, 0.03, 0.045), (0.10, -0.11, -0.055), "FeedTray", steel),
    ]

    for index in range(6):
        x = 0.025 + index * 0.038
        z = -0.085 - index * 0.017
        components.append(cylinder(0.012, 0.052, (x, -0.125, z), f"BeltRound{index + 1:02d}", brass))
        components.append(box((0.019, 0.030, 0.036), (x, -0.125, z), f"BeltLink{index + 1:02d}", link))

    for name, mesh, matrix in components:
        scene.add_geometry(mesh, node_name=name, geom_name=name, parent_node_name="WeaponRoot", transform=matrix)
    return scene


def render_preview(scene: trimesh.Scene) -> None:
    combined = scene.to_geometry()
    figure = plt.figure(figsize=(13, 7))
    axis = figure.add_subplot(111, projection="3d")
    polygons = combined.vertices[combined.faces]
    colors = combined.visual.face_colors / 255.0
    axis.add_collection3d(
        Poly3DCollection(
            polygons,
            facecolors=colors,
            linewidths=0.08,
            edgecolors=(0.1, 0.1, 0.1, 0.35),
        )
    )
    bounds = combined.bounds
    extents = bounds[1] - bounds[0]
    padding = np.maximum(extents * 0.12, np.array([0.04, 0.04, 0.04]))
    axis.set_xlim(bounds[0, 0] - padding[0], bounds[1, 0] + padding[0])
    axis.set_ylim(bounds[0, 1] - padding[1], bounds[1, 1] + padding[1])
    axis.set_zlim(bounds[0, 2] - padding[2], bounds[1, 2] + padding[2])
    axis.set_box_aspect(extents + padding * 2.0)
    axis.view_init(elev=18, azim=-58)
    axis.set_axis_off()
    axis.set_title("Blackwater Support LMG — Living Kingdoms Source Candidate", pad=18)
    figure.tight_layout()
    figure.savefig(PREVIEW_PATH, bbox_inches="tight")
    plt.close(figure)


def main() -> None:
    scene = build_scene()
    OBJ_PATH.write_text(scene.export(file_type="obj"), encoding="utf-8")
    render_preview(scene)
    source = OBJ_PATH.read_text(encoding="utf-8")
    for required in (
        "o Receiver",
        "o FeedCover",
        "o Magazine",
        "o Bolt",
        "o MuzzleDevice",
        "o BipodLeftLeg",
        "o BeltRound01",
    ):
        if required not in source:
            raise RuntimeError(f"generated model missing {required}")
    print(f"wrote {OBJ_PATH} ({OBJ_PATH.stat().st_size} bytes)")
    print(f"wrote {PREVIEW_PATH} ({PREVIEW_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
