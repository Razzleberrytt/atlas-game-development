#!/usr/bin/env python3
"""Fail validation when the dedicated Main World becomes physically disconnected.

The recovered Studio snapshot intentionally preserves authored positions, including
lower-world props imported without their original terrain. Repo-owned traversal
repair slices are therefore part of the playable-world contract: they must form
one connected walkable support graph from the lower hub, support the preserved
primary route, and physically underlay every ground-bearing piece in the recovered
lower-world groups.

This validator is geometric rather than screenshot-based so a future snapshot
refresh cannot silently recreate unreachable "islands" while still producing a
syntactically valid Rojo build.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games" / "living-kingdoms"
PROJECT = GAME / "main-world.project.json"

TRAVERSAL_MOUNTS = ("TraversalRepair", "OuterTraversalRepair")
ROOT_SURFACE = "main_world.traversal.lower_continent"
MAX_STEP_DELTA = 2.05
RECT_EPSILON = 0.25
SUPPORT_VERTICAL_TOLERANCE = 4.0
GROUND_BEARING_MAX_CENTER_Y = 20.0

# These recovered groups belong to the lower playable world rather than the
# elevated civic presentation layer. Every BasePart in them whose bottom is
# close enough to ground level must sit over reachable repo-owned support.
LOWER_WORLD_GROUPS = (
    "Dark",
    "Village",
    "Crystal",
    "Beach",
    "Volcanic",
    "Desert",
    "Swamp",
    "Snow",
    "Jungle",
    "Autumn",
    "Sky",
    "Meadow",
    "Mushroom",
    "Ruins",
    "Ocean",
    "Ice",
    "Bamboo",
    "Geyser",
    "Lavender",
    "Cherry",
    "Tundra",
    "Canyon",
    "Coral",
    "Geothermal",
    "Oasis",
    "CrystalDesert",
)


@dataclass(frozen=True)
class Surface:
    name: str
    x: float
    top: float
    z: float
    size_x: float
    size_z: float

    @property
    def min_x(self) -> float:
        return self.x - self.size_x / 2

    @property
    def max_x(self) -> float:
        return self.x + self.size_x / 2

    @property
    def min_z(self) -> float:
        return self.z - self.size_z / 2

    @property
    def max_z(self) -> float:
        return self.z + self.size_z / 2


@dataclass(frozen=True)
class Anchor:
    group: str
    name: str
    x: float
    bottom: float
    z: float


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise RuntimeError(f"required Main World topology source is missing: {path.relative_to(ROOT)}")
    return json.loads(path.read_text(encoding="utf-8"))


def iter_instances(node: Any) -> Iterator[dict[str, Any]]:
    if not isinstance(node, dict):
        return
    yield node
    for child in node.get("Children", []):
        yield from iter_instances(child)


def part_geometry(instance: dict[str, Any]) -> tuple[float, float, float, float, float, float] | None:
    if instance.get("ClassName") not in {"Part", "MeshPart", "SpawnLocation"}:
        return None
    props = instance.get("Properties", {})
    cframe = props.get("CFrame")
    size = props.get("Size")
    if not isinstance(cframe, list) or len(cframe) < 3:
        return None
    if not isinstance(size, list) or len(size) < 3:
        return None
    x, y, z = (float(cframe[0]), float(cframe[1]), float(cframe[2]))
    size_x, size_y, size_z = (float(size[0]), float(size[1]), float(size[2]))
    return x, y, z, size_x, size_y, size_z


def traversal_surfaces(project_world: dict[str, Any]) -> list[Surface]:
    surfaces: list[Surface] = []
    for mount in TRAVERSAL_MOUNTS:
        node = project_world.get(mount)
        if not isinstance(node, dict) or "$path" not in node:
            raise RuntimeError(f"Main World project is missing traversal mount {mount!r}")
        model = load_json(GAME / str(node["$path"]))
        for instance in iter_instances(model):
            name = str(instance.get("Name", ""))
            if not name.startswith("main_world.traversal."):
                continue
            geometry = part_geometry(instance)
            if geometry is None:
                continue
            x, y, z, size_x, size_y, size_z = geometry
            surfaces.append(
                Surface(
                    name=name,
                    x=x,
                    top=y + size_y / 2,
                    z=z,
                    size_x=size_x,
                    size_z=size_z,
                )
            )
    if not surfaces:
        raise RuntimeError("no repo-owned Main World traversal surfaces were discovered")
    names = [surface.name for surface in surfaces]
    if len(names) != len(set(names)):
        raise RuntimeError("Main World traversal surface names must be unique")
    return surfaces


def rectangles_touch(a: Surface, b: Surface) -> bool:
    x_touch = a.min_x <= b.max_x + RECT_EPSILON and b.min_x <= a.max_x + RECT_EPSILON
    z_touch = a.min_z <= b.max_z + RECT_EPSILON and b.min_z <= a.max_z + RECT_EPSILON
    return x_touch and z_touch


def walkably_adjacent(a: Surface, b: Surface) -> bool:
    return rectangles_touch(a, b) and abs(a.top - b.top) <= MAX_STEP_DELTA


def reachable_surfaces(surfaces: list[Surface]) -> set[str]:
    by_name = {surface.name: surface for surface in surfaces}
    if ROOT_SURFACE not in by_name:
        raise RuntimeError(f"Main World traversal root is missing: {ROOT_SURFACE}")

    neighbors: dict[str, set[str]] = {name: set() for name in by_name}
    for index, left in enumerate(surfaces):
        for right in surfaces[index + 1 :]:
            if walkably_adjacent(left, right):
                neighbors[left.name].add(right.name)
                neighbors[right.name].add(left.name)

    visited = {ROOT_SURFACE}
    frontier = [ROOT_SURFACE]
    while frontier:
        current = frontier.pop()
        for neighbor in neighbors[current]:
            if neighbor not in visited:
                visited.add(neighbor)
                frontier.append(neighbor)
    return visited


def point_has_support(anchor: Anchor, surfaces: list[Surface], reachable: set[str]) -> bool:
    for surface in surfaces:
        if surface.name not in reachable:
            continue
        if not (surface.min_x - RECT_EPSILON <= anchor.x <= surface.max_x + RECT_EPSILON):
            continue
        if not (surface.min_z - RECT_EPSILON <= anchor.z <= surface.max_z + RECT_EPSILON):
            continue
        if abs(surface.top - anchor.bottom) <= SUPPORT_VERTICAL_TOLERANCE:
            return True
    return False


def route_anchors(project_world: dict[str, Any]) -> list[Anchor]:
    route_node = project_world.get("Routes")
    if not isinstance(route_node, dict) or "$path" not in route_node:
        raise RuntimeError("Main World project is missing the preserved Routes mount")
    route_model = load_json(GAME / str(route_node["$path"]))
    anchors: list[Anchor] = []
    for instance in iter_instances(route_model):
        geometry = part_geometry(instance)
        if geometry is None:
            continue
        x, y, z, _, size_y, _ = geometry
        anchors.append(
            Anchor(
                group="Routes",
                name=str(instance.get("Name", "unnamed route part")),
                x=x,
                bottom=y - size_y / 2,
                z=z,
            )
        )
    if not anchors:
        raise RuntimeError("preserved Main World Routes contain no BasePart anchors")
    return anchors


def lower_world_anchors(group: str, project_world: dict[str, Any]) -> list[Anchor]:
    node = project_world.get(group)
    if not isinstance(node, dict) or "$path" not in node:
        raise RuntimeError(f"Main World project is missing lower-world mount {group!r}")
    model = load_json(GAME / str(node["$path"]))
    anchors: list[Anchor] = []
    for instance in iter_instances(model):
        geometry = part_geometry(instance)
        if geometry is None:
            continue
        x, y, z, _, size_y, _ = geometry
        bottom = y - size_y / 2
        if y > GROUND_BEARING_MAX_CENTER_Y or bottom > SUPPORT_VERTICAL_TOLERANCE:
            continue
        anchors.append(
            Anchor(
                group=group,
                name=str(instance.get("Name", "unnamed lower-world part")),
                x=x,
                bottom=bottom,
                z=z,
            )
        )
    if not anchors:
        raise RuntimeError(f"lower-world group {group!r} has no ground-bearing BasePart anchors")
    return anchors


def main() -> int:
    project = load_json(PROJECT)
    try:
        project_world = project["tree"]["Workspace"]["LivingKingdomsMainWorld"]
    except (KeyError, TypeError) as exc:
        raise RuntimeError("Main World project workspace tree is malformed") from exc
    if not isinstance(project_world, dict):
        raise RuntimeError("Main World project workspace root must be an object")

    surfaces = traversal_surfaces(project_world)
    reachable = reachable_surfaces(surfaces)
    disconnected = sorted(surface.name for surface in surfaces if surface.name not in reachable)
    if disconnected:
        raise RuntimeError(
            "Main World traversal support graph contains unreachable surfaces: " + ", ".join(disconnected)
        )

    routes = route_anchors(project_world)
    unsupported_routes = [
        anchor.name for anchor in routes if not point_has_support(anchor, surfaces, reachable)
    ]
    if unsupported_routes:
        raise RuntimeError(
            "preserved Main World route contains unsupported chunks: " + ", ".join(unsupported_routes)
        )

    lower_anchors = [
        anchor
        for group in LOWER_WORLD_GROUPS
        for anchor in lower_world_anchors(group, project_world)
    ]
    unsupported_lower_world = [
        f"{anchor.group}/{anchor.name} ({anchor.x:.1f}, {anchor.z:.1f})"
        for anchor in lower_anchors
        if not point_has_support(anchor, surfaces, reachable)
    ]
    if unsupported_lower_world:
        raise RuntimeError(
            "lower Main World contains ground-bearing pieces without reachable support: "
            + ", ".join(unsupported_lower_world)
        )

    print(
        "[main-world-traversal] OK — "
        f"{len(surfaces)} support surfaces form one graph; "
        f"{len(routes)} preserved route chunks and "
        f"{len(lower_anchors)} ground-bearing lower-world parts are supported"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
