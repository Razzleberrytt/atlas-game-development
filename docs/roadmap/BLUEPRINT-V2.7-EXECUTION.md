# Blueprint v2.7 Execution Authority

Blueprint v2.7 is the active **runtime stabilization and observability authority** for Atlas as of 2026-08-07. It controls the state/presentation rollout, evidence capture, compatibility removal, and promotion decisions for that lane.

For whether unrelated development may proceed while these gates remain open, [`PARALLEL-DEVELOPMENT-POLICY.md`](PARALLEL-DEVELOPMENT-POLICY.md) controls. **v2.7 is not a blanket project freeze.**

This is a rollout and observability release, not a gameplay-scope release. It does not claim that every active Roblox Studio path is repaired. It defines how the affected runtime path is instrumented, migrated, soaked, rolled back, and finally accepted.

## Release intent

Version 2.7 exists to close the gap between a statically coherent repository and runtime paths that still require state/presentation proof.

The release must make these facts observable and provable:

1. every producer and consumer of legacy runtime state is known;
2. state is delivered only after a usable client listener exists;
3. unchanged current state does not generate repeated network sends;
4. independent current facts are retained by semantic key before readiness;
5. route, landmark, mark, and similar presentation have one client owner;
6. reset, respawn, late join, streaming, and disconnect return runtime gauges to baseline;
7. compatibility code is removed only after its replacement has accepted evidence and a rollback checkpoint.

### Scope rule

v2.7 does **not** itself promote or verify new biomes, classes, enemy families, weapon families, dungeon themes, progression layers, monetization systems, or live-service systems. Those features may nevertheless be designed, implemented, tested, and merged in parallel under the Parallel Development Policy when their direct dependencies are satisfied.

A v2.7 gate blocks only:

- claiming the affected runtime path accepted/verified;
- unsafe activation that depends on unresolved behavior;
- a directly conflicting integration that cannot be isolated.

It does not block source-safe or dependency-safe work elsewhere.

## Product promise

The product direction remains the same: build a polished, replayable cooperative action-RPG expedition while continuing modular development across the broader product.

```text
prepare
→ choose weapon
→ outdoor route
→ readable mixed combat
→ information/discovery ability
→ short repeatable dungeon
→ elite
→ randomized item decision
→ boss
→ return
→ voluntarily begin another run
```

Existing Living Kingdoms systems are assets to reconcile with that promise. The roadmap does not require deleting working code merely because an earlier blueprint used different names or implementation shapes.

## Authority order

When project materials disagree, use this order:

```text
accepted runtime evidence / current Roblox platform behavior
→ PARALLEL-DEVELOPMENT-POLICY.md for scope/parallel-work decisions
→ BLUEPRINT-V2.7-EXECUTION.md + PRODUCTION-CORE-V2.7.md for the stabilization lane
→ ACTIVE-PLACE-ROLLOUT-V2.7.md + CROSS-SYSTEM-TRACEABILITY-V2.7.md
→ current specialist bibles and accepted specifications
→ docs/architecture/technical-blueprint.md
→ earlier roadmap checkpoints
```

Historical closing directives are context, not orders.

### Conflict rule

1. Identify the authority class: mechanical, replication, presentation, authoring, operational, scope, or historical.
2. Prefer accepted runtime evidence over authored prose.
3. For whether unrelated work may proceed, use the Parallel Development Policy.
4. Do not allow a presentation implementation to acquire mechanical authority merely because it is convenient.
5. Record material conflict resolutions in `docs/decisions/` and update the Production Core when appropriate.

## Evidence scale

- **E0** — design only
- **E1** — source assembled/static checks
- **E2** — Studio starts and required systems initialize
- **E3** — single-player integrated behavior demonstrated
- **E4** — multiplayer and adversarial behavior demonstrated
- **E5** — device/performance/reliability demonstrated
- **E6** — outside-player fun demonstrated
- **E7** — live telemetry demonstrated

**Current claimed level: E2.** The accepted pinned-artifact Studio packet is [`../production/evidence/2026-08-08-r1-playable-replay-loop.md`](../production/evidence/2026-08-08-r1-playable-replay-loop.md). It proves only the claims it records. A roadmap commit alone cannot promote evidence level.

## Rollout stages

Use one controlled variable at a time inside the stabilization lane:

```text
R0 — instrument only
R1 — earliest effective state listener
R2 — client-ready delivery gate
R3 — semantic-key/change-token suppression
R4 — centralized presentation ownership
R5 — compatibility-removal candidate
```

A stage advances only when its expected counter changes and visible behavior match. Parallel work in other lanes may continue while a stage is open.

## Runtime state contract

### Client startup

```text
construct application-scope controllers
→ bind required state listeners
→ declare ClientReady
→ receive authoritative current state/snapshot
→ consume semantic current-state updates
```

Do not rely on a server continuously replaying state until the client happens to connect.

### Semantic keys

A current fact must have a stable semantic key, for example:

```text
round.phase
objective.current
route.target
landmark.active_set
horde.pressure
status.marked:<entityId>
modifier.warden_shield:<entityId>
```

Independent current facts must not overwrite one another merely because they share one physical `RemoteEvent`.

### Change tokens

A change token is derived from state mutation, not wall-clock time. Wall-clock time, frame number, and random GUID-per-publish tokens defeat unchanged-state suppression and are invalid.

### Pre-ready retention

If current state must survive before `ClientReady`, retain the latest value by:

```text
player + remote id + semantic key
```

On readiness, reconstruct the current state once, then clear the pending structure.

### Delivery diagnostics

Record at minimum:

```text
Attempts
Accepted
SuppressedUnchanged
Sent
BufferedLatest
SuppressedBeforeReady
```

## Presentation ownership contract

One semantic primitive has one presentation owner.

```text
Highlight             → one shared Highlight lease registry
route guide            → RouteGuidePresentationController
landmark accent        → LandmarkAccentPresentationController
status/mark outline    → status presentation through the same Highlight registry
viewmodel              → one viewmodel/weapon presentation owner
camera modifiers       → one named modifier stack
temporary VFX          → scoped pool/effect owner
animation marker hooks → owning animation/track scope
```

Production Highlights may not target `Workspace`, broad map roots, or other oversized containers. Stable semantic targets must survive streaming.

## Lifecycle contract

Application, character, and operation/round lifetimes are separate scopes. Reset and respawn acceptance requires counters and presentation-object gauges to return to their named baselines. Generation tokens or equivalent cancellation guards must prevent stale asynchronous work from mutating a newer scope.

## Required observability

The development overlay/logging path should expose enough information to answer:

```text
ClientReady state
legacy State listener count
messages/sec by channel and semantic key
Attempts / Accepted / SuppressedUnchanged
BufferedLatest / SuppressedBeforeReady / Sent
managed connection count by scope
active Highlight leases by channel
broad-target violations
active transient presentation objects
viewmodel/camera owner count
animation tracks and marker-listener counts
streaming rebind count
unresolved semantic targets
```

## Cutover ledger

Every legacy producer and effective consumer receives a ledger row containing call site, runtime domain, owner, semantic key, change token, rates, feature flag, replacement path, evidence packet, rollback checkpoint, and status.

## Tickets 331–360

### Baseline and inventory — 331–335

| # | Ticket |
|---|---|
| 331 | Freeze a development copy and record build identity. |
| 332 | Fill the cutover ledger with every `HordeNetwork.State` producer. |
| 333 | Record every effective client listener and owning controller. |
| 334 | Capture baseline State messages/sec and pending queue symptoms. |
| 335 | Capture Highlight owner/Adornee inventory and baseline gauges. |

### State cutover — 336–345

| # | Ticket |
|---|---|
| 336 | Enable the earliest listener for one development place only. |
| 337 | Verify exactly one effective legacy listener and no doubled presentation. |
| 338 | Enable the ready gate and delayed-controller test. |
| 339 | Migrate the first producer behind semantic key + change token. |
| 340 | Prove unchanged attempts are suppressed and network sends fall. |
| 341 | Migrate round-state producer. |
| 342 | Migrate objective-state producer. |
| 343 | Migrate route-state producer. |
| 344 | Migrate landmark-state producer. |
| 345 | Capture before/after per-key rate diff. |

### Presentation ownership — 346–350

| # | Ticket |
|---|---|
| 346 | Route route-guide highlighting through centralized lease ownership. |
| 347 | Route landmark highlighting through centralized lease ownership. |
| 348 | Enable broad-target rejection and audit every violation. |
| 349 | Run stream-out/rebind for route, landmark, secret, and marked target. |
| 350 | Capture baseline/peak/end presentation gauges. |

### Soak and closure — 351–360

| # | Ticket |
|---|---|
| 351 | Run five resets and compare counters/gauges. |
| 352 | Run three respawns and compare listeners/viewmodel/presentation gauges. |
| 353 | Run delayed-ready and late-join matrix. |
| 354 | Run two-player reset/disconnect matrix. |
| 355 | Run 100 animation plays and verify listener stability. |
| 356 | Run ten-minute active network/presentation soak. |
| 357 | Capture representative client/server profiling/network evidence. |
| 358 | Close all P0/P1 rollout defects and rerun affected matrix. |
| 359 | Assemble incident closure packet and promotion review. |
| 360 | Remove compatibility only for ledger rows with accepted replacement evidence and a retained rollback checkpoint. |

Ticket 360 is a removal gate, not permission to delete every compatibility path at once.

## Promotion gate

Do not advance the **v2.7 stabilization lane** because a warning disappears once. Promotion requires captured evidence that its applicable invariants hold. Parallel feature work may continue meanwhile, but cannot use unfinished v2.7 evidence as proof of production readiness.

## Stop conditions

Stop and fix **the affected integration path** when:

- remote queue/discard warnings occur in supported normal play;
- producer/network rate grows across reset without a gameplay reason;
- application/character/round connection counts leak;
- a broad Highlight hides gameplay or two controllers fight for the same primitive;
- late join or delayed readiness reconstructs incomplete current state;
- stream-out is treated as gameplay completion;
- animation marker listeners multiply across repeated plays;
- viewmodel or camera ownership duplicates after respawn;
- damage, cooldown, loot, inventory, progression, or ownership can be client-authored;
- low-graphics/mobile presentation loses critical gameplay information.

A stop condition does **not** automatically stop unrelated lanes that do not share the failing dependency. If the work can be isolated safely, continue it under the Parallel Development Policy.

## Parallel development while rollout remains open

While Tickets 331–360 are unfinished, teams/agents may continue high-ROI work across gameplay, RPG, Main World/environment, content factories, progression/persistence preparation, product/business preparation, and developer tooling.

Prefer modular, reversible increments. Keep risky activation behind explicit boundaries. Do not create duplicate authorities. Do not relabel unverified work as verified.

## Companion documents

- [`PARALLEL-DEVELOPMENT-POLICY.md`](PARALLEL-DEVELOPMENT-POLICY.md) — controls whether unrelated work may proceed.
- [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md) — daily-use runtime stabilization rules.
- [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md) — rollout stages, counters, ledger, rollback, and closure packet.
- [`CROSS-SYSTEM-TRACEABILITY-V2.7.md`](CROSS-SYSTEM-TRACEABILITY-V2.7.md) — ownership and evidence by player-facing state.
- [`QUALITY-AUDIT-V2.7.md`](QUALITY-AUDIT-V2.7.md) — static quality facts and runtime reality boundary.
- [`README.md`](README.md) — roadmap precedence and historical index.

> Stabilize the affected road rigorously. Keep building everywhere else.
