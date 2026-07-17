from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected one match in {path}, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


registry = "games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau"
replace_once(
    registry,
    '''\trecord(
\t\tKeys.ObjectiveRelayConsoleModel,
\t\tFamilyIds.Objective,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/server/Systems/MissionDirectorService.luau",
\t\t"Relay console is generated from primitive Parts, a status lamp, and a ProximityPrompt.",
\t\t"RelayConsole",
\t\t{ "InteractionAttachment", "StatusAttachment" },
\t\t"objective.restore-lookout-relay",
\t\tfalse
\t),''',
    '''\trecord(
\t\tKeys.ObjectiveRelayConsoleModel,
\t\tFamilyIds.Objective,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Controllers/MissionObjectPresentationController.luau",
\t\t"The authoritative relay body, lamp, and prompt remain unchanged while an eleven-part client-local procedural shell provides standby, restore, and online readability from validated safe mission snapshots.",
\t\t"RelayConsolePresentation",
\t\t{},
\t\t"objective.restore-lookout-relay",
\t\tfalse
\t),''',
)
replace_once(
    registry,
    '''\trecord(
\t\tKeys.ExtractionBeaconModel,
\t\tFamilyIds.Extraction,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/server/Systems/MissionDirectorService.luau",
\t\t"Extraction is represented by a neon pillar, light, and billboard marker.",
\t\t"ExtractionBeacon",
\t\t{ "MarkerAttachment" },
\t\t"mission.extraction-clearing",
\t\tfalse
\t),''',
    '''\trecord(
\t\tKeys.ExtractionBeaconModel,
\t\tFamilyIds.Extraction,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Controllers/MissionObjectPresentationController.luau",
\t\t"The server creates extraction only after unlock; a twelve-part client-local procedural package then provides open, holdout, success, and failure readability from validated safe mission snapshots.",
\t\t"ExtractionBeaconPresentation",
\t\t{},
\t\t"mission.extraction-clearing",
\t\tfalse
\t),''',
)

registry_test = "games/living-kingdoms/tests/VisualAssetContractsConfig.test.luau"
replace_once(
    registry_test,
    '''assertThat(#supplyCache.requiredAttachmentNames == 0, "procedural supply cache must not claim authored attachments")
assertThat(
\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,
\t"standard hostile must remain honestly marked as primitive geometry"
)''',
    '''assertThat(#supplyCache.requiredAttachmentNames == 0, "procedural supply cache must not claim authored attachments")
local relayConsole = config.ByKey[contracts.AssetKeys.ObjectiveRelayConsoleModel]
assertThat(relayConsole.statusId == contracts.StatusIds.PrimitivePlaceholder, "relay console must remain primitive")
assertThat(
\trelayConsole.runtimeOwnerPath == "src/client/Controllers/MissionObjectPresentationController.luau",
\t"relay console registry must name the mission-object presentation owner"
)
assertThat(relayConsole.expectedRootName == "RelayConsolePresentation", "relay presentation root drifted")
assertThat(#relayConsole.requiredAttachmentNames == 0, "procedural relay must not claim authored attachments")
local extractionBeacon = config.ByKey[contracts.AssetKeys.ExtractionBeaconModel]
assertThat(extractionBeacon.statusId == contracts.StatusIds.PrimitivePlaceholder, "extraction beacon must remain primitive")
assertThat(
\textractionBeacon.runtimeOwnerPath == "src/client/Controllers/MissionObjectPresentationController.luau",
\t"extraction registry must name the mission-object presentation owner"
)
assertThat(extractionBeacon.expectedRootName == "ExtractionBeaconPresentation", "extraction presentation root drifted")
assertThat(#extractionBeacon.requiredAttachmentNames == 0, "procedural extraction must not claim authored attachments")
assertThat(
\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,
\t"standard hostile must remain honestly marked as primitive geometry"
)''',
)

roadmap = "docs/roadmap/VISUAL-PRODUCTION-TRACK.md"
replace_once(
    roadmap,
    '''- [~] **VIS-0105 — Replace world, supply, and objective placeholders.**
  - The authored rifle-ammunition cache now receives a 13-part client-local procedural supply case with rails, latches, handle, signal band, surface label, empty tray, and one motorized lid around the unchanged server-owned `3.6 x 1.8 x 2.6` collidable root.
  - Existing per-operative consumed disclosure opens and darkens only that player's case, exposes the empty tray, changes the label from `RIFLE AMMO` to `EMPTY`, and disables only the local prompt; consumed messages are remembered before cache lookup for streaming safety.
  - The cache layer uses three global connections, zero per-cache connections, zero frame loops, zero timers, zero new remotes, and no server runtime change. Cleanup restores local root visibility and prompt state.
  - Still required: Studio gameplay-camera and interaction review, final cache materials/effects/audio, world dressing, landmarks, objective equipment, extraction presentation, route cues, lighting, fog, ambience, and representative performance evidence.
  - Objective art follows the P8 authored chain and may not disclose hidden or inactive truth.''',
    '''- [~] **VIS-0105 — Replace world, supply, and objective placeholders.**
  - The authored rifle-ammunition cache now receives a 13-part client-local procedural supply case with rails, latches, handle, signal band, surface label, empty tray, and one motorized lid around the unchanged server-owned `3.6 x 1.8 x 2.6` collidable root.
  - Existing per-operative consumed disclosure opens and darkens only that player's case, exposes the empty tray, changes the label from `RIFLE AMMO` to `EMPTY`, and disables only the local prompt; consumed messages are remembered before cache lookup for streaming safety.
  - The authoritative relay console now receives an eleven-part client-local shell with geometry-plus-text standby, restore, and online states. The authoritative extraction beacon receives a twelve-part base, mast-fin, crown, lens, direction-panel, and label package only after the server has already created the unlocked beacon.
  - Validated monotonic safe mission snapshots drive relay inactive/active/completed and extraction exfiltration/holdout/success/failure presentation. Inconsistent facts restore the primitive server objects instead of fabricating mission truth.
  - The mission-object layer uses three global connections, zero per-object connections, zero frame loops, zero timers, zero new remotes, and no server runtime change. Cleanup restores primitive root visibility, lights, and marker UI.
  - Still required: Studio gameplay-camera, prompt, extraction-zone, and long-distance review; final cache/objective/extraction materials, effects, and audio; world dressing, landmarks, route cues, lighting, fog, ambience, accessibility, and representative performance evidence.
  - Objective art follows the P8 authored chain and may not disclose hidden or inactive truth.''',
)

inventory = "docs/specifications/visual-placeholder-inventory.md"
replace_once(
    inventory,
    "| Objective | Relay console | Primitive placeholder | `MissionDirectorService`; primitive console, lamp, and ProximityPrompt | VIS-0105 / P8 |",
    "| Objective | Relay console | Primitive placeholder | `MissionDirectorService` retains the authoritative body/lamp/prompt; `MissionObjectPresentationFactory` and `MissionObjectPresentationController` add an eleven-part standby/restore/online procedural shell | VIS-0105 / P8 |",
)
replace_once(
    inventory,
    "| Extraction | Extraction beacon | Primitive placeholder | `MissionDirectorService`; neon signal pillar, light, and billboard | VIS-0105 / P10 |",
    "| Extraction | Extraction beacon | Primitive placeholder | `MissionDirectorService` creates the authoritative beacon only after unlock; `MissionObjectPresentationFactory` and `MissionObjectPresentationController` add a twelve-part open/holdout/outcome procedural package | VIS-0105 / P10 |",
)
replace_once(
    inventory,
    "Continue VIS-0105 with objective, extraction, and major-world readability while keeping Studio cache review, final cache materials/effects/audio, canonical operative art, class-action cues, avatar-scale coverage, and representative performance evidence pending.",
    "Continue VIS-0105 with major-world and route readability while keeping Studio cache/relay/extraction review, final interactable materials/effects/audio, canonical operative art, class-action cues, avatar-scale coverage, accessibility, and representative performance evidence pending.",
)

print("mission object readability integration staged")
