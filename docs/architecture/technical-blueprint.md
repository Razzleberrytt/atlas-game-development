# Living Kingdoms — Technical Blueprint

## Architecture objective

Support a small, server-authoritative cooperative survival operation without premature framework complexity. Favor clear boundaries, responsive local presentation, data-driven configuration, replaceable systems, and an architecture that targets 1–4 players now without preventing 8-player support later.

## Authority model

### Client owns

- Tactical camera controls and presentation
- Local input sampling and interpretation
- Immediate movement, reload, interaction, class-ability, targeting, firing-presentation, and UI feedback
- Local visibility presentation, lighting effects, indicators, and non-authoritative effects
- Requests to move, reload, use class abilities, interact, revive, or collect supplies

### Server owns

- Operative identity, class eligibility, spawn assignment, and match participation
- Validation of movement constraints and interaction range
- Target legality, automatic target acquisition, weapon configuration, fire cadence, ammunition, reload state, hit validation, damage, and death
- Health, incapacitation, revival, and recovery resources
- Supply availability and collection
- Enemy spawning, navigation, targeting, attacks, and boss state
- Objective, operation, extraction, success, and failure state
- XP awards, ranks, unlocks, and persistent data
- Any gameplay-relevant visibility or discovery rule

The client requests player-directed actions and may predict safe targeting and firing presentation for responsiveness. The server selects or confirms legal automatic-combat targets and applies consequential state. Never trust client-supplied targets, hits, damage, ammunition totals, cadence, health, inventory, class unlocks, XP, rank, objective completion, enemy state, or visibility claims.

Roblox character network ownership may provide responsive physical simulation, but it does not make the client authoritative. Movement work must define server-side sanity checks and recovery behavior before competitive integrity or exploit resistance is claimed.

## Source layout

```text
games/living-kingdoms/
├── default.project.json
├── src/
│   ├── client/
│   │   ├── Controllers/
│   │   └── UI/
│   ├── server/
│   │   ├── Services/
│   │   └── Systems/
│   └── shared/
│       ├── Config/
│       ├── Network/
│       ├── Types/
│       └── Utilities/
├── tests/
└── README.md
```

This is a boundary guide, not permission to scaffold every future module before it is needed.

## Intended system boundaries

- `CameraController` — elevated camera lifecycle, local-survivor follow framing, panning, zoom, and current bounds
- `SurvivorController` — implemented local operative input, character/respawn binding, and responsive camera-relative movement intent
- `CombatContracts` — shared stable combat IDs and server-authoritative pipeline data shapes; declarations only in LK-0201
- `FirearmConfig` — shared prototype balance home for the first basic firearm family
- `OperativeLifeContracts` — shared stable operative life IDs and server-authoritative health, transition, revive, solo-recovery, and squad-failure data shapes; initial declarations in LK-0301 with the focused failure vocabulary added by LK-0307
- `OperativeLifeConfig` — shared canonical initial P3 health, bleed-out, revive, solo-recovery, and failure-grace values
- `OperativeLifeService` — server-owned active-operative snapshots, monotonic commit revisions, character bindings, and central Alive eligibility
- `WeaponController` — local reload input plus non-authoritative automatic-targeting and firing presentation
- `SquadUIController` — personal status, teammate status, location aids, and operation information
- `PlayerService` — server-owned operative lifecycle, class assignment, and spawn state
- `MovementValidationSystem` — server sanity checks for operative movement and state restrictions
- `CombatSystem` — server-owned target acquisition, automatic firing, ammunition use, hits, health, damage, incapacitation, revival, and death
- `InventorySystem` — server-owned ammunition, recovery resources, and supply collection
- `ClassSystem` — server-owned specialist eligibility and class actions
- `VisibilitySystem` — gameplay-relevant discovery and squad-location rules
- `EnemySystem` — enemy lifecycle, pursuit, attacks, horde pressure, and special behaviors
- `ObjectiveSystem` — authored objective state and interactions
- `OperationService` — briefing, insertion, escalation, extraction, success, failure, and results
- `ProgressionService` — persistent XP, ranks, class unlocks, and data-store recovery

Names may be refined in the milestone that first needs them. Avoid duplicate managers or speculative frameworks.

## Reusable existing systems

- Repository layout, Rojo project mappings, bootstrap scripts, pinned toolchain, production documentation, and smoke/build workflows remain valid.
- `CameraController` and its explicit `init`, `start`, `stop`, and `destroy` lifecycle remain valid.
- The fixed overhead/elevated view, local-survivor follow framing, keyboard panning, mouse-wheel zoom, replacement-camera handling, and configurable focus-point bounds remain implemented and must not be deleted.
- `SurvivorController` now owns desktop movement input while active and temporarily disables `CameraController` keyboard panning, restoring it when stopped. Zoom, bounds, Scriptable mode, and both controllers' lifecycle behavior remain available.
- Current strict-mode and client/server/shared dependency rules remain valid.

The camera is a foundation, not a final survival control design. Its bounds must later be configured around the authored operation map. Giving survivor movement sole ownership of W/A/S/D and arrow keys remains the current input-conflict decision: keyboard camera panning is implemented but disabled during active survivor control. While that control is active, `CameraController` follows the local character's `HumanoidRootPart` on XZ, preserves the configured world-space focus height, and applies bounded frame-rate-independent smoothing. Existing working camera code should be extended only when a survival milestone demonstrates the need.

## Superseded RTS architecture

The former selection, unit-command, worker, resource-economy, building-placement, construction, production-queue, barracks, swordsman, army AI, and enemy Town Hall boundaries are not part of the active product. They are historical concepts in Git history, not planned modules. Generic ideas such as server authority, data-driven configuration, health, damage, enemies, and match state remain useful but must be specified for one-operative cooperative survival rather than reused as RTS contracts.

## Data-driven rules

Balance values belong in shared configuration modules rather than controller logic. Operative, weapon, class, enemy, wave, supply, objective, boss, rank, and operation definitions should use stable IDs and include only the data required by an implemented system. Authored operation configuration must be versionable and testable.

## Networking rules

- Use a small, explicit request and state-update surface.
- Validate operative state, class, visibility, line of sight, range, target legality, weapon readiness, cadence, ammunition, resource cost, and operation phase on the server.
- Rate-limit requests that can be spammed.
- Use server timestamps or equivalent state for cadence and reload validation.
- Send only information a client needs; limited visibility must not be undermined by replicating hidden tactical state through custom remotes.
- Do not design the MVP around exactly four array slots or fixed player indices; player collections and spawn assignment must tolerate a later limit of eight.
- Define reconnect, leave, and persistence-failure behavior before progression ships.

## Engineering standards

- Luau strict mode where practical
- One primary responsibility per module
- No ambiguous fallback names such as `Manager2` or `HelperFinal`
- No hidden balance constants inside algorithms
- No unrelated refactors in feature pull requests
- New behavior requires a manual verification path; deterministic logic should receive automated tests where feasible
- No gameplay implementation without a focused specification and acceptance criteria

## Performance policy

Measure the actual cooperative load rather than inheriting former RTS unit-count targets. Prototype with 1–4 players, representative horde counts, projectiles or raycasts, AI navigation, visibility effects, and operation scripting. Preserve a path to eight players by avoiding per-player duplication of global enemy work and unbounded per-entity polling loops. Profile before complex optimization.

## Dependency direction

UI and controllers may call shared interfaces. Server systems may depend on shared configuration and utilities. Shared code must not depend on client-only or server-only modules. Persistent progression must not become a dependency of moment-to-moment combat correctness; a match must fail safely if data services are unavailable.

## P3 declaration boundary

`OperativeLifeContracts` and `OperativeLifeConfig` are safe to require from either side of the client/server boundary, but shared availability does not grant authority. The server owns every consequential health, life-state, incapacitation, revive, solo-recovery, death, timestamp, and squad-viability value. A client may read only a deliberately disclosed snapshot and, in a later task, request a revive target and hold phase; it never determines eligibility, distance, line of sight, timing, progress, completion, restored health, death, or failure.

`OperativeLifeService` is the production same-server runtime owner introduced by LK-0305. It derives identity from registered `Player.UserId`, initializes an `Alive` snapshot at `100/100`, returns only deep copies, and commits accepted LK-0302 through LK-0304 resolver output only when its expected service-owned revision matches. Commit validation checks identity, structure, health/life invariants, legal state direction, and monotonic authoritative time before replacing the whole snapshot and incrementing the revision. Player removal tears down the owned lifetime. LK-0307 adds copied roster reads, server-only registration/removal notifications, and one narrow operation-start eligibility flag so a solo incapacitation can receive canonical pending-recovery timing without trusting a client.

`SquadFailureEvaluator` is the pure LK-0307 viability and grace resolver. `SquadFailureService` owns the one `Viable`/`Pending`/`Failed` state, monotonic revision, frozen participant identities, solo/multiplayer history, late-join prohibition, abandonment fact, life/roster subscriptions, and one deadline timer. It consumes only copied life snapshots and `Workspace:GetServerTimeNow()`. Final disconnect removes viability immediately and marks abandonment; registrations after operation start are ignored, and committed failure is terminal. No client mutation remote, result framework, or broader operation state machine is introduced.

Alive is the single movement/combat eligibility state. Incapacitated and Dead set reversible Humanoid locomotion controls to zero without anchoring or destroying the character, and the P1 server sanity boundary neutralizes replicated displacement. The P2 Studio combat owner queries the same service, clears reload and selected target on restriction, and preserves ammunition, cadence, and processed ShotIds; return to Alive derives readiness without refilling. `Players.CharacterAutoLoads` is disabled and characters are loaded/bound deliberately, so replacement reapplies the existing snapshot and cannot revive an Incapacitated or Dead operative. Humanoid health is not P3 authority: the Humanoid remains a positive-health locomotion shell with Roblox's Dead state disabled, while the P3 snapshot is the only operative health/life truth. LK-0306 routes authoritative ordinary damage through the service-owned snapshot, the pure LK-0302 resolver, and the existing atomic commit/restriction boundary. The snapshot's processed-damage set remains the only replay owner.

LK-0308 adds one server life-runtime owner for finishing damage and the earliest stored bleed-out or solo-recovery deadline. It invokes the existing pure resolvers and commits through `OperativeLifeService`; stale callbacks cannot commit because revision and canonical deadline are re-read. One revive-session owner accepts only a rate-limited target-and-phase intent, derives sender, operation membership, state, range, line of sight, timing, movement, damage, character, and connection continuity on the server, and atomically coordinates the accepted life and P2 combat companion results. No client remote accepts damage, health, life state, time, progress, completion, recovery, death, or failure. The only new client authority request is `OperativeLifeNetwork.ReviveIntent` with the exact shape `{ targetOperativeEntityId, phase = "Begin" | "End" }`. Copied Player attributes and a plain debug label are temporary prototype disclosure, not authority. Persistence, result flow, production presentation, and P4 remain absent.

## Change policy

Architecture exists to support the next playable milestone. A new abstraction must solve a present, demonstrated need or remove meaningful duplication. P1 is complete and remains unchanged. LK-0201 through LK-0207 remain the accepted P2 contract, resolver, presentation, and Studio-harness boundary. LK-0301 through LK-0304 provide the shared declarations and pure P3 transitions. LK-0305 adds same-server snapshot ownership and restrictions; LK-0306 adds authoritative ordinary-damage routing into that owner; LK-0307 adds focused squad-failure evaluation and ownership; LK-0308 completes the narrow runtime integration and validation slice. P3 is complete. P4 is the next planned milestone and remains unstarted.
