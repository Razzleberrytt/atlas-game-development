# Roblox Cooperative FPS RPG
## Visual, Environment, and Animation Production Bible — Version 2.3 Refined

**Status:** Canonical visual-production specification integrated with the Version 2.3 runtime-presentation rules.  
**Applies to:** Emberwatch, Verdant Scar, Underroot Vault, player equipment, launch enemies, Frontier Rifle, Breach Shotgun, Pulse Mark, Gatekeeper, and their runtime presentation.  
**Parent document:** `Willie_Roblox_RPG_Master_Blueprint_v2.3.md`, held outside the repository in the `Roblox_RPG_Refined_v2.3` package. The active in-repo authority is [`../roadmap/BLUEPRINT-V2.3-EXECUTION.md`](../roadmap/BLUEPRINT-V2.3-EXECUTION.md).  
**Release date:** 2026-08-07.

This file preserves Chapters 141–160 from the Version 2.1 visual release because their dimensions and art language remain the visual baseline. Version 2.3 adds runtime ownership, quality-tier, streaming, and evidence refinements at the end. When a historical phrase says “Version 2.1,” read it as the origin of that specification, not as the current document authority.

### Authority

1. Accepted gameplay/device evidence controls dimensions and performance.
2. Production Core v2.3 and Master Chapters 181–196 control integrated runtime behavior.
3. This bible controls visual authoring and asset acceptance.
4. Historical checkpoint text provides context only.

---

# 141. Version 2.1 Visual Production Release Scope

Version 2.1 converts the earlier art-direction summary into a production-grade visual specification. It does not claim that final art, rigs, or animation have been created. It defines what those assets must communicate, how they fit together, how they are reviewed, and which technical limits protect the game on Roblox devices.

The visual release exists to answer five questions:

1. What should a player recognize from one screenshot?
2. How does environment art communicate route, cover, danger, secrecy, and future possibility?
3. How do characters, weapons, and factions remain readable during first-person combat?
4. How does animation express intention without becoming the source of mechanical truth?
5. How can a small team produce a distinctive world without creating an unsustainable asset pipeline?

## 141.1 Canonical Deliverables

Version 2.1 defines:

- the visual north star and screenshot-identity test;
- composition, shape, scale, color, lighting, and material grammar;
- modular environment dimensions and socket rules;
- complete first-pass environment specifications for Emberwatch, the Verdant Scar, and Underroot Vault;
- prop, foliage, decal, weather, damage, and environmental-storytelling standards;
- visual specifications for the player, launch factions, enemy roles, weapons, abilities, and the Gatekeeper;
- animation rig, state, layering, marker, timing, and interruption contracts;
- first-person weapon motion and camera-motion limits;
- enemy telegraph and hit-reaction specifications;
- VFX, UI, audio, and accessibility integration rules;
- provisional geometry, texture, material, particle, lighting, streaming, and animation budgets;
- asset briefs, naming, review gates, and production tickets 151–180.

## 141.2 Authority and Evidence

The following authority model applies:

```text
This chapter set defines intended visual behavior.
A greybox proves dimensions and gameplay readability.
A gameplay-ready asset proves hierarchy, collision, and integration.
An art pass proves visual identity.
A device test proves performance.
A fresh-player test proves communication.
```

An attractive asset does not pass if it hides an enemy tell, creates false cover, blocks aim, breaks navigation, exceeds budget, or fails on lower graphics settings.

## 141.3 Visual Quality Laws

1. **Silhouette before surface detail.**
2. **Gameplay information before decoration.**
3. **Landmarks before clutter.**
4. **One region, one dominant visual argument.**
5. **Reuse forms a language; repetition without variation becomes noise.**
6. **First-person readability outranks realistic weapon proportions.**
7. **Animation communicates intent; the server owns the result.**
8. **Every critical cue uses more than color alone.**
9. **Every hero effect has a reduced-quality form.**
10. **No asset earns final polish before its gameplay role is accepted.**

## 141.4 Non-Goals

This pass does not lock:

- final character faces or avatar monetization;
- final costume catalog;
- exact texture resolutions for every future device class;
- a full day/night cycle;
- destructible terrain simulation;
- cinematic cutscene production;
- procedural generation of final art assets;
- photorealism;
- hundreds of one-use props;
- a unique shader or pipeline for every faction.

The vertical slice needs a coherent visual language, not a museum of unrelated technical demonstrations.

# 142. Visual North Star and Screenshot Identity

## 142.1 One-Sentence Visual Pitch

**A warm frontier settlement faces a luminous, overgrown rupture where patched human craft, altered life, and severe ancient machinery collide.**

The visual identity depends on contrast between three worlds:

| Visual culture | Core feeling | Shape language | Surface language | Light language |
|---|---|---|---|---|
| Emberwatch frontier | Human, improvised, hopeful | layered wedges, braces, cloth arcs | timber, worn metal, canvas, ceramic, soot | warm amber pools and practical lamps |
| Verdant Scar | alive, unstable, inviting, dangerous | sweeping roots, tilted trunks, broken curves | moss, bark, wet stone, altered chitin, wayline glass | green-gold daylight with cyan fractures |
| Meridian / Underroot | ancient, exact, impersonal | vertical slabs, rings, axial symmetry | pale stone, dark alloy, smooth ceramic, emissive channels | cool directional shafts and controlled cyan-white light |

Gleaners and altered creatures sit between these cultures rather than forming a fourth unrelated art style.

## 142.2 Screenshot Identity Test

A screenshot passes only when a viewer can identify at least two of these without interface text:

- the region;
- the dominant faction or threat;
- the immediate route;
- whether the space is safe, contested, or hostile;
- one memorable landmark;
- one unusual world rule, such as a wayline fracture or Meridian seal.

The test is performed at:

```text
wide establishing view
normal first-person exploration view
combat view with three enemy roles
mobile-sized capture
low graphics quality capture
```

If the image depends on tiny decals, high-resolution textures, or bloom to communicate identity, the identity is too fragile.

## 142.3 Visual Hierarchy

Every gameplay view should organize information in this order:

1. immediate threat or objective;
2. navigable route and cover;
3. landmark and spatial orientation;
4. interactable or secret clue;
5. ambient story detail;
6. decorative micro-detail.

The lower levels may enrich the scene but may not compete with the higher levels.

## 142.4 Shape Grammar

### Friendly frontier shapes

- broad bases;
- visible supports;
- rounded cloth and cable arcs;
- asymmetry that still appears stable;
- repeated hand-sized repair plates;
- vertical lamps and pennants used as wayfinding punctuation.

### Meridian shapes

- circles interrupted by straight cuts;
- tall narrow voids;
- repeated thirds;
- impossible-looking balance created through hidden support;
- surfaces that meet too cleanly for the frontier world;
- closed forms becoming open only when activated.

### Gleaner shapes

- forward-leaning silhouettes;
- cut and reassembled plates;
- triangular scrap guards;
- exposed fasteners;
- scavenged Meridian components mounted at the wrong angle;
- hazard-orange recognition accents.

### Altered wildlife shapes

- low center of gravity;
- strong directional head or forelimb silhouette;
- natural anatomy interrupted by luminous seams;
- asymmetry concentrated around the altered region;
- no random tentacles unless they create a gameplay verb.

## 142.5 Detail Distribution

Use a three-scale detail model:

```text
macro: landmark, massing, silhouette
medium: supports, openings, roots, panels, readable damage
micro: fasteners, scratches, moss breakup, decals
```

The target ratio is approximately:

```text
60% visually quiet support area
30% medium structural information
10% high-detail focal accents
```

This is a composition target, not a pixel formula. Hero objects may be denser, but a whole room cannot be a hero object.

## 142.6 Visual Motifs

Recurring motifs create memory:

- **Wayline split:** two lines diverging around a void, used for mystery and unstable energy.
- **Watch lamp:** warm vertical light inside a protective cage, used for safety and civilization.
- **Meridian ring:** incomplete circle with a precise missing segment, used for locks, machines, and boss armor.
- **Root embrace:** organic material wrapping but not fully consuming artificial structures, used for the Verdant Scar.
- **Survey mark:** three short painted strokes, used by explorers to indicate route, warning, or discovery.

Motifs must recur with meaning. They are not wallpaper stamps.

# 143. Composition, Scale, Navigation, and Combat Readability

## 143.1 Project Scale Baseline

All dimensions are provisional gameplay targets measured in studs and must be tested with the chosen player rig, camera FOV, movement speed, dodge distance, and enemy footprints.

| Element | Target |
|---|---:|
| Base construction grid | 4 studs |
| Preferred macro-module increments | 8, 16, or 32 studs |
| Standard single route width | 10–14 studs |
| Two-way combat lane | 16–24 studs |
| Major encounter arena width | 48–80 studs |
| Standard doorway clear width | 7 studs minimum |
| Standard doorway clear height | 10 studs minimum |
| Large enemy/boss doorway | 14–20 studs wide |
| Low cover height | 3–4 studs |
| Full cover height | 6.5–8 studs |
| Standard wall module height | 12 or 16 studs |
| Primary landmark visible distance | 150–300 studs where streaming permits |
| Secret clue recognition distance | 8–25 studs depending on clue level |

Dimensions are validated in first person, over-the-shoulder spectator views if used, mobile aspect ratios, and multiplayer congestion.

## 143.2 Route Composition

Primary routes use at least two of the following:

- value contrast;
- warm/cool contrast;
- repeated edge alignment;
- floor material change;
- overhead framing;
- directional prop placement;
- distant landmark;
- motion, such as cloth, drifting spores, or a wayline pulse;
- explicit objective indicator only when environmental guidance is insufficient.

Do not rely on a single yellow paint stripe everywhere. A universal paint solution makes different spaces feel like the same warehouse wearing plants.

## 143.3 Cover Language

Cover must be visually truthful.

### Full cover

- mass reaches clearly above the player camera center;
- silhouette reads as solid from combat distance;
- no deceptive decorative holes at head height;
- collision matches visible form closely enough for bullets and movement;
- top edge does not appear vaultable unless traversal supports it.

### Low cover

- repeated waist-height profile;
- enough width to support a deliberate crouch or lateral break if those verbs exist;
- never used as an invisible projectile blocker above its visible boundary.

### Soft concealment

Foliage, cloth, smoke, or light effects may obscure vision but are not hard cover unless the combat system treats them as such. The distinction must be taught consistently.

## 143.4 Encounter Arena Composition

Every arena provides:

- one readable entry and one fallback position;
- at least two lateral reposition routes;
- cover that answers Shooter pressure;
- open space that makes Pursuer pressure legible;
- a separation opportunity that counters Warden links;
- protected enemy entry points that do not look like player routes;
- one strong landmark for orientation;
- clear arena bounds without arbitrary invisible walls.

Arena art is reviewed with enemy debug paths and range rings visible. A beautiful prop arrangement that collapses AI lanes is rejected.

## 143.5 Height and Verticality

Verticality is used for orientation, tactical choice, and curiosity—not constant camera strain.

- Standard combat height change: 0–12 studs.
- Major overlook or route transition: 12–32 studs.
- Sniper or future threat perch: visually readable before use.
- Drops that cannot be reversed must announce commitment.
- Climbable or mantle-capable edges share a consistent profile and clearance.
- Ceiling clutter must not dominate the first-person view or catch the camera.

## 143.6 Negative Space

Reserve negative space around:

- enemy telegraphs;
- boss weak points;
- interactable silhouettes;
- loot presentation;
- major landmarks;
- player spawn and revive areas;
- objective text and world markers.

The environment is not complete when every empty corner has acquired a crate.

# 144. Color Script, Lighting, Atmosphere, and Weather

## 144.1 Palette Structure

Each location uses a **70/20/10** hierarchy:

```text
70% dominant environmental family
20% structural or faction contrast
10% focal gameplay accent
```

Critical gameplay accents are reserved. Decorative assets may not consume the same saturation and luminance range as enemy telegraphs, interactables, rare loot, or objectives.

## 144.2 Provisional Palette

| Use | Hex family | Notes |
|---|---|---|
| Emberwatch timber/earth | `#6B4A32`, `#8B6545` | warm, worn, low saturation |
| Emberwatch lamp | `#FFB45A`, `#FFD18A` | safety and civilization |
| Verdant canopy | `#385A3B`, `#64804A` | broad environmental base |
| Verdant altered growth | `#77B98B`, `#B0D38D` | biological anomaly, not objective color |
| Wayline cyan | `#54D6E6`, `#B6F7FF` | discovery and Meridian activation |
| Meridian stone | `#C9D1CC`, `#88938F` | pale, controlled, slightly green-gray |
| Meridian alloy | `#1F2A30`, `#34434A` | dark support and machinery |
| Gleaner hazard | `#D66B2C`, `#F1A044` | scavenger recognition and aggression |
| Hostile major tell | `#F0523D` plus shape/audio | never color-only |
| Friendly protection | `#79C6FF` plus stable outward motion | distinct from hostile compression |
| Fracture corruption | `#8A5DDA`, `#C09AFF` | instability and phase effects |

These colors are references, not hardcoded universal values. Lighting and material response must be tested for color-vision accessibility and low graphics quality.

## 144.3 Location Color Script

### Emberwatch

- late-afternoon warmth;
- cooler horizon and deep shadows to preserve depth;
- lamps visible before they are necessary;
- limited cyan Meridian remnants used as mystery accents;
- no permanent alarm-red ambience.

### Verdant Scar

- green-gold daylight filtered through canopy;
- cooler cyan seams around wayline activity;
- local fog used to separate depth planes, not conceal navigation;
- dangerous altered nests shift toward bruised violet or sickly pale green;
- encounter arenas retain readable neutral ground beneath effects.

### Underroot Vault

- cool low ambient level;
- strong authored shafts and activated channels;
- dark alloy frames against pale stone;
- secret spaces use quieter contrast, not simply “more blue”; 
- combat rooms lift exposure enough that black silhouettes do not vanish.

## 144.4 Lighting Rules

1. Primary navigation remains readable without bloom.
2. Critical enemy silhouettes remain visible against both bright and dark backgrounds.
3. Dynamic lights are accents, not the sole source of legibility.
4. Shadow casting is reserved for objects whose shadow materially improves depth or threat reading.
5. Flicker frequencies remain comfortable and have reduced-intensity alternatives.
6. Light color does not override faction or telegraph language.
7. Interior and exterior exposure transitions are tested without requiring long adaptation.

## 144.5 Atmosphere

Atmosphere communicates scale and biome state.

- Fog density increases with distance, never inside immediate combat readability unless the encounter is explicitly built around concealment.
- Foreground particles are sparse and slow.
- Midground motion carries wind, spores, ash, or dust.
- Background layers establish depth and weather.
- Screen-facing particles avoid crossing the crosshair continuously.

## 144.6 Weather States

The vertical slice uses one primary state per area and at most one controlled variation.

| Area | Primary | Optional variation | Gameplay consequence |
|---|---|---|---|
| Emberwatch | calm late afternoon | light rain after return | ambience only |
| Verdant Scar | humid filtered sun | brief wayline storm | exposes resource/secret clue; does not destroy visibility |
| Underroot | still cool interior | pulse surge | changes light channels and hazard timing |

Full procedural weather is postponed. Each state needs an art, audio, performance, and accessibility review.

# 145. Material, Texture, Surface, and Decal Language

## 145.1 Material Strategy

Use Roblox built-in materials and MaterialVariants for broad repeatable surfaces. Use MeshPart textures and SurfaceAppearance selectively for hero assets and surfaces whose roughness, metalness, normal, or emissive response materially contributes to identity. PBR is a tool, not the definition of quality.

## 145.2 Material Families

### Frontier family

- rough timber with broad grain;
- painted metal with worn edges, not uniform procedural scratches;
- dark forged metal for load-bearing parts;
- canvas and rope with large folds readable at distance;
- ceramic or stone heat shields around machinery;
- soot concentrated by function.

### Verdant family

- bark divided into two or three broad species patterns;
- wet and dry stone variants;
- moss applied by growth logic and moisture, not random noise;
- altered chitin with controlled pearlescence;
- translucent growth used sparingly because transparency is expensive and visually loud;
- wayline crystal or glass with emissive seams, not fully glowing blobs.

### Meridian family

- pale micro-textured stone or ceramic;
- dark low-roughness alloy only on machine joints and frames;
- narrow emissive channels;
- etched rings and cuts with consistent scale;
- clean surfaces interrupted by age through fractures, deposits, and displaced geometry rather than generic grunge.

## 145.3 Texture Allocation

Provisional maximums before profiling:

| Asset class | Typical texture strategy |
|---|---|
| First-person weapon | one 1024–2048 hero atlas or equivalent material set |
| World weapon | shared 1024 atlas or reduced companion set |
| Regular enemy | one 1024 main set; optional small emissive/mask support |
| Boss | up to two 2048 hero sets only with device evidence |
| Modular environment kit | shared 1024 trim sheet plus reusable materials |
| Medium prop | 512–1024 shared atlas |
| Small prop/decal | 256–512 atlas region |
| Foliage cluster | 512–1024 shared family atlas |

These are project budgets, not engine limits. Reuse and observed memory cost decide final values.

## 145.4 Texel and Detail Consistency

- First-person assets receive the highest detail density.
- Hero landmarks receive high density only near reachable surfaces.
- Modular walls maintain consistent apparent density across pieces.
- Large terrain forms rely on materials, vertex color, decals, and geometry breakup rather than one enormous unique texture.
- Tiny text is avoided on world props because it becomes noise across devices and localization contexts.

## 145.5 Roughness and Metalness Rules

- Most world surfaces are non-metallic.
- Metalness is used only where the material is visibly metal.
- Frontier metal is generally rough and worn; Meridian machine surfaces may be smoother but are not mirror-polished.
- Wetness changes roughness and value locally, not the base identity of every surface.
- Emissive surfaces retain visible structure and do not become flat white under bloom.

## 145.6 Decal Grammar

Decals fall into named functions:

```text
WAYFINDING
FACTION
DAMAGE
WEATHERING
STORY
GAMEPLAY_CLUE
```

Each decal asset declares its function. Gameplay-clue decals cannot be reused as generic grime. Damage decals follow impact, heat, water, traffic, or age logic.

## 145.7 Surface Acceptance

A material or texture passes when:

- it reads at intended camera distance;
- it survives low graphics settings;
- it does not create shimmering or excessive high-frequency noise;
- it supports the region palette;
- it uses an approved material family;
- it fits atlas and memory strategy;
- its collision and physical material behavior are intentional;
- its emissive behavior remains readable without bloom.

# 146. Modular Environment Metrics and Kit Contracts

## 146.1 Grid and Pivot Standard

- Base grid: 4 studs.
- Primary room dimensions: multiples of 8 studs.
- Large room masses: multiples of 16 or 32 studs.
- Pivots sit on the intended snap point, normally floor center or socket center.
- Forward direction is documented per kit.
- Room modules include a visible development-only origin marker that is removed or disabled in production.
- Scale is frozen before texture and collision approval.

## 146.2 Socket Contract

Every procedural or reusable connection socket declares:

```lua
SocketId: string
SocketType: "Door" | "Hall" | "Drop" | "Lift" | "Secret" | "Vista" | "EnemyEntry"
Width: number
Height: number
Forward: Vector3
ClearanceDepth: number
ThemeId: string
TraversalTags: {string}
SealAssetId: string?
```

Visual frame, collision opening, navigation clearance, and data socket must agree.

## 146.3 Wall and Floor Modules

Each theme provides:

- straight wall 4, 8, and 16 studs;
- inner and outer corners;
- damaged or open variants;
- floor 8×8 and 16×16;
- height transition and stair/ramp modules;
- ceiling or canopy modules where needed;
- door frame and sealed frame;
- cover inserts;
- lighting anchor variants;
- trim and end caps;
- streaming-safe landmark connectors.

## 146.4 Collision Standard

- Use simple collision primitives where possible.
- Visual holes that appear traversable must either be traversable or clearly blocked.
- Cover collision follows visible edges.
- Decorative foliage does not create invisible movement barriers.
- Small floor detail does not create character snag points.
- Enemy navigation test rigs are run through every gameplay-ready module.
- First-person camera collision is tested at corners and narrow doors.

## 146.5 Variant Strategy

Variation comes from combinations of:

- structural module;
- material tint or approved variant;
- prop cluster;
- decal set;
- damage state;
- lighting anchor;
- foliage or deposit layer;
- encounter dressing.

Do not create a new structural mesh merely to move one bolt.

## 146.6 Prefab Ownership

Each prefab has one owner and one assembly source. Runtime copies are generated from or linked to that source according to the project workflow. Manual edits to scattered copies are prohibited because they create invisible divergence.

## 146.7 Kit Validation Scene

Every kit includes a test place or isolated scene with:

- all modules arranged by category;
- pivot and grid demonstration;
- material and lighting comparison;
- collision test route;
- player and enemy scale references;
- low and high graphics captures;
- streaming test;
- memory and render stats capture;
- known limitations.

# 147. Emberwatch Hub Environment Specification

## 147.1 Fantasy and Function

Emberwatch is a frontier survey outpost built around a recovered wayline beacon. It must feel safe, useful, expandable, and slightly temporary. Players should believe the settlement can survive, but also understand that the world beyond it is larger and older.

The hub is not a decorative city. It is a compact preparation space that teaches the game's visual grammar and points toward future mysteries.

## 147.2 Hub Zones

### Arrival Ramp

Purpose:

- spawn orientation;
- first view of the beacon and expedition gate;
- low-risk movement tutorial;
- visual contrast between patched frontier construction and Meridian remains.

Art requirements:

- broad ramp and handrail silhouette;
- warm lamps forming a path;
- one distant sealed route visible beyond the playable branch;
- no crowd or prop density that obscures the first objective.

### Survey Hall

Purpose:

- mission and map selection;
- Mara Vale or equivalent guide NPC;
- region model, charts, and visual foreshadowing.

Art requirements:

- radial composition around a table or projection surface;
- hanging maps and sample objects organized by region;
- one Meridian fragment integrated into frontier furniture;
- clear interaction pockets for multiple players.

### Forge Terrace

Purpose:

- salvage, crafting, equipment explanation;
- material identity;
- visible transformation from scrap into useful gear.

Art requirements:

- hot orange work light balanced against cool exterior;
- broad equipment silhouettes rather than a forest of tiny tools;
- safe separation between social path and animated machinery;
- sparks and smoke limited to local accents.

### Expedition Gate

Purpose:

- departure, party readiness, and run start;
- strongest outward-facing composition.

Art requirements:

- framed view toward the Verdant Scar;
- readable readiness pads or interaction positions;
- survey marks and supply staging;
- gate machinery that can visually move from idle to active;
- clear separation between cosmetic animation and teleport/run state.

### Watch Overlook

Purpose:

- social pause;
- view of future landmarks;
- optional lore and screenshot space.

Art requirements:

- uncluttered horizon;
- foreground framing element;
- at least three depth layers;
- one animated distant world event or wayline pulse at low frequency.

## 147.3 Hub Kit Manifest

Vertical-slice target:

```text
Floor/deck modules: 8
Wall/railing modules: 10
Roof/canopy modules: 6
Stair/ramp modules: 5
Door/gate modules: 4
Structural supports: 8
Lamp families: 3
Furniture families: 5
Utility machinery: 4
Landmark pieces: beacon, tower, Meridian arch
Prop clusters: 10
Damage/weathering variants: 6
```

Counts are production targets, not promises to expose every variant in the first build.

## 147.4 Hub Palette and Lighting

- dominant warm timber and earth;
- dark support metal;
- amber safety lamps;
- cool blue horizon and Meridian accents;
- no aggressive combat red outside alerts;
- NPC faces and interactables receive readable key light without stage-like spotlights.

## 147.5 Hub Population and Motion

Ambient motion may include:

- one repair loop;
- one survey discussion loop;
- cloth and cable movement;
- slow beacon pulse;
- supply lift or gate mechanism;
- distant patrol silhouettes.

Loops must be asynchronous enough to avoid robotic synchronization and sparse enough to protect performance and social readability.

## 147.6 Hub Acceptance

- New players identify the expedition gate within ten seconds without a giant permanent arrow.
- All major services are visible from a compact route.
- The beacon, gate, and sealed future route remain recognizable on low graphics.
- Four players can stand at each major service without collision confusion.
- Hub lighting distinguishes safe space from the biome without making the biome appear visually inferior.
- No ambient animation can block an interaction or trap a player.

# 148. Verdant Scar Environment Specification

## 148.1 Fantasy and Function

The Verdant Scar is a living frontier rupture where an old Meridian line has altered terrain and wildlife. It must communicate wonder and danger simultaneously. The route begins legible and familiar, then becomes increasingly strange as natural and artificial forms interlock.

## 148.2 Route Beats

### Beat 1 — Survey Boundary

- Last warm lamps from Emberwatch.
- Clear path and low vegetation.
- First survey marks.
- A distant Meridian structure establishes direction.
- Pursuer lesson occurs in open space.

### Beat 2 — Split Root Crossing

- Large root or fallen trunk divides the path.
- Two readable lanes with different cover quality.
- Shooter lesson uses exposure and hard cover.
- One optional side observation reveals altered wildlife behavior.

### Beat 3 — Gleaner Camp

- Scavenged frontier and Meridian components.
- Orange faction accents.
- Improvised firing positions.
- Environmental story shows the Gleaners are extracting or misusing wayline material.
- Route through camp remains readable after combat clutter appears.

### Beat 4 — Quiet Basin

- Lower threat density.
- Strong landmark reflection or water element.
- Pulse Mark secret clue.
- Contrast beat before mixed encounter.
- Optional cache positioned so discovery feels earned, not randomly hidden in grass.

### Beat 5 — Scar Convergence

- Roots bend toward Meridian geometry.
- Warden presence introduces precise cool light.
- Mixed combat arena supports spacing, cover, and target priority.
- Background shows Underroot entrance before the player reaches it.

### Beat 6 — Underroot Threshold

- Organic forms recede.
- Meridian rings and vertical slabs dominate.
- Warm expedition lamps mark the last safe checkpoint.
- Door activation visually explains that a run instance is beginning.

## 148.3 Terrain and Foliage Layers

Use three vegetation layers:

```text
canopy: large silhouette and light breakup
mid layer: route framing, cover context, species identity
ground layer: local variation and clue support
```

Ground foliage must not conceal loot, hazards, low enemies, or interaction prompts. Collision is disabled on most decorative foliage. Gameplay plants receive distinct silhouette, spacing, and interaction feedback.

## 148.4 Foliage Families

Vertical-slice target:

- 3 tree/trunk families;
- 3 large root families;
- 4 bush or fern clusters;
- 3 ground-cover clusters;
- 2 hanging vine families;
- 2 altered growth families;
- 1 wayline-reactive plant family;
- dead/damaged variants for two major families.

Each family includes close, medium, and simplified distant presentation where needed.

## 148.5 Landmark Set

- Split Crown Tree: navigation anchor and first reveal.
- Broken Survey Mast: human scale and route confirmation.
- Gleaner Extractor: faction landmark and combat objective context.
- Scar Pool: quiet basin and reflection landmark.
- Meridian Needle: distant vertical orientation anchor.
- Underroot Ring: dungeon threshold and mystery payoff.

## 148.6 Secret Clue Language

Secrets use combinations of:

- roots bending against normal growth direction;
- survey marks that stop or diverge;
- subtle cyan pulse synchronized with audio;
- repeated small Meridian motif;
- displaced ground cover;
- local wind or particle movement;
- creature attention or tracks.

Pulse Mark intensifies or confirms the clue; it should not replace the clue.

## 148.7 Biome Hazard Language

| Hazard | Shape | Motion | Color/audio | Safe response |
|---|---|---|---|---|
| Wayline vent | narrow crack with branching edge | pressure build then upward release | cyan-white with rising tone | step away or time crossing |
| Spore cloud | visible volume and source pod | expanding slow billow | pale green with soft warning pulse | avoid or wait |
| Unstable root | lifted arc with stress marks | bend, snap, sweep | bark crack and ground dust | move laterally |
| Fracture zone | separated floating fragments | rhythmic phase offset | violet echo and low hum | leave marked boundary |

No hazard is invisible before damage.

## 148.8 Verdant Scar Acceptance

- Players can navigate from Emberwatch boundary to Underroot without objective markers after one guided run.
- Cover truth remains consistent through foliage.
- The biome is recognizable in grayscale silhouette and in low-quality capture.
- Secret clues remain visible without Pulse Mark but become easier to interpret with it.
- Enemy colors remain distinct against green backgrounds.
- Foliage and particles do not dominate fill rate or obscure the crosshair.
- Terrain transitions do not create navigation traps for AI or players.

# 149. Underroot Vault Environment Specification

## 149.1 Fantasy and Function

Underroot Vault is an ancient Meridian transit and containment structure exposed by the Scar. It must feel constructed by a culture with precise rules, then invaded by roots, water, scavengers, and unstable energy.

The theme supports procedural assembly through strong module grammar. A player should know that rooms belong to the same complex while still recognizing room function and route choice.

## 149.2 Spatial Grammar

- Vertical slabs define boundaries.
- Incomplete rings define doors, machines, and objectives.
- Dark frames carry mechanical motion.
- Pale surfaces define traversable architecture.
- Roots and deposits indicate age and damage, not random biome paste.
- Cyan channels indicate dormant or active systems.
- Violet fracture effects indicate malfunction or danger.

## 149.3 Room Families

### Entrance

- decompression from biome to vault;
- clear back-facing exit state;
- visual summary of Meridian door language;
- low combat pressure.

### Connector

- short orientation reset;
- one dominant axis;
- controlled vista or light direction;
- low prop density;
- no encounter that requires complex pathing.

### Combat Crossing

- central obstacle or bridge;
- two lateral cover routes;
- enemy entry silhouettes separated from player route;
- overhead ring or shaft as orientation anchor.

### Combat Chamber

- 48–72 stud primary width;
- at least three combat lanes;
- Warden separation opportunity;
- floor pattern supporting range judgment;
- no decorative pillars that produce unreadable projectile clipping.

### Traversal Room

- one clear main traversal verb;
- safe observation before commitment;
- failure recovery or checkpoint strategy;
- route silhouette visible even when effects are reduced.

### Secret Room

- distinct quiet composition;
- lower visual density;
- clue continuity from preceding room;
- reward focal area with negative space;
- optional route never required for boss access.

### Elite Room

- stronger symmetry and enclosed threshold;
- modifier presentation space;
- controlled enemy entry points;
- visible reward lock state.

### Boss Antechamber

- rest and anticipation;
- Gatekeeper motif introduced at human scale;
- loadout and party readiness clarity;
- one-way threshold communicated without surprise.

### Boss Arena

- large central silhouette;
- outer traversal ring;
- clear hazard sectors;
- protected phase-transition staging;
- high-contrast weak-point backgrounds;
- reset-safe geometry and VFX anchors.

## 149.4 Socket and Seal Language

Door states:

```text
Dormant: dark channel, closed ring
Available: low cyan circulation
Locked by encounter: amber or red-orange segmented barrier plus icon/audio
Secret: incomplete local clue, no full objective treatment
Activated: ring opens through controlled mechanical sequence
Broken: asymmetrical physical damage, not merely a red light
```

## 149.5 Procedural Variety Without Visual Noise

A seed varies:

- room order;
- approved structural variants;
- root/deposit dressing;
- damage state;
- encounter dressing;
- optional branch;
- secret placement;
- lighting state within bounded palettes.

A seed does not randomly recolor the whole vault, rotate gravity, or replace every clean surface with clutter.

## 149.6 Underroot Kit Manifest

Vertical-slice target:

```text
Entrance: 1
Connector structures: 3
Combat structures: 5
Traversal structures: 2
Secret structures: 2
Elite structure: 1
Boss antechamber: 1
Boss arena: 1
Exit/return: 1
Fallback route: 1
Door/seal families: 4
Column/frame families: 5
Floor pattern families: 4
Root/deposit overlays: 8
Damage variants: 8
Lighting anchor sets: 5
```

## 149.7 Underroot Acceptance

- Room function reads within three seconds of entry.
- Critical path and optional branch remain distinguishable without identical arrows.
- Procedural variants never break socket, collision, lighting, or navigation rules.
- Boss route is always visually and mechanically reachable.
- Clean, overgrown, damaged, and active states still read as the same architectural culture.
- Low graphics mode preserves door, hazard, weak-point, and objective language.

# 150. Props, Foliage, Damage, Destruction, and Environmental Storytelling

## 150.1 Prop Tiers

### Tier A — Gameplay prop

Examples: cover, explosive hazard, interactable switch, cache, objective device.

Requirements:

- unique silhouette;
- collision and state contract;
- gameplay VFX/audio anchors;
- damage or interaction state;
- explicit ownership and tests.

### Tier B — Narrative prop

Examples: survey kit, abandoned meal, Gleaner extraction rig, specimen rack.

Requirements:

- communicates one story idea;
- does not imitate an interactable;
- uses approved kit materials;
- placed in authored clusters.

### Tier C — Dressing prop

Examples: cable coil, broken tile, small container, moss clump.

Requirements:

- atlas reuse;
- low collision or none;
- low material count;
- density controlled by budget.

## 150.2 Prop Cluster Rules

A prop cluster has:

- one focal object;
- two to five supporting objects;
- a clear orientation or use story;
- negative space around gameplay routes;
- optional decal or wear layer;
- one approved variant rather than dozens of random rotations.

## 150.3 Damage States

Damage is authored by cause:

```text
impact
heat
corrosion
root pressure
wayline fracture
scavenger dismantling
age/water
```

Each cause has characteristic edge shape, debris, discoloration, and VFX residue. Damage does not default to generic black scratches.

## 150.4 Destruction Scope

Vertical-slice destruction is state-based, not free-form physics destruction.

Supported examples:

- cache opens;
- weak barrier breaks;
- boss armor panel detaches;
- Gleaner device overloads;
- small prop reacts or collapses locally;
- gate transitions through authored states.

Each destructible declares:

```text
intact state
telegraph state
transition event
broken state
collision change
navigation impact
cleanup/reset policy
replication owner
performance fallback
```

## 150.5 Environmental Storytelling Grammar

A story vignette contains:

```text
actor or faction trace
purpose
interruption
consequence
question or payoff
```

Example:

> A survey crew anchored a measuring rig, roots grew toward the active instrument, and the final chalk marks lead away from the official path.

The vignette should be understood at a glance and rewarded by closer inspection. It does not require a paragraph of text to become meaningful.

## 150.6 Repetition Rules

- Signature prop clusters do not repeat in adjacent rooms.
- Rotated duplicates remain recognizable as duplicates; use them sparingly.
- Important story props are not used as generic filler elsewhere.
- Procedural dressing uses weighted sets and exclusion tags.
- Props that resemble loot or interactables are reserved for those functions.

# 151. Player, Faction, and Enemy Visual Specification

## 151.1 Player Visual Goal

Players should look like capable frontier explorers using recovered technology, not identical military operators or ornate fantasy royalty. The equipment language must support Roblox avatar expression while preserving combat readability.

## 151.2 Player Silhouette Layers

```text
base avatar/body
functional harness or frontier layer
archetype-readable equipment
weapon silhouette
optional cosmetic layer
temporary gameplay state
```

Gameplay state always renders above cosmetic ambiguity. A bulky cosmetic may not hide a downed state, weak-point indicator, team outline, or weapon muzzle.

## 151.3 Archetype Shape Accents

- Pathfinder: forward equipment, compact sensor shapes, narrow antenna or lens motif.
- Bastion: broader shoulder and forearm protection, stable rectangular equipment.
- Conduit: cable loops, energy-routing nodes, soft circular motifs.
- Machinist: asymmetrical tool mounts, deployed device silhouette, articulated components.

These are readable accents, not mandatory full-body uniforms.

## 151.4 Faction Recognition Matrix

| Faction | Primary silhouette | Motion posture | Accent | Surface |
|---|---|---|---|---|
| Emberwatch | upright, layered, stable | purposeful and grounded | amber | patched frontier materials |
| Gleaners | forward, angular, uneven | opportunistic and quick | orange | scrap, exposed fasteners |
| Meridian | vertical, balanced, axial | precise and economical | cyan-white | pale stone, dark alloy |
| Altered creatures | low, directional, asymmetrical | animal force interrupted by phase behavior | biological cyan/violet | hide, chitin, luminous seams |

## 151.5 Pursuer Visual Specification

Role: close-distance pressure.

Silhouette:

- low forward body line;
- large forelimbs or shoulder mass;
- narrow rear profile;
- head or core aligned toward travel direction;
- weak point positioned so retreating players can still identify it during recovery.

Animation-supporting anatomy:

- clear compression before lunge;
- forelimb or shoulder arc that shows attack direction;
- tail, plates, or spines that settle during recovery;
- no secondary appendage motion that mimics another attack.

Color:

- subdued natural body;
- altered seams brighten during telegraph;
- weak point distinct by shape and rhythm as well as color.

## 151.6 Gleaner Shooter Visual Specification

Role: exposure pressure.

Silhouette:

- upright or half-crouched humanoid/scavenger profile;
- weapon visibly longer than Breacher-class future variants;
- recognizable shoulder or backpack rig;
- orange cloth or plate accent readable at range.

Weapon and aim language:

- barrel or sight glow builds during telegraph;
- body settles and narrows before burst;
- recoil is readable but does not throw aim animation into comedy;
- reload or cooldown posture creates a clear punish window.

## 151.7 Meridian Warden Visual Specification

Role: support and target priority.

Silhouette:

- tallest of the three proof enemies;
- narrow central body with outward link arms, fins, or ring segments;
- stable vertical posture;
- protected core visible through deliberate opening.

Link language:

- source ring opens before link;
- beams or arcs connect cleanly without covering target silhouettes;
- linked target receives a shell or segmented orbit, not a full opaque bubble;
- source death visibly collapses all links.

## 151.8 Gatekeeper Visual Specification

The Gatekeeper combines Meridian precision with visible age and containment damage.

- broad central core and readable weapon arm;
- incomplete ring motif at boss scale;
- armor panels separate cleanly into weak-point states;
- phase two adds instability through displacement and fracture, not random extra horns;
- silhouette remains recognizable during all VFX peaks;
- arena hazards use the same geometric language as the boss.

# 152. Weapon Art, First-Person Viewmodel, and Cosmetic Boundaries

## 152.1 Two-Model Rule

Each weapon has:

```text
FP model: camera-composed proportions and animation hierarchy
World model: third-person, pickup, inventory preview, and enemy-view proportions
```

The models share identity, material language, named attachments, and major moving parts. They do not need identical geometry.

## 152.2 First-Person Composition

At hip fire:

- muzzle remains below or to the side of the crosshair;
- weapon occupies roughly the lower-right or chosen handedness region without covering central threat space;
- moving parts remain visible during fire and reload;
- hands do not clip the camera at standard FOV;
- wide and narrow mobile aspect ratios are tested.

At aim-down-sights:

- sight picture is clean;
- peripheral threat visibility remains acceptable;
- weapon depth does not create excessive near-plane clipping;
- reticle and physical sight do not disagree about aim.

## 152.3 Frontier Rifle Art Specification

Identity:

- dependable survey weapon;
- long rectangular receiver softened by frontier grip and stock materials;
- visible magazine and chamber action;
- one Meridian-derived targeting component integrated rather than pasted on;
- worn but maintained.

Required hierarchy:

```text
Root
Grip_R
Grip_L
Magazine
Bolt_or_Action
Trigger
Muzzle
AimReference
ShellEject
VFX_Muzzle
VFX_ImpactOrigin
CosmeticSockets
```

## 152.4 Breach Shotgun Art Specification

Identity:

- compact, heavy, close-range tool;
- broad muzzle and reinforced fore-end;
- clear shell or magazine logic;
- stronger vertical recoil silhouette;
- distinct enough from rifle in monochrome inventory view.

## 152.5 Cosmetic Boundaries

Cosmetics may change:

- color family within readability limits;
- approved material variant;
- small non-gameplay attachments;
- decals and wear pattern;
- charm or trophy position outside sight picture;
- inspect animation flourish later.

Cosmetics may not:

- alter sight alignment;
- obscure muzzle or reload state;
- change perceived weapon family;
- imitate rarity or hostile telegraph colors misleadingly;
- increase model footprint enough to block view;
- change timing, recoil, or gameplay state.

## 152.6 Weapon Asset Acceptance

- Correct named hierarchy.
- FP and world silhouettes match identity.
- Aim reference and muzzle are exact.
- Reload parts move without clipping.
- Hands support multiple avatar proportions or use a controlled viewmodel rig.
- Material slots meet budget.
- World model reads at pickup and enemy-view distance.
- Reduced-quality model remains recognizable.

# 153. Animation Architecture, Rigs, Layers, and State Contracts

## 153.1 Animation Ownership

Animation is presentation and timing coordination. The server owns mechanical state, target validity, damage, invulnerability, cooldown, and rewards.

For server-authoritative attacks:

```text
server enters telegraph state
→ animation starts on approved rig
→ replicated state and presentation play
→ server reaches commitment time
→ server validates target/world state
→ server opens active window
→ server resolves hit
→ animation continues or corrects
→ server enters recovery
```

An animation event marker may trigger sound, VFX, camera, or local presentation. It does not independently grant damage.

## 153.2 Rig Standard

Each animated rig declares:

- rig type and scale;
- root and movement owner;
- bone or Motor6D hierarchy;
- named attachments;
- Animator location;
- collision model;
- hit volumes and weak-point attachments;
- IK targets if used;
- weapon mount points;
- VFX/audio anchors;
- LOD or simplified animation strategy;
- import/export version.

R15-compatible player animation is preferred unless a controlled custom viewmodel or character requirement justifies another rig.

## 153.3 Layer Stack

Recommended logical stack:

```text
1. locomotion base
2. stance and weapon upper body
3. action override: reload, ability, interaction
4. additive recoil or aim offset
5. hit reaction or status response
6. full override: downed, death, cinematic
```

Every clip declares whether it is full-body, upper-body, additive, or procedural.

## 153.4 Priority Contract

| Priority | Examples | Interruption rule |
|---|---|---|
| Ambient | idle variation, look | interrupted by any action |
| Locomotion | walk, run, strafe | blends with upper body |
| Combat stance | aim, ready, fire support | interrupted by reload/ability according to weapon rule |
| Action | reload, ability, interact | only approved cancel windows |
| Reaction | light hit, stagger | light reactions may be additive; stagger can interrupt |
| Critical | downed, death, boss transition | cannot be silently overridden |

## 153.5 Marker Naming Standard

```text
Foot_L
Foot_R
Muzzle
ShellEject
MagOut
MagIn
Chamber
Commit
HitboxOn
HitboxOff
AbilityRelease
VFX_Start
VFX_Stop
InvulnOn
InvulnOff
InteractContact
PropRelease
RecoveryStart
```

Marker names are stable API. Renaming requires code/search review and asset-version update.

## 153.6 Clip Metadata

Each clip records:

```text
AnimationId
RigVersion
Duration
Looped
Priority
Layer
BlendIn
BlendOut
RootMotionPolicy
Markers
CancelWindows
GameplayStateId
Author
Revision
ApprovalState
```

## 153.7 Root Motion Policy

Default:

- player locomotion movement comes from the character controller, not baked root translation;
- first-person recoil and sway are local presentation;
- enemy attack displacement is server state/controller-driven and synchronized with the clip;
- cinematic or boss transitions may use controlled authored movement only with reset-safe fallback;
- no clip silently moves a damage volume independently from the authoritative entity root.

## 153.8 IK Policy

Use IK selectively for:

- support hand placement on weapon;
- foot contact on modest slopes;
- hand-to-interactable alignment;
- head or sensor tracking within restrained angles;
- Gatekeeper hand/weapon contact during authored transitions.

IK is disabled or reduced when it causes jitter, silhouette loss, excessive cost, or conflict with first-person presentation. Authored animation remains the readable base.

# 154. Player Locomotion, Traversal, Interaction, and Social Animation

## 154.1 Locomotion Set

Minimum third-person set:

```text
idle relaxed
idle combat
walk forward/back/strafe
run forward/back/strafe
sprint
start and stop accents if affordable
jump start
air loop
land light
land heavy
dodge by supported direction
turn-in-place or aim correction if needed
downed idle and crawl
revive giver and receiver
```

## 154.2 Locomotion Style

- Frontier explorers move with grounded weight and clear intent.
- Sprint leans forward without hiding weapon state.
- Strafing keeps the upper body oriented toward aim while feet support direction.
- Jump is practical, not acrobatic.
- Heavy land communicates recovery without stealing control unexpectedly.
- Dodge reads as a committed evasion, not teleportation unless a future ability explicitly is one.

## 154.3 Speed Matching

Animation stride is matched to controller speed within a tolerable range. If speed changes substantially through buffs or device conditions, playback speed may adjust within approved bounds before a different clip is required.

Foot sliding acceptance:

- none obvious at standard walk/run speeds;
- minor sliding allowed during network correction or extreme slope only if not persistent;
- first-person camera motion does not amplify third-person foot correction.

## 154.4 Dodge Contract

Prototype phases:

```text
anticipation: 0.08–0.12 s
travel: 0.16–0.22 s
recovery presentation: 0.12–0.20 s
```

Mechanical timing comes from the movement system. Animation follows direction, preserves readable facing, and does not imply invulnerability outside the actual window.

## 154.5 Interaction Animation

Interaction clips use a three-part contract:

```text
approach/align
contact/commit
release/return
```

The interaction system may use IK or a small authored alignment zone. The player may not be dragged through walls or across large distances to satisfy a hand pose.

## 154.6 Revive Animation

- giver visibly commits to the downed player;
- receiver state remains readable to all players;
- interruption has a clear break reaction;
- progress UI and animation timing agree;
- first-person version does not hide incoming threats completely;
- revive completion marker triggers presentation only after server confirmation.

## 154.7 Social and Hub Loops

Ambient player emotes and NPC loops:

- remain short and interruptible;
- avoid blocking service NPCs;
- do not imitate combat, downed, or objective signals;
- use small spatial footprints;
- avoid synchronous crowd repetition;
- have reduced-motion or low-density alternatives.

# 155. First-Person Weapon, Camera, and Ability Animation

## 155.1 First-Person Motion Budget

All values are provisional and subject to comfort testing.

| Motion | Target limit |
|---|---:|
| Idle sway translation | 0.03–0.08 studs |
| Idle sway rotation | 0.2–0.8 degrees |
| Walk bob translation | 0.04–0.12 studs |
| Sprint bob translation | 0.08–0.18 studs |
| Camera recoil per rifle shot | 0.3–0.8 degrees before tuning |
| Weapon visual recoil | may exceed camera recoil but returns predictably |
| ADS transition | 0.15–0.25 seconds |
| Standard equip | 0.35–0.65 seconds |
| Standard rifle reload | synchronized to 1.8-second mechanic |

Reduced camera motion scales or disables bob, roll, FOV pulse, and shake without removing weapon-state information.

## 155.2 Fire Animation

Fire is layered:

```text
mechanical action
weapon kick
hand/arm response
muzzle VFX
camera response
sound
crosshair/hit confirmation
```

The weapon returns along a predictable path. Randomness belongs primarily in gameplay recoil/spread rules and small visual variation, not violent camera noise.

## 155.3 Reload Animation Contract

Frontier Rifle prototype:

```text
start and weapon check
MagOut marker
old magazine clears weapon
new magazine enters frame
MagIn marker
seated confirmation
Chamber marker if required
return to ready
```

The server owns reload start, legal interruption, completion, and ammunition. Markers align presentation with approved state transitions.

Cancel policy:

- before magazine removal: cancel may leave ammunition unchanged;
- after removal and before insertion: state must be explicitly defined;
- after server completion: visual can accelerate to ready but cannot undo ammo;
- weapon swap and ability use follow explicit compatibility rules.

## 155.4 Aim-Down-Sights

- sight aligns to camera using an authored reference;
- support hand and weapon parts remain stable;
- FOV change is restrained and optional in accessibility settings;
- sway and recoil reduce or change according to mechanics;
- transition does not temporarily expose an incorrect crosshair;
- third-person aim pose reflects intent without matching every FP micro-motion.

## 155.5 Pulse Mark Animation

Prototype timing:

```text
cast anticipation: 0.25 s
release marker: AbilityRelease
world pulse expansion: approximately 0.35–0.55 s presentation
recovery: 0.35 s
mark and secret results: server-confirmed
```

Visual action:

- off-hand or sensor moves into view;
- concentric split-wayline motif forms;
- pulse expands away from the player;
- confirmed targets receive clean mark treatment;
- no-target cast still completes and enters cooldown;
- rejected cast corrects without leaving a fake mark.

## 155.6 Damage and Low-Health Response

- directional response uses edge cues and controlled camera impulse;
- repeated light hits do not stack into uncontrollable camera shake;
- major telegraphed damage may use a stronger but brief response;
- low health uses audio, UI, and restrained visual treatment;
- color grading does not remove enemy or route readability;
- accessibility option reduces or disables chromatic, blur, and vignette effects.

# 156. Enemy Animation Sets and Telegraph Contracts

## 156.1 Universal Enemy Set

Each launch enemy requires:

```text
idle
locomotion
alert/acquire
turn or aim adjustment
attack telegraph
commit/active
recovery
damage reaction light
damage reaction weak point
stagger
status reaction if visually necessary
death
spawn/entry if used
```

## 156.2 Telegraph Standard

Every damaging attack communicates:

- **who** is attacking through pose and focus;
- **where** the attack will travel through body, weapon, ground, or VFX alignment;
- **when** it will commit through a rising motion/audio rhythm;
- **how** to respond through readable space and recovery;
- **what happened** through hit or miss consequence.

Telegraph duration is tuned by threat, tracking, area, and player reaction demand—not by animation aesthetics alone.

## 156.3 Pursuer Lunge

Provisional timing envelope:

```text
acquire/face: 0.10–0.20 s
compression telegraph: 0.45–0.65 s
commit travel: 0.16–0.24 s
active hit window: 0.08–0.14 s
recovery: 0.55–0.80 s
```

Animation requirements:

- body mass compresses visibly;
- luminous seams intensify toward commitment;
- attack direction locks near `Commit`;
- forelimbs or shoulder lead the path;
- miss produces a readable overextension;
- recovery exposes the weak point;
- hit reaction cannot silently cancel the attack after commitment unless stagger rules permit it.

## 156.4 Gleaner Shooter Burst

Provisional timing envelope:

```text
seek/settle: 0.20–0.40 s
aim telegraph: 0.40–0.65 s
three shots: 0.12–0.18 s spacing
burst recovery: 0.65–1.00 s
```

Animation requirements:

- shoulders and weapon settle into a narrow firing line;
- sight or barrel cue rises before first shot;
- each shot has distinct recoil and muzzle marker;
- target tracking reduces or locks according to mechanical rule before firing;
- cover impact and miss direction remain visible;
- recovery opens the body and breaks firing silhouette.

## 156.5 Meridian Warden Link

Provisional timing envelope:

```text
select targets: hidden server process
ring-open telegraph: 0.45–0.70 s
link establishment: 0.20–0.35 s
sustain: state-driven
link loss reaction: 0.15–0.30 s
```

Animation requirements:

- fins/rings open away from the core;
- source posture becomes rooted and less mobile;
- link origin points remain stable;
- linked allies receive subtle synchronized motion or VFX, not forced animation interruption;
- Warden death collapses structure inward and visibly terminates links.

## 156.6 Warden Pulse

```text
anticipation: 0.55–0.80 s
release: radial ground/body cue
active resolution: one server-owned event per target
recovery: 0.70–1.00 s
```

The pulse cannot visually resemble friendly Pulse Mark. Hostile motion compresses then bursts outward with sharper segmentation and hostile audio.

## 156.7 Hit Reactions

Reaction rules:

- light body hits use small additive recoil and do not stunlock;
- weak-point hits use a distinct directional reaction and feedback cue;
- stagger is a state with clear entry and recovery;
- repeated hits select from limited variants without resetting the whole body every frame;
- death interrupts all non-critical tracks and cleans status presentation;
- reaction intensity scales with damage class, not raw firing rate alone.

## 156.8 Death Animation

- death direction may consider impact direction within bounded variants;
- silhouette settles quickly enough not to remain false threat;
- collision and targeting state change from server truth, not the final pose;
- corpse lifetime and dissolve/cleanup are performance-controlled;
- no long ragdoll chaos in crowded encounters unless device-tested;
- important drops or objectives remain visible around the corpse.

# 157. Gatekeeper, Boss Phase, Ability, and Cinematic Animation

## 157.1 Boss Animation Principles

- Large motion starts earlier and reads longer.
- The camera is not forced away from gameplay for ordinary attacks.
- Phase transitions are authored but reset-safe.
- Attack families share motifs so players learn the boss.
- New phases combine known language before adding new language.
- Weak-point exposure is a pose and silhouette change, not only a UI icon.

## 157.2 Gatekeeper Baseline Set

```text
idle dormant
awakening
combat idle
locomotion/rotation
ranged burst telegraph/fire/recovery
ground shockwave charge/release/recovery
add summon or command
armor close/open/break
stagger or breakpoint
phase transition 1→2
phase-two combat idle
warden interaction
final defeat
disabled/reset return
```

## 157.3 Ground Shockwave Specification

- Boss lifts weapon/core and opens the incomplete ring.
- Energy gathers along floor channels before release.
- `Commit` locks the pattern.
- Wave expands with a readable vertical edge and audio front.
- Boss remains in recovery with weak point exposed.
- Jump/dodge/safe elevation response remains legible at low effects quality.

## 157.4 Phase Transition

Sequence contract:

```text
server reaches threshold once
→ current attack resolves or cancels safely
→ boss enters transition state
→ player damage rules update
→ transition animation and arena state play
→ hazards and add entrances activate
→ required assets acknowledge ready or timeout fallback executes
→ boss returns to combat state
```

The animation cannot be the only keeper of phase state. Disconnect, death, reset, or asset failure must not strand the encounter.

## 157.5 Camera and Cinematic Rules

- Intro camera moment is optional and brief.
- Players retain orientation when control returns.
- Multiplayer cameras are not forced through geometry or other avatars.
- Skipping never changes boss state or rewards.
- Important dialogue or motif can play during controlled gameplay rather than a long cutscene.
- Motion-sensitive players may reduce or disable authored camera movement.

## 157.6 Defeat

Defeat sequence:

- damage state locks exactly once;
- active attacks and hazards terminate safely;
- boss silhouette collapses or powers down in readable stages;
- reward state remains separate from visual sequence;
- arena exit becomes readable;
- players regain control quickly;
- cinematic failure falls back to a safe completed state.

# 158. VFX, Camera, UI, Audio, and Accessibility Integration

## 158.1 Shared Cue Stack

Every important event can use up to five coordinated channels:

```text
pose/animation
world VFX
sound
camera response
UI/haptic response
```

Not every event needs all five. Major lethal tells and accessibility-critical state changes use at least two non-color channels.

## 158.2 VFX Shape Language

| Category | Shape | Motion | Edge | Typical color |
|---|---|---|---|---|
| Friendly protection | open arcs, circles, shells | outward and stable | soft/continuous | white-blue |
| Hostile projectile | narrow cone, streak, line | forward acceleration | sharp | orange-red |
| Hostile area | segmented ring, wedge, crack | compression then release | hard | red-orange/violet |
| Discovery | split ring, expanding line | slow outward reveal | clean | cyan |
| Loot | vertical lift, contained spark | upward confirmation | clean | rarity-specific but restrained |
| Fracture | offset duplicates, broken planes | echo and phase | discontinuous | violet |

## 158.3 Particle and Transparency Rules

- Use particles to support shape, not replace it.
- Large transparent cards are limited because overdraw scales poorly.
- Effects avoid constant full-screen overlap.
- Opaque or emissive geometry may carry important telegraphs when particles are reduced.
- Normal combat effects have short lifetimes and bounded emit counts.
- Boss peaks are scheduled so multiple expensive effects do not stack without review.

## 158.4 Provisional Effect Budgets

| Effect class | Peak visible particles | Dynamic lights | Beams/trails | Notes |
|---|---:|---:|---:|---|
| Rifle shot | 10–35 | 0–1 brief local | 0–1 | impact is distance-culled |
| Enemy standard attack | 20–60 | 0–1 | 0–2 | telegraph geometry preferred |
| Pulse Mark | 40–100 | 0–1 | up to 12 short mark treatments | reduced mode preserves ring and target icon |
| Warden link set | low particles | 0 | up to 2 proof links | links remain thin and readable |
| Elite modifier | 20–80 sustained/periodic | 0–1 | limited | cannot hide base enemy |
| Boss peak | 150–300 provisional | 0–3 brief | limited by scene | must be profiled with full party |

These are initial budgets, not guarantees. Device evidence may lower them.

## 158.5 Camera Effects

Camera effects are classified:

```text
informational: directional hit, recoil
impact: major boss slam, heavy land
state: low health, fracture
cinematic: intro or phase moment
```

Each has intensity, duration, stacking, and accessibility scaling. Camera roll is rare. Long blur, chromatic aberration, or forced focus is avoided during active combat.

## 158.6 UI Integration

World and UI cues must not compete.

- Marked enemy outline and icon use the same status duration.
- Warden link UI appears only when world links may be obscured.
- Secret clue UI confirms, but does not reveal unrelated route information.
- Boss weak-point UI activates with the actual vulnerable state.
- Objective markers avoid covering enemy weak points and damage numbers.
- Damage numbers remain optional and scale by importance.

## 158.7 Accessibility Checklist

Every visual/animation feature reviews:

- color-independent recognition;
- flash frequency and intensity;
- reduced particles;
- reduced camera motion;
- FOV comfort;
- reticle visibility;
- text and icon size;
- subtitle or caption support for important audio cues;
- left/right handedness where feasible;
- input-device prompts;
- low graphics preservation;
- cognitive load during mixed encounters.

# 159. Performance Budgets, LOD, Streaming, and Asset Validation

## 159.1 Budget Philosophy

Budgets are starting ceilings. They protect iteration but do not replace measurement. The project profiles actual scenes on target devices with full combat, UI, audio, particles, and multiplayer—not isolated assets in an empty place.

## 159.2 Provisional Geometry Budgets

| Asset class | Target triangle band |
|---|---:|
| FP weapon | 20k–35k |
| World weapon | 6k–15k |
| Regular enemy | 12k–25k |
| Warden/support enemy | 18k–30k |
| Gatekeeper boss | 35k–60k |
| Modular structural piece | 300–5k |
| Hero landmark | 15k–50k, split/streamed where useful |
| Medium prop | 300–3k |
| Small prop | 50–800 |
| Foliage cluster | 200–2k |

These are project targets and must be reduced when screen density, materials, bones, transparency, or animation cost makes them inappropriate.

## 159.3 Material Slot Targets

```text
small prop: 1
medium prop: 1–2
modular environment piece: 1–2
regular enemy: 1–3
FP weapon: 1–3
boss: 2–5 only with evidence
```

Material count is reviewed alongside texture memory and draw cost.

## 159.4 Rig and Animation Budgets

- Use only necessary deform bones and joints.
- Enemy accessories are attached to the main rig rather than separate high-frequency physics assemblies.
- Animation tracks are loaded and reused, not created per frame or per shot.
- Idle variations are low priority and may be disabled at distance.
- Distant enemies reduce update rate and nonessential secondary motion.
- Ragdoll, cloth, and procedural IK are limited by scene and device budget.
- Boss transition clips are preloaded before the encounter gate opens where practical.

## 159.5 Streaming Strategy

- Enable and test instance streaming for the overworld-sized environment when appropriate.
- Group models according to meaningful streaming boundaries.
- Keep critical encounter state and necessary anchors available according to gameplay needs.
- Do not rely on a distant streamed-out landmark as the only objective information.
- Dungeon runtime rooms load before players enter their active boundary.
- Effects and sounds handle targets streaming out without stale references.
- Reset and cleanup work whether optional dressing is currently streamed to a client or not.

## 159.6 LOD Strategy

Three conceptual levels:

```text
Hero/Close: full silhouette, materials, animation, gameplay anchors
Mid: reduced geometry and secondary motion, preserved identity
Far: simplified mass, color block, landmark or threat silhouette
```

Use engine-supported model LOD or authored variants where they improve measured performance. LOD transitions are tested for popping in first-person movement.

## 159.7 Lighting Budget

- Prefer authored non-shadowing accent lights for most local sources.
- Shadow-casting lights are scarce and justified by major depth or threat value.
- Repeated decorative lamps may share baked-looking emissive language without individual dynamic lights.
- Mobile/low quality preserves route and telegraph contrast without relying on shadows.
- Boss arena peak lighting is profiled with all attacks and player abilities active.

## 159.8 Validation Captures

Every gameplay-ready environment or animated character records:

```text
high-quality still
low-quality still
mobile aspect still
combat-motion capture
wireframe/triangle summary
material and texture summary
memory/performance capture
streaming behavior
collision/navigation capture
animation marker report
known limitations
```

## 159.9 Current Platform Alignment

The pipeline assumes current Roblox support for:

- SurfaceAppearance and supported PBR texture maps on MeshParts;
- MaterialVariants and reusable materials;
- Animator-loaded animation tracks;
- animation event markers through `GetMarkerReachedSignal()`;
- IKControl for selective procedural inverse kinematics;
- instance streaming and model LOD strategies;
- MicroProfiler and performance statistics for measurement.

Official platform documentation remains authoritative and should be rechecked when implementation begins.

# 160. Visual Production Pipeline, Templates, Tickets 151–180, and Closing Directive

## 160.1 Asset Lifecycle

```text
Brief
→ reference and silhouette exploration
→ greybox
→ gameplay integration
→ style pass
→ animation/VFX/audio integration
→ optimization
→ device and accessibility test
→ approval
→ maintenance or deprecation
```

An asset may move backward when gameplay changes. “Final” is not protection from evidence.

## 160.2 Definition of Ready for Visual Work

A visual ticket is ready when:

- gameplay purpose is accepted;
- expected camera distances are known;
- dimensions and pivots are defined;
- collision/navigation needs are known;
- animation or VFX anchors are listed;
- palette and material family are selected;
- performance class is assigned;
- required variants are known;
- acceptance captures are specified;
- owner and review date are named.

## 160.3 Definition of Done for Environment Assets

- grid and pivot correct;
- collision and navigation tested;
- route, cover, hazard, or story role readable;
- material family approved;
- low-quality appearance acceptable;
- streaming and LOD behavior tested where relevant;
- no accidental interaction lookalike;
- naming, hierarchy, and metadata valid;
- performance capture attached;
- placed in at least one real gameplay context.

## 160.4 Definition of Done for Animation Assets

- correct rig and version;
- intended layer and priority declared;
- duration and gameplay timing match contract;
- markers present and named correctly;
- cancel and interruption behavior tested;
- no unacceptable hand, weapon, or body clipping;
- low frame rate and network correction reviewed;
- mechanical truth remains server-controlled;
- first-person and third-person relationship reviewed;
- accessibility and camera impact approved.

## 160.5 Review Cadence

### Daily artist review

- silhouette;
- function;
- scale;
- obvious technical blockers.

### Integration review

- collision;
- navigation;
- hierarchy;
- markers;
- gameplay states;
- device behavior.

### Visual-direction review

- screenshot identity;
- palette;
- shape language;
- detail distribution;
- faction/region consistency.

### Acceptance review

- performance;
- accessibility;
- fresh-player readability;
- evidence package;
- final owner signoff.

## 160.6 Asset Brief Template

```text
Asset ID:
Display name:
Owner:
Location/faction:
Gameplay purpose:
Expected camera distance:
Silhouette requirement:
Dimensions/grid/pivot:
Required states/variants:
Material family:
Texture strategy:
Rig/hierarchy:
Attachments/markers:
Collision/navigation:
VFX/audio anchors:
Performance class:
Accessibility risks:
Reference board:
Acceptance captures:
Dependencies:
Known exclusions:
```

## 160.7 Animation Brief Template

```text
Animation ID:
Rig and version:
Character/weapon:
Gameplay state:
Player-facing intent:
Duration target:
Telegraph/commit/active/recovery timing:
Layer and priority:
Root-motion policy:
Markers:
Cancel windows:
IK requirements:
First-person relationship:
Audio/VFX/camera events:
Network/server timing notes:
Accessibility notes:
Variants:
Acceptance test:
```

## 160.8 Visual Issue Severity

### Critical

- asset prevents route or encounter completion;
- collision creates exploit or softlock;
- attack telegraph communicates the wrong timing or direction;
- animation marker causes duplicated or missing authoritative result;
- severe device crash or memory failure.

### Major

- enemy role unreadable;
- cover truth broken;
- objective or secret cannot be found as intended;
- first-person model blocks combat view;
- boss phase or weak point visually desynchronized;
- repeated performance failure on target device.

### Moderate

- region identity inconsistent;
- clipping visible during common action;
- material/lighting issue harms readability;
- LOD pop or streaming gap is distracting;
- VFX overwhelms mixed combat.

### Minor

- isolated seam;
- small prop float;
- low-priority animation polish;
- non-gameplay decal or texture issue.

## 160.9 Tickets 151–180

### Visual foundation

151. Build a neutral scale, lighting, and material validation scene.  
152. Create project palette, material, decal, and VFX reference boards.  
153. Greybox standard door, corridor, cover, stair, ramp, and arena metrics.  
154. Create modular socket and pivot validator.  
155. Build high/low graphics screenshot comparison workflow.

### Emberwatch

156. Greybox Arrival Ramp, Survey Hall, Forge Terrace, Expedition Gate, and Overlook.  
157. Create Emberwatch structural kit.  
158. Create beacon, gate, and sealed-route landmarks.  
159. Create lamp, furniture, machinery, and prop-cluster families.  
160. Run first-player wayfinding and multiplayer congestion test.

### Verdant Scar

161. Greybox six route beats and mixed-combat arena.  
162. Build terrain, root, tree, and foliage families.  
163. Build Gleaner camp and extractor landmark.  
164. Build Pulse Mark secret clue and cache environment.  
165. Profile foliage, transparency, shadows, and streaming on target devices.

### Underroot Vault

166. Create Meridian material and trim-sheet family.  
167. Build entrance, connector, combat, traversal, secret, elite, and boss modules.  
168. Build door/seal state family and socket metadata.  
169. Build root/deposit/damage overlay sets.  
170. Validate ten generated layouts for readability, collision, lighting, and performance.

### Characters and weapons

171. Lock player equipment silhouette and avatar-integration rules.  
172. Build Frontier Rifle FP and world art hierarchy.  
173. Build Breach Shotgun FP and world art hierarchy.  
174. Create Pursuer, Shooter, and Warden silhouette/rig prototypes.  
175. Create Gatekeeper silhouette, armor states, and rig prototype.

### Animation and effects

176. Implement player locomotion, dodge, interaction, downed, and revive baseline.  
177. Implement rifle equip, fire, reload, ADS, and recoil layers.  
178. Implement Pursuer lunge, Shooter burst, Warden link/pulse, reactions, and deaths.  
179. Implement Pulse Mark and critical VFX/audio/camera cue stack.  
180. Run integrated visual-readability, accessibility, and performance gate.

## 160.10 Promotion Gate

Do not promote visual work into final production status until:

- greybox gameplay has passed;
- visual identity survives low graphics and mobile capture;
- route, cover, hazard, secret, and enemy role remain readable;
- animation timing agrees with authoritative mechanics;
- no critical cue depends on color alone;
- modular assets validate under real assembly;
- performance is measured in a representative scene;
- an evidence package exists;
- the asset has a maintenance owner.

## 160.11 Version 2.1 Closing Directive

Version 2.1 provides enough specification to begin visual pre-production without inventing style, scale, hierarchy, or timing asset by asset.

The next useful evidence is:

```text
one neutral validation scene
one Emberwatch greybox screenshot
one Verdant Scar route flythrough
one generated Underroot greybox seed
one Frontier Rifle FP blockout
one Pursuer silhouette and lunge blockout
one low-graphics capture
one mobile capture
one animation marker report
one performance capture
```

> Make the route readable in flat gray. Make the enemy readable in silhouette. Make the attack readable without damage. Then earn the detail.

---

# Version 2.3 Refinement Appendix — Runtime Visual Quality

## A. One Visual Primitive, One Owner

The authoring bible describes what a cue should communicate. Runtime code must also know who owns the actual object.

| Primitive | Canonical runtime owner |
|---|---|
| Highlight | centralized lease registry |
| world objective marker | objective presentation controller |
| route path/anchor | route presentation controller |
| landmark accent | landmark presentation controller |
| Pulse Mark outline | mark presentation through lease registry |
| beam/trail/light burst | temporary-effect scope/pool |
| first-person viewmodel | one viewmodel owner |
| recoil/ADS/damage camera | one camera modifier stack |
| animation marker listener | track/controller scope that created it |

An artist should not be asked to solve ownership in the asset. The runtime contract must already exist.

## B. Readability Under Streaming

Every landmark, secret, route anchor, and world objective that receives runtime presentation has a stable semantic ID. The asset may stream out. Its meaning does not.

When absent locally:

- remove local world effects;
- retain semantic state;
- show an appropriate HUD fallback only when useful;
- rebind on stream-in;
- never convert stream-out into “completed” or “destroyed” gameplay state.

## C. Quality Tier Acceptance

Every hero asset/effect is reviewed in three states:

1. **Full:** intended hero presentation.
2. **Reduced:** lower density/overdraw/light count with same semantics.
3. **Minimum readable:** only the cues required to preserve gameplay truth.

The minimum-readable capture is part of acceptance for enemy attacks, Pulse Mark, Warden links, objectives, hazards, and route guidance.

## D. Visual Collision Truth

For every cover, doorway, traversal edge, and boss arena prop:

```text
visible shape
≈ collision shape
≈ navigation expectation
≈ projectile/raycast expectation
```

Large invisible blockers and decorative shapes that falsely imply cover are major defects.

## E. Animation Acceptance Refinement

A clip is accepted only with:

- intended state/layer;
- duration and marker report;
- cancel/interruption rule;
- mechanical state trace from the server;
- 30 FPS or simulated low-frame-rate review;
- first-person relation if relevant;
- 100-play listener-leak test for marker-driven runtime integration;
- reduced-motion review when the clip drives camera movement.

## F. Studio Screenshot Review Set

Every environment/encounter milestone should maintain a repeatable capture set:

```text
neutral lighting / editor view
normal gameplay full quality
normal gameplay reduced quality
minimum-readable mode
mobile aspect
combat under pressure
Pulse Mark active
Warden link active
route/objective active
stream target absent/rebound
```

Comparing the same viewpoints prevents aesthetic improvement from quietly damaging readability or performance.

