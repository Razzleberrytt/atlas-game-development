# Run Field XP and squad upgrades — HROI-0105 v2

## Purpose

Make every confirmed enemy death visibly advance the current operation and turn each earned Field Level into a consequential run-only squad choice without introducing permanent progression, inventory scope, or client-authored rewards.

## Player-facing behavior

- Every server-confirmed enemy death awards **20 shared Field XP**.
- Field Level 2 requires 100 XP, so the first choice arrives after five ordinary confirmed deaths under prototype tuning.
- Later thresholds grow by 1.3× per level, rounded to whole XP.
- The bottom-center HUD shows Field Level, XP progress, and short gain/level-up confirmation.
- Every earned level queues one server-authored three-choice upgrade offer.
- Every client sees the same offer. The first valid server-accepted selection locks the squad choice.
- Choices do not pause combat and reset with the operation session.

## Initial upgrade pool

| Upgrade | Effect per stack | Server application |
| --- | ---: | --- |
| Ballistic Calibration | +5 firearm damage | Optional bounded argument to `DamageResolver` |
| Rapid Cycling | 10% faster automatic fire | Optional bounded argument to `AutomaticFireResolver` |
| Quick Hands | 15% faster reload | Optional bounded argument to `ReloadResolver.begin` |

Offer order rotates deterministically by Field Level and offer sequence. The server authors all three choices and stack counts. Effects are clamped by shared configuration even if many levels are earned.

## Authority model

The server owns all progression facts. `RunProgressionService` observes the existing server-authored enemy `LifeStateId` and `HitSequence` attributes under `Workspace.EnemyEntities`.

An award is legal only when a tracked production enemy transitions from a non-dead life state to authoritative `Dead`. A newly observed dead model is accepted only after the initial baseline scan and only when it carries a confirmed hit sequence. Each model can award once.

`ProgressionNetwork` exposes:

- `State` — server-to-client safe snapshots
- `ReadState` — read-only recovery for a client that missed the first event
- `SelectionIntent` — one narrow client request containing only a request ID, the current offer ID, and one offered upgrade ID

The selection boundary validates exact payload shape, request cadence, current offer identity, offered membership, and stack bounds. Clients cannot submit kills, XP, levels, offer contents, stacks, damage values, cadence values, reload duration, or persistent progression.

There is no persistence or DataStore access.

## Cooperative decision

Field XP and upgrade effects are shared by the squad. This prevents kill stealing, keeps automatic combat cooperative, and guarantees that all operatives use one authoritative run build. Two simultaneous choices are serialized by the server; after the first valid selection commits, the stale offer is rejected for everyone else.

## Combat composition

`OperativeCombatRuntimeService` reads one immutable modifier snapshot from `RunProgressionService` during each operative evaluation and when a reload begins. The existing pure combat resolvers accept optional server arguments:

- no argument preserves baseline behavior
- malformed, slower, negative, non-finite, or out-of-bound values fall back to baseline
- the client never supplies these arguments

Death observation remains independent of shooter identity. Upgrade choices do not change the XP truth path.

## Runtime bounds

- one server Heartbeat connection
- one bounded enemy-folder scan every 0.1 seconds
- at most 64 tracked living/corpse-overlap models
- at most four queued upgrade selections
- one progression selection-event connection
- 0.2-second per-player selection request cooldown
- zero per-enemy connections
- zero server delayed tasks in progression
- one read-only XP HUD event connection and frame connection
- one upgrade-choice state event connection

The 64-model observation ceiling does not increase the authoritative 24-living-enemy gameplay cap.

## Explicitly deferred

- individualized operative upgrade choices
- voting or host-priority selection rules
- movement, revive, pickup, armor, or special-ability upgrades
- assists and contribution XP
- objective and revive XP
- loot drops
- permanent account progression
- battle pass, paid power, inventory, crafting, and rarity economies

## Acceptance gate

Automated validation must pass StyLua, Selene, every Lune fixture, and Rojo build. Studio approval must verify:

1. five confirmed enemy deaths produce one level-up and one three-choice offer
2. a killing hit awards only once
3. two clients see the same offer and only one choice commits
4. each upgrade changes only its documented weapon dimension
5. late client state recovery includes the pending offer and current stacks
6. corpse cleanup does not duplicate XP
7. restarting the session resets Field XP and upgrade stacks
8. the XP HUD and choice panel remain readable without obscuring isometric combat
