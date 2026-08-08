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
- PR #221 is no longer blocked by R1, but must be rebased/revalidated and satisfy its own evidence gate before merge.
- PR #222 remains stacked/blocked pending #221 and its required evidence.
- PR #239 is an open held pre-launch operation-selection contract; do not duplicate or activate it blindly.

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
3. Do not merge #221/#222 early.
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
| BA-006 | READY | Refresh migration validators/docs so historical damaged-archive manifests cannot be mistaken for current reconstruction truth. | Keep current evidence and historical provenance clearly separated. |

## P1 — Main World / HubTown / environment preparation

This is now a first-class product lane under Master Roadmap Phase W.

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-010 | DONE | **Main World + environment audit and composition specification.** Audit live Forward Operations Hub plus recovered authored overworld against the `Arrival → Orientation → Exploration → Interaction → Preparation → Adventure → Return` loop. | Completed in `docs/specifications/main-world-environment-audit.md`; source/evidence dispositions and Studio-only acceptance work are explicit. No runtime activation or broad geometry was added. |
| BA-011 | DONE | Main World source representation/placement strategy. | Dedicated held Main World place/project boundary, source/model/Terrain ownership, streaming groups and arrival/return anchor policy are defined in `docs/specifications/main-world-source-representation-strategy.md` and locked by `MainWorldRepresentationConfig`. No runtime activation. |
| BA-012 | DONE | Canonical Hub interaction registry. | Stable preparation/board/vendor/NPC/crafting/gathering/portal/social anchors and owner/dependency boundaries are defined in `docs/specifications/canonical-hub-interaction-registry.md`; no runtime activation. |
| BA-013 | READY | Environment production plan. | Terrain/biome/prop/material/lighting/VFX/audio kits, repetition budgets, LOD/streaming/performance targets. No speculative geometry pass. |
| BA-014 | READY | Main World acceptance matrix. | Studio checklist for orientation, navigation, landmark recognition, service finding, return flow, visual quality and measured performance. |

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
| BA-030 | READY | Dungeon/expedition content contract. | Dungeon IDs, room/encounter sequence, elite/boss slots, reward refs, return path, difficulty metadata. |
| BA-031 | READY | Portal destination/eligibility contract. | Destination, party/unlock constraints, denial reasons; no teleport authority invented. |
| BA-032 | BLOCKED on BA-030 | First repeatable dungeon content data. | One short authored dungeon sequence using canonical combat/enemy systems. |
| BA-033 | BLOCKED on BA-032 | Elite/boss reward-decision data. | References canonical loot/item/run-build owners. |
| BA-034 | IN PROGRESS via PR #239 | Held pre-launch operation-selection contract. | Inspect PR #239 before any work. Do not duplicate it; no runtime activation until accepted. |
| BA-035 | BLOCKED on BA-034 + social/session design | Party/session ownership policy for operation selection. | Dedicated contract; do not invent a leader/host implicitly. |

## P4 — combat/RPG depth audits without authority duplication

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-040 | READY | Enemy-archetype coverage audit. | Gap matrix for pressure/counter/readability, not a new EnemyService. |
| BA-041 | BLOCKED on BA-040 | Missing enemy configs/pure behavior primitives. | Use canonical enemy authority. |
| BA-042 | READY | Loot/build-decision coverage audit. | Affix/stat/set/rarity decision gaps tied to player choices. |
| BA-043 | BLOCKED on BA-042 | Deterministic item/affix generation rules. | Seedable bounded resolver using canonical loot/inventory owners. |
| BA-044 | READY | Progression/skill mapping audit. | Current-vs-historical mapping + smallest useful vertical-slice progression. |

## P5 — authored route, exploration and discovery preparation

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-050 | READY | First authored outdoor route as data. | Route/landmark/encounter/discovery/entrance/exit sequence. |
| BA-051 | BLOCKED on BA-050 | Encounter-beat definitions. | Mixed groups, pacing, elite placement, recovery assumptions. |
| BA-052 | READY | Landmark/discovery definitions. | Stable discovery IDs, gameplay meaning, presentation intent, reward refs, streaming-safe identity. |

## P6 — onboarding, input and UI preparation

| ID | Status | Task | Deliverable / boundary |
|---|---|---|---|
| BA-060 | READY | First-session onboarding sequence. | Main World spawn → preparation → expedition → reward → return. |
| BA-061 | READY | PC/mobile/controller action-map audit. | Existing/missing/conflicting semantic actions + accessibility considerations. |
| BA-062 | BLOCKED on BA-061 | Input abstraction improvements. | Client-only semantic mapping; no gameplay authority change. |
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

- merge PR #221 before its R1 gate;
- merge/activate PR #222 before its dependencies;
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

Before starting, always re-fetch `main` and inspect PR #239 plus any newer PRs.

### Highest-ROI agent task

**BA-013 — Environment production plan.**

Why now:

- BA-010 classified the live bridge and recovered authored content;
- BA-011 fixed the dedicated place/project, source/model/Terrain ownership, streaming-group and arrival/return boundaries;
- BA-012 now assigns stable interaction anchors, existing owners and explicit blocked ownership seams;
- BA-013 can define terrain/structure/prop/foliage/material/lighting/VFX/audio kits, quality tiers and measured budgets without activating held content.

### Parallel assignment — concurrent agents (2026-08-08)

More than one agent is working this queue at the same time. BA-010 → BA-011 → BA-012 landed back to back through PRs #241/#242/#243, so anyone continuing that thread should keep going rather than collide with a second agent starting the same ticket. Two file-disjoint tracks are named here so both can run simultaneously without inspecting each other's branch first:

**Track 1 — Main World / Hub lane (continue in sequence).** `BA-013 → BA-014`. Touches `docs/specifications/`, `src/shared/Config/`, `src/shared/World/`, and matching `tests/` for environment/acceptance content only. Whichever agent already holds this thread (most recently the agent that landed BA-012 via PR #243) should continue it rather than switch lanes.

**Track 2 — combat/RPG depth audits (P4).** `BA-040 → BA-042 → BA-044`. Pure gap-matrix audits read existing enemy/loot/progression source and write new `docs/specifications/*-audit.md` files; they add no code and touch no file Track 1 depends on. This is the recommended track for whichever agent is not already mid-thread on Track 1.

Both tracks still obey every build-ahead law below, in particular: fetch current `main` and check open PRs before starting, do not duplicate work already in flight, and keep new content unbooted/dormant until its runtime gate opens.

### Other safe parallel candidates

Once Track 1 and Track 2 are both claimed, or if either track turns out to already be in progress on `main`, these remain safe (after checking for overlap with open PRs):

```text
BA-020 quest contracts
BA-021 NPC contracts
BA-022 crafting contracts
BA-023 gathering/resource-node model
BA-024 vendor/catalog contracts
BA-030 dungeon/expedition contract
BA-031 portal eligibility contract
BA-050 authored route data
BA-052 landmark/discovery definitions
BA-060 onboarding sequence
BA-061 action-map audit
BA-063 UI information architecture
```

### Human/Studio lane

The highest-value human/runtime task remains:

**produce a recorded CI artifact containing the client-bootstrap fix, re-pin a fresh v2.7 R1 evidence packet to that exact build/place identity, and rerun R1.**

> Build ahead without building around the gate: reduce future uncertainty, but never convert preparation into an unearned runtime claim.
