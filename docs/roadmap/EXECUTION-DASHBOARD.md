# Atlas — Execution Dashboard v1.13

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-10  
**Purpose:** answer quickly: **what is true, what is NOW, what is NEXT, and how do we keep later development cheaper?**

For detailed acceptance use `PLAYABLE-MVP-PATCH-EXECUTION.md`. For long-range scope use `MASTER-ROADMAP.md`. `MVP-BUILD-THROUGH-TESTING-POLICY.md` controls cadence. Repeated families use `../production/EXTENSION-COST-MODEL.md`; reusable gameplay effects use `../production/EFFECT-OWNER-ROUTING.md`.

## 1. Current truth

- **MVP 0.1 source:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.2 combat/readability source pass:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.3 — Loot + Build Replayability source pass:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.4 — RPG Progression source pass:** **BUILT — VERIFICATION PENDING**.
- Studio/device/play/performance evidence remains a parallel lane; unrun evidence is not a source-development lock and is never called VERIFIED.
- **Patch 0.5 — Main World + Environment Expansion:** **SOURCE-UNBLOCKED — AUTHORED RBXL RECONCILIATION COMPLETE; VERIFICATION PENDING**.
- The supplied 2026-08-10 `livingkingdoms.rbxl` is pinned as authored-world evidence at SHA-256 `7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b` and 1,808,699 bytes. It contains 2,342 declared instances, 1,775 Workspace instances, and 367 embedded scripts.
- Current GitHub/Rojo gameplay remains authoritative. The incoming place is not mapped into the active project and its overlapping bootstrap/combat/enemy/inventory/loot/data/monetization runtime is quarantined rather than resurrected.
- Script reconciliation preserves all historically unique material: 27/28 historically unique source files are present in the new place, while the absent `RNGConfig.luau` remains preserved in the 2026-08-07 archive.
- The useful bounded civic evidence from the current revision is now exhausted safely:
  - PR #371 — exact 11-instance Central Fountain held reconstruction;
  - PR #377 — exact 35-instance Grand Staircase held reconstruction;
  - PR #379 — exact 6-instance Hub Archway held reconstruction;
  - PR #380 — current-revision Dungeon Portal parity against the existing held portal contract.
- Other Resources, WorldStructures, atmosphere, Terrain, NPC/vendor/quest, and asset-specific details remain partial/hierarchy evidence when complete current property rows are not committed. Do not invent them merely to increase recovered-world coverage.
- `AuthoredWorldRecoveryCoverageConfig` remains the admission boundary. Held authored-world representations stay dormant until the existing dedicated Main World creation/activation gates are satisfied.

## 2. NOW → NEXT → LATER

### NOW

**Resume ordinary Patch 0.5 Main World progression from the reconciled held evidence.**

The RBXL intake/gap-chase is no longer the active task. The smallest coherent next capability is to turn the admitted held hub-core evidence into a reviewable **dedicated Main World source representation** without activating duplicate gameplay authority or forcing it into the operation forest.

Target chain:

```text
checksum-pinned admitted civic evidence
→ stable main_world.hub_core semantic composition
→ dedicated Main World source representation
→ explicit server/client bootstrap allowlists
→ reproducible offline build
→ arrival / preparation / expedition-gate / return semantics
→ Studio/device/streaming/performance evidence
```

Rules:

- do not copy the recovered whole world into the active operation place;
- preserve authored-overworld coordinates 1:1 unless a later evidence-backed representation contract explicitly says otherwise;
- do not revive legacy bootstrap/services, duplicate remotes, or model-owned gameplay authority;
- keep canonical combat, inventory, progression, persistence, expedition, and networking owners in current repository source;
- do not guess Terrain voxels, missing asset IDs, NPC/vendor/quest behavior, global Lighting ownership, or teleport/session behavior;
- keep `WorldFoundationService` operation-world generation out of the dedicated Main World bootstrap;
- use stable semantic IDs and streaming groups so gameplay/presentation truth survives locally absent Instances;
- keep ordinary Studio/device evidence pending until actually run; pending evidence does not block dependency-safe source work.

### NEXT

1. compose the admitted Central Fountain + Grand Staircase + Hub Archway + held arrival + held Dungeon Portal into the smallest source-managed `main_world.hub_core` representation;
2. define/verify explicit dedicated Main World server/client bootstrap allowlists and keep legacy runtime/import directories excluded;
3. produce the reproducible dedicated Main World offline build once the existing creation gate is satisfied;
4. establish cold-join arrival, expedition launch, success/failure return, debrief, and replay re-entry semantics through existing canonical owners;
5. preview/readability-check the hub core before expanding environmental breadth;
6. replace recovered `WorldPath` slabs with stable route/control data and bounded render chunks only after the hub core is coherent;
7. admit terrain, structures, props, foliage, lighting, VFX, and audio only through the existing production-kit/budget and acceptance rules.

### LATER

- deeper Patch 0.5 Main World environment breadth after the hub core is accepted;
- Patch 0.6 systemic replayability;
- Patch 0.7 persistence hardening;
- Patch 0.8 co-op/social/session;
- Patch 0.9 content/pipeline expansion;
- release-candidate hardening.

### WIP limit

- one active implementation PR for the current capability;
- at most one additional non-overlapping feature PR only when the first is externally blocked and the extra work remains inside the current patch;
- never duplicate an existing open PR or another active agent's work.

## 3. Compounding-development target

The repository must become **cheaper to extend as it grows**.

For repeated feature/content families:

```bash
python scripts/extension_cost.py list
python scripts/extension_cost.py show <contract-id>
python scripts/extension_cost.py check <contract-id> --base main
```

For reusable gameplay effects:

```bash
python scripts/effect_routes.py validate
python scripts/effect_routes.py list
python scripts/effect_routes.py show <EffectId>
python scripts/effect_routes.py next
```

Patch 0.5's evidence/admission flywheel is now:

```text
checksum-pinned authored evidence
→ bounded coherent review unit
→ stable semantic ID + streaming group
→ deterministic parity/preservation record
→ held source-managed representation
→ dedicated-place composition behind explicit bootstrap gates
→ later activation only after acceptance evidence
```

The RBXL reconciliation work has already paid the one-time extraction/recovery cost for the admitted civic core. Do not repeatedly rediscover or re-import the same geometry.

## 4. Studio/device evidence lane

The consolidated pass still covers the representative run, replay, keyboard/controller/touch, combat feel/readability, banking/equip, lifecycle, build-choice readability, durable rank/progression presentation, Rally/marker readability, and representative performance.

For Patch 0.5, source admission and held reconstruction do **not** substitute for the Main World acceptance matrix. A representative build must still cover arrival camera/readability, four-player clearance, traversal/dead travel, interaction visibility, streaming continuity/rebind, quality tiers, performance, memory, and cleanup.

- **pass:** promote applicable BUILT — VERIFICATION PENDING work to VERIFIED;
- **reproducible failure:** make the concrete FIX NOW and preempt expansion;
- **not run:** continue dependency-safe source work when available while preserving pending-evidence truth.

## 5. Planning snapshot

| Area | Status truth | Compounding target |
|---|---|---|
| Foundation / architecture | mature | stable owners + machine-readable routing + low rediscovery |
| MVP 0.1 | BUILT — VERIFICATION PENDING | regression-protected baseline |
| 0.2 combat/readability | BUILT — VERIFICATION PENDING | reusable feedback/reaction contracts |
| 0.3 loot/builds | BUILT — VERIFICATION PENDING | affix/effect/reward variants are data-first |
| 0.4 RPG progression | BUILT — VERIFICATION PENDING | bounded rank map + generic entitlement/presentation + reusable owner adapters |
| **0.5 Main World** | **SOURCE-UNBLOCKED — RBXL RECONCILED; VERIFICATION PENDING** | admitted hub core → dedicated source representation → acceptance evidence |
| 0.6 systemic replayability | future; do not start before coherent 0.5 hub-core progress | combinatorial output from reusable systems |
| 0.7 persistence | substantial foundations | migration/lifecycle invariants and recovery tests |
| 0.8 co-op/social | basic foundations | multiplayer coverage over existing owners |
| 0.9 content/pipeline | preparation present | mostly data/content + validation |
| RC 1.0 | future | accumulated automation reduces hardening cost |

## 6. Agent task algorithm

When asked to continue:

1. fetch current `main`;
2. inspect open PRs, same-capability branches, and active-agent overlap;
3. read NOW/NEXT;
4. fix concrete safety/authority/data/runtime/validation failures first;
5. otherwise implement the smallest coherent NOW increment;
6. prefer existing owners + data/configuration over copied services/controllers/remotes;
7. add focused regression defense;
8. run the matching validation profile;
9. merge successful dependency-safe work;
10. keep manual evidence pending when not run;
11. do not jump to later-patch breadth while coherent current-patch work remains;
12. stop only for a genuine unsafe/unknown dependency and record the exact resume condition.

## 7. Real stop conditions

Stop expansion and fix/report when continuing would knowingly build on unsafe or false assumptions, including client-authored consequential truth, valuable-state corruption/duplication, competing owners, known lifecycle failure, missing required canonical authority/evidence, irreversible unsafe migration, or automated validation failure.

The former civic-property-evidence blocker is closed by the checksum-pinned 2026-08-10 intake and PRs #371/#377/#379/#380. Remaining incomplete world-property families are not permission to fabricate them; they simply stay outside the admitted source representation until better evidence exists.

Unrun ordinary Studio/device/play-feel evidence alone is not a stop condition.

> **Build continuously, route effects to one owner, make repeated variants cheaper, automate recurring friction, and stop only for real blockers.**
