# Blueprint v2.7 Execution Authority

Blueprint v2.7 is the active production authority for Atlas as of 2026-08-07. It supersedes Blueprint v2.3 for execution order, runtime-state rollout, presentation ownership, evidence capture, and promotion decisions.

This is a **rollout and observability release**, not a gameplay-scope release. It does not claim that the active Roblox Studio place is repaired. It defines how the existing place is instrumented, migrated, soaked, rolled back, and finally accepted.

## Release intent

Version 2.7 exists to close the gap between a statically coherent repository and an active place that still shows runtime presentation/network symptoms.

The release must make these facts observable and provable:

1. every producer and consumer of legacy runtime state is known;
2. state is delivered only after a usable client listener exists;
3. unchanged current state does not generate repeated network sends;
4. independent current facts are retained by semantic key before readiness;
5. route, landmark, mark, and similar presentation have one client owner;
6. reset, respawn, late join, streaming, and disconnect return runtime gauges to baseline;
7. compatibility code is removed only after its replacement has accepted evidence and a rollback checkpoint.

### Explicit non-goals

Version 2.7 does not authorize a new biome, class, enemy family, weapon family, dungeon theme, broad progression layer, monetization system, or live-service expansion. It also does not mark any Studio-only gate complete without captured evidence.

## Product promise

The product direction remains the same: build one polished, replayable cooperative action-RPG expedition before expanding the world.

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
→ BLUEPRINT-V2.7-EXECUTION.md + PRODUCTION-CORE-V2.7.md
→ ACTIVE-PLACE-ROLLOUT-V2.7.md + CROSS-SYSTEM-TRACEABILITY-V2.7.md
→ current specialist bibles and accepted specifications
→ docs/architecture/technical-blueprint.md
→ earlier roadmap checkpoints
```

Historical closing directives are context, not orders.

### Conflict rule

1. Identify the authority class: mechanical, replication, presentation, authoring, operational, or historical.
2. Prefer accepted runtime evidence over authored prose.
3. If both are prose, prefer the newer canonical layer.
4. Do not allow a presentation implementation to acquire mechanical authority merely because it is convenient.
5. Record material conflict resolutions in `docs/decisions/` and update the Production Core.

## Evidence scale

- **E0** — design only
- **E1** — source assembled/static checks
- **E2** — Studio starts and required systems initialize
- **E3** — single-player integrated behavior demonstrated
- **E4** — multiplayer and adversarial behavior demonstrated
- **E5** — device/performance/reliability demonstrated
- **E6** — outside-player fun demonstrated
- **E7** — live telemetry demonstrated

**Current claimed level: E2.** The accepted pinned-artifact Studio packet is
[`../production/evidence/2026-08-08-r1-playable-replay-loop.md`](../production/evidence/2026-08-08-r1-playable-replay-loop.md).
It proves initialization and the R1/replay claims it records; it does not claim E3–E5. A roadmap commit alone cannot promote evidence level.

## Active Studio incidents

The active-place screenshot captured on 2026-08-07 showed two blocking symptoms:

1. `ReplicatedStorage.HordeNetwork.State` invocation-queue exhaustion/discard warnings;
2. escaped broad blue/yellow `Highlight` presentation.

The screenshot proves symptoms, not exact root causes. The producer scripts, effective listener lifetime, send-rate growth, bad `Adornee`, duplicate ownership, and any `.rbxl`-only code remain facts to measure in the active place.

**2026-08-08 update:** R1 containment passed on the newly pinned CI artifact with zero queue/discard warnings and zero enabled broad Highlight targets. The flat false-color editor view encountered during the run was independently traced to hidden local Studio physics-visualization flags, not gameplay Highlight state. This does not skip CL-002/CL-003 consolidation, R2 readiness, R3 suppression, or later lifecycle matrices.

## Rollout stages

Use one controlled variable at a time:

```text
R0 — instrument only
R1 — earliest effective state listener
R2 — client-ready delivery gate
R3 — semantic-key/change-token suppression
R4 — centralized presentation ownership
R5 — compatibility-removal candidate
```

A stage advances only when its expected counter changes and visible behavior match. A flag is temporary architecture; every flag requires an owner, rollback trigger, evidence gate, and planned removal condition.

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

A current fact must have a stable semantic key. Examples:

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

A change token is derived from state mutation, not wall-clock time.

Good tokens include a revision, sequence incremented on mutation, enum + relevant counters, or another deterministic state revision. `os.clock()`, server time, frame number, and a random GUID per publish defeat unchanged-state suppression and are invalid as change tokens.

### Pre-ready retention

If current state must survive before `ClientReady`, retain the latest value by:

```text
player + remote id + semantic key
```

not merely by player + remote. On readiness, reconstruct the current state once, then clear the pending structure.

### Delivery diagnostics

For each semantic key record at minimum:

```text
Attempts
Accepted
SuppressedUnchanged
```

For each delivery channel record:

```text
Sent
BufferedLatest
SuppressedBeforeReady
```

This separates noisy gameplay producers from readiness problems.

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

Production Highlights may not target `Workspace`, broad map roots, or other oversized containers. Controllers request semantic presentation; they do not each create competing primitives.

Stable semantic targets must survive streaming. A locally missing Instance is not equivalent to gameplay completion.

## Lifecycle contract

Application, character, and operation/round lifetimes are separate scopes.

Reset and respawn acceptance requires counters and presentation-object gauges to return to their named baselines. A controller that reconnects on every round without disconnecting its prior listeners is a blocking defect even when the screen looks correct for one run.

Generation tokens or equivalent cancellation guards must prevent stale asynchronous work from mutating a newer character, run, target, or presentation scope.

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

Observability must be bounded and removable from production presentation. It may not leak private or security-sensitive data.

## Cutover ledger

Every legacy producer and effective consumer receives a ledger row:

```text
legacy call site
runtime domain
owner
semantic key
change token
current rate
post-migration rate
feature flag
replacement path
evidence packet
rollback checkpoint
status
```

Do not use “we think these are all the producers” as a completion condition.

The initial inventory must cover at least round state, objective state, route state, landmark state, and any horde/threat state still carried by `HordeNetwork.State`.

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
| 357 | Capture representative client/server MicroProfiler/network evidence. |
| 358 | Close all P0/P1 rollout defects and rerun affected matrix. |
| 359 | Assemble incident closure packet and promotion review. |
| 360 | Remove compatibility code only for ledger rows with accepted replacement evidence and a retained rollback checkpoint. |

Ticket 360 is a removal gate, not permission to delete every compatibility path at once.

## Promotion gate

Do not advance because the warning disappears once. Promotion requires captured evidence that:

```text
all legacy producers/consumers are inventoried
exactly one intended compatibility listener exists while required
pre-ready current state is gated/retained intentionally
semantic publish rate is bounded by change
unchanged attempts are suppressed
0 queue/discard warnings occur in accepted normal-play soak
route and landmark presentation have one owner
0 broad production Highlight targets exist
stream-out/rebind preserves semantic truth
five-reset gauges return to baseline
three-respawn gauges return to baseline
late join reconstructs current state
100 animation plays do not multiply marker listeners
two-player reset/disconnect attribution and cleanup pass
compatibility removal has a rollback checkpoint
```

Only then may the project update its evidence ledger and remove the corresponding compatibility bridge.

## Stop conditions

Stop and fix before adding scope when:

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

## What follows accepted rollout evidence

After Tickets 331–360 close with accepted evidence, choose the next dependency from actual failure and retention evidence. The likely sequence remains:

1. accepted durable persistence/value proof;
2. preparation/outdoor-route integration;
3. procedural dungeon runtime and boss integration;
4. outside-player repeat-intention testing.

Do not use a cleaner state channel as an excuse to resume broad feature expansion before the integrated loop is trusted.

## Companion documents

- [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md) — daily-use current authority.
- [`ACTIVE-PLACE-ROLLOUT-V2.7.md`](ACTIVE-PLACE-ROLLOUT-V2.7.md) — rollout stages, counters, ledger, rollback, and closure packet.
- [`CROSS-SYSTEM-TRACEABILITY-V2.7.md`](CROSS-SYSTEM-TRACEABILITY-V2.7.md) — ownership and evidence by player-facing state.
- [`QUALITY-AUDIT-V2.7.md`](QUALITY-AUDIT-V2.7.md) — static quality facts and the runtime reality boundary.
- [`README.md`](README.md) — roadmap precedence and historical index.

> Stabilize the old road before closing it. Remove the bridge only when accepted evidence proves nobody still depends on it.
