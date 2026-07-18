# Enemy pressure runtime (P5-0104 – P5-0107)

The production enemy system for Living Kingdoms: one basic horde archetype with a full server-owned lifecycle — fair spawning, roaming, pursuit, melee attacks, death, and cleanup — driven by the mission's authored escalation and a roaming-pressure scheduler with recovery windows, plus the production automatic-combat runtime that lets operatives fight back everywhere, not only in Studio.

## Scope

P5-0104 declares the shared enemy vocabulary, balance configuration, and a pure decision resolver. P5-0105 implements the runtime director that owns every enemy. P5-0106 routes mission escalation and operative automatic combat through the production runtime and retires the Studio-only fixture path from the bootstrap. P5-0107 validates the composed system and its performance bounds.

No special enemy, boss, pathfinding around obstacles, enemy-versus-cover behavior, inventory drop, XP award, or balance completion is introduced. Those remain P6+, P9, and P12 work.

## Authority and trust rules

- The server owns enemy identity, spawning, position simulation, behavior state, targeting intent, health, attacks, death, and cleanup. There is **no enemy remote surface**: clients see enemies only as ordinary server-owned replicated Workspace instances, and every enemy body's network ownership is pinned to the server.
- Enemy melee damage commits through the existing P3 authority chain — `OperativeLifeService.applyAuthoritativeDamage` with a revision check and a deterministic duplicate-protected damage event ID (`enemyattack:<enemyId>:<operativeId>:<timestamp>`). Only `Alive` operatives receive enemy damage; finishing blows against downed operatives are deliberately excluded so revives stay meaningful.
- Operative fire against enemies commits through the director's revisioned health boundary: identity must match, the expected revision must be current, health can never increase, and previously processed ShotIds must be preserved. Stale or forged commits are rejected without state change.
- The client combat request surface is unchanged from LK-0206: `ReloadIntent` remains the only client-to-server combat input, and `CombatPresentation` remains server-to-client disclosure only.

## Shared vocabulary and configuration

`EnemyContracts` (shared) declares the stable IDs and data shapes:

- `EnemyArchetypeId`: `enemy.exclusion_walker` — the only P5 archetype.
- `EnemyBehaviorStateId`: `Roaming`, `Pursuing`, `Attacking`, `StandDown`, `Dead`.
- `EnemySpawnSourceId`: `AuthoredWave`, `RoamingPressure`.
- Spawn rejection reasons (stable first-failure order): `InvalidDefinition`, `DuplicateEntityId`, `PopulationCapReached`, `OutsidePlayableExtent`, `TooCloseToOperative`.
- Behavior rejection reasons: `InvalidFacts`, `InvalidTimestamp`.

`EnemyConfig` (shared) is the single balance home. Prototype values, not promises:

| Value | Prototype |
| --- | ---: |
| Walker health | 45 (faster crowd-clearing time to kill) |
| Pursuit / roam speed | 13 / 7.5 studs per second |
| Detection radius | 110 studs |
| Pursuit-drop radius (hysteresis) | 145 studs |
| Attack range / damage / cooldown | 6 studs / 12 / 1.45 s |
| Fair-spawn minimum distance to any alive operative | 64 studs (inclusive) |
| Deferred-spawn retry interval / queue bound | 2 s / 16 |
| Population caps | 6 per operative, 24 absolute |
| Roaming cadence by escalation level 0–3 | 12 s×2, 10 s×2, 8 s×2, 6 s×3 |
| Recovery window after each authored wave | 8 s |
| Roaming spawn ring | 68–96 studs from a squad anchor |
| Corpse cleanup | 8 s |
| Gameplay visibility radius (darkness engagement bound) | 60 studs |
| Combat evaluation interval / LOS raycast budget | 0.1 s / 3 per operative per pass |
| Enemy evaluation interval | 0.2 s |

Config asserts its own invariants: fairness distance exceeds both the darkness engagement radius and melee range, roaming intervals tighten monotonically with escalation, the spawn ring honors fairness and stays inside the authored world, and the absolute cap covers a four-operative squad.

### Horde Pressure v1 intent

This tuning pass fixes the highest-leverage playtest failure: the world could wait a full minute before adding one roaming enemy, while fair spawns could land outside the walker's detection radius. The revised loop starts contact in roughly twelve seconds, fills the already validated population budget in groups, and places pressure spawns inside detection range. Enemy health is reduced so the denser population creates a satisfying kill rhythm rather than a field of damage sponges.

The pass deliberately does **not** raise the 6-per-operative / 24-absolute cap. Density comes from reaching the current ceiling quickly and refilling losses, preserving the existing worst-case runtime budget until representative Studio profiling supports a higher cap.

## Pure behavior resolution

`EnemyBehaviorResolver` is deterministic, side-effect free, loop free, and randomness free.

`resolveSpawn(request, facts)` judges one proposed spawn in the stable order above. Every fact — existing IDs, active count, population cap, playable extent, alive operative positions — is caller-supplied server truth. Fairness uses horizontal XZ distance with an inclusive boundary: exactly 64 studs is legal, so spawns never appear inside an operative's validated darkness sight or melee reach.

`resolveBehavior(enemy, operatives, serverTimestamp)` returns one decision:

1. `Dead` and `StandDown` are inert.
2. A current target is retained while alive inside the pursuit-drop radius (hysteresis keeps commitment honest — the threat fact reflects actual intent, not proximity).
3. Otherwise the nearest alive operative inside detection is acquired; exact distance ties break to the lexically smallest operative entity ID, mirroring LK-0203.
4. A target inside melee range makes the enemy `Attacking`; the swing is legal only when the cooldown has elapsed, and its damage event is derived entirely from enemy identity, target identity, configured damage, and the supplied timestamp.

## Enemy director runtime

`EnemyDirectorService` is the server-only owner of every enemy:

- **Spawning:** `spawnEnemy` validates through the resolver against live facts. An authored-wave placement that is merely unfair (an operative stands too close) or over the cap defers into a bounded retry queue and lands once conditions allow; impossible placements (duplicate, invalid, outside the world) are dropped. Roaming proposals never defer — the next interval simply proposes a fresh position.
- **Bodies:** graybox `HumanoidRootPart` + `Humanoid` models with a name/health billboard, spawned under `Workspace.EnemyEntities`, server network ownership.
- **Waves:** `spawnAuthoredWave(waveIndex, definitions)` raises the escalation level monotonically, opens the recovery window, and spawns/defers each definition.
- **Pressure:** `beginOperationPressure` (infiltration) starts level-0 roaming; each authored wave tightens the cadence. Roam spawns anchor on a deterministically rotated alive operative and propose golden-angle ring positions 68–96 studs out, clamped to the world, then pass the same fairness validation. The 110-stud detection radius means accepted pressure spawns become active threats instead of idling beyond awareness. The shortened recovery window pauses roaming around each authored spike without draining urgency. `endOperationPressure` (mission resolution) is the stand-down: spawning stops, pending spawns clear, and every living enemy becomes inert so a resolved squad is not chased through the result screen.
- **Behavior application:** one evaluation pass per configured interval reads operative facts once, applies each enemy's resolver decision (movement intent via `Humanoid:MoveTo`, walk speeds per state, deterministic roam wander), and commits legal attacks through the P3 boundary. A rejected life commit does not consume the attack cooldown.
- **Death and cleanup:** an accepted health commit reaching zero marks the enemy `Dead`, anchors the corpse, frees population capacity, and schedules cleanup on the same evaluation pass — no timers.

Bounded by construction: one heartbeat connection, one evaluation loop, configured population caps (6/12/24 concurrent enemies for 1/2/4 operatives), a bounded deferred queue, zero per-enemy connections, zero timers, zero raycasts, zero remotes, and no randomness (a deterministic sequence counter drives roam identity and headings).

## Production automatic combat

`OperativeCombatRuntimeService` replaces the LK-0207 development harness as the bootstrapped combat owner and runs everywhere. It composes the unchanged pure P2 modules — `TargetCandidateSelector`, `AutomaticFireResolver`, `FirearmHitResolver`, `DamageResolver`, `ReloadResolver` — against director-owned enemies for every operative:

- **Identity:** operative combat entity IDs are the P3 life IDs (`operative.player:<UserId>`), so enemy threat facts and revive coordination address the same operative.
- **Gameplay visibility:** the darkness-bounded prototype provider — a hostile is visible only inside the 60-stud horizontal radius, deliberately shorter than the 80-stud firearm range so darkness, not range, limits engagement. This is the first runtime answer to the P2 "visibility provider" question and remains replaceable by a richer P4-derived provider later.
- **Line of sight:** a bounded budget of 3 raycasts per operative per evaluation covers the nearest visible candidates; unbudgeted candidates fail closed as unsighted this pass. The selected target's raycast result also supplies the authoritative obstruction outcome at fire time.
- **Threat priority:** candidates carry `activelyThreateningOperativeEntityId` straight from server-owned enemy pursuit intent, so the LK-0203 threatening-closest rule now has a production source.
- **Damage:** accepted shots resolve through hit/damage and commit to the director's revisioned enemy health boundary; the enemy's `processedShotIds` set remains the duplicate boundary.
- **Weapons:** production weapons start loaded (12 + 24 reserve prototype values). Reload flow, rate limiting, presentation messages, life-state restrictions, and character-replacement generations match the harness behavior exactly.
- **Revive coordination:** `readReviveCombatState`/`commitReviveCombatState` move to this service, so `OperativeReviveSessionService` completes revives in production — previously impossible outside Studio.

`AutomaticCombatDevelopmentHarness` remains a Studio-only manual diagnostic (command-bar `start()`), is no longer bootstrapped, and no longer owns mission hostiles. Both connect the same `ReloadIntent` remote, so stop the production runtime before starting the harness manually.

## Mission integration

`MissionDirectorService` now drives the director: infiltration calls `beginOperationPressure`, each escalation wave calls `spawnAuthoredWave` with the authored `MissionConfig` positions, and resolution calls `endOperationPressure`. The wave-3 positions were retuned to sit outside the fair-spawn floor around the extraction zone so the holdout wave spawns immediately and pursues in rather than deferring while the squad holds the center; `MissionContracts` fixtures enforce this cross-config invariant.

## Validation

Run from the repository root:

- `lune run games/living-kingdoms/tests/EnemyContracts.test.luau` — vocabulary stability, balance invariants, representative 1/2/4 population caps, cadence coverage.
- `lune run games/living-kingdoms/tests/EnemyBehaviorResolver.test.luau` — fair-spawn ordering and boundaries, detection, hysteresis, tie-breaks, attack range/cooldown legality, inert states, determinism, immutability.
- `lune run games/living-kingdoms/tests/EnemyDirectorService.test.luau` — spawn lifecycle, deferral and retry, waves, roaming cadence and recovery windows, pursuit intent, authoritative attacks, the health commit boundary, death and corpse cleanup, stand-down, performance bounds, teardown.
- `lune run games/living-kingdoms/tests/OperativeCombatRuntimeService.test.luau` — darkness visibility, the raycast budget, threat priority, the fire→hit→damage→death pipeline, reload validation, life restrictions, the revive boundary, teardown, and source audits.
- `lune run games/living-kingdoms/tests/P5IntegrationValidation.test.luau` — the real mission director driving the real enemy director end-to-end, holdout spawn fairness, stand-down on success and on squad wipe, connection counts, and remote-surface audits.
- All prior fixtures, StyLua, Selene (`games/living-kingdoms/src`), `rojo sourcemap`, and `rojo build` must continue to pass.

A live multiplayer Studio playthrough of the full pressure loop — walkers visibly roaming, pursuing, attacking, dying to automatic fire, waves landing around the authored beats, and the holdout climax — remains the outstanding manual check and is scripted in the smoke test.

## Known limitations and future extension points

- Movement is straight-line `Humanoid:MoveTo` intent; there is no pathfinding, so walkers can be blocked by dense obstacles. Acceptable for the graybox forest; revisit when a playtest demonstrates the need.
- Enemies never attack `Incapacitated` operatives, and melee obstruction is not raycast-checked (a 6-stud swing through a wall is theoretically possible). Both are deliberate simplifications.
- The darkness visibility provider is a plain radius; flashlight cones, lighting state, and P4 perception do not yet feed operative targeting or enemy detection.
- Stand-down is terminal per operation; replay/reset flow is P10.
- One archetype, no special enemy (P9), no drops or XP (P6/P11), placeholder graybox bodies and billboard health text.
