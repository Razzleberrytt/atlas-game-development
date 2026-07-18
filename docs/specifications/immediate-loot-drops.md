# Immediate run loot drops — HROI-0106 v1

Tracking: issue #98, **Horde Pressure & Run Reward Vertical Slice**.

## Goal

Make confirmed enemy deaths occasionally leave an immediate, readable reward in the world without introducing permanent inventory, rarity economies, crafting, paid power, or client-authored rewards.

## Drop pool

| Drop | Deterministic share | Reward |
| --- | ---: | ---: |
| Ammunition Bundle | 45% | up to 8 reserve rounds |
| Field Dressing | 25% | up to 30 canonical P3 health |
| Field Intel | 10% | 40 shared Field XP |
| No drop | 20% | — |

The item decision is deterministic from the authoritative enemy entity ID. It is not a client roll and does not use `math.random`.

## World readability

Each accepted drop appears immediately above the confirmed corpse position as a server-owned floating neon pickup with:

- distinct item color
- occlusion-respecting highlight
- point light
- isometric-distance billboard showing item name and reward
- instant ProximityPrompt collection

Drops expire after 18 seconds. At most 20 may exist simultaneously, while death observation remains bounded to the existing 64-model living/corpse-overlap ceiling. The pickup model is transient world presentation and is destroyed immediately after a successful authoritative claim.

## Authority chain

1. `LootDropService` observes the existing server-authored enemy life-state and confirmed-hit attributes.
2. A non-dead → `Dead` transition is processed once by enemy entity ID.
3. `LootDropResolver` receives only server facts and returns a deterministic drop decision.
4. The server creates the world object and maps its prompt to the authoritative drop entry.
5. Roblox supplies the triggering `Player` through one global `ProximityPromptService.PromptTriggered` connection.
6. The service revalidates drop identity, availability, player life state, current operative position, and maximum collection distance.
7. The selected reward must commit through its existing or newly revisioned authority boundary before the drop is consumed.

The client cannot submit a drop ID, kind, reward amount, position, claim state, health, ammunition, or XP.

## Reward boundaries

### Ammunition Bundle

Uses the existing pure `AmmunitionSupplyResolver` with the new server-only `EnemyDrop` source ID, then commits through `OperativeCombatRuntimeService.commitReviveCombatState`. A full reserve leaves the drop available for another squad member.

### Field Dressing

Uses a new pure `OperativeHealingResolver` and `OperativeLifeService.applyAuthoritativeHealing`. Healing is:

- Alive-only
- revision-gated
- timestamp-matched
- clamped to canonical maximum health
- committed to P3 health, never Humanoid health

A full-health operative cannot consume the dressing.

### Field Intel

Uses `RunProgressionService.awardFieldIntel` with a bounded duplicate-protected reward ID. It grants shared run-only Field XP and may generate the next server-owned upgrade choice. It does not increment squad kills.

## Runtime bounds

- one loot Heartbeat connection
- one global prompt-triggered connection
- one player-removal connection
- zero per-drop connections
- maximum 20 active drops
- 18-second lifetime
- maximum eight-stud collection distance
- zero timers or delayed tasks
- zero new remotes
- zero persistent storage

## Explicitly deferred

- inventory and manual item slots
- rarity tiers
- equipment drops
- affixes and randomized stats
- crafting and vendors
- permanent unlocks
- physics-scattered gore or loot
- individualized ownership locks
- special-enemy-exclusive loot tables

## Acceptance gate

Automated validation must pass StyLua, Selene, the full Lune fixture suite, and Rojo build. Studio review must confirm:

1. drops appear at corpse positions and remain readable from the gameplay camera
2. one drop can be collected only once
3. full ammo or health does not waste the pickup
4. another squad member may collect a pickup the first operative cannot use
5. Field Intel advances shared Field XP without adding a kill
6. pickup distance is revalidated on the server
7. drops expire and the active cap is respected
8. 24 living enemies plus temporary drops remain acceptable on representative hardware
