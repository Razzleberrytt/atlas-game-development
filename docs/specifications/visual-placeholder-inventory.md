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
| Weapon | Basic firearm model | Missing presentation | `OperativeCombatRuntimeService`; firearm state exists without a canonical model | VIS-0102 |
| Operative | Base operative rig | Default-avatar placeholder | `OperativeLifeService`; Roblox character shell bound through `HumanoidRootPart` | VIS-0104 |
| Class equipment | Combat Specialist equipment | Missing presentation | Text-only class selection | VIS-0104 |
| Class equipment | Medic equipment | Missing presentation | Text-only class selection | VIS-0104 |
| Class equipment | Engineer equipment | Missing presentation | Text-only class selection | VIS-0104 |
| Enemy | Exclusion Walker model | Primitive placeholder | `EnemyDirectorService`; one `3 x 5.6 x 3` Part, Humanoid, and health billboard | VIS-0103 |
| Supply | Ammunition cache | Primitive placeholder | `AmmunitionCacheService`; one green metal Part and ProximityPrompt | VIS-0105 |
| Objective | Relay console | Primitive placeholder | `MissionDirectorService`; primitive console, lamp, and ProximityPrompt | VIS-0105 / P8 |
| Extraction | Extraction beacon | Primitive placeholder | `MissionDirectorService`; neon signal pillar, light, and billboard | VIS-0105 / P10 |
| World | Blackwater world foundation | Primitive placeholder | `WorldFoundationService`; deterministic Part-based terrain, routes, vegetation, structures, and props | VIS-0105 |
| Landmark | Ranger Station | Primitive placeholder | Part-built cabin, equipment, mast, truck, cases, and signage | VIS-0105 |
| Landmark | Logging Road | Primitive placeholder | Segmented road and tire-track geometry | VIS-0105 |
| Landmark | Lookout Tower | Primitive placeholder | Part-built tower, platform, cabin, stairs, and warning light | VIS-0105 |
| Landmark | Campground | Primitive placeholder | Part-built shelters, campsite, and props | VIS-0105 |
| Landmark | Creek Crossing | Primitive placeholder | Part-built water, banks, bridge, and route | VIS-0105 |
| Landmark | Rocky Overlook | Primitive placeholder | Primitive plateau and rock composition | VIS-0105 |
| Landmark | Military Roadblock | Primitive placeholder | Primitive barriers, vehicle, light, and props | VIS-0105 |
| Landmark | Extraction Clearing | Primitive placeholder | Authored primitive clearing awaiting final extraction package | VIS-0105 |
| Effect | Basic firearm fire/impact set | Missing presentation | No approved muzzle, casing, tracer, or impact set | VIS-0102 |
| Effect | Standard hostile attack set | Missing presentation | Authoritative melee exists without approved anticipation/strike effects | VIS-0103 |
| Audio | Basic firearm set | Missing presentation | No approved fire, reload, empty, or handling set | VIS-0102 |
| Audio | Standard hostile set | Missing presentation | No approved alert, pursuit, attack, hit, or death set | VIS-0103 |
| Audio | Blackwater ambience | Temporary presentation | `EnvironmentAmbienceController` code-driven ambience | VIS-0105 / VIS-0108 |
| Interface | Ammunition display | Temporary presentation | Functional weapon/ammunition UI | VIS-0102 / VIS-0108 |
| Interface | Life-state display | Temporary presentation | Functional alive/incapacitated/revive/death UI | VIS-0104 / VIS-0108 |
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

`VIS-0102` is the first actual production-asset vertical slice: approve the firearm visual direction, integrate one canonical model and its presentation attachments, and prove the weapon still obeys the existing server-owned firearm contract.