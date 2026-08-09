# BA-033 — First Dungeon Elite/Boss Reward Decisions

**Status:** DONE as authored data; runtime consumption remains intentionally disabled.

**Primary source:** `games/living-kingdoms/src/shared/Config/FirstDungeonRewardDecisionConfig.luau`

## Goal

BA-032 authored the first repeatable dungeon and preserved the BA-030 `Elite` / `Boss` room reward references. BA-033 turns those two references into explicit player-decision data without inventing another loot, inventory, persistence, or reward authority.

The selected player-facing decision surface is the existing operation-bound **Run Relic choice**: two choices per reward, bounded to three non-stacking slots and owned by the canonical run-RPG system.

## Authored decision beats

| Order | Room | BA-030 room reward ref | Canonical run-RPG source | Decision | Source state | BA-033 runtime consumption |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `warden-threshold` | `Elite` | `reward-source.elite-kill` | Two-choice Run Relic offer | `Implemented` | Disabled |
| 2 | `keeper-core` | `Boss` | `reward-source.boss-milestone` | Two-choice Run Relic offer | `Planned` | Disabled |

The ordering is deliberate: the elite beat gives the player a build decision before the final boss, and the boss beat defines the intended capstone reward decision for the completed run.

## Authority boundary

BA-033 references, but does not replace, these existing owners:

- `RunRpgContracts` owns stable Run Relic and reward-source IDs;
- `RunRpgConfig` owns the relic catalog, two-choice reward size, implementation states, and run-build ceilings;
- the existing run-build service path remains the only authority allowed to create/resolve Run Relic offers;
- BA-032 `FirstDungeonContentConfig` remains the authored room/enemy sequence owner;
- BA-030 `RoomAssemblyContracts` remains the local `Elite` / `Boss` room reward-reference vocabulary.

`FirstDungeonRewardDecisionConfig` is intentionally unconsumed data. It grants nothing by itself and sets `RuntimeConsumptionEnabled = false` at both the package and decision level.

## Why persistent equipment is excluded

BA-042 found an older mapped persistent equipment reward/persistence pipeline beside the newer run-build choice system. That equipment path can generate elite/boss rarity/Power rewards, but its player-facing equip/application loop is incomplete and its product authority is unresolved.

BA-033 therefore sets `PersistentEquipmentEligible = false`. This is not a deletion or migration decision. BA-043 remains blocked until the project explicitly decides whether persistent equipment is retained, held dormant, or migrated.

## Elite source status

`reward-source.elite-kill` is already `Implemented` in the canonical run-RPG source catalog and has live pacing configuration. BA-033 still does **not** automatically connect the authored `warden-threshold` room to that runtime path. A future integration task must decide the exact authoritative event adapter so room completion cannot counterfeit a confirmed elite kill.

## Boss source status

`reward-source.boss-milestone` exists in `RunRpgContracts` and `RunRpgConfig`, but remains `Planned` and absent from live `RelicRewardSourceConfig` pacing. BA-033 deliberately preserves that state. The authored boss decision is therefore a destination contract for later wiring, not a claim that boss relic rewards are live.

## Validation

`FirstDungeonRewardDecisionConfig.test.luau` locks the following source-level invariants:

- exactly two ordered reward beats exist: elite then boss;
- both beats remain attached to the BA-032 elite/boss rooms and BA-030 reward refs;
- each beat maps to the canonical run-RPG reward-source ID;
- the two-choice Run Relic contract remains intact;
- elite source status remains `Implemented` and boss milestone remains `Planned`;
- runtime consumption stays disabled;
- persistent equipment stays excluded from this data package.

## Follow-on

A later integration ticket may consume this data through the existing authoritative run-build owner. That work must preserve server-confirmed event semantics, intentionally enable the boss milestone source before use, and must not silently activate the persistent equipment pipeline.
