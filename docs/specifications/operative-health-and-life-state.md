# Operative Health and Life-State Specification

**Status:** Canonical initial P3 specification

**Planning task:** LK-P3-PLAN-001

**Implementation tasks:** LK-0301 through LK-0308

**Runtime behavior:** Pure, unintegrated operative damage transitions through LK-0302

## Scope

P3 defines the smallest server-owned model for operative health, incapacitation, revival, unrecoverable death, and squad failure. It turns the milestone into ordered, testable implementation work without adding a general state-machine framework or beginning runtime implementation.

The canonical life-state vocabulary is exactly `Alive`, `Incapacitated`, and `Dead`. Reloading, weapon readiness, movement, interaction, and operation phase are related state owned by their respective systems; they are not additional life states.

## Authority

- The server owns maximum and current health, life state, damage application, incapacitation and bleed-out timestamps, finishing damage, revive eligibility and progress, solo recovery use, death, the active-operative roster, and squad failure.
- A client may request a revive interaction for its own operative and may present only state deliberately disclosed by the server. It cannot choose the target's eligibility, distance, line of sight, duration, progress, restored health, interruption, completion, or recovery result.
- Server timestamps use one monotonic server time domain. A client timestamp is never an authority input.
- Character physics or Roblox network ownership does not make a client authoritative over distance, movement restrictions, health, life state, or interaction continuity.
- Health and life-state balance values belong in shared configuration. Consequential transitions remain server-only.

## Shared LK-0301 declarations

`src/shared/Health/OperativeLifeContracts.luau` is the declaration-only home for the P3 domain. Its `OperativeLifeStateIds` table contains exactly `Alive`, `Incapacitated`, and `Dead`. It also freezes stable transition-rejection and revive-status/rejection ID tables while leaving runtime snapshots mutable for future pure resolvers to copy and return.

The initial stable rejection/status vocabulary is intentionally bounded:

- Operative life transition rejections: `InvalidSnapshot`, `InvalidHealth`, `InvalidDamage`, `InvalidServerTimestamp`, `IllegalTransition`, `StaleTransition`, and `AlreadyResolved`.
- Revive session statuses: `Active`, `Cancelled`, and `Completed`.
- Revive rejections: `ReviverNotAlive`, `TargetNotIncapacitated`, `SameOperative`, `TargetBusy`, `OutOfRange`, `NoLineOfSight`, `SessionNotActive`, `ReviveNotComplete`, `ReviveInterrupted`, and `InvalidServerTimestamp`.

These status values are revive-session state, not additional operative life states. Reloading, reviving, disabled, respawning, extracted, and spectating remain outside the operative life-state vocabulary.

`src/shared/Config/OperativeLifeConfig.luau` is the single canonical initial P3 configuration home:

| Value | Initial setting |
| --- | ---: |
| `MaximumHealth` | `100` |
| `BleedOutDurationSeconds` | `30` |
| `ReviveRangeStuds` | `8` |
| `ReviveDurationSeconds` | `4` |
| `ReviveHealth` | `30` |
| `SoloRecoveryDurationSeconds` | `8` |
| `SoloRecoveriesPerOperation` | `1` |
| `SquadFailureGraceSeconds` | `3` |

The configuration module asserts that health, durations, and range are finite and positive; revive health does not exceed maximum health; and the solo allowance is exactly the integer one. The returned configuration is frozen. Client code may read these shared prototype values for disclosed presentation, but their availability never lets a client establish authoritative state or timing.

### Contract ownership and first consumers

| Contract | Server-authoritative owner | Client disclosure | Client request boundary | Never accept from a client as truth | First consumer |
| --- | --- | --- | --- | --- | --- |
| `OperativeLifeStateId` | The future operative runtime owner assigns the current life state. | May read a deliberately disclosed operative state. | None; a client cannot request a chosen state. | Life state or a transition claim. | LK-0302 |
| `OperativeHealthState` | The server owns current and maximum health. | May read disclosed health for permitted presentation. | None. | Current health, maximum health, damage result, or restored health. | LK-0302 |
| `OperativeLifeStateSnapshot` | The server owns and atomically commits the complete snapshot. | May read only a curated disclosed snapshot. | None. | Any snapshot field, including nested timestamps or solo state. | LK-0302 |
| `OperativeLifeTransitionResult` | A server-only pure resolver derives the result; the runtime owner later commits it. | May receive a separately curated outcome, not use the result as authority. | None. | Acceptance, rejection, state after, health after, or authoritative time. | LK-0302 |
| `OperativeLifeTransitionRejectionReasonId` | The server selects the first applicable rejection. | May read a disclosed reason for presentation or diagnostics. | None. | A rejection reason or validity claim. | LK-0302 |
| `IncapacitationState` | The server creates the incapacitation start and bleed-out deadline. | The affected client may read disclosed timing; teammate disclosure remains bounded. | None. | Incapacitation time, bleed-out deadline, elapsed time, or completion. | LK-0303 |
| `SoloRecoveryState` | The server derives eligibility, usage, start, and completion from operation history. | The affected client may read its disclosed status. | None; recovery is automatic when eligible. | Eligibility, participant history, usage, timing, or completion. | LK-0303 |
| `ReviveSessionState` | The server owns participants, status, start, and completion time. | Involved clients may read a disclosed session snapshot. | A later request may name only a target and begin/end hold phase. | Reviver identity, eligibility, distance, line of sight, timing, progress, status, or completion. | LK-0304 |
| `ReviveSessionStatusId` | The server assigns `Active`, `Cancelled`, or `Completed`. | Involved clients may read a disclosed status. | A hold phase is intent, never a requested authoritative status. | Status, cancellation, or completion. | LK-0304 |
| `ReviveTransitionResult` | A server-only pure resolver derives the result; the runtime owner later commits it. | May receive curated revive feedback only. | A later target/hold request may trigger evaluation. | Acceptance, rejection, progress, session after, target state, or restored health. | LK-0304 |
| `ReviveRejectionReasonId` | The server derives the first applicable rejection from authoritative facts. | The requesting client may read a safe disclosed reason. | A client may request evaluation but not choose its outcome. | Eligibility, range, line of sight, busy state, interruption, timing, or rejection reason. | LK-0304 |
| `SquadViabilitySnapshot` | The server derives roster counts, recovery paths, viability, and grace timestamps. | Clients may later read only a disclosed operation-status projection. | None. | Active roster, life states, recovery paths, viability, failure, grace timing, or authoritative timestamps. | LK-0307 |

The shared types do not prove provenance. Future server callers must build every consequential value from server-owned state. No client-provided health, life state, incapacitation timestamp, bleed-out deadline, solo eligibility or usage, revive eligibility, distance, line of sight, start time, progress, completion, restored health, death, squad viability, squad failure, or timestamp may cross into these contracts as truth.

## LK-0302 pure operative damage resolver

`src/server/Systems/OperativeHealthResolver.luau` exposes one focused API:

```luau
OperativeHealthResolver.resolveDamage(
    operativeSnapshot,
    authoritativeDamage,
    serverTimestamp
): OperativeLifeTransitionResult
```

The resolver is deterministic, side-effect-free, server-domain only, and unintegrated. It applies at most one accepted damage event to one canonical `OperativeLifeStateSnapshot`. It does not prove that an input is authoritative: its caller must construct the snapshot, damage event, target identity, amount, and timestamp from server-owned state. Client health, life state, damage amount or type, target identity, timestamp, and transition requests are never valid sources.

`AuthoritativeOperativeDamage` is the minimum accepted shape: nonempty `damageEventId`, optional nonempty `sourceEntityId`, nonempty `targetEntityId`, finite positive `damageAmount`, and `serverTimestamp`. The separately supplied server timestamp must be finite, nonnegative, and exactly match the event timestamp. Extra P2 event fields do not widen the resolver's authority surface.

Validation uses this stable first-failure order and returns exactly one canonical LK-0301 reason:

1. `InvalidSnapshot` — malformed identity or life-state vocabulary, malformed health table structure, inconsistent incapacitation structure, malformed solo-recovery state or nested timestamps, or malformed processed-event set.
2. `InvalidHealth` — non-finite health, nonpositive or noncanonical maximum health, health outside `0..MaximumHealth`, `Alive` at zero, or non-Alive state with nonzero health.
3. `InvalidDamage` — malformed or empty damage identity, malformed optional source identity, target mismatch, or damage that is not finite and strictly positive.
4. `InvalidServerTimestamp` — non-finite, negative, or inconsistent event/call timestamps.
5. `IllegalTransition` — a structurally valid `Incapacitated` or `Dead` snapshot; finishing damage and Dead-state behavior belong to LK-0303.
6. `AlreadyResolved` — the valid damage identity is already present in the committed snapshot's processed-event set.

`StaleTransition` remains a canonical LK-0301 ID for a later resolver and is not invented as an alias for any LK-0302 failure.

Accepted nonlethal damage subtracts the amount, preserves maximum health and all unrelated canonical state, leaves health above zero, remains `Alive`, creates no incapacitation state, records the authoritative transition timestamp and damage-event correlation, and marks the event processed in the returned snapshot.

Accepted damage that reaches or exceeds current health clamps health to exactly zero and transitions only `Alive` to `Incapacitated`. The resolver creates `startedAtServerTimestamp = serverTimestamp` and `bleedOutDeadlineServerTimestamp = serverTimestamp + OperativeLifeConfig.BleedOutDurationSeconds`. Exactly zero and overkill use the same configured 30-second rescue window; excess damage is discarded and cannot enter `Dead`, shorten bleed-out, or start solo recovery.

The snapshot owns a caller-managed `processedDamageEventIds` set. The resolver copies that set and adds the accepted identity. Duplicate safety exists only after the caller atomically commits the complete returned snapshot before resolving another event for that operative. There is no hidden global service, runtime owner, persistence, cross-server guarantee, automatic cleanup, or memory bound in LK-0302. The future runtime owner must define one operative-lifetime boundary and cleanup policy.

The resolver never mutates its snapshot or damage input. Accepted results contain copied nested tables; rejected results contain a deep copied, value-preserving snapshot and no accepted timestamp, correlation, or partial incapacitation. Repeated calls with equivalent inputs produce equivalent outputs.

The P2 `AuthoritativeDamageEvent` is structurally compatible with the minimum LK-0302 input and may be adapted as authoritative server input without changing how P2 creates it. P2 `DamageResolver`, `TargetHealthState`, processed ShotIds, and the test-hostile `becameDead` health-crossing field remain unchanged. LK-0302 does not commit either P2 or P3 state at runtime.

Bleed-out completion, damage against an already incapacitated operative, finishing death, solo recovery, revival, runtime character restrictions, remotes, presentation, squad failure, and every P4 behavior remain deferred. LK-0303 is the next pure domain task and is not started by this resolver.

## Canonical life state and transitions

| Current state | Event | Next state | Result |
| --- | --- | --- | --- |
| `Alive` | Accepted nonlethal damage | `Alive` | Health decreases but remains above zero. |
| `Alive` | Accepted damage reaches zero | `Incapacitated` | Health becomes zero and the server starts bleed-out. Direct lethal damage does not bypass incapacitation in the base P3 model. |
| `Incapacitated` | Completed eligible teammate revival | `Alive` | Health becomes the configured revive health and restrictions are removed. |
| `Incapacitated` | Completed eligible solo recovery | `Alive` | The one solo recovery allowance is consumed and health becomes the configured revive health. |
| `Incapacitated` | Bleed-out deadline reached | `Dead` | The operative becomes unrecoverable for the operation. |
| `Incapacitated` | Accepted finishing damage | `Dead` | Any positive authoritative damage finishes the operative immediately. |
| `Dead` | Operation teardown and a later operation insertion | `Alive` | This is a new operation lifetime, not an in-operation revive or respawn. |

All other transitions are rejected without partial mutation. In particular, `Alive` cannot be revived, `Alive` cannot transition directly to `Dead` from ordinary base-P3 damage, `Incapacitated` cannot be incapacitated again, `Dead` cannot take consequential damage or be revived, and no in-operation `Dead` to `Alive` transition exists. Duplicate or stale completion requests are idempotently rejected.

## Health rules

- Maximum operative health is `100`; valid current health is the inclusive range `0` through `100`.
- Server transitions clamp accepted results to that range. Invalid non-finite health or damage inputs fail closed at the authoritative boundary.
- Ordinary damage that would reduce an `Alive` operative to zero enters `Incapacitated`, including a single high-damage hit. Overkill is discarded after health reaches zero; it does not shorten bleed-out or bypass the rescue window.
- The MVP has no passive or automatic health regeneration.
- P3 has no general healing action or healing item. Class healing, medic bonuses, stabilization resources, and scarcity belong to later class and supply milestones. Revival's configured health restoration is part of P3, not a healing system.
- Damage against an `Incapacitated` operative is finishing damage: any accepted positive amount causes immediate `Dead`. Damage types or authored hazards may opt out only by being non-damaging; there is no separate reduced bleed-out calculation in P3.
- An authoritative environmental hazard may finish an incapacitated operative under the same rule. A client touch, region claim, or hazard identity cannot establish damage.

### Relationship to the P2 pure health state

LK-0205 `TargetHealthState` and `DamageResolver` remain accepted, pure P2 contracts for test hostile damage and ShotId deduplication. Their `becameDead` field means only that the P2 target health crossed from positive to zero; it is not the canonical P3 operative-death decision.

P3 must introduce a focused operative life-state contract rather than reinterpret or silently expand the P2 table in place. The future runtime owner will atomically commit operative health/life state and processed ShotIds, adapting an accepted authoritative damage event into the P3 transition. It will preserve P2 fixture behavior. Processed ShotIds survive incapacitation and revival for the same operative lifetime and are cleared only when that runtime lifetime is torn down; a revive cannot make a ShotId reusable.

## Incapacitation policy

- Entry occurs only when accepted damage moves an `Alive` operative from positive health to zero.
- Base bleed-out duration is `30` seconds, measured from a server-owned incapacitation timestamp. Exactly the deadline is lethal if revival has not already completed atomically.
- An incapacitated operative cannot walk, crawl, jump, fight, acquire targets, fire, reload, use class actions, collect supplies, start interactions, or revive another operative. Crawl is deliberately absent from the base P3 prototype.
- Entry interrupts an active reload without ammunition transfer, clears the selected target, disables weapon readiness, stops automatic combat, and cancels any revive the operative was performing.
- An incapacitated operative may receive one eligible revive. It cannot contribute input or progress to that revive.
- The local camera keeps the incapacitated operative framed using the existing tactical follow relationship and existing zoom behavior. P3 adds no free spectate, hidden-information disclosure, or camera redesign.
- Further accepted damage, including an authoritative environmental hazard, causes immediate death rather than reducing the remaining timer.
- Multiplayer operatives have no repeated-incapacitation count limit in the base model. Each successful revival returns them to `Alive` at low health, with no invulnerability or healing, so repeated mistakes remain dangerous. The solo exception below is limited once per operation.
- If an incapacitated player disconnects, any revive targeting them is cancelled and their operative is removed from the connected active roster. A same-operation rejoin does not create a fresh recoverable character; it returns as `Dead` for the remainder of that operation.

## Revival policy

- During the base P3 prototype, any `Alive` teammate may revive an `Incapacitated` teammate. No class, item, medic bonus, or recovery resource is required in P3.
- The reviver and target must be distinct active operatives, within `8` horizontal studs, with server-confirmed line of sight.
- Revival requires a continuous `4`-second hold. The server owns start time, current eligibility, completion time, and committed result.
- Exactly one authoritative revive session may target an operative at a time. The first valid session wins; additional revivers do not accelerate progress and receive a busy rejection.
- Releasing the interaction, either operative moving, range exceeding `8` studs, line of sight failing, either player disconnecting, the reviver taking any accepted damage, the reviver becoming incapacitated or dead, or the target becoming dead or otherwise no longer incapacitated cancels progress. Cancellation resets progress to zero; no partial progress is banked.
- A completed revival restores `30` health and transitions the target atomically to `Alive`.
- Revival grants no invulnerability, damage immunity, crowd control immunity, or protected animation window.
- Loaded and reserve ammunition are unchanged by incapacitation and revival. Any in-progress reload was already interrupted on incapacitation and does not resume. After revival, weapon readiness is derived from the preserved ammunition and cadence state; the previous selected target remains cleared.
- Revive progress is server-owned. A client may display disclosed target identity, start/cancel/complete state, and server-derived progress or timing, but presentation cannot complete or preserve a revive.

### Future revive-intent trust boundary

The future client-to-server request may contain only the server-known `CombatEntityId` of the intended incapacitated teammate plus the begin/end phase necessary to represent a held interaction. Roblox supplies the requesting player. It must not accept a reviver ID, distance, position, line-of-sight result, life state, health, duration, elapsed progress, completion claim, timestamp, restored health, class bonus, or interruption result. The server rate-limits requests, maps the sender to its active operative, derives every eligibility fact, and revalidates continuously and at completion.

## Solo policy

Solo play uses one explicit exception so an otherwise valid run is not ended by the first incapacitation:

- Only when the operation began with one active participant and has never had another active participant, the operative receives one automatic solo recovery allowance for that operation.
- Solo recovery completes after `8` uninterrupted seconds of incapacitation, uses the same `30` restored health, and is server-timed. It requires no client completion request.
- Accepted finishing damage or bleed-out still causes death. The recovery allowance is consumed only on successful recovery; it is unavailable after its first successful use.
- A second incapacitation has no solo recovery path and proceeds to bleed-out or finishing death.
- This allowance is not an inventory item, token, purchase, class bonus, persistent upgrade, or monetized recovery. It cannot be earned, replenished, transferred, or bought.
- An operation that ever had multiple active participants never converts to solo recovery merely because teammates disconnect or die.

## Death and respawn policy

- Death is unrecoverable for the current operation and occurs only through incapacitated bleed-out, accepted finishing damage, or a future explicitly authored unrecoverable operation event.
- On death the server cancels outgoing and incoming revive sessions, disables movement and combat, interrupts reload, clears selected target state, and prevents further interaction. Loaded/reserve ammunition may remain in the operation snapshot but cannot be used.
- The character remains as a stationary, non-interactive readable body until operation cleanup or a later bounded presentation decision. P3 does not add ragdoll, gore, lootable corpses, or a corpse framework.
- The dead player's camera remains framed on their own operative in P3. Teammate spectating and any information it may reveal are deferred until operation and visibility rules can define safe disclosure.
- Automatic Roblox respawn is not the gameplay model during an operation. The runtime task must disable or intercept automatic character replacement for an active operation; a replacement character cannot restore a dead operative. A new character is allowed only during explicit operation setup/teardown or a development reset outside the operation lifetime.
- A disconnected operative returns `Dead` on same-operation rejoin and cannot reset health, solo recovery, ammunition, reload, target, or ShotId state. Exact cross-server reservation and persistence are deferred to the operation milestone.
- Processed ShotIds, selected target, reload, and combat state are cleaned when the operative's operation lifetime is torn down. Selected target and reload are also cleared on incapacitation/death; processed ShotIds are not cleared by revival.

## Squad-failure policy

- The server evaluates failure from the current connected active-operative roster and authoritative life states. Clients cannot report that the squad has failed or recovered.
- The squad remains viable while at least one active operative is `Alive` or the sole-operation participant is `Incapacitated` with an unused, pending solo recovery path.
- In a multiplayer operation, all active operatives being `Incapacitated` means no legal reviver exists and starts a `3`-second server-owned failure grace period. The same applies when every active operative is `Dead` or incapacitated without a recovery path.
- The grace period is cancelled if a legal viability state is restored before its deadline. Exactly at the deadline, the server commits failure once. The grace exists to make simultaneous transitions and disconnect cleanup deterministic; it does not allow incapacitated players to revive one another.
- One `Alive` operative prevents squad failure even when every teammate is dead, out of range, obstructed, or otherwise currently impossible to revive. The run continues until that operative also becomes unrecoverable or an authored objective fails.
- With one participant, the first incapacitation remains viable only during the pending solo recovery. Finishing damage, bleed-out, or a later incapacitation after the allowance was used starts failure grace.
- Disconnecting removes that player from the connected active roster, cancels their revive sessions, and immediately reevaluates viability. Disconnects cannot grant the solo exception. If no connected active operatives remain, the session is abandoned for cleanup rather than waiting on bleed-out; result/reward semantics belong to P10.
- Late joins do not cancel pending or committed failure and do not enter an operation already in progress during P3. Join-in-progress policy belongs to the operation milestone.
- Critical-objective failure remains a separate future operation rule. P3 supplies life-state failure truth only and does not implement operation results, rewards, extraction, or result screens.

## Client disclosure and presentation

- A player may receive their own exact health, life state, bleed-out deadline, solo-recovery status, and revive progress involving them.
- Teammate disclosures are limited to what P3 needs for a rescue: disclosed operative identity, `Alive`/`Incapacitated`/`Dead`, eligibility-relevant interaction feedback, and server-owned progress for the active revive. P4 may further restrict distant information; P3 must not reveal hostile, visibility, or map state.
- Presentation may show temporary prototype status text, a basic health value, incapacitation/bleed-out status, and revive progress. Polished squad UI, health bars, damage numbers, spectator UI, and result screens are deferred.
- Malformed, stale, unknown, or out-of-order presentation messages fail closed and cannot mutate authoritative state.

## Deferred features and explicit exclusions

P3 planning and its implementation tasks do not include darkness or visibility systems, enemy AI or hordes, medic bonuses, healing actions or items, recovery-resource scarcity, permanent progression, loot, objectives, extraction, boss behavior, polished UI, ragdoll, gore, monetized or paid recovery, revive tokens, speculative framework code, or any P4 feature.

## Unresolved design questions

These questions require later playtesting or a later milestone; none blocks the initial P3 model:

- Tune the provisional `30`-second bleed-out, `4`-second teammate revive, `8`-stud range, `30` revive health, `8`-second solo recovery, and `3`-second failure grace after the first two-client prototype.
- Decide whether a later medic class changes revive speed, restored health, stabilization, or resource cost without making non-medic squads invalid.
- Decide whether crawling materially improves rescue play after the stationary incapacitation prototype is tested.
- Define which future enemy attacks and authored hazards intentionally apply finishing damage; P3 defines the rule but does not add those sources.
- Define safe teammate spectating and distant life-state disclosure together with P4 visibility and P10 operation presentation.
- Define cross-server reconnect reservation, join-in-progress, abandoned-session results, and final operation teardown in P10.
