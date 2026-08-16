#!/usr/bin/env python3
"""Compute one canonical machine-readable metrics view of the Living Kingdoms Main World.

The dedicated Main World already has strong geometry validators, but historically
its useful measurements were emitted only as human-readable validator summaries.
This module reuses those canonical geometry functions and exposes one structured
metrics surface for CI, audits, dashboards, and future world-generation tooling.

No recovered Studio source is modified and no gameplay runtime is activated.
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Callable, Sequence
from typing import Any, TypeVar

from validate_main_world_route_readability import (
    DISTRICT_TARGETS,
    ROAD_MATERIAL,
    enum_value,
    mounted_model,
    point_on_road,
    project_world,
    reachable_roads,
    regional_roads,
    roads_touch,
    validate_ground_skin,
    validate_road_support,
)
from validate_main_world_static_scene import CONFIG, read, table_strings
from validate_main_world_traversal_topology import (
    LOWER_WORLD_GROUPS,
    Surface,
    iter_instances,
    lower_world_anchors,
    part_geometry,
    point_has_support,
    reachable_surfaces,
    route_anchors,
    traversal_surfaces,
    validate_hub_handoff,
    walkably_adjacent,
)

T = TypeVar("T")
SCHEMA_VERSION = 2

ARRIVAL_LANDING = "main_world.arrival_handoff.landing"
ARRIVAL_STEP_PREFIX = "main_world.arrival_handoff.step."
ARRIVAL_EXPECTED_STEP_COUNT = 8
ARRIVAL_ROAD = "main_world.regional_route.north_trunk"
ARRIVAL_TOUCH_EPSILON = 0.051
ARRIVAL_MAX_STEP_DROP = 1.0
ARRIVAL_MIN_WIDTH = 12.0


def _edge_count(items: Sequence[T], adjacent: Callable[[T, T], bool]) -> int:
    edges = 0
    for index, left in enumerate(items):
        for right in items[index + 1 :]:
            if adjacent(left, right):
                edges += 1
    return edges


def _bounds(items: Sequence[Any]) -> dict[str, float]:
    if not items:
        raise RuntimeError("cannot compute Main World bounds from an empty collection")
    return {
        "min_x": round(min(item.min_x for item in items), 3),
        "max_x": round(max(item.max_x for item in items), 3),
        "min_z": round(min(item.min_z for item in items), 3),
        "max_z": round(max(item.max_z for item in items), 3),
    }


def _coverage(reached: int, total: int) -> float:
    if total <= 0:
        raise RuntimeError("Main World coverage denominator must be positive")
    return round(reached / total, 6)


def _rect_gap(left: Surface, right: Any) -> float:
    x_gap = max(0.0, left.min_x - right.max_x, right.min_x - left.max_x)
    z_gap = max(0.0, left.min_z - right.max_z, right.min_z - left.max_z)
    return max(x_gap, z_gap)


def _arrival_metrics(world: dict[str, Any], roads: Sequence[Any]) -> dict[str, Any]:
    """Validate and measure the cold-join handoff from the authored spawn to the road graph."""

    model = mounted_model(world, "ArrivalTraversal")
    arrival_surfaces: dict[str, Surface] = {}
    for instance in iter_instances(model):
        name = str(instance.get("Name", ""))
        if name != ARRIVAL_LANDING and not name.startswith(ARRIVAL_STEP_PREFIX):
            continue
        geometry = part_geometry(instance)
        if geometry is None:
            raise RuntimeError(f"Main World arrival handoff instance is not a BasePart: {name}")
        props = instance.get("Properties", {})
        if props.get("Anchored") is not True or props.get("CanCollide") is not True:
            raise RuntimeError(f"Main World arrival handoff must remain anchored and collidable: {name}")
        if enum_value(instance, "Material") != ROAD_MATERIAL:
            raise RuntimeError(f"Main World arrival handoff must use the road material: {name}")
        x, y, z, size_x, size_y, size_z = geometry
        if size_x < ARRIVAL_MIN_WIDTH:
            raise RuntimeError(f"Main World arrival handoff narrowed below {ARRIVAL_MIN_WIDTH:g} studs: {name}")
        if name in arrival_surfaces:
            raise RuntimeError(f"Main World arrival handoff surface name is duplicated: {name}")
        arrival_surfaces[name] = Surface(
            name=name,
            x=x,
            top=y + size_y / 2,
            z=z,
            size_x=size_x,
            size_z=size_z,
        )

    expected_steps = [f"{ARRIVAL_STEP_PREFIX}{index:03d}" for index in range(1, ARRIVAL_EXPECTED_STEP_COUNT + 1)]
    expected_names = {ARRIVAL_LANDING, *expected_steps}
    if set(arrival_surfaces) != expected_names:
        missing = sorted(expected_names - set(arrival_surfaces))
        unexpected = sorted(set(arrival_surfaces) - expected_names)
        raise RuntimeError(
            "Main World arrival handoff surface contract drifted: "
            f"missing={missing or 'none'} unexpected={unexpected or 'none'}"
        )

    ordered = [arrival_surfaces[ARRIVAL_LANDING], *(arrival_surfaces[name] for name in expected_steps)]
    step_drops: list[float] = []
    horizontal_gaps: list[float] = []
    previous = ordered[0]
    for current in ordered[1:]:
        if current.z <= previous.z:
            raise RuntimeError("Main World arrival handoff must progress northward from the authored spawn")
        horizontal_gap = max(0.0, current.min_z - previous.max_z)
        if horizontal_gap > ARRIVAL_TOUCH_EPSILON:
            raise RuntimeError(
                f"Main World arrival handoff has a horizontal gap of {horizontal_gap:.3f} studs before {current.name}"
            )
        drop = previous.top - current.top
        if drop <= 0.0 or drop > ARRIVAL_MAX_STEP_DROP + ARRIVAL_TOUCH_EPSILON:
            raise RuntimeError(f"Main World arrival handoff has an unsafe vertical step of {drop:.3f} studs")
        horizontal_gaps.append(horizontal_gap)
        step_drops.append(drop)
        previous = current

    road_by_name = {road.name: road for road in roads}
    road = road_by_name.get(ARRIVAL_ROAD)
    if road is None:
        raise RuntimeError(f"Main World arrival metrics cannot find road handoff target: {ARRIVAL_ROAD}")
    final = ordered[-1]
    road_horizontal_gap = _rect_gap(final, road)
    road_vertical_gap = abs(final.top - road.top)
    if road_horizontal_gap > ARRIVAL_TOUCH_EPSILON or road_vertical_gap > ARRIVAL_TOUCH_EPSILON:
        raise RuntimeError(
            "Main World arrival handoff does not terminate flush with the regional road: "
            f"horizontal={road_horizontal_gap:.3f} vertical={road_vertical_gap:.3f}"
        )

    widths = [surface.size_x for surface in ordered]
    return {
        "surface_count": len(ordered),
        "reachable_surface_count": len(ordered),
        "reachable_surface_ratio": _coverage(len(ordered), len(ordered)),
        "step_count": len(step_drops),
        "safe_step_count": len(step_drops),
        "safe_step_ratio": _coverage(len(step_drops), len(step_drops)),
        "landing_top": round(ordered[0].top, 3),
        "road_top": round(road.top, 3),
        "vertical_descent": round(ordered[0].top - road.top, 3),
        "max_step_drop": round(max(step_drops), 3),
        "min_width": round(min(widths), 3),
        "max_horizontal_gap": round(max(horizontal_gaps), 3),
        "road_handoff_horizontal_gap": round(road_horizontal_gap, 3),
        "road_handoff_vertical_gap": round(road_vertical_gap, 3),
        "bounds": _bounds(ordered),
    }


def collect_metrics() -> dict[str, Any]:
    """Return validated current-state Main World metrics without mutating sources."""

    world = project_world()
    world_mounts = {name for name in world if not name.startswith("$")}

    config_source = read(CONFIG)
    static_roots = set(table_strings(config_source, "StaticRootNames"))
    dynamic_roots = set(table_strings(config_source, "DynamicRootNames"))
    classified_roots = static_roots | dynamic_roots
    if classified_roots != world_mounts:
        missing = sorted(world_mounts - classified_roots)
        stale = sorted(classified_roots - world_mounts)
        raise RuntimeError(
            "Main World metrics cannot classify every mounted root: "
            f"missing={missing or 'none'} stale={stale or 'none'}"
        )
    if static_roots & dynamic_roots:
        raise RuntimeError("Main World metrics found roots classified as both static and dynamic")

    surfaces = traversal_surfaces(world)
    support_reachable = reachable_surfaces(surfaces)
    disconnected_surfaces = sorted(surface.name for surface in surfaces if surface.name not in support_reachable)
    if disconnected_surfaces:
        raise RuntimeError(
            "Main World metrics found disconnected traversal surfaces: " + ", ".join(disconnected_surfaces)
        )

    hub_surface_count = validate_hub_handoff(world, surfaces, support_reachable)

    routes = route_anchors(world)
    unsupported_routes = [
        anchor.name for anchor in routes if not point_has_support(anchor, surfaces, support_reachable)
    ]
    if unsupported_routes:
        raise RuntimeError(
            "Main World metrics found unsupported preserved route chunks: " + ", ".join(unsupported_routes)
        )

    lower_group_counts: dict[str, int] = {}
    lower_anchors = []
    for group in LOWER_WORLD_GROUPS:
        anchors = lower_world_anchors(group, world)
        lower_group_counts[group] = len(anchors)
        lower_anchors.extend(anchors)

    unsupported_lower = [
        f"{anchor.group}/{anchor.name}"
        for anchor in lower_anchors
        if not point_has_support(anchor, surfaces, support_reachable)
    ]
    if unsupported_lower:
        raise RuntimeError(
            "Main World metrics found unsupported lower-world anchors: " + ", ".join(unsupported_lower)
        )

    ground_skin_count = validate_ground_skin(world)
    roads = regional_roads(world)
    road_reachable = reachable_roads(roads)
    disconnected_roads = sorted(road.name for road in roads if road.name not in road_reachable)
    if disconnected_roads:
        raise RuntimeError("Main World metrics found disconnected regional roads: " + ", ".join(disconnected_roads))

    support_sample_count = validate_road_support(roads, surfaces, support_reachable)
    reached_districts = sorted(
        name
        for name, (x, z) in DISTRICT_TARGETS.items()
        if point_on_road(x, z, roads, road_reachable)
    )
    missed_districts = sorted(set(DISTRICT_TARGETS) - set(reached_districts))
    if missed_districts:
        raise RuntimeError(
            "Main World metrics found regional roads missing district targets: " + ", ".join(missed_districts)
        )

    arrival = _arrival_metrics(world, roads)
    traversal_edges = _edge_count(surfaces, walkably_adjacent)
    road_edges = _edge_count(roads, roads_touch)

    return {
        "schema_version": SCHEMA_VERSION,
        "world": {
            "mounted_root_count": len(world_mounts),
            "static_root_count": len(static_roots),
            "dynamic_root_count": len(dynamic_roots),
            "lower_world_group_count": len(LOWER_WORLD_GROUPS),
        },
        "arrival": arrival,
        "traversal": {
            "surface_count": len(surfaces),
            "reachable_surface_count": len(support_reachable),
            "reachable_surface_ratio": _coverage(len(support_reachable), len(surfaces)),
            "graph_edge_count": traversal_edges,
            "hub_surface_count": hub_surface_count,
            "preserved_route_anchor_count": len(routes),
            "supported_route_anchor_count": len(routes) - len(unsupported_routes),
            "lower_world_anchor_count": len(lower_anchors),
            "supported_lower_world_anchor_count": len(lower_anchors) - len(unsupported_lower),
            "lower_world_anchor_counts_by_group": dict(sorted(lower_group_counts.items())),
            "bounds": _bounds(surfaces),
        },
        "navigation": {
            "ground_skin_count": ground_skin_count,
            "road_count": len(roads),
            "reachable_road_count": len(road_reachable),
            "reachable_road_ratio": _coverage(len(road_reachable), len(roads)),
            "road_graph_edge_count": road_edges,
            "road_support_sample_count": support_sample_count,
            "district_target_count": len(DISTRICT_TARGETS),
            "reached_district_target_count": len(reached_districts),
            "district_reach_ratio": _coverage(len(reached_districts), len(DISTRICT_TARGETS)),
            "reached_district_targets": reached_districts,
            "bounds": _bounds(roads),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit the canonical metrics document as JSON instead of the concise validation summary",
    )
    args = parser.parse_args()

    metrics = collect_metrics()
    if args.json:
        print(json.dumps(metrics, indent=2, sort_keys=True))
        return 0

    world = metrics["world"]
    arrival = metrics["arrival"]
    traversal = metrics["traversal"]
    navigation = metrics["navigation"]
    print(
        "[main-world-metrics] OK — "
        f"{world['mounted_root_count']} mounts; "
        f"arrival {arrival['reachable_surface_count']}/{arrival['surface_count']} reachable, "
        f"max step {arrival['max_step_drop']:.3f}; "
        f"traversal {traversal['reachable_surface_count']}/{traversal['surface_count']} reachable "
        f"across {traversal['graph_edge_count']} edges; "
        f"roads {navigation['reachable_road_count']}/{navigation['road_count']} reachable "
        f"across {navigation['road_graph_edge_count']} edges; "
        f"district reach {navigation['reached_district_target_count']}/{navigation['district_target_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
