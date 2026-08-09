# Atlas Main World and Environment Audit

**Build-ahead ticket:** BA-010
**Roadmap phase:** W0 — Current-world audit and disposition
**Audit date:** 2026-08-08
**Evidence level:** Repository/source and recovered-RBXL evidence only; Studio visual, traversal, streaming, audio and performance acceptance remains required
**Runtime activation:** None

## Decision summary

Atlas should keep the existing two-space architecture and use the recovered authored overworld as the basis of the eventual Main World. The source-generated Forward Operations Hub remains useful as a temporary bridge, but it is not an acceptable final Main World.

The target composition is:

```text
authored-overworld arrival / HubTown
→ immediate orientation landmark
→ compact interaction and preparation loop
→ optional local exploration / discoveries
→ canonical expedition portal or board
→ modern operation runtime
→ deterministic return to HubTown
```

No broad geometry pass should begin from this audit alone. BA-011 must first define the source representation and lifecycle boundary, BA-012 must define stable interaction anchors, BA-013 must turn the environment findings into budgets and kits, and BA-014 must turn the Studio checklist into an acceptance matrix.

## Scope and evidence

This audit covers:

- the active source-generated `LivingKingdomsWorld` operation forest;
- the live `ForwardOperationsHub` shell at Ranger Station;
- the recovered authored-overworld roots (`HubTown`, `WorldPath`, `WorldStructures`, `Resources`, authored spawn, clouds and fireflies);
- Rojo mapping, world bootstraps, lighting, atmosphere, environmental animation and audio seams;
- structural readiness for future Main World interactions without activating those systems.

Primary evidence:

- `games/living-kingdoms/default.project.json`
- `games/living-kingdoms/CANONICAL-RUNTIME.md`
- `games/living-kingdoms/src/server/Systems/WorldFoundationService.luau`
- `games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau`
- `games/living-kingdoms/src/server/Systems/HubPreparationService.luau`
- `games/living-kingdoms/src/shared/Config/HubPreparationConfig.luau`
- `games/living-kingdoms/src/shared/Config/WorldContentConfig.luau`
- `games/living-kingdoms/src/shared/Config/RecoveredWorldPlacementConfig.luau`
- current evidence under `docs/migration/current/`
- `docs/migration/REEXTRACTED-WORLD-EVIDENCE.md`

The repaired extraction verifies 1,775 / 1,775 Workspace identity rows, 1,699 geometry/light property rows, and 1,742 rows after supported UI/particle presentation decoding. It does not prove in-game composition, camera readability, collision quality, streaming behavior, audio mix or performance.

## Disposition vocabulary

| Disposition | Meaning |
|---|---|
| KEEP | Preserve the existing owner, content or policy substantially as-is. |
| REFINE | Preserve the intent and ownership, then improve composition or implementation. |
| REBUILD | Recreate from verified evidence under a new source-managed representation. |
| REPLACE | Retire the current representation after a gated replacement is accepted. |
| REMOVE | Do not ship or activate this content/path; retain historical evidence where required. |
| MISSING | Required product surface or contract does not yet exist. |

## Current loop audit

| Loop beat | Current evidence | Disposition | Required outcome |
|---|---|---|---|
| Arrival | Players receive the generated `SquadInsertion` spawn at `(-224, 3.4, -208)` beside Ranger Station. A hidden safety spawn/floor is also Rojo-mapped. No authored-overworld arrival lifecycle is active. | REFINE | BA-011 must define authoritative arrival and return spawn selection per world lifecycle. Arrival needs a safe multiplayer landing area, a strong first-frame landmark and no ambiguity between safety and production spawns. |
| Orientation | Ranger Station has a district sign, emergency lights and a nearby controls board. The three preparation stations sit about 44–54 studs north of the spawn, but source cannot prove they are visible or understood from the gameplay camera. | REFINE | Establish a single orientation landmark, readable sightline to preparation, device-correct prompts and a concise statement of the immediate goal. Validate from gameplay camera in Studio. |
| Exploration | The operation forest has eight named landmarks, four outer routes, five region treatments and environmental-story clusters. HubTown has 46 immediate child groups, but it is held and inactive. | REBUILD | Local Main World exploration should use selected authored HubTown/nearby-overworld content, not the entire operation forest as a social hub. Exploration paths need deliberate loops, discoveries and bounded dead travel. |
| Interaction | The live shell offers class, weapon and expedition UI entry through three presentation-only prompts. Recovered HubTown contains vendor stalls, a quest board, portal, four Humanoids and one prompt, but legacy gameplay authority is prohibited. | REFINE | Keep the thin presentation-router pattern. BA-012 must define canonical stable-ID anchors and delegate mutations to current/future canonical owners. Do not infer modern bindings from old `[B]`/`[G]` signs. |
| Preparation | Specialist, armory and expedition surfaces delegate to existing UI/services; character, inventory and skills remain keyboard-menu owned. | REFINE | Consolidate preparation into a device-neutral spatial and UI information hierarchy without creating duplicate inventory, class, loadout or progression owners. |
| Adventure | `portal.expedition.primary` is an active presentation entry; `ExpeditionLobbyService` remains launch authority. The authored DungeonPortal is faithfully held but inert. | KEEP | Preserve canonical expedition authority and use the eventual authored portal/board only as a validated entry surface. |
| Return | Operation/result systems exist, but there is no accepted authored-overworld return destination or Main World re-entry composition. | MISSING | Define success, failure, reset, disconnect/reconnect and replay return destinations. Return must place the party at a recognizable debrief/reward/replay seam, not merely at a generic spawn. |

## World and content disposition

| Element | Evidence-backed finding | Disposition | Composition requirement |
|---|---|---|---|
| Two coordinate spaces | Recovered authored content spans roughly X `-1844..2832`, Y `0.5..1400`, Z `-3184..1900`; the modern operation uses a ±640-stud half extent. | KEEP | Preserve 1:1 authored coordinates and separate lifecycle roots/places. Never translate the overworld into `LivingKingdomsWorld` merely to make it fit. |
| Forward Operations Hub | Three functional stations and a controls board are generated beside Ranger Station. It is explicitly presentation-only and authority-safe. | REFINE, then REPLACE | Keep until the authored-overworld launch/return loop is accepted. Replace as the primary Main World, but retain the pattern as an operation-side field camp if it has a distinct gameplay purpose. |
| Ranger Station | Hollow structure, through-route, supplies, radio mast, emergency lighting and abandoned vehicle provide a useful operation insertion landmark and story. | KEEP | Keep in the modern operation. Do not treat it as the final civic/social center. |
| Operation forest | Eight landmarks, outer regions/routes, deterministic vegetation and evacuation storytelling give the active operation a coherent field setting. | KEEP / REFINE | Preserve gameplay routes and landmark identities. Improve through measured art/LOD/streaming passes rather than reclassifying the operation as the Main World. |
| HubTown | 270 recovered rows, 46 immediate child paths, vendor groups, fountain, staircase, archway, quest board, portal, lights, VFX and NPC-shaped content prove substantial authored intent. | REBUILD | Reconstruct coherent groups from property evidence behind the authored-overworld hold. Use stable IDs and modern owners; do not boot `HubTownService` or other legacy gameplay services. |
| Authored spawn | One original `Workspace/SpawnLocation` is preserved as evidence; exact player-facing arrival quality is unverified. | REFINE | Reconstruct it as a candidate authored-overworld spawn anchor, then validate capacity, facing, clearance, camera reveal and return behavior in Studio. |
| WorldPath | 189 identical 6 × 0.2 × 6 slabs form a straight route from near Z `-3` to Z `-1500`. | REPLACE | Keep the recovered route contract/evidence, not 189 loose production parts. BA-011 should define spline/control-point or modular route representation and intentional traversal beats. |
| WorldStructures | 1,190 rows across 17 groups, including large fantasy landmarks, 461-row vegetation and 201-row detail groups. | REBUILD selectively | Rank groups by Main World role, silhouette, proximity and cost. Reconstruct only coherent, useful groups; Studio review decides which legacy aesthetics fit current Atlas direction. |
| Resources | 113 rows across Trees, Rocks and IronOre support future gathering presentation. | KEEP as held evidence | No gathering authority is activated. BA-013 may derive prop families; gameplay waits for canonical resource/economy contracts. |
| DungeonPortal | 10-row property-backed reconstruction includes frame, lights, sign and particle swirl, with no recovered prompt. | KEEP held / REFINE | Preserve presentation evidence and old text as evidence only. A future modern interaction delegates to `portal.expedition.primary`. |
| Quest board | 16-row property-backed stall/board reconstruction, including SurfaceGui and BillboardGui text, with no recovered prompt. | KEEP held / REFINE | Use as the likely operation-selection landmark after the pre-launch selection and interaction contracts are accepted. |
| Vendor stalls/NPC forms | Apothecary, armor smith, weapon smith and merchant groups exist; four Humanoids are present in HubTown evidence. | REBUILD | Preserve visual identity where useful. Future NPC/vendor definitions use stable IDs; legacy vendor stock, pricing and request handling remain inactive. |
| Central Fountain / Grand Staircase / Hub Archway | Recovered groups offer potential orientation silhouettes and civic hierarchy. | REFINE | Prioritize these for composition preview because they can form arrival, center and adventure-gate landmarks. Final keep/rebuild decisions require Studio camera review. |
| `Buildings` folder | Verified as a single empty folder in the recovered place. | REMOVE from production representation | Retain migration evidence only; do not preserve an empty runtime container as meaningful content. |
| Terrain voxels | Terrain identity exists, but voxel data is not represented by current extraction/source. The modern operation uses large Parts for terrain foundation. | MISSING | BA-011/013 must define Studio-owned terrain workflow, source metadata, review checkpoints and rollback. Do not guess legacy voxels. |
| AmbientFireflies / WorldClouds | Small recovered presentation roots exist and belong to authored-overworld space. | REBUILD | Reconstruct only after density, quality tiers and environmental-VFX budgets are defined. |

## Proposed Main World composition contract

This is a composition requirement, not permission to build geometry.

### Spatial hierarchy

1. **Arrival threshold** — safe spawn/re-entry pad with a framed view of the civic landmark and no prompt pile-up.
2. **Orientation center** — Central Fountain, staircase or an equally strong recovered silhouette anchors the mental map.
3. **Preparation ring** — class/loadout/inventory/skills surfaces sit within a short, readable loop around the center; services remain distinguishable by shape and function, not color alone.
4. **Interaction edge** — quest board, NPCs and vendors sit on outward-facing paths so interaction introduces the world rather than trapping players in a menu courtyard.
5. **Adventure gate** — the archway/portal/board sequence terminates the main sightline and hands off to canonical expedition preparation.
6. **Exploration branches** — optional paths lead to discoveries, resources, views or future entrances, then reconnect without long empty return travel.
7. **Return/debrief seam** — returning players appear near reward/progression/replay information while remaining spatially connected to the arrival landmark.

### Navigation rules

- A new player should see one primary goal and at least one secondary curiosity from arrival.
- The core preparation loop should be compact enough for repeated runs; longer travel belongs to optional exploration.
- Major destinations need stable semantic IDs and at least two readable channels among silhouette, path alignment, signage, light, audio and UI fallback.
- Paths should form loops or meaningful branches, not a 1,500-stud uninterrupted corridor.
- Boundaries should read as authored geography/architecture, not invisible walls or repeated filler props.
- Four-player clusters must be able to spawn, inspect stations and pass through entrances without prompt/camera congestion.

### Expansion seams

| Future domain | Structural readiness now | Required seam |
|---|---|---|
| NPCs/dialogue | Authored NPC-shaped groups exist; no canonical registry. | Stable NPC IDs, interaction capabilities and conversation references from BA-012/BA-021. |
| Vendors | Four authored vendor groups exist; legacy economy is prohibited. | Vendor anchor IDs pointing to future canonical catalogs/currency owners; no local pricing truth. |
| Quests/operations | Quest board presentation is reconstructed and held. | Board anchor → validated pre-launch selection → expedition launch; no direct client mutation of mission state. |
| Crafting/gathering | Resource presentation evidence exists. | Resource/crafting station anchors only after inventory, persistence and economy ownership is defined. |
| Inventory/progression | Canonical UI/services already exist. | Spatial surfaces may open those owners; they do not duplicate state or transactions. |
| Dungeons/expeditions | Recovered portal and active expedition terminal both exist as presentation. | One canonical destination/eligibility/launch path with explicit denial and return behavior. |
| Social/party | No accepted Main World social layout or party ownership contract. | Gathering area, party formation/readiness surfaces and reserved-server policy from dedicated social/session work. |
| Secrets/discoveries | Landmarks and world-content IDs exist; authored discovery content is not active. | Streaming-safe discovery IDs, HUD fallback and bounded rewards. |

## Environment and visual audit

### Terrain, vegetation and props

- The modern operation generator creates **2,334 vegetation BaseParts** from configured tree, log, boulder and shrub loops before roads, structures, props, lights and vista dressing are counted. This is deterministic (`Seed = 1847`) but not yet a measured performance budget.
- Pine and hardwood trees are assembled from one trunk plus three primitive canopy Parts. Counts and transforms vary, but silhouette/material families remain highly repetitive.
- The operation uses large Parts for floor, shelves, ridges, creek and region plates. This is reviewable graybox geometry, not a final Terrain composition.
- Route clearance and landmark clearance are config-driven and deterministic, which is worth keeping.
- The recovered world contains far richer authored group variety, but hierarchy/property recovery does not prove that every group is visually coherent or performant in the current camera.

Disposition: **KEEP** deterministic placement and clearance contracts; **REFINE** the operation through measured prop/foliage kits; **REBUILD** the Main World from selected authored groups; **MISSING** final Terrain/LOD/streaming strategy.

### Landmarks, scale and silhouette

- Eight stable modern-operation landmarks and several named outer regions provide strong semantic hooks.
- Recovered HubTown is compact (roughly ±61 studs horizontally) relative to the enormous overworld structure bounds, which is appropriate for a dense service center but creates a sharp scale transition that needs an authored threshold.
- Central Fountain, Grand Staircase, Hub Archway, quest board and DungeonPortal are the highest-value early preview candidates because they can define center, elevation, interaction and exit.
- The Destiny Monolith, Crystal Tower, Dark Citadel and other large structure groups may be powerful distant silhouettes, but their current-product fit and occlusion cost require Studio review.

Disposition: **KEEP** stable IDs and authored scale; **REFINE** landmark hierarchy; do not approve recovered hero structures from names/source rows alone.

### Lighting, sky, fog and grading

- `WorldFoundationService` creates a night-biased base look with Atmosphere, ColorCorrection, Bloom, SunRays and Clouds, but no source-managed `Sky` instance.
- `NightCorruptionService` changes ClockTime, Brightness, ExposureCompensation, FogEnd and Ambient every 0.5 seconds.
- `EnvironmentAmbienceController` adds client-local threat grade/bloom and storm pulses at a 0.1-second update interval.
- `ExpeditionAtmosphereController` temporarily overwrites several Lighting values and adds its own atmosphere/bloom/grade/depth effects while expedition rooms exist, then restores remembered values.
- These layers are individually bounded but do not share a single explicit environment-profile owner. Server updates can overlap a client's remembered/restored expedition values; this needs lifecycle and multiplayer observation before any consolidation decision.
- Local decorative lights are generally non-shadowing, matching the visual bible's performance direction. Actual simultaneous light count and low-quality readability are unmeasured.

Disposition: **REFINE** into explicit world/operation environment profiles with ownership and transition rules; preserve day/night gameplay authority; require Studio evidence before changing current look.

### VFX and environmental animation

- Wind, flicker and blink effects are client-local presentation and do not mutate gameplay truth.
- Environmental animation uses tagged/attributed objects and bounded lists, which is a sound pattern.
- `ExpeditionEnvironmentAnimationController` does not retain the two `Workspace.ChildAdded` / `ChildRemoved` connections it creates, so `stop()` cannot disconnect them. This is lifecycle debt and must be repaired in a runtime-safe ticket with a focused test.
- Recovered fireflies, fires, lights and particle emitters need density/overdraw budgets and reduced/minimum-readable variants before activation.

Disposition: **KEEP** client-local presentation ownership; **REFINE** connection scopes and quality tiers; **REBUILD** recovered effects only from property evidence and budgets.

### Audio and atmosphere

- No Main World ambient-zone or music-zone architecture exists.
- The expedition creates a `Sound` marked `NeedsSoundAsset`, but it has no `SoundId` and is intentionally silent.
- Current `EnvironmentAmbienceController` is visual/code-driven despite being cataloged as ambience.
- Weapon/enemy audio exists but reuses temporary approved asset IDs and is not a substitute for environmental soundscape.

Disposition: **MISSING**. BA-013 should specify ambient beds, localized emitters, transition/crossfade ownership, SoundGroups, accessibility controls and performance limits. Do not invent asset IDs.

## Technical audit

| Area | Finding | Risk | Required action |
|---|---|---|---|
| Rojo representation | `default.project.json` maps source trees plus a hidden safety floor/spawn. Authored-overworld geometry is not mapped as active content. | Safe today, but future world work could drift into Studio-only unreviewable state. | BA-011 defines what belongs in config, model assets, Studio Terrain and migration manifests. |
| Initialization | `WorldFoundationService.start()` runs before dependent main server systems; the separate hub bootstrap waits for the generated root. Start guards make repeated calls safe. | `WaitForChild` has no diagnostic timeout; independent Script scheduling still needs Studio boot observation. | Preserve ordering boundary; add explicit readiness/diagnostics only in a scoped implementation ticket. |
| Authority | Hub prompts only open client UI; class, loadout, inventory, progression and expedition services keep gameplay authority. | Low current security risk. Future vendor/quest/crafting prompts could accidentally mutate client-side. | BA-012 records owner and intent contract for every interaction anchor. |
| Replication | The operation world is generated server-side as many anchored Instances and replicated to every client. | Join cost, memory and mobile rendering may be high. | Measure instance count, replication/download, memory and frame time in BA-014/Studio. |
| Streaming | No `StreamingEnabled`, radius or model streaming policy is declared in the Rojo project or canonical world configs. | Overworld scale and instance count are not production-ready; semantic targets may stream unpredictably when enabled later. | BA-011 defines boundaries and model policies; BA-014 tests stream-out/rebind and navigation fallbacks. |
| LOD | No source evidence of authored LOD tiers for Main World groups. | Recovered hero structures/vegetation may overdraw or pop poorly. | BA-013 defines Hero/Mid/Far strategy and per-kit budgets. |
| Collision/query | Generated presentation Parts default to `CanQuery = true`; many decorative Parts remain collidable unless explicitly disabled. | Unmeasured physics/query cost and false cover/navigation. | Audit collision groups, query/touch flags and visual collision truth in Studio. |
| Determinism | World seed, counts, route corridors and stable landmark IDs are config-driven. | Good maintainability; large geometry still lives in one ~2,000-line builder. | Keep deterministic contracts; BA-011 separates data/representation without creating a second runtime owner. |
| State listeners | `EnvironmentAmbienceController` directly listens to legacy `HordeNetwork.State` in addition to the known HUD/crescendo consumers. | It is another compatibility consumer during the v2.7 single-listener migration. | Recorded as CL-004 in the cutover ledger; migrate only under the gated R1/R2/R3 plan. |
| Lighting ownership | Base world, night corruption, threat ambience and expedition atmosphere all mutate Lighting/effects. | Restore races, inconsistent client views and hard-to-test transitions. | Define profile priority/ownership in BA-013; validate lifecycle in Studio before code migration. |
| Audio | Environmental audio has no playable asset/zone implementation. | Main World lacks atmosphere and transition feedback. | Specify architecture first; source approved assets separately and verify permissions/mix in Studio. |

## Studio-only review and acceptance checklist

Create a fresh evidence packet or BA-014 acceptance artifact with exact commit/build/place identity. Do not mark these passed from source inspection.

### Arrival and flow

- [ ] Cold join, respawn, operation success, operation failure and replay decline land at the intended location/facing.
- [ ] Four players can spawn simultaneously without overlap, falls, blocked camera or prompt contention.
- [ ] From the gameplay camera, a new player identifies the orientation landmark and adventure direction within 10 seconds without opening a menu.
- [ ] Players can reach class, loadout and expedition preparation without dead ends or unclear backtracking.
- [ ] Return flow exposes result/reward/replay context and does not resemble a fresh unexplained spawn.

### Navigation and composition

- [ ] Walk timed routes: spawn → orientation center → each preparation surface → adventure gate → return seam.
- [ ] Record dead-travel segments and multiplayer congestion points.
- [ ] Validate landmark recognition from near, mid and far distance at full, reduced and minimum-readable quality.
- [ ] Check boundaries, invisible blockers, false cover, stair/ramp metrics and camera clipping.
- [ ] Review optional branches for meaningful payoff and loop-back behavior.

### Visual/environment

- [ ] Capture fixed viewpoints in neutral/editor, normal full, reduced, minimum-readable and mobile aspect modes.
- [ ] Review terrain seams, floating/sunken props, vegetation repetition, silhouette collisions and scale consistency.
- [ ] Review day/night, corruption tiers and expedition transition/restore behavior.
- [ ] Confirm route, prompt, enemy and objective readability against fog, bloom, particles and landmark lighting.
- [ ] Validate that no critical cue depends on color alone.

### Audio

- [ ] Verify every ambient/music asset permission before use.
- [ ] Measure crossfades and rapid boundary re-entry for pops, stacking or silence.
- [ ] Review hub social mix, interaction cues, portal/expedition transition and return/debrief mix.
- [ ] Verify volume controls, captions/visual alternatives for critical audio, and mobile speaker intelligibility.

### Performance, streaming and cleanup

- [ ] Record server/client instance counts by root and class.
- [ ] Record client/server memory, frame time, render cost and network receive during join/traversal with four players.
- [ ] Test target mobile/low-graphics devices with representative combat and UI active.
- [ ] Enable the proposed streaming policy in a controlled branch and verify spawn safety, route continuity, semantic target rebind and no completion-on-stream-out bugs.
- [ ] Measure active dynamic lights, particles, tagged animated Parts and connection counts.
- [ ] Repeatedly enter/exit expedition space and confirm Lighting effects, sounds, environment animation and connections return to baseline.

## Ordered follow-up

1. **BA-011 — Main World source representation/placement strategy (complete at E1).** The dedicated place/project boundary, reviewable representations, Terrain ownership, streaming groups and spawn/return anchors are defined in [`main-world-source-representation-strategy.md`](main-world-source-representation-strategy.md).
2. **BA-012 — Canonical Hub interaction registry.** Define stable anchors and canonical owners for preparation, quest/operation board, vendors, NPCs, crafting/gathering seams, portal and social surfaces.
3. **BA-013 — Environment production plan.** Define terrain/structure/prop/foliage/material/lighting/VFX/audio kits, variation budgets, LOD, streaming and quality tiers.
4. **BA-014 — Main World acceptance matrix.** Turn the checklist above into measurable thresholds and repeatable Studio captures.
5. Continue BA-005 reconstruction only for coherent groups selected by this composition plan; do not activate the authored overworld until the runtime and lifecycle gates permit it.

## Completion boundary

BA-010 is complete when this source/evidence audit is accepted. It does **not** assert that the current or recovered world is visually approved, performant, stream-safe or ready to activate. Those claims require the Studio work above.
