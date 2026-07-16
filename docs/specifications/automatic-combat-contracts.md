# Automatic Combat Contracts

**Status:** Canonical contract specification

**Tasks:** LK-0201, LK-0202, LK-0203

**Runtime behavior:** Pure server candidate-validation and target-selection functions; no runtime bootstrap integration

## Scope

This specification defines the smallest shared vocabulary required for the P2 automatic-combat pipeline. LK-0201 declared data shapes, stable IDs, authority, trust boundaries, and prototype firearm balance homes. LK-0202 adds validation of exactly one server-derived candidate. LK-0203 adds deterministic selection from a caller-provided candidate list. Neither function discovers hostiles, retains target state, fires weapons, applies damage, adds remotes, or presents combat.

Manual priority-target override and authored scarcity pickups remain deferred. No `AimController`, `WeaponController`, `CombatSystem`, `EngagementSystem`, enemy, weapon instance, health change, or networking behavior is created by LK-0201.

## Canonical pipeline

Hostile discovery → Candidate validation → Deterministic priority selection → Automatic-fire readiness decision → Server-authoritative fire resolution → Hit and damage resolution → Non-authoritative client presentation

Each arrow crosses an explicit data boundary, not an event bus or service requirement. Later tasks may implement the smallest module needed for their stage.

## Authority and trust rules

- The server owns entity identity, team membership and hostility, operative state, hostile eligibility, gameplay visibility, line of sight, range, weapon readiness, cadence, ammunition, target validation, target selection or confirmation, hits, damage, and authoritative timestamps.
- A client may read only combat state the server deliberately discloses. Hidden candidates and undisclosed tactical state must not be replicated merely because a shared type exists.
- A client may predict a likely target or firing feedback only for immediate presentation. Prediction cannot consume ammunition, establish a legal target or hit, change health, or become authoritative through later echoing.
- Never accept a client-supplied target, hit, damage value, ammunition total, cadence state, or timestamp as truth.
- `ReloadIntent` is the minimal future player-directed input: the client may identify the equipped weapon it wants to reload. The server must derive eligibility, ammunition movement, duration, interruption, and completion. LK-0201 declares no remote.
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
| `ReloadIntent` | Minimal future player request to reload the equipped weapon | Client requests; server decides | Client originates weapon intent and may predict presentation | Eligibility, ammunition transfer, duration, completion, interruption, or time | LK-0206 |
| `CombatPresentationMessage` | Disclosed target and shot events for non-authoritative feedback | Server curates; client presents | May drive immediate presentation | Messages may never be treated as target, hit, ammo, or damage authority | LK-0206 |

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

The function returns a `SelectedTargetState` using canonical reason `ThreateningClosest` or `ValidClosest`. The returned target ID is non-optional and `selectedAtServerTimestamp` is `nil` because this pure selection step does not read or create authoritative time. When no candidate validates, it returns `nil` rather than a retained or cleared selection state. Every call is independent: there is no target persistence, target-switch hysteresis, reacquisition cache, randomness, or input mutation. Safe target loss therefore produces `nil`, and a later call may reacquire solely from its current inputs. Manual priority override and sticky targeting remain deferred.

## Fire readiness, cadence, and ammunition

Automatic fire requires a selected target that remains valid, operative state `Ready`, weapon readiness `Ready`, at least one loaded round, and a server timestamp at or after `nextAllowedFireServerTimestamp`. A successful server fire consumes exactly one loaded round and advances cadence in the same authoritative decision. Rejected decisions consume nothing.

The client directly chooses reload timing through a future `ReloadIntent`, but the server owns whether reload begins, how reserve ammunition moves into the magazine, its duration, interruption, and completion. Scarcity pickups and final operation ammunition tuning belong to P6.

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

## Presentation boundary

`TargetSelected`, `TargetCleared`, and `ShotFired` are the only declared presentation message kinds. They are type declarations, not remotes. The server must disclose them only when doing so does not reveal hidden hostiles. A client may respond with facing, muzzle, tracer, sound, or UI feedback in LK-0206, but the corresponding authoritative fire result and damage event remain server truth.

## Unresolved design questions

- Combat-entity ID generation, lifetime across respawn, and reuse policy.
- Team/faction assignment and relationship lookup source.
- The gameplay visibility provider and exact line-of-sight raycast policy.
- Target-switch hysteresis or other sticky-target behavior, if playtesting later demonstrates a need.
- Reload interruption rules and whether a partially completed reload has any effect.
- Hit model, obstruction filtering, body-part treatment, and damage application order.
- Final weapon values, ammunition scarcity, and supply ownership after P2 prototypes.

Each question is resolved by the first later task that needs the answer. None authorizes speculative runtime code in LK-0201.
