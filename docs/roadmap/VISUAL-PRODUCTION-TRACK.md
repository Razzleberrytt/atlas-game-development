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
- [ ] **VIS-0101 — Define the visual asset registry and placeholder inventory.**
  - Add stable visual asset keys, family/version metadata, attachment or rig expectations, canonical fallbacks, and source/license fields.
  - Inventory current primitive weapons, enemies, operatives, interactables, world props, effects, sounds, and temporary UI.
  - No production imports, arbitrary numeric client IDs, or gameplay behavior changes.
- [ ] **VIS-0102 — Replace the basic firearm presentation.**
  - Approve a reference board and representative firearm concept.
  - Add the canonical firearm model, attachment points, magazine state, fire/reload/empty animation compatibility, muzzle/impact effects, and sound set.
  - Preserve existing server-owned cadence, ammunition, reload, targeting, hit, and damage boundaries.
  - Add missing-asset fallback and Studio readability/performance evidence.
- [ ] **VIS-0103 — Replace the standard hostile presentation.**
  - Add one canonical horde rig and bounded cosmetic variants.
  - Support pursuit, attack anticipation, active strike, recovery, hit reaction, death, and stand-down.
  - Preserve the canonical enemy root, gameplay footprint, health, speed, attack, and targetability.
  - Validate representative horde load and cleanup.
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