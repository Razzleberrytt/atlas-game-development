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
- [x] **LK-0104 — Adapt tactical camera framing around the controlled survivor.**
  - **Acceptance:** the camera relationship to the operative is specified and implemented without removing existing lifecycle, pan, zoom, or bounds; authored-map bounds remain configurable; the player cannot accidentally lose the operative indefinitely; coexistence between camera and movement inputs is manually verified.
- [x] **LK-0105 — Complete multiplayer movement and regression checks.**
  - **Acceptance:** two clients can move separate operatives without controlling one another; respawn, leave, camera replacement, text focus, and input lifecycle cases pass; observed network limitations are recorded; no later gameplay system is introduced.

### P1 exit criteria

Complete. One player can reliably control one operative from the elevated tactical view, and two-client verification confirms distinct ownership and stable camera behavior.

## P2 — Automatic targeting and basic firearm combat

- [x] **LK-0201 — Specify the automatic-combat contract and firearm configuration.**
  - **Acceptance:** stable weapon, hostile, and combat-state IDs; range; readiness; cadence; ammunition ownership; reload input; target eligibility; visibility; line-of-sight rules; threatening-hostile definition; and client/server presentation messages are documented; balance values have shared configuration homes; manual priority override and scarcity pickups remain deferred.
- [x] **LK-0202 — Validate automatic-target candidates on the server.**
  - **Acceptance:** a server function accepts an operative and candidate hostile and returns a deterministic legal/illegal result based on operative state, hostile state, visibility, line of sight, range, ammunition, and weapon readiness; clients cannot make an illegal target valid; deterministic rules receive automated tests where feasible.
- [x] **LK-0203 — Select targets using the initial priority rules.**
  - **Acceptance:** the server selects the closest valid hostile actively threatening the operative, otherwise the closest valid hostile in range; ties use a documented deterministic rule; invalid, hidden, obstructed, dead, or out-of-range candidates are excluded; target loss and reacquisition are safe.
- [x] **LK-0204 — Add server-authoritative automatic fire and cadence.**
  - **Acceptance:** a ready operative with a valid selected target fires automatically at configured cadence; the server owns ammunition consumption and weapon readiness; empty, reloading, incapacitated, invalid-target, and cadence-violating states cannot fire; temporary test ammunition is isolated from P6 scarcity completion.
- [x] **LK-0205 — Resolve server-authoritative firearm hits and damage.**
  - **Acceptance:** one configured firearm family resolves obstruction, range, hit, and damage against a test hostile on the server; no client-supplied hit or damage is trusted; target invalidation between acquisition and shot fails safely; deterministic validation receives tests where feasible.
- [x] **LK-0206 — Add immediate automatic-combat presentation and reload input.**
  - **Acceptance:** the client presents target selection and firing promptly without establishing target legality, ammunition truth, hits, or damage; the player directly controls reload timing; reload has a documented interruption rule; presentation does not reveal hidden or otherwise undisclosed hostiles.
- [x] **LK-0207 — Complete two-client automatic-combat security and feel checks.**
  - **Acceptance:** clients cannot select illegal targets, fire for another operative, exceed cadence, create ammunition, set damage, or hit through invalid obstruction; target priority matches the documented rules; camera and movement regressions pass; manual priority override remains unimplemented unless separately approved.

### P2 exit criteria

Complete. A controlled operative automatically acquires and fires one basic firearm at a valid test hostile through an explicit server-authoritative contract. Players retain direct control of movement, positioning, and reload timing, while presentation remains responsive and cannot determine combat truth.

## P3 — Health, incapacitation, revival, and death

Define server-owned health and damage, incapacitated state, teammate revival, unrecoverable death, squad failure conditions, readable feedback, and edge cases for disconnect or respawn.

- [x] **LK-P3-PLAN-001 — Specify and decompose P3 health, incapacitation, revival, and death.**
  - **Work type:** Documentation and planning.
  - **Acceptance:** the canonical P3 specification defines authority, the minimal life-state vocabulary and legal transitions, health and bleed-out rules, teammate revival and interruption, the limited solo policy, death/respawn and reconnect behavior, squad failure, trust boundaries, deferrals, and unresolved tuning questions; P3 is decomposed into small ordered tasks; no gameplay source or later milestone behavior changes.
- [x] **LK-0301 — Specify shared operative health and life-state contracts and configuration.**
  - **Work type:** Pure contract/configuration work.
  - **Acceptance:** shared strict types and stable IDs represent only `Alive`, `Incapacitated`, and `Dead`, health/life snapshots, authoritative transition results, revive state, and rejection reasons; maximum health, bleed-out, revive distance/duration/health, solo recovery, and failure grace have one shared configuration home; the P2 `TargetHealthState` and fixtures remain compatible; declarations create no runtime owner, remote, UI, character mutation, timer loop, or P4 behavior; automated fixtures verify frozen IDs/configuration and valid vocabulary; StyLua, Selene, Rojo sourcemap, and Rojo build pass.
  - **Studio validation:** not required; confirm the project launches only if shared-module loading changes beyond pure fixture coverage.
- [x] **LK-0302 — Implement pure operative health and incapacitation transitions.**
  - **Work type:** Pure server-domain work.
  - **Acceptance:** a deterministic side-effect-free resolver accepts server-owned operative state and an authoritative damage input, clamps health to `0..100`, keeps nonlethal damage `Alive`, transitions ordinary lethal damage from `Alive` to `Incapacitated`, discards overkill, rejects invalid and illegal transitions, and never trusts client health/damage/timestamps; P2 damage behavior remains unchanged; fixtures cover exact zero, just-above zero, overkill, duplicates, invalid values, immutability, and input-order independence where applicable; no Humanoid, runtime health owner, healing, revive, timer, death presentation, or P4 behavior is added.
  - **Studio validation:** not required; pure fixtures are the acceptance path.
- [x] **LK-0303 — Add pure bleed-out, finishing-death, and solo-recovery transitions.**
  - **Work type:** Pure server-domain work.
  - **Acceptance:** server timestamps start and resolve the configured bleed-out deadline; exactly-deadline behavior is deterministic; any accepted positive damage while incapacitated produces `Dead`; authoritative environmental damage follows the same boundary; the operation-started-solo policy permits exactly one configured automatic recovery and never appears after multiplayer participation; dead and stale transitions are idempotently rejected; fixtures cover just-before/exact/after deadlines, finishing damage, the one solo recovery, second incapacitation, and immutable inputs; no runtime scheduler, enemy, hazard, respawn, UI, or P4 behavior is added.
  - **Studio validation:** not required; pure fixtures are the acceptance path.
- [x] **LK-0304 — Implement pure revive eligibility and progress transitions.**
  - **Work type:** Pure server-domain work.
  - **Acceptance:** deterministic begin/update/cancel/complete functions require one alive teammate, one incapacitated target, distinct identities, configured range, server-confirmed line of sight, and a continuous configured hold; only one session may own a target and multiple revivers never accelerate it; movement, damage, release, separation, line-of-sight loss, disconnect, death, or incapacitation cancels and banks no progress; completion restores configured health with no invulnerability and preserves ammunition/ShotId state while leaving reload and selected target cleared; fixtures cover every rejection/interruption, exact completion boundary, stale messages, and immutability; no remote, input, runtime loop, medic bonus, healing item, UI, or P4 behavior is added.
  - **Studio validation:** not required; pure fixtures are the acceptance path.
- [ ] **LK-0305 — Integrate server-owned operative life state and character restrictions.**
  - **Work type:** Runtime server work.
  - **Acceptance:** one focused server owner atomically commits the accepted pure P3 transitions for each active operative, owns processed-ShotId lifetime, and adapts authoritative P2 damage without changing P2 fixture semantics; incapacitation/death interrupt reload, clear selection, disable combat and interaction, and enforce stationary character restrictions; revive restores allowed movement/combat readiness from preserved ammo/cadence state; automatic in-operation Roblox respawn cannot restore a dead operative; respawn, disconnect, rejoin, and teardown paths do not duplicate connections or reuse stale state; no client request can set health, state, timestamps, progress, or death; no enemy, operation result, polished UI, or P4 system is introduced.
  - **Studio validation:** one-client lifecycle checks cover nonlethal damage, incapacitation, bleed-out/finishing death, revival through a server-side test control, character replacement rejection during an operation, disconnect cleanup, and P1/P2 camera/movement/combat regression.
- [ ] **LK-0306 — Add revive input and disclosed life-state presentation.**
  - **Work type:** Runtime client/network work.
  - **Acceptance:** one explicit rate-limited revive-intent remote accepts only a target entity ID and hold phase from the sending player; the server derives reviver identity, eligibility, distance, line of sight, timing, interruption, and completion; local input starts/ends intent without choosing progress; clients present only disclosed health/life state, bleed-out/solo status, and active revive progress using temporary readable feedback; incapacitated/dead camera behavior follows the specification without free spectate; malformed, extra, stale, hidden, or cross-operative payloads fail closed; existing reload/presentation remotes and P1/P2 behavior remain intact; no polished UI, spectating, medic behavior, healing item, or P4 disclosure is added.
  - **Studio validation:** two clients verify hold/release, distance, line of sight, movement, damage, separation, cross-operative spoofing, disconnect, duplicate/stale payloads, local camera framing, and that one client cannot complete or accelerate another client's revive.
- [ ] **LK-0307 — Implement server-owned squad-failure evaluation.**
  - **Work type:** Pure evaluation plus minimal runtime integration.
  - **Acceptance:** a deterministic evaluator treats any alive operative or valid pending solo recovery as viable, starts the configured grace only when no recovery path exists, commits failure once at the exact deadline, and cancels pending failure if viability legally returns; all-incapacitated multiplayer, all-dead, one alive but unable to revive, solo first/second incapacitation, disconnect removal, zero-connected abandonment, and prohibited late join behavior are covered; clients cannot declare failure; the integration exposes life-state failure truth without implementing operation results, objectives, rewards, extraction, respawn flow, or P4 behavior.
  - **Studio validation:** server plus two clients verify all-incapacitated grace/commit, one-alive continuation, disconnect reevaluation, no solo exception after multiplayer participation, and no duplicate failure transition.
- [ ] **LK-0308 — Complete two-client health, revival, security, and regression checks.**
  - **Work type:** Validation and focused defect repair only.
  - **Acceptance:** all P3 pure fixtures and a bounded two-client Studio path prove server ownership of health, incapacitation, bleed-out, finishing damage, revive eligibility/progress/completion, solo recovery, death, respawn prevention, reconnect cleanup, and squad failure; malicious clients cannot set health/state/progress/time/distance/line of sight, revive themselves in multiplayer, revive dead targets, accelerate holds, or recover another operative; death and rescue feedback are understandable and predictable; P1 movement/camera and all P2 targeting/fire/damage/reload/security fixtures regress cleanly; any discovered defect receives only the smallest in-scope repair and regression coverage; no P4 or later feature is introduced.
  - **Studio validation:** required two-client Server & Clients session with exact observations, timing boundaries, disconnect/character-replacement probes, security attempts, feel notes, limitations, and a clean final run recorded in `docs/production/SMOKE-TEST.md`.

### P3 exit criteria

One or two controlled operatives use a server-owned `Alive`/`Incapacitated`/`Dead` model; ordinary lethal damage creates a readable rescue window, an exposed teammate can complete a validated revival, the limited solo exception is deterministic, unrecoverable death cannot be bypassed by respawn or rejoin, and server-owned squad-failure truth is verified without introducing P4 or later operation systems.

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
