# Run Field XP and Squad Upgrades — HROI-0105 v4

## Purpose

Make every confirmed enemy death visibly advance the current operation and turn level thresholds into immediate combat decisions without introducing permanent progression, inventory scope, or client-authored rewards.

This slice extends shared squad Field XP with a bounded three-choice run-upgrade loop and one narrow tactical bonus for confirmed Screamer interruptions. It remains deliberately smaller than a full roguelite system: no rarity, no inventory, no persistence, and no paid power. The v4 pool grew from four all-offensive picks to **eight upgrades across offensive, defensive, economy, reload, and pattern axes**, adopting the canonical RPG-0101 catalog identities (see [`rpg-integration-plan.md`](rpg-integration-plan.md) §7.4). It is the first implementation slice of the RPG track's Field Upgrade layer.

## Player-facing behavior

- Every server-confirmed enemy death awards **20 Field XP** to the current squad run.
- Killing a Choir Screamer during its authoritative reinforcement windup awards an additional **10 Field XP** exactly once.
- Field Level 2 requires 80 XP, so the first level-up occurs after four ordinary confirmed deaths under current tuning.
- Later thresholds grow by 1.4× per level, rounded to whole XP.
- The unified combat HUD shows current Field Level, XP progress, and level/selection confirmations.
- Crossing a threshold opens a centered three-card squad upgrade choice.
- The first valid squad selection locks the upgrade for the run and closes the offer for every client.
- Multiple unclaimed levels queue one offer at a time.
- Field XP, level, kills, and offers reset when the progression service starts a new server session. The centralized `RunBuildService` resets owned upgrade stacks and future relic/effect state at the operation boundary; derived modifier attributes reset from that empty state.

## Upgrade pool (v4)

Each offer contains three eligible entries selected deterministically from the eight-upgrade pool. Maxed upgrades leave the offer pool.

| Upgrade | Per-stack effect | Maximum stacks | Axis |
|---|---:|---:|---|
| Overpressure Rounds | +20% firearm damage | 4 | Firepower |
| Hair Trigger | 12% shorter automatic-fire cadence | 4 | Firepower |
| Echo Chamber | 15% deterministic chance that a shot consumes no ammunition | 3 | Ammunition |
| Cull Protocol | +35% damage against enemies at 30 health or less | 3 | Firepower |
| Trauma Plating | −10% incoming enemy damage (squad) | 3 | Survival |
| Field Discipline | +15% Field XP from confirmed kills | 3 | Economy |
| Combat Loader | −12% reload duration | 3 | Reload |
| Pattern Amplifier | +15% cleave/pierce secondary damage, up to full primary | 3 | Firepower |

Trauma Plating is a squad modifier consumed at the enemy attack source (`EnemyDirectorService` scales the melee `damageAmount` before the P3 commit boundary, mirroring how `DamageResolver` scales operative damage). Combat Loader is consumed by `ReloadResolver` at reload begin. Pattern Amplifier is consumed in `DamageResolver`'s secondary-impact (`resolvePattern`) path. All fall back to no effect when progression state is absent.

Hard combat ceilings remain independent of card text and are held within the shared RPG-0101 global `ModifierCeilings` (locked by `RunRpgReconciliation`):

- total applied damage may not exceed 3× configured firearm damage
- automatic-fire cadence may not fall below 55% of configured cadence
- ammo conservation may not exceed 45%
- Cull Protocol activates only at the server-configured 30-health threshold
- incoming-damage mitigation may not exceed 30% (multiplier floor 0.7)
- Field XP economy may not exceed 1.5× (the global `maximumFieldXpMultiplier`)
- reload duration may not fall below 50% of configured duration
- Pattern Amplifier raises secondary damage only up to full primary damage (effective secondary multiplier capped at 1.0; attribute bounded by the global `maximumPatternDamageMultiplier` of 2×)

### Interim mechanics

RPG-PLAN-001 §7.1 describes Trauma Plating as post-level *temporary armor* and Field Discipline as bonus XP from *cooperative actions* (revive/treatment/resupply/objective). Those forms depend on a temporary-armor health buffer and cooperative-action XP sources that are not yet built, so this slice ships simpler functional mechanics (flat squad mitigation; confirmed-kill XP) and records the divergence in [`rpg-integration-plan.md`](rpg-integration-plan.md) §7.4. Combat Loader matches its planned mechanic.

## Authority model

The server owns all progression and modifier facts. `RunBuildService` is the operation-scoped owner of the shared Field Upgrade stacks mirrored into each operative's build record; `RunProgressionService` observes the existing server-authored enemy `LifeStateId` and `HitSequence` attributes under `Workspace.EnemyEntities`.

An ordinary death XP award is legal only when a tracked production enemy transitions from a non-dead life state to authoritative `Dead`. A newly observed dead model is accepted only after the initial baseline scan and only when it carries a confirmed hit sequence. Each model can award once.

`ScreamerInterruptRewardService` separately observes the bounded enemy folder so scheduler order cannot lose the later `Windup` → `Interrupted` fact. A bonus is legal only for a dead Screamer with a confirmed hit, the reinforcement special kind, the exact authoritative `Interrupted` state, a positive special sequence, and a non-empty server-authored combat entity ID. It submits a deterministic event ID through `RunProgressionService.awardFieldIntel`, whose bounded processed-ID history rejects duplicates. No client remote exists for the bonus.

`ProgressionNetwork` exposes:

- `State` — server-to-client safe snapshots
- `ReadState` — read-only recovery of the current snapshot
- `ChooseUpgrade` — client-to-server submission of one upgrade ID

`ChooseUpgrade` accepts no client level, stack, magnitude, damage, cadence, chance, XP, or reward values. The server rejects extra arguments, throttles requests, verifies the ID is in the current offer, verifies its stack cap, accepts only the first legal selection, and publishes the resulting shared snapshot.

Accepted stacks commit through `RunBuildService` and are reduced to bounded combat modifiers by the pure `RunUpgradeResolver`. `RunProgressionService` writes those values as server-owned attributes on `ProgressionNetwork` before automatic combat starts. The authoritative resolvers consume those trusted attributes and fail closed on out-of-range values: `AutomaticFireResolver` (cadence, ammo conservation), `DamageResolver` (damage, cull), `EnemyDirectorService` (incoming-damage mitigation, applied to the melee amount before the P3 commit), `ReloadResolver` (reload duration, applied at reload begin), and `DamageResolver.resolvePattern` (Pattern Amplifier, raising secondary cleave/pierce damage toward full primary). Field Discipline's Field XP bonus is applied inside `RunProgressionService` when awarding confirmed-kill XP.

There is no persistence or DataStore access.

## Cooperative decision

Field XP and upgrades are shared by the squad. This prevents kill stealing and makes automatic combat compatible with cooperative progression. The first accepted squad choice wins in v3; voting, leader assignment, individualized builds, shooter credit, and assists remain later product decisions.

## Runtime bounds

- one server Heartbeat connection for ordinary death progression
- one bounded enemy-folder scan every 0.1 seconds for ordinary deaths
- one separate bounded Heartbeat scan every 0.1 seconds for confirmed Screamer interruptions
- at most 64 tracked living/corpse-overlap models in either observer
- zero per-enemy progression or reward connections
- zero server delayed progression tasks
- one throttled upgrade intent connection
- one unified client progression-state connection
- fixed upgrade buttons created only while a server-authored offer exists
- zero new combat loops, raycasts, path requests, or enemy population

The 64-model observation ceiling does not increase the authoritative 24-living-enemy gameplay cap.

## Explicitly deferred

- upgrade rerolls, rarity, synergies, curses, and branching trees
- magazine, movement, revive, pickup, or maximum-health upgrades (reload is now implemented via Combat Loader; survivability ships as Trauma Plating's interim flat mitigation rather than the planned temporary-armor buffer)
- squad voting or designated chooser rules
- assists and non-interrupt contribution XP
- cooperative-action XP sources (revive/treatment/resupply/objective) — Field Discipline currently boosts confirmed-kill XP as an interim mechanic until these sources exist
- permanent account progression
- battle pass, paid power, inventory, crafting, and rarity economies

## Acceptance gate

Automated validation must pass StyLua, Selene, every Lune fixture, and Rojo build. Studio approval must verify:

1. four ordinary confirmed enemy deaths produce one level-up and one three-card offer
2. a killing hit awards ordinary death XP only once
3. two clients see identical choices and the same accepted result
4. stale, duplicate, unoffered, malformed, and spammed choice requests do not mutate state
5. each accepted upgrade changes only its documented combat behavior
6. maxed upgrades leave later offer pools
7. corpse cleanup does not duplicate ordinary XP
8. restarting the server session resets Field XP and all modifier attributes
9. a Screamer killed during reinforcement windup grants one +10 bonus, displays +30 combined XP, and cannot duplicate after cleanup
10. the choice panel is usable with mouse and touch without obscuring critical combat space
11. the 24-enemy representative load remains playable with both bounded progression observers active
