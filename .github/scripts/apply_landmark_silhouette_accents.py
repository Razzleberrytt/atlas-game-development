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
\t\tKeys.WorldRangerStation,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/server/Systems/WorldFoundationService.luau",
\t\t"Ranger Station landmark is generated from Parts and graybox signage.",
\t\t"RangerStation",
\t\t{},
\t\t"RangerStation",
\t\tfalse
\t),''',
    '''\trecord(
\t\tKeys.WorldRangerStation,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Controllers/LandmarkAccentPresentationController.luau",
\t\t"The authored station retains all geometry, collision, signage, spawn, and lights while four client-local roof and mast accents improve its static silhouette.",
\t\t"LandmarkSilhouettePresentation",
\t\t{},
\t\t"RangerStation",
\t\tfalse
\t),''',
)
replace_once(
    registry,
    '''\trecord(
\t\tKeys.WorldMilitaryRoadblock,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/server/Systems/WorldFoundationService.luau",
\t\t"Military Roadblock is generated from primitive vehicle, barrier, light, and prop geometry.",
\t\t"MilitaryRoadblock",
\t\t{},
\t\t"MilitaryRoadblock",
\t\tfalse
\t),''',
    '''\trecord(
\t\tKeys.WorldMilitaryRoadblock,
\t\tFamilyIds.World,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Controllers/LandmarkAccentPresentationController.luau",
\t\t"The authored roadblock retains all barriers, vehicles, collision, signs, and lights while six client-local checkpoint accents improve its static silhouette.",
\t\t"LandmarkSilhouettePresentation",
\t\t{},
\t\t"MilitaryRoadblock",
\t\tfalse
\t),''',
)

test = "games/living-kingdoms/tests/VisualAssetContractsConfig.test.luau"
replace_once(
    test,
    '''assertThat(loggingRoad.expectedRootName == "RouteGuidePresentation", "route-guide root contract drifted")
assertThat(#loggingRoad.requiredAttachmentNames == 0, "procedural route guides must not claim attachments")
assertThat(
\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,
\t"standard hostile must remain honestly marked as primitive geometry"
)''',
    '''assertThat(loggingRoad.expectedRootName == "RouteGuidePresentation", "route-guide root contract drifted")
assertThat(#loggingRoad.requiredAttachmentNames == 0, "procedural route guides must not claim attachments")
for _, assetKey in
\t{
\t\tcontracts.AssetKeys.WorldRangerStation,
\t\tcontracts.AssetKeys.WorldMilitaryRoadblock,
\t}
do
\tlocal landmark = config.ByKey[assetKey]
\tassertThat(landmark.statusId == contracts.StatusIds.PrimitivePlaceholder, "landmark accents must remain primitive")
\tassertThat(
\t\tlandmark.runtimeOwnerPath == "src/client/Controllers/LandmarkAccentPresentationController.luau",
\t\t"accented landmark must name the presentation owner"
\t)
\tassertThat(
\t\tlandmark.expectedRootName == "LandmarkSilhouettePresentation",
\t\t"landmark accent root contract drifted"
\t)
\tassertThat(#landmark.requiredAttachmentNames == 0, "procedural landmark accents must not claim attachments")
end
assertThat(
\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,
\t"standard hostile must remain honestly marked as primitive geometry"
)''',
)

roadmap = "docs/roadmap/VISUAL-PRODUCTION-TRACK.md"
replace_once(
    roadmap,
    '''  - The route-guide layer uses two global workspace connections, zero per-segment connections, zero frame loops, zero timers, zero remotes, and no server runtime change.
  - Still required: Studio gameplay-camera, terrain-clipping, prompt, extraction-zone, and long-distance review; final world/interactable materials, effects, and audio; landmark dressing, lighting, fog, ambience, accessibility, and representative performance evidence.''',
    '''  - The route-guide layer uses two global workspace connections, zero per-segment connections, zero frame loops, zero timers, zero remotes, and no server runtime change.
  - Ranger Station now receives four client-local roof/mast silhouette accents and Military Roadblock receives six checkpoint/lamp accents. Both landmarks exist from world construction; the lookout objective area and extraction clearing remain explicitly excluded.
  - The landmark-accent layer uses two global workspace connections, zero per-landmark connections, zero frame loops, zero timers, zero remotes, and no server runtime change. All ten parts are welded, massless, non-collidable, non-touchable, and non-queryable.
  - Still required: Studio gameplay-camera, terrain-clipping, prompt, extraction-zone, and long-distance review; final world/interactable materials, effects, and audio; remaining landmark dressing, lighting, fog, ambience, accessibility, and representative performance evidence.''',
)

inventory = "docs/specifications/visual-placeholder-inventory.md"
replace_once(
    inventory,
    "| Landmark | Ranger Station | Primitive placeholder | Part-built cabin, equipment, mast, truck, cases, and signage | VIS-0105 |",
    "| Landmark | Ranger Station | Primitive placeholder | `WorldFoundationService` retains the cabin, signage, spawn, lights, and collision; `LandmarkAccentPresentationFactory` and controller add four client-local roof/mast silhouette accents | VIS-0105 |",
)
replace_once(
    inventory,
    "| Landmark | Military Roadblock | Primitive placeholder | Primitive barriers, vehicle, light, and props | VIS-0105 |",
    "| Landmark | Military Roadblock | Primitive placeholder | `WorldFoundationService` retains barriers, vehicles, signs, lights, and collision; `LandmarkAccentPresentationFactory` and controller add six client-local checkpoint/lamp silhouette accents | VIS-0105 |",
)
replace_once(
    inventory,
    "Continue VIS-0105 with major-landmark dressing and world-material planning while keeping Studio route/cache/relay/extraction review, final effects/audio, canonical operative art, class-action cues, avatar-scale coverage, accessibility, and representative performance evidence pending.",
    "Continue VIS-0105 with world-material planning and the remaining safe landmark silhouettes while keeping Studio route/landmark/cache/relay/extraction review, final effects/audio, canonical operative art, class-action cues, avatar-scale coverage, accessibility, and representative performance evidence pending.",
)

print("landmark silhouette accent integration staged")
