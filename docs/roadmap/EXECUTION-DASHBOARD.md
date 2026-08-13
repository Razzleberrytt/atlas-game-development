# Atlas — Execution Dashboard v1.19

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-11  
**Purpose:** answer quickly: **what is true, what is NOW, what is NEXT, and how do we keep later development cheaper?**

For detailed acceptance use `PLAYABLE-MVP-PATCH-EXECUTION.md`. For long-range scope use `MASTER-ROADMAP.md`. `MVP-BUILD-THROUGH-TESTING-POLICY.md` controls cadence. Repeated families use `../production/EXTENSION-COST-MODEL.md`; reusable gameplay effects use `../production/EFFECT-OWNER-ROUTING.md`.

## 1. Current truth

- **MVP 0.1 source:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.2 combat/readability source pass:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.3 — Loot + Build Replayability source pass:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.4 — RPG Progression source pass:** **BUILT — VERIFICATION PENDING**.
- Studio/device/play/performance evidence remains a parallel lane; unrun evidence is not a source-development lock and is never called VERIFIED.
- **Patch 0.5 — Main World + Environment Expansion:** **DEDICATED SOURCE BUILD + BOUNDED PRIMARY ROUTE MAPPED — BA-014 VERIFICATION PENDING**.
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
- Source-safe review/streaming preparation is established:
  - PR #389 — machine-readable hub readability contract, stable `main_world.hub_core` streaming identity, and project/source-contract topology validation;
  - PR #390 — non-blocking semantic presentation resolver with explicit `Present` / `Missing` / `UnknownContentId` states and no `WaitForChild` dependency;
  - PR #391 — stable `route.world.primary` control truth replacing 189 recovered WorldPath slab Instances as route authority;
  - PR #392 — BA-013-aligned `main_world.primary_route` chunk descriptors, deterministically covering the route in 12 bounded 64–128 stud chunks;
  - PR #393 — held Main World expedition-portal delegation contract proving the authored surface delegates to canonical `ExpeditionLobbyService` while owning no eligibility, transport, join/ready/launch grant, or consequential mutation;
  - PR #395 — follow-up canonical identity/intent enforcement for that held delegation path, rejecting drifted anchor IDs, bridge state, content, intent, or launch owner.
- The first bounded primary-route representation is now source-managed and mapped:
  - PR #396 — `MainWorldPrimaryRouteRenderConfig` plus a 12-Part model derived from route-control/chunk truth and exact recovered WorldPath surface style, with parity/topology regression coverage and no legacy slab resurrection;
  - PR #397 — maps that validated model only at `Workspace/LivingKingdomsMainWorld/Routes/PrimaryRoute`, while keeping runtime activation, place IDs, exact streaming radii, `ModelStreamingMode`, quality-tier behavior, and BA-014 acceptance evidence unset/pending.
- The BA-014 run is now executable rather than only defined:
  - PR #399 — operator runbook turning the 31-check definition into a repeatable Studio sequence, recording no outcome;
  - PR #400 — placement parity: BA-011 named a `Routes/Primary` container the built place does not contain, while the project and render contract both map `Routes/PrimaryRoute`. Declared placement is now bound to the dedicated project by fixture in both directions, and each streaming group carries an explicit `projectMappingStatus`;
  - PR #401 — `MainWorldAcceptanceScopeResolver` derives which checks the mapped build can actually answer: **10 in scope (7 blocking), 21 out of scope** on `resources`/`structures`/`atmosphere` content the place does not contain. A scoped pass authorizes nothing; the full matrix keeps its own gate;
  - PR #403 — repaired `scripts/efficiency.py audit`, which died with `UnicodeEncodeError` on Windows before printing its findings, and stopped six sibling CLIs mangling their output;
  - PR #404 — `MainWorldBa014RunEvaluator` plus `evaluate-ba014-run.luau` decide a recorded run as INVALID/PARTIAL/FAIL/PASS through the committed contracts, generate the blank run record for the current scope, and keep reporting `activationAcceptable` from the full matrix so a scoped pass cannot read as acceptance.
- **The BA-014 source chain is complete.** Definition → derived scope → operator runbook → generated run record → mechanical verdict all exist and are regression-covered. What remains is the Studio run itself, against the exact built artifact.
- **A presentation content-factory capability landed in PRs #407–#438** (24 PRs) and is source-prepared, presentation-only, and gated:
  - four ingestion boundaries specified — `environment-asset-kit-registry`, `weapon-visual-skin-content-factory`, `enemy-horror-presentation-factory`, `crafting-visual-content-factory`;
  - **32 registered environment assets** across four registry waves and 10 families (Rock, DeadTree, Root, Brush, GroundClutter, Cave, Camp, Structure, Industrial, Prop), plus 8 weapon skin rows, 6 enemy horror role profiles, and 8 crafting presentation rows;
  - **44 source model definitions** under 26 manifests (29 world, 6 enemy, 5 crafting, 4 gathering);
  - fixture count rose 306 → **335**.
  - No `src/` runtime owner consumes these registries — they are an ingestion boundary, not a second gameplay system, and the authority audits fail closed on any row declaring a gameplay owner. This is the intended state, not an omission.
- **That content does not widen BA-014 scope.** All 32 environment assets declare `main_world.resources` (18) or `main_world.structures` (14), and both groups remain `projectMappingStatus = "Unmapped"`. Re-deriving the scope on `00ddba5` still yields **10 in scope (7 blocking), 21 out of scope**. The content needed for the next families now exists in source; the *mapping decision* is what stays gated behind the hub/route pass.
- **First BA-014 run attempt, 2026-08-11: `PARTIAL` — blocked at preflight on place identity.** Preflight steps 1–5 passed (validation green at 335 fixtures; artifact `MainWorld-BA014.rbxlx`, SHA-256 `564b31cb…`, 1,026,674 bytes, from commit `00ddba5`). Step 7 failed: the connected Studio instance exposes a different place, with no `workspace.LivingKingdomsMainWorld`. All 10 in-scope checks recorded `Blocked`; the evaluator returned `PARTIAL` (not `FAIL` — a bridge failure is not a runtime defect) and `activationAcceptable: false`. See [`../production/evidence/2026-08-11-ba014-preflight-place-identity-blocked.md`](../production/evidence/2026-08-11-ba014-preflight-place-identity-blocked.md).
- The place the bridge exposes is a **deliberately divergent local work stream** holding Studio-Assistant-authored biome content, which the repository owner intends to combine with the GitHub version later. It is not a stale copy of the artifact and must not be treated as one, nor used as a substitute observation source.
- The dedicated build therefore contains the exact admitted arrival + Central Fountain + Grand Staircase + Hub Archway + Dungeon Portal presentation **plus the bounded 12-Part primary route**. The 189 recovered `WorldPath` slabs remain non-authoritative and unmapped.
- Other Resources, WorldStructures, atmosphere, Terrain, NPC/vendor/quest, and asset-specific details remain outside active representation when complete current evidence is absent. Do not invent them merely to increase coverage.
- `AuthoredWorldRecoveryCoverageConfig` remains the admission boundary. Source admission, offline building, and source mapping do not equal runtime activation or acceptance verification.

## 2. NOW → NEXT → LATER

### NOW

**Run or capture the first BA-014 Main World hub/route acceptance evidence on the currently mapped bounded representation; fix concrete failures before adding environmental breadth.**

The repository-first source chain is complete through a reproducible dedicated build containing the admitted hub core and a 12-Part primary route representation derived from canonical route/chunk contracts. The next material truth is measured engine/device behavior, not another guessed streaming or environment parameter.

The first run is a **10-check scoped pass**, not a 31-check pass. Derive the worklist from source rather than from prose — `MainWorldAcceptanceScopeResolver.resolveScope(matrix, MainWorldRepresentationConfig.mappedStreamingGroupIds())` — and use [`../validation/MAIN-WORLD-BA-014-STUDIO-RUNBOOK.md`](../validation/MAIN-WORLD-BA-014-STUDIO-RUNBOOK.md) as the operator sequence. Record results only for in-scope checks; a scoped run that records an out-of-scope result is rejected. Satisfying the scope does **not** promote Patch 0.5 to VERIFIED — it clears the mapped hub/route for the next environment family, and full acceptance stays gated until the remaining families are mapped and their checks recorded.

Record the run and let the contracts decide it — do not decide acceptance by reading the sheet:

```bash
lune run games/living-kingdoms/tools/evidence/evaluate-ba014-run.luau > run-record.json   # blank, current scope
lune run games/living-kingdoms/tools/evidence/evaluate-ba014-run.luau run-record.json     # verdict
```

No BA-014 check has yet been executed. The 2026-08-11 attempt reached Studio but stopped at preflight because the bridge exposed a different place, so every check is `Blocked` rather than `NotRun` and the gate is unchanged.

**The blocker is now narrower and concretely actionable.** It is no longer "no Studio/device lane exists" — a lane exists and the tooling works end-to-end. The remaining requirement is that the exact artifact be the place the bridge observes:

```text
build main-world.project.json  →  open THAT artifact in Studio
→ confirm workspace.LivingKingdomsMainWorld is present
→ resume runbook §5 from step 2  →  new evidence packet
```

**Dependency-safe source preparation for this gate remains exhausted.** The definition, derived scope, runbook, run-record generation, and mechanical verdict all exist, are regression-covered, and have now been exercised end-to-end on a real attempt. Further preparation would require guessing BA-014 measurements or instrumenting a runtime that is deliberately held.

Target chain:

```text
admitted hub evidence
→ dedicated source build
→ semantic/readability/authority contracts
→ primary-route control truth
→ bounded route chunks
→ validated 12-Part source-managed route representation
→ dedicated Main World mapping
→ Studio streaming/readability/performance evidence
→ fix failures if any
→ only then broader environment admission / activation
```

Rules:

- do not copy the recovered 189 `WorldPath` slabs into the dedicated place;
- keep route truth in `route.world.primary` + `main_world.primary_route`; mapped Parts remain removable presentation, not gameplay authority;
- preserve the BA-013 64–128 stud chunk authoring contract unless measured evidence justifies a source-contract change;
- exact streaming radii, `ModelStreamingMode`, quality-tier behavior, and performance acceptance remain BA-014 measured concerns; do not guess them;
- preserve authored-overworld coordinates and recovered corridor width unless an evidence-backed representation contract explicitly changes presentation while retaining control truth;
- do not revive legacy bootstrap/services, duplicate remotes, or model-owned gameplay authority;
- keep canonical combat, inventory, progression, persistence, expedition, and networking owners in current repository source;
- do not guess Terrain voxels, missing asset IDs, NPC/vendor/quest behavior, global Lighting ownership, or teleport/session behavior;
- keep `WorldFoundationService` out of the dedicated Main World bootstrap;
- streamed-out presentation must never change consequential gameplay truth;
- keep the portal's recovered `[G]` text presentation-only; Main World portal delegation remains held until activation/transport gates are separately satisfied;
- do not call Patch 0.5 VERIFIED until the required Studio/device evidence has actually passed.

### NEXT

1. run Studio hub/route readability + streaming evidence on the mapped dedicated build when an actual Studio/device lane is available: arrival camera/readability, four-player clearance, traversal/dead travel, portal interaction visibility, route seams, stream-out/rebind, quality tiers, performance, memory, cleanup;
2. treat any reproducible BA-014 failure as FIX NOW and repair the smallest source-owned cause before adding environmental breadth;
3. if BA-014 evidence passes, admit the next smallest evidence-backed environment family through `AuthoredWorldRecoveryCoverageConfig` and existing production-kit/budget rules rather than importing the recovered whole world — the registered kit content for `main_world.resources` and `main_world.structures` already exists in source, so this is a bounded mapping decision, not new content authoring. Admitting a group flips its `projectMappingStatus` and automatically widens the derived scope, adding its checks to the next run's worklist;
4. keep every newly admitted presentation family semantic-ID/addressable and safe when locally absent under streaming;
5. define inter-place transport only after authorized published place IDs and transport/session policy exist;
6. activate/publish the dedicated Main World only after creation, authority, transport, streaming, performance, and acceptance gates are genuinely satisfied.

When no Studio/device lane is available, dependency-safe source preparation may continue only when it does **not** require guessing BA-014 measurements or bypassing the evidence gate. Broader Main World representation expansion is held until the first mapped hub/route evidence pass is known.

### LATER

- deeper Patch 0.5 environment breadth after the mapped hub/route representation clears BA-014 evidence;
- Patch 0.6 ranks 98-100 (variation HUD/recap), held for a Studio/UX pass;
- further Patch 0.7 persistence hardening;
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

For Patch 0.5, source admission, source-safe streaming contracts, route-control conversion, the mapped 12-Part route representation, and reproducible offline builds do **not** substitute for the Main World acceptance matrix.

A representative Studio/device pass still needs to cover arrival camera/readability, four-player clearance, traversal/dead travel, interaction visibility, streaming continuity/rebind, route seams, quality tiers, representative performance, memory, and cleanup.

- **pass:** promote applicable BUILT — VERIFICATION PENDING work to VERIFIED and allow the next evidence-backed Patch 0.5 breadth increment;
- **reproducible failure:** make the concrete FIX NOW and preempt expansion;
- **not run:** preserve pending-evidence truth; continue only dependency-safe source preparation that does not require invented BA-014 measurements.

## 5. Planning snapshot

| Area | Status truth | Compounding target |
|---|---|---|
| Foundation / architecture | mature | stable owners + machine-readable routing + low rediscovery |
| MVP 0.1 | BUILT — VERIFICATION PENDING | regression-protected baseline |
| 0.2 combat/readability | BUILT — VERIFICATION PENDING | reusable feedback/reaction contracts |
| 0.3 loot/builds | BUILT — VERIFICATION PENDING | affix/effect/reward variants are data-first |
| 0.4 RPG progression | BUILT — VERIFICATION PENDING | bounded rank map + generic entitlement/presentation + reusable owner adapters |
| **0.5 Main World** | **BA-014 SOURCE CHAIN COMPLETE AND EXERCISED; NO CHECK EXECUTED — first run `PARTIAL`, BLOCKED on the bridge observing the exact built artifact** | measured hub/route evidence → fix failures → gated environment breadth/activation |
| Presentation content factory | SOURCE-PREPARED, PRESENTATION-ONLY (32 env assets / 44 source models / 4 boundaries) | registry+model data, no runtime owner; admission still gated by BA-014 |
| 0.6 systemic replayability | BUILT — VERIFICATION PENDING; the 100-item micro-update backlog is complete through rank 97, ranks 98-100 remain GATED on Studio/UX | combinatorial output from reusable systems |
| 0.7 persistence | BUILT — VERIFICATION PENDING for the session lifecycle: single owner, symmetric release, lease decided from the committed update, migration/recovery invariants locked across the supported schema matrix | remaining: durable state beyond inventory, and live multi-server evidence |
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

The former civic-property-evidence blocker, dedicated source-build gate, hub semantic/readability gate, WorldPath control-conversion gate, bounded route-chunk planning gate, held portal-delegation gate, bounded route-source gate, dedicated route-mapping gate, and BA-014 run-scoping gate are closed by the checksum-pinned 2026-08-10 intake and PRs #371/#377/#379/#380/#382/#383/#384/#385/#386/#387/#389/#390/#391/#392/#393/#395/#396/#397/#399/#400/#401.

The current breadth gate is measured BA-014 behavior of the mapped hub/route build. Remaining incomplete world-property families are not permission to fabricate them. Unrun ordinary Studio/device/play-feel evidence alone is not a stop condition when dependency-safe source preparation remains, but it **is** a gate against broader representation choices that would require guessing streaming/readability/performance behavior.

> **Build continuously, route effects to one owner, make repeated variants cheaper, automate recurring friction, and stop only for real blockers.**
