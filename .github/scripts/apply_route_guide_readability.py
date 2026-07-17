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
\t\tKeys.WorldLoggingRoad,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/server/Systems/WorldFoundationService.luau",
\t\t"Logging Road is a sequence of primitive route segments and tire tracks.",
\t\t"LoggingRoad",
\t\t{},
\t\t"LoggingRoad",
\t\tfalse
\t),''',
    '''\trecord(
\t\tKeys.WorldLoggingRoad,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Controllers/RouteGuidePresentationController.luau",
\t\t"Existing authored logging-road and switchback-trail segments retain all server geometry and collision while paired client-local guide posts improve route-edge readability without destination labels or extraction cues.",
\t\t"RouteGuidePresentation",
\t\t{},
\t\t"LoggingRoad",
\t\tfalse
\t),''',
)

test = "games/living-kingdoms/tests/VisualAssetContractsConfig.test.luau"
replace_once(
    test,
    '''assertThat(#extractionBeacon.requiredAttachmentNames == 0, "procedural extraction must not claim authored attachments")
assertThat(
\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,
\t"standard hostile must remain honestly marked as primitive geometry"
)''',
    '''assertThat(#extractionBeacon.requiredAttachmentNames == 0, "procedural extraction must not claim authored attachments")
local loggingRoad = config.ByKey[contracts.AssetKeys.WorldLoggingRoad]
assertThat(loggingRoad.statusId == contracts.StatusIds.PrimitivePlaceholder, "route guides must remain primitive")
assertThat(
\tloggingRoad.runtimeOwnerPath == "src/client/Controllers/RouteGuidePresentationController.luau",
\t"logging-road registry must name the route-guide presentation owner"
)
assertThat(loggingRoad.expectedRootName == "RouteGuidePresentation", "route-guide root contract drifted")
assertThat(#loggingRoad.requiredAttachmentNames == 0, "procedural route guides must not claim attachments")
assertThat(
\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,
\t"standard hostile must remain honestly marked as primitive geometry"
)''',
)

roadmap = "docs/roadmap/VISUAL-PRODUCTION-TRACK.md"
replace_once(
    roadmap,
    '''  - The mission-object layer uses three global connections, zero per-object connections, zero frame loops, zero timers, zero new remotes, and no server runtime change. Cleanup restores primitive root visibility, lights, and marker UI.
  - Still required: Studio gameplay-camera, prompt, extraction-zone, and long-distance review; final cache/objective/extraction materials, effects, and audio; world dressing, landmarks, route cues, lighting, fog, ambience, accessibility, and representative performance evidence.''',
    '''  - The mission-object layer uses three global connections, zero per-object connections, zero frame loops, zero timers, zero new remotes, and no server runtime change. Cleanup restores primitive root visibility, lights, and marker UI.
  - Existing `LoggingRoad*` and `SwitchbackTrail*` parts now receive two client-local guide posts per segment, capped at 22 parts across the current eleven authored segments. Creek pieces, landmarks, objectives, and the extraction clearing are explicitly excluded; no destination text or future-state cue is created.
  - The route-guide layer uses two global workspace connections, zero per-segment connections, zero frame loops, zero timers, zero remotes, and no server runtime change.
  - Still required: Studio gameplay-camera, terrain-clipping, prompt, extraction-zone, and long-distance review; final world/interactable materials, effects, and audio; landmark dressing, lighting, fog, ambience, accessibility, and representative performance evidence.''',
)

inventory = "docs/specifications/visual-placeholder-inventory.md"
replace_once(
    inventory,
    "| Landmark | Logging Road | Primitive placeholder | Segmented road and tire-track geometry | VIS-0105 |",
    "| Landmark | Logging Road | Primitive placeholder | `WorldFoundationService` retains authored road/trail geometry and collision; `RouteGuidePresentationFactory` and `RouteGuidePresentationController` add paired client-local edge guides with no destination or extraction cue | VIS-0105 |",
)
replace_once(
    inventory,
    "Continue VIS-0105 with major-world and route readability while keeping Studio cache/relay/extraction review, final interactable materials/effects/audio, canonical operative art, class-action cues, avatar-scale coverage, accessibility, and representative performance evidence pending.",
    "Continue VIS-0105 with major-landmark dressing and world-material planning while keeping Studio route/cache/relay/extraction review, final effects/audio, canonical operative art, class-action cues, avatar-scale coverage, accessibility, and representative performance evidence pending.",
)

print("route guide readability integration staged")
