# Automatic Combat Contracts

**Status:** Canonical contract specification

**Tasks:** LK-0201, LK-0202, LK-0203, LK-0204, LK-0205, LK-0206

**Runtime behavior:** Pure server candidate-validation, target-selection, automatic-fire, hit-resolution, damage, and reload transitions; focused client reload/presentation controller; Studio-only reload integration harness

## Scope

This specification defines the smallest shared vocabulary required for the P2 automatic-combat pipeline. LK-0201 declared data shapes, stable IDs, authority, trust boundaries, and prototype firearm balance homes. LK-0202 adds validation of exactly one server-derived candidate. LK-0203 adds deterministic selection from a caller-provided candidate list. LK-0204 adds a pure server-owned automatic-fire decision and weapon-state transition for one already selected target. LK-0205 adds pure server-owned hit revalidation and damage transitions for one accepted shot. LK-0206 adds pure server-owned reload transitions and a focused local reload/presentation boundary. These functions do not discover hostiles, retain hidden global state, run a production combat loop, or implement enemy behavior.

Manual priority-target override and authored scarcity pickups remain deferred. LK-0206 does not add an `AimController`, `CombatSystem`, `EngagementSystem`, enemy, weapon instance, production health change, or generic networking framework.

## Canonical pipeline

Hostile discovery → Candidate validation → Deterministic priority selection → Automatic-fire readiness decision → Server-authoritative fire resolution → Hit and damage resolution → Non-authoritative client presentation

Each arrow crosses an explicit data boundary, not an event bus or service requirement. Later tasks may implement the smallest module needed for their stage.

## Authority and trust rules

- The server owns entity identity, team membership and hostility, operative state, hostile eligibility, gameplay visibility, line of sight, range, weapon readiness, cadence, ammunition, target validation, target selection or confirmation, hits, damage, and authoritative timestamps.
- A client may read only combat state the server deliberately discloses. Hidden candidates and undisclosed tactical state must not be replicated merely because a shared type exists.
- A client may predict a likely target or firing feedback only for immediate presentation. Prediction cannot consume ammunition, establish a legal target or hit, change health, or become authoritative through later echoing.
- Never accept a client-supplied target, hit, damage value, ammunition total, cadence state, or timestamp as truth.
- `ReloadIntent` is the minimal player-directed input: the client may identify only the equipped weapon it wants to reload. The server derives eligibility, ammunition movement, duration, interruption, and completion. The remote accepts no client timestamp, ammunition, capacity, duration, completion time, state table, target, hit, or damage.
- Server timestamps use one server-owned monotonic time domain. Clients may use disclosed timestamps to align presentation but may not submit timestamps for validation.

## Stable identifiers

- `CombatEntityId` uniquely identifies one server-known operative or hostile for its authoritative lifetime. Generation, persistence across respawn, and reuse policy are deferred until entities exist; clients cannot mint accepted IDs.
- `CombatEntityKindId` is `Operative` or `Hostile`.
- `CombatTeamId` identifies a server-owned team or faction. `TeamRelationshipId` is the server-derived relationship `Friendly`, `Hostile`, or `Neutral`; team IDs alone do not authorize damage.
- `WeaponId` identifies a weapon definition. The first stable ID is `weapon.basic_firearm`.
- `OperativeCombatStateId` is `Ready`, `Reloading`, `Incapacitated`, `Dead`, or `Disabled`.
- `WeaponReadinessStateId` is `Ready`, `CadenceBlocked`, `Reloading`, `Empty`, or `Disabled`.
- `DamageTypeId` begins with `Ballistic`. Damage types describe resolution semantics; clients cannot select them.
- `ShotId` and `DamageEventId` correlate server results with presentation and diagnostics. The server creates both.

## Contract ownership and first consumer

| Contract | Purpose | Authority | Client read/prediction | Never accept from client | First consumer |
| --- | --- | --- | --- | --- | --- |
| Stable ID tables | Shared vocabulary for entities, relationships, states, rejection reasons, selection reasons, damage, and presentation | Server assigns consequential IDs | May read disclosed IDs and branch presentation | Entity/team/weapon/state assignment | LK-0202 |
| `AmmunitionState` | Loaded, reserve, and capacity snapshot for one weapon | Server | May read a disclosed snapshot; may animate predicted feedback without mutation | Any ammunition count or capacity | LK-0202 for eligibility; LK-0204 for consumption |
| `WeaponCadenceState` | Last and next legal server fire time | Server | May read disclosed timing for presentation | Client time, last-fire time, or next-fire time | LK-0204 |
| `WeaponReadinessState` | Combines readiness, ammunition, and cadence state | Server | May read disclosed readiness; may not turn prediction into fire | Readiness, ammunition, or cadence | LK-0202 |
| `TargetCandidate` | Server-derived facts needed to judge and prioritize one possible hostile, including the exact operative it actively threatens when applicable | Server | Must not receive hidden candidates; may mirror only disclosed facts for likely-target presentation | Candidate identity, distance, relationship, visibility, line of sight, threat, life, or targetability | LK-0202 |
| `TargetValidationResult` | Deterministic legal/illegal result and rejection reason | Server | May read a disclosed result for presentation/debugging | Validity or rejection reason | LK-0202 |
| `SelectedTargetState` | Current authoritative target and deterministic selection reason | Server | May present a disclosed selection | Target identity, selection reason, or selection time | LK-0203 |
| `AutomaticFireDecision` | Whether the server may fire now with a selected target | Server | May predict animation timing only | Decision, target, rejection reason, weapon, or evaluation time | LK-0204 |
| `AuthoritativeFireResult` | Accepted/rejected shot result, authoritative ammunition, and optional hit correlation | Server | May drive disclosed firing presentation | Shot ID, status, ammunition, target, hit, or timestamp | LK-0204; hit fields first resolved in LK-0205 |
| `AuthoritativeDamageEvent` | Immutable description of server-resolved damage | Server | May drive disclosed damage presentation | Source, target, shot, weapon, type, amount, or timestamp | LK-0205 |
| `ReloadIntent` | Minimal player request to reload the equipped weapon | Client requests; server decides | Client originates weapon intent and may predict presentation | Eligibility, ammunition transfer, duration, completion, interruption, or time | LK-0206 |
| `CombatPresentationMessage` | Disclosed target, shot, and reload events for non-authoritative feedback | Server curates; client presents | May drive immediate presentation | Messages may never be treated as target, hit, ammo, or damage authority | LK-0206 |

## Target eligibility

LK-0202 returns a deterministic `TargetValidationResult` for exactly one operative and one server-derived candidate. The validator does not prove input provenance; its caller must obtain operative, relationship, hostile, visibility, line-of-sight, position, ammunition, and readiness facts from server-owned systems. Remote payloads and client-authored attributes are not valid sources.

A candidate is valid only when all checks pass in this stable first-failure order:

1. The operative combat state permits combat.
2. The server-derived relationship is `Hostile`.
3. The hostile is alive.
4. The hostile is targetable.
5. Gameplay visibility rules mark the hostile visible to the operative.
6. A server line-of-sight test passes independently of visibility.
7. Horizontal XZ distance from the operative to the hostile is within the equipped weapon range.
8. Server-owned loaded ammunition is available.
9. Server-owned weapon readiness permits consideration.

The first failed check returns its canonical LK-0201 rejection ID: `OperativeStateInvalid`, `RelationshipNotHostile`, `HostileDead`, `HostileUntargetable`, `NotVisible`, `NoLineOfSight`, `OutOfRange`, `NoAmmunition`, or `WeaponNotReady`. These canonical IDs correspond to the more descriptive task vocabulary without adding duplicates.

Visibility and line of sight are separate. Visibility determines whether the operative is allowed to know and engage the hostile; line of sight determines whether an unobstructed legal shot exists. A client rendering a hostile or reporting an unobstructed view satisfies neither rule.

## LK-0202 range and execution policy

The first isometric prototype measures weapon range on the horizontal XZ plane. Vertical separation does not alter the engagement radius. `TargetCandidateValidator` computes the squared horizontal distance from server-derived positions and compares it with the squared `FirearmConfig.BasicFirearm.RangeStuds`; it does not trust the candidate's stored `distanceStuds` field as an independent authority.

The maximum-range boundary is inclusive: exactly `80` horizontal studs and values just inside are valid, while any value just outside is `OutOfRange`. Squared comparison avoids an unnecessary square root without changing the boundary.

`TargetCandidateValidator.validate(operative, candidate)` is deterministic and side-effect free. It validates only the configured basic firearm, creates no discovery or selection state, runs no loop, performs no raycast, and mutates no input or gameplay state. Visibility and line of sight remain separate server-derived booleans. Their provider implementations, including visibility discovery and raycast filtering, remain deferred.

## Threatening-hostile definition and priority

A valid hostile is **actively threatening the operative** only when server-owned hostile state says it is currently pursuing, attacking, or committed to an attack whose intended victim is that operative. Proximity, facing, client observation, or membership in a wave alone is insufficient.

`TargetCandidate.activelyThreateningOperativeEntityId` is the minimum server-derived intent signal used by LK-0203. It contains the intended operative's `CombatEntityId` only while the hostile is pursuing, attacking, or committed to an attack against that operative; otherwise it is `nil`. It must not be populated from proximity, facing, visibility alone, wave membership, client observation, damage presentation, or a generic hostile flag. The earlier generic `isActivelyThreatening` field remains in the shared shape for backward compatibility but does not establish operative-specific threat and is ignored by the selector.

`TargetCandidateSelector.select(operative, candidates)` validates every caller-provided candidate through `TargetCandidateValidator` and selects at most one target in this order:

1. The valid candidate actively threatening this exact operative with the shortest horizontal XZ distance.
2. If no valid candidate threatens this operative, the valid candidate with the shortest horizontal XZ distance.
3. If multiple candidates in the applicable priority group have exactly equal squared distances, the candidate with the lexically smallest `CombatEntityId`.

Selection recomputes squared horizontal XZ distance from the server-derived operative and candidate positions. It never trusts `distanceStuds` as authority. Distances use exact Luau number comparisons with no epsilon: a smaller squared value wins, and exact numeric equality reaches the ID tie-break. This keeps comparison transitive and input-order independent. The validator's inclusive maximum-range rule remains authoritative, so a candidate exactly at maximum range is eligible.

The function returns a `SelectedTargetState` marked `isValid = true` using canonical reason `ThreateningClosest` or `ValidClosest`. The returned target ID is non-optional and `selectedAtServerTimestamp` is `nil` because this pure selection step does not read or create authoritative time. The validity flag records the authoritative caller's current representation; callers must set it false when later server-owned facts invalidate a retained selection. When no candidate validates, selection returns `nil` rather than a retained or cleared selection state. Every call is independent: there is no target persistence, target-switch hysteresis, reacquisition cache, randomness, or input mutation. Safe target loss therefore produces `nil`, and a later call may reacquire solely from its current inputs. Manual priority override and sticky targeting remain deferred.

## Fire readiness, cadence, and ammunition

`AutomaticFireResolver.resolve(operativeState, selectedTarget, weaponState, serverTimestamp)` evaluates one authoritative attempt and returns an `AutomaticFireResolution` containing the canonical `AutomaticFireDecision`, `AuthoritativeFireResult`, and a new `WeaponReadinessState`. The caller must supply server-owned state, use a monotonic server time source, and commit the returned weapon state before resolving another attempt. The resolver has no global state, does not mutate its inputs, runs no loop, and accepts at most one shot per call.

The stable first-failure rejection order is:

1. Operative combat state is not `Ready`: `OperativeStateInvalid`.
2. No `SelectedTargetState` exists: `NoSelectedTarget`.
3. The selection is not marked valid by the authoritative caller, has no target ID, or names a different operative: canonical `SelectedTargetInvalid`.
4. The weapon, ammunition, or cadence weapon ID is not the configured basic firearm, or weapon readiness is not `Ready`: `WeaponNotReady`.
5. Loaded ammunition is zero or less: `NoAmmunition`.
6. The server timestamp is earlier than `nextAllowedFireServerTimestamp`: `CadenceBlocked`.

`SelectedTargetInvalid` is the canonical contract ID for the task's “TargetInvalid” vocabulary. Every non-`Ready` weapon readiness state, including `CadenceBlocked`, `Reloading`, `Empty`, and `Disabled`, returns `WeaponNotReady`; `CadenceBlocked` as an automatic-fire rejection is derived independently from the authoritative cadence timestamp. A rejected decision creates no shot, preserves ammunition and cadence timestamps, and returns an unchanged-value weapon-state copy. Repeated calls with the same blocked state therefore produce the same rejection.

Exactly `nextAllowedFireServerTimestamp` is legal; any representable timestamp just before it is blocked. An accepted shot sets `lastFireServerTimestamp` to the evaluated server timestamp and sets `nextAllowedFireServerTimestamp` to that timestamp plus `FirearmConfig.BasicFirearm.CadenceSeconds`. Cadence advances from the current authoritative fire time, never from the previous deadline, so long elapsed intervals do not create catch-up bursts. Client timestamps are not an API source and must never be forwarded as `serverTimestamp`.

An accepted shot consumes exactly one loaded round, preserves reserve rounds and magazine capacity, and includes the selected target ID. The last loaded round may fire and reaches zero; another attempt with zero loaded rounds is rejected. Prototype initial loaded and reserve values remain temporary P2 test configuration, not P6 scarcity completion.

LK-0204 creates a deterministic `ShotId` as `shot:<operativeEntityId>:<weaponId>:<serverTimestamp>`. This is server-owned because the resolver has no ShotId input. It is intentionally temporary: uniqueness depends on the authoritative caller committing the returned cadence state and not accepting two shots for the same operative, weapon, and timestamp. Persistent identity, cross-server uniqueness, and respawn lifetime policy remain deferred until a runtime combat owner requires them.

`AuthoritativeFireResult.didHit` and `hitEntityId` remain `nil` for both accepted and rejected LK-0204 results. Firing does not determine a miss, perform obstruction or hit checks, or apply damage. Those behaviors begin in LK-0205.

The client directly chooses reload timing through `ReloadIntent`, but the server owns whether reload begins, how reserve ammunition moves into the magazine, its duration, interruption, and completion. Scarcity pickups and final operation ammunition tuning belong to P6.

## Reload begin, completion, and interruption

`ReloadResolver.begin(operativeState, weaponState, serverTimestamp)` and `ReloadResolver.complete(operativeState, weaponState, serverTimestamp)` are deterministic, side-effect-free state transitions. Their caller supplies and commits server-owned operative and weapon state and uses a monotonic server timestamp. Both functions return copied state and leave their inputs unchanged.

Reload begins only when all of these conditions pass in stable first-failure order:

1. Operative state is `Ready`; otherwise `OperativeStateInvalid`.
2. The configured basic firearm is equipped and all weapon/ammunition/cadence IDs and configured magazine capacity agree; otherwise `WeaponInvalid`.
3. No reload is already represented by readiness or reload timing; otherwise `AlreadyReloading`.
4. Weapon readiness is `Ready`; otherwise `WeaponNotReady`.
5. Loaded rounds are below magazine capacity; otherwise `MagazineFull`.
6. Reserve rounds are greater than zero; otherwise `NoReserveAmmunition`.

An accepted begin preserves ammunition and cadence, changes operative and weapon readiness to `Reloading`, records the configured weapon ID, and derives `completionServerTimestamp = serverTimestamp + FirearmConfig.BasicFirearm.ReloadDurationSeconds`. The configured duration is initially `2` seconds. A client timestamp, duration, eligibility claim, or completion claim is never an input.

Completion requires an active reload for the configured weapon. Any server timestamp before the completion timestamp returns `ReloadNotComplete` and preserves state; exactly the completion timestamp is legal. A successful completion transfers:

`min(magazineCapacity - loadedRounds, reserveRounds)`

Loaded rounds increase and reserve rounds decrease by exactly the same amount. Capacity and cadence remain unchanged, existing loaded rounds are never discarded, and the reload timing is cleared. A second completion returns `ReloadNotInProgress`, so ammunition cannot transfer twice.

The initial interruption policy is intentionally narrow. Incapacitation, death, weapon disablement, or changing the equipped weapon interrupts reload, clears reload timing, and transfers no ammunition. Rejected and interrupted transitions preserve loaded and reserve totals. Movement does not interrupt reload. Taking damage alone does not interrupt reload. Final scarcity, pickups, switching behavior, and additional weapon families remain deferred.

## Hit revalidation, obstruction, and miss policy

`FirearmHitResolver.resolve(acceptedFireResult, shotContext, targetContext)` resolves one already accepted LK-0204 shot against one current authoritative target snapshot. The caller must provide server-owned operative and target positions, identity, relationship, life, targetability, gameplay visibility, and an obstruction result. The resolver does not discover or select a target, decide whether fire is allowed, consume ammunition, advance cadence, perform a raycast, or mutate input state.

Hit validation uses this stable first-failure order:

1. The fire result is `Fired` and its hit fields remain unresolved: otherwise `FireNotAccepted`.
2. The fire result has a nonempty operative ID, selected target ID, fired timestamp, and the deterministic server-owned LK-0204 `ShotId`; the shot context names the same operative: otherwise `MissingShotIdentity`.
3. The fire result and shot context name `FirearmConfig.BasicFirearm.WeaponId`: otherwise `WeaponInvalid`.
4. The current target and shot context both match the selected target ID: otherwise `TargetMismatch`.
5. The current target is alive: otherwise `TargetDead`.
6. The current target is targetable: otherwise `TargetInvalid`.
7. The current server-derived relationship is `Hostile`: otherwise `TargetNotHostile`.
8. Current gameplay visibility is true: otherwise `NotVisible`.
9. Current horizontal XZ distance is within configured range: otherwise `OutOfRange`.
10. The authoritative obstruction outcome is resolved: `Blocked` returns `LineOfSightBlocked`, `Miss` returns `Miss`, and `TargetHit` succeeds.

Revalidation deliberately occurs after the fire decision because current target facts may differ from the earlier candidate and selection snapshots. Range is recomputed from the current server-owned positions; prior `TargetCandidate.distanceStuds` is not an input. It uses the same horizontal XZ squared-distance policy and inclusive configured maximum as LK-0202, so exactly `80` studs remains legal.

`ShotResolutionContext.obstructionResultId` is the single initial obstruction/hit input boundary. It must be produced by authoritative server code and is limited to `TargetHit`, `Blocked`, or `Miss`. For the basic firearm, a legal `TargetHit` outcome means the selected target was unobstructed and resolves as a hit. `Blocked` represents failed server-confirmed line of sight, while `Miss` represents an explicit authoritative miss. The resolver accepts no hit part, hit position, client raycast result, visibility claim, target choice, or damage value. Raycast implementation and filtering remain deferred until runtime integration needs them.

The initial model has no penetration, ricochet, spread, critical hit, body-part multiplier, armor, splash damage, projectile, or bullet simulation behavior.

## Authoritative damage transition and duplicate boundary

`DamageResolver.resolve(hitResolution, targetHealthState, serverTimestamp)` returns a new `DamageResolution` without mutating its inputs. A successful hit against the matching health-state entity subtracts exactly `FirearmConfig.BasicFirearm.DamagePerHit`, clamps health to zero, and returns a frozen `AuthoritativeDamageEvent`. The event's weapon ID, `Ballistic` damage type, amount, source, target, shot, and authoritative timestamp are derived only from server-owned resolver inputs and configuration. No client damage amount, type, target, or timestamp is accepted.

A successful transition reports `becameDead = true` only when this damage moves positive health to zero. A nonlethal hit reports false. A miss, blocked shot, rejected hit, or mismatched target creates no damage event and preserves health. LK-0205 does not call `Humanoid:TakeDamage` and adds no incapacitation, revival, death presentation, loot, XP, or progression behavior.

`TargetHealthState.processedShotIds` is the temporary caller-owned duplicate boundary. `DamageResolver` copies it, marks the accepted `ShotId` terminal on the first damage-resolution pass even when that shot missed or was rejected during revalidation, and returns the copy in `targetHealthStateAfter`. The caller must atomically commit that returned state before processing another resolution. A committed duplicate returns `ShotAlreadyResolved`, creates no second damage event, and preserves health. There is no hidden global or persistent deduplication service. Ownership, atomic commit, cleanup, memory bounds, cross-server behavior, and lifetime across respawn remain limitations for the future runtime combat owner to resolve.

## Prototype firearm configuration

`FirearmConfig.BasicFirearm` is the shared balance home for the first firearm family:

| Value | Prototype |
| --- | ---: |
| Weapon ID | `weapon.basic_firearm` |
| Damage type | `Ballistic` |
| Range | 80 studs |
| Cadence | 0.2 seconds per shot |
| Magazine capacity | 12 rounds |
| Initial loaded rounds | 12 |
| Temporary initial reserve | 24 rounds |
| Reload duration | 2 seconds |
| Damage per hit | 20 |

These are prototype values, not a balance promise. Temporary initial ammunition exists only to support P2 combat verification and must not be mistaken for P6 scarcity completion.

## Reload intent and presentation networking

`ReplicatedStorage.CombatNetwork.ReloadIntent` is the single client-to-server combat request added by LK-0206. Its only payload is one `WeaponId`. Roblox supplies the sending `Player`; the server maps that player to server-owned operative and equipped-weapon state, rejects extra arguments or the wrong weapon ID, rate-limits requests, and derives all consequential values. The local controller also applies a `0.5`-second request cooldown so held or repeated `R` input cannot create uncontrolled requests.

`ReplicatedStorage.CombatNetwork.CombatPresentation` is server-to-client only. It carries explicit `TargetSelected`, `TargetCleared`, `ShotFired`, `ReloadStarted`, `ReloadCompleted`, or `ReloadInterrupted` messages. Reload messages disclose only the configured weapon ID and, for start, the server-owned completion timestamp; they do not disclose or accept ammunition state. Target and shot messages retain the small canonical IDs and timestamps already declared.

The server may send a target or shot message only after that target is safe to disclose to that specific player. The client does not poll, predict, or search for hostiles. `WeaponController` creates a small highlight only after `TargetSelected`, destroys it on `TargetCleared`, never creates a target indicator from a shot or unknown message, and presents each disclosed ShotId at most once. It uses temporary status text for shot and reload events. Presentation never spends ammunition, changes reload state, selects targets, establishes hits, applies damage, changes health, or creates damage numbers, health bars, hit markers, or a permanent HUD.

## Temporary runtime boundary

There is still no production owner for automatic-combat discovery, selection, firing, ammunition, hits, damage, or reload scheduling. `ReloadDevelopmentHarness` runs only when `RunService:IsStudio()` and owns isolated per-player prototype reload state so the explicit reload and presentation remotes can be exercised. It initializes a partially loaded configured firearm, validates the sending player and equipped weapon, uses server time, and schedules only reload completion. It creates no hostile, target-selection poll, fire loop, hit, damage, health, AI, or production ammunition truth. Outside Studio the harness does not connect the reload remote; the future production combat owner must adopt the pure resolver and remote boundary rather than treating this harness as runtime integration.

## Unresolved design questions

- Combat-entity ID generation, lifetime across respawn, and reuse policy.
- Team/faction assignment and relationship lookup source.
- The gameplay visibility provider and exact runtime raycast/filtering implementation behind the authoritative obstruction boundary.
- Target-switch hysteresis or other sticky-target behavior, if playtesting later demonstrates a need.
- Runtime health ownership and atomic processed-ShotId commit/cleanup policy.
- Final weapon values, ammunition scarcity, and supply ownership after P2 prototypes.

Each question is resolved by the first later task that needs the answer. None authorizes speculative runtime code in LK-0201.
