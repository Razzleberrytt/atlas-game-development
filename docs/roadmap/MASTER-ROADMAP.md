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

- [ ] **LK-0101 — Add camera-relative movement for one local survivor.**
  - **Scope:** create the smallest useful desktop control step from the existing tactical camera; no combat, aiming, sprint, stamina, interaction, animation overhaul, enemies, or camera redesign.
  - **Acceptance:** one local Roblox character is the controlled operative; W/A/S/D input produces movement directions projected from the tactical camera onto the ground plane; diagonal input is normalized; input is ignored when game-processed or while a text box is focused; default controls do not double-apply movement; character respawn is handled without duplicate connections; stopping or destroying the controller disconnects input and clears movement intent; the existing `CameraController` lifecycle, pan, zoom, and bounds continue working; StyLua, Selene, Rojo sourcemap, and Rojo build pass; manual Studio checks are documented.
- [ ] **LK-0102 — Define and enforce the initial movement authority boundary.**
  - **Acceptance:** shared movement limits are configuration-driven; the server observes operative state and rejects or corrects movement that violates defined prototype constraints; normal local movement remains responsive; correction behavior and limitations are documented; no combat or enemy behavior is added.
- [ ] **LK-0103 — Add survivor-facing and movement-state replication.**
  - **Acceptance:** facing follows the specified movement intent when not aiming; idle and moving states are consistent for other clients; the server does not accept an arbitrary client-supplied transform; respawn and disconnect paths are safe.
- [ ] **LK-0104 — Adapt tactical camera framing around the controlled survivor.**
  - **Acceptance:** the camera relationship to the operative is specified and implemented without removing existing lifecycle, pan, zoom, or bounds; authored-map bounds remain configurable; the player cannot accidentally lose the operative indefinitely; coexistence between camera and movement inputs is manually verified.
- [ ] **LK-0105 — Complete multiplayer movement and regression checks.**
  - **Acceptance:** two clients can move separate operatives without controlling one another; respawn, leave, camera replacement, text focus, and input lifecycle cases pass; observed network limitations are recorded; no later gameplay system is introduced.

### P1 exit criteria

One player can reliably control one operative from the elevated tactical view, and two-client verification confirms distinct ownership and stable camera behavior.

## P2 — Aiming and basic firearm combat

- [ ] **LK-0201 — Specify the basic firearm contract and configuration.**
  - **Acceptance:** stable weapon/action IDs, aim inputs, cadence, range, damage ownership, movement/aim tradeoff hooks, and client/server messages are documented; balance values have shared configuration homes; scarcity pickup behavior remains deferred to P6.
- [ ] **LK-0202 — Add local pointer-to-world aiming.**
  - **Acceptance:** the local operative can aim at a valid ground-plane/world point from the tactical camera; facing and reticle feedback are immediate and non-authoritative; invalid or UI-captured input is ignored; no damage is possible.
- [ ] **LK-0203 — Add a validated fire request and cadence.**
  - **Acceptance:** the client requests a shot with only necessary aim context; the server validates player, weapon state, cadence, and plausible aim; spammed or malformed requests fail safely; no client-supplied damage is trusted.
- [ ] **LK-0204 — Resolve server-authoritative firearm hits and damage.**
  - **Acceptance:** one configured firearm family can hit a test damageable target using the specified server resolution; range, obstruction, and damage are server-owned; hit feedback does not reveal hidden targets; deterministic validation receives tests where feasible.
- [ ] **LK-0205 — Add reload commitment and movement-versus-fire hooks.**
  - **Acceptance:** firing, aiming, moving, and reloading expose explicit states for later tuning; reload has an interruptible or non-interruptible rule; temporary test ammunition is clearly isolated and cannot be mistaken for P6 scarcity completion.
- [ ] **LK-0206 — Complete two-client firearm security and feel checks.**
  - **Acceptance:** clients cannot fire for one another, exceed cadence, set damage, or hit through invalid obstruction; camera and movement regressions pass; tuning questions are recorded without adding enemies or final effects.

### P2 exit criteria

A controlled operative can aim and use one basic firearm against a test target through an explicit server-authoritative contract, with enough state to tune movement, aiming, firing, and reload tradeoffs later.

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
