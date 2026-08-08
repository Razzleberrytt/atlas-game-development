# Atlas — Master Roadmap v2.7

**Active authority:** Blueprint v2.7 Rollout & Observability + controlled build-ahead preparation  
**Date:** 2026-08-07  
**Current evidence claim:** E1 until accepted Studio evidence advances it

This document is the milestone-level view. Detailed runtime execution order lives in [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md), day-to-day rules live in [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md), and work that agents may safely prepare in parallel lives in [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md).

Older P0–P12 and blueprint roadmaps remain historical implementation records. They no longer authorize uncontrolled runtime work ahead of the active v2.7 gate.

## Status legend

- `[ ]` Not started
- `[~]` In progress / prepared work exists but evidence or promotion remains open
- `[x]` Complete with applicable evidence
- `[!]` Blocked by an earlier gate
- `[H]` Historical implementation record; not current execution authority

## Current program state

| Program area | Status | Current meaning |
|---|---|---|
| Repository/tooling foundation | [x] | GitHub-first source, Rojo/tooling/tests/CI and reproducible build artifacts exist. |
| Combined-game preservation | [x] | Incoming RBXL content/scripts/hierarchy were preserved as migration inputs without replacing canonical systems. |
| Core gameplay systems | [H] | Significant movement/combat/life/enemy/objective/run-build/result work exists in source. Existing behavior is preserved as an asset, not treated as proof of the new runtime gate. |
| v2.7 state/presentation rollout | [~] | **Primary runtime milestone.** R1 containment is implemented; runtime evidence is pending; #221 and #222 are prepared but intentionally blocked. |
| Parallel agent build-ahead | [~] | **Authorized preparation lane.** P0 migration truth is complete and merged (BA-001/003/070/071/072 plus the import recovery; BA-002 partial). Contract, audit and content preparation continues without activating future gameplay/runtime scope. |
| E2 Studio initialization | [!] | Cannot be claimed from documentation or CI alone. Requires captured Studio startup evidence. |
| E3 integrated solo behavior | [!] | Begins only after rollout blockers are closed enough to run a trustworthy integrated loop. |
| E4 multiplayer/adversarial | [!] | Requires two-player reset/disconnect/ownership/attribution evidence after E3 path is stable. |
| Durable persistence/value | [!] | Deliberately gated until runtime state, ownership, cleanup, and retry behavior are accepted. |
| Broader vertical-slice activation | [!] | Runtime activation waits for rollout acceptance, but isolated preparation is authorized by `AGENT-BUILD-AHEAD-QUEUE.md`. |
| Device/performance acceptance | [!] | Requires representative captures and reliability evidence, not source inference. |
| Outside-player fun/repeat intent | [!] | Requires a stable integrated build first. |
| Broad world/live-service expansion | [!] | Explicitly out of scope until the polished repeatable loop is proven. |

## Current checkpoint — 2026-08-07

Repository facts at this checkpoint:

- `main` at roadmap update start: `fda4e823bf662abbbbac2aa61e297ac7a51ed1f0`;
- evidence remains **E1**;
- canonical R1 Studio artifact remains commit `2c870d270b96064c9a06343cc088b251299373f4`, artifact ID `9009926429`;
- R1 capture tooling and deterministic evidence evaluation tooling are on `main`;
- PR #221 is a prepared draft for single physical `HordeNetwork.State` listener ownership and must not merge before R1 acceptance;
- PR #222 is stacked/prepared R2 publisher infrastructure and must not merge/activate before #221 plus its required evidence;
- the user may defer the Studio run while agents work the build-ahead queue, but deferred runtime gates are not considered passed;
- the P0 build-ahead pass merged as PR #226 changed no runtime source, no Rojo mapping and no active-place behavior, so the pinned R1 artifact remains valid and the evidence level remains E1;
- a second Studio task now exists alongside the R1 run: re-extracting the damaged preservation package. It is independent of R1 and blocks only HubTown composition work.

## North-star sequence

The target product remains one polished, replayable cooperative expedition:

```text
prepare
→ choose a build/weapon
→ readable authored route
→ mixed combat with distinct tactical questions
→ information/discovery interaction
→ repeatable dungeon/encounter sequence
→ elite/reward decision
→ boss/result
→ return
→ choose to play again
```

Exact names and implementations may be reconciled with existing Living Kingdoms systems. The roadmap protects the player-facing loop and authority boundaries rather than requiring needless rewrites.

# Phase R — Active-place rollout and incident closure

**Status: [~] ACTIVE RUNTIME LANE**

This phase controls runtime promotion. Parallel preparation is allowed only through Phase B below and may not bypass these gates.

## R0 — Inventory and baselines — Tickets 331–335

- [x] **331** Freeze a development copy and record build identity/rollback checkpoint.
- [~] **332** Inventory every direct/indirect `HordeNetwork.State` producer. Canonical source producer is identified; active-place/runtime completeness remains unproven.
- [~] **333** Inventory every effective client listener and owning controller. Canonical listeners are identified; effective Studio timing/count remains unproven.
- [!] **334** Capture baseline State attempts/sec, sends/sec, and queue symptoms. **Studio evidence required.**
- [~] **335** Capture every Highlight producer/Adornee and baseline connection/presentation gauges. Canonical source owners are inventoried; escaped active-place producer and runtime gauges remain unproven.

### Exit gate

- producer/consumer inventory is complete enough to name all known call sites;
- baseline measurements are recorded before architecture changes;
- rollback build/commit is identified.

## R1/R2/R3 — State delivery cutover — Tickets 336–345

- [~] **336** Enable the earliest compatibility listener in a development place. Source implementation and diagnostics exist; canonical R1 Studio acceptance is pending.
- [~] **337** Prove exactly one effective compatibility listener and no doubled presentation. PR #221 is prepared but blocked behind R1 acceptance and its own runtime evidence.
- [~] **338** Enable client-ready gating and delayed-controller test. Dormant publisher primitive is prepared in stacked PR #222; activation is blocked.
- [!] **339** Migrate the first producer behind semantic key + mutation-derived change token. Do not begin activation until R2 evidence passes.
- [!] **340** Prove unchanged attempts suppress and actual sends fall.
- [!] **341** Migrate round-state producer.
- [!] **342** Migrate objective-state producer.
- [!] **343** Migrate route-state producer.
- [!] **344** Migrate landmark-state producer.
- [!] **345** Capture before/after per-key rate differences.

### Exit gate

```text
listener-before-ready path understood
pre-ready current state intentionally retained/gated
semantic keys distinguish independent current facts
unchanged state is suppressed
actual network send rate is bounded by mutation
no newly doubled client presentation
```

## R4 — Presentation ownership — Tickets 346–350

- [!] **346** Route route-guide highlighting through the shared lease registry.
- [!] **347** Route landmark highlighting through the shared lease registry.
- [~] **348** Enable broad-target rejection and investigate every violation. Conservative containment is implemented; runtime rejection count/root-cause attribution remains pending.
- [!] **349** Run stream-out/rebind for route, landmark, secret, and marked target.
- [!] **350** Capture baseline/peak/end presentation gauges.

### Exit gate

```text
one production Highlight owner
route and landmark semantic ownership remain distinct
0 broad production Highlight targets
stream-out suspends local visual without clearing gameplay truth
rebind restores correct visual when target returns
presentation objects return to baseline after cleanup
```

## R5 — Soak, closure, and compatibility removal — Tickets 351–360

- [!] **351** Run five resets and compare state/network/connection/presentation gauges.
- [!] **352** Run three respawns and compare viewmodel/camera/connection/presentation gauges.
- [!] **353** Run delayed-ready and late-join matrix.
- [!] **354** Run two-player reset/disconnect matrix.
- [!] **355** Run 100 animation plays and verify marker-listener stability.
- [!] **356** Run a ten-minute active network/presentation soak.
- [!] **357** Capture representative client/server profiling/network evidence.
- [!] **358** Close all P0/P1 rollout defects and rerun affected matrices.
- [!] **359** Assemble the incident closure packet and conduct promotion review.
- [!] **360** Remove compatibility only for ledger rows with accepted replacement evidence and a retained rollback checkpoint.

### R5 promotion gate

All must be captured, not assumed:

```text
all legacy producers/consumers inventoried
intended compatibility listener count understood
0 queue/discard warnings in accepted normal play
semantic sends bounded by real state change
route/landmark/status Highlight ownership centralized
0 broad production Highlight targets
five-reset gauges return to baseline
three-respawn gauges return to baseline
delayed-ready/late-join current-state reconstruction passes
stream-out/rebind passes
100 animation plays do not multiply marker listeners
two-player reset/disconnect attribution and cleanup pass
closure packet accepted
rollback checkpoint retained for each removed compatibility row
```

# Phase B — Parallel build-ahead preparation

**Status: [~] ACTIVE PREPARATION LANE**

This phase allows meaningful work while the user defers Studio-only validation. It does **not** authorize runtime activation or evidence promotion.

The canonical detailed queue is [`AGENT-BUILD-AHEAD-QUEUE.md`](AGENT-BUILD-AHEAD-QUEUE.md).

## B0 — Combined-game migration truth

Highest priority because it turns the preserved RBXL import into a controlled integration plan.

- [x] HubTown migration manifest. `docs/migration/hubtown-migration-manifest.json`, 81 recovered rows claimed exactly once.
- [~] Authored-world migration manifest covering structures, ruins, landmarks, resources, portals, NPC structures, lighting and VFX. All 41 provable rows covered; `Workspace/WorldStructures` has no surviving child row, so the manifest is **partial pending Studio re-extraction**.
- [x] Disposition matrix for all preserved Studio-only scripts. All 28 classified; 17 from recovered source, 11 from identity plus reference copies.
- [ ] Stable world-content ID/contracts and reference validation. Manifest/graph reference validation is done (BA-072); the Luau contracts (BA-004) are not started.
- [x] Combined-game dependency graph. `docs/migration/combined-game-integration-graph.json`, 26 nodes, CI-validated and acyclic.
- [x] Source audits preventing legacy gameplay-service resurrection. `tests/LegacyServiceResurrectionSourceAudit.test.luau`.

### B0 finding — the preservation package is damaged

Sourcing this work surfaced a defect that bounds everything above: the
2026-08-07 RBXL preservation archives do not restore. 17 of 28 Studio-only
sources and 122 of 1,775 Workspace instance rows survive; the rest is
unrecoverable from the repository. `VALIDATION.md` had asserted a lossless
round trip that is not reproducible, and has been corrected.

The recoverable material is now stored as plain text under
`games/living-kingdoms/imports/studio-2026-08-07/recovered/` and pinned in CI by
`scripts/verify_studio_import_package.py`. The finding and the required Studio
re-extraction steps are in
[`../production/RBXL-IMPORT-INTEGRITY-2026-08-07.md`](../production/RBXL-IMPORT-INTEGRITY-2026-08-07.md).

This does not change the evidence level and does not affect the active-place
runtime, the pinned R1 artifact, or any canonical source.

## B1 — Gameplay-domain preparation

May be prepared as pure/dormant contracts and tested modules without bootstrap/runtime wiring:

- [ ] quest definitions and deterministic state resolver;
- [ ] NPC definitions/interactions;
- [ ] crafting recipes/resolver;
- [ ] gathering/resource-node definitions;
- [ ] vendor/catalog/pricing contracts;
- [ ] dungeon/expedition and portal contracts;
- [ ] cross-domain ID/orphan/cycle validation.

## B2 — Vertical-slice content preparation

- [ ] first HubTown composition specification;
- [ ] first authored outdoor route data;
- [ ] mixed encounter beat definitions;
- [ ] landmark/discovery definitions;
- [ ] first repeatable dungeon content data;
- [ ] elite/boss reward-decision data;
- [ ] first-session onboarding sequence.

## B3 — Depth audits and controlled primitives

- [ ] enemy-archetype coverage audit;
- [ ] randomized loot/build-decision coverage audit;
- [ ] progression/skill mapping audit;
- [ ] PC/mobile/controller action-map audit;
- [ ] UI information architecture;
- [ ] prepare narrowly scoped missing pure/config primitives only after audits identify a concrete vertical-slice need.

## Build-ahead promotion boundary

A build-ahead branch may be fully coded and CI-green while still being intentionally unmerged or dormant.

Before runtime activation:

```text
no duplicate canonical service
no new authoritative client path
no early R2/R3/R4 cutover
no legacy bootstrap resurrection
no claim of Studio behavior from source CI
runtime wiring separated from preparation
applicable v2.7 gate accepted
```

# Phase E — Evidence promotion

**Status: [!] BLOCKED BY PHASE R**

## E2 — Studio initialization

Accept when the repository-synchronized development place starts, required systems initialize, diagnostics are readable, and no blocking initialization/runtime error invalidates the run.

## E3 — Single-player integrated behavior

Accept after the intended loop can be repeated cleanly with stable state/presentation ownership and evidence explaining important failures/outcomes.

Required emphasis:

- authoritative combat/life/outcome;
- route/objective readability;
- reset/respawn cleanup;
- reward/build state consistency;
- no compatibility regression.

## E4 — Multiplayer/adversarial

Accept after two-player ownership, attribution, reset, disconnect, delayed readiness, replay/retry, and audience isolation behave correctly under deliberate edge cases.

# Phase D — Durable value

**Status: [!] BLOCKED UNTIL R + E3/E4**

Resume the durable-value sequence only after runtime ownership is trustworthy:

1. persistence adapter boundary;
2. session ownership/lease rules;
3. sequential migrations;
4. no-blank-overwrite protection;
5. unknown-write reconciliation;
6. inventory/reward overflow recovery;
7. deterministic/idempotent transaction replay;
8. leave/rejoin/shutdown/failure testing.

Do not persist a state model that is still leaking or duplicating in memory.

# Phase V — Vertical-slice integration

**Status: [!] RUNTIME ACTIVATION BLOCKED; PREPARATION AUTHORIZED BY PHASE B**

After runtime/durable-value gates permit it, promote prepared work into the smallest complete replayable expedition rather than expanding breadth.

Suggested dependency order:

1. preparation/loadout start;
2. HubTown/safe-space composition and portal entry;
3. authored outdoor route and landmarks;
4. mixed-combat sequence;
5. optional discovery/secret interaction;
6. repeatable dungeon/room sequence;
7. elite + meaningful item decision;
8. boss/terminal outcome;
9. return/replay invitation.

Each integration step must use the accepted state/presentation/lifecycle architecture rather than reintroducing legacy broadcast or competing visual ownership.

# Phase Q — Device, performance, accessibility, and reliability

**Status: [!] REQUIRES REPRESENTATIVE BUILD**

Accept only from measured evidence:

- desktop and mobile frame-time captures;
- network send-rate profile;
- streaming behavior;
- memory/presentation-object stability;
- low-graphics readability;
- reduced-motion behavior;
- UI safe-area/input coverage;
- multiplayer server soak.

# Phase F — Outside-player fun gate

**Status: [!] REQUIRES STABLE INTEGRATED LOOP**

Fresh players should be able to explain:

- what their goal was;
- why they took damage or failed;
- what different enemy/encounter pressures asked them to do;
- what their build/reward choice changed;
- what they wanted to do next.

The strongest signal is voluntary replay, not roadmap completion.

# Scope protection

Do not start broad runtime expansion while any active stop condition is open. The build-ahead queue is intentionally narrower than unrestricted feature development.

Not authorized yet:

- multiple large regions/continents;
- PvP;
- raids;
- housing;
- unrestricted trading/auction house;
- battle pass/seasons solely to manufacture retention;
- dozens of classes or hundreds of items before the first build loop is readable;
- vehicles/mounts;
- broad monetization catalog;
- speculative backend complexity unsupported by the vertical slice.

# Stop conditions

Stop and fix when:

- remote queue/discard warnings occur in supported normal play;
- state rate/connections/presentation objects grow across reset without a real gameplay reason;
- a broad Highlight hides gameplay;
- two controllers own the same visual primitive;
- late join/delayed readiness loses current facts;
- stream-out is interpreted as gameplay completion;
- animation listeners multiply;
- viewmodel/camera ownership duplicates after respawn;
- client input can author damage, rewards, inventory, progression, or ownership;
- low-graphics/mobile removes critical information;
- an evidence claim cannot point to a reproducible packet;
- build-ahead work boots a preserved legacy service beside its canonical replacement;
- a preparatory branch quietly activates runtime behavior that its roadmap gate has not authorized.

# Historical milestone records

Detailed P0–P12, HROI, RPG, VIS, and earlier blueprint histories are retained in the versioned/historical roadmap files and Git history. They remain useful when understanding why systems exist, but they do not override the v2.7 runtime queue, the promotion gates, or the controlled Phase B build-ahead queue.

> Current strategy: keep the runtime rollout disciplined while using agent time to eliminate future integration uncertainty.
