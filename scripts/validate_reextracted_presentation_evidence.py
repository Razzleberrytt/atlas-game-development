#!/usr/bin/env python3
"""Validate BA-005 recovered UI/particle presentation evidence."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_PATH = ROOT / "docs" / "migration" / "current" / "reextracted-presentation-evidence.json"
SOURCE_SHA = "e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"[presentation-evidence] ERROR: {message}")


def close(actual: object, expected: float, epsilon: float = 1e-7) -> bool:
    return abs(float(actual) - expected) <= epsilon


def main() -> int:
    evidence = json.loads(EVIDENCE_PATH.read_text(encoding="utf-8"))
    require(evidence["status"] == "BA-005_PRESENTATION_EVIDENCE_V1", "status mismatch")
    require(evidence["source_rbxl"]["sha256"] == SOURCE_SHA, "source SHA mismatch")
    require(evidence["source_rbxl"]["bytes"] == 1639392, "source byte count mismatch")

    generated = evidence["full_presentation_property_json"]
    require(generated["workspace_property_rows"] == 1742, "Workspace presentation row count mismatch")
    require(generated["bytes"] == 1660969, "generated presentation JSON byte count mismatch")
    require(
        generated["sha256"] == "e8142dc973d0dd17673f0584d02643cf42938335562227530cd741451f4b99eb",
        "generated presentation JSON SHA mismatch",
    )

    classes = evidence["coverage"]["classes"]
    require(classes["Part"] == 1305, "Part coverage mismatch")
    require(classes["Model"] == 211, "Model coverage mismatch")
    require(classes["PointLight"] == 146, "PointLight coverage mismatch")
    require(classes["ParticleEmitter"] == 31, "ParticleEmitter coverage mismatch")
    require(classes["TextLabel"] == 10, "TextLabel coverage mismatch")
    require(classes["SurfaceGui"] == 2, "SurfaceGui coverage mismatch")
    require(evidence["coverage"]["unsupported_allowed_properties"] == [], "allowlisted decode failures present")

    portal = evidence["dungeon_portal"]
    require(portal["identity_rows"] == 10, "portal identity count mismatch")
    require(portal["property_backed_rows"] == 9, "portal property-backed count mismatch")
    require(portal["generated_container_rows"] == 1, "portal generated-container count mismatch")

    surface = portal["surface_gui"]
    require(surface["source_id"] == 209, "SurfaceGui source ID mismatch")
    props = surface["properties"]
    require(props["CanvasSize"] == [800.0, 600.0], "SurfaceGui canvas mismatch")
    require(props["Face"] == 5, "SurfaceGui face mismatch")
    require(props["PixelsPerStud"] == 50.0, "SurfaceGui PixelsPerStud mismatch")
    require(props["Enabled"] is True and props["AlwaysOnTop"] is False, "SurfaceGui flags mismatch")

    label = portal["text_label"]
    require(label["source_id"] == 210, "TextLabel source ID mismatch")
    props = label["properties"]
    require(props["Text"] == "ENTER THE DEPTHS\n[G] to enter dungeon", "recovered portal text mismatch")
    require(props["TextScaled"] is True and props["TextWrapped"] is True, "TextLabel scaling/wrapping mismatch")
    require(props["Visible"] is True, "TextLabel visibility mismatch")
    require(props["Position"]["x"] == {"scale": 0.0, "offset": 0}, "TextLabel X position mismatch")
    require(props["Position"]["y"] == {"scale": 0.0, "offset": 0}, "TextLabel Y position mismatch")
    require(props["Size"]["x"] == {"scale": 1.0, "offset": 0}, "TextLabel X size mismatch")
    require(props["Size"]["y"] == {"scale": 1.0, "offset": 0}, "TextLabel Y size mismatch")
    require(props["TextXAlignment"] == 2 and props["TextYAlignment"] == 1, "TextLabel alignment mismatch")

    emitter = portal["particle_emitter"]
    require(emitter["source_id"] == 207, "ParticleEmitter source ID mismatch")
    props = emitter["properties"]
    require(props["Texture"] == "rbxassetid://241876674", "portal texture mismatch")
    require(props["Rate"] == 40.0, "portal particle rate mismatch")
    require(props["Lifetime"] == [2.0, 3.0], "portal lifetime mismatch")
    require(props["Speed"] == [1.0, 3.0], "portal speed mismatch")
    require(props["SpreadAngle"] == [360.0, 360.0], "portal spread mismatch")
    require(props["Acceleration"] == [0.0, 2.0, 0.0], "portal acceleration mismatch")
    require(len(props["Color"]) == 2, "portal color sequence length mismatch")
    require(len(props["Size"]) == 3, "portal size sequence length mismatch")
    require(len(props["Transparency"]) == 3, "portal transparency sequence length mismatch")
    require(close(props["Size"][1]["time"], 0.5) and close(props["Size"][1]["value"], 2.0), "portal size midpoint mismatch")
    require(close(props["Transparency"][1]["value"], 0.20000000298023224), "portal transparency midpoint mismatch")

    print(
        "[presentation-evidence] OK: 1,742 Workspace rows, "
        "portal SurfaceGui/TextLabel/ParticleEmitter evidence verified"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
