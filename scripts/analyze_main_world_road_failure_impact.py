#!/usr/bin/env python3
"""Measure rooted failure impact across the Living Kingdoms Main World road graph.

Raw bridge/articulation counts answer whether the road graph is structurally
fragile, but not whether a failure affects only a harmless terminal spur or cuts
the player's arrival path off from multiple districts. This analysis roots the
road graph at the actual authored arrival handoff and simulates road-node and
road-edge failures without mutating recovered world source.
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from typing import Any, TypeVar

from main_world_metrics import ARRIVAL_ROAD, _graph_resilience
from validate_main_world_route_readability import (
    DISTRICT_TARGETS,
    ROAD_ROOT,
    point_on_road,
    project_world,
    reachable_roads,
    regional_roads,
    roads_touch,
)

T = TypeVar("T")
SCHEMA_VERSION = 1


def _build_adjacency(items: Sequence[T], adjacent: Callable[[T, T], bool]) -> tuple[list[str], dict[str, set[str]]]:
    names = [str(getattr(item, "name")) for item in items]
    if not names:
        raise RuntimeError("road failure analysis requires at least one graph node")
    if len(set(names)) != len(names):
        raise RuntimeError("road failure analysis requires unique graph node names")

    graph = {name: set() for name in names}
    for left_index, left in enumerate(items):
        for right in items[left_index + 1 :]:
            if adjacent(left, right):
                left_name = str(getattr(left, "name"))
                right_name = str(getattr(right, "name"))
                graph[left_name].add(right_name)
                graph[right_name].add(left_name)
    return names, graph


def _reachable_names_from_root(
    graph: dict[str, set[str]],
    root_name: str,
    *,
    removed_node: str | None = None,
    removed_edge: tuple[str, str] | None = None,
) -> set[str]:
    if root_name not in graph:
        raise RuntimeError(f"road failure analysis root is missing: {root_name}")
    if removed_node == root_name:
        return set()

    normalized_removed_edge = tuple(sorted(removed_edge)) if removed_edge is not None else None
    reached = {root_name}
    pending = [root_name]
    while pending:
        current = pending.pop()
        for neighbor in sorted(graph[current]):
            if neighbor == removed_node:
                continue
            if normalized_removed_edge == tuple(sorted((current, neighbor))):
                continue
            if neighbor not in reached:
                reached.add(neighbor)
                pending.append(neighbor)
    return reached


def _districts_reached(roads: Sequence[Any], reachable_names: set[str]) -> list[str]:
    return sorted(
        district
        for district, (x, z) in DISTRICT_TARGETS.items()
        if point_on_road(x, z, roads, reachable_names)
    )


def _district_support(roads: Sequence[Any]) -> dict[str, list[str]]:
    support: dict[str, list[str]] = {}
    for district, (x, z) in DISTRICT_TARGETS.items():
        supporting = []
        for road in roads:
            if point_on_road(x, z, roads, {road.name}):
                supporting.append(road.name)
        support[district] = sorted(supporting)
    return dict(sorted(support.items()))


def _node_failure_impacts(
    roads: Sequence[Any],
    graph: dict[str, set[str]],
    root_name: str,
    articulation_names: Sequence[str],
) -> list[dict[str, Any]]:
    all_names = set(graph)
    baseline_districts = set(_districts_reached(roads, all_names))
    impacts = []
    for removed_node in articulation_names:
        if removed_node == root_name:
            continue
        reachable = _reachable_names_from_root(graph, root_name, removed_node=removed_node)
        stranded = sorted(all_names - reachable - {removed_node})
        reached_districts = set(_districts_reached(roads, reachable))
        lost_districts = sorted(baseline_districts - reached_districts)
        impacts.append(
            {
                "removed_node": removed_node,
                "reachable_road_count": len(reachable),
                "stranded_road_count": len(stranded),
                "stranded_road_names": stranded,
                "lost_district_target_count": len(lost_districts),
                "lost_district_targets": lost_districts,
            }
        )
    return sorted(
        impacts,
        key=lambda impact: (
            -impact["lost_district_target_count"],
            -impact["stranded_road_count"],
            impact["removed_node"],
        ),
    )


def _bridge_failure_impacts(
    roads: Sequence[Any],
    graph: dict[str, set[str]],
    root_name: str,
    bridge_edges: Sequence[dict[str, str]],
    dead_end_names: set[str],
) -> list[dict[str, Any]]:
    all_names = set(graph)
    baseline_districts = set(_districts_reached(roads, all_names))
    impacts = []
    for bridge in bridge_edges:
        left = bridge["left"]
        right = bridge["right"]
        reachable = _reachable_names_from_root(graph, root_name, removed_edge=(left, right))
        stranded = sorted(all_names - reachable)
        reached_districts = set(_districts_reached(roads, reachable))
        lost_districts = sorted(baseline_districts - reached_districts)
        terminal_branch = len(stranded) == 1 and stranded[0] in dead_end_names
        impacts.append(
            {
                "left": left,
                "right": right,
                "reachable_road_count": len(reachable),
                "stranded_road_count": len(stranded),
                "stranded_road_names": stranded,
                "lost_district_target_count": len(lost_districts),
                "lost_district_targets": lost_districts,
                "terminal_branch": terminal_branch,
            }
        )
    return sorted(
        impacts,
        key=lambda impact: (
            -impact["lost_district_target_count"],
            -impact["stranded_road_count"],
            impact["left"],
            impact["right"],
        ),
    )


def analyze() -> dict[str, Any]:
    world = project_world()
    roads = regional_roads(world)
    baseline_reachable = reachable_roads(roads)
    road_names, graph = _build_adjacency(roads, roads_touch)
    all_names = set(road_names)
    if baseline_reachable != all_names:
        missing = sorted(all_names - baseline_reachable)
        raise RuntimeError("road failure analysis baseline is disconnected: " + ", ".join(missing))
    if ARRIVAL_ROAD not in graph:
        raise RuntimeError(f"arrival handoff road is missing from road graph: {ARRIVAL_ROAD}")
    if ROAD_ROOT not in graph:
        raise RuntimeError(f"route validation root is missing from road graph: {ROAD_ROOT}")

    baseline_from_arrival = _reachable_names_from_root(graph, ARRIVAL_ROAD)
    if baseline_from_arrival != all_names:
        missing = sorted(all_names - baseline_from_arrival)
        raise RuntimeError("arrival handoff cannot reach the complete road graph: " + ", ".join(missing))

    resilience = _graph_resilience(roads, roads_touch)
    dead_end_names = set(resilience["dead_end_node_names"])
    node_impacts = _node_failure_impacts(
        roads,
        graph,
        ARRIVAL_ROAD,
        resilience["articulation_point_names"],
    )
    bridge_impacts = _bridge_failure_impacts(
        roads,
        graph,
        ARRIVAL_ROAD,
        resilience["bridge_edges"],
        dead_end_names,
    )

    district_support = _district_support(roads)
    unsupported_districts = sorted(district for district, support in district_support.items() if not support)
    if unsupported_districts:
        raise RuntimeError("district targets lack road support: " + ", ".join(unsupported_districts))
    single_road_districts = sorted(district for district, support in district_support.items() if len(support) == 1)

    root_neighbors = sorted(graph[ARRIVAL_ROAD])
    largest_node_impact = node_impacts[0] if node_impacts else None
    largest_bridge_impact = bridge_impacts[0] if bridge_impacts else None

    return {
        "schema_version": SCHEMA_VERSION,
        "arrival_handoff_root": ARRIVAL_ROAD,
        "route_validation_root": ROAD_ROOT,
        "road_count": len(roads),
        "baseline_reachable_road_count": len(baseline_from_arrival),
        "baseline_district_target_count": len(_districts_reached(roads, baseline_from_arrival)),
        "arrival_root_degree": len(root_neighbors),
        "arrival_root_neighbor_names": root_neighbors,
        "arrival_root_is_articulation": ARRIVAL_ROAD in set(resilience["articulation_point_names"]),
        "resilience": resilience,
        "district_support": district_support,
        "single_road_district_target_count": len(single_road_districts),
        "single_road_district_targets": single_road_districts,
        "node_failure_impacts": node_impacts,
        "bridge_failure_impacts": bridge_impacts,
        "largest_non_root_node_failure_impact": largest_node_impact,
        "largest_bridge_failure_impact": largest_bridge_impact,
        "max_lost_districts_from_non_root_node_failure": (
            largest_node_impact["lost_district_target_count"] if largest_node_impact else 0
        ),
        "max_stranded_roads_from_non_root_node_failure": (
            largest_node_impact["stranded_road_count"] if largest_node_impact else 0
        ),
        "max_lost_districts_from_bridge_failure": (
            largest_bridge_impact["lost_district_target_count"] if largest_bridge_impact else 0
        ),
        "max_stranded_roads_from_bridge_failure": (
            largest_bridge_impact["stranded_road_count"] if largest_bridge_impact else 0
        ),
    }


@dataclass(frozen=True)
class _SyntheticNode:
    name: str


def _self_test() -> None:
    nodes = [_SyntheticNode(name) for name in ["A", "B", "C", "D"]]
    edges = {tuple(sorted(edge)) for edge in {("A", "B"), ("B", "C"), ("C", "D")}}

    def adjacent(left: _SyntheticNode, right: _SyntheticNode) -> bool:
        return tuple(sorted((left.name, right.name))) in edges

    _, graph = _build_adjacency(nodes, adjacent)
    assert _reachable_names_from_root(graph, "A") == {"A", "B", "C", "D"}
    assert _reachable_names_from_root(graph, "A", removed_node="B") == {"A"}
    assert _reachable_names_from_root(graph, "A", removed_edge=("B", "C")) == {"A", "B"}

    cycle_nodes = [_SyntheticNode(name) for name in ["A", "B", "C"]]
    cycle_edges = {tuple(sorted(edge)) for edge in {("A", "B"), ("B", "C"), ("C", "A")}}

    def cycle_adjacent(left: _SyntheticNode, right: _SyntheticNode) -> bool:
        return tuple(sorted((left.name, right.name))) in cycle_edges

    _, cycle_graph = _build_adjacency(cycle_nodes, cycle_adjacent)
    assert _reachable_names_from_root(cycle_graph, "A", removed_edge=("B", "C")) == {"A", "B", "C"}
    assert _reachable_names_from_root(cycle_graph, "A", removed_node="B") == {"A", "C"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--json", action="store_true", help="emit the full failure-impact document as JSON")
    mode.add_argument("--self-test", action="store_true", help="run deterministic synthetic failure simulations")
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        print("[main-world-road-impact] failure simulation self-test passed")
        return 0

    metrics = analyze()
    if args.json:
        print(json.dumps(metrics, indent=2, sort_keys=True))
        return 0

    node_impact = metrics["largest_non_root_node_failure_impact"]
    bridge_impact = metrics["largest_bridge_failure_impact"]
    node_summary = (
        "none"
        if node_impact is None
        else f"{node_impact['removed_node']} loses {node_impact['lost_district_target_count']} districts/"
        f"{node_impact['stranded_road_count']} roads"
    )
    bridge_summary = (
        "none"
        if bridge_impact is None
        else f"{bridge_impact['left']} <-> {bridge_impact['right']} loses "
        f"{bridge_impact['lost_district_target_count']} districts/{bridge_impact['stranded_road_count']} roads"
    )
    print(
        "[main-world-road-impact] OK — "
        f"arrival root degree {metrics['arrival_root_degree']}; "
        f"single-road districts {metrics['single_road_district_target_count']}/{metrics['baseline_district_target_count']}; "
        f"worst non-root node: {node_summary}; worst bridge: {bridge_summary}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
