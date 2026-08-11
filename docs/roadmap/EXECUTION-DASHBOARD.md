# Atlas — Execution Dashboard v1.12

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
- Patch 0.4 closed with one deliberately small durable Operative Rank map, generic owner-bound unlock eligibility/presentation, and five bounded personal unlocks spanning three existing server consequence owners. It introduced no second save owner and did not turn rare in-run firearms into permanent insertion gear.
- PR #366 repaired the BA-010 expedition-environment Workspace-listener lifecycle debt and added regression coverage; full validation and the reproducible build are green.
- **Patch 0.5 — Main World + Environment Expansion:** **BLOCKED — REQUIRED CIVIC PROPERTY EVIDENCE UNAVAILABLE**.
- BA-010 through BA-014 define the Main World audit, dedicated-place/source boundary, stable interaction registry, production kits/budgets, and unrun acceptance matrix. These are authority/evidence inputs, not permission to dump or activate the recovered world.
- `MainWorldRepresentationConfig` holds the dedicated Main World boundary, 1:1 authored coordinates, semantic streaming groups, and arrival/return anchor policy.
- `AuthoredWorldRecoveryCoverageConfig` is the geometry-admission gate. It pins canonical source RBXL SHA256 `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`, records the uncommitted historical full property artifact as 1,546,379 bytes with SHA256 `078a64153fbc1d29409e326c924ba7bb1cd3cbe7137277697955af7c448708ea`, and forbids new geometry promotion from incomplete evidence.
- The hierarchy evidence proves civic candidates exist (`CentralFountain`, `GrandStaircase`, `HubArchway`), but current committed reviewable property evidence does not contain complete supported-property rows for one of those groups. The canonical binary `.rbxl` itself is not present in the repository or retained workflow artifacts inspected during this pass.
- PR #368 added `scripts/roblox/select_rbxl_subtree_evidence.py`: full decoder JSON → one deterministic, checksum-gated, exact-path review unit.
- PR #369 added `scripts/roblox/extract_rbxl_review_unit.py`: canonical `.rbxl` → property decoder → bounded subtree review artifact in one command. Full validation and reproducible build are green.
- Safe code-side preparation for this specific civic-evidence blocker is now exhausted. Do **not** fabricate Central Fountain geometry, relax the admission gate, activate a whole recovered HubTown, or jump to later-patch breadth merely to avoid the blocker.

## 2. NOW → NEXT → LATER

### NOW

**BLOCKED — recover reviewable canonical property evidence for one coherent `main_world.hub_core` civic unit.**

Preferred first target remains `Workspace/HubTown/CentralFountain`, because BA-010/BA-013 identify a compact arrival/orientation/adventure-gate composition and the arrival anchor plus DungeonPortal already have bounded held contracts.

Resume when **either** of these evidence inputs becomes reviewably available:

1. the canonical binary place whose SHA256 is exactly `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`; or
2. the historical full property decoder artifact whose SHA256 is exactly `078a64153fbc1d29409e326c924ba7bb1cd3cbe7137277697955af7c448708ea`.

Preferred direct resume command when the canonical place is available:

```bash
python scripts/roblox/extract_rbxl_review_unit.py livingkingdoms.rbxl \
  --subtree Workspace/HubTown/CentralFountain \
  --expected-source-sha256 e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16 \
  --out central-fountain.json
```

If the historical full decoder JSON is recovered instead:

```bash
python scripts/roblox/select_rbxl_subtree_evidence.py rbxl-world-properties.json \
  --subtree Workspace/HubTown/CentralFountain \
  --expected-source-sha256 e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16 \
  --out central-fountain.json
```

After a bounded artifact exists, the target chain is:

```text
checksum-pinned evidence
→ complete supported-property rows for one coherent civic group
→ stable main_world.hub_core review-unit identity
→ held source representation + property-parity regression
→ reviewable model asset
→ dedicated Main World mapping/bootstrap only after the existing creation gate is satisfied
```

Rules:

- do not create or activate the dedicated Main World project merely to make progress;
- do not map held content into the current operation project or parent recovered content under `LivingKingdomsWorld`;
- preserve authored-overworld coordinates 1:1; no global translation, rotation, or scale to fit the operation forest;
- do not guess Terrain voxels, missing properties, asset IDs, NPC/vendor/quest authority, teleport policy, or legacy gameplay behavior;
- keep `WorldFoundationService` operation-world generation out of the future Main World bootstrap;
- use stable semantic IDs and semantic streaming groups so gameplay/presentation truth survives a locally absent Instance;
- never restore all 1,775 recovered rows or a whole `HubTown` / `WorldStructures` root as one production review unit;
- keep the existing Forward Operations Hub as the temporary bridge until the authored arrival/preparation/launch/return loop is accepted;
- keep Studio/device/streaming/performance evidence pending until BA-014 is run against a real representative build;
- because `PLAYABLE-MVP-PATCH-EXECUTION.md` forbids later-patch breadth while a current-patch blocker is known, do not advance to Patch 0.6 simply because this external evidence is missing.

### NEXT

1. once the first civic review artifact exists, validate property parity and create the smallest held source representation for that one coherent group;
2. preview held arrival + orientation landmark + expedition-gate composition without runtime activation;
3. establish the authored Main World return/debrief anchor and cold-join/success/failure/replay re-entry semantics before activation;
4. create the dedicated Main World Rojo project only when the existing gate is satisfied: first property-validated coherent model group + explicit server/client bootstrap allowlists + reproducible offline build;
5. expand `main_world.hub_core` through stable-ID interaction/service forms while preserving canonical class/loadout/inventory/progression/expedition owners;
6. replace recovered `WorldPath` slabs with stable route/control data and bounded 64–128-stud render chunks only after the hub core is readable;
7. admit terrain, structures, props, foliage, lighting, VFX, and audio only through BA-013 kit/budget rules and BA-014 evidence.

Rejected shortcuts remain:

- copying the recovered whole world into the active operation place;
- treating recovered hierarchy counts or partial samples as property-complete geometry evidence;
- creating a second gameplay owner inside reconstructed vendors, quest boards, portal models, NPCs, or prompts;
- inventing Terrain, asset IDs, global Lighting ownership, teleport/session behavior, or streaming radii without required evidence/authority;
- marking Main World VERIFIED from source-only reconstruction or screenshots without BA-014 device/traversal/streaming/performance evidence.

### LATER

- deeper Patch 0.5 Main World environment breadth after the hub core is accepted;
- Patch 0.6 systemic replayability;
- Patch 0.7 persistence hardening;
- Patch 0.8 co-op/social/session;
- Patch 0.9 content/pipeline expansion;
- release-candidate hardening.

### WIP limit

- one active implementation PR for the current capability;
- at most one additional non-overlapping feature PR only when the first is externally blocked **and** the additional work remains inside the current patch's blocker-removal/preparation boundary;
- never duplicate an existing open PR or work currently owned by another active agent.

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
checksum-pinned recovered evidence
→ direct decoder or existing full decoder output
→ exact bounded subtree selector
→ stable semantic ID + streaming group
→ deterministic property-parity validation
→ held source-managed representation
→ later place mapping only after explicit gates
```

The first admitted hub-core unit should make the second coherent unit cheaper. PRs #368/#369 remove the repeated manual extraction/selection ritual; they do not substitute for the missing canonical evidence itself.

## 4. Studio/device evidence lane

The consolidated pass still covers the representative run, replay, keyboard/controller/touch, combat feel/readability, banking/equip, lifecycle, build-choice readability, durable rank/progression presentation, Rally/marker readability, and representative performance.

For Patch 0.5, source admission and held reconstruction do **not** substitute for BA-014. When a representative Main World build exists, BA-014 must cover arrival camera/readability, four-player clearance, traversal/dead travel, interaction visibility, streaming continuity/rebind, quality tiers, performance, memory, and cleanup.

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
| **0.5 Main World** | **BLOCKED — CIVIC PROPERTY EVIDENCE** | exact evidence → bounded review unit → reusable admission/reconstruction |
| 0.6 systemic replayability | future; do not start while 0.5 blocker is known | combinatorial output from reusable systems |
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
5. if NOW is externally blocked, perform only bounded preparation that directly removes or shortens that blocker;
6. otherwise implement the smallest coherent NOW increment;
7. prefer existing owners + data/configuration over copied services/controllers/remotes;
8. add focused regression defense;
9. run the matching validation profile;
10. merge successful dependency-safe work;
11. keep manual evidence pending when not run;
12. do not jump to later-patch breadth while a current-patch blocker is known;
13. stop when safe blocker-removal work is exhausted and report the exact external resume condition.

## 7. Real stop conditions

Stop expansion and fix/report when continuing would knowingly build on unsafe/false assumptions, including client-authored consequential truth, valuable-state corruption/duplication, competing owners, known lifecycle failure, missing required canonical authority/evidence, irreversible unsafe migration, or automated validation failure.

The current Patch 0.5 civic review-unit blocker is a real stop condition **after** PRs #368/#369: exact extraction/admission tooling exists, but the checksum-pinned canonical source or full exact property artifact is not currently reviewably available.

Unrun ordinary Studio/device/play-feel evidence alone is not a stop condition.

> **Build continuously, route effects to one owner, make repeated variants cheaper, automate recurring friction, and stop only for real blockers.**
