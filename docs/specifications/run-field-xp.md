# Run Field XP and Squad Upgrades — HROI-0105 v3

## Purpose

Make every confirmed enemy death visibly advance the current operation and turn level thresholds into immediate combat decisions without introducing permanent progression, inventory scope, or client-authored rewards.

This slice extends shared squad Field XP with a bounded three-choice run-upgrade loop and one narrow tactical bonus for confirmed Screamer interruptions. It remains deliberately smaller than a full roguelite system: four upgrades, no rarity, no inventory, no persistence, and no paid power.

## Player-facing behavior

- Every server-confirmed enemy death awards **20 Field XP** to the current squad run.
- Killing a Choir Screamer during its authoritative reinforcement windup awards an additional **10 Field XP** exactly once.
- Field Level 2 requires 80 XP, so the first level-up occurs after four ordinary confirmed deaths under current tuning.
- Later thresholds grow by 1.4× per level, rounded to whole XP.
- The unified combat HUD shows current Field Level, XP progress, and level/selection confirmations.
- Crossing a threshold opens a centered three-card squad upgrade choice.
- The first valid squad selection locks the upgrade for the run and closes the offer for every client.
- Multiple unclaimed levels queue one offer at a time.
- Field XP, level, kills, offers, stacks, and modifiers reset when the progression service starts a new server session.

## Initial upgrade pool

Each offer contains three eligible entries selected deterministically from the four-upgrade pool. Maxed upgrades leave the offer pool.

| Upgrade | Per-stack effect | Maximum stacks |
|---|---:|---:|
| Overpressure Rounds | +20% firearm damage | 4 |
| Hair Trigger | 12% shorter automatic-fire cadence | 4 |
| Echo Chamber | 15% deterministic chance that a shot consumes no ammunition | 3 |
| Cull Protocol | +35% damage against enemies at 30 health or less | 3 |

Hard combat ceilings remain independent of card text:

- total applied damage may not exceed 3× configured firearm damage
- automatic-fire cadence may not fall below 55% of configured cadence
- ammo conservation may not exceed 45%
- Cull Protocol activates only at the server-configured 30-health threshold

## Authority model

The server owns all progression and modifier facts. `RunProgressionService` observes the existing server-authored enemy `LifeStateId` and `HitSequence` attributes under `Workspace.EnemyEntities`.

An ordinary death XP award is legal only when a tracked production enemy transitions from a non-dead life state to authoritative `Dead`. A newly observed dead model is accepted only after the initial baseline scan and only when it carries a confirmed hit sequence. Each model can award once.

`ScreamerInterruptRewardService` separately observes the bounded enemy folder so scheduler order cannot lose the later `Windup` → `Interrupted` fact. A bonus is legal only for a dead Screamer with a confirmed hit, the reinforcement special kind, the exact authoritative `Interrupted` state, a positive special sequence, and a non-empty server-authored combat entity ID. It submits a deterministic event ID through `RunProgressionService.awardFieldIntel`, whose bounded processed-ID history rejects duplicates. No client remote exists for the bonus.

`ProgressionNetwork` exposes:

- `State` — server-to-client safe snapshots
- `ReadState` — read-only recovery of the current snapshot
- `ChooseUpgrade` — client-to-server submission of one upgrade ID

`ChooseUpgrade` accepts no client level, stack, magnitude, damage, cadence, chance, XP, or reward values. The server rejects extra arguments, throttles requests, verifies the ID is in the current offer, verifies its stack cap, accepts only the first legal selection, and publishes the resulting shared snapshot.

Accepted stacks are reduced to bounded combat modifiers by the pure `RunUpgradeResolver`. `RunProgressionService` writes those values as server-owned attributes on `ProgressionNetwork` before automatic combat starts. The pure automatic-fire and damage resolvers consume those trusted attributes and fail closed on out-of-range values.

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
- reload, magazine, movement, revive, pickup, armor, or maximum-health upgrades
- squad voting or designated chooser rules
- assists and non-interrupt contribution XP
- objective and revive XP
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
