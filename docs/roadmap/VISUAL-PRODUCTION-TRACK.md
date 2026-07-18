# Living Kingdoms — Visual Production Track

## Purpose

Replace functional placeholders with readable, performant, source-tracked production assets without changing gameplay authority, tuning, hitboxes, interaction bounds, hidden information, or unfinished feature contracts.

**Core rule:** gameplay truth stabilizes first; presentation attaches second.

Canonical specification: `docs/specifications/visual-asset-production.md`  
Detailed current inventory: `docs/specifications/visual-placeholder-inventory.md`

## Status summary

| ID | Status | Outcome / remaining gate |
|---|---|---|
| VIS-PLAN-001 | Complete | Visual target, authority rules, budgets, sourcing, fallbacks, and review gates defined. |
| VIS-0101 | Complete | Registry and placeholder inventory established; no asset is falsely marked production-approved. |
| VIS-0102 | In progress | All five loadout firearms have dedicated multi-part presentation models, distinct per-loadout combat feel, temporary shot effects, and the complete client-local AUD-0102 audio set (fire, reload, empty click, handling). Needs Studio import/readability review, unique production-approved audio assets, the Studio mix review, and performance evidence. |
| VIS-0103 | In progress | Exclusion Walker silhouette, disclosed-state poses, attack readability, six visually distinct horde-role profiles over the shared 18-part shell, and the complete client-local AUD-0103 audio set (alert, windup, strike, hit, death) exist. Needs canonical swap, unique production-approved audio assets, the Studio mix review, and horde performance evidence. |
| VIS-0104 | In progress | Operative/class silhouettes, life-state cues, and carry poses exist. Needs canonical rig/animation, class-action cues, avatar-scale review, and squad performance evidence. |
| VIS-0105 | In progress — review gate | Cache, relay, extraction, routes, five safe landmarks, and shared world-material language exist. Needs Studio visual/accessibility/performance review before more geometry. |
| VIS-0106 | Blocked by P9 | Special-enemy and boss package waits for stable encounter contracts. |
| VIS-0107 | Blocked by canonical assets/P11 | Small cosmetic system waits for canonical fallbacks and persistence ownership. |
| VIS-0108 | Blocked by P12 | Release-candidate visual, audio, accessibility, and performance closure. |

## Current decision gate

**Do not add another broad procedural-geometry pass before Roblox Studio review.**

Review the existing VIS-0102–VIS-0105 presentation from the actual gameplay camera:

- silhouette and state readability at normal combat distance;
- terrain, avatar, prop, and UI clipping;
- prompt and interaction clarity;
- extraction and objective hidden-information behavior;
- low-quality graphics and dark/fog conditions;
- color-independent critical cues;
- representative squad, hostile, route, and landmark performance;
- cleanup during streaming, respawn, phase changes, and match end.

Record defects as bounded follow-up tasks. Only approved shapes/material roles should move into canonical authored assets.

## Completed VIS-0105 scope

- Ammunition cache: local available/consumed presentation around the unchanged server-owned cache and prompt.
- Relay and extraction: client presentation driven only by validated server disclosures; inconsistent state restores primitive fallbacks.
- Routes: paired edge guides on authored road/trail segments with no destination or extraction hints.
- Safe landmarks: Ranger Station, Military Roadblock, Campground, Creek Crossing, and Rocky Overlook.
- Explicit exclusions: Lookout Tower objective area and Extraction Clearing remain behind their mission-state boundaries.
- Shared material language: immutable semantic roles for infrastructure, security, camp, crossing, and overlook treatment.

All current world additions remain presentation-only: no gameplay ownership, new remotes, server-state mutation, collision authority, or production approval.

## Completed slice details

Source-audited detail of what each in-progress slice has already delivered. These remain temporary or fallback presentation, not canonical production approval.

- **VIS-0102 firearms.** Hit-confirmed tracer policy: a temporary tracer marks server-resolved shots and the reload lifecycle. The five-weapon loadout roster (Blackwater Support LMG, Morrow Breach Shotgun, Longwatch Sniper Rifle, Vigil Service Pistol, Razor Compact SMG) has dedicated project-original presentation models with distinct per-loadout combat feel, and `WeaponAudioController` covers the full client-local fire/reload/empty-click/handling cue set (AUD-0102). Unique production-approved audio assets and the Studio mix review remain pending.
- **VIS-0103 Exclusion Walker.** A deterministic 18-component Exclusion Walker source candidate exists as an offline fallback silhouette. Attack readability uses a cancelable 0.6-second server-owned windup so the disclosed-state pose telegraphs the strike. `HordeRolePresentationService` composes six visually distinct role profiles (Hollow Infected, Razor Runner, Grave Crawler, Choir Screamer, Rot Bloater, Grief Brute) by rescaling only massless non-colliding presentation parts of the shared shell, and `EnemyAudioController` covers the full client-local alert/windup/strike/hit/death cue set (AUD-0103). Unique production-approved hostile assets and the Studio mix review remain pending.
- **VIS-0104 operatives.** Life-state cues plus event-driven upper-body carry poses read the operative's weapon state without changing the canonical rig.
- **VIS-0105 world presentation.**
  - Cache: a procedural supply case presents available/consumed state around the unchanged server-owned cache.
  - Routes: paired edge guides on authored segments, capped at 22 parts, with no destination or extraction hints.
  - Relay and extraction: Validated monotonic safe mission snapshots drive client presentation; inconsistent state restores primitive fallbacks.

## Dependency rules

Execution order:

`VIS-PLAN-001` → `VIS-0101` → (`VIS-0102` + `VIS-0103`) → `VIS-0104` → `VIS-0105` → `VIS-0106` → `VIS-0107` → `VIS-0108`

Dependencies override order:

- action-specific class cues wait for their gameplay contracts;
- objective/extraction art may reveal only validated server-disclosed truth;
- boss visuals wait for P9 encounter contracts;
- cosmetics wait for canonical fallbacks and P11 ownership;
- release closure runs with P12 accessibility and performance work.

## Production replacement priority

1. Firearm model, effects, and audio.
2. Standard hostile model, animation, effects, and audio.
3. Operative rig, class equipment, and animation.
4. Cache, relay, extraction, and major world props/materials.
5. Special enemy and boss.
6. Optional cosmetic variants.
7. Release-candidate UI, ambience, accessibility, and polish.

## Safe parallel work before Studio approval

- reference boards and authored concept exploration;
- source/license documentation;
- offline mesh, texture, and audio candidates;
- material prototypes that do not enter gameplay runtime;
- test plans and performance budgets.

Do not merge canonical replacements without preserving gameplay footprints, fallback behavior, cleanup, accessibility, rights, and performance evidence.

## MVP visual exit criteria

The track exits when:

- no release-blocking primitive/debug placeholder remains;
- primary characters, weapons, enemies, interactables, objectives, extraction, and landmarks are coherent and recognizable;
- combat, rescue, scarcity, class, objective, boss, and result states read from the gameplay camera;
- server authority and canonical gameplay footprints remain intact;
- representative horde/boss load meets P12 budgets;
- critical information is not color-only or audio-only;
- missing assets fail safely to approved fallbacks;
- all imported sources and rights are recorded;
- cosmetics, if included, remain cosmetic only.
