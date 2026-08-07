# Legacy Gathering / Crafting Concepts

Reference extracted from the Studio-only `SurvivalGatheringService.server.luau`. The exact original Luau remains in the verified legacy archive; this document captures the mechanics worth considering for the merged game without promoting the legacy service as a production owner.

## Core interaction

- Hatchet/melee range: **7 studs**
- Swing cooldown: **0.55 seconds**
- Resource respawn: **45 seconds**
- Base tree/rock harvest damage: **1**
- Legacy enemy hit damage: **15**
- Resource groups: **Trees**, **Rocks**, **IronOre**
- Resource health is tracked through attributes and depleted nodes respawn after the timer.
- **10% critical harvest** chance awards double yield.
- **5% rare discovery** chance awards bonus resources.
- Legacy inventory tracked `sticks`, `logs`, `stone`, and `iron_ore`.
- Hatchet upgrades increase tree/rock/enemy effectiveness.

## Legacy recipes

| Recipe | Cost |
| --- | --- |
| Stone Wall | 3 stone |
| Stone Floor | 2 stone, 1 log |
| Campfire | 5 sticks, 2 logs |
| Spike Trap | 3 sticks |
| Hatchet Upgrade | 3 stone, 2 sticks |
| Lantern | 2 iron ore, 1 stick |
| Storage Chest | 4 logs, 1 iron ore |
| Wooden Platform | 3 logs, 2 sticks |
| Iron Spikes | 3 iron ore, 2 sticks |

## Buildable ideas retained

- Stone walls and floors
- Campfires
- Lanterns / local lighting
- Storage chests
- Wooden platforms
- Iron spikes
- Spike traps that affect enemies

## What should survive the merge

The strongest idea is not the old implementation itself; it is a lightweight **field-resource → tactical preparation** loop. Gathering could give expeditions small optional choices such as temporary defenses, camp utility, side-objective rewards, crafting materials or hub upgrades without turning the action RPG into a slow survival simulator.

## What must be rewritten before activation

The legacy service owns its own inventory state and can directly mutate Humanoid health. That conflicts with the current authoritative architecture. If this feature is activated:

- resources/items must flow through canonical inventory and persistence;
- all hit/gather/build requests need server-side distance, state, cooldown and ownership validation;
- enemy damage must use canonical combat/damage resolution rather than direct Humanoid mutation;
- build placement needs server validation and bounds/collision rules;
- recipes and rewards must be balanced against the canonical economy;
- the feature should remain scope-gated until it demonstrably improves the core RPG/combat loop.
