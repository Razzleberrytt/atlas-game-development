# Atlas — Agent Build-Ahead Queue v2.8

**Status:** ACTIVE PARALLEL PREPARATION LANE  
**Refreshed:** 2026-08-08  
**Primary use:** Codex/Claude/other coding agents working while Blueprint v2.7 runtime evidence remains gated by Studio evidence

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
- Checkpoint used for this refresh: `60229a32ec1f7db3b87a68e5f81ddf8115e665f1`
- Refreshed in place at `944c684520c2ebaf6cf821a8a94a21a33588dc4f` (2026-08-08): BA-010, BA-011 and BA-012 closed via PR #241/#242/#243, `CLAUDE.md` added, BA-074 closed with `scripts/validate_roadmap_authority.py`. The task table below reflects current status; re-fetch `main` before starting any task regardless — this queue is being actively worked by more than one agent in parallel (see "Parallel assignment" below).
- Evidence: **E2** (pinned-artifact Studio initialization/R1; later integrated matrices remain open)
- Studio import preservation is **repaired**: 28/28 Studio-only sources and 1,775/1,775 Workspace identity/hierarchy rows are preserved.
- Property-backed authored-world recovery is now available; older documents that cite only 122 recoverable Workspace rows are historical damage-state evidence, not current truth.
- The recovered authored overworld is a separate future coordinate/lifecycle space from the modern operation forest.
- The live Ranger Station Forward Operations Hub is a temporary preparation bridge, not the final Main World.
- R1 is accepted on recorded artifact 9028866465; the older pre-bootstrap-fix artifact remains invalid historical evidence.
- PR #221 is merged with its exact-build single-listener evidence accepted at E2; later runtime matrices remain open.
- PR #222 is merged as dormant R2 preparation only; `ClientReady` activation and R2 runtime evidence remain separate controlled work.
- PR #239 is merged as the held pre-launch operation-selection contract; its runtime/network/launch handoff remains disabled.

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
10. Every source change needs focused tests and full applicable validation.
11. Future phases in Master Roadmap v2.8 remain locked unless this queue explicitly marks a task READY.

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
| BA-005 | IN PROGRESS | Source-managed authored-overworld reconstruction behind hold. | Property recovery + WorldPath + coordinate-space decision + DungeonPortal + quest board landed across PRs #232–#238. Continue coherent HubTown/resource/world-structure groups without booting them. |
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
| BA-020 | READY | Canonical quest contracts + deterministic quest-state resolver. | Stable IDs/prerequisites/transitions/reward refs; no bootstrap/client authority. |
| BA-021 | READY | NPC definition/conversation/interaction contracts. | Stable IDs/roles/dialogue refs/capabilities; pure validation. |
| BA-022 | READY | Crafting recipe model/resolver. | Recipe/ingredient/output refs and eligibility reasons; no inventory mutation path. |
| BA-023 | READY | Gathering/resource-node model. | Resource/node/tool/respawn/reward refs; no live gathering authority. |
| BA-024 | READY | Vendor/catalog/pricing contracts. | Vendor/catalog/currency/item refs; no purchase mutation path. |
| BA-025 | BLOCKED on BA-020–024 | Cross-domain dependency validation. | Catch unknown IDs, cycles, impossible prerequisites and orphaned rewards. |
| BA-026 | BLOCKED on BA-022–024 + Master ECON gate | Economy model/audit. | Define currencies, sources/sinks, value bands, salvage/overflow/idempotency and telemetry before broad activation. |

## P3 — operation, dungeon, portal and pre-launch preparation

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-030 | DONE | Dungeon/expedition content contract. | [`docs/specifications/dungeon-expedition-content-contract.md`](../specifications/dungeon-expedition-content-contract.md) — adds `EncounterSlotId`/`EncounterIntensity`/`RewardSourceId` to the existing handcrafted room pool (`RoomAssemblyContracts`/`RoomAssemblyConfig`), reusing `EquipmentRewardContracts`'s Elite/Boss reward vocabulary and the existing lobby return-to-safety remote for the return path. No spawner/runtime wiring changed. |
| BA-031 | DONE | Portal destination/eligibility contract. | `src/shared/World/PortalDestinationContracts.luau` (destination ref, party/unlock constraints, denial-reason enum, pure `evaluateEligibility` resolver) plus the one authored `PortalDestinationConfig.luau` definition for `portal.expedition.primary`, tracking `ExpeditionConfig.Definitions.FirstExpedition`'s party bounds. `RuntimeEnabled = false`; no consumer calls it yet and no teleport/network authority was added. |
| BA-032 | DONE | First repeatable dungeon content data. | [`docs/specifications/first-repeatable-dungeon-content.md`](../specifications/first-repeatable-dungeon-content.md) — pins canonical seed `202` for a seven-room First Descent and authors concrete basic/Runner/Crawler/Spitter/Brute/Screamer/Progenitor compositions against the existing room/enemy/horde contracts. Data-only; no runtime spawner wiring. |
| BA-033 | DONE | Elite/boss reward-decision data. | [`docs/specifications/first-dungeon-reward-decisions.md`](../specifications/first-dungeon-reward-decisions.md) — maps the authored elite/boss room reward refs to canonical two-choice Run Relic decisions (`reward-source.elite-kill` / `reward-source.boss-milestone`) while keeping runtime consumption disabled and persistent equipment excluded pending BA-043. |
| BA-034 | DONE | Held pre-launch operation-selection contract. | PR #239 merged the held operation-selection contracts/config with runtime/network/launch handoff disabled; no party-leader policy was invented. |
| BA-035 | BLOCKED on social/session ownership decision | Party/session ownership policy for operation selection. | Dedicated contract; do not invent a leader/host implicitly. |

## P4 — combat/RPG depth audits without authority duplication

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-040 | DONE | Enemy-archetype coverage audit. | [`docs/specifications/enemy-archetype-coverage-audit.md`](../specifications/enemy-archetype-coverage-audit.md) — direct config/runtime verification finds Runner speed, Screamer reinforcement, Bloater death burst, and Brute second phase mechanically coherent with their presentation; Crawler alone remains thin because its faster low posture promises stalking/ambush behavior the shared owner does not implement. Covers the walker, six horde roles, Spitter, Progenitor, and five elite affixes. No runtime activation. |
| BA-041 | BLOCKED on scoped Crawler identity decision | Missing enemy configs/pure behavior primitives. | BA-040 found no broad missing-role implementation: Runner and Brute already have source-proven mechanics. Decide whether Crawler's faster low-profile identity is sufficient or whether one bounded canonical behavior is wanted before changing `HordeExperienceService` or enemy config. |
| BA-042 | DONE | Loot/build-decision coverage audit. | [`docs/specifications/loot-build-decision-coverage-audit.md`](../specifications/loot-build-decision-coverage-audit.md) — finds a complete operation-bound run-build choice path beside an older mapped persistent equipment grant/persistence path whose rarity/Power model lacks a client equip/application loop and conflicts with the first RPG integration's exclusions. Records 12/17 Field Upgrades, 12/12 Run Relics, three configured relic sources, no independent temporary-resource choice layer, no player-item affixes/sets, and outstanding Studio evidence. No runtime activation. |
| BA-043 | BLOCKED on explicit equipment/run-build authority decision | Deterministic item/affix generation rules. | Existing `EquipmentReward*` and inventory owners already define persistent rarity/Power rewards, while the first run-RPG integration excludes that shape and no player item-affix/set contract exists. Decide whether persistent equipment is retained, held, or migrated before adding a seedable affix resolver; never create a parallel loot/inventory/persistence owner. |
| BA-044 | DONE | Progression/skill mapping audit. | [`docs/specifications/progression-skill-mapping-audit.md`](../specifications/progression-skill-mapping-audit.md) — maps historical P11 into current Phase D/M authority, distinguishes run-only Field XP/upgrades from missing career XP/rank/unlock ownership, records the existing terminal-result and partial class-availability seams plus inventory-specific persistence infrastructure, and proposes one duplicate-safe match award → configured XP/rank → approved non-power unlock as the smallest useful future slice. E1 audit only; no Phase D/M activation. |

## P5 — authored route, exploration and discovery preparation

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-050 | DONE | First authored outdoor route as data. | [`docs/specifications/first-authored-outdoor-route.md`](../specifications/first-authored-outdoor-route.md) — orders the eight active Ranger Station → Extraction Clearing landmarks, exposes three route-local BA-051 encounter slots plus one optional BA-052 discovery slot, and hands off to First Descent at `descent-entry`. `RuntimeConsumptionActive = false`; recovered 189-Part WorldPath geometry remains held and the expedition launch terminal is not reused as dungeon-transition authority. |
| BA-051 | DONE | Encounter-beat definitions. | [`docs/specifications/first-outdoor-encounter-beats.md`](../specifications/first-outdoor-encounter-beats.md) — binds the three BA-050 slots to a Basic orientation contact, a Basic/Runner/Crawler mixed group, and a two-wave Basic/Runner → Basic/Blight-Spitter roadblock. Duration/recovery values remain authoring targets, only the final roadblock carries late-route elite-resolver-candidate intent, and runtime consumption stays disabled. |
| BA-052 | DONE | Landmark/discovery definitions. | [`docs/specifications/first-outdoor-discovery.md`](../specifications/first-outdoor-discovery.md) — defines the optional Lookout Cache with stable discovery/slot/landmark/streaming IDs, `OptionalVantageCache` gameplay meaning, `ReadableOptionalDetour` presentation intent, and canonical planned `reward-source.authored-container` reward reference. Data-only; no streaming, persistence, networking, presentation, or reward runtime ownership. |

## P6 — onboarding, input and UI preparation

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-060 | DONE | First-session onboarding sequence. | [`docs/specifications/first-session-onboarding-sequence.md`](../specifications/first-session-onboarding-sequence.md) — pins the 12-step safe arrival → preparation → deliberate launch → route/discovery → First Descent → Run Relic decision → result → safe return → build understanding → deliberate replay journey. Runtime-existing, prepared-data, prepared-integration, and blocked-lifecycle states remain explicit; final replay is blocked on the current `OperationLifecycleService` auto-replay behavior rather than being changed sideways. |
| BA-061 | DONE | PC/mobile/controller action-map audit. | [`docs/specifications/input-action-map-audit.md`](../specifications/input-action-map-audit.md) — inventories 17 semantic actions across 10 controllers and finds the action surface is not device-neutral. **Firing is `MouseButton1`-only, so gamepad and touch players cannot attack**; reload, sprint and revive lack gamepad bindings; `E` (revive) and `ButtonX` (class action) both collide with the engine's `ProximityPrompt` defaults; two `Escape` listeners and two number-key claims are uncoordinated. Records accessibility considerations and the structural absence of any shared action map. Locked by `tests/InputActionMapSourceAudit.test.luau`. E1 source audit only — no device was tested and no binding changed. |
| BA-062 | READY | Input abstraction improvements. | Unblocked by BA-061, which records a recommended remediation order: device-neutral fire binding first, then the `E`/`ButtonX` collisions, then missing gamepad bindings, then a shared action map. Client-only semantic mapping; no gameplay authority change, and the server keeps sole ownership of shots, cadence, ammunition, targeting and damage. |
| BA-063 | READY | UI information architecture. | Main World/expedition/loot/progression screen-state matrix and ownership boundaries. |

## P7 — integration planning and anti-regression

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-070 | DONE | Combined-game integration dependency graph. | Existing graph/validation remains useful; refresh when dependencies materially change. |
| BA-071 | DONE | Legacy-service resurrection audits. | Keep current and extend when new adapters appear. |
| BA-072 | DONE | Content-ID/migration reference validator tooling. | Extend toward live Luau/content contracts as BA-025 lands. |
| BA-073 | BLOCKED on relevant prepared domains + v2.7 gate | Vertical-slice integration plan. | Exact promotion order and Studio evidence requirements after runtime gates open. |
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

### Highest-ROI build-ahead task after current-patch work

Playable MVP + Patch Execution v2.9 now controls global implementation order.
Gate 0 runtime stabilization and the smallest MVP 0.1 enablers outrank this
queue. Use the task below only when the runtime/evidence lane cannot proceed or
build-ahead work is explicitly requested.

**BA-062 — device-neutral fire binding (first item only).**

BA-061 found that firing is bound to `MouseButton1` alone, so gamepad and touch
players can move, reload, sprint, ping and loot but cannot attack. That is an
MVP 0.1 device-parity defect, not future breadth, and it outranks the rest of
this queue.

Why now:

- MVP 0.1's acceptance questions explicitly ask whether keyboard, controller and touch players can play the loop; today two of the three cannot fight;
- the fix is client-only intent origin — move fire to `ContextActionService` with a gamepad trigger and a touch button while keeping `MouseButton1` — and the server keeps sole ownership of shots, cadence, ammunition, targeting and damage;
- it is small, testable and directly reduces what the pending Studio pass has to re-diagnose.

Take only the first remediation item under BA-062, then re-evaluate. The `E`
and `ButtonX` prompt collisions and the shared action map are separate
increments; do not fold them into the same change, and do not solve the
collisions by sinking input, which would break world interaction.

Main World Track 1 is complete as a preparation sequence (BA-010 → BA-014) and
its next step is measurement in the human/Studio lane, not this queue.

### Parallel assignment — concurrent agents (2026-08-08)

More than one agent is working this queue at the same time. BA-010 → BA-011 → BA-012 landed back to back through PRs #241/#242/#243, so anyone continuing that thread should keep going rather than collide with a second agent starting the same ticket. Two file-disjoint tracks are named here so both can run simultaneously without inspecting each other's branch first:

**Track 1 — Main World / Hub lane (complete).** `BA-010 → BA-011 → BA-012 → BA-013 → BA-014` all landed. The lane's next step is executing the BA-014 matrix, which requires a working Studio evidence transport and belongs to the human/Studio lane below. Do not re-open Track 1 as build-ahead work; take a P2/P6 candidate instead.

**Track 2 — combat/RPG depth audits (P4; complete).** `BA-040 → BA-042 → BA-044`. The three E1 gap-matrix audits are merged; BA-041 and BA-043 remain blocked on their recorded product decisions.

Both tracks still obey every build-ahead law below, in particular: fetch current `main` and check open PRs before starting, do not duplicate work already in flight, and keep new content unbooted/dormant until its runtime gate opens.

### Other safe parallel candidates

Both named tracks are now complete, so these are the remaining safe candidates (after checking for overlap with open PRs). `BA-020 → BA-024` form one dependency chain that ends in BA-025's cross-domain validation, and are the natural second lane beside the BA-062 input work:

```text
BA-020 quest contracts
BA-021 NPC contracts
BA-022 crafting contracts
BA-023 gathering/resource-node model
BA-024 vendor/catalog contracts
BA-063 UI information architecture
```

BA-063's screen-state matrix should consume BA-061's action inventory rather than re-deriving it.

### Human/Studio lane

The highest-value human/runtime task remains:

**produce a recorded CI artifact containing the client-bootstrap fix, re-pin a fresh v2.7 R1 evidence packet to that exact build/place identity, and rerun R1.**

> Build ahead without building around the gate: reduce future uncertainty, but never convert preparation into an unearned runtime claim.