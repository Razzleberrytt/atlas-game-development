# Atlas — Execution Dashboard v1.14

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
- **Patch 0.5 — Main World + Environment Expansion:** **DEDICATED SOURCE BUILD ESTABLISHED — HUB CORE MATERIALIZED; VERIFICATION PENDING**.
- The supplied 2026-08-10 `livingkingdoms.rbxl` is pinned as authored-world evidence at SHA-256 `7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b` and 1,808,699 bytes. It contains 2,342 declared instances, 1,775 Workspace instances, and 367 embedded scripts.
- Current GitHub/Rojo gameplay remains authoritative. The incoming place is not mapped into the active operation project and its overlapping bootstrap/combat/enemy/inventory/loot/data/monetization runtime remains quarantined rather than resurrected.
- Script reconciliation preserves all historically unique material: 27/28 historically unique source files are present in the new place, while the absent `RNGConfig.luau` remains preserved in the 2026-08-07 archive.
- The admitted hub core is now represented in source rather than only held as recovery evidence:
  - PR #382 — stable `main_world.hub_core` semantic composition;
  - PR #383 — explicit dedicated Main World server/client bootstrap allowlists with legacy/import runtime excluded;
  - PR #384 — dedicated `main-world.project.json`, first reviewable model payload, reproducible offline Main World build, and CI build gate;
  - PR #385 — exact authored arrival spawn plus held `Arrival -> Preparation -> Expedition -> Debrief` lifecycle contract bound to canonical expedition/result owners;
  - PR #386 — exact Grand Staircase + Hub Archway model payloads and full parity coverage;
  - PR #387 — exact Dungeon Portal presentation payload and parity/authority coverage under `HubCore/ExpeditionGate`.
- The dedicated Main World remains unpublished and runtime-disabled. No place IDs, teleport policy, duplicate remotes, legacy dungeon authority, or operation-world generator have been introduced.
- The current dedicated build now contains the exact admitted arrival + Central Fountain + Grand Staircase + Hub Archway + Dungeon Portal presentation. The hub-core source representation creation gate and reproducible offline-build gate are therefore satisfied.
- Other Resources, WorldStructures, atmosphere, Terrain, NPC/vendor/quest, and asset-specific details remain partial/hierarchy evidence when complete current property rows are not committed. Do not invent them merely to increase recovered-world coverage.
- `AuthoredWorldRecoveryCoverageConfig` remains the admission boundary. Source admission does not equal runtime activation or acceptance verification.

## 2. NOW → NEXT → LATER

### NOW

**Make the dedicated Main World hub core reviewable and robust before expanding environmental breadth.**

The source-representation/bootstrap/offline-build/lifecycle creation chain is complete. The smallest coherent next capability is source-safe hub-core readability and streaming preparation that does not require inventing missing world data or activating transport.

Target chain:

```text
checksum-pinned admitted civic evidence
→ stable main_world.hub_core semantic composition
→ dedicated Main World source representation
→ explicit server/client bootstrap allowlists
→ reproducible offline build
→ arrival / preparation / expedition-gate / debrief semantics
→ source-safe readability + streaming/control contracts
→ Studio/device/streaming/performance evidence
```

Rules:

- do not copy the recovered whole world into the active operation place;
- preserve authored-overworld coordinates 1:1 unless a later evidence-backed representation contract explicitly says otherwise;
- do not revive legacy bootstrap/services, duplicate remotes, or model-owned gameplay authority;
- keep canonical combat, inventory, progression, persistence, expedition, and networking owners in current repository source;
- do not guess Terrain voxels, missing asset IDs, NPC/vendor/quest behavior, global Lighting ownership, or teleport/session behavior;
- keep `WorldFoundationService` operation-world generation out of the dedicated Main World bootstrap;
- use stable semantic IDs, route/control data, and streaming groups so gameplay/presentation truth survives locally absent Instances;
- keep the portal's recovered `[G]` text presentation-only until an explicit canonical interaction adapter exists;
- keep ordinary Studio/device evidence pending until actually run; pending evidence does not block dependency-safe source work.

### NEXT

1. define machine-readable hub-core readability/clearance/streaming expectations around arrival, civic landmarks, and expedition gate without changing authored coordinates;
2. add source-level validation for stable semantic IDs, bounded streaming groups, and locally-absent-instance-safe references across the dedicated hub core;
3. preview/readability-check the hub core in Studio when evidence can actually be run; record arrival camera/readability, four-player clearance, traversal/dead travel, and interaction visibility truth rather than guessing it;
4. replace recovered `WorldPath` slabs with stable route/control data and bounded render chunks only after the hub core is coherent;
5. establish an explicit canonical portal interaction adapter only when it can delegate to existing expedition authority without inventing inter-place transport;
6. admit terrain, structures, props, foliage, lighting, VFX, and audio only through the existing production-kit/budget and acceptance rules;
7. activate/publish the dedicated Main World only after its separate creation, authority, transport, and acceptance gates are actually satisfied.

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
→ dedicated source-managed representation
→ explicit bootstrap boundary
→ reproducible dedicated-place build
→ source-safe readability / control / streaming contracts
→ later activation only after acceptance evidence
```

The RBXL reconciliation work has already paid the one-time extraction/recovery cost for the admitted civic core. Do not repeatedly rediscover or re-import the same geometry.

## 4. Studio/device evidence lane

The consolidated pass still covers the representative run, replay, keyboard/controller/touch, combat feel/readability, banking/equip, lifecycle, build-choice readability, durable rank/progression presentation, Rally/marker readability, and representative performance.

For Patch 0.5, source admission and reproducible offline building do **not** substitute for the Main World acceptance matrix. A representative build must still cover arrival camera/readability, four-player clearance, traversal/dead travel, interaction visibility, streaming continuity/rebind, quality tiers, performance, memory, and cleanup.

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
| **0.5 Main World** | **DEDICATED SOURCE BUILD ESTABLISHED — HUB CORE MATERIALIZED; VERIFICATION PENDING** | readability/streaming/control contracts → acceptance evidence → gated activation |
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

The former civic-property-evidence blocker and the dedicated source-representation/offline-build creation gates are closed by the checksum-pinned 2026-08-10 intake and PRs #371/#377/#379/#380/#382/#383/#384/#385/#386/#387. Remaining incomplete world-property families are not permission to fabricate them; they simply stay outside the admitted source representation until better evidence exists.

Unrun ordinary Studio/device/play-feel evidence alone is not a stop condition.

> **Build continuously, route effects to one owner, make repeated variants cheaper, automate recurring friction, and stop only for real blockers.**
