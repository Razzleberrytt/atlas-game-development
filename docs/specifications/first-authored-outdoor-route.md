# BA-050 — First Authored Outdoor Route

**Status:** DATA-ONLY / DORMANT  
**Runtime activation:** No  
**Primary source:** `games/living-kingdoms/src/shared/Config/FirstOutdoorRouteConfig.luau`

## Purpose

BA-050 defines the first short outdoor approach for the playable MVP without creating a second world, mission, encounter, discovery, or transition authority.

The route gives the first expedition a readable traversal spine before **The First Descent**:

`Ranger Station → Logging Road → Forest Service Lookout → Campground → Creek Crossing → Rocky Overlook → Military Roadblock → Forest Extraction Clearing → First Descent`

It reuses stable world-content IDs already owned by `WorldContentConfig` and preserves `route.world.primary` as the recovered route identity.

## Authored sequence

The route begins at `landmark.ranger_station`, traverses the eight active source-managed landmark identities in their authored order, then hands off to the canonical First Descent sequence at `descent-entry`.

Three route-local encounter slots are exposed for BA-051:

- `encounter-slot.outdoor.first-descent.logging-road`
- `encounter-slot.outdoor.first-descent.campground`
- `encounter-slot.outdoor.first-descent.military-roadblock`

One optional route-local discovery slot is exposed for BA-052:

- `discovery-slot.outdoor.first-descent.lookout-tower`

These are attachment points only. BA-050 does not define enemy groups, pacing mechanics, discovery rewards, or presentation behavior.

## Ownership boundaries

BA-050 deliberately does **not**:

- reconstruct or boot the 189 imported `Workspace/WorldPath` Parts;
- enable `RecoveredWorldPathConfig.RuntimeEnabled`;
- promote `route.world.primary` to active world geometry;
- spawn enemies or own encounter state;
- grant discovery or loot rewards;
- move/teleport players;
- launch or complete an expedition;
- introduce raw Workspace/Instance paths;
- use `portal.expedition.primary` as the dungeon entrance.

`portal.expedition.primary` remains the preparation/launch presentation entry whose launch authority stays with the existing expedition lobby flow. The outdoor route terminates instead at the canonical First Descent content handoff (`first-descent-repeatable` / `descent-entry`).

## Recovered geometry policy

`RecoveredWorldPathConfig` mathematically preserves the legacy 189-Part straight-line evidence behind `SourceHold = true` and `RuntimeEnabled = false`.

BA-050 references only its stable canonical content identity (`route.world.primary`). It does not make the old geometry authoritative and does not collapse the held authored-overworld evidence into the live operation-forest lifecycle.

## Follow-on tasks

- **BA-051** may bind concrete mixed-group encounter beats, pacing, elite placement, and recovery assumptions to the three encounter-slot IDs.
- **BA-052** may bind a stable discovery definition, gameplay meaning, presentation intent, and reward reference to the optional lookout discovery slot.
- Runtime consumption remains a later integration task subject to the active roadmap/evidence gates.

## Validation

`games/living-kingdoms/tests/FirstOutdoorRouteConfig.test.luau` verifies:

- canonical route identity and held geometry remain unchanged;
- all eight landmark IDs resolve and remain active landmarks;
- authored landmark order is stable;
- encounter/discovery slot counts and IDs are stable;
- the discovery slot remains optional;
- the final handoff targets First Descent at `descent-entry`;
- no raw `Workspace/` path is authored into the route data;
- the expedition launch terminal cannot be reused as the dungeon handoff.

Studio/manual verification is not required for BA-050 because the task is dormant contract/data preparation. Visual/traversal/runtime acceptance remains deferred to the appropriate integration or consolidated MVP Studio pass.
