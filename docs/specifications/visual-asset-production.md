# Living Kingdoms — Visual Asset Production Specification

## Status

**VIS-PLAN-001 complete when merged.** This document defines how placeholder Roblox geometry becomes production-ready weapons, operatives, enemies, world props, effects, animation, audio, and optional cosmetic skins without allowing presentation assets to become gameplay authority.

No imported model, animation, texture, sound, or skin is approved merely because it looks good. Every production asset must preserve gameplay readability, server authority, accessibility, performance, and deterministic fallback behavior.

## Direct answer

Living Kingdoms will not ship as a field of plain blocks.

The intended MVP includes:

- a recognizable production model for the basic firearm;
- readable operative silhouettes and class equipment;
- production visual rigs for the standard hostile, special enemy, and boss;
- authored ammunition caches, objectives, extraction equipment, landmarks, and environmental props;
- firing, reload, movement, incapacitation, revive, enemy, and boss animation;
- muzzle flash, impact, damage, rescue, class-action, objective, and boss telegraph effects;
- layered ambience, weapon, enemy, interface, and objective audio;
- icons and interface art that match the physical world.

Cosmetic weapon or operative skins are planned only after the canonical model and readability baseline exist. Skins are cosmetic side-grades, never stat upgrades.

## Visual target

The provisional target is **grounded stylized survival horror** rather than photorealism or toy-like abstraction.

The look should support:

- strong silhouettes from an elevated isometric camera;
- readable motion in darkness and horde pressure;
- weathered, practical equipment rather than glossy military fantasy;
- a hostile Appalachian forest atmosphere with authored landmarks;
- restrained color, with brighter accents reserved for critical interaction and threat communication;
- enough stylization to remain performant and visually coherent on Roblox hardware.

This direction is provisional until a later concept-art review approves a reference board and representative asset set.

## Current placeholder policy

Current simple Parts, primitive rigs, debug labels, temporary UI, and basic materials are **functional placeholders**. They exist to prove movement, targeting, health, scarcity, objectives, spawning, pursuit, and mission flow.

A placeholder may remain temporarily when it:

- preserves the correct authoritative owner;
- exposes the correct gameplay footprint;
- remains readable enough for validation;
- has a documented replacement task;
- does not become an accidental art dependency.

A placeholder must be replaced before release candidate when it obscures identity, timing, hit readability, interaction state, class role, enemy behavior, objective state, or navigation.

## Authority boundary

Presentation assets may reflect gameplay truth but may not establish it.

### Weapons

The firearm model, magazine, muzzle attachment, animation, muzzle flash, tracer, recoil, shell, sound, and skin are presentation.

They may not define or modify:

- cadence;
- ammunition counts;
- reload acceptance or completion;
- target acquisition;
- line of sight;
- range;
- hit validation;
- damage;
- enemy death;
- class bonuses.

The server remains authoritative even if the displayed muzzle, animation, or effect is delayed or missing.

### Enemies

The visual enemy rig attaches to a simple authoritative enemy root and collision/hit representation. Mesh shape, accessories, animation scale, particles, and skin variation may not silently change legal targeting, health, movement speed, attack range, damage, or hit volume.

The standard hostile, special enemy, and boss each require a canonical gameplay footprint that remains stable when visuals are replaced.

### Operatives

Body packages, uniforms, class equipment, weapon skins, and animation are presentation. They may communicate the assigned class but may not create class ownership, resources, cooldowns, health, revive state, ammunition, or operation participation.

### World objects

Caches, objective consoles, extraction equipment, landmarks, and interactable props must attach presentation to stable authored identifiers and server-owned interaction bounds. A prettier mesh cannot enlarge an interaction radius or move a server-owned objective.

### Skins

A skin selection may identify only an approved cosmetic asset variant. The server validates ownership and approved IDs when persistence eventually exists.

Skins may not:

- change weapon statistics;
- change hitboxes or interaction bounds;
- make a player or enemy materially harder to see;
- conceal class identity or critical state;
- alter audio timing used for gameplay;
- grant paid power;
- load arbitrary client-provided asset IDs.

Missing, invalid, or unavailable skin assets always fall back to the canonical model.

## Asset families

### Operatives and classes

The MVP needs one shared operative rig plus readable class-specific equipment layers:

- Combat Specialist: stable firing stance and recognizable bracing equipment;
- Medic: visible medical pack and treatment tools;
- Engineer: visible utility pack and resupply equipment.

Class readability must survive distance, darkness, duplicate-class squads, color-vision differences, and low graphics settings. Shape and equipment placement matter more than color alone.

### Weapons

The basic firearm production set includes:

- world/view model suitable for the isometric camera;
- hand and body attachment points;
- magazine and reload states;
- muzzle and casing/ejection presentation points;
- idle, locomotion, firing, reload, empty, incapacitated, and revive compatibility;
- canonical material set;
- future cosmetic material/texture slots that do not affect geometry or authority.

Additional weapon families are outside the current MVP unless separately approved.

### Standard enemies

The horde hostile needs:

- a readable silhouette at combat distance;
- locomotion that communicates pursuit direction and speed;
- attack anticipation, active strike, recovery, damage reaction, death, and stand-down presentation;
- enough visual variation to avoid obvious cloning without creating hidden gameplay variants;
- distance-appropriate simplification for horde performance.

Cosmetic variation may change clothing, surface damage, or accessories while preserving the same gameplay archetype and footprint.

### Special enemy and boss

P9 owns the gameplay design and production integration for the special enemy and boss. Their visual work must include:

- unmistakable silhouettes;
- pre-action anticipation;
- redundant position, timing, shape, animation, text, and audio telegraphs where appropriate;
- phase-state readability;
- vulnerability readability;
- death and terminal-state clarity;
- bounded effect and instance budgets during horde pressure.

### Environment and interactables

The production environment includes:

- terrain and vegetation composition;
- ranger station, lookout, campground, creek crossing, extraction clearing, and objective landmarks;
- ammunition caches and depletion state;
- relay/objective equipment;
- extraction beacon or vehicle/equipment presentation;
- cover, route cues, temporary defensive positions, and hazard dressing;
- fog, lighting, weather, decals, props, and ambient motion.

Environmental art may guide attention but may not reveal hidden supply, enemies, or objective truth that the server has not disclosed.

### Effects and audio

Critical events need restrained, layered presentation:

- weapon fire, reload, empty click, and ammunition pickup;
- enemy alert, pursuit, attack, hit, and death;
- player damage, incapacitation, bleed-out pressure, revive, recovery, and death;
- flashlight, squad ping, class action, objective, extraction, mission success/failure, special attack, and boss phase cues.

No critical warning may depend on audio alone. Effects must remain understandable when particles, volume, or graphics quality are reduced.

## Technical asset contract

Production integration should use a small, explicit asset registry rather than scattered numeric IDs or model-name guesses.

Each registered visual asset should eventually declare, as applicable:

- stable asset key;
- asset family and version;
- canonical fallback key;
- expected rig or attachment contract;
- authoritative root/footprint compatibility;
- animation set key;
- effect set key;
- audio set key;
- approved cosmetic variants;
- performance classification;
- replacement status and source/license record.

No runtime should search arbitrary descendants by appearance or accept a client-provided asset reference as truth.

## Import and source policy

Every imported asset requires a recorded source and usage right.

Allowed sources include:

- original project-created assets;
- commissioned assets with clear project rights;
- appropriately licensed marketplace or library assets whose license permits the intended use and modification;
- generated concept or texture material only when its rights and final production use are documented.

Unknown-source toolbox models are not production assets. Imported models must be inspected for hidden scripts, unnecessary instances, remote behavior, oversized textures, excessive geometry, and naming collisions before entering the project.

## Provisional performance budgets

These are project budgets, not platform maximums. They may be tightened after profiling.

- Standard horde enemy: target at most 8,000 visible triangles, at most two skinned meshes, and a compact bone count.
- Operative including class equipment: target at most 18,000 visible triangles before the equipped weapon.
- Basic firearm: target at most 6,000 visible triangles.
- Special enemy: target at most 15,000 visible triangles.
- Boss: target at most 30,000 visible triangles with distance simplification and bounded effects.
- Texture count and resolution must be minimized through shared atlases/materials where practical.
- Standard enemies must avoid per-enemy particle emitters, lights, sounds, or scripts that continue running when idle, dead, distant, or cleaned up.
- Animation and effect evaluation must remain bounded under representative horde plus special-enemy plus boss load.

A visually impressive asset that breaks the P12 frame/server budgets is not acceptable.

## Animation requirements

Animation state follows authoritative or safely replicated gameplay state.

Minimum production sets:

- operative locomotion, firearm idle, fire, reload, empty, incapacitated, revive interaction, revived recovery, and death;
- class action anticipation, active/channel, interruption, completion, and cooldown/readiness cues where visible;
- standard hostile locomotion, attack anticipation, active attack, recovery, hit reaction, death, and stand-down;
- special-enemy and boss actions, phase transitions, vulnerability, interruption where legal, and death.

Animation events may trigger local presentation but may not commit ammunition, hits, damage, healing, revive, resources, objectives, or phase transitions.

## Cosmetic strategy

Canonical models come first. Cosmetic skins are not a substitute for missing production art.

The recommended order is:

1. one readable canonical firearm appearance;
2. one readable canonical operative/class appearance set;
3. one readable canonical enemy appearance per gameplay archetype;
4. approved material or surface variants that preserve silhouette and visibility;
5. broader cosmetic catalog only after the complete operation, persistence, accessibility, and performance gates are stable.

For the MVP, a very small set of earned or default cosmetic variants is preferable to a store-sized catalog. No battle pass or paid power is introduced.

## Review gates

A visual replacement is accepted only when all applicable gates pass:

1. **Silhouette:** readable from the elevated gameplay camera.
2. **State:** clearly communicates alive/incapacitated/dead, ready/reloading/empty, idle/attacking/recovering, available/depleted, or active/completed as applicable.
3. **Authority:** does not move consequential truth into animation, mesh, attachment, or client code.
4. **Footprint:** matches the canonical server-owned root, hit, movement, and interaction bounds.
5. **Accessibility:** critical meaning is not color-only or audio-only.
6. **Performance:** meets the current representative load budget.
7. **Cleanup:** leaves no running effects, sounds, connections, scripts, or instances after removal/replay.
8. **Fallback:** missing or failed loading produces a safe canonical placeholder or model.
9. **Rights:** source and license are recorded.
10. **Studio evidence:** representative one-, two-, and four-operative sessions verify readability and performance where required.

## Explicit deferrals

This plan does not currently approve:

- multiple weapon families;
- loot rarity visuals;
- randomized stat skins;
- paid weapon or class power;
- battle passes;
- arbitrary user-generated asset loading;
- gore systems requiring separate age-rating or policy review;
- cinematic cutscenes;
- a large cosmetic store;
- production model creation without visual review in Roblox Studio.

## Immediate next visual task

`VIS-0101` should define the code-side visual asset registry, stable keys, fallback rules, and placeholder inventory without importing production models or changing gameplay behavior.

Actual model creation/import begins with `VIS-0102`, the basic firearm presentation vertical slice, after an art-direction reference board and one representative weapon concept are approved.