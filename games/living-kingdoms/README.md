# Living Kingdoms

Living Kingdoms is the temporary working title and internal identifier for a brutally difficult cooperative isometric survival game on Roblox. Final public branding is unresolved; repository, folder, Rojo project, script, and namespace naming remain unchanged.

## Current stage

P1, tactical player movement and character control, and P2, automatic targeting and basic firearm combat, are complete. The initial MVP targets 1–4 players, while architecture should permit later support for up to 8. Each player controls one specialist operative rather than an army.

The existing client starts a fixed elevated tactical camera that smoothly follows the local player while Roblox's standard character moves relative to that camera. Mouse-wheel zoom and configurable world-space focus-point bounds remain active. Keyboard camera panning remains implemented but is disabled while survivor movement is active so one keypress cannot move both the character and camera.

## Preserved project layout

```text
living-kingdoms/
├── default.project.json
├── src/
│   ├── client/
│   │   ├── Controllers/
│   │   │   ├── CameraController.luau
│   │   │   └── SurvivorController.luau
│   │   └── init.client.luau
│   ├── server/
│   │   ├── Systems/
│   │   │   ├── MovementStateReplicationSystem.luau
│   │   │   └── MovementValidationSystem.luau
│   │   └── init.server.luau
│   └── shared/
│       ├── Combat/
│       ├── Config/
│       └── Health/
├── tests/
└── README.md
```

The shared source and test directories contain placeholder files so Git preserves the scaffold. `default.project.json` maps source into Roblox services as follows:

| Source path | Roblox destination |
| --- | --- |
| `src/client` | `StarterPlayer/StarterPlayerScripts/Client` |
| `src/server` | `ServerScriptService/Server` |
| `src/shared` | `ReplicatedStorage/Shared` |

The bootstrap scripts use strict Luau and print these startup confirmations:

- `[Living Kingdoms] Client bootstrap started`
- `[Living Kingdoms] Server bootstrap started`

## Local survivor movement

The client bootstrap initializes and starts `SurvivorController` after `CameraController`. Both controllers expose `init()`, `start()`, `stop()`, and `destroy()` with safe repeated calls and terminal destruction.

`SurvivorController` binds to the existing local-player character, `Humanoid`, and `HumanoidRootPart`, including respawns and temporary missing instances. W/A/S/D and arrow-key input is converted through the tactical camera's horizontal look and right vectors, normalized to prevent faster diagonals, and applied every render step through `Humanoid:Move()`. Roblox's normal Humanoid movement, collision, and WalkSpeed remain in use. Processed input and text-box focus suppress movement, and Roblox's default character controls are disabled while this controller is active so movement is not double-applied.

## Prototype movement authority boundary

Responsive movement still uses the local `SurvivorController`, Roblox's standard `Humanoid`, and normal character network ownership. `MovementLimits` names the shared prototype values: maximum horizontal speed `16` studs per second, observation interval `0.25` seconds, horizontal tolerance `4` studs, and warning cooldown `2` seconds. The client uses the configured speed as its intended Humanoid WalkSpeed; the server independently uses the same speed as a validation limit and does not trust any client-reported position, speed, timestamp, or validation state.

The server starts one `MovementValidationSystem` and uses one shared bounded Heartbeat loop for all active players. For each valid living character, it stores the last accepted root position and server timestamp. At an observation, allowed horizontal displacement is `16 * elapsed server seconds + 4 studs`. Vertical displacement is intentionally excluded so normal jumping, falling, slopes, and small physics variation do not cause corrections.

Initial spawn and replacement characters establish a fresh accepted point. Missing characters, missing or replaced `HumanoidRootPart` instances, and dead Humanoids clear the accepted sample so respawn or temporary incomplete character state cannot be compared with stale data. Player state is removed on leave, character replacement overwrites the prior state, and stopping the system disconnects its shared connections and clears all state. No server-authorized teleport or reset gameplay exists yet; any future system that adds one must explicitly coordinate a validation reset before moving the character.

When horizontal displacement clearly exceeds the formula, the server restores the root to the last accepted full position while preserving its orientation, clears assembly linear and angular velocity, advances the accepted timestamp to stabilize the next observation, and emits `[Living Kingdoms] Corrected impossible movement for <player>` at most once per two-second cooldown. Consequential correction remains server-owned.

This is only a prototype movement sanity boundary. It is deliberately tolerant, observes discrete samples rather than continuous paths, and is not production-grade exploit prevention. It does not add movement remotes, custom replication, client prediction/reconciliation, teleport gameplay, or a speculative security framework.

## Survivor facing and replicated movement state

While survivor control is active, `SurvivorController` temporarily disables the local Humanoid's automatic rotation and turns the character toward the normalized camera-relative movement direction. Releasing input preserves the last facing. The controller restores the Humanoid's prior `AutoRotate` value on stop, character replacement, or destruction. No aiming system exists yet, so all current facing is movement-driven; a future aiming task must explicitly define when aim overrides movement facing.

The server observes every active living character from one shared bounded loop. `MovementStateConfig` names the `SurvivorMovementState` and `SurvivorFacingDirection` character attributes, the `Idle` and `Moving` state IDs, a `0.1`-second observation interval, and a `1`-stud-per-second moving threshold. The server derives speed from successive replicated root positions and publishes the root's horizontal look direction while moving. Idle preserves the last known facing so other clients see stable presentation state.

There is no client movement-state remote and the server accepts no client-supplied facing, speed, validation state, or transform. Missing, dead, or replaced characters reset observation samples; replacement clears the old character's attributes, player leave removes state, and system shutdown disconnects the shared connections and clears all replicated state. These attributes are presentation signals, not a production anti-cheat or an animation system. Their discrete observation can briefly lag a transition by one interval and physics-driven horizontal motion can qualify as moving.

## Preserved camera behavior

The client bootstrap initializes and starts `CameraController`. The controller exposes `init()`, `start()`, `stop()`, and `destroy()`; repeated lifecycle calls are safe no-ops when the requested state is already satisfied, and destruction is terminal.

The current view uses initial focus point `(0, 0, 0)`, pitch `-60` degrees, yaw `45` degrees, and height `80` studs. Mouse-wheel zoom changes height by `10` studs per wheel unit and clamps it from `40` to `160` studs. The focus point is clamped from `-128` to `128` on X and Z. Keyboard panning remains available to the camera controller at `48` studs per second, but `SurvivorController` disables it while active and restores it on stop.

These values and controls are not the final survival-camera design. Survivor movement owns the shared movement keys while active. Bounds must later be adapted to one authored operation map. Working camera code remains intact unless a focused survival task demonstrates a change is needed.

## Local survivor camera follow

While `SurvivorController` is active, it enables `CameraController` survivor-follow mode and disables keyboard camera panning. Stopping survivor control disables follow and restores keyboard panning. Movement retains sole ownership of W/A/S/D and arrow keys; mouse-wheel zoom remains available.

The camera follows the local character's `HumanoidRootPart` on the horizontal XZ plane. `SurvivorFollowConfig` centralizes a world-space offset of `(0, 0, 0)`, responsiveness of `12` per second, a `0.05`-stud settle distance, and the `PreserveConfiguredFocusHeight` vertical policy. The follow target is `(root.X + offset.X, configuredFocusY + offset.Y, root.Z + offset.Z)`, clamped to the existing `-128` to `128` X/Z focus bounds.

Each render step uses exponential smoothing with `alpha = 1 - exp(-responsiveness * deltaTime)` and interpolates the current focus toward the bounded target. Once the remaining distance is at most `0.05` studs, the focus is set to the target so it does not drift indefinitely. Root Y is intentionally ignored, so ordinary walking physics, animation, slopes, and jumping do not produce vertical camera bob. Pitch `-60` degrees, yaw `45` degrees, current zoom height, zoom limits `40` to `160`, and `Scriptable` mode are unchanged.

`CameraController` listens for local character addition/removal and for root addition/removal while started. Respawn binds the replacement character and converges from the last valid frame. A missing character, missing root, or missing `Workspace.CurrentCamera` causes no follow update; the last valid focus remains until a valid target or camera returns. Stop and destroy disconnect all follow-owned connections, and repeated lifecycle calls remain safe.

The configured focus bounds must enclose the authored playable area. If gameplay later permits a survivor to move beyond those bounds, the focus remains correctly clamped and the survivor can eventually leave the frame; viewport-aware bounds and survivor movement confinement are not part of LK-0104.

## Canonical direction

The source of truth is:

1. [`docs/bible/00-project-charter.md`](../../docs/bible/00-project-charter.md)
2. [`docs/bible/01-mvp.md`](../../docs/bible/01-mvp.md)
3. [`docs/architecture/technical-blueprint.md`](../../docs/architecture/technical-blueprint.md)
4. [`docs/roadmap/MASTER-ROADMAP.md`](../../docs/roadmap/MASTER-ROADMAP.md)
5. [`docs/decisions/0001-cooperative-survival-pivot.md`](../../docs/decisions/0001-cooperative-survival-pivot.md)
6. [`docs/decisions/0002-automatic-combat-targeting.md`](../../docs/decisions/0002-automatic-combat-targeting.md)

The former worker-selection, economy, construction, production, and army-command plan is superseded. Completed repository and camera work is preserved.

Combat uses server-authoritative automatic target acquisition and fire. Players directly control movement, positioning, interaction, reload timing, class abilities, and resource decisions. A future manual priority-target override remains optional and is not part of the first combat milestone.

## Automatic-combat contracts

LK-0201 adds shared contracts in `src/shared/Combat/CombatContracts.luau`, prototype balance values in `src/shared/Config/FirearmConfig.luau`, and the canonical [`automatic-combat contract specification`](../../docs/specifications/automatic-combat-contracts.md). Pure LK-0202 through LK-0206 server modules consume these declarations. There is still no production runtime targeting, firing, enemy, or health mutation behavior.

The server owns entity and relationship truth, operative and weapon state, visibility, line of sight, range, target legality and selection, cadence, ammunition, hits, damage, and authoritative timestamps. Clients may use only disclosed state for non-authoritative presentation and may never establish combat truth.

## Local validation

Follow [`docs/production/LOCAL-SETUP.md`](../../docs/production/LOCAL-SETUP.md), [`docs/production/LUAU-TOOLING.md`](../../docs/production/LUAU-TOOLING.md), [`docs/production/ROJO-BUILD-VALIDATION.md`](../../docs/production/ROJO-BUILD-VALIDATION.md), and [`docs/production/SMOKE-TEST.md`](../../docs/production/SMOKE-TEST.md).

## Server target-candidate validation

LK-0202 adds `TargetCandidateValidator.validate(operative, candidate)`, a pure, unintegrated server function that evaluates one server-derived hostile candidate in a stable first-failure order. It uses horizontal XZ range, treats exactly the configured maximum range as valid, and keeps gameplay visibility separate from line of sight. The caller—not the validator—must guarantee that all facts came from authoritative server systems.

The standalone fixture runner requires Lune and can be invoked from the repository root with `lune run games/living-kingdoms/tests/TargetCandidateValidator.test.luau`. The validator is not imported by the server bootstrap, so it adds no polling, discovery, selection, firing, damage, enemy, networking, or presentation behavior.

## Deterministic server target selection

LK-0203 adds `TargetCandidateSelector.select(operative, candidates)`, a pure server function that validates every caller-provided candidate through `TargetCandidateValidator` and returns at most one `SelectedTargetState`. Valid hostiles actively threatening the exact operative take priority; otherwise the closest valid hostile wins. Distance is recomputed from authoritative positions on the horizontal XZ plane, and exact equal-distance ties use lexical `CombatEntityId` ordering.

The shared candidate contract adds optional `activelyThreateningOperativeEntityId`, the exact intended victim derived from server threat state. The selector ignores the earlier generic threat boolean because it cannot prove that a hostile is pursuing, attacking, or committed to attack this operative. When there is no valid candidate, selection returns `nil`; it has no timestamp, persistence, hysteresis, cache, or input mutation.

Run its standalone fixture from the repository root with `lune run games/living-kingdoms/tests/TargetCandidateSelector.test.luau`. The selector is not imported by the server bootstrap, so it adds no polling, discovery, automatic firing, cadence mutation, ammunition consumption, damage, enemies, networking, or presentation behavior.

## Server-authoritative automatic-fire transition

LK-0204 adds `AutomaticFireResolver.resolve(operativeState, selectedTarget, weaponState, serverTimestamp)`, a pure server function that accepts or rejects at most one shot. Accepted fire consumes one loaded round, preserves reserve ammunition, advances last and next cadence timestamps from the authoritative fire time, returns a deterministic server-owned ShotId, and leaves hit fields unresolved. Rejected fire preserves all input values and uses a stable first-failure reason.

The resolver trusts no client timestamp, ammunition, cadence, target, or ShotId input. Its caller must provide authoritative state and commit the returned weapon-state copy. Run its standalone fixture with `lune run games/living-kingdoms/tests/AutomaticFireResolver.test.luau`. The module is not imported by the server bootstrap and adds no loop, discovery, hit resolution, damage, enemy, networking, client, or presentation behavior.

## Server-authoritative hit and damage transitions

LK-0205 adds `FirearmHitResolver.resolve(acceptedFireResult, shotContext, targetContext)` and `DamageResolver.resolve(hitResolution, targetHealthState, serverTimestamp)`. The first revalidates current authoritative target identity, life, targetability, hostility, visibility, horizontal XZ range, and one server-owned obstruction outcome for one already accepted shot. The second returns a copied health state and, only for a successful hit, one frozen configured Ballistic damage event. Neither module mutates input state or calls `Humanoid:TakeDamage`.

Duplicate protection is a temporary caller-owned `processedShotIds` set carried in the health state. The caller must atomically commit the returned state; cleanup, lifetime, and runtime ownership remain deferred. Run the standalone fixture with `lune run games/living-kingdoms/tests/FirearmHitDamageResolver.test.luau`. The modules are not imported by the server bootstrap and add no enemy, discovery, loop, networking, reload, client, or presentation behavior.

## Reload input and immediate combat presentation

LK-0206 adds `WeaponController` with the existing `init()`, `start()`, `stop()`, and `destroy()` lifecycle. Desktop `R` sends only the configured equipped `WeaponId`; game-processed input and focused text boxes are ignored, a local `0.5`-second cooldown bounds repeated requests, and stop/destroy disconnect input and presentation connections. The client never sends ammunition, capacity, duration, timestamp, eligibility, target, hit, or damage.

The controller consumes only explicit server-disclosed target, shot, and reload messages. A disclosed target can receive one small temporary highlight, clear destroys it, a disclosed ShotId produces one concise status update, and reload start/completion/interruption produce temporary status text. Unknown messages and shot target IDs never create target indicators. Presentation does not mutate authoritative ammunition or health.

`ReloadResolver.begin` and `ReloadResolver.complete` own the pure authoritative transition. Begin requires a ready operative, the configured equipped weapon, a non-full magazine, reserve ammunition, and no current reload. Completion at or after the configured two-second server deadline moves `min(capacity - loaded, reserve)` without discarding loaded rounds. Incapacitation, death, weapon disablement, or equipped-weapon change interrupts with no transfer; movement and taking damage do not interrupt this initial prototype.

The two explicit RemoteEvents are `CombatNetwork.ReloadIntent` and `CombatNetwork.CombatPresentation`. `ReloadIntent` is the only client-to-server combat listener. A Studio-only `AutomaticCombatDevelopmentHarness` composes the accepted pure P2 modules with two stationary labeled fixtures, isolated per-player weapon state, and server-owned fixture health/processed ShotIds. It starts test magazines empty so `R` exercises the authoritative two-second reload before acquisition and fire. It is inactive outside Studio and is not a production combat owner, hostile-discovery path, enemy architecture, AI, or final ammunition system. Run all P2 fixtures plus `CombatSecurityIntegration.test.luau` with Lune for focused validation.

## Operative health and life-state declarations

LK-0301 adds `OperativeLifeContracts` under `src/shared/Health` and `OperativeLifeConfig` under `src/shared/Config`. The contract module declares only the stable `Alive`, `Incapacitated`, and `Dead` life-state vocabulary plus focused health, incapacitation, transition, revive, solo-recovery, and squad-viability shapes. Stable identifier tables and the configuration table are frozen; runtime snapshots are not.

The configuration centralizes maximum health `100`, bleed-out `30` seconds, revive range `8` studs, revive duration `4` seconds, revive health `30`, solo recovery `8` seconds, one solo recovery per operation, and squad-failure grace `3` seconds. Module-load assertions enforce positive finite values, revive health within maximum health, and exactly one solo recovery.

These shared modules are safe for client and server code to require, but the server remains authoritative. No bootstrap imports them, and they add no owner, transition resolver, timers, character changes, remotes, UI, or runtime behavior. The P2 `TargetHealthState`, `DamageResolver.becameDead` semantics, firearm configuration, processed-ShotId boundary, and all P2 fixtures remain unchanged. Run `lune run games/living-kingdoms/tests/OperativeLifeContracts.test.luau` for the LK-0301 fixture.

## Pure operative health and incapacitation transitions

LK-0302 adds `OperativeHealthResolver.resolveDamage(operativeSnapshot, authoritativeDamage, serverTimestamp)`. The pure server-domain resolver validates one canonical operative snapshot and one server-owned damage input, applies finite positive damage only to `Alive`, preserves positive-health results as `Alive`, and turns exact-zero or overkill results into `Incapacitated` at zero health. Incapacitation starts at the exact authoritative timestamp and derives its deadline from the configured 30-second bleed-out duration; the resolver does not complete bleed-out or enter `Dead`.

The returned snapshot carries a copied caller-owned `processedDamageEventIds` set. Duplicate rejection is effective only after a future caller atomically commits the returned snapshot; this task adds no hidden deduplication state, runtime owner, persistence, cleanup, loop, scheduler, character mutation, remote, or presentation. A P2 `AuthoritativeDamageEvent` is structurally compatible as server input, while P2 damage creation, processed ShotIds, and `becameDead` retain their existing semantics.

Run `lune run games/living-kingdoms/tests/OperativeHealthResolver.test.luau` for health boundaries, invalid values, timestamp/identity validation, illegal-state rejection, duplicates, deterministic precedence, and immutability.

LK-0303 adds `OperativeIncapacitationResolver` with three explicit pure APIs: `evaluateBleedOut`, `resolveFinishingDamage`, and `evaluateSoloRecovery`. Bleed-out accepts at the stored snapshot deadline or later without recalculating it. Any accepted positive finishing-damage event transitions `Incapacitated` to `Dead` at zero health and copies its stable identity into the returned processed-event set.

Solo recovery requires explicit server-owned facts that the operation started solo and never had multiple participants, plus canonical snapshot timing. It completes at the stored eight-second deadline, restores the configured `ReviveHealth` of `30`, consumes the one operation use, clears incapacitation/recovery timing, and grants no invulnerability. These synchronous APIs have no scheduler, runtime owner, timer, polling, Humanoid behavior, remote, UI, squad evaluation, or teammate revival. Run `lune run games/living-kingdoms/tests/OperativeIncapacitationResolver.test.luau` for the LK-0303 fixture.

LK-0304 adds the pure `OperativeReviveResolver.beginRevive` and `continueRevive` APIs. Begin requires distinct valid identities, an `Alive` reviver, an `Incapacitated` target, no accepted session already owning the target, at most the configured `8` studs, and server-confirmed line of sight. Distance and line of sight are explicit server-owned facts. The resolver derives an `Active` session's four-second deadline from its authoritative start time; continuation derives clamped progress only from authoritative time and the stored session timestamps.

Every continuation revalidates session ownership, participants, life states, hold continuity, range, and line of sight. It also requires explicit server-owned facts that the reviver remains connected and participating, performed no disallowed movement, and received no accepted interrupting damage during the hold. Any interruption returns a copied `Cancelled` session with zero progress, and a retry must begin a new session with no carried progress.

Completion is impossible before the stored deadline; at or after it, the target becomes `Alive`, receives exactly the configured `ReviveHealth` of `30`, clears incapacitation/recovery timing, and preserves maximum health, recovery eligibility/usage, processed damage IDs, and unrelated state. A focused caller-owned combat companion reuses the P2 weapon, selection, and processed-ShotId shapes: completion preserves ammunition, cadence, and ShotIds by value in copied state while clearing reload and selected target. LK-0304 adds no runtime owner, P2 orchestration, session storage, connection/damage/movement listener, timer, polling, Heartbeat, remote, input, UI, or character/Humanoid mutation. Run `lune run games/living-kingdoms/tests/OperativeReviveResolver.test.luau` for the LK-0304 fixture.

## Operative life runtime

LK-0305 adds `OperativeLifeService`, the production same-server owner of one copied P3 snapshot and monotonic revision per registered player. Identity is derived from server-known `Player.UserId`. Registration creates `Alive` at `100/100`, with no incapacitation, no processed damage IDs, and no invented solo-operation eligibility. `read` returns a deep copy; `commitAcceptedTransition` accepts only an accepted pure resolver result at the current revision and validates identity, structure, health/life invariants, legal direction, and non-regressing authoritative time before atomically replacing state. Player removal clears the owned lifetime.

Alive remains eligible for P1 movement and P2 combat. Incapacitated and Dead are stationary without anchoring, cannot fire/reload/target, and synchronously clear reload and selection while preserving ammunition, cadence, and processed ShotIds. A valid committed return to Alive restores movement/combat eligibility without refilling. Character replacements bind to the existing snapshot; stale characters are disabled. Automatic character loading is disabled and performed deliberately so Roblox respawn cannot reset Dead or Incapacitated. Humanoid health is a positive locomotion shell with its Dead state disabled, not the authoritative P3 health value. `OperativeLifeDevelopmentHarness` composes existing pure resolvers for validation and, only in Studio, creates server-only `BindableFunction` controls in `ServerStorage`; it exposes no remote or production loop. Run `lune run games/living-kingdoms/tests/OperativeLifeService.test.luau` for focused ownership and restriction coverage.

LK-0306 adds the server-only `OperativeLifeService.applyAuthoritativeDamage(operativeEntityId, expectedRevision, authoritativeDamage)` entry point. It copies the current service-owned snapshot, rejects a stale authoritative revision, invokes the pure LK-0302 resolver, validates its accepted correlation and processed-event result, and commits through the existing atomic transition boundary. Successful results are copied. Ordinary nonlethal, lethal, and overkill damage therefore update runtime health and restrictions without allowing ordinary damage to produce `Dead`.

Replay protection remains solely in each authoritative snapshot's `processedDamageEventIds` set: LK-0302 checks and copies it, and `OperativeLifeService` commits and owns it for the registered operative lifetime. No client remote accepts damage, health, life state, revision, timestamps, processed IDs, or transition results. The Studio-only server `ApplyDamage` BindableFunction is isolated in `ServerStorage` for development validation. Run `lune run games/living-kingdoms/tests/OperativeLifeDamageRouting.test.luau` for focused runtime routing coverage.

LK-0307 adds pure `SquadFailureEvaluator.evaluateViability(facts, serverTimestamp)` and `resolve(state, facts, serverTimestamp)` APIs plus the server-only `SquadFailureService`. The stable state vocabulary is `Viable`, `Pending`, and `Failed`. A connected registered `Alive` operative is viable even when no revive can be completed. Otherwise, only one authoritative pending solo recovery is viable: the operation started solo, never had multiplayer participation, the operative is Incapacitated and eligible, the one allowance is unused, and its canonical recovery timing is still valid. Incapacitated or Dead teammates do not prove a revive path.

The first loss of viability stores the server timestamp and its exact `+3` second deadline. Viability returning before that deadline cancels Pending and clears all grace timing; a later loss starts a fresh full grace. Evaluation at or after the stored deadline commits `Failed` once, and ordinary later viability cannot undo it. The runtime reads copied `OperativeLifeService` snapshots, reevaluates on life commits and roster changes, and uses one server timer for deadline completion. Disconnect removes the snapshot immediately; zero connected admitted operatives irreversibly mark the operation abandoned. Participation freezes at explicit operation start, so later registrations are ignored for viability during Pending and Failed; reconnect restoration is not implemented. No client failure remote or client-controlled clock exists. Run the two LK-0307 fixtures with `lune run games/living-kingdoms/tests/SquadFailureEvaluator.test.luau` and `lune run games/living-kingdoms/tests/SquadFailureService.test.luau`.

LK-0308 completes the narrow P3 integration owner. `OperativeLifeRuntimeService` routes server-created finishing damage and centrally evaluates the earliest stored bleed-out or solo-recovery deadline through the existing pure resolvers and `OperativeLifeService` commit boundary. `OperativeReviveSessionService` owns one continuous four-second session per target, derives every eligibility and interruption fact on the server, and accepts only `{ targetOperativeEntityId, phase = "Begin" | "End" }` through its rate-limited `ReviveIntent` remote. Completion preserves ammunition, cadence, and processed ShotIds while clearing reload and target selection.

The client receives copied life, health, deadline, recovery, revive, and squad-failure attributes for prototype validation only. `OperativeLifeController` renders those values as a plain debug label and may request hold begin/end; no disclosed value is echoed as authority. Studio-only bindable controls can route authoritative damage or advance evaluation to an already stored deadline, but they call the same production resolver and commit paths.

## Next planned milestone

P3 is complete. P4 — darkness, limited vision, and squad-location tools — is the next planned milestone and remains unstarted. Operation results, broader operation flow, persistence, enemies, scarcity pickups, production presentation, and all later gameplay systems remain deferred.
