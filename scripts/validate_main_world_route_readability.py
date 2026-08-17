#!/usr/bin/env python3
"""Guard the dedicated Main World's source-managed visual navigation network.

Traversal topology answers "can the player physically get there?". This guard
answers the separate readability question: does the recovered lower world expose
one coherent, supported cobblestone road graph from the arrival area to the
major outer biome districts, and is the repo-owned continent visually skinned as
ground instead of reading like an oversized road slab?
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterator

from validate_main_world_traversal_topology import (
    GAME,
    PROJECT,
    Surface,
    iter_instances,
    load_json,
    part_geometry,
    reachable_surfaces,
    traversal_surfaces,
)

GROUND_MATERIAL = 1360
ROAD_MATERIAL = 880
ROAD_ROOT = "main_world.regional_route.spawn_apron"
ROAD_TOUCH_EPSILON = 0.3
ROAD_SUPPORT_TOLERANCE = 0.35
SAMPLE_STEP = 18.0

REQUIRED_ROADS = {
    "main_world.regional_route.central_crossroad",
    "main_world.regional_route.north_trunk",
    "main_world.regional_route.north_biome_cross",
    "main_world.regional_route.south_biome_cross",
    "main_world.regional_route.west_outer_rail",
    "main_world.regional_route.east_outer_rail",
    ROAD_ROOT,
}

# Representative navigation destinations, not individual biome props. These
# ensure the road graph reaches the useful edges of the recovered lower world.
DISTRICT_TARGETS = {
    "arrival": (0.0, 30.0),
    "north-west": (-165.0, 285.0),
    "north-east": (165.0, 285.0),
    "west-north": (-450.0, 165.0),
    "west-south": (-450.0, -285.0),
    "east-north": (450.0, 165.0),
    "east-south": (450.0, -285.0),
    "south-west": (-300.0, -165.0),
    "south-east": (300.0, -165.0),
}


@dataclass(frozen=True)
class Road:
    name: str
    x: float
    bottom: float
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


def project_world() -> dict[str, Any]:
    project = load_json(PROJECT)
    try:
        world = project["tree"]["Workspace"]["LivingKingdomsMainWorld"]
    except (KeyError, TypeError) as exc:
        raise RuntimeError("Main World project workspace tree is malformed") from exc
    if not isinstance(world, dict):
        raise RuntimeError("Main World project workspace root must be an object")
    return world


def mounted_model(world: dict[str, Any], mount: str) -> dict[str, Any]:
    node = world.get(mount)
    if not isinstance(node, dict) or "$path" not in node:
        raise RuntimeError(f"Main World project is missing {mount!r} mount")
    return load_json(GAME / str(node["$path"]))


def enum_value(instance: dict[str, Any], property_name: str) -> int | None:
    value = instance.get("Properties", {}).get(property_name)
    if isinstance(value, dict) and isinstance(value.get("Enum"), int):
        return int(value["Enum"])
    return None


def validate_ground_skin(world: dict[str, Any]) -> int:
    model = mounted_model(world, "GroundSkin")
    count = 0
    for instance in iter_instances(model):
        name = str(instance.get("Name", ""))
        if not name.startswith("main_world.ground."):
            continue
        geometry = part_geometry(instance)
        if geometry is None:
            raise RuntimeError(f"ground skin instance is not a BasePart: {name}")
        props = instance.get("Properties", {})
        if enum_value(instance, "Material") != GROUND_MATERIAL:
            raise RuntimeError(f"ground skin must use Enum.Material.Ground: {name}")
        if props.get("CanCollide") is not False or props.get("CanQuery") is not False or props.get("CanTouch") is not False:
            raise RuntimeError(f"ground skin must remain presentation-only: {name}")
        count += 1
    if count < 5:
        raise RuntimeError(f"expected at least 5 Main World ground-skin pieces, found {count}")
    return count


def regional_roads(world: dict[str, Any]) -> list[Road]:
    model = mounted_model(world, "RegionalRoutes")
    roads: list[Road] = []
    for instance in iter_instances(model):
        name = str(instance.get("Name", ""))
        if not name.startswith("main_world.regional_route."):
            continue
        geometry = part_geometry(instance)
        if geometry is None:
            raise RuntimeError(f"regional route instance is not a BasePart: {name}")
        if enum_value(instance, "Material") != ROAD_MATERIAL:
            raise RuntimeError(f"regional route must preserve the recovered cobblestone material: {name}")
        x, y, z, size_x, size_y, size_z = geometry
        roads.append(
            Road(
                name=name,
                x=x,
                bottom=y - size_y / 2,
                top=y + size_y / 2,
                z=z,
                size_x=size_x,
                size_z=size_z,
            )
        )
    names = {road.name for road in roads}
    missing = sorted(REQUIRED_ROADS - names)
    if missing:
        raise RuntimeError("Main World regional route contract is missing: " + ", ".join(missing))
    if len(names) != len(roads):
        raise RuntimeError("Main World regional route names must be unique")
    return roads


def roads_touch(left: Road, right: Road) -> bool:
    x_touch = left.min_x <= right.max_x + ROAD_TOUCH_EPSILON and right.min_x <= left.max_x + ROAD_TOUCH_EPSILON
    z_touch = left.min_z <= right.max_z + ROAD_TOUCH_EPSILON and right.min_z <= left.max_z + ROAD_TOUCH_EPSILON
    return x_touch and z_touch and abs(left.top - right.top) <= ROAD_TOUCH_EPSILON


def reachable_roads(roads: list[Road]) -> set[str]:
    by_name = {road.name: road for road in roads}
    if ROAD_ROOT not in by_name:
        raise RuntimeError(f"regional route root is missing: {ROAD_ROOT}")
    neighbors: dict[str, set[str]] = {name: set() for name in by_name}
    for index, left in enumerate(roads):
        for right in roads[index + 1 :]:
            if roads_touch(left, right):
                neighbors[left.name].add(right.name)
                neighbors[right.name].add(left.name)
    visited = {ROAD_ROOT}
    frontier = [ROAD_ROOT]
    while frontier:
        current = frontier.pop()
        for neighbor in neighbors[current]:
            if neighbor not in visited:
                visited.add(neighbor)
                frontier.append(neighbor)
    return visited


def axis_samples(minimum: float, maximum: float) -> Iterator[float]:
    if maximum < minimum:
        minimum, maximum = maximum, minimum
    yield minimum
    cursor = minimum + SAMPLE_STEP
    while cursor < maximum:
        yield cursor
        cursor += SAMPLE_STEP
    if maximum > minimum:
        yield maximum


def road_samples(road: Road) -> Iterator[tuple[float, float]]:
    inset_x = min(0.45, road.size_x / 4)
    inset_z = min(0.45, road.size_z / 4)
    xs = [road.min_x + inset_x, road.x, road.max_x - inset_x]
    zs = [road.min_z + inset_z, road.z, road.max_z - inset_z]
    if road.size_x >= road.size_z:
        for x in axis_samples(road.min_x + inset_x, road.max_x - inset_x):
            for z in zs:
                yield x, z
    else:
        for z in axis_samples(road.min_z + inset_z, road.max_z - inset_z):
            for x in xs:
                yield x, z


def point_supported(x: float, z: float, bottom: float, surfaces: list[Surface], reachable: set[str]) -> bool:
    for surface in surfaces:
        if surface.name not in reachable:
            continue
        if not (surface.min_x - ROAD_TOUCH_EPSILON <= x <= surface.max_x + ROAD_TOUCH_EPSILON):
            continue
        if not (surface.min_z - ROAD_TOUCH_EPSILON <= z <= surface.max_z + ROAD_TOUCH_EPSILON):
            continue
        if abs(surface.top - bottom) <= ROAD_SUPPORT_TOLERANCE:
            return True
    return False


def validate_road_support(roads: list[Road], surfaces: list[Surface], reachable: set[str]) -> int:
    samples = 0
    for road in roads:
        for x, z in road_samples(road):
            samples += 1
            if not point_supported(x, z, road.bottom, surfaces, reachable):
                raise RuntimeError(
                    f"regional route leaves reachable support: {road.name} at ({x:.1f}, {z:.1f})"
                )
    return samples


def point_on_road(x: float, z: float, roads: list[Road], reachable: set[str]) -> bool:
    for road in roads:
        if road.name not in reachable:
            continue
        if road.min_x - ROAD_TOUCH_EPSILON <= x <= road.max_x + ROAD_TOUCH_EPSILON and road.min_z - ROAD_TOUCH_EPSILON <= z <= road.max_z + ROAD_TOUCH_EPSILON:
            return True
    return False


def main() -> int:
    world = project_world()
    ground_count = validate_ground_skin(world)
    roads = regional_roads(world)
    route_reachable = reachable_roads(roads)
    disconnected = sorted(road.name for road in roads if road.name not in route_reachable)
    if disconnected:
        raise RuntimeError("Main World regional road graph is disconnected: " + ", ".join(disconnected))

    surfaces = traversal_surfaces(world)
    support_reachable = reachable_surfaces(surfaces)
    sample_count = validate_road_support(roads, surfaces, support_reachable)

    missed_targets = [
        name for name, (x, z) in DISTRICT_TARGETS.items() if not point_on_road(x, z, roads, route_reachable)
    ]
    if missed_targets:
        raise RuntimeError("Main World regional roads do not reach district targets: " + ", ".join(missed_targets))

    print(
        "[main-world-route-readability] OK — "
        f"{ground_count} Ground-material skin pieces, {len(roads)} connected cobblestone roads, "
        f"{sample_count} support samples, {len(DISTRICT_TARGETS)} district targets"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
