# Living Kingdoms — World Foundation

## Purpose

P5-0101 established the first walkable environment and P5-0102 completes its first gameplay-camera readability and landmark-identity pass. HROI-ENV-001 deepens the existing client ambience with bounded threat-responsive mood rather than another broad procedural-geometry pass. These are environment milestones only. The world builder creates no enemies, weapons, inventory, objectives, extraction state, rewards, or story scripting.

The player-facing test is immediate: the exclusion zone must feel like a real Appalachian community was evacuated yesterday. Civilization is close enough to leave evidence, but no occupied or safe place is visible.

## World identity

- **Place:** a quarantined forest-service district in the Appalachian Mountains of the eastern United States.
- **Time:** after midnight, shortly after a hurried evacuation.
- **Palette:** desaturated pine, wet soil, weathered timber, slate, cold moonlight, and sparse red/amber emergency light.
- **Terrain language:** ridges and shelves bound the operation; trails, a creek bed, switchbacks, logging roads, fallen timber, and boulder groups make navigation legible without producing open combat arenas.
- **Story language:** abandoned transport, scattered cases, an extinguished campsite, quarantine barricades, police tape, damaged utilities, and an empty ranger station carry the narrative. Text labels identify believable infrastructure, not plot exposition.

## Authored route and landmarks

The prototype occupies a 640 × 640 stud operation area. The squad inserts beside the ranger station in the southwest. A logging road creates the broad southern navigation line while a narrower hiking trail moves through the campground and creek crossing, then climbs by switchbacks toward the lookout and rocky overlook. The eastern quarantine roadblock shows where civil authority failed. The extraction clearing is visible and readable as a future holdout location but has no interaction or mission behavior.

The eight refined graybox landmarks are:

1. **Ranger station:** a headquarters silhouette with lit generator, radio mast, equipment storage, porch insertion, service truck, and supply cases.
2. **Logging road:** a broad muddy line with paired tire tracks, stacked timber, a log loader, broken fencing, and damaged utility infrastructure.
3. **Forest-service lookout:** the dominant vertical silhouette with weathered cross-bracing, elevated cabin, stairs, and a slow blinking red aviation light visible through the canopy.
4. **Campground:** tents, picnic tables, a cold fire ring, an abandoned backpack, an open medical kit, and restrained scattered supplies.
5. **Creek crossing:** raised muddy banks, shallow water, exposed stepping rocks, a visibly damaged bridge, and fallen timber that communicates alternate footing.
6. **Rocky overlook:** elevated stone clusters, a pronounced cliff edge, broken guard rail, open vista, and small distant town-light points.
7. **Military roadblock:** concrete barriers, sandbags, two abandoned military vehicles, paired floodlights, checkpoint cabin, quarantine sign, and caution tape.
8. **Forest extraction clearing:** a wide dormant landing mark with a clear southern approach line, future flare positions, generator, perimeter lamps, stumps, and temporary equipment cases.

Each landmark model carries `LandmarkId`, `DisplayName`, and `Graybox` attributes. The extraction pad also carries `FutureExtractionZone`; this is an authoring label, not gameplay authority.

## Lighting and atmosphere

Moonlight and a low blue-gray ambient floor preserve terrain silhouettes. Fog shortens long sight lines without hiding the immediate walkable surface. Emergency lamps, generator work lights, and perimeter beacons use a small number of non-shadowed local lights. Local client presentation gives selected canopy pieces subtle wind movement and makes emergency power fluctuate; neither effect changes collision, visibility authority, or gameplay-light contracts.

P5-0102 lengthens the readable fog range, opens cloud cover slightly, defines the moon direction through clock time and Appalachian latitude, and increases path/terrain contrast. The lookout blink, checkpoint floodlights, ranger generator, and extraction work light establish a restrained hierarchy: cold moonlight defines terrain while red and amber infrastructure identifies destinations.

HROI-ENV-001 layers one client-local color grade and one client-local bloom effect over the existing server-authored lighting. The controller accepts only monotonic `HordeNetwork.State` revisions, clamps disclosed threat to `0..1`, and smooths the visual response before increasing wind motion, emergency-power instability, contrast, desaturation, and bloom. Occasional deterministic double-flash storm pulses briefly surge the grade and dip tagged emergency lights; their cadence has a strict 9–24 second bound and uses no task loop. This is atmosphere, not threat detection: the controller performs no raycast, hostile scan, gameplay-light activation, mission mutation, or client-to-server request.

No music or unlicensed audio asset IDs are included. Wind, insects, wildlife, distant sirens, helicopters, and radio chatter remain an audio-content pass once approved source assets and a mix budget exist. Burning wreckage is also deferred until an effects budget and authored asset pass; current emergency light communicates the intended contrast without adding particles.

## Technical boundaries

`WorldFoundationConfig` owns the deterministic seed, landmark registry, operation extent, vegetation counts, insertion point, and environment tuning. `WorldFoundationService` generates one named `Workspace` folder at server startup and is idempotent across repeated starts. It uses anchored Roblox primitives so the Rojo project is immediately playable without external packages or marketplace assets. `EnvironmentAmbienceController` performs presentation-only updates at 10 Hz using exactly one heartbeat connection and one existing disclosed-state connection.

P5-0102 reduces procedural vegetation modestly and replaces coarse axis-based clearance with authored segment clearance along the logging road, switchbacks, creek-to-extraction path, insertion route, and helicopter approach. Landmark clearance is also wider. This keeps canopy mass at the perimeter while protecting route reveals from the isometric camera. Route surfaces and landmark models remain ordinary static collision; non-walkable labels, lights, tire tracks, town lights, flare markers, and caution tape do not collide.

The environment mood pass adds no part, particle emitter, audio asset, remote, server runtime, per-prop script, shadow-casting local light, or authoritative attribute. Vegetation animation remains sampled at 10 Hz and applies only to selected non-collidable crowns. Stop and teardown restore tagged light brightness, aviation-light transparency, canopy base transforms, and remove both client-local post effects. The deterministic world budget remains 104 pines, 44 hardwoods, 15 fallen logs, and 52 boulders.

The generated geometry is intentionally graybox. Primitive tree crowns, buildings, vehicles, rocks, tents, and signs are composition references for a later art pass, not final assets. Runtime generation keeps this first foundation reviewable in source control; a later authored-place conversion should preserve stable landmark IDs and route intent.

## Manual Studio walkthrough

1. Build or serve `games/living-kingdoms/default.project.json`, open the place, and start a one-client Play session.
2. Confirm the character spawns at the ranger-station porch and the tactical camera frames the southwest insertion.
3. Follow the paired muddy tracks east. Confirm the log stacks/loader read as logging activity and the roadblock floodlights and barrier line become legible through fog before the world boundary.
4. Return through the campground, checking that its low tent/table silhouette differs from the ranger station. Cross by bridge or exposed creek rocks, then take the cairn-marked switchbacks toward the lookout and overlook.
5. Confirm the lookout tower and aviation blink provide reorientation from several route segments without foliage filling the gameplay-camera foreground.
6. At the overlook, verify the guard rail and stone lip read as a non-climbable cliff edge and distant town lights sit beyond the immediate play route.
7. Approach the extraction clearing from the creek and southern corridor. Verify its open perimeter, landing mark, dormant flare positions, generator, and approach line are readable, with no objective prompt or extraction behavior.
8. Reverse the circuit with the gameplay camera. Confirm path continuity, deliberate choke points, readable elevation changes, no hidden required route, no visually open invisible wall, and no prop collision creating an accidental dead end.
9. Verify darkness retains nearby terrain silhouettes, the flashlight improves local readability, selected canopy moves subtly, emergency lights fluctuate without turning fully unreadable, and the lookout light blinks at a slow stable interval.
10. During a rising-threat run, confirm the mood changes gradually rather than snapping: wind and power become less stable, the image becomes slightly harsher and less saturated, and brief storm flashes remain readable without obscuring combat, prompts, routes, critical UI, or disclosed hostiles.
11. In a two-client session, confirm both clients see the same static layout while the mood remains independent presentation only. Confirm Explorer contains exactly one `Workspace/LivingKingdomsWorld`, eight attributed landmark models, one invisible `SquadInsertion`, no duplicate mood effects after restart, and no enemy, weapon, inventory, crafting, progression, or story additions from this environment pass.

## P5-0102 readability findings

- Coarse vegetation exclusion could preserve the initial road while allowing trees to obscure switchbacks, the creek-to-extraction connection, and long landmark reveals. Segment-based clearance now protects every intended route without clearing the entire forest interior.
- The initial logging road and trail used single flat color bands. Tire tracks, cairns, creek banks, and route-specific material contrast now communicate broad vehicle route versus narrow foot route from the isometric angle.
- Several landmarks had similar low primitive mass. The radio mast, lookout tower/blink, floodlight pair, open landing composition, log loader, campground furniture, and overlook edge give each a distinct silhouette and purpose.
- The original complete bridge did not tell a convincing evacuation or alternate-traversal story. A missing plank, collapsed rail, exposed rocks, and fallen tree now make the shallow crossing legible while preserving a traversable route.
- Story evidence is concentrated at believable interruption points—station departure, campground abandonment, roadside vehicle, damaged utilities, and quarantine checkpoint—rather than scattered uniformly as clutter.

## Known limitations

- Geometry, foliage, structures, road dressing, and vehicles are prototype primitives.
- The terrain is an anchored-part graybox rather than final sculpted Roblox Terrain.
- No licensed ambience audio, VFX wreckage, wildlife, helicopter, or radio assets ship in this pass; the distant-storm flash intentionally has no thunder until approved audio and mixing budgets exist.
- Landmark labels are authoring/readability aids and may be reduced during the final art pass.
- Primitive rectangular terrain shelves can show hard seams and cannot yet deliver final creek-bank, ravine, or switchback erosion. Their traversal edges should be replaced with sculpted Terrain while preserving the current route widths.
- Tree crowns, the tower, ranger building, tents, vehicles, loader, barriers, bridge, equipment cases, generator, floodlights, utility poles, signs, and cliff rocks are the recommended future art-replacement areas. Replace repeated high-silhouette pieces first; preserve landmark bounds, collision intent, and stable IDs.
- Distant town lights are composition points, not a rendered town. The extraction approach is a visual corridor only and contains no helicopter, flare effect, objective, or extraction logic.
- Local Studio review is representative of desktop isometric presentation only; the new threat mood still requires an actual gameplay-camera review for flash comfort, low-quality graphics, color-vision accessibility, mobile/console framing, lower-end GPU cost, internet conditions, and final asset streaming.
