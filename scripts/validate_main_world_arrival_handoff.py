#!/usr/bin/env python3
"""Validate the dedicated Main World arrival-to-road traversal handoff."""

from __future__ import annotations

import gzip
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games" / "living-kingdoms"
PROJECT = GAME / "main-world.project.json"
ARRIVAL = GAME / "assets" / "recovered-world" / "models" / "main-world-studio-2026-08-11" / "MainWorld-ArrivalTraversal.model.json"
ROUTES = GAME / "assets" / "recovered-world" / "models" / "main-world-studio-2026-08-11" / "MainWorld-RegionalRoutes.model.json"
PACKED_HUB = GAME / "assets" / "recovered-world" / "models" / "main-world-studio-2026-08-11" / "compressed" / "MainWorld-HubCore.model.json.gz"
LIFECYCLE = GAME / "src" / "shared" / "Config" / "MainWorldLifecycleConfig.luau"

EXPECTED_MOUNT = "assets/recovered-world/models/main-world-studio-2026-08-11/MainWorld-ArrivalTraversal.model.json"
EXPECTED_TARGET = 'TargetPath = "Workspace/LivingKingdomsMainWorld/HubCore/Arrival/SpawnLocation"'
EPSILON = 0.051
MAX_STEP_DROP = 1.0
MIN_WIDTH = 12.0


def read_json(path: Path) -> dict:
    if not path.exists():
        raise RuntimeError(f"required Main World arrival source is missing: {path.relative_to(ROOT)}")
    return json.loads(path.read_text(encoding="utf-8"))


def find_named(node: dict, name: str) -> dict | None:
    if node.get("Name") == name:
        return node
    for child in node.get("Children", []):
        found = find_named(child, name)
        if found is not None:
            return found
    return None


def parts_with_prefix(node: dict, prefix: str) -> list[dict]:
    found: list[dict] = []
    if str(node.get("Name", "")).startswith(prefix):
        found.append(node)
    for child in node.get("Children", []):
        found.extend(parts_with_prefix(child, prefix))
    return found


def geometry(node: dict) -> tuple[float, float, float, float, float, float]:
    properties = node.get("Properties")
    if not isinstance(properties, dict):
        raise RuntimeError(f"arrival part {node.get('Name')!r} is missing Properties")
    cframe = properties.get("CFrame")
    size = properties.get("Size")
    if not isinstance(cframe, list) or len(cframe) < 3 or not isinstance(size, list) or len(size) != 3:
        raise RuntimeError(f"arrival part {node.get('Name')!r} is missing axis-aligned geometry")
    return (
        float(cframe[0]),
        float(cframe[1]),
        float(cframe[2]),
        float(size[0]),
        float(size[1]),
        float(size[2]),
    )


def top(node: dict) -> float:
    _, y, _, _, sy, _ = geometry(node)
    return y + sy / 2.0


def south(node: dict) -> float:
    _, _, z, _, _, sz = geometry(node)
    return z - sz / 2.0


def north(node: dict) -> float:
    _, _, z, _, _, sz = geometry(node)
    return z + sz / 2.0


def overlaps_x(a: dict, b: dict) -> bool:
    ax, _, _, asx, _, _ = geometry(a)
    bx, _, _, bsx, _, _ = geometry(b)
    return min(ax + asx / 2.0, bx + bsx / 2.0) + EPSILON >= max(ax - asx / 2.0, bx - bsx / 2.0)


def assert_static_walkable(node: dict) -> None:
    properties = node.get("Properties", {})
    if properties.get("Anchored") is not True or properties.get("CanCollide") is not True:
        raise RuntimeError(f"arrival handoff part must be anchored and collidable: {node.get('Name')}")
    _, _, _, sx, _, _ = geometry(node)
    if sx < MIN_WIDTH:
        raise RuntimeError(f"arrival handoff narrowed below {MIN_WIDTH:g} studs: {node.get('Name')}")


def main() -> int:
    project = read_json(PROJECT)
    try:
        mount = project["tree"]["Workspace"]["LivingKingdomsMainWorld"]["ArrivalTraversal"]
    except (KeyError, TypeError) as exc:
        raise RuntimeError("Main World project does not mount ArrivalTraversal") from exc
    if not isinstance(mount, dict) or mount.get("$path") != EXPECTED_MOUNT:
        raise RuntimeError("Main World ArrivalTraversal mount drifted")

    lifecycle = LIFECYCLE.read_text(encoding="utf-8")
    if EXPECTED_TARGET not in lifecycle or "ColdJoinStartsHere = true" not in lifecycle:
        raise RuntimeError("Main World lifecycle no longer points cold joins at the recovered arrival spawn")

    hub = json.loads(gzip.decompress(PACKED_HUB.read_bytes()).decode("utf-8"))
    spawn = find_named(hub, "SpawnLocation")
    if spawn is None or spawn.get("ClassName") != "SpawnLocation":
        raise RuntimeError("packed HubCore lost its authored SpawnLocation")
    sx, sy, sz, ssx, ssy, ssz = geometry(spawn)
    if (sx, sy, sz, ssx, ssy, ssz) != (0.0, 7.0, 30.0, 6.0, 1.0, 6.0):
        raise RuntimeError("authored SpawnLocation transform or size drifted")
    spawn_properties = spawn.get("Properties", {})
    if spawn_properties.get("Enabled") is not True or spawn_properties.get("Anchored") is not True:
        raise RuntimeError("authored SpawnLocation must remain enabled and anchored")

    routes = read_json(ROUTES)
    spawn_apron = find_named(routes, "main_world.regional_route.spawn_apron")
    north_trunk = find_named(routes, "main_world.regional_route.north_trunk")
    if spawn_apron is None or north_trunk is None:
        raise RuntimeError("regional route network lost the spawn apron or north trunk")

    arrival = read_json(ARRIVAL)
    landing = find_named(arrival, "main_world.arrival_handoff.landing")
    if landing is None:
        raise RuntimeError("arrival handoff landing is missing")
    steps = parts_with_prefix(arrival, "main_world.arrival_handoff.step.")
    if len(steps) != 8:
        raise RuntimeError(f"arrival handoff requires exactly 8 shallow steps, found {len(steps)}")
    steps.sort(key=lambda node: geometry(node)[2])

    assert_static_walkable(landing)
    if abs(top(landing) - top(spawn)) > EPSILON:
        raise RuntimeError("arrival landing is not flush with the authored SpawnLocation")
    if abs(south(landing) - north(spawn)) > EPSILON or not overlaps_x(landing, spawn):
        raise RuntimeError("arrival landing does not touch the north edge of the authored SpawnLocation")

    previous = landing
    previous_top = top(landing)
    for index, step in enumerate(steps, start=1):
        assert_static_walkable(step)
        if abs(south(step) - north(previous)) > EPSILON:
            raise RuntimeError(f"arrival handoff has a horizontal gap before step {index}")
        current_top = top(step)
        drop = previous_top - current_top
        if drop <= 0.0 or drop > MAX_STEP_DROP + EPSILON:
            raise RuntimeError(f"arrival step {index} vertical drop is unsafe: {drop:.3f} studs")
        previous = step
        previous_top = current_top

    if abs(previous_top - top(spawn_apron)) > EPSILON:
        raise RuntimeError("arrival handoff final step is not flush with the regional spawn apron")
    if not overlaps_x(previous, north_trunk):
        raise RuntimeError("arrival handoff final step does not overlap the north-trunk route")
    _, _, trunk_z, _, _, trunk_sz = geometry(north_trunk)
    if not (trunk_z - trunk_sz / 2.0 - EPSILON <= geometry(previous)[2] <= trunk_z + trunk_sz / 2.0 + EPSILON):
        raise RuntimeError("arrival handoff final step falls outside the north-trunk route span")

    portal = find_named(hub, "PortalFrame")
    if portal is None:
        raise RuntimeError("HubCore lost the expedition portal frame used for arrival-clearance validation")
    if south(landing) < north(portal) + 4.0 - EPSILON:
        raise RuntimeError("arrival descent intrudes into the expedition portal clearance zone")

    print(
        "[main-world-arrival-handoff] OK — authored spawn preserved at (0, 7, 30); "
        "16-stud landing + 8 shallow steps connect its north edge to the regional road"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
