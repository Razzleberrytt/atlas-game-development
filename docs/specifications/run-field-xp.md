# Run Field XP — HROI-0105 v1

## Purpose

Make every confirmed enemy death visibly advance the current operation without introducing permanent progression, inventory scope, or client-authored rewards.

This first slice adds **shared squad Field XP** and a compact always-visible HUD. It intentionally stops before upgrade choices so the reward truth, pacing, networking, and presentation can be validated independently.

## Player-facing behavior

- Every server-confirmed enemy death awards **20 Field XP** to the current squad run.
- Field Level 2 requires 100 XP, so the first level-up occurs after five ordinary confirmed deaths under prototype tuning.
- Later thresholds grow by 1.3× per level, rounded to whole XP.
- The bottom-center HUD shows current Field Level, XP progress, and a short `+20 FIELD XP` confirmation.
- Crossing a threshold displays a stronger `LEVEL UP! FIELD LEVEL N` message.
- Field XP, level, and kill count reset when the server starts a new operation session.

## Authority model

The server owns all progression facts. `RunProgressionService` observes the existing server-authored enemy `LifeStateId` and `HitSequence` attributes under `Workspace.EnemyEntities`.

An award is legal only when a tracked production enemy transitions from a non-dead life state to authoritative `Dead`. A newly observed dead model is accepted only after the initial baseline scan and only when it carries a confirmed hit sequence. Each model can award once.

The client cannot submit a kill, XP amount, level, reward, or progression mutation. `ProgressionNetwork` exposes only:

- `State` — server-to-client safe snapshots
- `ReadState` — read-only recovery of the current snapshot for a client that missed the first event

There is no persistence or DataStore access.

## Cooperative decision

Field XP is shared by the squad for this slice. This prevents kill stealing and makes automatic combat compatible with cooperative progression. Shooter-specific credit, assists, and individualized upgrade choices remain future extensions.

## Runtime bounds

- one server Heartbeat connection
- one bounded enemy-folder scan every 0.1 seconds
- at most 128 tracked living/corpse-overlap models
- zero per-enemy connections
- zero server delayed tasks
- zero client reward requests
- one client state-event connection
- one client RenderStepped connection used only to fade the gain notification

The 128-model observation ceiling does not increase the authoritative 96-living-enemy profiling cap.

## Explicitly deferred

- three-choice run upgrades
- damage, reload, magazine, movement, revive, pickup, or armor modifiers
- assists and contribution XP
- objective and revive XP
- loot drops
- permanent account progression
- battle pass, paid power, inventory, crafting, and rarity economies

## Acceptance gate

Automated validation must pass StyLua, Selene, every Lune fixture, and Rojo build. Studio approval must verify:

1. five confirmed enemy deaths produce one level-up
2. a killing hit awards only once
3. two clients see identical shared progression
4. late client state recovery is correct
5. corpse cleanup does not duplicate XP
6. restarting the session resets Field XP
7. the HUD remains readable without covering the isometric combat space
