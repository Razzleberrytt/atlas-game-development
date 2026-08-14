# Patch 0.7 — Durable player-value domain inventory

**Status:** analysis for Patch 0.7 tasks #61–#63
**Method:** every `src/server/Systems` module holding per-player state was checked for a durable path (`DataStore`, `InventoryLiveService`, or the persistence service). Domains below are what that search found, not what the design intends.

## What is durable today

Exactly one durable record exists per Roblox user id, owned by `PlayerInventoryPersistenceService` and reached only through `InventoryLiveService`.

| Domain | Durable? | Owner |
|---|---|---|
| Equipment inventory (items, affixes, rarity, power) | yes | `PlayerInventoryPersistenceService` |
| Equipped slot bindings | yes | same record |
| Applied reward grant ledger | yes | same record |
| Applied dismantle ledger | yes | same record |
| Per-grant content signatures | yes | same record (schema 4) |

Five server modules consume it: `inventory-network`, `expedition-reward-results`, `DurableStartingLoadoutService`, `OperativeProgressionService`, `RelicModifierService`.

## What survives only in memory

| Domain | Loss on disconnect | Deliberate? |
|---|---|---|
| Run XP, run level, run upgrade choices (`RunProgressionService`) | whole run's progression | **Yes** — the module documents itself as run-only; a run is the unit of play |
| Run relic/build modifiers (`RunBuildService`) | run build | Yes — same run scope |
| Weapon loadout selection (`WeaponLoadoutService`) | current loadout | Yes — re-derived from durable gear on join |
| Class selection (`ClassService`) | current class | Yes — re-chosen per session |
| Ammunition cache state (`AmmunitionCacheService`) | run consumables | Yes — run economy |
| Life/revive state (`OperativeLifeService`, `OperativeReviveSessionService`) | current health/downed state | Yes — session state by definition |
| Recovery loot in progress (`RecoveryLootService`) | uncollected run loot | Yes — collected loot becomes durable equipment |
| Run currency (`RunCurrencyAmount`, secret branch rewards) | run currency | Yes — the field name is its scope |

**Ranked by player loss impact, none of these justifies durability today.** Each is scoped to a run or a session by design, and the value that is meant to outlive a run — equipment — already crosses into the durable record through the reward path. Making run state durable would not harden persistence; it would change what a run *is*.

## Account vs character boundary (#63)

There is no character concept. The durable key is `player:<UserId>:inventory` and the lease key is `player:<UserId>:lease`, both derived from the Roblox user id alone. **Everything durable is account-scoped.**

This is worth stating because it is an easy thing to break silently: a future per-character record keyed only by user id would collide across characters, and one keyed by character id would lose the account-wide guarantee the lease depends on. The lease protects a *user*, so any per-character durable state must live inside the account record or acquire its own lease.

## Progression and unlocks are derived, not stored (#64, #65)

Operative rank and unlocks are a deterministic projection of the durable grant ledger, computed by `OperativeProgressionResolver` and served by `OperativeProgressionService`. Nothing about them is separately persisted.

**That is the better design and Patch 0.7 should not undo it.** A separate durable progression record would be a second authority over the same facts, free to disagree with the ledger it was derived from — which is precisely the divergence task #70 exists to prevent. The single-owner rule applies to durable state as much as to runtime services.

The failure mode here is not "progression is not durable". It is "the projection silently stops matching its source" — which is exactly what happened before PR #495, when the resolver read the ledger by value and rejected every non-empty one. The protection that matters is a cross-domain version binding, not a second record.

## Currency (#66)

The task is scoped to "currencies already proven necessary by gameplay". There is no durable currency. `RunCurrencyAmount` appears only in secret-branch reward config and is run-scoped by name and by use. No durable currency contract is warranted, and inventing one would create a durable domain no gameplay reads.

## Consequences for #67–#69

Atomic mutation transaction identity for progression, unlocks, and currency presupposes durable mutations in those domains. There are none: progression and unlocks are derived, and currency does not exist durably. The transaction identity that matters already exists on the mutations that are real — reward grants and dismantles — and is covered by Patch 0.7 Batch 4.
