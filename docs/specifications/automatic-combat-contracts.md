# Automatic Combat Contracts

**Status:** Canonical contract specification

**Task:** LK-0201

**Runtime behavior:** None

## Scope

This specification defines the smallest shared vocabulary required for the P2 automatic-combat pipeline. It declares data shapes, stable IDs, authority, trust boundaries, and prototype firearm balance homes. It does not discover hostiles, validate candidates, select targets, fire weapons, apply damage, add remotes, or present combat.

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
| `TargetCandidate` | Server-derived facts needed to judge one possible hostile | Server | Must not receive hidden candidates; may mirror only disclosed facts for likely-target presentation | Candidate identity, distance, relationship, visibility, line of sight, threat, life, or targetability | LK-0202 |
| `TargetValidationResult` | Deterministic legal/illegal result and rejection reason | Server | May read a disclosed result for presentation/debugging | Validity or rejection reason | LK-0202 |
| `SelectedTargetState` | Current authoritative target and deterministic selection reason | Server | May present a disclosed selection | Target identity, selection reason, or selection time | LK-0203 |
| `AutomaticFireDecision` | Whether the server may fire now with a selected target | Server | May predict animation timing only | Decision, target, rejection reason, weapon, or evaluation time | LK-0204 |
| `AuthoritativeFireResult` | Accepted/rejected shot result, authoritative ammunition, and optional hit correlation | Server | May drive disclosed firing presentation | Shot ID, status, ammunition, target, hit, or timestamp | LK-0204; hit fields first resolved in LK-0205 |
| `AuthoritativeDamageEvent` | Immutable description of server-resolved damage | Server | May drive disclosed damage presentation | Source, target, shot, weapon, type, amount, or timestamp | LK-0205 |
| `ReloadIntent` | Minimal future player request to reload the equipped weapon | Client requests; server decides | Client originates weapon intent and may predict presentation | Eligibility, ammunition transfer, duration, completion, interruption, or time | LK-0206 |
| `CombatPresentationMessage` | Disclosed target and shot events for non-authoritative feedback | Server curates; client presents | May drive immediate presentation | Messages may never be treated as target, hit, ammo, or damage authority | LK-0206 |

## Target eligibility

LK-0202 must return a deterministic `TargetValidationResult`. A candidate is valid only when all checks pass:

1. The operative combat state permits combat.
2. The server-derived relationship is `Hostile`.
3. The hostile is alive and targetable.
4. Gameplay visibility rules mark the hostile visible to the operative.
5. A server line-of-sight test passes independently of visibility.
6. Server-computed distance, using the policy finalized by LK-0202, is within the equipped weapon range.
7. Server-owned ammunition is available.
8. Server-owned weapon readiness permits consideration.

Visibility and line of sight are separate. Visibility determines whether the operative is allowed to know and engage the hostile; line of sight determines whether an unobstructed legal shot exists. A client rendering a hostile or reporting an unobstructed view satisfies neither rule.

## Threatening-hostile definition and priority

A valid hostile is **actively threatening the operative** only when server-owned hostile state says it is currently pursuing, attacking, or committed to an attack whose intended victim is that operative. Proximity, facing, client observation, or membership in a wave alone is insufficient.

LK-0203 selects the closest valid actively threatening hostile first. If none exists, it selects the closest valid hostile in range. Tie behavior must be deterministic and will be finalized with selection implementation; a manual priority-target override remains deferred.

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
- The server-owned hostile intent signal used to establish active threat.
- Whether range is measured in full 3D or on the horizontal plane.
- Deterministic equal-distance tie-breaking and target-switch stability.
- Reload interruption rules and whether a partially completed reload has any effect.
- Hit model, obstruction filtering, body-part treatment, and damage application order.
- Final weapon values, ammunition scarcity, and supply ownership after P2 prototypes.

Each question is resolved by the first later task that needs the answer. None authorizes speculative runtime code in LK-0201.
