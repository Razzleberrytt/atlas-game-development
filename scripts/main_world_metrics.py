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
    lower_world_anchors,
    point_has_support,
    reachable_surfaces,
    route_anchors,
    traversal_surfaces,
    validate_hub_handoff,
    walkably_adjacent,
)

T = TypeVar("T")
SCHEMA_VERSION = 1


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
    traversal = metrics["traversal"]
    navigation = metrics["navigation"]
    print(
        "[main-world-metrics] OK — "
        f"{world['mounted_root_count']} mounts; "
        f"traversal {traversal['reachable_surface_count']}/{traversal['surface_count']} reachable "
        f"across {traversal['graph_edge_count']} edges; "
        f"roads {navigation['reachable_road_count']}/{navigation['road_count']} reachable "
        f"across {navigation['road_graph_edge_count']} edges; "
        f"district reach {navigation['reached_district_target_count']}/{navigation['district_target_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
