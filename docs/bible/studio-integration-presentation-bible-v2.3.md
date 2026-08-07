# Roblox Cooperative FPS RPG
## Studio Integration and Presentation Stability Bible — Version 2.3 Refined

**Release date:** 2026-08-07  
**Purpose:** Runtime integration authority for client readiness, replicated presentation, controller lifecycle, highlights, streaming, animation markers, diagnostics, and evidence.  
**Relationship:** Canonical companion to Master Blueprint v2.3. Chapters 161–180 preserve the Version 2.2 incident-response baseline; this file adds the Version 2.3 hardening appendix.

### Current incident status

The active Studio screenshot shows queue-exhaustion warnings for `ReplicatedStorage.HordeNetwork.State` and escaped blue/yellow highlight presentation. The exact producer/listener bug is not yet proven. Instrumentation and a clean soak are required before closure.

---

# 161. Version 2.2 Studio Integration and Presentation Stability Scope

## 161.1 Purpose

Version 2.2 converts the visual-production specification into a **runtime presentation contract**. Version 2.1 defined what the game should look like, how environments and animation should be authored, and what visual evidence must exist. Version 2.2 defines how those authored assets are allowed to connect to live replicated game state without producing duplicate listeners, stale highlights, queue overflow, runaway effects, streaming failures, or presentation that disagrees with server truth.

This release is motivated by real Studio evidence captured during development: the Output window reported repeated `Remote event invocation queue exhausted` messages for `ReplicatedStorage.HordeNetwork.State`, while the viewport showed large blue fills and widespread yellow outlines that were inconsistent with normal gameplay presentation. Those symptoms are treated as an integration incident, not as isolated cosmetic bugs.

## 161.2 Product Question

> Can the project start, restart, stream, change encounters, and update presentation for a full play session without network queues growing, listeners multiplying, or visual state escaping its intended owner?

A beautiful asset pipeline is not useful if the runtime presentation layer can accidentally highlight half the map or deliver state faster than a client can receive it.

## 161.3 Deliverables

Version 2.2 defines:

- client readiness and subscription order;
- initial state snapshot and subsequent delta contracts;
- reliable versus unreliable presentation channels;
- state coalescing and backpressure rules;
- controller lifecycle and connection ownership;
- centralized highlight/adornment ownership;
- route, landmark, objective, ability, and debug presentation channels;
- streaming-safe instance rebinding;
- presentation object pooling and lifetime rules;
- animation-track and marker listener ownership;
- viewmodel, camera, HUD, and VFX runtime integration;
- runtime diagnostics and Studio debug overlays;
- soak, restart, late-join, streaming, and low-frame-rate tests;
- a formal incident response for event queue exhaustion and runaway highlights;
- tickets 181–210.

## 161.4 Explicit Non-Claims

Version 2.2 does not claim that the current `.rbxl` place has been repaired from this environment. The screenshot provides evidence of symptoms, but source inspection inside the active Studio project is still required to identify the exact firing script, listener lifetime, or incorrect `Highlight.Adornee` assignment.

In particular, the apparent doubling pattern in dropped-event log counts is **not by itself proof of duplicate server loops**. The implementation must measure connection counts and send rates before attributing cause.

## 161.5 Promotion Standard

A presentation system may not be called stable because it looks correct for one minute. It advances only after:

```text
cold start
→ client ready
→ initial snapshot
→ state changes
→ encounter reset
→ character respawn
→ streaming out/in
→ late join
→ two-player observation
→ ten-minute soak
→ clean shutdown
```

with bounded network traffic, bounded connections, and visual state returning to baseline.

---

# 162. Runtime Bootstrap, Client Readiness, and Subscription Order

## 162.1 The Listener-Before-Traffic Law

For any server-to-client RemoteEvent whose data matters to current presentation, the client must bind its listener before the server begins recurring delivery.

Canonical order:

```text
ReplicatedFirst boot shell
→ shared module load
→ client controller Init()
→ remote listeners bind
→ presentation registries initialize
→ controller Start()
→ ClientReady handshake
→ server sends authoritative initial snapshot
→ normal delta traffic begins
```

The server must not assume `PlayerAdded` means presentation code is ready. Player existence, character existence, and client-controller readiness are different states.

## 162.2 Readiness State

Server tracks a small ephemeral record:

```lua
export type ClientRuntimeReadiness = {
    UserId: number,
    SessionNonce: string,
    ProtocolVersion: number,
    Ready: boolean,
    ReadyAt: number?,
    SnapshotRevision: number,
}
```

A new client request:

```text
Runtime.ClientReady
```

contains only protocol/version capability information. It cannot grant gameplay state.

The server responds by scheduling one current-state snapshot. It does not replay an unbounded history of prior presentation events.

## 162.3 Re-Ready and Respawn

Character respawn does **not** create a second permanent client bootstrap. Controllers persist across respawn where appropriate and rebind only character-scoped references.

If the client bootstrap itself restarts in development:

- prior listeners are destroyed first;
- the new readiness nonce differs;
- server supersedes the previous runtime session;
- exactly one active subscription set remains.

## 162.4 Failure Policy

If readiness never arrives:

- gameplay authority remains on the server;
- no valuable mutation is blocked solely by missing presentation;
- high-rate presentation traffic is not sent;
- the player may receive a bounded boot failure UI through the earliest available path;
- diagnostics record the stage where startup stopped.

## 162.5 Acceptance

- no queue-exhaustion warning during slow client startup;
- one readiness record per live client session;
- one initial snapshot after readiness;
- respawn does not duplicate remote listeners;
- development hot-restart returns listener counts to the prior baseline.

---

# 163. Replicated State Model: Snapshot, Delta, and Ephemeral Signals

## 163.1 Separate State from Events

The project must distinguish three things that are often incorrectly sent through one generic `State` remote:

1. **Current authoritative state** — what is true now.
2. **Durable transition** — a change that must eventually be observed in order.
3. **Ephemeral presentation pulse** — useful if received, harmless if dropped.

They use different delivery policies.

## 163.2 Initial Snapshot

After `ClientReady`, server sends:

```lua
export type RuntimeSnapshot = {
    ProtocolVersion: number,
    Revision: number,
    Encounter: any,
    Objectives: any,
    PlayerCombat: any,
    AbilityPresentation: any,
    ActiveMarks: any,
    RoutePresentation: any,
    LandmarkPresentation: any,
}
```

Only sanitized presentation state belongs here. Inventory or private data uses its own existing snapshot contract.

Snapshot requirements:

- finite size;
- one current revision;
- stable IDs rather than Workspace instance references when possible;
- no historical event log;
- safe to apply twice;
- client can rebuild presentation solely from this snapshot plus later deltas.

## 163.3 Reliable Delta

Reliable deltas carry discrete state transitions such as:

```text
objective activated
objective completed
encounter wave changed
entity marked/unmarked
landmark state changed
route guide mode changed
player downed/revived
boss phase changed
```

Each delta includes:

```text
revision
event/state kind
stable target ID
minimal payload
```

The client discards stale revisions and requests/resolves a new snapshot if it detects an unrecoverable gap in state that truly matters.

## 163.4 Unreliable Presentation Signals

Roblox documents `UnreliableRemoteEvent` for one-way data that changes continuously or is not critical to game state. It is appropriate for carefully chosen signals such as:

- nonessential aim traces;
- frequent cosmetic position hints;
- transient ambient pulses;
- debug visual telemetry;
- presentation-only interpolation hints.

It is **not** the authority channel for:

- damage;
- inventory;
- reward completion;
- objective completion;
- cooldown truth;
- persistent marks;
- revive state;
- boss phase.

## 163.5 No Generic Everything-Remote

`HordeNetwork.State` may remain as a migration alias temporarily, but the target architecture splits state by semantic contract. A single remote that receives every gameplay and presentation update becomes impossible to budget, test, or reason about.

---

# 164. Network Backpressure, Coalescing, and Delivery Budgets

## 164.1 Backpressure Rule

A reliable remote is not a substitute for a frame loop. If the server produces updates faster than the client can consume them, the design is incorrect even when each payload is small.

Roblox's `RemoteEvent` documentation notes that events can be buffered when no matching listener is connected, eventually producing discarded/queue warnings. Therefore, recurring delivery begins only after readiness and must remain bounded.

## 164.2 Project Delivery Classes

Provisional budgets:

| Class | Example | Target delivery |
|---|---|---:|
| A — critical transition | encounter phase | event driven only |
| B — normal state delta | objective/mark change | event driven, coalesced in same frame |
| C — presentation telemetry | route hint strength | ≤10 Hz unless measured need exists |
| D — cosmetic continuous | noncritical trace | unreliable, ≤20 Hz starting point |
| E — debug | diagnostic sample | off by default, ≤5 Hz |

These are project budgets, not Roblox platform limits. Lower rates are preferred when visuals can interpolate locally.

## 164.3 Coalescing

When multiple changes affect the same target in one scheduler step:

```text
old state A
→ intermediate B
→ final C
```

send the minimum state needed to render C unless B itself has a required player-facing event.

Examples:

- health presentation can send latest health, not every internal mutation if the UI is already interpolating;
- route guide target changes twice before the next presentation tick: send the final target;
- an entity marked then dies in the same tick: death cleanup outranks a new highlight lease.

## 164.4 Duplicate-Send Prevention

Each state publisher keeps its last published presentation hash/revision. If the serialized semantic state has not changed, it does not send another reliable update merely because a loop ran.

## 164.5 Diagnostics

Track by channel:

```text
messages sent/sec
messages received/sec
coalesced count
suppressed duplicate count
snapshot count
payload category
listener count
last revision
ready state
```

Approximate payload-size instrumentation may be added for development, but correctness does not depend on exact byte measurement.

## 164.6 Stop Conditions

Stop promotion when:

- reliable presentation is sent every Heartbeat without demonstrated necessity;
- a client receives recurring traffic before readiness;
- send rate grows after every round reset;
- listener count grows after every respawn;
- queue-exhaustion/discard warnings appear;
- state correctness depends on receiving every cosmetic update.

---

# 165. Client Presentation Controller Lifecycle Contract

## 165.1 Required Lifecycle

Every presentation controller implements a common conceptual lifecycle:

```lua
export type PresentationController = {
    Init: (self: PresentationController, context: any) -> (),
    Start: (self: PresentationController) -> (),
    ResetCharacter: (self: PresentationController, character: Model?) -> (),
    Stop: (self: PresentationController) -> (),
    Destroy: (self: PresentationController) -> (),
}
```

`Init()` resolves dependencies and allocates owned registries. `Start()` binds long-lived listeners exactly once. Character-specific listeners belong to a replaceable character scope. `Destroy()` is idempotent.

## 165.2 Connection Ownership

Every `RBXScriptConnection` has exactly one owner.

Allowed patterns:

- controller lifetime scope;
- character lifetime scope;
- target/effect lease scope;
- animation track scope;
- temporary modal/UI scope.

Disallowed patterns:

- anonymous connection created inside a frequently called state callback;
- connection created inside `RenderStepped`;
- one connection per state update without destroying the prior one;
- global event connection created by every enemy presentation object when one centralized dispatcher is sufficient.

## 165.3 One Listener Per Remote Per Client Domain

Prefer one domain listener that dispatches internally:

```text
remote
→ controller/domain dispatcher
→ stable-ID lookup
→ presentation object
```

rather than every target object connecting directly to the same global remote.

## 165.4 Restart Safety

Development restart test:

```text
Start
→ Stop
→ Start
→ Stop
→ Start
```

must produce the same permanent connection count as the first start.

## 165.5 Character Scopes

On `CharacterAdded`:

- destroy old character scope;
- bind camera/viewmodel/body listeners once;
- reapply current authoritative presentation snapshot;
- never recreate global remote listeners.

---

# 166. Centralized Highlight, Adornment, and Outline Ownership

## 166.1 Problem

`Highlight` is powerful enough to create catastrophic visual noise when several systems create instances independently or attach them to broad containers. Roblox exposes `Adornee`, `DepthMode`, fill, and outline properties; therefore the project treats Highlights as managed presentation resources rather than casual decoration.

## 166.2 Single Owner

Create one client `HighlightPresentationService` or equivalent registry. Gameplay presentation systems request leases; they do not directly create persistent Highlights.

```lua
export type HighlightLease = {
    LeaseId: string,
    TargetStableId: string,
    Channel: string,
    Priority: number,
    ExpiresAt: number?,
    StyleId: string,
}
```

## 166.3 Channels

Canonical channels:

```text
ThreatMark
Objective
Interactable
Route
Landmark
SecretClue
PartySupport
Debug
```

A target may have multiple logical leases but only one resolved visible style when styles conflict.

Provisional priority:

```text
ThreatMark > Objective > SecretClue > Interactable > Route > Landmark > Debug
```

Debug may override only when an explicit Studio debug mode is active.

## 166.4 Adornee Safety

A production highlight request must resolve to:

- one intended `Model`; or
- one intended `BasePart`.

Reject or warn on broad targets such as:

```text
Workspace
CurrentCamera
ReplicatedStorage
whole region container
whole map model
player character when only a held tool is intended
```

The system logs the stable ID and resolved instance path when a lease is created in debug mode.

## 166.5 Fill Policy

Default route and landmark presentation should favor outline, icon, beacon, or world-space accent over opaque fill. Large solid fills obscure silhouettes and destroy environment readability.

Project starting rules:

- Landmark: high fill transparency, occluded by world where useful.
- Route: no broad full-model fill; prefer localized accent pieces or beacons.
- ThreatMark/Pulse Mark: can use `AlwaysOnTop` where the design intentionally reveals through cover.
- Secret clue: restrained pulse, not permanent neon paint.
- Debug: visually unmistakable and automatically disabled outside development.

## 166.6 Budget

Project budget starts at:

```text
normal simultaneous visible highlights: 12
absolute presentation pool target: 24
full-screen/broad adornments: 0 in normal gameplay
```

This is a project readability/performance budget, not an asserted engine limit.

## 166.7 Cleanup

Release lease on:

- expiry;
- status removal;
- target death;
- target stream-out;
- objective completion;
- controller stop;
- encounter reset;
- character reset where relevant.

No lease may rely only on a delayed task to clean itself. Central reset destroys or releases every owned effect deterministically.

---

# 167. Route Guide, Landmark, Objective, and Secret Presentation Contracts

## 167.1 Different Information Needs Different Visual Language

Do not use the same yellow outline for route, objective, landmark, interactable, and debug information. Players need to infer meaning before reading text.

| Domain | Primary cue | Secondary cue | Through-wall? |
|---|---|---|---|
| Route | world-space beacon/path accent | HUD direction | usually no |
| Landmark | silhouette/light identity | map/HUD name | distant visibility allowed |
| Objective | localized icon/accent | objective HUD | context dependent |
| Interactable | proximity response | prompt | no |
| Pulse Mark threat | marked silhouette/outline | icon | yes, by design |
| Secret clue | subtle cyan/wayline response | sound/prompt after discovery | limited |
| Debug | loud diagnostic color/labels | counters | dev only |

## 167.2 Route Guide Controller

`RouteGuidePresentationController` should consume a semantic route target, not enumerate every Workspace descendant.

State example:

```lua
{
    RouteId = "route.emberwatch_to_gate",
    TargetNodeId = "route_node.expedition_gate",
    Mode = "Beacon",
    Revision = 17,
}
```

The controller resolves a tagged/registered target and presents one bounded guide. If the target is streamed out, it falls back to compass/HUD direction rather than adorning an ancestor container.

## 167.3 Landmark Accent Controller

Landmark accents are authored on explicit accent anchors such as:

```text
LandmarkAccentAnchor
BeaconLight
SignageGlow
WaylineCore
```

Do not apply `Highlight` to the entire landmark assembly by default. The accent system should be readable when the landmark is partly occluded without turning every structural part into an outline forest.

## 167.4 Secret Presentation

Pulse Mark reveals registered discoverables through stable IDs. A reveal request cannot turn arbitrary descendants into clues because they happen to share a parent folder.

## 167.5 Acceptance

Fresh players should be able to answer:

- “Where am I going?”
- “What is important?”
- “What can I interact with?”
- “What is dangerous?”
- “What did Pulse Mark reveal?”

without every answer being “the yellow thing.”

---

# 168. Presentation State Bus and UI Synchronization

## 168.1 Purpose

Client systems need one local semantic state layer between network messages and visual objects. Remote callbacks should not directly mutate dozens of UI and world instances.

```text
Remote snapshot/delta
→ PresentationStateStore
→ domain selectors
→ HUD/world/camera/VFX controllers
```

## 168.2 State Store Laws

- keyed by stable IDs;
- revision aware;
- immutable or copy-on-write semantics where practical;
- updates batched to one local presentation step;
- selectors notify only when selected semantic state changes;
- no Workspace instances stored as durable state keys.

## 168.3 HUD and World Agreement

If an objective changes:

```text
one semantic state transition
→ HUD objective text
→ world objective cue
→ map marker
→ accessibility audio cue
```

rather than four systems independently interpreting the server packet.

## 168.4 Error Reconciliation

If the client predicted a presentation and the server rejects the action:

- predicted cue stops;
- authoritative state wins;
- rollback is visually readable but not dramatic;
- stale effects release leases;
- UI does not continue counting a rejected cooldown or objective.

---

# 169. VFX, Beam, Trail, Light, and Temporary Object Lifetime

## 169.1 Effect Ownership

Every runtime-created presentation object belongs to a scope:

```text
frame/transient
ability activation
enemy attack
status lease
encounter
character
client session
```

Its cleanup trigger is known at creation time.

## 169.2 Pooling

Pool only objects that are:

- frequently created;
- structurally identical;
- safe to reset completely;
- costly enough for pooling to matter.

Likely candidates:

- muzzle flashes;
- tracer beams;
- impact particles;
- simple world beacons;
- damage number containers if retained;
- temporary highlight instances managed by one service.

Do not pool stateful objects whose reset is more error-prone than recreation.

## 169.3 Reset Contract

Before a pooled object returns:

```text
Enabled false
Adornee/Attachments nil
Parent pool container
colors reset
transparency reset
sizes reset
emitters cleared
beam/trail attachments cleared
connections destroyed
attributes cleared
lease metadata cleared
```

## 169.4 Light Budget

Short-lived combat lights must be bounded. Persistent local lights belong to authored environment lighting, not weapon spam.

No weapon may create one PointLight per bullet and leave it for arbitrary debris lifetime.

## 169.5 Reduced Motion

Reduced-motion mode can:

- reduce screen-space displacement;
- shorten decorative pulses;
- remove nonessential camera shake;
- lower particle velocity/density;
- preserve timing and threat information through shape, icon, audio, and contrast.

---

# 170. Streaming-Safe Presentation and Stable-ID Rebinding

## 170.1 Streaming Reality

Roblox instance streaming can dynamically load and unload Workspace content. Presentation code must therefore assume that a target represented in semantic state may not currently exist on the client.

## 170.2 Stable Identity First

Presentation state stores:

```text
StableDefinitionId / EntityId / RouteNodeId / DiscoverableId
```

not a long-lived direct pointer as the sole source of truth.

A local `InstanceResolver` maps stable IDs to currently streamed instances using tags, attributes, entity registries, or explicit registration.

## 170.3 Stream-Out

When an instance leaves the client:

- release instance-bound visual objects;
- retain semantic state if still relevant;
- do not interpret missing instance as objective completion or enemy death;
- fall back to HUD/compass presentation when appropriate.

## 170.4 Stream-In

When the instance becomes available again:

- validate stable ID and current revision;
- rebind current lease/state;
- do not replay expired transient effects;
- do not create duplicate listeners.

## 170.5 WaitForChild Policy

Avoid indefinite `WaitForChild()` chains for streamed Workspace descendants. Systems either use a bounded wait for true startup dependencies or subscribe to registration/stream-in signals.

## 170.6 Model Streaming Choices

Important authored models should receive deliberate streaming/LOD review. Persistent or atomic-like behavior is chosen only when justified by gameplay and memory cost; the system must not mark the entire biome as permanently resident merely to simplify presentation code.

---

# 171. Animation Runtime Integration and Marker Listener Safety

## 171.1 Animation Is Presentation, Mechanics Are Authority

Version 2.1 established marker vocabulary and timing. Version 2.2 adds runtime ownership:

- server owns attack legality and damage windows;
- client animation can predict approved presentation;
- markers trigger local audio/VFX and authored transitions;
- animation markers never become the sole proof that damage occurred.

## 171.2 Track Registry

Each animated domain keeps a registry by semantic action:

```text
Idle
Locomotion
Fire
Reload
Ability
AttackTelegraph
AttackActive
Recovery
Reaction
Death
```

Track load, marker connection, priority, fade rules, and destruction are managed centrally per animator/rig.

## 171.3 Marker Connections

For each loaded track:

- marker signals are connected once;
- connections are stored with the track scope;
- replacing/reloading a track destroys prior marker connections;
- a looping track does not create new marker listeners each loop;
- a state transition does not call `GetMarkerReachedSignal()` repeatedly without reuse/cleanup.

## 171.4 Animation Restart Test

Play/reload the same weapon or enemy action 100 times. Marker callback count per action must remain constant.

## 171.5 Desynchronization Policy

If authoritative timing arrives late:

- do not rewind the world violently for minor presentation differences;
- correct the local layer toward truth;
- suppress duplicated muzzle/hit cues by activation or shot ID;
- major boss/attack state discrepancies snap to the authoritative phase with a clean transition.

---

# 172. First-Person Viewmodel, Camera, and Character Lifecycle Stability

## 172.1 One Viewmodel Owner

Only the first-person presentation controller owns the local viewmodel hierarchy. Weapon, ability, recoil, sprint, and damage systems request state changes through it.

Do not let every weapon script create its own camera child tree.

## 172.2 Character Respawn

On character replacement:

```text
stop old viewmodel animations
release old camera modifiers
clear old character references
destroy old character-scope connections
bind new character
restore currently equipped weapon presentation
apply current sensitivity/accessibility settings
```

## 172.3 Camera Modifier Stack

Use named, bounded modifiers:

```text
base look
ADS
recoil
sprint bob
landing impulse
damage impulse
ability pulse
cinematic override
accessibility reduction
```

No system writes the final camera CFrame blindly after another system. A camera stack resolves the composition in deterministic order.

## 172.4 Kill Switch

Development command can disable:

- camera shake;
- recoil presentation;
- viewmodel;
- weapon VFX;
- world highlights;
- route guides;
- post effects.

This isolates problems without modifying production scripts during diagnosis.

---

# 173. Asset Preload, Dependency Readiness, and Graceful Degradation

## 173.1 Do Not Block the Game on Every Asset

Startup separates:

### Required to enter playable state

- core UI shell;
- input bindings;
- network listeners;
- critical local scripts;
- minimum player presentation.

### Preload opportunistically

- likely first weapon animations/audio;
- near-term encounter effects;
- first route landmark assets where applicable.

### Stream/load on demand

- distant biome detail;
- optional cosmetics;
- later dungeon content;
- noncritical ambience.

## 173.2 Missing Presentation Asset

If an animation, sound, or cosmetic fails to load:

- server gameplay continues if safe;
- fallback presentation communicates the state;
- error is logged with asset semantic ID;
- no infinite retry loop occurs;
- player is not granted or denied valuable results based on cosmetic load.

## 173.3 Version Mismatch

Snapshot contains protocol/content revision. If client code cannot safely interpret it, fail visibly into a bounded compatibility/rejoin path rather than partially rendering arbitrary fields.

---

# 174. Runtime Diagnostics, Counters, and Studio Debug Overlay

## 174.1 Debug Overlay Panels

Development-only overlay supports:

### Network

```text
client ready
protocol version
snapshot revision
last delta revision
reliable messages/sec by channel
unreliable messages/sec by channel
coalesced updates
suppressed duplicates
```

### Controller lifecycle

```text
active controllers
per-controller permanent connections
character-scope connections
render/heartbeat bindings owned
restart generation
```

### Presentation objects

```text
active highlights by channel
active beams/trails/emitters
pooled objects checked out
world-space UI count
active camera modifiers
active animation tracks/marker connections
```

### Streaming

```text
semantic targets unresolved
recent stream-outs
recent rebinds
fallback HUD targets
```

## 174.2 Logging

Structured diagnostic example:

```text
[presentation.highlight.acquire]
lease=...
target=enemy.pursuer/entity_...
channel=ThreatMark
adornee=Workspace.Runtime.Enemies....
revision=82
```

Production logging is sampled/bounded; detailed paths are development-only.

## 174.3 Baseline Snapshot

A command captures runtime baseline:

```text
connections
instances owned by presentation
active effects
remote rates
memory category counters where available
frame time sample
```

After an encounter reset or test cycle, compare against baseline.

---

# 175. Studio Debugging Workflow and Isolation Ladder

## 175.1 Reproduce Before Editing

Record:

```text
place/build version
test mode
players
exact steps
time to failure
Output messages
active encounter/state
screenshots/video
relevant counters
```

## 175.2 Isolation Ladder

When presentation explodes visually or network warnings appear:

1. Pause spawning/new rounds.
2. Disable debug presentation.
3. Disable route/landmark presentation.
4. Disable ability/status presentation.
5. Disable nonessential state publishers.
6. Inspect remote send/receive counters.
7. Inspect controller connection counts.
8. Inspect active `Highlight` instances and their `Adornee` paths.
9. Inspect one suspected producer at a time.
10. Re-enable systems in reverse order after the metric is stable.

## 175.3 Do Not Diagnose by Deleting Random Instances

Destroying visible Highlights manually can hide the symptom while the producer continues recreating them. Identify the owner and stop the acquisition path first.

## 175.4 Assistant/Tool Use

Studio Assistant can help inspect scripts and current state, but every proposed fix still requires:

- source diff review;
- multiplayer test;
- cleanup test;
- performance observation;
- evidence capture.

---

# 176. Performance Profiling and Presentation Budgets

## 176.1 Frame-Time Targets

Roblox's MicroProfiler documentation frames performance in milliseconds per frame: approximately 16.67 ms corresponds to 60 FPS and 33.33 ms to 30 FPS. Project budgets are therefore reviewed as frame-time cost, not merely average FPS.

## 176.2 Presentation Script Budget

Provisional representative-scene targets:

```text
presentation/controller Lua average: <2.0 ms desktop development target
presentation/controller Lua average: <3.5 ms midrange-mobile investigation threshold
single presentation spike: investigate >5 ms when repeatable
```

These are internal starting gates and must be replaced by device evidence.

## 176.3 Render-Step Discipline

Only camera/viewmodel and truly frame-dependent interpolation belong on render-step paths.

Route guides, objectives, highlights, state replication, and most effect lifetime work are event driven or low-frequency scheduled.

## 176.4 MicroProfiler Capture Set

Capture:

- empty hub baseline;
- mixed encounter baseline;
- Pulse Mark with maximum visible marks;
- route guide plus landmark presentation;
- heavy VFX moment;
- respawn/reset;
- streaming boundary crossing;
- ten-minute soak after repeated encounters.

## 176.5 Mobile First Reality Check

A desktop editor can hide cost. At least one representative midrange mobile device or Roblox mobile profiler capture is required before visual/presentation promotion.

---

# 177. Presentation Regression Tests and Runtime Invariants

## 177.1 Core Invariants

The following must always be true:

```text
one active global listener set per client session
one active character scope per local character
no reliable presentation send before ClientReady
no broad production Highlight adornee
no stale highlight after semantic state ends
no state publisher whose send rate grows after reset
no animation marker listener growth after repeated plays
no camera modifier survives its owning state
no pooled effect returns with old target/attachments
no stream-out is interpreted as authoritative removal
```

## 177.2 Automated/Instrumented Tests

Where possible, add test helpers that:

- count owned connections before/after controller restart;
- simulate snapshot + duplicate snapshot;
- apply stale delta and confirm rejection;
- apply 100 identical state updates and confirm duplicate suppression;
- acquire/release highlight leases repeatedly;
- stream/register/unregister a fake target repeatedly;
- play an animation track repeatedly and count marker callbacks;
- reset encounter ten times and compare owned-instance baseline.

## 177.3 Manual Matrix

Test modes:

```text
Play Solo
Start Server + 2 clients
character respawn
late client join
low graphics
reduced motion
mobile aspect ratio
simulated poor network
streaming traversal
round restart loop
```

## 177.4 Ten-Minute Soak Gate

During a ten-minute repeated-combat session:

- connection count reaches steady state;
- presentation-owned instance count returns near baseline between encounters;
- reliable state send rate does not trend upward;
- no queue/discard warning appears;
- no orphan highlight or beam remains after final reset.

---

# 178. Studio Incident Case Study: `HordeNetwork.State` Queue Exhaustion

## 178.1 Observed Evidence

A Studio screenshot captured during development showed repeated Output errors of the form:

```text
Remote event invocation queue exhausted for ReplicatedStorage.HordeNetwork.State;
did you forget to implement OnClientEvent?
```

Roblox's `RemoteEvent` reference states that when no connected listener exists, events may buffer and eventually be discarded with a warning instructing the developer to implement the corresponding event listener.

## 178.2 What the Evidence Establishes

The evidence strongly establishes:

- the server was firing `HordeNetwork.State`;
- the receiving client did not have an effective matching listener for at least part of that traffic;
- traffic continued long enough to exhaust/discard buffered invocations.

It does **not** establish without source/runtime measurement:

- the exact firing script;
- whether one or several loops were firing;
- whether the listener never existed or connected too late;
- whether the apparent dropped-count pattern reflects duplicated loops or log aggregation.

## 178.3 Corrective Architecture

Migration plan:

```text
1. locate every State:FireClient / FireAllClients call
2. locate every State.OnClientEvent connection
3. instrument send rate and connection count
4. bind client listeners before ClientReady
5. gate recurring server traffic on ClientReady
6. replace generic state spam with initial snapshot
7. send only semantic deltas after snapshot
8. coalesce unchanged/repeated state
9. move disposable continuous presentation to unreliable channel if appropriate
10. soak-test resets and respawns
```

## 178.4 Acceptance

The incident is closed only when:

- no queue-exhaustion/discard warning appears in a ten-minute soak;
- cold startup with deliberately delayed client readiness does not overflow;
- round reset does not change listener/send baselines;
- two clients can join at different times and each receives one correct snapshot;
- state presentation remains correct after one client respawns.

---

# 179. Studio Incident Case Study: Runaway Highlights and Presentation Escape

## 179.1 Observed Evidence

The same Studio capture showed:

- very large blue filled geometry in front of the player;
- extensive yellow outlines across world structures;
- normal world readability heavily obscured.

The screenshot alone cannot identify the exact script, but the visual pattern is consistent with broad or excessive highlight/adornment presentation. Roblox `Highlight` exposes an `Adornee` property controlling which instance is highlighted, plus fill/outline and depth properties.

## 179.2 Investigation Procedure

In the affected running client:

1. Search Explorer for `Highlight` instances.
2. Record count and parent.
3. Inspect `Adornee` for each active highlight.
4. Record `FillTransparency`, `OutlineTransparency`, `DepthMode`, and `Enabled`.
5. Identify the script/controller that created each instance.
6. Disable `LandmarkAccentPresentationController` and `RouteGuidePresentationController` independently.
7. Check whether the blue fill belongs to character/tool/viewmodel or world presentation.
8. Confirm no highlight targets `Workspace`, the entire map, a biome root, or unintended character ancestor.
9. Confirm cleanup after objective/route state changes.
10. Re-enable through centralized lease service.

## 179.3 Design Correction

All production Highlights move behind the centralized ownership service described in Chapter 166. Existing ad-hoc highlight creation becomes migration debt.

Route and landmark systems default to localized authored anchors, icons, beacons, lighting accents, or subtle outlines—not broad full-model fills.

## 179.4 Acceptance

- zero broad-container production adornees;
- highlight count remains inside project budget;
- disabling one presentation channel removes only that channel;
- encounter/reset cleanup returns active leases to baseline;
- Pulse Mark can still intentionally reveal marked threats through cover;
- low-graphics and color-accessibility modes retain meaning.

---

# 180. Version 2.2 Tickets 181–210, Evidence Gate, and Closing Directive

## 180.1 Tickets 181–210

### Runtime bootstrap and network

181. Add client bootstrap stage tracer and protocol version.  
182. Add `ClientReady` handshake and server readiness registry.  
183. Split current `State` behavior into initial snapshot and semantic delta contracts.  
184. Add revision numbers, stale-delta rejection, and snapshot resync path.  
185. Add state-change coalescing and duplicate-send suppression.  
186. Add presentation channel send/receive counters and Studio network panel.  
187. Identify eligible noncritical continuous signals and prototype `UnreliableRemoteEvent` only where loss is safe.

### Controller lifecycle

188. Standardize `Init/Start/ResetCharacter/Stop/Destroy` controller lifecycle.  
189. Add owned connection registry and per-controller connection diagnostics.  
190. Migrate global remote listeners to one domain listener per client.  
191. Add controller restart/respawn leak test.  
192. Add character-scope replacement utility.

### Presentation ownership

193. Build centralized Highlight lease service.  
194. Define channel styles, priorities, expiry, and broad-Adornee rejection.  
195. Migrate route guide presentation to stable target IDs and bounded cues.  
196. Migrate landmark accent presentation to authored anchors.  
197. Migrate Pulse Mark highlight presentation without changing server status truth.  
198. Add presentation kill switches for route, landmark, highlights, VFX, camera, and viewmodel.

### Streaming, effects, animation

199. Add stable-ID instance resolver and stream-in/out rebinding.  
200. Add pooled-effect reset contract and active-object counters.  
201. Audit animation marker connections and track lifetimes.  
202. Add camera modifier stack ownership and respawn cleanup.  
203. Add graceful missing-asset/fallback presentation path.

### Evidence and performance

204. Reproduce and close `HordeNetwork.State` queue-exhaustion incident.  
205. Reproduce and close runaway Highlight/adornment incident.  
206. Capture empty-hub and mixed-encounter MicroProfiler baselines.  
207. Run late-join, respawn, streaming, and two-client presentation matrix.  
208. Run ten encounter resets and compare connection/effect baselines.  
209. Run ten-minute soak on desktop plus representative mobile capture.  
210. Assemble Version 2.2 Studio runtime evidence package and promote only passing systems.

## 180.2 Version 2.2 Promotion Gate

Do not call the presentation layer stable until:

```text
queue/discard errors: 0 during acceptance soak
broad production Highlight adornees: 0
client-ready ordering: proven
snapshot count: exactly one per readiness generation unless resync requested
permanent listener count after respawn/reset: unchanged
animation marker callbacks per action after repetition: unchanged
presentation-owned instances after reset: return to bounded baseline
late join: correct
stream-out/in: correct
low graphics: readable
mobile capture: acceptable
```

## 180.3 Evidence Package

Capture:

- Output window after cold start;
- network diagnostic panel;
- controller connection baseline;
- active Highlight lease panel;
- one correct route guide screenshot;
- one correct Pulse Mark through-cover screenshot;
- one late-join snapshot trace;
- one respawn trace;
- one stream-out/rebind trace;
- one MicroProfiler capture during mixed combat;
- one ten-minute soak summary;
- before/after captures for both Studio incidents.

## 180.4 Version 2.2 Closing Directive

Version 2.2 makes visual correctness a runtime engineering responsibility rather than an asset-only responsibility.

The next valuable proof is not another visual chapter. It is a clean Studio session where:

```text
listeners bind once
→ client announces ready
→ one snapshot arrives
→ deltas stay bounded
→ route cues target only what they own
→ Pulse Mark reveals only what it owns
→ resets release everything
→ streaming rebinds cleanly
→ Output remains quiet
```

> A presentation system is finished when it can disappear cleanly. Every glow, marker, connection, and packet must know who owns it, why it exists, and exactly when it stops.

---

# Version 2.3 Hardening Appendix

## A. State Channel Invariants

The runtime presentation boundary is accepted only when all are true:

```text
listeners exist before ClientReady
one snapshot establishes current state
reliable deltas are revisioned
unchanged state is not resent on a timer
revision gaps trigger resync
reset does not multiply producers
respawn does not multiply listeners
late join reconstructs current state
normal play produces zero queue/discard warnings
```

## B. Presentation Baseline Invariants

At a defined idle baseline record:

```text
controller connections
character-scoped connections
Highlight leases
temporary effects
animation tracks
marker listeners
camera modifiers
unresolved semantic targets
reliable messages/sec
unreliable messages/sec
```

Repeat after five encounter resets and three respawns. Counts that should return to baseline must do so.

## C. Highlight Guardrails

A production highlight request is invalid when its target is Workspace, an unrelated region root, or a model whose bounds/descendant breadth exceed sanity limits without an explicit approved exception.

The lease registry logs:

```text
lease id
channel
stable target id
resolved local instance
priority
style token
created time
owner scope
release reason
```

## D. Incident Closure Evidence

The queue incident closes only with:

- producer and listener traces;
- clean cold start;
- reset/respawn invariance;
- late join;
- two-player test;
- ten-minute soak;
- zero warnings.

The highlight incident closes only with:

- producer inventory;
- narrow adornees;
- centralized ownership;
- reset/respawn cleanup;
- streaming rebind;
- before/after captures.

## E. Development Kill Switches

Provide independent development flags for:

```text
route guides
landmark accents
gameplay highlights
Pulse Mark presentation
world VFX
screen VFX
camera modifiers
viewmodel
animation-driven presentation events
```

A kill switch is an isolation tool, not a permanent substitute for fixing ownership.

