# Enemy Ammunition Loot — HROI-0106 v2

## Purpose

Make a confirmed enemy kill occasionally create an immediate, readable resource reward without introducing inventory, rarity economies, client-authored pickups, or permanent progression.

This slice adds short-lived ammunition drops at corpse positions. It deliberately uses the existing authoritative ammunition scarcity and combat state boundaries.

## Player-facing behavior

- A server-confirmed Exclusion Walker death receives one deterministic loot roll.
- Approximately 7% of confirmed deaths produce **Salvaged Rounds** worth 8 reserve rounds.
- Approximately 1% produce a brighter **Heavy Ammo Case** worth 20 reserve rounds.
- Approximately 92% produce no item, preserving brutal ammunition scarcity.
- There is no pity timer, dry-streak guarantee, or hidden catch-up grant.
- Drops hover, rotate, glow, and disclose their ammunition value above the corpse position.
- A living operative automatically collects a drop inside 5.5 studs.
- When multiple operatives are eligible, the nearest collects; equal-distance ordering is stable by player UserId.
- A player with full reserve ammunition cannot consume the drop, leaving it available to a teammate.
- Common drops expire after 16 seconds. Rare drops expire after 24 seconds.
- Collection uses the existing ammunition HUD feedback through the authoritative combat runtime.

At these rates, the expected enemy-loot return is 0.76 reserve rounds per kill before capacity clamping. Enemy kills therefore cannot sustain automatic fire by themselves; authored caches, conservation upgrades, movement, and squad resource discipline remain important.

## Authority model

`EnemyLootService` owns every consequential fact:

1. It observes the existing server-authored enemy `LifeStateId` and `HitSequence` attributes.
2. It accepts one non-dead → `Dead` transition per tracked production enemy.
3. It derives the deterministic rarity roll from enemy identity and server death sequence.
4. It creates and owns the replicated pickup instance.
5. It derives eligible players from `Players`, life state, server character position, and reserve capacity.
6. It resolves the grant through `AmmunitionSupplyResolver` using the explicit `EnemyLoot` supply source.
7. It commits reserve ammunition through `OperativeCombatRuntimeService`.
8. It destroys the item only after a successful authoritative commit or lifetime expiry.

The client submits no loot claim, pickup identity, location, rarity, ammunition amount, capacity, or inventory state.

## Runtime bounds

- one server Heartbeat connection
- one combined evaluation every 0.1 seconds
- at most 64 observed living/corpse-overlap enemy models
- at most 16 active loot drops
- at most eight planned players considered per active drop
- zero per-enemy connections
- zero per-drop connections
- zero touch events
- zero ProximityPrompts
- zero delayed tasks
- zero loot remotes
- zero DataStore access

The service creates no new enemy, combat, pathfinding, raycast, or client frame loop.

## Cooperative decision

Enemy ammunition loot is first-come by physical proximity, but full-ammo players cannot waste it. This keeps the reward immediate while allowing a nearby lower-ammunition teammate to claim value.

Drops are not instanced per player in v2. Personal loot, manual pinging, reserve requests, and squad allocation UI remain deferred.

## Explicitly deferred

- healing items and an authoritative Alive → Alive healing contract
- armor, shields, or temporary invulnerability
- weapons, attachments, rarity affixes, crafting, and inventory
- currency or permanent account rewards
- magnet range upgrades
- pity timers or guaranteed enemy drops
- special-enemy-specific loot tables
- objective, revive, or container loot
- sound and authored mesh assets

## Acceptance gate

Automated validation must pass StyLua, Selene, every Lune fixture, and Rojo build. Studio approval must verify:

1. confirmed deaths sometimes produce common, rare, and no-drop outcomes
2. long kill streaks can legitimately produce no ammunition drops
3. the item appears at the corpse rather than the enemy spawn point
4. the label and glow are readable from the elevated isometric camera
5. entering 5.5 studs collects without a button press
6. reserve ammunition increases by the disclosed amount, clamped to capacity
7. a full-ammo player does not delete a drop
8. two nearby players produce one authoritative winner
9. corpse cleanup does not remove or duplicate an already-created drop
10. common and rare drops expire at their configured lifetimes
11. sixteen active drops prevent further creation until budget is released
12. session restart clears every drop and collection record
13. no warnings or runtime errors appear during death, collection, expiry, join, or leave