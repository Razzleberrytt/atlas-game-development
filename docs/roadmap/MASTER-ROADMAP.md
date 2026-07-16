# Living Kingdoms — Master Roadmap

## Status legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[-]` Superseded by the cooperative-survival pivot
- `[!]` Blocked

Milestones are ordered. Work begins only after prerequisites are met, and later milestones do not authorize speculative scaffolding in earlier pull requests.

## Preserved foundation history

### Former M0 — Repository and Roblox foundation

- [x] **LK-0001** Create the Rojo-compatible Roblox project scaffold.
- [x] **LK-0002** Add `default.project.json` mappings for client, server, and shared source.
- [x] **LK-0003** Add minimal client and server bootstrap scripts.
- [x] **LK-0004** Document local setup for Roblox Studio, Rojo, and the repository.
- [x] **LK-0005** Add formatting and static-analysis configuration selected for the toolchain.
- [x] **LK-0006** Verify a local Rojo build produces a valid place file or synchronized Studio tree.
- [x] **LK-0007** Add a smoke-test checklist and record the first successful launch.

### Former M1 — Overhead camera

- [x] **LK-0010** Create `CameraController` with an explicit public lifecycle.
- [x] **LK-0011** Switch the local camera to a fixed overhead strategy view.
- [x] **LK-0012** Add keyboard camera panning.
- [x] **LK-0013** Add mouse-wheel zoom.
- [x] **LK-0014** Add configurable camera bounds.
- [-] **LK-0015** Add RTS camera smoothing. Superseded; responsiveness will be evaluated with operative controls.
- [-] **LK-0016** Add RTS touch pan and pinch-zoom design notes. Superseded; touch is redesigned after the desktop survival control model is proven.
- [-] **LK-0017** Run the former RTS camera manual test suite. Superseded; existing camera regression checks remain useful and a survival-camera suite will be defined when controls change.

The implemented camera lifecycle, overhead framing, keyboard panning, mouse-wheel zoom, and bounds remain reusable. Future bounds and controls will be adapted to the authored survival-operation map without deleting working code.

## P0 — Concept pivot and canonical specification

- [x] **LK-PIVOT-001** Reframe the canonical product, MVP, architecture, roadmap, and project readmes around cooperative isometric survival.
- [x] Record why the pivot occurred before major gameplay investment and what is preserved or discarded.
- [x] Mark former RTS specifications and roadmap work as superseded.
- [x] Define the first two implementation milestones as Codex-ready tasks.

### P0 exit criteria

The charter, MVP, technical blueprint, roadmap, decision record, and readmes agree on the new direction; no gameplay source changed; the existing project still formats, lints, sourcemaps, and builds.

## P1 — Tactical player movement and character controller

- [x] **LK-0101 — Add camera-relative movement for one local survivor.**
  - **Scope:** create the smallest useful desktop control step from the existing tactical camera; no combat, aiming, sprint, stamina, interaction, animation overhaul, enemies, or camera redesign.
  - **Acceptance:** one local Roblox character is the controlled operative; W/A/S/D input produces movement directions projected from the tactical camera onto the ground plane; diagonal input is normalized; input is ignored when game-processed or while a text box is focused; default controls do not double-apply movement; character respawn is handled without duplicate connections; stopping or destroying the controller disconnects input and clears movement intent; the existing `CameraController` lifecycle, pan, zoom, and bounds continue working; StyLua, Selene, Rojo sourcemap, and Rojo build pass; manual Studio checks are documented.
- [x] **LK-0102 — Define and enforce the initial movement authority boundary.**
  - **Acceptance:** shared movement limits are configuration-driven; the server observes operative state and rejects or corrects movement that violates defined prototype constraints; normal local movement remains responsive; correction behavior and limitations are documented; no combat or enemy behavior is added.
- [x] **LK-0103 — Add survivor-facing and movement-state replication.**
  - **Acceptance:** facing follows the specified movement intent when not aiming; idle and moving states are consistent for other clients; the server does not accept an arbitrary client-supplied transform; respawn and disconnect paths are safe.
- [ ] **LK-0104 — Adapt tactical camera framing around the controlled survivor.**
  - **Acceptance:** the camera relationship to the operative is specified and implemented without removing existing lifecycle, pan, zoom, or bounds; authored-map bounds remain configurable; the player cannot accidentally lose the operative indefinitely; coexistence between camera and movement inputs is manually verified.
- [ ] **LK-0105 — Complete multiplayer movement and regression checks.**
  - **Acceptance:** two clients can move separate operatives without controlling one another; respawn, leave, camera replacement, text focus, and input lifecycle cases pass; observed network limitations are recorded; no later gameplay system is introduced.

### P1 exit criteria

One player can reliably control one operative from the elevated tactical view, and two-client verification confirms distinct ownership and stable camera behavior.

## P2 — Automatic targeting and basic firearm combat

- [ ] **LK-0201 — Specify the automatic-combat contract and firearm configuration.**
  - **Acceptance:** stable weapon, hostile, and combat-state IDs; range; readiness; cadence; ammunition ownership; reload input; target eligibility; visibility; line-of-sight rules; threatening-hostile definition; and client/server presentation messages are documented; balance values have shared configuration homes; manual priority override and scarcity pickups remain deferred.
- [ ] **LK-0202 — Validate automatic-target candidates on the server.**
  - **Acceptance:** a server function accepts an operative and candidate hostile and returns a deterministic legal/illegal result based on operative state, hostile state, visibility, line of sight, range, ammunition, and weapon readiness; clients cannot make an illegal target valid; deterministic rules receive automated tests where feasible.
- [ ] **LK-0203 — Select targets using the initial priority rules.**
  - **Acceptance:** the server selects the closest valid hostile actively threatening the operative, otherwise the closest valid hostile in range; ties use a documented deterministic rule; invalid, hidden, obstructed, dead, or out-of-range candidates are excluded; target loss and reacquisition are safe.
- [ ] **LK-0204 — Add server-authoritative automatic fire and cadence.**
  - **Acceptance:** a ready operative with a valid selected target fires automatically at configured cadence; the server owns ammunition consumption and weapon readiness; empty, reloading, incapacitated, invalid-target, and cadence-violating states cannot fire; temporary test ammunition is isolated from P6 scarcity completion.
- [ ] **LK-0205 — Resolve server-authoritative firearm hits and damage.**
  - **Acceptance:** one configured firearm family resolves obstruction, range, hit, and damage against a test hostile on the server; no client-supplied hit or damage is trusted; target invalidation between acquisition and shot fails safely; deterministic validation receives tests where feasible.
- [ ] **LK-0206 — Add immediate automatic-combat presentation and reload input.**
  - **Acceptance:** the client presents target selection and firing promptly without establishing target legality, ammunition truth, hits, or damage; the player directly controls reload timing; reload has a documented interruption rule; presentation does not reveal hidden or otherwise undisclosed hostiles.
- [ ] **LK-0207 — Complete two-client automatic-combat security and feel checks.**
  - **Acceptance:** clients cannot select illegal targets, fire for another operative, exceed cadence, create ammunition, set damage, or hit through invalid obstruction; target priority matches the documented rules; camera and movement regressions pass; manual priority override remains unimplemented unless separately approved.

### P2 exit criteria

A controlled operative automatically acquires and fires one basic firearm at a valid test hostile through an explicit server-authoritative contract. Players retain direct control of movement, positioning, and reload timing, while presentation remains responsive and cannot determine combat truth.

## P3 — Health, incapacitation, revival, and death

Define server-owned health and damage, incapacitated state, teammate revival, unrecoverable death, squad failure conditions, readable feedback, and edge cases for disconnect or respawn.

## P4 — Darkness, limited vision, and squad-location tools

Implement limited personal information, darkness presentation, server-owned discovery rules where gameplay relevant, separated spawn support, and a periodic location ping or equivalent aid that preserves uncertainty.

## P5 — Enemy spawning, pursuit, and horde pressure

Implement basic enemy lifecycle, fair spawn rules, pursuit, attacks, authored waves, roaming pressure, escalation triggers, recovery windows, and representative performance measurement.

## P6 — Ammunition scarcity and supply collection

Replace temporary firearm resources with server-owned finite ammunition, supply caches at authored risky locations, collection rules, clear inventory feedback, and balance telemetry sufficient to distinguish tension from unavoidable starvation.

## P7 — Three interdependent MVP classes

Implement combat specialist, medic, and engineer responsibilities, limitations, cross-class interactions, class choice, and multiplayer verification. The engineer may restore ammunition only within strict scarcity constraints.

## P8 — Authored operation objectives

Build one operation flow with two or three authored objectives, forced relocation, useful temporary defensive positions, failure rules, and objective state readable to the squad.

## P9 — Special enemy and boss encounter

Add one special enemy that disrupts a reliable tactic and one readable boss climax that demands coordination and tests lessons taught earlier in the operation.

## P10 — Match completion, failure, and extraction

Implement final extraction or holdout, full-squad success and failure resolution, result screens, cleanup, replay flow, and safe handling of leave/disconnect cases.

## P11 — Persistent XP, ranks, and class unlock

Implement server-owned XP awards for victory and limited meaningful participation on failure, a small military-style rank ladder, reliable persistence, anti-idle safeguards, and at least one side-grade specialist class unlock. Do not add paid power or material permanent stat inflation.

## P12 — Cooperative balance, performance, and polish

Tune difficulty for high but learnable failure, class dependence, scarcity, relocation pressure, solo-to-four-player scaling, horde performance, accessibility, feedback, and operation readability. Validate that architecture has no fixed four-player assumptions before expanding toward eight-player support.

## Superseded RTS roadmap

The following uncompleted RTS tasks are explicitly superseded, not completed:

- [-] **LK-0020–LK-0029:** selectable-unit contracts, worker spawning, single/multi/drag selection, selection indicators, ownership selection rules, touch selection, and selection regression tests.
- [-] **LK-0030–LK-0039:** selected-unit move commands, worker destination validation, formation spacing, command feedback, and the worker movement vertical slice.
- [-] **LK-0040–LK-0049:** wood, trees, worker gathering, carrying, deposits, and resource-counter UI.
- [-] **LK-0050–LK-0059:** Town Hall and Barracks specification, placement, construction, production queue, Swordsmen, rally locations, and economy-to-army testing.
- [-] **LK-0060–LK-0069:** RTS attack commands, Swordsman combat, enemy defenders, enemy Town Hall destruction, and RTS match completion. Generic health, damage, death, enemies, success, and failure will receive new survival-specific contracts in P2–P10.

The former RTS charter, MVP, and technical blueprint were canonical specifications and have been revised in place. Their historical text remains available through Git history and is summarized in the pivot decision record. No standalone gameplay specifications existed to retain.

## Backlog policy

New ideas go into `BACKLOG.md` if that file is introduced; they do not interrupt the active milestone unless they expose a blocker, security problem, data-loss risk, or fundamental architectural flaw. Final branding work is deferred and must not rename the repository, game directory, Rojo project, scripts, or namespaces during these milestones.
