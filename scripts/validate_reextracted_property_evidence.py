#!/usr/bin/env python3
"""Validate committed BA-005 property evidence and its generation contract."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUMMARY_PATH = ROOT / "docs" / "migration" / "current" / "reextracted-property-evidence.json"
MANIFEST_PATH = ROOT / "docs" / "migration" / "current" / "reextracted-property-evidence-manifest.json"

SOURCE_SHA = "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16"
WORKSPACE_ROWS = 1699


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"[property-evidence] ERROR: {message}")


def vec(actual: object, expected: list[float], label: str) -> None:
    require(isinstance(actual, list), f"{label} must be an array")
    require(len(actual) == len(expected), f"{label} length mismatch")
    for index, wanted in enumerate(expected):
        got = float(actual[index])
        require(abs(got - wanted) <= 1e-5, f"{label}[{index}] expected {wanted}, got {got}")


def main() -> int:
    summary = json.loads(SUMMARY_PATH.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    require(summary["status"] == "BA-005_PROPERTY_EVIDENCE_V1", "summary status mismatch")
    require(manifest["status"] == "BA-005_PROPERTY_EVIDENCE_V1", "manifest status mismatch")
    require(summary["source_rbxl"]["sha256"] == SOURCE_SHA, "summary source SHA mismatch")
    require(manifest["source_rbxl"]["sha256"] == SOURCE_SHA, "manifest source SHA mismatch")
    require(summary["source_rbxl"]["bytes"] == 1639392, "summary source byte count mismatch")
    require(manifest["source_rbxl"]["bytes"] == 1639392, "manifest source byte count mismatch")

    coverage = summary["coverage"]
    require(coverage["workspace_property_rows"] == WORKSPACE_ROWS, "Workspace property row count mismatch")
    require(manifest["full_property_json"]["workspace_property_rows"] == WORKSPACE_ROWS, "manifest row count mismatch")
    require(manifest["full_property_json"]["bytes"] == 1546379, "raw property JSON byte count mismatch")
    require(
        manifest["full_property_json"]["sha256"]
        == "078a64153fbc1d29409e326c924ba7bb1cd3cbe7137277697955af7c448708ea",
        "raw property JSON SHA mismatch",
    )
    require(coverage["unsupported_allowed_properties"] == [], "allowlisted property decode failures are present")

    require(coverage["classes"]["Part"] == 1305, "Part coverage mismatch")
    require(coverage["classes"]["Model"] == 211, "Model coverage mismatch")
    require(coverage["classes"]["PointLight"] == 146, "PointLight coverage mismatch")
    require(coverage["classes"]["Fire"] == 22, "Fire coverage mismatch")
    require(coverage["classes"]["Attachment"] == 12, "Attachment coverage mismatch")
    require(coverage["classes"]["SpawnLocation"] == 2, "SpawnLocation coverage mismatch")
    require(coverage["classes"]["ProximityPrompt"] == 1, "ProximityPrompt coverage mismatch")

    floor = summary["positive_controls"]["Workspace/BootstrapSafetyFloor"]
    spawn = summary["positive_controls"]["Workspace/BootstrapSafetySpawn"]
    vec(floor["CFrame"]["position"], [-224.0, -3.0, -208.0], "floor position")
    vec(floor["size"], [48.0, 6.0, 48.0], "floor size")
    require(floor["Anchored"] is True and floor["CanCollide"] is True, "floor flags mismatch")
    vec(spawn["CFrame"]["position"], [-224.0, 0.5, -208.0], "spawn position")
    vec(spawn["size"], [12.0, 1.0, 12.0], "spawn size")
    require(float(spawn["Transparency"]) == 1.0, "spawn transparency mismatch")
    require(spawn["Neutral"] is True, "spawn Neutral mismatch")

    structures = summary["subtrees"]["Workspace/WorldStructures"]
    hub = summary["subtrees"]["Workspace/HubTown"]
    path = summary["subtrees"]["Workspace/WorldPath"]
    resources = summary["subtrees"]["Workspace/Resources"]
    require(structures["cframe_rows"] == 894, "WorldStructures CFrame coverage mismatch")
    require(hub["cframe_rows"] == 157, "HubTown CFrame coverage mismatch")
    require(path["cframe_rows"] == 189 and path["segment_count"] == 189, "WorldPath coverage mismatch")
    require(resources["cframe_rows"] == 62, "Resources CFrame coverage mismatch")

    monolith = summary["selected_instances"]["Workspace/WorldStructures/DestinyMonolith/CoreTower"]
    portal = summary["selected_instances"]["Workspace/HubTown/DungeonPortal/PortalFrame"]
    vec(monolith["properties"]["CFrame"]["position"], [0.0, 200.0, -1500.0], "monolith position")
    vec(monolith["properties"]["size"], [80.0, 400.0, 80.0], "monolith size")
    vec(portal["properties"]["CFrame"]["position"], [0.0, 8.0, 22.0], "portal position")
    vec(portal["properties"]["size"], [10.0, 16.0, 4.0], "portal size")

    require(manifest["current_scope"]["runtime_activation"] is False, "property evidence must remain inert")
    require(manifest["current_scope"]["terrain_voxels_decoded"] is False, "terrain parity must not be claimed")
    require(manifest["current_scope"]["particle_sequences_decoded"] is False, "particle sequence parity must not be claimed")

    print(
        "[property-evidence] OK: 1,699 decoded Workspace rows, "
        "positive controls and authored-world coverage verified"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
