# Living Kingdoms — Agent Build-Ahead Queue

**Status:** ACTIVE PARALLEL PREPARATION LANE  
**Date:** 2026-08-07  
**Primary use:** Claude/Codex/other coding agents working while Blueprint v2.7 runtime evidence remains blocked on a Roblox Studio run

This queue exists so useful development can continue without pretending the active v2.7 runtime gate has passed.

It does **not** replace Blueprint v2.7. It defines work that may be prepared in isolation while R1/R2/R3/R4 runtime promotion remains controlled.

## Current gate snapshot

- Canonical repository: `Razzleberrytt/atlas-game-development`
- Canonical game path: `games/living-kingdoms`
- Current `main` at creation of this queue: `fda4e823bf662abbbbac2aa61e297ac7a51ed1f0`
- Evidence level: **E1**
- Required manual gate: canonical R1 Studio evidence packet
- Canonical R1 test artifact remains:
  - commit `2c870d270b96064c9a06343cc088b251299373f4`
  - artifact ID `9009926429`
  - SHA-256 `587ccc2974f8188bde34a0a757213efb4b9f72e68e940db4615232cace28bf89`
- PR #221: single-listener consolidation prepared, draft/blocked
- PR #222: ready-gated publisher primitive prepared, stacked/draft/blocked
- R3 semantic suppression is **not authorized for activation** before R2 evidence.

## Two-lane rule

### Lane A — Active runtime rollout

Controlled by Blueprint v2.7 Tickets 331–360.

Do not bypass:

- R1 Studio evidence;
- single-listener runtime validation;
- R2 delayed-ready/late-join evidence;
- R3 semantic/change-token evidence;
- R4 presentation ownership evidence;
- R5 soak/closure evidence.

### Lane B — Build-ahead preparation

Authorized by this document.

Agents may prepare future gameplay/content architecture in isolated branches and draft PRs **without activating it in the canonical runtime**.

Build-ahead work must satisfy all of these:

1. Do not alter or invalidate the pinned R1 artifact.
2. Do not merge #221 or #222 early.
3. Do not activate R2/R3/R4 runtime cutovers early.
4. Do not introduce a second authority path for combat, enemies, inventory, loot, persistence, networking, or presentation.
5. Prefer pure modules, contracts, configuration, data manifests, migration inventories, source audits, tests, tooling, and dormant integration boundaries.
6. Any future runtime wiring must be clearly separated from preparatory code.
7. Every source change gets focused tests and full repository validation.
8. Any gameplay-prep PR that would alter the active place runtime stays draft/blocked until the appropriate runtime gate opens.
9. Do not claim Studio behavior from source tests.
10. Fetch current `main` before starting a task because concurrent agents may advance the repository.

## Agent workflow

For each task:

1. Read `games/living-kingdoms/AGENTS.md`.
2. Read `MASTER-ROADMAP.md`, `BLUEPRINT-V2.7-EXECUTION.md`, `PRODUCTION-CORE-V2.7.md`, and this queue.
3. Re-fetch `main` and inspect open related PRs before editing.
4. Select the first `READY` task whose dependencies are satisfied.
5. Create one focused branch per task or tightly coupled task group.
6. Preserve the newer canonical architecture; treat preserved RBXL content as migration input.
7. Add/update tests.
8. Run layout validation, StyLua, Selene, all Lune fixtures, and Rojo build.
9. Open a PR with an explicit label in the title:
   - `[BUILD-AHEAD]` when it is preparatory and independently reviewable;
   - `[BUILD-AHEAD/BLOCKED]` when it must not merge before a runtime gate.
10. Record what is source-proven versus Studio-only.
11. Update this queue when a task is completed, split, superseded, or blocked.

## Priority queue

Status values:

- `READY` — agent may begin now.
- `IN PROGRESS` — branch/PR exists.
- `PREPARED` — implementation is ready but intentionally not activated/merged.
- `BLOCKED` — dependency or runtime gate required.
- `DONE` — accepted into the intended branch/main with applicable evidence.

### P0 — Combined-game migration truth

These tasks make the old Studio world/content usable without rebooting stale systems.

| ID | Status | Task | Deliverable | Merge posture |
|---|---|---|---|---|
| BA-001 | READY | Build a canonical HubTown migration manifest from preserved RBXL import material. | Machine-readable inventory mapping HubTown instances/assets/scripts to `KEEP`, `MIGRATE`, `REPLACE`, `ARCHIVE`, with canonical owner and dependencies. | Docs/data/tooling may merge if runtime-neutral. |
| BA-002 | READY | Build the authored-world migration manifest for structures, ruins, landmarks, resources, portals, NPC structures, lighting and VFX. | Stable IDs, source paths, asset refs, intended canonical representation, Studio-only notes, dependency matrix. | Docs/data/tooling may merge if runtime-neutral. |
| BA-003 | READY | Produce a legacy-script disposition matrix for all preserved Studio-only scripts. | Every preserved script classified: canonical replacement, reusable logic candidate, content-only reference, dead/stale, or requires manual Studio inspection. | Docs/tooling only. |
| BA-004 | READY | Define stable world-content IDs/contracts shared by HubTown, portals, NPCs, landmarks, resources and authored encounters. | Strict Luau types + validation fixtures; no active runtime wiring. | Draft if added under runtime source; safe to merge only if truly dormant. |

### P1 — HubTown and social-space preparation

| ID | Status | Task | Deliverable | Merge posture |
|---|---|---|---|---|
| BA-010 | BLOCKED on BA-001/004 | Prepare canonical HubTown composition specification. | Spawn points, vendor/NPC anchors, dungeon portal anchors, navigation landmarks, safe-zone boundaries, interaction IDs, environmental ownership. | Branch/draft. |
| BA-011 | BLOCKED on BA-010 | Prepare HubTown model/source representation strategy. | Reviewable `.rbxmx`/Rojo mapping plan or generated placement-data strategy with migration tooling. | Draft; no live activation. |
| BA-012 | BLOCKED on BA-010 | Prepare HubTown interaction registry. | Data-driven NPC/vendor/portal interaction definitions with validation and duplicate-ID protection. | Draft. |

### P2 — Quest, NPC, crafting, gathering, vendor domains

| ID | Status | Task | Deliverable | Merge posture |
|---|---|---|---|---|
| BA-020 | READY | Define canonical quest contracts and deterministic quest-state resolver. | Quest IDs, objectives, prerequisites, transitions, rewards references, failure/abandon semantics, pure tests. No remote/bootstrap wiring. | `[BUILD-AHEAD/BLOCKED]` draft if runtime source changes. |
| BA-021 | READY | Define canonical NPC definition/conversation/interaction contracts. | Stable NPC IDs, role metadata, interaction capabilities, authored dialogue references, pure validation. | Draft/dormant. |
| BA-022 | READY | Define canonical crafting recipe model and deterministic resolver. | Recipe IDs, ingredient quantities, eligibility result/reason IDs, output references, tests. No inventory mutation wiring. | Draft/dormant. |
| BA-023 | READY | Define gathering/resource-node content model. | Resource IDs, node archetypes, respawn/config metadata, tool/eligibility requirements, reward references, validation. | Draft/dormant. |
| BA-024 | READY | Define vendor/catalog/pricing contracts. | Vendor IDs, catalog entries, currency/item references, eligibility/result reason IDs, tests. No purchase mutation path yet. | Draft/dormant. |
| BA-025 | BLOCKED on BA-020–024 | Create cross-domain dependency validation. | Fixture proving quests/crafting/vendors/gathering/NPC references resolve to known IDs without cycles or orphaned content. | Can merge if pure/test-only. |

### P3 — Dungeon and expedition preparation

| ID | Status | Task | Deliverable | Merge posture |
|---|---|---|---|---|
| BA-030 | READY | Define canonical dungeon/expedition content contract. | Dungeon IDs, room sequence descriptors, encounter hooks, elite/boss slots, reward tables, return path, difficulty metadata. | Draft/dormant. |
| BA-031 | READY | Define portal destination/eligibility contract. | Portal IDs, destination dungeon/route IDs, party constraints, unlock prerequisites, explicit denial reasons. | Draft/dormant. |
| BA-032 | BLOCKED on BA-030 | Prepare first repeatable dungeon content data. | One short expedition with authored room/encounter sequence and boss slot using existing canonical combat/enemy systems. | Draft; no bootstrap/activation. |
| BA-033 | BLOCKED on BA-032 | Prepare dungeon reward-decision data. | Elite/boss reward choice definitions that reference the canonical loot/item system rather than replacing it. | Draft. |

### P4 — Combat-content depth without authority duplication

| ID | Status | Task | Deliverable | Merge posture |
|---|---|---|---|---|
| BA-040 | READY | Audit current enemy archetype coverage against the product north star. | Gap matrix for melee pressure, ranged pressure, disruptor/control, elite mechanics, boss mechanics and readable counters. | Docs/data safe. |
| BA-041 | BLOCKED on BA-040 | Prepare missing enemy archetype configs/behavior primitives using the existing EnemyService authority boundary. | Focused configs/pure resolvers/tests; no competing enemy service. | Draft if runtime behavior changes. |
| BA-042 | READY | Audit randomized item/loot coverage and identify missing build-decision dimensions. | Affix/stat/set/rarity gap report tied to player choices, not raw item count. | Docs/data safe. |
| BA-043 | BLOCKED on BA-042 | Prepare deterministic item-generation/affix rules and fixtures. | Seedable resolver, bounded affix compatibility, duplicate/exclusion rules, test matrix; use existing loot/inventory authority. | Draft/dormant until integration gate. |
| BA-044 | READY | Audit progression/skill-system source and preserved Studio concepts. | Canonical-vs-legacy mapping with recommended smallest vertical-slice skill progression. | Docs/data safe. |

### P5 — Authored outdoor route and exploration preparation

| ID | Status | Task | Deliverable | Merge posture |
|---|---|---|---|---|
| BA-050 | BLOCKED on BA-002/004 | Define first authored outdoor route as data. | Route IDs, encounter beats, landmark IDs, optional discovery node, entrance/exit, readable objective sequence. | Draft/dormant. |
| BA-051 | BLOCKED on BA-050 | Prepare encounter beat definitions for the first route. | Mixed enemy groups, pacing constraints, objective/trigger references, elite placement, failure/recovery assumptions. | Draft/dormant. |
| BA-052 | BLOCKED on BA-002 | Prepare landmark/discovery content definitions. | Stable discovery IDs, presentation intent, gameplay meaning, rewards references, streaming-safe identity. | Draft/dormant. |

### P6 — Player onboarding and control preparation

| ID | Status | Task | Deliverable | Merge posture |
|---|---|---|---|---|
| BA-060 | READY | Design the smallest first-session onboarding sequence. | Player-facing goals from spawn → weapon/build choice → route → combat → dungeon → reward → return. | Docs/content safe. |
| BA-061 | READY | Audit PC/mobile/controller action coverage. | One semantic action map showing existing bindings, missing actions, conflicts, hold/tap behavior and accessibility considerations. | Docs/tests/tooling safe. |
| BA-062 | BLOCKED on BA-061 | Prepare input abstraction improvements without changing authority. | Shared semantic action definitions and client-only mapping preparation with tests where practical. | Draft if runtime source changes. |
| BA-063 | READY | Prepare UI information architecture for HubTown/expedition/loot decisions. | Screen/state matrix, ownership boundaries, safe-area/mobile notes; no visual runtime activation required. | Docs/content safe. |

### P7 — Integration planning and anti-regression

| ID | Status | Task | Deliverable | Merge posture |
|---|---|---|---|---|
| BA-070 | READY | Create a combined-game integration dependency graph. | Ordered graph from preserved RBXL content through HubTown → route → dungeon → loot → return, with runtime-gate dependencies explicit. | Docs/tooling safe. |
| BA-071 | READY | Add source audits protecting against legacy service resurrection. | Tests fail if old `RPGServerBootstrap`/duplicate CombatService/EnemyService/Inventory/Loot/Persistence/Monetization paths are accidentally bootstrapped. | Safe if test-only. |
| BA-072 | READY | Add canonical content-ID collision/orphan validator tooling. | Validator scans prepared content manifests/contracts and reports duplicates, broken refs, cycles where forbidden. | Safe if tooling/test-only. |
| BA-073 | BLOCKED on BA-001–072 relevant subsets | Assemble a `VERTICAL-SLICE-INTEGRATION-PLAN.md`. | Exact PR/merge order after v2.7 gates open; identifies which prepared branches can be promoted and what Studio evidence each requires. | Docs safe. |

## Tasks agents must NOT perform yet

Until the corresponding runtime gate is accepted, do not:

- merge PR #221 before R1 acceptance;
- merge/activate PR #222 before #221 and its evidence;
- add/enable the actual `ClientReady` cutover on `main` before the R2 stage is authorized;
- implement/activate R3 suppression in the current producer before R2 evidence;
- remove the compatibility `HordeNetwork.State` path;
- claim the broad blue/yellow Highlight incident is fixed without Studio evidence;
- replace the conservative broad-Highlight guard with an inferred root cause;
- boot legacy RBXL gameplay services beside canonical services;
- wire prepared quests/crafting/vendors/gathering/dungeons into production bootstraps before the integration gate opens;
- merge large authored-world/runtime changes into `main` merely because source CI passes;
- claim E2/E3/E4 from repository tests.

## Current recommended assignment for Claude

If Claude is being given one autonomous run, assign in this order until time/context runs out:

```text
BA-001 HubTown migration manifest
→ BA-002 authored-world migration manifest
→ BA-003 legacy-script disposition matrix
→ BA-070 combined-game dependency graph
→ BA-071 legacy-service resurrection audits
→ BA-072 content reference validator
→ BA-020 quest contracts/resolver
→ BA-022 crafting contracts/resolver
→ BA-030 dungeon/expedition contract
→ BA-040 enemy coverage audit
→ BA-042 loot/build-decision audit
```

The first six items are especially valuable because they reduce integration uncertainty while touching little or no active gameplay runtime.

## Promotion rule after the user completes R1 Studio evidence

When the canonical R1 packet is accepted:

1. Update `V2.7-CUTOVER-LEDGER.md` with measured facts.
2. Rebase/recheck PR #221 against current `main`.
3. Promote #221 only under its documented gate and collect its runtime evidence.
4. Then promote the R2 activation stage using the prepared #222 primitive.
5. After R2 delayed-ready/late-join evidence passes, implement R3 semantic/change-token suppression.
6. Continue R4/R5 evidence closure.
7. Use `BA-073` to promote prepared gameplay/content work in dependency order rather than rebuilding it from scratch.

## Definition of success for this parallel lane

The build-ahead lane is successful when the Studio gate can eventually open and the team already has:

- a complete migration truth map for the preserved RBXL game;
- canonical content IDs and contracts;
- quest/crafting/vendor/gathering/dungeon schemas ready;
- HubTown and world composition mapped;
- one outdoor route and one dungeon planned in canonical terms;
- enemy/loot/progression gaps understood;
- legacy duplicate services guarded against resurrection;
- integration branches/PRs small enough to review and promote independently;
- no false runtime evidence claims and no uncontrolled feature activation.

> Build ahead aggressively; activate conservatively.
