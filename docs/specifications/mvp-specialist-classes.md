# Living Kingdoms — MVP Specialist Classes

## Status

**P7 complete.** Shared contracts, selection ownership, all three class vertical slices, cross-class presentation, adversarial/scaling fixtures, and bounded Studio-only validation telemetry are implemented through `P7-0107`. `P8-PLAN-001` is the next gameplay task.

## Purpose

The class system must make cooperation matter through responsibilities, limits, and interactions—not through three differently colored damage multipliers. Combat specialist, medic, and engineer must each contribute frequently enough to be noticed, carry a finite cost or vulnerability, and create moments where teammates protect or enable one another.

The system must also preserve composition resilience:

- no starting class is required to enter or attempt the operation;
- duplicate starting classes are allowed;
- a balanced squad should have materially better options, not an automatic victory;
- solo play remains difficult but possible with any starting class;
- missing roles reduce flexibility or efficiency rather than making a required objective impossible.

## Canonical role responsibilities

### Combat specialist

The combat specialist provides dependable position stabilization during dangerous pressure. The role is not simply “more permanent damage.” Its first vertical slice is a bounded **Brace** action:

- the operative enters a temporary committed firing stance;
- while legally active, the server applies configured weapon-stability benefits such as improved cadence and/or target-retention reliability within the existing P2/P5 automatic-combat boundary;
- movement beyond a small configured tolerance, incapacitation, death, reload interruption policy, class change, operation resolution, or explicit cancellation ends the stance;
- Brace never creates ammunition, ignores visibility, bypasses line of sight, chooses an illegal target, forges a hit, or exceeds the configured effect/cooldown;
- the cost is positional commitment, vulnerability during the stance, ammunition consumption, and cooldown.

The initial slice uses a six-second stance, fourteen-second cooldown, 1.5-stud movement tolerance, and a server-composed `0.85` cadence-interval multiplier. Target-retention grace remains declared for later evidence-driven tuning; P7-0103 does not alter target legality or reveal hidden enemies.

### Medic

The medic preserves squad viability using finite recovery resources. The first vertical slice includes:

- **Field Treatment:** a server-validated, nearby, line-of-sight, continuous treatment action for an Alive injured teammate;
- **Revive Assistance:** a bounded improvement to the existing P3 teammate-revive path, such as shorter required hold time and/or higher restored health, chosen in P7-0104 configuration;
- finite personal medical charges or treatment resource owned by the server;
- interruption on movement, damage, invalid state, range/line-of-sight loss, target change, disconnect, operation resolution, or resource exhaustion.

The medic may not self-revive, revive Dead operatives, heal beyond maximum health, fabricate health or time, ignore the P3 revision boundary, erase repeated mistakes indefinitely, or become the only way to complete ordinary revives.

### Engineer

The engineer extends ammunition resilience and later supports authored operation equipment. The P7 vertical slice is **Field Resupply**:

- the engineer spends a finite operation-issued resupply resource;
- the action targets the engineer or a nearby valid Alive teammate according to the final P7-0105 configuration;
- the server derives identity, class, operation membership, distance, line of sight, weapon compatibility, capacity, grant amount, resource cost, replay state, and commit order;
- ammunition grants commit through the existing production combat/ammunition authority boundary;
- the grant cannot exceed reserve capacity, be recycled, be transferred repeatedly for profit, or create more total ammunition than the configured engineer budget.

P8 may integrate the engineer with authored objective-equipment repair through a narrow interface defined when a real objective needs it. P7 must not scaffold an unused repair/objective framework.

## Class interactions

The minimum intended interaction loop is:

1. The combat specialist uses Brace to stabilize a threatened position and create time/space.
2. The medic uses that window to treat or revive a teammate.
3. The engineer uses that window to resupply an operative before the squad relocates.
4. The medic preserves the engineer/combat specialist after exposure.
5. The engineer extends the ammunition runway that lets the combat specialist continue protecting channels and retreats.

These interactions are behavioral opportunities, not hard combo requirements. No class action directly forces another player’s action or grants client authority over another operative.

## Fixed class-composition decisions

### Starting availability

Combat specialist, medic, and engineer are unlocked for every player by default. Persistent unlock checks do not apply to them.

### Duplicate classes

Duplicate starting classes are allowed in the MVP. This prevents matchmaking or small-party composition from making a run invalid before play begins. Duplicate roles trade breadth for concentrated capability and must remain subject to personal resources/cooldowns.

### Solo play

A solo player may choose any starting class. The operation does not provide AI companions, free mid-run class swaps, unlimited fallback healing, or unlimited fallback ammunition. Existing P3 solo recovery remains the only special solo life exception unless a later evidence-based task changes it explicitly.

### Selection timing

- Selection is available during the briefing/pre-insertion phase.
- The server validates that the requested class is a known, currently unlocked class.
- Insertion locks the class for the active operation.
- No ordinary mid-run class swapping.
- A fresh replay creates a fresh selection window.

### Absence-of-role policy

Authored objectives, extraction, boss completion, and ordinary rescue cannot require a specific starting class. A class may reduce cost, time, danger, or resource pressure, but its absence cannot make a mandatory step impossible.

## Shared class vocabulary

P7-0101 will define strict shared declarations for at least:

- `ClassId`
- `ClassActionId`
- `ClassActionStateId`
- `ClassTargetKindId`
- `ClassSelectionStateId`
- `ClassActionRejectionReasonId`
- `ClassResourceId`
- `AuthoritativeClassAssignment`
- `AuthoritativeClassActionState`
- `AuthoritativeClassResourceState`
- `ClassSelectionIntent`
- `ClassActionIntent`
- safe owner and squad presentation snapshots

The initial action-state vocabulary should stay minimal:

- `Idle`
- `Starting` only if a server-confirmed windup is required
- `Active`
- `Cooldown`

Do not create generic buff/debuff frameworks, effect graphs, gameplay tags, skill trees, perk systems, loadouts, inventory grids, or arbitrary ability scripting for three actions.

## Resource and cooldown ownership

Every class capability must have a server-owned limiting mechanism:

- Brace: configured duration/stance conditions and cooldown; ammunition remains the ongoing strategic cost.
- Field Treatment/Revive Assistance: finite medical resource and configured channel/cooldown limits.
- Field Resupply: finite resupply resource and configured grant/cost/cooldown limits.

Rules:

- clients never submit remaining resource, cooldown completion, action duration, grant amount, heal amount, or effect strength;
- server timestamps own timing;
- resources cannot become negative or exceed configured maxima;
- replay/operation reset is explicit;
- death, incapacitation, disconnect, and operation resolution interrupt active actions;
- any preserved resource across character replacement comes from the server-owned operation record, not the character or client;
- P11 persistence does not store or restore in-match class resources.

## Authority model

### Client may

- request one of the known starting classes during the legal selection phase;
- request begin/end/cancel for a known class action using the smallest action-specific payload;
- provide a candidate target identity only when the action is player-directed;
- present immediate non-authoritative button/stance/channel feedback;
- display server-authored class, resource, action, interruption, and cooldown state.

### Server owns

- operative and operation identity;
- class availability, selection legality, assignment, lock state, and roster disclosure;
- action eligibility and rejection precedence;
- operative/target life state;
- positions, distance, line of sight, movement continuity, and damage interruption facts;
- timestamps, cooldowns, channels, costs, resources, grants, healing, revive modifiers, and weapon effects;
- replay protection, revision/generation correlation, operation reset, disconnect cleanup, and terminal interruption;
- every mutation to health, ammunition, weapon behavior, objective equipment, or operation state.

### Never trust

- client-selected effect values;
- client health/ammunition/resource totals;
- client class unlock claims;
- client distance, line of sight, movement, damage, time, cooldown, or completion facts;
- client claims that another operative accepted an effect;
- client target legality or operation phase.

## Runtime ownership and module boundaries

Names may be refined in the first task that implements them, but responsibilities must not duplicate existing owners.

### Shared

- `ClassContracts` — stable IDs and copied data shapes only.
- `ClassConfig` — class definitions, resources, ranges, durations, cooldowns, costs, and effect bounds.

### Pure server-domain modules

- `ClassSelectionResolver` — deterministic selection eligibility and rejection order.
- `ClassActionResolver` or focused action resolvers — deterministic start/update/cancel/complete decisions from caller-supplied facts.
- Focused combat/medical/resupply effect resolvers where they keep consequential math side-effect-free and testable.

### Runtime server modules

- `ClassService` — one owner of operation class assignments, action states, resources, revisions, subscriptions, and copied reads.
- A focused class-action runtime/coordinator may own bounded action timing if keeping it separate avoids turning `ClassService` into combat/objective code.
- Existing owners remain authoritative:
  - `OperativeLifeService` and revive runtime own health/life transitions;
  - `OperativeCombatRuntimeService` owns weapon/ammunition/cadence state;
  - `MissionDirectorService` owns operation phase;
  - future P8 objective runtime owns objective equipment/progress.

The class runtime must call narrow existing commit boundaries; it must not mirror or replace their state.

## Network surface

P7 should use a small explicit network, created by the server bootstrap and validated server-side.

Recommended shape:

- `ClassNetwork/SelectionIntent` — client to server during briefing only; payload contains a class ID and nothing else.
- `ClassNetwork/ActionIntent` — client to server; discriminated action ID, phase (`Begin`/`End`/`Cancel` where required), and optional candidate target operative ID.
- `ClassNetwork/State` — server to client safe owner/squad snapshots and presentation events.

The final contracts may combine or separate presentation events if that produces a smaller safer surface. No remote accepts health, ammunition, resources, cooldowns, timestamps, effect magnitudes, objective state, or another player’s class assignment.

All client-to-server requests require:

- exact payload shape and type validation;
- operation membership and legal phase;
- active operative ownership;
- rate limits appropriate to selection and action cadence;
- stable first-failure rejection order;
- stale/replay rejection;
- no extra arguments.

## Action lifecycle

A class action follows this server-owned lifecycle:

1. Receive and shape-validate the request.
2. Derive sender operative, assignment, operation phase, life state, resource, cooldown, and current action.
3. Derive target facts, position, range, line of sight, movement, and existing owner revisions where applicable.
4. Run a pure eligibility/start resolver.
5. Reserve or spend resource according to the action’s documented commit policy.
6. Commit the class action state with a new revision/generation.
7. Schedule no more runtime work than the action requires; prefer one owner-level earliest-deadline scheduler or existing bounded evaluation pass over per-player loops.
8. Revalidate continuity at update/completion.
9. Commit the effect through the existing health/ammunition/combat boundary.
10. Enter cooldown or return to Idle.
11. Disclose only safe owner/squad presentation.

Failures before the effect commit leave consequential target state unchanged. If a resource is reserved before a channel, cancellation/refund behavior must be explicit and deterministic.

## Deterministic rejection precedence

The exact IDs live in P7-0101, but each resolver should fail in a stable order broadly equivalent to:

1. malformed request/facts;
2. unknown class/action/target;
3. wrong operation phase or not a participant;
4. wrong assigned class/action;
5. inactive, incapacitated, or dead actor;
6. locked, already active, or cooldown state;
7. insufficient class resource;
8. invalid target identity or self-target policy;
9. invalid target life state;
10. range failure;
11. line-of-sight failure;
12. movement/damage/continuity failure;
13. stale revision/generation or duplicate/replay;
14. effect-owner commit rejection.

Tests must lock precedence where the reason is part of player feedback or security behavior.

## Integration with existing systems

### Combat

Brace modifies only configuration-approved inputs or state inside the existing automatic-combat pipeline. It does not send client-selected targets, hidden enemy facts, hit results, damage, ammo, or cadence timestamps.

### Life and revival

Field Treatment and medic revive benefits call the existing P3 life/revive boundaries with server-derived facts and expected revisions/generations. The base revive remains available to non-medics.

### Ammunition scarcity

Field Resupply commits an exact bounded grant through the existing production combat state and must be included in scarcity telemetry as a distinct source. P6 cache history remains independent; engineer resupply cannot mark authored caches consumed or reset them.

### Mission and objectives

Selection closes at insertion. Resolution interrupts all class actions. P8 may request an engineer class fact or invoke a narrow repair action, but cannot mutate class assignment/resource state directly.

### Persistence

P11 owns unlocks and profile data. P7 assumes the three starting class IDs are unlocked and accepts a server-supplied unlock set without implementing DataStore access.

## Life, character, disconnect, and replay rules

- Incapacitation or death immediately cancels active class actions.
- Character replacement rebinds presentation/input but does not refill resources or reset cooldowns.
- Disconnect cancels active actions and removes the active runtime entry according to the operation participation policy.
- Reconnect behavior must align with P10’s final policy; P7 stores state by operative/operation identity rather than character instance.
- Operation resolution interrupts actions and freezes further effects.
- Fresh replay creates new assignment/action/resource revisions and cannot reuse request IDs or stale timers from the previous operation.

## Presentation and accessibility

Every class needs clear owner and teammate cues:

- class identity in squad status;
- action available/active/interrupted/cooldown states;
- personal finite resource count or categorical availability;
- target/channel progress where allowed;
- concise rejection/interruption feedback;
- visible teammate action cue so protection opportunities are readable.

Critical cues must not rely on color or sound alone. Use text, shape/icon, animation/timing, and world/UI position redundantly. Presentation may not reveal hidden hostile identities, distant supplies, or undisclosed objective facts.

## Observability and balance evidence

P7 validation should collect read-only sampled facts sufficient to answer:

- How often did each class action become available, start, complete, interrupt, and enter cooldown?
- How much medical/resupply resource was issued, spent, wasted, or left unused?
- How much health or ammunition was legally restored?
- How long was each operative committed to a channel/stance?
- Did Brace meaningfully create safe action windows or merely increase damage?
- Did any class spend long periods without a useful contribution opportunity?
- Could solo and duplicate-role squads progress without a forbidden hard class gate?
- Did balanced squads gain materially better recovery/resource options?

Telemetry must remain read-only and must not create a production analytics dependency.

## Performance budgets

P7 targets one to four players while preserving a path to eight:

- no fixed four-entry arrays or hard-coded player indices;
- no per-frame class loops;
- no per-action Heartbeat connection;
- no unbounded per-operative timer accumulation;
- at most one active class action per operative unless a later task proves a second state is necessary;
- bounded roster/action/resource snapshots;
- bounded teammate disclosure;
- cleanup leaves zero active class actions, timers, and owned connections after stop/replay.

## Security validation

P7-0107 must prove clients cannot:

- assign or swap another player’s class;
- select after insertion lock;
- claim an unlock;
- invoke an action belonging to another class;
- act while incapacitated/dead or outside the operation;
- forge a target, distance, line of sight, resource, cooldown, duration, timestamp, revision, heal, ammo grant, weapon effect, or completion;
- replay an accepted request or race a stale completion;
- duplicate resources through cancellation, disconnect, character replacement, or replay;
- use class presentation to reveal hidden hostile/objective/supply state.

## Ordered implementation plan

### P7-0101 — Shared contracts and configuration

Deliver declarations and fixtures only. Lock IDs, copied shapes, class definitions, starting resources, cooldown/channel bounds, selection window vocabulary, and rejection reasons. No runtime or remote.

### P7-0102 — Selection and assignment

Deliver server-owned briefing selection, operation lock, duplicate support, safe roster state, lifecycle cleanup, and abuse tests. No class effects.

### P7-0103 — Combat specialist

Complete. Brace runs through the production combat owner with finite duration/cooldown, positional/life/reload/mission interruption, replay/rate bounds, explicit cancellation, compact keyboard/gamepad/touch feedback, and no healing, resupply, objective repair, ammunition creation, or target-authority bypass.

### P7-0104 — Medic

Complete. Field Treatment uses three finite server-owned charges, a three-second nearby line-of-sight channel, a 25-health revisioned life-owner commit, movement/damage/target/range/visibility interruption, and a four-second cooldown. Charges are spent only after a successful heal commit. Medic revives continue through the ordinary P3 session and revision boundary with a server-derived `0.75` duration multiplier and 40 restored health; non-medics retain the original duration and health. No self/dead revive or engineer/combat effect.

### P7-0105 — Engineer

Complete. Field Resupply uses two finite server-owned charges and a 2.5-second nearby Alive-target channel with movement, damage, range, visibility, weapon-compatibility, reserve-cap, mission, and life-state continuity. A completed channel requests one configured 12-round supply; the production combat owner applies only the compatible capped amount through `AmmunitionSupplyResolver`, deduplicates its server-created supply ID, publishes the committed ammunition state, and reports Engineer counts/rounds as a distinct scarcity-telemetry source. A charge is spent only after a positive ammunition commit.

Future P8 objective-equipment integration is intentionally limited to the existing read-only class-assignment boundary: the objective owner may read `ClassService.read(player)` to determine whether the operative is an Engineer. P8 must define any real repair intent, equipment eligibility, progress, cost, and commit contract when authored equipment exists; P7 reserves no repair action ID, remote, resource, objective state, or runtime.

### P7-0106 — Cross-class presentation

Complete. The existing safe class snapshot now drives bounded teammate world labels with written shape tokens, class names, role summaries, and active-action copy. The owner panel discloses class identity, finite current/maximum resources, numeric active/cooldown time, accessible action state, and concise mapped failure reasons. All cues use text and shape/weight changes in addition to color, create no new remote or authority path, reveal no hidden hostile/objective/supply facts, and clean up character labels and client connections deterministically.

### P7-0107 — Validation and tuning

Run automated abuse/regression tests plus solo, duplicate-role, and balanced 2/3/4-operative Studio sessions. Tune only configuration-backed values supported by evidence.

## Required Studio matrix

At minimum:

1. Solo combat specialist, medic, and engineer runs through the same early operation segment.
2. Two-player duplicate-role pairs for each class.
3. Two-player mixed pairs covering all role pairings.
4. Three-player balanced squad.
5. Four-player balanced-plus-duplicate squad.
6. Incapacitation during every action.
7. Damage/movement/range/line-of-sight interruption during every channel/stance.
8. Disconnect and character replacement during active actions.
9. Operation resolution and replay with active/cooldown actions.
10. Malicious/stale request attempts from multiple clients.

Record action frequency, completion/interruption, resource use, contribution readability, downtime, composition viability, performance owner counts, and cleanup residue.

## Explicit P7 exclusions

- unlockable fourth class;
- persistence, ranks, XP, or DataStore access;
- skill trees, perks, loadouts, equipment rarity, crafting, trading, or paid power;
- arbitrary buffs/debuffs or generic ability scripting;
- inventory transfer between players;
- permanent stat increases;
- class-specific weapons or a broader weapon roster;
- friendly fire;
- AI teammates;
- mandatory class gates on objectives, boss, extraction, or ordinary revive;
- engineer objective repair runtime before P8 has an authored use;
- special enemies, boss mechanics, result screens, replay flow, or progression.

## Open tuning questions—not architecture blockers

These values remain intentionally configurable until P7 vertical slices and Studio evidence:

- Brace duration, cooldown, movement tolerance, cadence benefit, and target-retention behavior;
- Field Treatment channel time, heal amount, charge count, range, cooldown, and damage interruption policy;
- medic revive hold-time/restored-health modifier;
- Field Resupply target policy, channel time, charge count, grant size, range, cooldown, and self-use policy;
- whether class resources refill only on fresh operation start or at one authored P8 resupply point;
- exact UI layout and input bindings;
- whether four-player balanced composition uses one duplicate chosen freely or a later matchmaking recommendation.

Any change to the fixed role responsibilities, duplicate policy, class-lock timing, authority boundaries, or absence-of-role policy requires a documented design decision rather than incidental implementation.
