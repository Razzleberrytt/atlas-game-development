# Atlas — Execution Dashboard v1.15

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
- **Patch 0.5 — Main World + Environment Expansion:** **DEDICATED SOURCE BUILD + SOURCE-SAFE HUB/ROUTE CONTRACTS ESTABLISHED — VERIFICATION PENDING**.
- The supplied 2026-08-10 `livingkingdoms.rbxl` remains pinned authored-world evidence at SHA-256 `7cfa9ae257cccc1c048459029f95dfdb83a4e113cbf1ff2f281bc7c9532a695b` and 1,808,699 bytes. It contains 2,342 declared instances, 1,775 Workspace instances, and 367 embedded scripts.
- Current GitHub/Rojo gameplay remains authoritative. Preserved/import runtime remains quarantined; the operation project still does not map the recovered whole world or duplicate gameplay owners.
- The dedicated Main World remains unpublished and runtime-disabled. No place IDs, teleport policy, duplicate remotes, legacy dungeon authority, or operation-world generator have been introduced.
- Hub-core creation is complete in source:
  - PR #382 — stable `main_world.hub_core` semantic composition;
  - PR #383 — explicit dedicated Main World bootstrap allowlists and anti-resurrection boundary;
  - PR #384 — dedicated `main-world.project.json`, reproducible offline Main World build, and CI build gate;
  - PR #385 — exact authored arrival plus held `Arrival -> Preparation -> Expedition -> Debrief` lifecycle contract;
  - PR #386 — exact Grand Staircase + Hub Archway model payloads and parity coverage;
  - PR #387 — exact Dungeon Portal presentation payload and authority-preserving parity coverage.
- Source-safe review/streaming preparation is also established:
  - PR #389 — machine-readable hub readability contract, stable `main_world.hub_core` streaming identity, and project/source-contract topology validation;
  - PR #390 — non-blocking semantic presentation resolver with explicit `Present` / `Missing` / `UnknownContentId` states and no `WaitForChild` dependency;
  - PR #391 — stable `route.world.primary` control truth replacing 189 recovered WorldPath slab Instances as route authority;
  - PR #392 — BA-013-aligned `main_world.primary_route` chunk descriptors, deterministically covering the route in 12 held 64–128 stud chunks with no render assets mapped;
  - PR #393 — held Main World expedition-portal delegation contract proving the authored surface delegates to canonical `ExpeditionLobbyService` while owning no eligibility, transport, join/ready/launch grant, or consequential mutation.
- The dedicated build contains the exact admitted arrival + Central Fountain + Grand Staircase + Hub Archway + Dungeon Portal presentation. Route **control and chunk descriptors exist**, but route render assets remain deliberately unmapped.
- Other Resources, WorldStructures, atmosphere, Terrain, NPC/vendor/quest, and asset-specific details remain outside active representation when complete current evidence is absent. Do not invent them merely to increase coverage.
- `AuthoredWorldRecoveryCoverageConfig` remains the admission boundary. Source admission and offline building do not equal runtime activation or acceptance verification.

## 2. NOW → NEXT → LATER

### NOW

**Advance Patch 0.5 from source-safe planning into the smallest evidence-backed visible expansion without bypassing BA-014 acceptance gates.**

The admitted hub core, stable semantic lookup, primary route control data, bounded route chunk descriptors, and held portal delegation path are complete. The next source increment should add only representation that can be derived from existing canonical contracts/production rules and remain independently removable/streamable.

Target chain:

```text
admitted hub evidence
→ dedicated source build
→ semantic/readability/authority contracts
→ primary-route control truth
→ bounded held route chunks
→ smallest source-managed route render representation
→ Studio streaming/readability/performance evidence
→ only then broader environment admission / activation
```

Rules:

- do not copy the recovered 189 `WorldPath` slabs into the dedicated place;
- route render representation must consume `route.world.primary` + `main_world.primary_route` chunk truth rather than making Instances authoritative again;
- stay within BA-013 route chunk authoring targets (64–128 studs, split earlier at semantic beats when justified);
- exact streaming radii, `ModelStreamingMode`, quality-tier behavior, and performance acceptance remain BA-014 measured concerns; do not guess them;
- preserve authored-overworld coordinates and recovered corridor width unless an evidence-backed representation contract explicitly changes presentation while retaining control truth;
- do not revive legacy bootstrap/services, duplicate remotes, or model-owned gameplay authority;
- keep canonical combat, inventory, progression, persistence, expedition, and networking owners in current repository source;
- do not guess Terrain voxels, missing asset IDs, NPC/vendor/quest behavior, global Lighting ownership, or teleport/session behavior;
- keep `WorldFoundationService` out of the dedicated Main World bootstrap;
- streamed-out presentation must never change consequential gameplay truth;
- keep the portal's recovered `[G]` text presentation-only; Main World portal delegation remains held until activation/transport gates are separately satisfied;
- keep Studio/device evidence pending until actually run.

### NEXT

1. define the smallest source-managed primary-route render representation that consumes the existing route/chunk contracts and does not resurrect 189 legacy slab Instances;
2. add parity/topology regression coverage proving route render chunks preserve control boundaries, corridor truth, stable semantic IDs, and removable presentation ownership;
3. map only that bounded route representation into the dedicated Main World after its source contract is green;
4. run Studio hub/route readability + streaming evidence when an actual Studio/device lane is available: arrival camera/readability, four-player clearance, traversal/dead travel, portal interaction visibility, stream-out/rebind, quality tiers, performance, memory, cleanup;
5. treat any reproducible BA-014 failure as FIX NOW before environmental breadth;
6. admit terrain, structures, props, foliage, lighting, VFX, and audio only through existing production-kit/budget and evidence rules;
7. define inter-place transport only after authorized published place IDs and transport/session policy exist;
8. activate/publish the dedicated Main World only after creation, authority, transport, streaming, performance, and acceptance gates are genuinely satisfied.

### LATER

- deeper Patch 0.5 environment breadth after the first bounded route representation and BA-014 evidence;
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

Patch 0.5's source flywheel is now:

```text
checksum-pinned evidence
→ stable semantic/control truth
→ bounded source representation
→ explicit ownership + streaming identity
→ deterministic regression coverage
→ reproducible dedicated-place build
→ measured Studio acceptance
→ gated activation / broader content
```

The one-time recovery cost has already been paid for the admitted civic core and WorldPath line. Do not repeatedly rediscover or re-import that geometry.

## 4. Studio/device evidence lane

For Patch 0.5, source admission, source-safe streaming contracts, route-control conversion, and reproducible offline builds do **not** substitute for the Main World acceptance matrix.

A representative Studio/device pass still needs to cover arrival camera/readability, four-player clearance, traversal/dead travel, interaction visibility, streaming continuity/rebind, route seams, quality tiers, representative performance, memory, and cleanup.

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
| **0.5 Main World** | **DEDICATED SOURCE BUILD + SOURCE-SAFE HUB/ROUTE CONTRACTS ESTABLISHED; VERIFICATION PENDING** | bounded route representation → BA-014 evidence → gated environment breadth/activation |
| 0.6 systemic replayability | future; do not start before coherent 0.5 Main World progress | combinatorial output from reusable systems |
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

Stop expansion and fix/report when continuing would knowingly build on unsafe or false assumptions, including client-authored consequential truth, valuable-state corruption/duplication, competing owners, known lifecycle failure, missing required canonical authority/evidence, irreversible unsafe migration, automated validation failure, or a representation decision that requires unmeasured BA-014 streaming/performance assumptions.

The former civic-property-evidence blocker, dedicated source-build gate, hub semantic/readability gate, WorldPath control-conversion gate, bounded route-chunk planning gate, and held portal-delegation gate are closed by the checksum-pinned 2026-08-10 intake and PRs #371/#377/#379/#380/#382/#383/#384/#385/#386/#387/#389/#390/#391/#392/#393.

Remaining incomplete world-property families are not permission to fabricate them. Unrun ordinary Studio/device/play-feel evidence alone is not a stop condition when dependency-safe source work remains.

> **Build continuously, route effects to one owner, make repeated variants cheaper, automate recurring friction, and stop only for real blockers.**
