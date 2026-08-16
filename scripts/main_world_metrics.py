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
from dataclasses import dataclass
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
SCHEMA_VERSION = 3

ARRIVAL_LANDING = "main_world.arrival_handoff.landing"
ARRIVAL_STEP_PREFIX = "main_world.arrival_handoff.step."
ARRIVAL_EXPECTED_STEP_COUNT = 8
ARRIVAL_ROAD = "main_world.regional_route.north_trunk"
ARRIVAL_TOUCH_EPSILON = 0.051
ARRIVAL_MAX_STEP_DROP = 1.0
ARRIVAL_MIN_WIDTH = 12.0


def _coverage(reached: int, total: int) -> float:
    if total <= 0:
        raise RuntimeError("Main World coverage denominator must be positive")
    return round(reached / total, 6)


def _bounds(items: Sequence[Any]) -> dict[str, float]:
    if not items:
        raise RuntimeError("cannot compute Main World bounds from an empty collection")
    return {
        "min_x": round(min(item.min_x for item in items), 3),
        "max_x": round(max(item.max_x for item in items), 3),
        "min_z": round(min(item.min_z for item in items), 3),
        "max_z": round(max(item.max_z for item in items), 3),
    }


def _graph_resilience(items: Sequence[T], adjacent: Callable[[T, T], bool]) -> dict[str, Any]:
    """Measure structural redundancy in an undirected world graph.

    Connectivity alone can hide a brittle map where one road or traversal tile is
    the only route between large regions. Tarjan's algorithm identifies those
    articulation points and bridge edges in linear time after the adjacency graph
    is built. The current authored graphs are small, so the geometry-to-adjacency
    construction remains the same deterministic O(n^2) pair scan used elsewhere.
    """

    if not items:
        raise RuntimeError("cannot compute Main World graph resilience from an empty collection")

    names = [str(getattr(item, "name")) for item in items]
    if len(set(names)) != len(names):
        raise RuntimeError("Main World graph resilience requires unique node names")

    adjacency: list[set[int]] = [set() for _ in items]
    edge_count = 0
    for left_index, left in enumerate(items):
        for right_index in range(left_index + 1, len(items)):
            if adjacent(left, items[right_index]):
                adjacency[left_index].add(right_index)
                adjacency[right_index].add(left_index)
                edge_count += 1

    component_count = 0
    component_seen: set[int] = set()
    for root in range(len(items)):
        if root in component_seen:
            continue
        component_count += 1
        stack = [root]
        component_seen.add(root)
        while stack:
            current = stack.pop()
            for neighbor in adjacency[current]:
                if neighbor not in component_seen:
                    component_seen.add(neighbor)
                    stack.append(neighbor)

    discovery = [-1] * len(items)
    low = [-1] * len(items)
    parent = [-1] * len(items)
    articulation_points: set[int] = set()
    bridges: set[tuple[int, int]] = set()
    next_discovery = 0

    def visit(node: int) -> None:
        nonlocal next_discovery
        discovery[node] = next_discovery
        low[node] = next_discovery
        next_discovery += 1
        child_count = 0

        for neighbor in sorted(adjacency[node]):
            if discovery[neighbor] == -1:
                parent[neighbor] = node
                child_count += 1
                visit(neighbor)
                low[node] = min(low[node], low[neighbor])

                if parent[node] == -1 and child_count > 1:
                    articulation_points.add(node)
                if parent[node] != -1 and low[neighbor] >= discovery[node]:
                    articulation_points.add(node)
                if low[neighbor] > discovery[node]:
                    bridges.add((min(node, neighbor), max(node, neighbor)))
            elif neighbor != parent[node]:
                low[node] = min(low[node], discovery[neighbor])

    for node in range(len(items)):
        if discovery[node] == -1:
            visit(node)

    degrees = [len(neighbors) for neighbors in adjacency]
    isolated_names = sorted(names[index] for index, degree in enumerate(degrees) if degree == 0)
    dead_end_names = sorted(names[index] for index, degree in enumerate(degrees) if degree == 1)
    articulation_names = sorted(names[index] for index in articulation_points)
    bridge_edges = sorted(
        ({"left": names[left], "right": names[right]} for left, right in bridges),
        key=lambda edge: (edge["left"], edge["right"]),
    )
    degree_distribution: dict[str, int] = {}
    for degree in sorted(set(degrees)):
        degree_distribution[str(degree)] = degrees.count(degree)

    bridge_count = len(bridges)
    return {
        "node_count": len(items),
        "edge_count": edge_count,
        "connected_component_count": component_count,
        "isolated_node_count": len(isolated_names),
        "isolated_node_names": isolated_names,
        "dead_end_node_count": len(dead_end_names),
        "dead_end_node_names": dead_end_names,
        "min_degree": min(degrees),
        "max_degree": max(degrees),
        "average_degree": round(sum(degrees) / len(degrees), 6),
        "degree_distribution": degree_distribution,
        "degree_at_least_two_ratio": _coverage(sum(degree >= 2 for degree in degrees), len(degrees)),
        "articulation_point_count": len(articulation_names),
        "articulation_point_names": articulation_names,
        "bridge_count": bridge_count,
        "bridge_edges": bridge_edges,
        "cycle_rank": edge_count - len(items) + component_count,
        "edge_redundancy_ratio": round((edge_count - bridge_count) / edge_count, 6) if edge_count > 0 else 0.0,
    }


@dataclass(frozen=True)
class _SyntheticNode:
    name: str


def _synthetic_graph(names: Sequence[str], edges: set[tuple[str, str]]) -> tuple[list[_SyntheticNode], Callable[[Any, Any], bool]]:
    nodes = [_SyntheticNode(name) for name in names]
    normalized = {tuple(sorted(edge)) for edge in edges}

    def adjacent(left: _SyntheticNode, right: _SyntheticNode) -> bool:
        return tuple(sorted((left.name, right.name))) in normalized

    return nodes, adjacent


def _self_test_graph_resilience() -> None:
    path, path_adjacent = _synthetic_graph(
        ["A", "B", "C", "D"],
        {("A", "B"), ("B", "C"), ("C", "D")},
    )
    path_metrics = _graph_resilience(path, path_adjacent)
    assert path_metrics["connected_component_count"] == 1
    assert path_metrics["edge_count"] == 3
    assert path_metrics["cycle_rank"] == 0
    assert path_metrics["dead_end_node_names"] == ["A", "D"]
    assert path_metrics["articulation_point_names"] == ["B", "C"]
    assert path_metrics["bridge_count"] == 3
    assert path_metrics["edge_redundancy_ratio"] == 0.0

    cycle, cycle_adjacent = _synthetic_graph(
        ["A", "B", "C"],
        {("A", "B"), ("B", "C"), ("C", "A")},
    )
    cycle_metrics = _graph_resilience(cycle, cycle_adjacent)
    assert cycle_metrics["connected_component_count"] == 1
    assert cycle_metrics["edge_count"] == 3
    assert cycle_metrics["cycle_rank"] == 1
    assert cycle_metrics["dead_end_node_count"] == 0
    assert cycle_metrics["articulation_point_count"] == 0
    assert cycle_metrics["bridge_count"] == 0
    assert cycle_metrics["degree_at_least_two_ratio"] == 1.0
    assert cycle_metrics["edge_redundancy_ratio"] == 1.0

    disconnected, disconnected_adjacent = _synthetic_graph(
        ["A", "B", "C"],
        {("A", "B")},
    )
    disconnected_metrics = _graph_resilience(disconnected, disconnected_adjacent)
    assert disconnected_metrics["connected_component_count"] == 2
    assert disconnected_metrics["isolated_node_names"] == ["C"]
    assert disconnected_metrics["dead_end_node_names"] == ["A", "B"]
    assert disconnected_metrics["bridge_count"] == 1
    assert disconnected_metrics["articulation_point_count"] == 0
    assert disconnected_metrics["cycle_rank"] == 0


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
    traversal_resilience = _graph_resilience(surfaces, walkably_adjacent)
    road_resilience = _graph_resilience(roads, roads_touch)

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
            "graph_edge_count": traversal_resilience["edge_count"],
            "resilience": traversal_resilience,
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
            "road_graph_edge_count": road_resilience["edge_count"],
            "resilience": road_resilience,
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
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--json",
        action="store_true",
        help="emit the canonical metrics document as JSON instead of the concise validation summary",
    )
    mode.add_argument(
        "--self-test",
        action="store_true",
        help="run deterministic synthetic graph tests for the resilience algorithm",
    )
    args = parser.parse_args()

    if args.self_test:
        _self_test_graph_resilience()
        print("[main-world-metrics] graph resilience self-test passed")
        return 0

    metrics = collect_metrics()
    if args.json:
        print(json.dumps(metrics, indent=2, sort_keys=True))
        return 0

    world = metrics["world"]
    arrival = metrics["arrival"]
    traversal = metrics["traversal"]
    traversal_resilience = traversal["resilience"]
    navigation = metrics["navigation"]
    road_resilience = navigation["resilience"]
    print(
        "[main-world-metrics] OK — "
        f"{world['mounted_root_count']} mounts; "
        f"arrival {arrival['reachable_surface_count']}/{arrival['surface_count']} reachable, "
        f"max step {arrival['max_step_drop']:.3f}; "
        f"traversal {traversal['reachable_surface_count']}/{traversal['surface_count']} reachable "
        f"across {traversal['graph_edge_count']} edges, "
        f"{traversal_resilience['articulation_point_count']} chokepoints/{traversal_resilience['bridge_count']} bridges; "
        f"roads {navigation['reachable_road_count']}/{navigation['road_count']} reachable "
        f"across {navigation['road_graph_edge_count']} edges, "
        f"{road_resilience['articulation_point_count']} chokepoints/{road_resilience['bridge_count']} bridges; "
        f"district reach {navigation['reached_district_target_count']}/{navigation['district_target_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
