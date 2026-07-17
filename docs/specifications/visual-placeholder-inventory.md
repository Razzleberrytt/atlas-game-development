# Living Kingdoms — Visual Placeholder Inventory

## Status

**VIS-0101 inventory.** This document mirrors the machine-checked registry in `VisualAssetConfig.luau` and identifies what players currently see—or do not yet see—before production-art replacement begins.

The registry is descriptive only. It does not load assets or change gameplay.

## Classification vocabulary

- **Primitive placeholder:** generated Parts, lights, labels, or other basic Roblox instances currently stand in for the asset.
- **Default-avatar placeholder:** the normal Roblox character shell currently stands in for the production operative.
- **Missing presentation:** authoritative gameplay exists, but no approved production presentation set is registered.
- **Temporary presentation:** a functional UI, ambience, marker, or similar pass exists but is not release-candidate art.
- **Production approved:** reserved for a later reviewed asset. VIS-0101 intentionally approves none.

## Current inventory

| Family | Asset | Current state | Current owner / evidence | Replacement track |
|---|---|---|---|---|
| Weapon | Basic firearm model | Missing production presentation | `BasicFirearmPresentationFactory` plus `WeaponPresentationController`; project-original Blackwater Support LMG procedural fallback with deterministic source candidate, stale-grip cleanup, and event-driven carry integration | VIS-0102 / VIS-0104 |
| Operative | Base operative rig | Default-avatar placeholder | `OperativeLifeService`; Roblox character shell remains authoritative, with `ClassSilhouetteController` armor and `OperativeCarryPresentationController` R6/R15 ready, reviver, incapacitated, and dead upper-body fallbacks | VIS-0104 |
| Class equipment | Combat Specialist equipment | Primitive placeholder | `ClassSilhouetteController`; broad reinforced shoulders, paired ammunition cases, back roll, and diagonal chest band from the validated class roster | VIS-0104 |
| Class equipment | Medic equipment | Primitive placeholder | `ClassSilhouetteController`; compact pack, twin tall canisters, paired satchels, and round beacon from the validated class roster | VIS-0104 |
| Class equipment | Engineer equipment | Primitive placeholder | `ClassSilhouetteController`; wide utility pack, squared tool cases, frame bar, and asymmetric antenna from the validated class roster | VIS-0104 |
| Enemy | Exclusion Walker model | Primitive placeholder | `EnemyPresentationService` plus `EnemyPresentationController`; motorized 18-part shell with server-authored behavior/life/windup/attack/hit disclosure and local roaming, pursuit, threat-ready, early/late windup, confirmed strike/recovery, hit, stand-down, and death poses attached to the unchanged authoritative `3 x 5.6 x 3` root | VIS-0103 |
| Supply | Ammunition cache | Primitive placeholder | `AmmunitionCacheService` retains the authoritative root/prompt; `SupplyCachePresentationFactory` and `AmmunitionCachePresentationController` add a 13-part available/locally-consumed procedural case | VIS-0105 |
| Objective | Relay console | Primitive placeholder | `MissionDirectorService` retains the authoritative body/lamp/prompt; `MissionObjectPresentationFactory` and `MissionObjectPresentationController` add an eleven-part standby/restore/online procedural shell | VIS-0105 / P8 |
| Extraction | Extraction beacon | Primitive placeholder | `MissionDirectorService` creates the authoritative beacon only after unlock; `MissionObjectPresentationFactory` and `MissionObjectPresentationController` add a twelve-part open/holdout/outcome procedural package | VIS-0105 / P10 |
| World | Blackwater world foundation | Primitive placeholder | `WorldFoundationService`; deterministic Part-based terrain, routes, vegetation, structures, and props | VIS-0105 |
| Landmark | Ranger Station | Primitive placeholder | `WorldFoundationService` retains the cabin, signage, spawn, lights, and collision; `LandmarkAccentPresentationFactory` and controller add four client-local roof/mast silhouette accents | VIS-0105 |
| Landmark | Logging Road | Primitive placeholder | `WorldFoundationService` retains authored road/trail geometry and collision; `RouteGuidePresentationFactory` and `RouteGuidePresentationController` add paired client-local edge guides with no destination or extraction cue | VIS-0105 |
| Landmark | Lookout Tower | Primitive placeholder | Part-built tower, platform, cabin, stairs, and warning light | VIS-0105 |
| Landmark | Campground | Primitive placeholder | `WorldFoundationService` retains shelters, props, signage, and collision; `LandmarkAccentPresentationFactory` and controller add four client-local tent/dead-fire accents from the shared material language | VIS-0105 |
| Landmark | Creek Crossing | Primitive placeholder | `WorldFoundationService` retains water, banks, bridge, warning prop, and collision; `LandmarkAccentPresentationFactory` and controller add four client-local warning/fallen-tree accents | VIS-0105 |
| Landmark | Rocky Overlook | Primitive placeholder | `WorldFoundationService` retains plateau, rocks, guardrail, lights, signage, and collision; `LandmarkAccentPresentationFactory` and controller add four client-local guardrail/cliff-edge accents | VIS-0105 |
| Landmark | Military Roadblock | Primitive placeholder | `WorldFoundationService` retains barriers, vehicles, signs, lights, and collision; `LandmarkAccentPresentationFactory` and controller add six client-local checkpoint/lamp silhouette accents | VIS-0105 |
| Landmark | Extraction Clearing | Primitive placeholder | Authored primitive clearing awaiting final extraction package | VIS-0105 |
| Effect | Basic firearm fire/impact set | Temporary presentation | Code-built muzzle flash, casing, hit-confirmed tracer, and authoritative impact cue | VIS-0102 |
| Effect | Standard hostile attack set | Temporary presentation | Cancelable server-owned windup plus confirmed active-strike/recovery and hit pose cues exist; authored particles, impact effects, and production audio remain missing | VIS-0103 |
| Audio | Basic firearm set | Missing presentation | No approved fire, reload, empty, or handling set | VIS-0102 |
| Audio | Standard hostile set | Missing presentation | No approved alert, pursuit, attack, hit, or death set | VIS-0103 |
| Audio | Blackwater ambience | Temporary presentation | `EnvironmentAmbienceController` code-driven ambience | VIS-0105 / VIS-0108 |
| Interface | Ammunition display | Temporary presentation | Functional weapon/ammunition UI | VIS-0102 / VIS-0108 |
| Interface | Life-state display | Temporary presentation | `OperativeLifeController` retains functional local UI; `OperativeLifeWorldPresentationController` adds server-attribute-driven downed, revive-progress, solo-recovery, and KIA geometry/text cues | VIS-0104 / VIS-0108 |
| Interface | Mission display | Temporary presentation | Explicit temporary objective/radio/countdown/outcome UI | P8/P10 / VIS-0108 |
| Interface | Class selection | Temporary presentation | Functional three-button selection panel | VIS-0104 / VIS-0108 |
| Interface | Squad ping | Temporary presentation | Functional location marker presentation | VIS-0108 |

## Cosmetic eligibility

The initial registry permits future cosmetic variants only for:

- the basic firearm;
- the operative body/equipment presentation;
- the three starting-class equipment sets;
- the standard hostile's non-gameplay surface variation.

World objects, supplies, objectives, extraction equipment, effects, audio, and interfaces are not marked as cosmetic families in VIS-0101.

Eligibility is not ownership and does not create a skin system. It only records which canonical families could safely support approved variants later.

## Current fallback state

No production asset has been approved, so every registry record currently has no production fallback key. The existing primitive, default-avatar, missing, or temporary state remains the honest fallback until its replacement PR passes visual, authority, footprint, accessibility, rights, cleanup, and performance review.

When canonical production assets begin entering the registry:

- each optional variant must point to its canonical approved fallback;
- missing or rejected variants must use that fallback;
- a visual failure must never break movement, combat, enemies, health, objectives, extraction, or match completion.

## Replacement priority

1. Basic firearm model/effects/audio.
2. Standard hostile model/animation/effects/audio.
3. Operative and class silhouettes.
4. Cache, objective, extraction, and major world props.
5. Special enemy and boss.
6. Optional cosmetic variants.
7. Release-candidate UI, ambience, and polish.

## Next task

Continue VIS-0105 with Studio review and authored world/interactable material replacement planning while keeping the lookout objective and extraction clearing behind their validated mission boundaries; final effects/audio, canonical operative art, class-action cues, avatar-scale coverage, accessibility, and representative performance evidence remain pending.
