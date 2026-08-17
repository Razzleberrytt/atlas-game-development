# Atlas — Execution Dashboard v1.31

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-17  
**Main baseline audited:** `0cb0c8c967a269ac6899d4056f70b90741f5fe1d`  
**Purpose:** answer quickly what is true, what is NOW, what may proceed, and what comes NEXT.

## Precedence

1. Accepted runtime evidence and current Roblox platform behavior — truth about what actually works.
2. [`../bible/00-current-product-authority.md`](../bible/00-current-product-authority.md) — product identity and design conflict resolution.
3. [`PARALLEL-DEVELOPMENT-POLICY.md`](PARALLEL-DEVELOPMENT-POLICY.md) — dependency-safe eligibility, not unlimited WIP.
4. [`AUTOMATED-FIRST-EXECUTION-POLICY.md`](AUTOMATED-FIRST-EXECUTION-POLICY.md) — automated execution cadence and verification authority.
5. This dashboard — current daily status and NOW/NEXT selection.
6. [`PLAYABLE-MVP-PATCH-EXECUTION.md`](PLAYABLE-MVP-PATCH-EXECUTION.md) — player-facing patch goals/product intent.
7. [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md) — long-range destination inventory.
8. Patch-specific acceptance/backlog documents — active only when this dashboard selects that patch/capability.

## Current truth — 2026-08-17

- Living Kingdoms remains a Roblox/Rojo repository-first codebase; `games/living-kingdoms/src/` is gameplay-authoritative source.
- Patch 0.7 durable persistence/valuable-state hardening remains automated-acceptance complete for all non-deferred work (86 / 100 implemented; 14 explicit deferrals).
- **LKB-0682, LKB-0033, LKB-0567, and LKB-0321 are VERIFIED.** The latest completed gameplay capability, LKB-0321, merged as `ddf3a13f0fac07a4538e371a8adaf143f56c8ede` after Full Atlas #2398; main push #2399 passed. Its coordination closeout passed #2400, merged as `0cb0c8c967a269ac6899d4056f70b90741f5fe1d`, and main push #2401 passed.
- LKB-0321 supersedes stale #570's path-budget/fairness work. #570's separate stuck-recovery/jump-policy ideas remain unselected source evidence only.
- Current `RoomSequenceAssembler` already owns deterministic seeded **content order**, variable route length, encounter slots/intensity, reward source metadata, and Entry/Elite/Boss ordering. Do not replace that owner with stale #568 code.
- Current `RoomPlacementPlanner` still owns only a fixed straight Z-axis layout. There is no current `InstanceLayoutValidator` and no current `ProceduralInstanceGenerator` orchestration seam.
- Fresh #568 audit found a current-compatible separable capability: deterministic self-avoiding cardinal spatial placement with bounded attempts/fallback, pure fail-closed layout validation, and a thin generator/orchestration seam. The old branch's assembler options, spawn/reward metadata expansion, and runtime rewrite are not required for this slice.
- Current `ExpeditionRoomPlacementService` already owns Roblox instance placement and current `ModularDungeonRoomPresentation.apply(...)`; any LKB-0481 integration must preserve those owners and adapt only the geometry/socket handling needed for cardinal layouts.
- #566/#579 durable character progression remains genuinely absent but is a much larger R3 persistence/schema stack. #574 multi-run procedural-instance ownership is also a later independent capability and is not part of LKB-0481.
- Therefore **LKB-0481 is the sole BUILDING ticket**. Canonical mapping: workstream 20 **Procedural Rooms & Spatial Placement** × dimension 6 **Deterministic resolution** = LKB-0481.

## NOW

### 1. Deterministic procedural spatial generation and validation — LKB-0481

Reconcile only the smallest current-compatible spatial-generation capability from stale #568 onto fresh current main.

Required outcome:

- preserve `RoomSequenceAssembler` as the canonical owner of room content order and current public behavior;
- upgrade `RoomPlacementPlanner` from one fixed linear axis to deterministic seeded self-avoiding cardinal placement with bounded generation attempts and deterministic fallback;
- preserve canonical room sequence order even when the physical route turns;
- expose explicit grid cell, entrance/exit side, turn, connector axis/size, layout version, generation-attempt, and fallback metadata needed to validate/render the layout;
- add a pure `InstanceLayoutValidator` that fails closed on malformed plans/layouts, seed mismatch, room-count/order/identity drift, duplicate cells, overlap, invalid cardinal adjacency, socket-direction mismatch, and connector-geometry mismatch;
- add a thin `ProceduralInstanceGenerator` that orchestrates the existing assembler → planner → validator path without inventing another room-content owner;
- keep generation bounded and reproducible from seed; no hidden Roblox randomness/services in pure resolution;
- adapt the existing `ExpeditionRoomPlacementService` only enough to consume validated cardinal layouts: orient doorway fixtures/connectors and create walls/openings correctly on North/East/South/West sides;
- preserve `ExpeditionEnvironmentBuilder` and `ModularDungeonRoomPresentation.apply(...)` exactly as downstream presentation owners;
- preserve the singleton current expedition-room lifecycle for this ticket; no #574 run registry/multi-run authority;
- add focused deterministic planner/generator/validator tests plus source/integration audits proving the runtime placement service consumes the validated generator and does not bypass it;
- pass Full Atlas validation before merge.

Scope exclusions:

- do **not** copy #568's stale `RoomSequenceAssembler` option/variable-count changes; current main already has a stronger deterministic assembler;
- do not add encounter spawn-point attachments, reward/completion hook authority, or new gameplay metadata merely because old #568 bundled them;
- do not import #574's `ExpeditionInstanceRegistry`, multi-run spatial slots, or party/run ownership;
- do not change combat, enemies, loot, XP, persistence, mission authority, or room-content selection;
- do not weaken current modular dungeon presentation to match the old branch.

Risk tier: **R2**. If implementation requires changing durable state, run ownership, mission authority, or content-order contracts, stop and reclassify rather than silently expanding scope.

Exit gate:

1. deterministic same-seed layouts reproduce exactly; different seeds demonstrate bounded spatial variation;
2. every accepted layout preserves canonical order, unique cells, non-overlap, cardinal adjacency, correctly facing sockets, and matching connector geometry;
3. generation attempts are finite and fallback is deterministic;
4. current placement/presentation owners render the validated axis-aware layout without a second spatial authority;
5. Full Atlas validation is green on the exact final PR head;
6. merge and require green main-push validation;
7. audit #568/#574 overlap again, verify LKB-0481, release the shared claim, and re-run the selector.

### 2. Keep repository/documentation truth coherent

Update canonical coverage/efficiency registries only if this coherent capability materially creates or retires a reusable seam. Do not create another status system.

## Selector audit — why LKB-0481 won

- **#568 procedural spatial generation:** high replayability leverage, distinct from current main, decomposable into an R2 deterministic slice, and compatible with current assembler/runtime ownership when stale bundled metadata is excluded. **Selected as LKB-0481.**
- **#566/#579 progression:** high player-loop value but currently an R3 durable-account/schema/migration stack spanning 26 changed files across two old PRs. Requires a fresh persistence-owner audit before activation.
- **#570 stuck recovery:** smaller diff, but no current measured stuck defect justifies choosing it over a replayability capability; remains failure-fallback source evidence.
- **#574 multi-run procedural ownership:** useful later, but it expands authoritative run-instance ownership before the current spatial generator/validator seam exists on main. Deferred until after LKB-0481 and a fresh runtime-ownership audit.

## NEXT

After LKB-0481 leaves BUILDING:

1. require exact-head Full Atlas and post-merge main validation;
2. record VERIFIED only with that evidence, then release the mutex through a validated closeout;
3. re-audit #568/#574 for surviving unique work and #566/#579 against the then-current durable account architecture;
4. rank the smallest next player-value capability, publish one atomic claim, and continue the same loop.

Patch 0.8 remains an available planned queue but is not automatically selected. Patch 0.9 and RC 1.0 remain later planned queues unless explicitly activated.

## Development coverage lens

For broad audits/refactors, route through:

```text
LK concern(s)
→ canonical engine(s)
→ real existing owner
→ dependency/PR overlap
→ smallest coherent implementation
→ risk-tier validation
→ measurement/evidence
→ coverage update if materially changed
→ merge
```

Coverage gaps are candidates, not automatic priority.

## Manual evidence backlog

Manual Studio/device/play work is separate from NOW/NEXT. Record only what was actually measured. Reproducible defects discovered there may become source-work candidates; unrun facts remain UNMEASURED.

## WIP rule

- one active implementation PR for the current capability/lane;
- at most one additional non-overlapping feature PR only when the first is externally blocked;
- open PR count is not the execution queue;
- inspect freshness/overlap before starting;
- merge only after applicable automated validation is green;
- update NOW/NEXT whenever execution truth materially changes.
