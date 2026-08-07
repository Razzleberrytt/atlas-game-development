# Active-Place Rollout & Observability — Version 2.7

This document controls how the active Living Kingdoms place is migrated away from the legacy runtime-state/presentation path without turning the migration layer into permanent architecture.

It is subordinate only to accepted runtime evidence and the v2.7 Execution Authority/Production Core.

## 1. Rollout objective

Close the two observed active-place symptoms with measurable evidence:

- `HordeNetwork.State` queue/discard warnings;
- escaped broad Highlight presentation.

The target is not “hide the warning.” The target is a bounded, observable state-delivery path and single-owner presentation path that survive reset, respawn, delayed readiness, late join, streaming, disconnect, and repeated play.

## 2. Rollout stages

| Stage | Change | Exit evidence |
|---|---|---|
| R0 | Instrument only | producer/consumer/Highlight inventories and baseline counters captured |
| R1 | Earliest effective state listener | exactly one intended compatibility listener, no doubled presentation |
| R2 | ClientReady delivery gate | delayed-ready case has no queue warning and current state reconstructs |
| R3 | Semantic state suppression | unchanged attempts suppress; actual sends fall; visible state unchanged |
| R4 | Centralized presentation ownership | route/landmark/mark primitives have one owner; broad-target violations zero |
| R5 | Compatibility-removal candidate | closure packet accepted and rollback checkpoint retained |

Do not combine multiple stage changes in one uncontrolled publish.

## 3. Feature flags

Recommended rollout flags:

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

Each row in the rollout ledger must name the relevant flag, rollback trigger, and removal gate.

## 4. Cutover ledger

The ledger is the migration source of truth.

Required columns:

```text
Legacy Call Site
Domain
Owner
Semantic Key
Change Token
Baseline Attempts/sec
Baseline Sends/sec
Post-Migration Attempts/sec
Post-Migration Sends/sec
Flag
Replacement
Evidence Packet
Rollback Checkpoint
Status
```

Initial domains to inventory:

```text
round.phase
objective.current
route.target
landmark.active_set
horde/threat state
```

Delete dead payload fields rather than migrating them ceremonially.

## 5. Consumer inventory

Record every effective `HordeNetwork.State.OnClientEvent` connection:

```text
owning LocalScript/controller
created at application/character/round scope
exists before first publish? yes/no
recreated on respawn? yes/no
recreated on reset? yes/no
mutates UI? Highlights? route? camera? other state?
```

While the compatibility remote exists, prefer exactly one compatibility listener that dispatches to domain controllers. Do not let every controller open its own legacy listener.

## 6. StatePublisher contract

A semantic publisher answers:

```text
what current fact is this?
has it changed?
is the client ready?
if not, what latest value for this key must survive?
how many publish attempts occurred?
how many actual sends occurred?
```

Required API behavior:

```text
publish(player, remoteId, semanticKey, changeToken, payload)
```

The publisher rejects or suppresses unchanged `(semanticKey, changeToken)` pairs.

### Valid change tokens

- domain revision;
- sequence incremented only on mutation;
- stable state enum + relevant counters;
- equipment/profile revision;
- source/target relationship revision.

### Invalid change tokens

- `os.clock()`;
- `workspace:GetServerTimeNow()`;
- frame number;
- random GUID per publish.

## 7. Keyed pre-ready retention

Pending state must be retained by **player + remote + semantic key**.

Example:

```text
player
└── combat.modifier_state
    ├── target_A → latest state A
    ├── target_B → latest state B
    └── target_C → latest state C
```

A single “latest payload per RemoteEvent” buffer is insufficient whenever one remote carries multiple independent facts.

On `ClientReady`, reconstruct one current value per key in an explicitly safe order or through one snapshot schema, then clear pending state.

## 8. Counter dictionary

### Publisher counters by semantic key

- `Attempts`
- `Accepted`
- `SuppressedUnchanged`

### Delivery counters by remote/channel

- `Sent`
- `BufferedLatest`
- `SuppressedBeforeReady`

### Client gauges

- effective legacy listener count;
- managed connections by application/character/round scope;
- active Highlight leases by channel;
- broad-target violations;
- active transient effects;
- active viewmodel owners;
- active camera modifiers;
- active animation tracks;
- animation marker listeners;
- unresolved semantic targets;
- streaming rebind count.

Counters must be bounded. Diagnostics must not become the new performance bug.

## 9. Named baselines

Record a baseline packet for each relevant state:

```text
B0 — cold application after ClientReady
B1 — operation active, no encounter pressure
B2 — encounter active
B3 — operation reset complete
B4 — respawn complete
B5 — late join synchronized
B6 — post-soak cleanup
```

For each baseline record expected ranges for connections, leases, temporary objects, and send rates. Replace provisional ranges with measured accepted values.

## 10. Highlight migration

### Single registry

One client-side Highlight lease registry owns production Highlight Instances.

Suggested semantic channels:

```text
ThreatMark
Objective
Route
Landmark
SecretClue
SupportLink
Debug
```

Controllers request leases; they do not create independent competing Highlights.

### Broad-target rejection

Production requests must reject or loudly flag targets such as:

- `Workspace`;
- the entire map/world root;
- a biome root containing unrelated gameplay;
- the player character when a narrow world target was intended.

Debug-only broad targets must be explicit, visually distinct, and disabled for normal acceptance runs.

### Route cutover

`RouteGuidePresentationController` owns route semantics but requests its visible accent through the shared registry. On target change/reset/stream-out it releases or suspends the lease deterministically.

### Landmark cutover

`LandmarkAccentPresentationController` owns landmark semantic intent but uses the same shared registry. Route and landmark priority conflicts are resolved in one place, not by two Highlight Instances fighting on the model.

## 11. Streaming behavior

Presentation stores semantic IDs, not permanent assumptions about local Instance presence.

```text
semantic target active
+ Instance available → render
+ Instance streams out → release local primitive, keep semantic state
+ Instance returns → rebind and render
+ gameplay says target ended → clear semantic state
```

Do not treat `AncestryChanged`/missing Instance alone as objective completion.

## 12. Connection/lifecycle assertions

Every connection belongs to exactly one scope:

```text
ApplicationScope
CharacterScope
OperationScope
```

After reset, OperationScope returns to its B0/B1 expected count. After respawn, CharacterScope returns to its accepted count and old viewmodel/camera/marker listeners are gone.

Generation tokens or cancellation IDs must invalidate stale delayed work.

## 13. Required soak matrices

### Five-reset matrix

For each reset record:

```text
State attempts/sec
State sends/sec
legacy listener count
managed connection counts
Highlight leases
transient presentation objects
```

Pass: no monotonic leak and no warning/discard event.

### Three-respawn matrix

Pass when viewmodel, camera modifier, character connections, status presentation, and animation listeners return to accepted post-respawn baseline every time.

### Delayed-ready / late-join matrix

Pass when a deliberately delayed client can become ready without queue warnings and reconstruct all required current facts. A late joiner receives current state, not historical event spam.

### Two-player reset/disconnect matrix

Pass when one client leaving or resetting does not destroy the other client’s presentation state, duplicate listeners, misattribute state, or corrupt owner-specific UI.

### 100-animation-play matrix

Pass when marker-listener counts do not grow across 100 repeated plays and mechanical results remain server-owned.

### Ten-minute active soak

Pass when:

```text
queue/discard warnings = 0
send rate remains semantically bounded
connections remain bounded
Highlight leases remain bounded
broad-target violations = 0
post-soak cleanup returns to baseline
```

## 14. Rollback discipline

Before every stage change record:

```text
base commit/build id
feature flags
expected behavior
expected counter changes
rollback trigger
known-good rollback commit/build
```

Rollback restores one known version or flag configuration. Do not manually reverse a dozen unrelated Studio edits under pressure.

## 15. Closure packet

The queue/highlight incident closure packet contains:

```text
build identity
producer inventory
consumer inventory
before/after per-key rate table
ClientReady trace
five-reset table
three-respawn table
delayed-ready/late-join result
two-player result
Highlight owner/Adornee report
broad-target report
streaming rebind report
100-animation result
ten-minute soak summary
profiling/network captures
open defects
rollback checkpoint
promotion decision
```

The packet is accepted only when P0/P1 rollout defects are closed and rerun.

## 16. Compatibility-removal rule

Compatibility code is removed **per ledger row**, not by ceremony.

A row may be removed when:

1. replacement path is active;
2. replacement evidence is accepted;
3. old path receives no required traffic;
4. one rollback checkpoint is retained;
5. the removal does not make another unmigrated row lose state.

## 17. Definition of done

Version 2.7 rollout work is done when the active place—not merely the reference package—demonstrates:

```text
0 accepted-play queue/discard warnings
all State producers/consumers inventoried
semantic send rates bounded by mutation
all required current state reconstructs after delayed ready and late join
one owner for route/landmark/highlight primitives
0 broad production Highlight targets
reset and respawn gauges return to baseline
streaming rebind works
animation listener count remains bounded
multiplayer reset/disconnect cleanup passes
closure packet accepted
compatibility rows removed only where evidence permits
```

> A compatibility layer is scaffolding. Measure it, migrate through it, then remove it before it becomes the building.
