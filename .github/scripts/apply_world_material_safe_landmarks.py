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
\t\tKeys.WorldCampground,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/server/Systems/WorldFoundationService.luau",
\t\t"Campground is generated from primitive shelter, campsite, and prop geometry.",
\t\t"Campground",
\t\t{},
\t\t"Campground",
\t\tfalse
\t),''',
    '''\trecord(
\t\tKeys.WorldCampground,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Controllers/LandmarkAccentPresentationController.luau",
\t\t"The authored campground retains shelter, props, signage, and collision while four client-local tent and dormant-fire accents use the shared world material language to improve static readability.",
\t\t"LandmarkSilhouettePresentation",
\t\t{},
\t\t"Campground",
\t\tfalse
\t),''',
)
replace_once(
    registry,
    '''\trecord(
\t\tKeys.WorldCreekCrossing,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/server/Systems/WorldFoundationService.luau",
\t\t"Creek Crossing uses primitive water, bank, bridge, and route geometry.",
\t\t"CreekCrossing",
\t\t{},
\t\t"CreekCrossing",
\t\tfalse
\t),''',
    '''\trecord(
\t\tKeys.WorldCreekCrossing,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Controllers/LandmarkAccentPresentationController.luau",
\t\t"The authored crossing retains water, banks, bridge geometry, collision, and warning prop while four client-local warning and fallen-tree accents improve static readability.",
\t\t"LandmarkSilhouettePresentation",
\t\t{},
\t\t"CreekCrossing",
\t\tfalse
\t),''',
)
replace_once(
    registry,
    '''\trecord(
\t\tKeys.WorldRockyOverlook,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/server/Systems/WorldFoundationService.luau",
\t\t"Rocky Overlook is generated from primitive rock and plateau geometry.",
\t\t"RockyOverlook",
\t\t{},
\t\t"RockyOverlook",
\t\tfalse
\t),''',
    '''\trecord(
\t\tKeys.WorldRockyOverlook,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Controllers/LandmarkAccentPresentationController.luau",
\t\t"The authored overlook retains rock, plateau, guardrail, distant-light, signage, and collision geometry while four client-local guardrail and cliff-edge accents improve static readability.",
\t\t"LandmarkSilhouettePresentation",
\t\t{},
\t\t"RockyOverlook",
\t\tfalse
\t),''',
)

registry_test = "games/living-kingdoms/tests/VisualAssetContractsConfig.test.luau"
replace_once(
    registry_test,
    '''\t{
\t\tcontracts.AssetKeys.WorldRangerStation,
\t\tcontracts.AssetKeys.WorldMilitaryRoadblock,
\t}''',
    '''\t{
\t\tcontracts.AssetKeys.WorldRangerStation,
\t\tcontracts.AssetKeys.WorldMilitaryRoadblock,
\t\tcontracts.AssetKeys.WorldCampground,
\t\tcontracts.AssetKeys.WorldCreekCrossing,
\t\tcontracts.AssetKeys.WorldRockyOverlook,
\t}''',
)

roadmap = "docs/roadmap/VISUAL-PRODUCTION-TRACK.md"
replace_once(
    roadmap,
    '''  - Ranger Station now receives four client-local roof/mast silhouette accents and Military Roadblock receives six checkpoint/lamp accents. Both landmarks exist from world construction; the lookout objective area and extraction clearing remain explicitly excluded.
  - The landmark-accent layer uses two global workspace connections, zero per-landmark connections, zero frame loops, zero timers, zero remotes, and no server runtime change. All ten parts are welded, massless, non-collidable, non-touchable, and non-queryable.
  - Still required: Studio gameplay-camera, terrain-clipping, prompt, extraction-zone, and long-distance review; final world/interactable materials, effects, and audio; remaining landmark dressing, lighting, fog, ambience, accessibility, and representative performance evidence.''',
    '''  - Ranger Station, Military Roadblock, Campground, Creek Crossing, and Rocky Overlook now share a bounded client-local landmark accent system. The lookout objective area and extraction clearing remain explicitly excluded.
  - The landmark-accent layer uses two global workspace connections, zero per-landmark connections, zero frame loops, zero timers, zero remotes, and no server runtime change. Its current five-landmark maximum is 22 welded, massless, non-collidable, non-touchable, and non-queryable parts.
  - `WorldMaterialLanguageConfig` now defines ten immutable semantic roles for infrastructure, security, camp, crossing, and overlook presentation plus explicit no-authority, no-destination, no-hidden-state, geometry-plus-material, and production-approval rules.
  - Still required: Studio gameplay-camera, terrain-clipping, prompt, extraction-zone, and long-distance review; final authored world/interactable materials, effects, and audio; lighting, fog, ambience, accessibility, and representative performance evidence.''',
)

inventory = "docs/specifications/visual-placeholder-inventory.md"
replace_once(
    inventory,
    "| Landmark | Campground | Primitive placeholder | Part-built shelters, campsite, and props | VIS-0105 |",
    "| Landmark | Campground | Primitive placeholder | `WorldFoundationService` retains shelters, props, signage, and collision; `LandmarkAccentPresentationFactory` and controller add four client-local tent/dead-fire accents from the shared material language | VIS-0105 |",
)
replace_once(
    inventory,
    "| Landmark | Creek Crossing | Primitive placeholder | Part-built water, banks, bridge, and route geometry | VIS-0105 |",
    "| Landmark | Creek Crossing | Primitive placeholder | `WorldFoundationService` retains water, banks, bridge, warning prop, and collision; `LandmarkAccentPresentationFactory` and controller add four client-local warning/fallen-tree accents | VIS-0105 |",
)
replace_once(
    inventory,
    "| Landmark | Rocky Overlook | Primitive placeholder | Primitive plateau and rock composition | VIS-0105 |",
    "| Landmark | Rocky Overlook | Primitive placeholder | `WorldFoundationService` retains plateau, rocks, guardrail, lights, signage, and collision; `LandmarkAccentPresentationFactory` and controller add four client-local guardrail/cliff-edge accents | VIS-0105 |",
)
replace_once(
    inventory,
    "Continue VIS-0105 with world-material planning and the remaining safe landmark silhouettes while keeping Studio route/landmark/cache/relay/extraction review, final effects/audio, canonical operative art, class-action cues, avatar-scale coverage, accessibility, and representative performance evidence pending.",
    "Continue VIS-0105 with Studio review and authored world/interactable material replacement planning while keeping the lookout objective and extraction clearing behind their validated mission boundaries; final effects/audio, canonical operative art, class-action cues, avatar-scale coverage, accessibility, and representative performance evidence remain pending.",
)

print("world material and safe landmark integration staged")
