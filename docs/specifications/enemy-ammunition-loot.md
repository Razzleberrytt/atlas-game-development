# Enemy Ammunition Loot — HROI-0106 v2

## Purpose

Make a confirmed enemy kill create an immediate, readable resource reward often enough to sustain momentum without introducing inventory, rarity economies, client-authored pickups, or permanent progression.

This slice adds short-lived ammunition drops at corpse positions. It deliberately uses the existing authoritative ammunition scarcity and combat state boundaries.

## Player-facing behavior

- A server-confirmed Exclusion Walker death receives one deterministic loot decision.
- The **first confirmed kill of the server run always produces Salvaged Rounds**, so the reward loop is visible immediately.
- Every fifth confirmed death also guarantees **Salvaged Rounds** when the active world-drop budget allows it.
- Between guaranteed checkpoints, approximately 30% of confirmed deaths naturally produce **Salvaged Rounds** worth 8 reserve rounds.
- Approximately 5% of non-guaranteed deaths produce a brighter **Heavy Ammo Case** worth 20 reserve rounds.
- Other non-guaranteed deaths produce no item, preserving anticipation and scarcity.
- Drops hover, rotate, glow, and disclose their ammunition value above the corpse position.
- A living operative automatically collects a drop inside 5.5 studs.
- When multiple operatives are eligible, the nearest collects; equal-distance ordering is stable by player UserId.
- A player with full reserve ammunition cannot consume the drop, leaving it available to a teammate.
- Common drops expire after 16 seconds. Rare drops expire after 24 seconds.
- Collection uses the existing ammunition HUD feedback through the authoritative combat runtime.

The cadence floor bounds rewardless combat to four consecutive deaths after the opening reward. The active-drop cap still takes precedence, so guaranteed cadence never creates unbounded world objects.

## Authority model

`EnemyLootService` and the pure `EnemyLootResolver` own every consequential fact:

1. The service observes the existing server-authored enemy `LifeStateId` and `HitSequence` attributes.
2. It accepts one non-dead → `Dead` transition per tracked production enemy.
3. It supplies the server-owned death sequence and active-drop count to the resolver.
4. The resolver applies first-blood and five-death cadence guarantees before natural rarity resolution.
5. The resolver derives all decisions deterministically from enemy identity and server death sequence; it never uses client input or random state.
6. The service creates and owns the replicated pickup instance.
7. It derives eligible players from `Players`, life state, server character position, and reserve capacity.
8. It resolves the grant through `AmmunitionSupplyResolver` using the explicit `EnemyLoot` supply source.
9. It commits reserve ammunition through `OperativeCombatRuntimeService`.
10. It destroys the item only after a successful authoritative commit or lifetime expiry.

The client submits no loot claim, pickup identity, location, rarity, ammunition amount, capacity, death count, guarantee state, or inventory state.

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
- zero additional loops or state tables for the guarantee cadence

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
- special-enemy-specific loot tables
- objective, revive, or container loot
- sound and authored mesh assets

## Acceptance gate

Automated validation must pass StyLua, Selene, every Lune fixture, and Rojo build. Studio approval must verify:

1. the first confirmed kill creates common Salvaged Rounds
2. each configured five-death checkpoint creates common Salvaged Rounds when below the active-drop cap
3. natural common, rare, and no-drop outcomes still occur between guaranteed checkpoints
4. the item appears at the corpse rather than the enemy spawn point
5. the label and glow are readable from the elevated isometric camera
6. entering 5.5 studs collects without a button press
7. reserve ammunition increases by the disclosed amount, clamped to capacity
8. a full-ammo player does not delete a drop
9. two nearby players produce one authoritative winner
10. corpse cleanup does not remove or duplicate an already-created drop
11. common and rare drops expire at their configured lifetimes
12. sixteen active drops prevent both rolled and guaranteed creation until budget is released
13. session restart clears every drop and death-sequence record
14. no warnings or runtime errors appear during death, collection, expiry, join, or leave
