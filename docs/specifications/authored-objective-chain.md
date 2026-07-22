# Authored objective chain — P8-PLAN-001

The plan for P8. It expands **Operation Blackwater Relay** from its single relay
interaction (see [`first-playable-operation.md`](first-playable-operation.md))
into a complete authored route of two required objectives plus one optional
supporting objective. The route forces a cross-map relocation, creates temporary
defensive value at one authored hold, gives every starting class a meaningful
moment without gating any required objective, and communicates objective truth
inside the disclosure limits established by P4.

This document is the planning gate. It fixes the objectives, their landmarks,
order, interactions, class opportunities, failure conditions, escalation, and
relocation pressure. It does **not** add code, contracts, or configuration —
those are `P8-0101` through `P8-0108`. Every constant named here is a target the
implementation tasks will place in `MissionConfig` (or a new
`ObjectiveConfig`) and validate; the numbers are authoring intent for the first
pass, tunable from evidence in P12.

## Design constraints inherited from the milestone

- **Reuse, do not rebuild.** The five-phase mission machine
  (`Insertion → Infiltration → Exfiltration → Holdout → Resolved`) and the
  single first-commit-wins terminal boundary in `MissionDirectorService` are
  sufficient. The objective chain runs entirely inside `Infiltration`; the
  required chain completing unlocks `Exfiltration` exactly where the current
  single relay does today. No new phase and no parallel state machine.
- **Server owns every objective fact.** Clients send interaction input only.
  Progress, completion, failure, timing, location, class effect, and escalation
  are server-read and server-committed (`P8-0102`).
- **One terminal failure.** The objectives add no new terminal-failure cause.
  The only ways the operation ends in failure remain a committed squad wipe or
  authoritative abandonment, exactly as today. An interrupted or decayed
  objective is a setback the squad recovers from, never a mission loss. This
  keeps the single terminal boundary intact for `P10`.
- **Disclosure stays within P4.** Presentation may name the current objective,
  its landmark, the next destination, and local progress. It may not reveal
  hidden threats, enemy counts, or distant supply truth
  (see [`darkness-visibility-and-squad-navigation.md`](darkness-visibility-and-squad-navigation.md)).

## The route

All three objectives sit on existing `WorldFoundationConfig` landmarks. Insertion
remains the Ranger Station. The chain drives the squad diagonally across the
640 × 640 operation area and then to extraction, so the route is a real
relocation, not a loop back through cleared ground.

| Order | Objective | Landmark (`LandmarkId`, center) | Required? | Cooperation / resource behavior it teaches |
| --- | --- | --- | --- | --- |
| 1 | Restore the emergency relay | `LookoutTower` (−205, 170), far NW | Required | A single held channel under first pressure |
| 2 | Charge the signal booster | `MilitaryRoadblock` (180, −178), far E | Required, needs 1 | A defended fixed-point hold that decays when abandoned |
| 3 | Restore the extraction floodlights | `ExtractionClearing` (218, 58), en route to holdout | **Optional**, needs 2 | A class-opportunity repair that rewards but never gates |

Relocation is the spine of the design: objective 1 is in the far northwest,
objective 2 is in the far east across the map, and the optional objective 3 and
the holdout are in the southeast. A squad cannot camp one landmark for the whole
operation; finishing objective 1 immediately obligates the long move to the
roadblock, and finishing objective 2 pushes them toward extraction.

### Objective 1 — Restore the emergency relay

The existing authored interaction, re-delivered through the generic objective
runtime rather than the current bespoke `requestObjectiveInteraction` path
(`P8-0103`). The `RelayConsole` graybox and its config position
(`{ x = -221, y = 17.5, z = 187 }` on `LookoutTower`, 14-stud interaction
radius) are preserved.

- **Interaction:** a short held channel (target ~4 s of continuous presence
  inside the radius) rather than the current instant press, so combat-specialist
  Brace and medic cover have something to protect. The channel accumulates only
  while a validated operative holds; leaving the radius pauses it, and it does
  not decay — objective 1 teaches the channel idea gently before objective 2
  raises the stakes.
- **Order/branching:** the operation's first required step; no prerequisite.
- **Completion:** commits the relay `Completed`, turns the status lamp green
  (existing behavior), and fires the relay-collapse escalation ring at the
  lookout (existing wave 1). Immediately directs the squad to the roadblock.
- **Class opportunity:** combat specialist Brace stabilizes the console position;
  medic keeps the channeler alive through the first ring. No class is required.

### Objective 2 — Charge the signal booster

The relay is live but too weak to reach extraction command. The squad must
relocate across the operation to the abandoned convoy's vehicle-mounted booster
at the Military Roadblock and hold while it charges. This is the authored
temporary-defense objective.

- **Interaction:** a **decaying accumulated-presence charge**. The booster charges
  while at least one validated operative stands inside its radius and drains at a
  slower rate when the radius is empty. Target values for the first pass: ~24 s
  of net charge to complete, drain at roughly half the charge rate, so a squad
  that abandons the point loses ground but a brief step-off to deal with pressure
  is recoverable. The roadblock's authored cover (barricades, convoy vehicles)
  is what makes the hold survivable.
- **Order/branching:** requires objective 1 complete. A stale-revision or
  out-of-order charge request is rejected by the runtime (`P8-0102`).
- **Temporary defensive value, bounded (`P8-0105`):** the roadblock is useful
  *only* while charging. On completion the booster escalation wave converges on
  the roadblock and the route pushes the squad off toward extraction, so the hold
  is never indefinitely optimal. No barricade economy, no base building, no
  crafting, no re-usable fortification — the cover is authored terrain the squad
  temporarily exploits, then leaves.
- **Completion:** commits the booster `Completed`, fires the booster escalation
  wave at the roadblock (the current "creek swarm" wave re-homed to this
  location), and unlocks `Exfiltration` — extraction becomes available exactly as
  it does after the single objective today.
- **Class opportunity:** combat specialist Brace anchors the hold; medic sustains
  defenders through a longer exposure than objective 1; engineer Field Resupply
  refills the ammunition the sustained hold burns. Cooperation is rewarded but a
  same-class squad can still complete it with more caution.

### Objective 3 — Restore the extraction floodlights (optional)

With the required chain done and extraction unlocked, the squad relocates toward
the clearing. The extraction floodlights are damaged. Restoring them is the
authored engineer opportunity and the milestone's optional objective.

- **Interaction:** the approved objective-equipment repair path
  (`mvp-specialist-classes.md` §Engineer: "P8 may integrate the engineer with
  authored objective-equipment repair through a narrow interface defined when a
  real objective needs it"). An **engineer** completes the repair on a short
  channel using the narrow objective-repair interface. **Without an engineer**,
  any operative can complete a slower manual bypass channel — longer and more
  exposed, but always possible. This is a class *opportunity*, never a class
  *gate*.
- **Order/branching:** requires objective 2 complete. Genuinely optional — it is
  **not** a prerequisite for `Exfiltration`, the holdout, or mission success.
  The squad may skip it and go straight to extraction.
- **Reward for completing it:** a bounded, readable advantage for the final
  holdout — the clearing's floodlights come on, improving readability during the
  extraction nightmare wave and marking the zone clearly. It grants no permanent
  power, no stat, and no persistent resource; skipping it simply leaves the
  holdout darker and harder.
- **Class opportunity:** primarily the engineer's meaningful objective moment;
  the manual bypass keeps a no-engineer squad whole.

## Order, prerequisites, and branching policy

- **Deterministic order.** `OBJ-RELAY → OBJ-BOOSTER → Exfiltration` is the fixed
  required spine. `OBJ-BEACON` is an optional branch off the post-booster state.
- **Prerequisites are hard.** The runtime rejects any progress on an objective
  whose prerequisite is not `Completed` (`InvalidPrerequisite`), so a skipped or
  unfinished required step can never advance the operation.
- **No hidden branching.** There is one authored path with one optional side
  step; no player choice reorders the required objectives. This keeps the first
  pass readable and its validation matrix small.

## Escalation mapping

The operation keeps exactly three authored escalation waves; P8 re-homes them to
the chain instead of adding new pressure systems
(see [`enemy-pressure-runtime.md`](enemy-pressure-runtime.md)). Escalation level
stays monotonic and each wave still spawns exactly once.

| Trigger | Wave (existing identity) | Authored location |
| --- | --- | --- |
| `OBJ-RELAY` complete | Relay collapse ring | Lookout (as today) |
| `OBJ-BOOSTER` complete | Booster swarm (today's creek swarm) | Roadblock |
| Holdout begins | Extraction nightmare | Extraction clearing (as today) |

Roaming pressure during the chain and full stand-down at resolution are unchanged.

## Failure conditions

- **Objective-level:** none are terminal. A channel or charge interrupted by
  death, incapacitation, or leaving the radius pauses (objective 1) or decays
  (objective 2) and is recoverable. There is no objective timer whose expiry ends
  the mission.
- **Operation-level (unchanged):** a committed squad wipe after its grace window,
  or authoritative abandonment when everyone disconnects, resolves the mission as
  failure from any phase through the existing `SquadFailureService` subscription.
- **Continuity:** all objective state is keyed by mission-scoped facts and
  operative entity IDs, never `Player` references, so a disconnect mid-channel
  cannot regress the phase, the chain, or the charge.

## Class opportunities without gates (summary)

| Class | Objective 1 | Objective 2 | Objective 3 |
| --- | --- | --- | --- |
| Combat specialist | Brace protects the relay channel | Brace anchors the defended hold | Protects the repairer |
| Medic | Keeps the channeler alive | Sustains defenders through the hold | Keeps the repairer alive |
| Engineer | Field Resupply before the long move | Field Resupply during the hold | **Fast objective-equipment repair** |

Missing any class changes options or efficiency (slower charge holds, a slower
manual floodlight bypass, less ammunition runway) but never makes a required
objective impossible.

## Presentation intent (for `P8-0107`)

The squad UI, driven only from the validated safe snapshot, communicates:

- the current objective line and its landmark name;
- the next destination after completion (relocation guidance allowed by P4);
- local progress — relay channel percentage, booster charge percentage (with a
  visible decaying state when the point is abandoned), floodlight repair
  percentage;
- interruption, completion, and (operation-level) failure.

It never discloses hidden threats, enemy counts, wave timing, or distant supply
truth. Radio lines extend the existing placeholder set; no licensed assets.

## Mapping to the P8 implementation tasks

| Task | What this plan hands it |
| --- | --- |
| `P8-0101` | Objective/step/interaction/progress/failure/completion IDs for the three objectives; versioned authored config (landmarks, positions, radii, channel/charge/decay/repair timings, prerequisites, permitted interactions, safe disclosure); pure fixtures for dependency and configuration invariants. |
| `P8-0102` | The generic runtime that validates phase, revision, identity, life state, class, range, line of sight, channel/charge continuity, prerequisites, and replay before committing any objective progress. |
| `P8-0103` | Objective 1 (relay) delivered through that runtime, routed through the existing mission authority — no parallel state machine. |
| `P8-0104` | Objective 2 (booster) and optional objective 3 (floodlights), each teaching a distinct cooperation/resource behavior with deterministic order and prerequisites. |
| `P8-0105` | The roadblock's decaying booster hold as the temporary — not indefinite — defensive value, with its post-completion push-off. |
| `P8-0106` | The engineer objective-equipment repair interface plus the no-engineer manual bypass; Brace/medic/resupply moments on every objective. |
| `P8-0107` | The route and objective presentation above. |
| `P8-0108` | Security and 1/2/4-operative validation: replay, remote spam, wrong phase, wrong class, impossible distance, stale revision, disconnect mid-channel, squad wipe, teardown; plus a Studio run of the full chain, forced relocation, and temporary defense. |

## Exit criteria for the plan

`P8-PLAN-001` is complete when the objectives, their landmarks, order,
interactions, class opportunities, failure conditions, escalation, defensive
value, and relocation pressure are fixed and mapped to existing landmarks and
mission phases — as above — so `P8-0101` can begin without further authoring
decisions.

## Deliberate exclusions

No new mission phase, no parallel objective state machine, no per-objective
terminal failure, no barricade economy or base building, no new enemy or boss
(that is `P9`), no persistent reward from any objective (that is `P11`), and no
new licensed assets. Timings named here are first-pass authoring intent to be
confirmed against evidence in `P12`.
