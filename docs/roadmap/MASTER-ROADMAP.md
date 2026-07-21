# Living Kingdoms — Master Roadmap

## Status legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[-]` Superseded by the cooperative-survival pivot
- `[!]` Blocked

Milestones are ordered. Work begins only after prerequisites are met, and later milestones do not authorize speculative scaffolding in earlier pull requests.

## Current milestone status

Snapshot as of 2026-07-21. Task-level detail and acceptance gates for unfinished P6–P12 work live in [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md), which controls those tasks per the [roadmap index](README.md); the cross-cutting art sequence lives in [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md).

| Milestone | Status | Summary |
| --- | --- | --- |
| M0/M1 foundation | Complete | Rojo scaffold, toolchain, camera foundation preserved through the pivot. |
| P0 — Survival pivot | Complete | Canonical charter, MVP, blueprint, and roadmap reframed. |
| P1 — Movement | Complete | Camera-relative operative control with a server sanity boundary. |
| P2 — Automatic combat | Complete | Pure server targeting/fire/hit/damage/reload pipeline and contracts. |
| P3 — Health and life state | Complete | Server-owned Alive/Incapacitated/Dead, revive, solo recovery, squad failure. |
| P4 — Darkness and navigation | Complete | Visibility/perception contracts, discovery memory, flashlight, squad ping. |
| P5 — Enemy pressure | Complete | Production enemy lifecycle, fair spawns, pursuit, attacks, waves, roaming, production automatic combat. Live Studio pressure-loop playthrough remains the outstanding manual check (smoke test). |
| P6 — Ammunition scarcity | Complete for prototype | `P6-0101`–`P6-0109` complete. The owner accepted the requested local 1/2/4-player tests with no reported blocker; no unmeasured tuning was applied, and retained raw telemetry remains a P12 validation limitation. |
| P7 — MVP classes | In progress | `P7-PLAN-001` through `P7-0104` complete, including Combat Specialist Brace and Medic treatment/revive assistance; `P7-0105` engineer is next. |
| P8 — Authored objectives | Not started | Fully planned; begins after P7. |
| P9 — Special enemy and boss | Not started | Fully planned; begins after P8. |
| P10 — Match loop and replay | Not started | Fully planned; begins after P9. |
| P11 — Persistence and unlock | Not started | Fully planned; begins after P10. |
| P12 — Release candidate | Not started | Fully planned; closes the MVP. |
| VIS — Visual production track | In progress | `VIS-PLAN-001` and `VIS-0101` complete; `VIS-0102`/`VIS-0103`/`VIS-0104` in progress with the five-weapon presentation models, six-role horde readability, and the client-local AUD-0102/AUD-0103 audio sets; later entries gated by their gameplay milestones. |
| HROI — Horde pressure and run-reward vertical slice | In progress | Bounded slices merged through PR #128 (issue #98): horde pressure and pacing tuning, confirmed hit/kill impact feedback, floating damage text, shooter hit markers, critical-condition urgency, shared run-only Field XP with squad upgrade choices, scarce enemy ammunition/recovery/Field Intel loot, five-weapon loadout roster with cleave/pierce patterns, six readable horde roles, environment mood, and client-local firearm/hostile audio. The RPG track now owns the expanded twelve-pick run-upgrade pool. Representative Studio playtest validation remains the outstanding HROI gate. |
| RPG — Run-based roguelite builds | In progress | `RPG-0101`–`RPG-0107` are complete: contracts/config, operation-scoped run-build state, the twelve-upgrade pool, shared bounded modifier resolution, the full five-affix elite roster, and the relic reward/slot/replacement framework. Deterministic server assignment preserves the protected opening, role compatibility, one-affix rule, and three-elite cap. Frenzied, Armored, Regenerator, Volatile, and Commander each have bounded mechanics, safe identity, readable counterplay, one-shot bonus Field XP, and cleanup coverage. The relic framework offers two deterministic compatible choices, bounds the reward queue at three, equips into empty slots or forces an explicit full-slot replacement, and cannot duplicate, reroll on reconnect, or survive teardown. `RPG-0108` implementation is complete and awaits Studio validation: all six first-batch relics now change authoritative outcomes through their existing owners — conditional damage in `DamageResolver`, wounded reload in `ReloadResolver`, Blood Battery healing through the revisioned P3 healing boundary, and the Grave Momentum kill-chain window in `HordeExperienceService` — using a revision-cached per-operative bundle read from the existing run-build owner. `RPG-0109` then completed the remaining six relics, so every declared relic carries a runtime effect and the catalog marks all twelve Implemented. `RPG-0110` connected every reward source whose authoritative owner exists — confirmed elite deaths, a squad-kill milestone, and confirmed special interrupts — and `RPG-0111` added the relic bar and the reward-choice/replacement interfaces over a bounded `RunBuildNetwork`, so relics are now earned, chosen, replaced, and read inside a live operation. Every implementable RPG task is delivered; `RPG-0112` is blocked on P10's result owner and `RPG-0113` is blocked on Studio evidence. Some implemented upgrades ship interim mechanics (see plan §7.4). |

### Immediate execution focus

- **Done:** merged PRs #142 and #144–#148 establish `RPG-0101`–`RPG-0106`; `RPG-0107` then extended the existing `RunBuildStateStore`/`RunBuildService` with the pure `RelicRewardResolver`, deterministic two-choice rewards, the three equipped slots, a bounded three-reward queue, validated full-slot replacement, safe snapshots, replay/reconnect protection, and operation teardown — no parallel build state or production reward owners were created.
- **Outstanding gate:** `RPG-0108` activates the first six relics (Blood Battery, Grave Momentum, Choir Breaker, Last Light, Emergency Chamber, Execution Protocol). Every part is implemented — the pure modifier foundation, the per-operative bundle threaded through `DamageResolver` and `ReloadResolver` (squad Field Upgrades stay squad-global via `ProgressionNetwork`), Blood Battery healing through the P3 healing boundary, and the Grave Momentum kill-chain window in `HordeExperienceService`. Only the representative Studio evidence for the "three viable build patterns" gate remains, so the task is not marked complete.
- **Then:** `RPG-0109` is complete — all six relics landed through their existing owners (Breach Doctrine and Longwatch Doctrine in `DamageResolver`'s pattern pass, Salvager's Mark in `EnemyLootService`'s collection path, Suppression Engine across `AutomaticFireResolver` and `DamageResolver` from a saturating sustained-shot counter, and Guardian Signal and Second Wind inside the P3 life core as expiring temporary armor and a one-charge incapacitation reprieve). All twelve declared relics are now Implemented. `RPG-0110` is complete for every available owner — confirmed elite deaths, a squad-kill milestone, and confirmed special interrupts now open real relic choices through the owners that already observe them, so relics are earnable in a live operation; objective, container, and boss sources stay deferred to P8/P9. `RPG-0111` is complete — an always-visible relic bar with charge and counter state, plus the reward-choice and replacement interfaces, over a bounded `RunBuildNetwork` whose only client requests are the two identity-free relic intents, so relics can finally be earned, chosen, replaced, and read in a live operation; `RPG-0112` waits for P10's result owner; `RPG-0113` performs final multiplayer/security/performance validation.
- **Blocked on evidence or dependencies:** no implementable RPG task remains. `RPG-0108`'s "three viable build patterns" gate, `RPG-0113`'s validation matrix, and the HROI representative playtest still need Studio sessions; `RPG-0112` needs P10's authoritative result owner. P7 class-effect runtime is now unblocked, while P8 and later still wait on their prerequisites.
- **Parallel manual gates:** the HROI representative Studio playtest/visual-mix evidence remains outstanding. P6 is signed off for the prototype with its raw-telemetry limitation carried to P12.

The active RPG task definitions, implementation path, dependencies, and exit gates live in [`../specifications/rpg-integration-plan.md`](../specifications/rpg-integration-plan.md).

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
- [x] **LK-0305 — Integrate server-owned operative life state and character restrictions.**
  - **Work type:** Runtime server work.
  - **Acceptance:** one focused server owner atomically commits the accepted pure P3 transitions for each active operative, owns processed-ShotId lifetime, and adapts authoritative P2 damage without changing P2 fixture semantics; incapacitation/death interrupt reload, clear selection, disable combat and interaction, and enforce stationary character restrictions; revive restores allowed movement/combat readiness from preserved ammo/cadence state; automatic in-operation Roblox respawn cannot restore a dead operative; respawn, disconnect, rejoin, and teardown paths do not duplicate connections or reuse stale state; no client request can set health, state, timestamps, progress, or death; no enemy, operation result, polished UI, or P4 system is introduced.
  - **Studio validation:** one-client lifecycle checks cover nonlethal damage, incapacitation, bleed-out/finishing death, revival through a server-side test control, character replacement rejection during an operation, disconnect cleanup, and P1/P2 camera/movement/combat regression.
- [x] **LK-0306 — Integrate authoritative ordinary damage routing.**
  - **Work type:** Runtime server work.
  - **Acceptance:** one server-only runtime entry point reads the current copied `OperativeLifeService` snapshot, rejects stale revisions, invokes the pure LK-0302 ordinary-damage resolver, validates accepted correlation/replay state, and atomically commits through the existing transition/restriction boundary; nonlethal damage remains Alive, lethal and overkill damage become Incapacitated at exactly zero, and ordinary damage never produces Dead; the service-owned processed-event set remains the sole replay mechanism; all failures leave state unchanged; no client can submit damage, health, state, revision, timestamp, processed IDs, or accepted results; no timers, finishing damage, revival runtime/networking/UI, squad failure, enemy, hazard, persistence, or P4 behavior is added.
  - **Studio validation:** two clients verify Alive 100 initialization, nonlethal 90, lethal/overkill Incapacitated 0, movement/fire/reload restrictions, second-player isolation, duplicate rejection, and Humanoid-edit resistance through a Studio-only server damage control.
- [x] **LK-0307 — Implement server-owned squad-failure evaluation.**
  - **Work type:** Pure evaluation plus minimal runtime integration.
  - **Acceptance:** a deterministic evaluator treats any alive operative or valid pending solo recovery as viable, starts the configured grace only when no recovery path exists, commits failure once at the exact deadline, and cancels pending failure if viability legally returns; all-incapacitated multiplayer, all-dead, one alive but unable to revive, solo first/second incapacitation, disconnect removal, zero-connected abandonment, and prohibited late join behavior are covered; clients cannot declare failure; the integration exposes life-state failure truth without implementing operation results, objectives, rewards, extraction, respawn flow, or P4 behavior.
  - **Studio validation:** server plus two clients verify all-incapacitated grace/commit, one-alive continuation, disconnect reevaluation, no solo exception after multiplayer participation, and no duplicate failure transition.
- [x] **LK-0308 — Complete two-client health, revival, security, and regression checks.**
  - **Work type:** Validation and focused defect repair only.
  - **Acceptance:** all P3 pure fixtures and a bounded two-client Studio path prove server ownership of health, incapacitation, bleed-out, finishing damage, revive eligibility/progress/completion, solo recovery, death, respawn prevention, reconnect cleanup, and squad failure; malicious clients cannot set health/state/progress/time/distance/line of sight, revive themselves in multiplayer, revive dead targets, accelerate holds, or recover another operative; death and rescue feedback are understandable and predictable; P1 movement/camera and all P2 targeting/fire/damage/reload/security fixtures regress cleanly; any discovered defect receives only the smallest in-scope repair and regression coverage; no P4 or later feature is introduced.
  - **Studio validation:** required two-client Server & Clients session with exact observations, timing boundaries, disconnect/character-replacement probes, security attempts, feel notes, limitations, and a clean final run recorded in `docs/production/SMOKE-TEST.md`.

### P3 exit criteria

Complete. One or two controlled operatives use a server-owned `Alive`/`Incapacitated`/`Dead` model; ordinary lethal damage creates a readable rescue window, an exposed teammate can complete a server-validated four-second revival, the limited solo exception is deterministic, unrecoverable death cannot be bypassed by character replacement, and server-owned squad-failure truth is verified without introducing P4 or later operation systems. The LK-0308 two-client and solo Studio evidence is recorded in `docs/production/SMOKE-TEST.md`; all 18 P1–P3 fixtures plus StyLua, Selene, Rojo sourcemap, Rojo build, and `git diff --check` form the automated exit gate.

## P4 — Darkness, limited vision, and squad-location tools

Create darkness, limited information, and selected squad navigation aids that preserve uncertainty without withholding the information necessary to regroup and pursue the current objective. The canonical P4 architecture is `docs/specifications/darkness-visibility-and-squad-navigation.md`.

- [x] **LK-P4-PLAN-001 — Plan and decompose P4 darkness, limited vision, and squad navigation.**
  - **Work type:** Documentation and planning.
  - **Acceptance:** the canonical specification separates rendering, gameplay, targeting, line-of-sight, discovery, and memory; defines darkness/light authority, automatic-targeting disclosure rules, player/enemy perception vocabulary, tool tradeoffs, performance/accessibility/security/synchronization policy, ordered tasks, dependencies, and exclusions; no gameplay source changes.
- [x] **LK-0401 — Define shared lighting contracts and configuration.**
  - **Work type:** Pure contract/configuration work.
  - **Acceptance:** stable visibility profiles, server-owned gameplay-light descriptors, activation/lifetime vocabulary, conservative budgets, and rejection reasons are documented and fixture-tested without lights, rendering, remotes, or runtime queries.
- [x] **LK-0402 — Define shared perception, disclosure, and memory contracts.**
  - **Work type:** Pure contract/configuration work.
  - **Acceptance:** frozen `Unknown`/`Suspected`/`Observed` perception, `Hidden`/`Disclosed` disclosure, `None`/`Remembered` memory, categorical confidence, and direct-sight/teammate/objective source IDs are shared with a flat server-authored record, bounded semantic combinations, placeholder configuration, deterministic pure validator, stable rejection precedence, and focused fixtures; gameplay-light coverage is only a later visibility-resolver input and cannot create an observation or disclosure; rendering, gameplay visibility, targeting, line of sight, discovery runtime, forgetting, AI, hearing, rays, UI, remotes, and replication remain separate and unimplemented.
- [x] **LK-0403 — Implement the pure server visibility resolver.**
  - **Work type:** Pure server-domain work.
  - **Acceptance:** server-known profiles and supplied authoritative spatial facts deterministically produce separate gameplay visibility, direct-sight eligibility, and targeting visibility without renderer data; fixtures cover darkness, light coverage, forward/peripheral/outside regions, blockers, state/range boundaries, disclosure, immutability, and unchanged P2 gates.
- [x] **LK-0404 — Integrate server-owned discovery and bounded memory runtime.**
  - **Work type:** Runtime server work.
  - **Acceptance:** one unbootstrapped server-only owner stores recipient-specific current discovery and position-free stale memory, validates trusted LK-0403 fact/result correlation, caps remembered records at 32 with deterministic age/entity-ID eviction, owns one cancellable earliest-expiry timer, emits only copied recipient-specific changes, and cleans up on expiry, recipient/entity removal, and teardown; no client mutation or replication remote, lighting runtime, raycast, enemy AI, or polished presentation.
- [x] **LK-0405 — Integrate bounded lighting-state runtime.**
  - **Work type:** Runtime server work.
  - **Acceptance:** one unbootstrapped server-only owner copies validated LK-0401 definitions, exposes flat copied activation records, supports permanent and bounded timed activation, owns one cancellable deterministic expiry timer, rejects stale transitions and active-light budget overflow, emits revisioned copied changes only for visible state mutations, and cleans up on expiration, removal, and teardown; coverage evaluation, visibility, discovery, rendering, Roblox light instances, remotes, tools, and AI remain deferred.
- [x] **LK-0406 — Add one approved flashlight or personal-light vertical slice.**
  - **Work type:** Focused tool/runtime and presentation work.
  - **Acceptance:** one production-connected personal flashlight has boolean-only server-validated intent, deterministic operative-owned LK-0401 light registration, bounded cone coverage without LOS/discovery/targeting authority, owner-only revision reconciliation, responsive accessible local presentation, P3 life-state shutdown, deterministic cleanup, focused fixtures, and two-client Studio validation; alternative tools and remote-operative cosmetics remain deferred.
- [x] **LK-0407 — Add the selected squad-navigation aid slice.**
  - **Work type:** Focused tool/disclosure work.
  - **Acceptance:** one production-connected Location-only squad ping accepts category plus candidate position only, derives identity/recipients/time/limits on the server, quantizes within 120 studs, replaces at one active per sender, caps four per squad, expires after six seconds through one deterministic scheduler, replicates revisioned safe snapshots only to current squadmates, supports G/middle-mouse, D-pad Up, and touch with text/shape non-audio presentation, and cleans up on life, roster, squad, expiry, and teardown transitions without discovery, hostile, targeting, minimap, compass, or tracking authority.
- [x] **LK-0408 — Complete P4 security, performance, and integration validation.**
  - **Work type:** Validation and focused defect repair only.
  - **Acceptance:** cross-system fixtures and source/runtime audits prove adversarial clients cannot alter visibility, discovery, lights, memory, pings, squad recipients, or P2 targeting; representative 1/2/4-player measurements remain bounded at 1/2/4 gameplay lights, 1/2/4 pings, one P4 expiry scheduler, 15/23/39 P4 connections, zero bootstrapped memory tables, and zero P4 shadows/particles/visibility rays; two-client Studio observation verifies accessible flashlight/ping presentation, life-state isolation, disconnect cleanup, and zero final owner counts; all prior fixtures and scoped source/build checks pass; the unchanged-tree StyLua line-ending limitation is documented separately; no production defect, optimization, or P5 work was required.

### P4 execution order

`LK-P4-PLAN-001` → `LK-0401` + `LK-0402` → `LK-0403` → (`LK-0404` + `LK-0405`) → (`LK-0406` + `LK-0407`) → `LK-0408`. `LK-0406` also depends on `LK-0405`; `LK-0407` depends on the disclosure contract/runtime it uses. No P5 enemy runtime begins during P4.

### P4 exit criteria

One to four operatives can navigate, regroup, and use only the selected bounded aids under readable darkness. The server controls gameplay visibility, discovery, memory, lighting state, and targeting disclosure; local rendering cannot expose or legalize hidden information; performance and accessibility criteria are measured without adding P5 systems.

**P4 status:** Complete. Prototype visibility/discovery production orchestration, hostile-load profiling, remote-operative flashlight cosmetics, broader squad tooling, and enemy behavior remain deferred to their explicitly planned later milestones.

## P5 — Enemy spawning, pursuit, and horde pressure

Implement basic enemy lifecycle, fair spawn rules, pursuit, attacks, authored waves, roaming pressure, escalation triggers, recovery windows, and representative performance measurement.

- [x] **P5-0101 — Establish the Living Kingdoms world foundation.**
  - **Work type:** Environment, atmosphere, and documentation only.
  - **Acceptance:** one deterministic 640 × 640 stud Appalachian exclusion-zone graybox is immediately walkable from the ranger-station insertion; dense mixed forest, terrain elevation, ridges, ravine/creek, trails, logging road, rocks, fallen timber, clearings, and natural choke points establish navigation language; all eight requested landmarks are recognizable and attributed; moonlight, readable fog, sparse emergency/generator illumination, local wind, and power fluctuation establish atmosphere; evacuation evidence communicates recent abandonment; camera bounds contain the operation; no enemy, weapon, mechanic, inventory, crafting, progression, extraction logic, or story scripting is introduced; configuration fixtures and repository tooling pass; final visual Studio review remains required and is documented honestly.
- [x] **P5-0102 — Improve world readability and landmark identity.**
  - **Work type:** Environment readability and documentation only.
  - **Acceptance:** all eight landmarks receive distinct recognizable graybox identities; authored segment clearance protects the logging road, switchbacks, creek-to-extraction connection, insertion route, and approach reveals from the gameplay camera; fog range, moon direction, path/terrain contrast, and a restrained emergency-light hierarchy keep destinations identifiable in darkness; the deterministic vegetation budget is reduced while retaining the boundary silhouette; no per-prop scripts, particles, shadow-casting local lights, audio, gameplay authority, or new runtime services are added; configuration fixtures and repository tooling pass; final visual Studio review remains documented in the smoke test.
- [x] **P5-0103 — Build the first playable operation.**
  - **Work type:** Mission orchestration, authored configuration, placeholder presentation, and documentation.
  - **Acceptance:** Operation Blackwater Relay runs insertion → infiltration → exfiltration → holdout → resolved entirely on server timestamps and server-read facts; the single relay objective revalidates every acceptance fact server-side in a stable first-failure order and commits exactly once; extraction unlock, the beacon, the presence-checked 90-second holdout, and terminal success/failure follow the specification; squad wipe or full-squad disconnect resolves failure from any phase; clients receive only validated safe snapshots through one server→client remote and can request nothing but the objective interaction; escalation reuses the existing stationary fixtures as a documented Studio-only placeholder pending the production enemy runtime; mission fixtures, all prior fixtures, and scoped source/build checks pass.
- [x] **P5-0104 — Define enemy contracts, configuration, and pure behavior resolution.**
  - **Work type:** Shared declarations, balance configuration, and pure server logic only.
  - **Acceptance:** stable enemy vocabulary (archetype, behavior states, spawn sources, spawn/attack rejection reasons) lives in one shared contracts module; every balance value — walker health/speed/detection/attack profile, fair-spawn distances, population caps, roaming cadence per escalation level, recovery windows, and cleanup timing — lives in one shared configuration module with validated invariants; one pure resolver derives fair-spawn legality in a stable first-failure order and per-enemy behavior transitions (roam, pursue, attack, stand-down, death inertness) deterministically from caller-supplied facts and timestamps with no Roblox services, loops, or input mutation; focused fixtures cover boundaries, ordering, tie-breaks, cooldowns, and immutability.
- [x] **P5-0105 — Implement the production enemy lifecycle and pressure runtime.**
  - **Work type:** Runtime server work.
  - **Acceptance:** one server-only director owns enemy identity, spawning, graybox bodies, health, behavior, movement intent, attacks, death, and cleanup; spawns are validated by the pure resolver and unfair placements defer to a bounded retry queue instead of appearing beside operatives; pursuit and attacks derive victims only from server-owned positions and P3 life state, route damage through the existing authoritative life commit boundary with deterministic duplicate-protected damage events, and never trust a client fact; roaming pressure follows the configured per-escalation cadence with authored-wave recovery windows; population stays within configured caps; one heartbeat connection and one bounded evaluation loop drive every enemy with zero per-enemy connections, zero raycasts, and zero client remotes; stand-down ends attacks and spawning at resolution; stop() tears down every enemy, connection, and pending spawn.
- [x] **P5-0106 — Route mission escalation and operative automatic combat through the production runtime.**
  - **Work type:** Runtime integration and focused replacement.
  - **Acceptance:** mission escalation waves spawn production enemies through the director (the Studio-only fixture path is removed from the mission), infiltration begins roaming pressure, and resolution stands pressure down; one production automatic-combat owner composes the existing pure P2 selection/fire/hit/damage/reload resolvers against director-owned enemies for every operative with darkness-bounded gameplay visibility, a bounded per-evaluation line-of-sight raycast budget, server-derived obstruction results, and P3 life-state restrictions; enemy deaths from operative fire commit through the director's revisioned health boundary; the revive flow reads and commits its combat companion state from the production owner so revives work outside Studio; the reload intent remote remains the only client-to-server combat input and the development harness is no longer bootstrapped; mission, revive, and combat fixtures prove the routing.
- [x] **P5-0107 — Complete P5 integration validation and performance measurement.**
  - **Work type:** Validation and documentation only.
  - **Acceptance:** cross-system fixtures prove adversarial clients cannot spawn, move, damage, kill, or despawn enemies, cannot forge enemy-sourced operative damage, and cannot expand the combat request surface; representative 1/2/4-operative measurements stay bounded at the configured population caps, one enemy heartbeat, one combat heartbeat, zero per-enemy connections or timers, and the configured per-evaluation raycast budget; wave, roaming, recovery-window, and stand-down pacing are exercised end-to-end against the mission flow; all fixtures and scoped source/build checks pass; remaining Studio verification is documented honestly.

### P5 execution order

`P5-0101` → `P5-0102` → `P5-0103` → `P5-0104` → `P5-0105` → `P5-0106` → `P5-0107`.

### P5 exit criteria

One to four operatives experience server-owned enemy pressure across the authored operation: fair spawns, pursuit, melee attacks resolved through the authoritative life boundary, authored escalation waves, roaming pressure with recovery windows, and automatic operative fire that can kill production enemies everywhere — not only in Studio. Population, evaluation, and raycast budgets are measured and bounded, and no client request can create, steer, damage, or reveal an enemy.

**P5 status:** Complete. A live multiplayer Studio playthrough of the full pressure loop remains the outstanding manual check and is documented in the smoke test. Special enemies, bosses, pathfinding around obstacles, enemy-versus-cover behavior, ammunition scarcity tuning, and final balance remain deferred to their planned milestones.

**Superseded parallel P5 implementation:** a concurrent agent session merged an alternative P5-0104–P5-0106 enemy slice (`EnemyLifecycleService`, `EnemyAssemblyRuntimeService`, `ProductionAutomaticCombatService`, `EnemyOperationIntegrationService`, `PressurePacingDomain`, `EnemyObservabilityService`, and their specs/fixtures; PRs #58–#59). Two enemy runtimes cannot share the mission, `ReloadIntent`, and the hostile population, so that slice was removed when this milestone merged: it never rewired `MissionDirectorService` off the retired Studio-fixture path, left revive coordination on the Studio-only harness, and shipped without roadmap/spec updates. Its Lune CI workflow and pinned Lune toolchain entry were kept. The code remains available in Git history; its sampled observability counters are a candidate follow-up for the retained `EnemyDirectorService`.

## P6 — Ammunition scarcity and supply collection

Replace temporary firearm resources with server-owned finite ammunition, supply caches at authored risky locations, collection rules, clear inventory feedback, and balance telemetry sufficient to distinguish tension from unavoidable starvation. Canonical specification: `docs/specifications/ammunition-scarcity-and-supply.md`. Full acceptance gates: [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md).

- [x] **P6-0101 — Define ammunition scarcity contracts and configuration.** Stable supply/collection/ammunition/rejection vocabulary and canonical finite values in shared configuration; pure declarations and fixtures only.
- [x] **P6-0102 — Replace temporary production ammunition with finite configured state.** Production combat initializes from the canonical finite values; fire, reload, revive, restriction, and respawn paths cannot refill or forge ammunition.
- [x] **P6-0103 — Author risky ammunition-cache locations.** Deterministic configuration-driven cache identity, compatibility, grant size, and world position creating route decisions without hidden random supply.
- [x] **P6-0104 — Implement server-owned cache collection.** The server derives identity, distance, life eligibility, capacity, duplicate history, grant, and commit; one collection per cache per operative with independent squadmate access.
- [x] **P6-0105 — Add authoritative ammunition HUD feedback.** Personal loaded/reserve state and collection grants presented without client ammunition authority.
- [x] **P6-0106 — Add per-operative cache depletion feedback.** Consumed caches stop prompting only for the collecting operative; server-owned collection history stays authoritative.
- [x] **P6-0107 — Add sampled scarcity telemetry and a Studio validation probe.** Conservation-derived accepted-shot accounting with read-only, Studio-only, scheduler-free snapshots of grants, cache use, minimums, dry transitions, and roster.
- [x] **P6-0108 — Run the controlled 1/2/4-operative evidence matrix.** Owner-reported local multiplayer tests passed for prototype progression; raw routed telemetry was not retained and remains a P12 limitation.
- [x] **P6-0109 — Tune scarcity from evidence and sign off P6.** No unsupported tuning change was applied; current prototype values are locked pending measured P12 validation.

### P6 execution order

`P6-0101` → `P6-0102` → `P6-0103` → `P6-0104` → `P6-0105` → `P6-0106` → `P6-0107` → `P6-0108` → `P6-0109`.

### P6 exit criteria

One to four operatives use finite server-owned ammunition and independently consume authored risky caches with clear personal feedback. Comparable Studio evidence shows that careful play creates pressure and recovery decisions without predetermined starvation, and P6 values are tuned from measurements rather than intuition.

**P6 status:** Complete for the current prototype (`P6-0101`–`P6-0109`). The owner accepted the requested local multiplayer test result. Raw routed telemetry remains explicitly deferred to P12, and no balance values were invented or changed without it.

## P7 — Three interdependent MVP classes

Implement combat specialist, medic, and engineer responsibilities, limitations, cross-class interactions, class choice, and multiplayer verification. The engineer may restore ammunition only within strict scarcity constraints. Canonical specification: `docs/specifications/mvp-specialist-classes.md`.

- [x] **P7-PLAN-001 — Specify and decompose the three starting classes.** Role philosophy, duplicate/solo policy, selection and lock timing, action lifecycle, trust boundaries, resource ownership, observability, accessibility, budgets, ordered tasks, and deferrals.
- [x] **P7-0101 — Define shared class contracts and configuration.** Stable class/action/state/target/rejection vocabulary, selection and resource records, cooldown/channel descriptors, safe snapshots, and fixture-verified configuration; no runtime effects. Completed under the bounded [P6/P7 sequencing exception](SEQUENCING-EXCEPTION-P6-P7.md).
- [x] **P7-0102 — Implement server-owned class selection and assignment.** Briefing-only selection of unlocked starting classes, insertion lock, duplicate-class support, identity-keyed roster, fail-closed stale/cross-player requests, one narrow request/state network, deterministic lifecycle. Completed under the same bounded exception.
- [x] **P7-0103 — Add the combat specialist vertical slice.** Server-owned Brace provides a bounded cadence benefit for six seconds, ends on movement/life/reload/mission interruption or cancellation, enters a fourteen-second cooldown, and exposes compact accessible owner feedback without bypassing combat authority.
- [x] **P7-0104 — Add the medic vertical slice.** Three server-owned treatment charges commit 25 health through the revisioned P3 life owner after a continuous three-second channel; medic revives remain in the existing P3 session/commit path with a `0.75` duration multiplier and 40 restored health. No self-revive, dead-revive, or fabricated health.
- [ ] **P7-0105 — Add the engineer vertical slice.** Finite operation-issued resupply committed through the existing ammunition authority within compatibility and reserve caps; objective repair remains a P8 integration.
- [ ] **P7-0106 — Integrate cross-class interactions and squad presentation.** Readable class identity, resources, cooldowns, teammate cues, and concise failure reasons proving the intended cooperation loop without color- or audio-only signals.
- [ ] **P7-0107 — Complete class security, scaling, and multiplayer validation.** Adversarial fixtures plus solo, duplicate-class, and 2/3/4-operative Studio evidence for contribution frequency, viability without a role, and balanced-squad advantage.

### P7 execution order

`P7-PLAN-001` → `P7-0101` → `P7-0102` → (`P7-0103` + `P7-0104` + `P7-0105`, one PR at a time) → `P7-0106` → `P7-0107`. Contracts, selection, combat specialist, and medic are complete; `P7-0105` is next.

### P7 exit criteria

Players choose and retain a server-owned starting class for the run. Each class contributes frequently, has a meaningful limitation and finite resource/cooldown, interacts with another role, and remains secure under multiplayer abuse. Any composition can attempt the operation while a balanced squad has more resilient options.

**P7 status:** In progress. Planning, contracts, selection/assignment, Combat Specialist Brace, and Medic treatment/revive assistance are complete (`P7-PLAN-001` through `P7-0104`); `P7-0105` engineer is next.

## P8 — Authored operation objectives

Expand Operation Blackwater Relay from its single relay interaction into a complete two-or-three-objective route that forces relocation, creates temporary defensive value, and communicates objective truth clearly.

- [ ] **P8-PLAN-001 — Specify the authored objective chain.** Exact objectives, locations, order/branching, interactions, class opportunities, failure conditions, escalation effects, defensive value, and relocation pressure mapped to existing landmarks and mission phases.
- [ ] **P8-0101 — Define objective contracts and authored configuration.** Stable objective/step/interaction/progress/failure/completion vocabulary with versioned authored definitions and pure validation fixtures.
- [ ] **P8-0102 — Implement the generic server-owned objective runtime.** One owner validates phase, revision, identity, state, class, range, line of sight, continuity, prerequisites, and replay before committing progress; clients declare nothing.
- [ ] **P8-0103 — Replace the placeholder relay interaction with objective one.** First authored objective delivered through the generic runtime and existing mission authority without a parallel state machine.
- [ ] **P8-0104 — Add objective two and the optional third objective.** Each objective teaches or tests a different cooperation/resource behavior with deterministic order and prerequisites.
- [ ] **P8-0105 — Add relocation pressure and temporary defensive-position value.** Timing, pressure, approaches, and resources make at least one hold position temporarily useful but never indefinitely optimal; no base building or barricade economy.
- [ ] **P8-0106 — Integrate class opportunities without class gates.** Meaningful moments for every starting class, including the engineer's approved objective-equipment repair; no required objective becomes impossible without a class.
- [ ] **P8-0107 — Add objective and route presentation.** Squad UI for current objective, P4-permitted guidance, progress, interruption, completion, failure, and next destination without disclosing hidden threats or distant supply.
- [ ] **P8-0108 — Complete objective-chain security and 1/2/4-player validation.** Replay/spam/phase/class/distance/revision/disconnect/wipe/teardown coverage plus Studio proof of the full chain, forced relocation, temporary defense, and bounded runtime work.

### P8 execution order

`P8-PLAN-001` → `P8-0101` → `P8-0102` → `P8-0103` → `P8-0104` → (`P8-0105` + `P8-0106`) → `P8-0107` → `P8-0108`.

### P8 exit criteria

The squad completes a readable two-or-three-objective authored route that uses existing landmarks, forces movement, rewards temporary defense and class cooperation, and remains fully server-authoritative from interaction through escalation and failure.

**P8 status:** Not started; begins after P7 completes.

## P9 — Special enemy and boss encounter

Add one special enemy that disrupts a reliable tactic and one readable boss climax that demands coordination and tests lessons taught earlier in the operation.

- [ ] **P9-PLAN-001 — Specify the special enemy and boss encounter.** The disrupted tactic, counterplay, telegraphs, phases, arena, objective connection, class contributions, failure readability, accessibility, spawn policy, and performance budgets.
- [ ] **P9-0101 — Define special-enemy contracts, configuration, and pure decisions.** Stable archetype/action/state/rejection vocabulary, tuning values, and a pure resolver for targeting, legal ability use, cooldowns, interruption, death inertness, and tie-breaks.
- [ ] **P9-0102 — Integrate the special enemy into the production director.** Reuse the existing enemy identity/health/spawn/damage/cleanup/stand-down owner and bounded evaluation; no per-enemy scheduler or client authority.
- [ ] **P9-0103 — Define boss contracts, configuration, and phase resolver.** Stable phase/transition/vulnerability/attack/summon/objective/outcome vocabulary with pure deterministic phase transitions from server-owned facts.
- [ ] **P9-0104 — Implement the boss runtime and authored arena integration.** One boss instance owned through production enemy/operation boundaries with revision-safe, bounded, cleaned-up phases, attacks, adds, and terminal state.
- [ ] **P9-0105 — Add readable telegraphs and accessible presentation.** Redundant position/timing/shape/text/animation/audio cues for every dangerous action without early disclosure or client-legalized hits.
- [ ] **P9-0106 — Complete encounter security, performance, and class-composition validation.** Forged-fact/stale/disconnect/wipe/replay/cleanup coverage, representative 1/2/4 horde-plus-boss profiling, and Studio proof that counterplay is attributable.

### P9 execution order

`P9-PLAN-001` → `P9-0101` → `P9-0102` → `P9-0103` → `P9-0104` → `P9-0105` → `P9-0106`.

### P9 exit criteria

The special enemy clearly disrupts one dominant tactic with learnable counterplay. The boss provides a readable coordinated climax, accepts contributions from all starting classes, respects prior resource decisions, and runs within bounded server performance.

**P9 status:** Not started; begins after P8 completes.

## P10 — Match completion, failure, and extraction

Turn the existing mission terminal state into a complete player-facing match loop: final extraction or holdout, authoritative success/failure, understandable results, deterministic cleanup, and a safe replay path.

- [ ] **P10-PLAN-001 — Specify terminal operation flow and result semantics.** Success/failure causes, extraction rules, result and contribution facts (for P11), cleanup ownership, replay behavior, leave/disconnect/rejoin policy, and disclosure.
- [ ] **P10-0101 — Define match-result and extraction contracts/configuration.** Stable result/cause/extraction/readiness/cleanup/replay vocabulary and safe result snapshots containing only server-authored operation facts.
- [ ] **P10-0102 — Implement one authoritative terminal-result resolver.** Every terminal cause converges on one first-commit-wins boundary; duplicates and races cannot produce multiple results.
- [ ] **P10-0103 — Integrate the final extraction or holdout sequence.** Server-read, revision-safe presence, timing, prerequisites, and pressure with explicit late-entry/departure/incapacitation/disconnect behavior.
- [ ] **P10-0104 — Add result presentation.** Success/failure screens explaining cause, key events, contribution facts, and next action; no XP or unlock promises before P11 commits them.
- [ ] **P10-0105 — Implement deterministic match cleanup and replay.** Documented stop order across every runtime owner; replay creates a fresh operation identity with zero stale timers, connections, revisions, histories, resources, enemies, or results.
- [ ] **P10-0106 — Complete leave, disconnect, rejoin, and shutdown handling.** Explicit session-retention, resume, and abandonment rules; no disconnect duplicates contribution, resources, life, credit, or rewards.
- [ ] **P10-0107 — Validate the full non-persistent match loop.** Automated coverage of every terminal cause, race, replay, and cleanup owner plus 1/2/4-operative Studio runs across success, failures, abandonment, and replay without developer intervention.

### P10 execution order

`P10-PLAN-001` → `P10-0101` → `P10-0102` → `P10-0103` → `P10-0104` → (`P10-0105` + `P10-0106`) → `P10-0107`.

### P10 exit criteria

A complete operation ends once in an understandable success or failure, cleans up every runtime owner, and can begin a fresh replay without stale state. The loop works for one to four operatives and safely handles leave/disconnect edge cases.

**P10 status:** Not started; begins after P9 completes.

## P11 — Persistent XP, ranks, and class unlock

Implement server-owned XP awards for victory and limited meaningful participation on failure, a small military-style rank ladder, reliable persistence, anti-idle safeguards, and at least one side-grade specialist class unlock. No paid power or material permanent stat inflation.

- [ ] **P11-PLAN-001 — Specify progression, persistence, and the unlockable class.** XP sources, contribution vocabulary, weighting, anti-idle rules, rank ladder, unlock identity and rank, schema/versioning, retry policy, observability, privacy, and migration.
- [ ] **P11-0101 — Define progression contracts and configuration.** Stable profile/rank/XP-event/contribution/award/unlock/load-save/rejection vocabulary with configuration-driven, fixture-tested curves and caps.
- [ ] **P11-0102 — Implement a persistence adapter with versioning and failure recovery.** Server-only DataStore access, session ownership, schema validation/migration, bounded retry, update-safe writes; match correctness never depends on persistence availability.
- [ ] **P11-0103 — Implement pure contribution and XP award resolution.** Awards derive only from P10 terminal facts and server-recorded contribution; duplicates, invalid values, client-authored contribution, and failure farming are impossible.
- [ ] **P11-0104 — Integrate the military-style rank ladder.** XP applies once, rank derives deterministically, and progress is disclosed without material permanent stat power.
- [ ] **P11-0105 — Implement the unlockable side-grade specialist.** One distinct approved capability at an attainable rank, reusing P7 class boundaries, proven to be a side-grade rather than a stronger replacement.
- [ ] **P11-0106 — Add anti-idle and abuse safeguards.** Bounds on low-effort farming, duplicate sessions, reconnect replay, result spoofing, and save/load races without punishing legitimate support play.
- [ ] **P11-0107 — Add progression and persistence presentation.** Loaded/offline/error state, XP/rank, earned breakdown, unlock progress, and new-unlock disclosure that never claims an unconfirmed save.
- [ ] **P11-0108 — Complete persistence failure, migration, and multiplayer validation.** Corruption/old-version/timeout/throttling/duplicate/shutdown/reconnect coverage plus verified awards, rank-up, unlock, reload, and safe degraded operation.

### P11 execution order

`P11-PLAN-001` → `P11-0101` → `P11-0102` → `P11-0103` → `P11-0104` → `P11-0105` → (`P11-0106` + `P11-0107`) → `P11-0108`.

### P11 exit criteria

Players earn server-owned, duplicate-safe XP from complete matches, advance through a small rank ladder, and unlock one side-grade class. Persistence is versioned, recoverable, observable, and unable to corrupt match authority or grant paid or material permanent power.

**P11 status:** Not started; begins after P10 completes.

## P12 — Cooperative balance, performance, and polish

Tune difficulty for high but learnable failure, class dependence, scarcity, relocation pressure, solo-to-four-player scaling, horde performance, accessibility, feedback, and operation readability. Validate that architecture has no fixed four-player assumptions before expanding toward eight-player support.

- [ ] **P12-PLAN-001 — Define the release-candidate validation matrix and target experience.** Target duration, success/failure bands, scarcity/rescue/class/pacing/boss/performance goals, supported controls and accessibility scope, and release-blocking severity rules.
- [ ] **P12-0101 — Consolidate end-to-end telemetry and baseline the current build.** Comparable 1/2/3/4-operative reports across pacing, combat, scarcity, life, class, boss, results, budgets, and cleanup residue; telemetry stays read-only.
- [ ] **P12-0102 — Tune solo-to-four-player pressure scaling.** Evidence-supported configuration adjustments only, avoiding fixed player slots and preserving compatibility with a later maximum of eight.
- [ ] **P12-0103 — Tune class dependence and composition resilience.** Balanced squads gain materially better options while solo and duplicate-role squads keep a difficult but possible path; no new classes or inflation.
- [ ] **P12-0104 — Tune scarcity, relocation, and operation pacing.** Aligned ammunition, medical, objective, recovery, defense, disruption, and climax pacing without dominant camping routes or predetermined starvation.
- [ ] **P12-0105 — Profile and optimize horde, special-enemy, boss, visibility, and UI load.** Measure first, then focused changes to cadence, budgets, instances, replication, rendering, and cleanup; no speculative rewrite.
- [ ] **P12-0106 — Complete the accessibility and readability pass.** Redundant text/shape/position/timing cues, readable contrast, understandable controls, and non-audio-only warnings across every critical state.
- [ ] **P12-0107 — Audit and remove fixed-four-player assumptions.** Search every contract, roster, spawn, UI, scaling, result, persistence, and cleanup path for fixed slots; add synthetic-identity tests beyond four.
- [ ] **P12-0108 — Complete the full security and regression audit.** Re-run every client abuse case across all systems; prove no client can establish consequential state and no owner leaks after replay or shutdown.
- [ ] **P12-0109 — Run release-candidate playthroughs and close the MVP.** Repeated 1/2/3/4-operative runs across compositions and outcomes with recorded limitations, blockers, evidence, and one synchronized release-candidate status across the canon.

### P12 execution order

`P12-PLAN-001` → `P12-0101` → (`P12-0102` + `P12-0103` + `P12-0104`, evidence-driven, one PR at a time) → `P12-0105` → `P12-0106` → `P12-0107` → `P12-0108` → `P12-0109`.

### P12 exit criteria

The complete MVP operation is difficult, readable, learnable, secure, bounded, replayable, persistent, and repeatedly completable for one to four operatives without fixed-four-player architecture, paid power, or unresolved release-blocking defects.

**P12 status:** Not started; closes the MVP after P11.

## Cross-cutting horde-and-reward vertical slice (HROI)

[Issue #98](https://github.com/Razzleberrytt/atlas-game-development/issues/98) directs a bounded high-ROI product track: make the current prototype loop dense, urgent, readable, and rewarding inside one representative operation area before expanding the map. It executes as independently validated PR-sized slices over existing owners and does not change milestone authority, task IDs, or acceptance gates in this file or the execution roadmap.

Merged so far (PRs #99–#128, excluding closed-unmerged #100 and #118): horde pressure and progression-pacing tuning with a single progression source of truth; server-confirmed hit/kill impact feedback, floating damage text, shooter-specific confirmed hit markers, and critical-condition urgency; shared run-only Field XP with server-authored three-choice squad upgrades; brutally scarce enemy ammunition loot plus rare recovery and Field Intel drops; the server-owned five-weapon loadout roster with authoritative shotgun cleave and sniper pierce, detailed presentation models, and distinct per-loadout feel; six visually readable horde roles over the shared Exclusion Walker shell; threat-responsive environment mood; and the client-local AUD-0102/AUD-0103 firearm and hostile audio sets.

Since PR #128 the run-upgrade pool grew from four picks through the v4 eight-pick bridge to the **RPG-0103 twelve-pick pool**. Trauma Plating, Field Discipline, Combat Loader, Pattern Amplifier, Specialist Munitions, Expanded Feed, Scavenger Reach, and Last Magazine add bounded survival, economy, reload, weapon-pattern, special-role, ammunition-capacity, loot-positioning, and scarcity axes. `RunRpgReconciliation` locks every live upgrade to an implemented catalog entry and every live modifier ceiling within shared RPG bounds. Trauma Plating and Field Discipline retain their documented interim mechanics; Pattern Amplifier is now filtered from incompatible weapon rosters.

Outstanding scope: representative Studio playtest validation (solo and two-client pacing, weak-device tier, cap/cleanup recovery, and abuse probes per HROI-0108), the Studio visual/mix reviews recorded in the visual track, and any evidence-driven retuning those sessions require. Healing loot remains deferred until an authoritative healing contract exists.

## Cross-cutting visual production track

Production art replaces placeholders in parallel with P6–P12 under the rule that gameplay truth is stable first and presentation attaches second; it may not change authority, tuning, hitboxes, or hidden information. Canonical sequence and status: [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) (`VIS-PLAN-001` and `VIS-0101` complete; `VIS-0102` firearm presentation in progress; later entries gated by their corresponding gameplay milestones).

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
