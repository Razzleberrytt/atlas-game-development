# Living Kingdoms — World Foundation

## Purpose

P5-0101 establishes the first walkable environment and the visual grammar for future Living Kingdoms operations. It is an environment milestone only. The world builder creates no enemies, weapons, inventory, objectives, extraction state, rewards, or story scripting.

The player-facing test is immediate: the exclusion zone must feel like a real Appalachian community was evacuated yesterday. Civilization is close enough to leave evidence, but no occupied or safe place is visible.

## World identity

- **Place:** a quarantined forest-service district in the Appalachian Mountains of the eastern United States.
- **Time:** after midnight, shortly after a hurried evacuation.
- **Palette:** desaturated pine, wet soil, weathered timber, slate, cold moonlight, and sparse red/amber emergency light.
- **Terrain language:** ridges and shelves bound the operation; trails, a creek bed, switchbacks, logging roads, fallen timber, and boulder groups make navigation legible without producing open combat arenas.
- **Story language:** abandoned transport, scattered cases, an extinguished campsite, quarantine barricades, police tape, damaged utilities, and an empty ranger station carry the narrative. Text labels identify believable infrastructure, not plot exposition.

## Authored route and landmarks

The prototype occupies a 640 × 640 stud operation area. The squad inserts beside the ranger station in the southwest. A logging road creates the broad southern navigation line while a narrower hiking trail moves through the campground and creek crossing, then climbs by switchbacks toward the lookout and rocky overlook. The eastern quarantine roadblock shows where civil authority failed. The extraction clearing is visible and readable as a future holdout location but has no interaction or mission behavior.

The eight graybox landmarks are:

1. Ranger station and squad insertion
2. Logging road with cut timber and damaged utility infrastructure
3. Forest-service lookout tower
4. Small abandoned campground
5. Creek crossing and damaged warning barrier
6. Rocky overlook on elevated terrain
7. Temporary military quarantine roadblock
8. Forest extraction clearing with dormant landing mark, generator, and perimeter lamps

Each landmark model carries `LandmarkId`, `DisplayName`, and `Graybox` attributes. The extraction pad also carries `FutureExtractionZone`; this is an authoring label, not gameplay authority.

## Lighting and atmosphere

Moonlight and a low blue-gray ambient floor preserve terrain silhouettes. Fog shortens long sight lines without hiding the immediate walkable surface. Emergency lamps, generator work lights, and perimeter beacons use a small number of non-shadowed local lights. Local client presentation gives selected canopy pieces subtle wind movement and makes emergency power fluctuate; neither effect changes collision, visibility authority, or gameplay-light contracts.

No music or unlicensed audio asset IDs are included. Wind, insects, wildlife, distant sirens, helicopters, and radio chatter remain an audio-content pass once approved source assets and a mix budget exist. Burning wreckage is also deferred until an effects budget and authored asset pass; current emergency light communicates the intended contrast without adding particles.

## Technical boundaries

`WorldFoundationConfig` owns the deterministic seed, landmark registry, operation extent, vegetation counts, insertion point, and environment tuning. `WorldFoundationService` generates one named `Workspace` folder at server startup and is idempotent across repeated starts. It uses anchored Roblox primitives so the Rojo project is immediately playable without external packages or marketplace assets. `EnvironmentAmbienceController` performs presentation-only updates at 10 Hz.

The generated geometry is intentionally graybox. Primitive tree crowns, buildings, vehicles, rocks, tents, and signs are composition references for a later art pass, not final assets. Runtime generation keeps this first foundation reviewable in source control; a later authored-place conversion should preserve stable landmark IDs and route intent.

## Manual Studio walkthrough

1. Build or serve `games/living-kingdoms/default.project.json`, open the place, and start a one-client Play session.
2. Confirm the character spawns at the ranger-station porch and the tactical camera frames the southwest insertion.
3. Follow the logging road east and verify the roadblock is readable through fog before the world boundary.
4. Return through the campground, cross the creek bridge, and take the switchback trail toward the lookout and overlook.
5. Approach the extraction clearing and verify its perimeter, landing mark, generator, and multiple forest approaches are readable, with no objective prompt or extraction behavior.
6. Verify darkness retains nearby terrain silhouettes, the flashlight improves local readability, selected canopy moves subtly, and emergency lights fluctuate without turning fully unreadable.
7. Confirm Explorer contains exactly one `Workspace/LivingKingdomsWorld`, eight attributed landmark models, one invisible `SquadInsertion`, and no enemy, weapon, inventory, crafting, progression, or story additions from this milestone.

## Known limitations

- Geometry, foliage, structures, road dressing, and vehicles are prototype primitives.
- The terrain is an anchored-part graybox rather than final sculpted Roblox Terrain.
- No licensed ambience audio, VFX wreckage, wildlife, helicopter, or radio assets ship in this pass.
- The two-client Studio smoke pass verified generation, insertion framing, forest silhouettes, ambient/emergency-light readability, and clean bootstrap output; a complete on-foot landmark-by-landmark art review remains outstanding.
- Landmark labels are authoring/readability aids and may be reduced during the final art pass.
