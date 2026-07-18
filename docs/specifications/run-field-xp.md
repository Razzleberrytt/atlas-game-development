# Run Field XP and Squad Upgrades — HROI-0105 v2

## Purpose

Make every confirmed enemy death visibly advance the current operation and turn level thresholds into immediate combat decisions without introducing permanent progression, inventory scope, or client-authored rewards.

This slice extends shared squad Field XP with a bounded three-choice run-upgrade loop. It remains deliberately smaller than a full roguelite system: four upgrades, no rarity, no inventory, no persistence, and no paid power.

## Player-facing behavior

- Every server-confirmed enemy death awards **20 Field XP** to the current squad run.
- Field Level 2 requires 100 XP, so the first level-up occurs after five ordinary confirmed deaths under prototype tuning.
- Later thresholds grow by 1.3× per level, rounded to whole XP.
- The bottom-center HUD shows current Field Level, XP progress, and short XP/selection confirmations.
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

An XP award is legal only when a tracked production enemy transitions from a non-dead life state to authoritative `Dead`. A newly observed dead model is accepted only after the initial baseline scan and only when it carries a confirmed hit sequence. Each model can award once.

`ProgressionNetwork` exposes:

- `State` — server-to-client safe snapshots
- `ReadState` — read-only recovery of the current snapshot
- `ChooseUpgrade` — client-to-server submission of one upgrade ID

`ChooseUpgrade` accepts no client level, stack, magnitude, damage, cadence, chance, XP, or reward values. The server rejects extra arguments, throttles requests, verifies the ID is in the current offer, verifies its stack cap, accepts only the first legal selection, and publishes the resulting shared snapshot.

Accepted stacks are reduced to bounded combat modifiers by the pure `RunUpgradeResolver`. `RunProgressionService` writes those values as server-owned attributes on `ProgressionNetwork` before automatic combat starts. The pure automatic-fire and damage resolvers consume those trusted attributes and fail closed on out-of-range values.

There is no persistence or DataStore access.

## Cooperative decision

Field XP and upgrades are shared by the squad. This prevents kill stealing and makes automatic combat compatible with cooperative progression. The first accepted squad choice wins in v2; voting, leader assignment, individualized builds, shooter credit, and assists remain later product decisions.

## Runtime bounds

- one server Heartbeat connection
- one bounded enemy-folder scan every 0.1 seconds
- at most 64 tracked living/corpse-overlap models
- zero per-enemy progression connections
- zero server delayed progression tasks
- one throttled upgrade intent connection
- one client state-event connection
- three fixed button connections
- one client RenderStepped connection used only to fade the gain notification
- zero new combat loops, raycasts, path requests, or enemy population

The 64-model observation ceiling does not increase the authoritative 24-living-enemy gameplay cap.

## Explicitly deferred

- upgrade rerolls, rarity, synergies, curses, and branching trees
- reload, magazine, movement, revive, pickup, armor, or maximum-health upgrades
- squad voting or designated chooser rules
- assists and contribution XP
- objective and revive XP
- loot drops
- permanent account progression
- battle pass, paid power, inventory, crafting, and rarity economies

## Acceptance gate

Automated validation must pass StyLua, Selene, every Lune fixture, and Rojo build. Studio approval must verify:

1. five confirmed enemy deaths produce one level-up and one three-card offer
2. a killing hit awards only once
3. two clients see identical choices and the same accepted result
4. stale, duplicate, unoffered, malformed, and spammed choice requests do not mutate state
5. each accepted upgrade changes only its documented combat behavior
6. maxed upgrades leave later offer pools
7. corpse cleanup does not duplicate XP
8. restarting the server session resets Field XP and all modifier attributes
9. the choice panel is usable with mouse and touch without obscuring critical combat space
10. the 24-enemy representative load remains playable with the progression HUD visible
