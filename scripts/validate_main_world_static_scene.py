#!/usr/bin/env python3
"""Guard the dedicated Main World's pre-runtime static-scene stabilization contract.

Recovered Studio presentation geometry includes unanchored BaseParts. Gameplay
runtime is intentionally disabled in the dedicated Main World, so those parts
must be stabilized by a tiny bootstrap-only pass without broadening runtime
authority or freezing roots that are intended to remain dynamic.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games" / "living-kingdoms"
PROJECT = GAME / "main-world.project.json"
CONFIG = GAME / "src" / "shared" / "Config" / "MainWorldBootstrapAllowlistConfig.luau"
SERVER = GAME / "src" / "main-world" / "server" / "MainWorldServer.server.luau"
STABILIZER = GAME / "src" / "main-world" / "server" / "MainWorldStaticSceneStabilizer.luau"

EXPECTED_DYNAMIC_ROOTS = {"NPCs"}
EXPECTED_STABILIZER_MOUNT = "src/main-world/server/MainWorldStaticSceneStabilizer.luau"
EXPECTED_SERVER_MOUNT = "src/main-world/server/MainWorldServer.server.luau"


def read(path: Path) -> str:
    if not path.exists():
        raise RuntimeError(f"required static-scene source is missing: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def table_strings(source: str, field: str) -> list[str]:
    pattern = rf"\b{re.escape(field)}\s*=\s*table\.freeze\(\{{(.*?)\}}\),"
    match = re.search(pattern, source, flags=re.DOTALL)
    if not match:
        raise RuntimeError(f"bootstrap config is missing table field {field!r}")
    return re.findall(r'"([^"\n]+)"', match.group(1))


def main() -> int:
    project = json.loads(read(PROJECT))
    config = read(CONFIG)
    server = read(SERVER)
    stabilizer = read(STABILIZER)

    try:
        world = project["tree"]["Workspace"]["LivingKingdomsMainWorld"]
        server_scripts = project["tree"]["ServerScriptService"]
    except (KeyError, TypeError) as exc:
        raise RuntimeError("Main World project tree is malformed") from exc

    if not isinstance(world, dict) or not isinstance(server_scripts, dict):
        raise RuntimeError("Main World project roots must be objects")

    world_mounts = {name for name in world if not name.startswith("$")}
    static_roots = set(table_strings(config, "StaticRootNames"))
    dynamic_roots = set(table_strings(config, "DynamicRootNames"))

    if not static_roots:
        raise RuntimeError("Main World static-scene allowlist must not be empty")
    if static_roots & dynamic_roots:
        overlap = ", ".join(sorted(static_roots & dynamic_roots))
        raise RuntimeError(f"Main World roots cannot be both static and dynamic: {overlap}")
    if dynamic_roots != EXPECTED_DYNAMIC_ROOTS:
        raise RuntimeError(
            "Main World dynamic-root contract drifted; expected only NPCs, got: "
            + ", ".join(sorted(dynamic_roots))
        )

    classified = static_roots | dynamic_roots
    missing_classification = sorted(world_mounts - classified)
    stale_classification = sorted(classified - world_mounts)
    if missing_classification or stale_classification:
        details = []
        if missing_classification:
            details.append("unclassified=" + ",".join(missing_classification))
        if stale_classification:
            details.append("not-mounted=" + ",".join(stale_classification))
        raise RuntimeError("Main World root classification is incomplete: " + "; ".join(details))

    if not re.search(r"\bRuntimeEnabled\s*=\s*false\b", config):
        raise RuntimeError("static-scene stabilization must not enable Main World gameplay runtime")
    if not re.search(r"\bEnabled\s*=\s*true\b", config):
        raise RuntimeError("Main World StaticSceneStabilization must be explicitly enabled")
    if "static-scene-stabilization" not in table_strings(config, "AllowedResponsibilities"):
        raise RuntimeError("bootstrap allowlist must declare static-scene-stabilization responsibility")

    main_server = server_scripts.get("MainWorldServer")
    stabilizer_mount = server_scripts.get("MainWorldStaticSceneStabilizer")
    if not isinstance(main_server, dict) or main_server.get("$path") != EXPECTED_SERVER_MOUNT:
        raise RuntimeError("dedicated Main World server entry point mount drifted")
    if not isinstance(stabilizer_mount, dict) or stabilizer_mount.get("$path") != EXPECTED_STABILIZER_MOUNT:
        raise RuntimeError("Main World static-scene stabilizer must be mounted as a ModuleScript source")

    executable_server_paths = [
        str(node.get("$path"))
        for name, node in server_scripts.items()
        if not name.startswith("$") and isinstance(node, dict) and str(node.get("$path", "")).endswith(".server.luau")
    ]
    if executable_server_paths != [EXPECTED_SERVER_MOUNT]:
        raise RuntimeError(
            "Main World must retain exactly one executable server entry point: "
            + ", ".join(executable_server_paths)
        )

    stabilize_call = server.find("MainWorldStaticSceneStabilizer.stabilize")
    runtime_gate = server.find("if not Config.RuntimeEnabled then")
    if stabilize_call < 0:
        raise RuntimeError("Main World server does not invoke the static-scene stabilizer")
    if runtime_gate < 0:
        raise RuntimeError("Main World server lost its disabled-runtime gate")
    if stabilize_call > runtime_gate:
        raise RuntimeError("static-scene stabilization must run before the disabled-runtime early return")
    # The guarantee is that the server resolves the world root from the configured
    # name and from nothing else. Pinning the exact call text also pinned the
    # absence of a timeout argument, so adding a bound to that wait -- which is
    # required, since an unbounded WaitForChild parks the script on a yield no
    # error handling can interrupt -- read as a violation. Match the receiver and
    # its first argument instead, and additionally reject a second world-root
    # lookup, which the old substring check could not see.
    world_root_waits = re.findall(r"Workspace:WaitForChild\(([^)]*)\)", server)
    if len(world_root_waits) != 1:
        raise RuntimeError(
            "Main World server must resolve the world root exactly once, found "
            f"{len(world_root_waits)}"
        )
    if world_root_waits[0].split(",")[0].strip() != "stabilization.WorldRootName":
        raise RuntimeError("Main World server must resolve only the configured world root")

    required_stabilizer_fragments = (
        'root:IsA("BasePart")',
        'descendant:IsA("BasePart")',
        "root.Anchored = true",
        "descendant.Anchored = true",
        "worldRoot:FindFirstChild(rootName)",
        'assert(root ~= nil, string.format("Main World static root %q is missing", rootName))',
    )
    missing_fragments = [fragment for fragment in required_stabilizer_fragments if fragment not in stabilizer]
    if missing_fragments:
        raise RuntimeError(
            "Main World stabilizer lost required fail-closed behavior: " + ", ".join(missing_fragments)
        )
    if "NPCs" in stabilizer:
        raise RuntimeError("stabilizer implementation must remain generic and must not hard-code dynamic NPC roots")

    print(
        "[main-world-static-scene] OK — "
        f"{len(static_roots)} static roots + {len(dynamic_roots)} dynamic root classify all "
        f"{len(world_mounts)} Main World mounts; gameplay runtime remains disabled"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
