# Atlas Production Core — Version 2.7

**Purpose:** daily-use canonical reference for implementation, Studio rollout, review, and production decisions. If this file conflicts with an older roadmap checkpoint, this file controls unless accepted runtime evidence or current Roblox behavior says otherwise.

**Release date:** 2026-08-07  
**Runtime status:** E2 accepted on the pinned R1 CI artifact; E3–E5 remain open.
**Active queue:** Tickets 331–360 in [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md).

## 1. North star

Build one polished, replayable cooperative action-RPG expedition before expanding into a large world.

The experience should combine readable combat, meaningful information/positioning decisions, randomized equipment/build identity, discovery, and cooperation. A new player should understand what happened, trust rewards and combat outcomes, and voluntarily begin another run.

## 2. Current authority

Use this precedence:

```text
accepted runtime evidence / current platform behavior
→ Production Core v2.7 + Blueprint v2.7 Execution Authority
→ Active-Place Rollout v2.7 + Cross-System Traceability v2.7
→ current specialist bibles/specifications
→ technical blueprint
→ historical roadmap checkpoints
```

Historical documents explain provenance; they do not override current execution order.

## 3. Product laws

1. One polished repeatable loop outranks broad unfinished scope.
2. Combat is intense but readable.
3. Enemies and objectives create tactical questions, not only damage throughput.
4. Cooperation adds interactions, recovery, coordination, and information—not only health scaling.
5. The server owns valuable truth.
6. Clients submit intent, never consequential outcomes.
7. Current state has one mechanical owner, one replication path, and one presentation owner.
8. Critical information survives low graphics, reduced motion, streaming, respawn, and reset.
9. Valuable mutations are deterministic/idempotent where replay is possible.
10. Runtime evidence outranks confident prose.

## 4. Evidence scale

```text
E0 design only
E1 source assembled / static acceptance
E2 Studio starts and required systems initialize
E3 single-player integrated behavior demonstrated
E4 multiplayer/adversarial behavior demonstrated
E5 device/performance/reliability demonstrated
E6 outside-player fun demonstrated
E7 live telemetry demonstrated
```

**Current claimed level: E2.** The accepted packet is
[`../production/evidence/2026-08-08-r1-playable-replay-loop.md`](../production/evidence/2026-08-08-r1-playable-replay-loop.md).
Do not report E3–E5 without their required evidence.

## 5. Current release blockers

R1 containment is accepted on the pinned artifact: zero queue/discard warnings, zero enabled broad Highlight targets, and a clean initialization/replay boundary. The flat blue/yellow/green editor view encountered during validation was traced to hidden local Studio physics-visualization flags rather than gameplay Highlight presentation.

Single-listener consolidation is accepted. Remaining runtime blockers are R2 delayed-ready/current-state delivery, R3 semantic suppression, centralized presentation ownership, and the reset/respawn/late-join/multiplayer/streaming matrices. The transport-agnostic R2 keyed-readiness primitive is source-prepared behind a disabled flag; preserve the R1 checkpoint and activate it only as a separate controlled stage change.

## 6. Runtime state law

Client startup:

```text
construct application controllers
→ bind required state listeners
→ ClientReady
→ reconstruct current authoritative state
→ consume semantic state changes
```

Do not continuously replay current state because the server does not know whether the client is ready.

### Semantic-key rule

Current state is identified by a semantic key, for example:

```text
round.phase
objective.current
route.target
landmark.active_set
horde.pressure
status.marked:<entityId>
```

Independent current facts must not overwrite each other merely because they share one `RemoteEvent`.

### Change-token rule

Only a real state mutation changes the token. Never use wall-clock time, frame number, or a new GUID per publish as the change token.

### Pre-ready retention

Retain current state by:

```text
player + remote + semantic key
```

Flush one current value per key when the client becomes ready, then clear the pending structure.

### Observability

Track at minimum:

```text
Attempts
Accepted
SuppressedUnchanged
Sent
BufferedLatest
SuppressedBeforeReady
messages/sec by domain/key
```

## 7. Presentation ownership

Exactly one owner per visual primitive:

```text
Highlight             → shared Highlight lease registry
route guide            → RouteGuidePresentationController
landmark accent        → LandmarkAccentPresentationController
status/mark outline    → status presentation via Highlight registry
viewmodel              → one viewmodel owner
camera modifiers       → one named modifier stack
temporary effects      → scoped effect owner/pool
animation marker hooks → owning track/controller scope
```

Production Highlights may not target `Workspace`, broad map roots, or similarly oversized containers.

A streamed-out Instance is locally unavailable; that is not equivalent to gameplay completion. Stable semantic IDs must allow rebinding when the instance returns.

## 8. Lifecycle law

Separate:

- application scope;
- character scope;
- operation/round scope.

Every connection and transient presentation object belongs to one scope and is released when that scope ends.

Use generation tokens or equivalent cancellation guards so stale async work cannot mutate a newer character, round, target, viewmodel, or presentation lease.

## 9. Rollout stages

```text
R0 instrument only
R1 earliest effective state listener
R2 ready-gated delivery
R3 semantic suppression
R4 centralized presentation ownership
R5 compatibility-removal candidate
```

Change one architectural variable at a time. Advance only after counters and visible behavior match expectations.

## 10. Rollout flags

Use temporary flags for architectural cutover only, such as:

```text
EnableRuntimeCounters
EnableEarlyStateListener
EnableReadyGatedStatePublisher
EnableSemanticStateSuppression
UseManagedRoutePresentation
UseManagedLandmarkPresentation
RejectBroadHighlightTargets
EnableSoakAssertions
```

Every flag requires an owner, introduction version, expected metric change, rollback trigger, and removal gate. Do not create a permanent flag graveyard.

## 11. Cutover ledger

Every legacy producer/consumer row records:

```text
call site
runtime domain
owner
semantic key
change token
baseline rate
post-migration rate
feature flag
replacement path
evidence packet
rollback checkpoint
status
```

The ledger is complete only after every producer and effective listener has been identified.

## 12. Active execution queue

### 331–335 — establish truth

1. Freeze a development copy and record build identity.
2. Inventory every `HordeNetwork.State` producer.
3. Inventory every effective client listener and owner.
4. Capture baseline State messages/sec and queue symptoms.
5. Capture Highlight owner/Adornee inventory and baseline gauges.

### 336–345 — state cutover

6. Enable earliest listener in the development place.
7. Prove exactly one effective compatibility listener and no doubled presentation.
8. Enable ready-gated delivery and delayed-controller test.
9. Migrate one producer behind semantic key + change token.
10. Prove unchanged publishes suppress and actual network sends fall.
11. Migrate round state.
12. Migrate objective state.
13. Migrate route state.
14. Migrate landmark state.
15. Capture before/after per-key rate differences.

### 346–350 — presentation ownership

16. Move route-guide highlighting behind centralized lease ownership.
17. Move landmark highlighting behind centralized lease ownership.
18. Enable broad-target rejection and investigate every violation.
19. Run stream-out/rebind for route, landmark, secret, and marked target.
20. Capture baseline/peak/end presentation gauges.

### 351–360 — soak and closure

21. Run five resets and compare gauges/rates.
22. Run three respawns and compare listeners/viewmodel/presentation gauges.
23. Run delayed-ready + late-join matrix.
24. Run two-player reset/disconnect matrix.
25. Run 100 animation plays and prove marker-listener stability.
26. Run a ten-minute active network/presentation soak.
27. Capture representative client/server profiling/network evidence.
28. Close all P0/P1 rollout defects and rerun affected matrices.
29. Assemble incident closure packet and promotion review.
30. Remove compatibility only for ledger rows with accepted replacement evidence and a retained rollback checkpoint.

## 13. Promotion gate

Do not promote because one test run looked clean. Require captured facts:

```text
all State producers/consumers inventoried
intended compatibility listener count understood
pre-ready state intentionally gated/retained
unchanged state suppressed
state send rate bounded by semantic change
0 queue/discard warnings in accepted normal-play soak
0 broad production Highlight targets
one presentation owner per migrated primitive
stream-out/rebind preserves semantic truth
five-reset gauges return to baseline
three-respawn gauges return to baseline
late join reconstructs current state
100 animation plays do not multiply marker listeners
two-player reset/disconnect cleanup passes
```

## 14. Stop conditions

Stop and fix before adding scope when:

- remote queue/discard warnings occur;
- state rate or connections grow across reset without a gameplay reason;
- broad Highlights hide gameplay;
- multiple controllers own the same primitive;
- delayed readiness/late join loses current state;
- stream-out is treated as completion;
- animation marker listeners multiply;
- viewmodel/camera ownership duplicates after respawn;
- damage, rewards, inventory, progression, or ownership can be client-authored;
- critical cues disappear on low graphics/mobile.

## 15. Scope protection

Do not use the rollout cleanup as permission to add multiple regions, PvP, raids, housing, unrestricted trading, battle passes, dozens of classes, hundreds of legendary items, vehicles, or other broad expansion.

After rollout acceptance, choose the next dependency from evidence. Likely sequence:

1. durable persistence/value proof;
2. preparation/outdoor-route integration;
3. procedural dungeon and boss integration;
4. outside-player repeat-intention testing.

## 16. Daily review checklist

```text
What changed?
Which runtime owner changed it?
Which rollout stage is active?
What did Attempts/Accepted/Suppressed do?
Did actual sends fall or rise?
Did connection/presentation gauges return to baseline?
Did late join/reset/respawn still pass?
Did server authority change?
What evidence packet was updated?
What is the smallest next dependency?
```

> Instrument first. Migrate one owner at a time. Remove compatibility only when the evidence says the bridge is empty.
