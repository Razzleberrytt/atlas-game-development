# Atlas — Agent Build-Ahead Queue v2.9

**Status:** ACTIVE PREPARATION LANE  
**Refreshed:** 2026-08-09  
**Primary use:** sequential coding-agent work while Blueprint v2.7 runtime evidence remains gated by Studio evidence

This queue authorizes useful preparation without pretending the active runtime rollout has passed.

It does **not** replace Blueprint v2.7. Runtime activation, state/presentation migration, evidence promotion, and compatibility removal remain controlled by Blueprint v2.7.

Read first:

1. [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md)
2. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md)
3. [`BLUEPRINT-V2.7-EXECUTION.md`](BLUEPRINT-V2.7-EXECUTION.md)
4. [`PRODUCTION-CORE-V2.7.md`](PRODUCTION-CORE-V2.7.md)
5. this queue
6. `games/living-kingdoms/CANONICAL-RUNTIME.md`

## Current gate snapshot

- Repository: `Razzleberrytt/atlas-game-development`
- Game path: `games/living-kingdoms`
- Checkpoint used for this refresh: `51bad3f948985bb0530d83a7ed10e02b4a55b5d7` (PR #318 merged)
- The task table below reflects current status; always re-fetch `main` and inspect open related PRs before starting work. **No READY task is reserved to Codex, Claude, or any other named agent.** While coding-agent quotas are constrained, work proceeds sequentially: finish and merge one task before claiming the next unless the user explicitly re-enables parallel execution.
- Evidence: **E2** (pinned-artifact Studio initialization/R1; later integrated matrices remain open)
- Studio import preservation is **repaired**: 28/28 Studio-only sources and 1,775/1,775 Workspace identity/hierarchy rows are preserved.
- Property-backed authored-world recovery is now available; older documents that cite only 122 recoverable Workspace rows are historical damage-state evidence, not current truth.
- The recovered authored overworld is a separate future coordinate/lifecycle space from the modern operation forest.
- The live Ranger Station Forward Operations Hub is a temporary preparation bridge, not the final Main World.
- R1 is accepted on recorded artifact 9028866465; the older pre-bootstrap-fix artifact remains invalid historical evidence.
- PR #221 is merged with its exact-build single-listener evidence accepted at E2; later runtime matrices remain open.
- PR #222 is merged as dormant R2 preparation only; `ClientReady` activation and R2 runtime evidence remain separate controlled work.
- PR #239 is merged as the held pre-launch operation-selection contract; its runtime/network/launch handoff remains disabled.
- BA-020 through BA-025 are merged preparation; BA-026 remains separately blocked by the Master ECON gate.
- BA-062's M1-M5 and C1-C4 source findings are remediated through the canonical action map, gamepad/touch coverage, prompt-key separation, UI close/label cleanup, and fail-closed numbered-choice coordination. Direct keyboard/gamepad claims are collision-free in source. PRs #286 and #287 add truthful Squad Ping and class-action presentation copy; the later primary-combat-mode path also routes Field Hatchet primary attack across mouse/R2/generated touch. **No real-device acceptance is claimed; consolidated Studio/device verification remains open.**
- MVP 0.1 source implementation is now end-to-end built through PRs #293–#318: deliberate safe replay, canonical First Descent seed/composition and boss reward, authored Approach combat and Lookout Cache discovery, server-authoritative melee → earned-firearm opening, failure forfeiture, temporary-run reset, live durable-inventory leases, durable equip/start-loadout handoff, and existing-menu durable equipment interaction. The milestone remains **BUILT — VERIFICATION PENDING**, not VERIFIED.

## Two-lane rule

### Lane A — active runtime rollout

Controlled by Blueprint v2.7 Tickets 331–360.

Never bypass:

- valid R1 evidence;
- single-listener validation;
- delayed-ready/late-join evidence;
- semantic/change-token cutover evidence;
- centralized presentation ownership evidence;
- reset/respawn/multiplayer/soak closure.

### Lane B — build-ahead preparation

Agents may prepare future architecture/content in isolated, reviewable changes when it does not activate gated runtime behavior.

Allowed forms include:

- pure contracts/resolvers;
- configuration/data;
- held authored-world reconstruction;
- audits;
- documentation/decisions;
- validators/tooling;
- source/security audits;
- dormant adapters/interfaces;
- content definitions that are not booted.

## Build-ahead laws

1. Fetch current `main` and inspect open related PRs before editing.
2. Do not duplicate work already in an open PR.
3. Treat merged preparation as dormant unless runtime/evidence authority explicitly promotes it.
4. Do not activate R2/R3/R4 cutovers early.
5. Do not create a second gameplay authority for combat, enemies, inventory, persistence, loot/rewards, progression, economy, missions, networking, or presentation.
6. Recovered Studio gameplay services remain inert; migrate content/data/presentation into canonical owners.
7. Keep authored overworld and operation-forest coordinate/lifecycle spaces separate.
8. Runtime wiring must be separated from preparation.
9. Source CI does not prove Studio behavior.
10. An unrun consolidated Studio/device pass is not a source-work lock by itself: when Playable MVP authority marks the current milestone **BUILT — VERIFICATION PENDING** and no known runtime failure invalidates assumptions, dependency-safe next-patch source work may continue. Any actual runtime/device failure preempts that work and returns priority to FIX.
11. Every source change needs focused tests and full applicable validation.
12. Future phases in Master Roadmap v2.8 remain locked unless this queue or the higher-precedence Playable MVP authority explicitly makes them current/eligible.
13. READY work is unassigned. Do not reserve tasks to Codex, Claude, or another named agent; while quota-limited sequential mode is active, finish and merge the current task before starting the next.

## Status values

- `READY` — may begin now after checking current main/open PRs
- `IN PROGRESS` — active branch/PR or reconstruction series exists
- `PREPARED` — implementation exists but is intentionally not activated
- `BLOCKED` — dependency/runtime gate required
- `DONE` — accepted into intended branch/main with applicable evidence
- `HISTORICAL` — useful provenance, superseded by newer verified state

# Priority queue

## P0 — preservation, canonical ownership, and authored-overworld truth

| ID | Status | Task | Current outcome / next requirement |
|---|---|---|---|
| BA-000 | DONE | Repair/pin Studio import preservation. | PR #228 repaired the original gap: 28/28 Studio-only sources and 1,775/1,775 Workspace identity rows preserved. |
| BA-001 | HISTORICAL | First HubTown migration manifest. | Useful provenance from the damaged first archive; current repaired/property-backed evidence outranks its missing-row conclusions. |
| BA-002 | HISTORICAL | First authored-world migration manifest. | Useful provenance only; current recovery verifies the full hierarchy and broad property evidence. |
| BA-003 | DONE | Legacy-script disposition/anti-resurrection boundary. | Legacy gameplay services remain non-authoritative. |
| BA-004 | DONE | Stable world-content IDs/contracts and canonical runtime map. | Landed through PR #229; current ownership documented in `CANONICAL-RUNTIME.md`. |
| BA-005 | IN PROGRESS — source work delivered, admission gated | Source-managed authored-overworld reconstruction behind hold. | Property recovery + WorldPath + coordinate-space decision + DungeonPortal + quest board landed across PRs #232–#238. The hub core, bounded primary route, and dedicated Main World build landed across PRs #382–#397. The resource/world-structure groups this row asks for now exist as source content: PRs #407–#438 registered 32 environment assets (18 `main_world.resources`, 14 `main_world.structures`) and 44 source models, presentation-only with no runtime owner. **Do not continue by authoring more groups.** Both target streaming groups remain `Unmapped`, and mapping them is gated behind the BA-014 hub/route evidence pass — see `EXECUTION-DASHBOARD.md`. |
| BA-006 | DONE | Refresh migration validators/docs so historical damaged-archive manifests cannot be mistaken for current reconstruction truth. | `scripts/validate_migration_current_evidence.py` pins the four required current-evidence files to the canonical RBXL identity and post-repair 28/28-source, 1,775/1,775-row baseline; the historical manifest validator now labels its frozen 122-row scope explicitly, and CI runs both boundaries. No runtime activation. |

## P1 — Main World / HubTown / environment preparation

This is now a first-class product lane under Master Roadmap Phase W.

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-010 | DONE | **Main World + environment audit and composition specification.** Audit live Forward Operations Hub plus recovered authored overworld against the `Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return` loop. | Completed in `docs/specifications/main-world-environment-audit.md`; source/evidence dispositions and Studio-only acceptance work are explicit. No runtime activation or broad geometry was added. |
| BA-011 | DONE | Main World source representation/placement strategy. | Dedicated held Main World place/project boundary, source/model/Terrain ownership, streaming groups and arrival/return anchor policy are defined in `docs/specifications/main-world-source-representation-strategy.md` and locked by `MainWorldRepresentationConfig`. No runtime activation. |
| BA-012 | DONE | Canonical Hub interaction registry. | Stable preparation/board/vendor/NPC/crafting/gathering/portal/social anchors and owner/dependency boundaries are defined in `docs/specifications/canonical-hub-interaction-registry.md`; no runtime activation. |
| BA-013 | DONE | Environment production plan. | [`docs/specifications/main-world-environment-production-plan.md`](../specifications/main-world-environment-production-plan.md) defines evidence-bounded terrain/route/structure/prop/foliage/material/lighting/VFX/audio kits, provisional asset and visible-scene ceilings, Full/Reduced/Minimum-readable behavior, Terrain manifests, semantic streaming units and measured BA-014 performance targets. E1 plan only; no geometry or runtime activation. |
| BA-014 | DONE | Main World acceptance matrix. | [`docs/specifications/main-world-acceptance-matrix.md`](../specifications/main-world-acceptance-matrix.md) plus `MainWorldAcceptanceMatrixConfig` — 31 named checks across arrival/flow, navigation, landmark readability, visual environment, audio, streaming/lifecycle and performance, each with capture modes, device profiles, evidence artifacts and either a provenance-labelled threshold or a BA-013 tier ceiling. Ships unrun: every check is `NotRun`, the table is frozen, recorded outcomes live in a separate `RunRecord` that `evaluateRun` decides against the definition, and the gate rejects until a complete run passes every blocking check. Running it is blocked on the Studio evidence transport, not on this queue. |

## P2 — quest, NPC, crafting, gathering, vendor/economy domains

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-020 | DONE | Canonical quest contracts + deterministic quest-state resolver. | Merged through PR #268 with stable IDs/prerequisites/transitions/reward refs; no bootstrap/client authority. |
| BA-021 | DONE | NPC definition/conversation/interaction contracts. | Merged through PR #269 with stable IDs/roles/dialogue refs/capabilities and pure validation. |
| BA-022 | DONE | Crafting recipe model/resolver. | Merged through PR #270 with recipe/ingredient/output refs and deterministic eligibility reasons; no inventory mutation path. |
| BA-023 | DONE | Gathering/resource-node model. | Merged through PR #271 with resource/node/tool/respawn/reward refs; no live gathering authority. |
| BA-024 | DONE | Vendor/catalog/pricing contracts. | Merged through PR #272 with vendor/catalog/currency/item refs; no purchase mutation path. |
| BA-025 | DONE | Cross-domain dependency validation. | Merged through PR #273; validates BA-020–024 references, cycles, impossible prerequisites, and orphaned reward refs without runtime activation. |
| BA-026 | BLOCKED on Master ECON gate | Economy model/audit. | BA-022–024 dependencies are prepared, but economy remains separately gated. Define currencies, sources/sinks, value bands, salvage/overflow/idempotency and telemetry only after Master ECON explicitly clears. |

## P3 — operation, dungeon, portal and pre-launch preparation

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-030 | DONE | Dungeon/expedition content contract. | [`docs/specifications/dungeon-expedition-content-contract.md`](../specifications/dungeon-expedition-content-contract.md) — adds `EncounterSlotId`/`EncounterIntensity`/`RewardSourceId` to the existing handcrafted room pool (`RoomAssemblyContracts`/`RoomAssemblyConfig`), reusing `EquipmentRewardContracts`'s Elite/Boss reward vocabulary and the existing lobby return-to-safety remote for the return path. No spawner/runtime wiring changed. |
| BA-031 | DONE | Portal destination/eligibility contract. | `src/shared/World/PortalDestinationContracts.luau` (destination ref, party/unlock constraints, denial-reason enum, pure `evaluateEligibility` resolver) plus the one authored `PortalDestinationConfig.luau` definition for `portal.expedition.primary`, tracking `ExpeditionConfig.Definitions.FirstExpedition`'s party bounds. `RuntimeEnabled = false`; no consumer calls it yet and no teleport/network authority was added. |
| BA-032 | DONE | First repeatable dungeon content data. | [`docs/specifications/first-repeatable-dungeon-content.md`](../specifications/first-repeatable-dungeon-content.md) pins canonical seed `202` and the seven-room First Descent compositions. Later MVP 0.1 integration (PRs #294 and #296) now consumes that seed, room-local placement and authored enemy composition through the existing expedition/enemy authorities; the original data contract remains the content source. |
| BA-033 | DONE | Elite/boss reward-decision data. | [`docs/specifications/first-dungeon-reward-decisions.md`](../specifications/first-dungeon-reward-decisions.md) remains the authored Run Relic decision source. Boss Run Relic consumption is now live through the existing run-build authority (PR #295). Persistent equipment was subsequently retained under its existing inventory owner and integrated into MVP replay through PRs #315/#317/#318; this row does not authorize Patch 0.3 affix breadth. |
| BA-034 | DONE | Held pre-launch operation-selection contract. | PR #239 merged the held operation-selection contracts/config with runtime/network/launch handoff disabled; no party-leader policy was invented. |
| BA-035 | BLOCKED on social/session ownership decision | Party/session ownership policy for operation selection. | Dedicated contract; do not invent a leader/host implicitly. |

## P4 — combat/RPG depth audits without authority duplication

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-040 | DONE | Enemy-archetype coverage audit. | [`docs/specifications/enemy-archetype-coverage-audit.md`](../specifications/enemy-archetype-coverage-audit.md) — direct config/runtime verification finds Runner speed, Screamer reinforcement, Bloater death burst, and Brute second phase mechanically coherent with their presentation; Crawler alone remains thin because its faster low posture promises stalking/ambush behavior the shared owner does not implement. Covers the walker, six horde roles, Spitter, Progenitor, and five elite affixes. No runtime activation. |
| BA-041 | BLOCKED on scoped Crawler identity decision | Missing enemy configs/pure behavior primitives. | BA-040 found no broad missing-role implementation: Runner and Brute already have source-proven mechanics. Decide whether Crawler's faster low-profile identity is sufficient or whether one bounded canonical behavior is wanted before changing `HordeExperienceService` or enemy config. |
| BA-042 | DONE | Loot/build-decision coverage audit. | [`docs/specifications/loot-build-decision-coverage-audit.md`](../specifications/loot-build-decision-coverage-audit.md) recorded the then-existing split between run-build choices and persistent equipment. That client equip/application gap is now closed by MVP 0.1: live inventory lease lifecycle (#315), server-owned durable equip/start-loadout handoff (#317), and sanitized existing-menu equip flow (#318). The audit remains useful provenance; player-item affixes/sets remain later Patch 0.3 breadth. |
| BA-043 | BLOCKED until Patch 0.3 becomes current | Deterministic item/affix generation rules. | The authority decision is resolved: persistent equipment is retained under the existing `EquipmentReward*` / inventory owners and now has a real equip/application loop. Do **not** add affix/set breadth during MVP 0.1/Patch 0.2; when Patch 0.3 becomes current, extend the retained owner rather than creating a parallel loot/inventory/persistence path. |
| BA-044 | DONE | Progression/skill mapping audit. | [`docs/specifications/progression-skill-mapping-audit.md`](../specifications/progression-skill-mapping-audit.md) — maps historical P11 into current Phase D/M authority, distinguishes run-only Field XP/upgrades from missing career XP/rank/unlock ownership, records the existing terminal-result and partial class-availability seams plus inventory-specific persistence infrastructure, and proposes one duplicate-safe match award → configured XP/rank → approved non-power unlock as the smallest useful future slice. E1 audit only; no Phase D/M activation. |

## P5 — authored route, exploration and discovery preparation

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-050 | DONE | First authored outdoor route as data. | [`docs/specifications/first-authored-outdoor-route.md`](../specifications/first-authored-outdoor-route.md) remains the authored route/slot source. Recovered 189-Part WorldPath geometry is still held, but later MVP 0.1 work consumes the related BA-051 Approach combat beats and BA-052 Lookout Cache without inventing unverified route geometry or reusing the launch terminal as dungeon-transition authority. |
| BA-051 | DONE | Encounter-beat definitions. | [`docs/specifications/first-outdoor-encounter-beats.md`](../specifications/first-outdoor-encounter-beats.md) remains the authored Approach sequence source. PR #299 now consumes its logging-road, campground and two-stage roadblock combat through the existing expedition encounter/enemy authorities with authored recovery pacing; BA-050 imported route geometry remains held. |
| BA-052 | DONE | Landmark/discovery definitions. | [`docs/specifications/first-outdoor-discovery.md`](../specifications/first-outdoor-discovery.md) remains the stable Lookout Cache definition. PR #300 activates the bounded Approach Lookout Cache claim through server-owned distance/run/phase/one-time validation and the existing RunBuild authored-container reward path; no client reward authority or account-persistence path was added. |

## P6 — onboarding, input and UI preparation

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-060 | DONE | First-session onboarding sequence. | [`docs/specifications/first-session-onboarding-sequence.md`](../specifications/first-session-onboarding-sequence.md) remains the 12-step first-session journey. The old auto-replay blocker is closed by PR #293: terminal result returns to safe preparation and a fresh run begins only after a new lobby-ready launch. PR #312 resets temporary run power, and PRs #315/#317/#318 make bank → equip → deliberate replay meaningful while preserving durable state. |
| BA-061 | DONE | PC/mobile/controller action-map audit. | [`docs/specifications/input-action-map-audit.md`](../specifications/input-action-map-audit.md) remains the source audit; BA-062 has remediated its M1-M5 and C1-C4 source findings. Device verification remains outstanding. |
| BA-062 | PREPARED | Input abstraction improvements. | Source remediation is complete at E1: fire/reload/sprint/revive gamepad/touch coverage, prompt-key separation, shared action map, device-family/binding-hint foundations, device-neutral hub close, adaptive launcher/ping copy, single Escape owner, fail-closed numbered-choice coordination, zero canonical direct key collisions, and class-action ButtonB presentation alignment. Consolidated Studio/device acceptance remains open before runtime evidence promotion. |
| BA-063 | DONE | UI information architecture. | PR #267 merged `UIInformationArchitectureConfig` plus its source/static specification and tests. Runtime behavior remains unchanged; the matrix is preparation for later UI work. |

## P7 — integration planning and anti-regression

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-070 | DONE | Combined-game integration dependency graph. | Existing graph/validation remains useful; refresh when dependencies materially change. |
| BA-071 | DONE | Legacy-service resurrection audits. | Keep current and extend when new adapters appear. |
| BA-072 | DONE | Content-ID/migration reference validator tooling. | Extend toward live Luau/content contracts as BA-025 lands. |
| BA-073 | HISTORICAL | Vertical-slice integration plan. | Superseded for practical sequencing by `PLAYABLE-MVP-PATCH-EXECUTION.md` and the merged MVP 0.1 integration series. Remaining evidence promotion is governed by the playable roadmap, build-through policy and Blueprint v2.7 evidence authority rather than a new speculative integration plan. |
| BA-074 | DONE | v2.8 roadmap/authority source audit. | `scripts/validate_roadmap_authority.py` checks the authority-stack documents for broken relative links, direct links to historical checkpoints (which must be reached only through `docs/roadmap/README.md`), and dangling commit-hash references; run it alongside the other repository validators. This audit pass also repaired stale checkpoint pins in `MASTER-ROADMAP.md` and this queue and added the explicit W1/BA-011 cross-reference. |

# Tasks agents must NOT perform yet

Do not:

- activate merged R2 preparation before its controlled stage and required runtime evidence;
- activate ClientReady/R3/R4 cutovers early;
- remove compatibility State paths without accepted replacement evidence;
- claim the queue/Highlight incident fixed from source shape or an informational local run;
- boot imported HubTown/Dungeon/Quest/Gathering/monetization/gameplay services beside canonical owners;
- collapse authored overworld into operation-forest coordinate space;
- wire quests/crafting/vendors/gathering/dungeons/economy into production merely because contracts are green;
- build matchmaking/party-leader authority as a side effect of another task;
- implement broad monetization before the outside-player fun gate;
- begin broad continents/PvP/raids/housing/trading/vehicles/seasons because they appear in future brainstorming;
- claim E2–E7 from repository tests.

# Recommended next work

Before starting, always re-fetch `main` and inspect any open overlapping PRs.

### Highest-ROI work after current-patch refresh

Playable MVP + Patch Execution v2.10 controls global implementation order. MVP 0.1's planned source loop is now **BUILT — VERIFICATION PENDING** through PR #318. The consolidated exact-build Studio/device pass remains the milestone acceptance task, but its being unrun does not freeze dependency-safe source work.

While consolidated verification is pending and no known runtime failure invalidates the baseline, the highest-ROI repository lane is:

**Patch 0.2 — Combat Feel + Readability.**

Before starting overlapping combat-presentation work, inspect open PR #316 (`[MVP 0.2] Show server-confirmed teammate melee swings`), refresh it against current `main`, remove any temporary branch scaffolding, and require normal CI before merge. Do not duplicate that slice in a new branch.

If the user explicitly asks for non-runtime build-ahead preparation instead of current-patch work, BA-005 remains allowed behind hold as a lower-priority lane. Keep reconstructed authored-overworld content dormant, evidence-bounded and separate from the operation forest. Main World Track 1 remains complete as preparation (BA-010 → BA-014); its next meaningful step is Studio measurement, not speculative composition.

### Assignment policy — no reserved agent tasks (2026-08-09)

Coding-agent quotas are currently constrained. **No READY ticket is assigned or reserved to Codex, Claude, or any other named agent.** The earlier parallel Track 1/Track 2 reservation scheme is retired; completed work remains recorded in the priority tables above.

Execution policy while this mode is active:

1. re-fetch `main` and inspect open PRs;
2. choose the highest-ROI allowed task under the active playable-patch authority;
3. finish that task on an isolated branch/PR;
4. run applicable CI/static validation;
5. merge the completed task before starting another;
6. repeat only after `main` is refreshed again.

### Current build-ahead backlog

```text
Patch 0.2 Combat Feel + Readability — CURRENT SOURCE-SAFE LANE; inspect open PR #316 before overlapping work
BA-005 authored-overworld reconstruction continuation — IN PROGRESS / allowed behind hold when build-ahead is explicitly desired
BA-026 economy model/audit — BLOCKED on Master ECON gate
BA-035 party/session ownership policy — BLOCKED on social/session ownership decision
BA-041 Crawler behavior primitive — BLOCKED on scoped identity decision
BA-043 item/affix generation — BLOCKED until Patch 0.3 becomes current
BA-073 vertical-slice integration plan — HISTORICAL / superseded by playable-patch sequencing
```

Do not resurrect completed BA-020–025, BA-062, or BA-063 work merely because an older queue snapshot listed it as READY.

### Human/Studio lane

The highest-value playable human/runtime task is now the **consolidated exact-build MVP 0.1 Studio/device pass**: complete the representative first run, return/bank/equip/replay loop, keyboard/controller/touch checks, and representative performance on one pinned build. Any failure becomes an immediate MVP 0.1 FIX.

Blueprint v2.7 R1/runtime-matrix evidence remains a separate controlling evidence obligation where that authority still requires refresh; do not treat Patch 0.2 source progress as evidence promotion. BA-062 likewise remains **BUILT/PREPARED — DEVICE VERIFICATION PENDING** until the consolidated pass records real device behavior.

> Build ahead without building around the gate: reduce future uncertainty, but never convert preparation into an unearned runtime claim.
