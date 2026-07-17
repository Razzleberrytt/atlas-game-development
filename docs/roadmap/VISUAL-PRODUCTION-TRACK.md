# Living Kingdoms — Visual Production Track

## Purpose

This is the cross-cutting production-art roadmap for replacing functional placeholders with readable, performant, production-ready visual and audio assets.

It does not change the P6–P12 gameplay dependency chain. Visual work may proceed in parallel only when it does not alter gameplay authority, tuning, hitboxes, interaction bounds, hidden information, or an unfinished feature contract.

Canonical specification: `docs/specifications/visual-asset-production.md`.

## Core rule

**Gameplay truth is stable first; presentation attaches second.**

Weapon meshes do not own shooting. Enemy rigs do not own health, targeting, attacks, or hit volume. Operative outfits do not own class state. Objective props do not own objective position or completion. Skins never own statistics.

## Current status

- [x] **VIS-PLAN-001 — Define the visual asset production specification.**
  - Defines the visual target, placeholder policy, authority boundary, asset families, cosmetic policy, source/license requirements, provisional budgets, review gates, and ordered production tasks.
  - Planning and documentation only.
- [x] **VIS-0101 — Define the visual asset registry and placeholder inventory.**
  - Adds 28 stable visual asset keys with family/version metadata, expected roots/attachments, gameplay-footprint references, cosmetic eligibility, and source/runtime-owner records.
  - Inventories current primitive weapons, enemies, operatives, interactables, world props, effects, sounds, ambience, and temporary UI in `visual-placeholder-inventory.md`.
  - All current records remain honestly classified as primitive, default-avatar, missing, or temporary; no production asset is falsely approved.
  - Declarations load no assets, register no numeric IDs, create no runtime owner, and change no gameplay behavior.
- [~] **VIS-0102 — Replace the basic firearm presentation.**
  - The current project-original Blackwater Support LMG procedural fallback provides a belt feed, ammunition box, carry handle, long barrel, heat shield, bipod, stable attachment locators, and deterministic 45-component import source; the earlier Blackwater Service Carbine source remains available for comparison and rollback.
  - Local and squad-visible bolt, ammunition-box, empty-state, and reload motion follows only server-disclosed shot and reload lifecycle messages; teammate ammunition counts remain private.
  - Accepted shots drive temporary muzzle flash, casing, hit-confirmed tracer, and authoritative damage-impact presentation.
  - Hit-confirmed tracer policy remains implemented: only server-confirmed damaging shots with an authoritative impact position display the short-lived tracer.
  - Still required: Roblox Studio mesh import and canonical swap, grip/isometric readability review, production effects, audio, and representative performance evidence.
  - Existing server-owned cadence, ammunition, reload, targeting, hit, and damage boundaries remain unchanged.
- [~] **VIS-0103 — Replace the standard hostile presentation.**
  - A deterministic 18-component Exclusion Walker source candidate and matching replicated procedural fallback replace the invisible/one-block silhouette with a broad torso, sensor face, long striking arms, claws, heavy feet, dorsal spine, and back canister.
  - The fallback exposes five presentation-only motors and a client-local pose controller for alternating roaming/pursuit stride, stationary threat-ready posture, confirmed hit reaction, death, and stand-down readability.
  - Six server-authored model attributes disclose exact behavior/life state plus confirmed attack and hit sequences/timestamps; alternating left/right active-strike and recovery poses begin only after authoritative damage commits.
  - The pose layer uses one client frame connection, two folder lifecycle connections, zero per-enemy connections, zero remotes, and no root, Humanoid, health, attack, or cleanup mutation; attribute writes occur only on committed changes and motor writes only when the pose ID changes.
  - The authoritative `HumanoidRootPart` remains exactly `3 x 5.6 x 3` studs and continues to own collision, movement, network ownership, targeting position, and gameplay footprint.
  - A stable presentation-only `AttackOrigin` locator remains available for later authored attack effects.
  - Attack anticipation remains pending because the contact-damage contract has no windup disclosure; the presentation layer never predicts a strike from distance or motion.
  - Still required: Roblox Studio mesh import/canonical swap, truthful attack anticipation, effects, audio, bounded cosmetic variants, and representative horde performance evidence.
- [ ] **VIS-0104 — Add operative and starting-class visual identity.**
  - Add one shared operative rig plus Combat Specialist, Medic, and Engineer equipment silhouettes.
  - Integrate firearm carry, locomotion, incapacitation, revive, death, and visible class-action cues only after their gameplay states exist.
  - Duplicate-class squads and color-vision differences remain readable.
- [ ] **VIS-0105 — Replace world, supply, and objective placeholders.**
  - Produce authored landmarks, environmental dressing, caches, depletion state, objective equipment, extraction presentation, route cues, temporary defensive positions, lighting, fog, and ambience.
  - Objective art follows the P8 authored chain and may not disclose hidden or inactive truth.
- [ ] **VIS-0106 — Produce the special enemy and boss visual package.**
  - Runs with P9 after the special-enemy and boss contracts are stable.
  - Includes canonical rigs, phase/vulnerability states, attacks, accessible telegraphs, effects, audio, death, and performance validation.
- [ ] **VIS-0107 — Add the bounded cosmetic skin system.**
  - Begins only after canonical models, persistence ownership, readability, and fallback rules are stable.
  - Approved cosmetic IDs only; no arbitrary client asset references, stat changes, silhouette advantages, paid power, or battle pass.
  - Prefer a very small earned/default MVP set over a broad catalog.
- [ ] **VIS-0108 — Complete release-candidate visual, audio, and performance polish.**
  - Runs with P12 accessibility and performance work.
  - Replaces all release-blocking placeholders, consolidates materials/effects/audio, validates low-quality settings, verifies cleanup, and records known cosmetic limitations.

## Execution order

`VIS-PLAN-001` → `VIS-0101` → (`VIS-0102` + `VIS-0103`, one PR at a time) → `VIS-0104` → `VIS-0105` → `VIS-0106` → `VIS-0107` → `VIS-0108`.

Dependencies override the apparent order:

- `VIS-0102` may begin after the current firearm gameplay contract is considered stable enough for presentation attachment.
- `VIS-0104` action-specific cues wait for the corresponding P7 action state.
- `VIS-0105` objective-specific assets wait for P8 authored objective definitions.
- `VIS-0106` waits for P9 encounter contracts.
- `VIS-0107` waits for canonical assets and the appropriate P11 persistence/ownership boundary.
- `VIS-0108` is part of P12 release-candidate closure.

## Production asset priorities

The recommended first production replacements are:

1. basic firearm;
2. standard hostile;
3. operative/class silhouettes;
4. ammunition cache and interaction state;
5. objective and extraction props;
6. major landmarks and environment pass;
7. special enemy and boss;
8. cosmetic variants.

This order improves what players see most often before spending effort on optional skins.

## What can proceed while P6 Studio evidence is deferred

The following visual work is evidence-independent and may proceed under a focused PR:

- reference board and concept decisions;
- placeholder inventory;
- asset key/fallback/source contracts;
- offline model or texture exploration that is not yet merged as production gameplay content;
- canonical firearm and enemy presentation integration only when their existing gameplay footprints remain unchanged and Studio review is available.

Class-effect animation, engineer resupply presentation, objective-specific production art, boss art, and cosmetic ownership runtime remain dependent on their corresponding gameplay milestones.

## Visual exit criteria for MVP

The MVP visual track exits when:

- no release-blocking primitive or debug placeholder remains;
- the firearm, operatives, classes, standard hostile, special enemy, boss, caches, objectives, extraction, and major landmarks are recognizable and coherent;
- critical combat, rescue, scarcity, class, objective, boss, and result states are readable from the gameplay camera;
- every asset preserves server authority and the canonical gameplay footprint;
- representative horde and boss load meets the P12 performance budget;
- critical information is not color-only or audio-only;
- missing assets fail safely to approved fallbacks;
- imported asset rights and sources are recorded;
- skins, if included, are cosmetic only.
