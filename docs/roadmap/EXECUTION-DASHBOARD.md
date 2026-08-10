# Atlas — Execution Dashboard v1.11

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
- Patch 0.3 has live canonical routes for all six current durable effect families: `DamagePercent`, `ReloadSpeedPercent`, `MaxHealthPercent`, `MoveSpeedPercent`, `AbilityHastePercent`, and `AbilityPowerPercent`.
- PR #350 proved the compounding seam by expanding the authored affix pool from 8 to 16 with only config + pure fixture changes and **zero server-authority changes**.
- PR #351 added a composed end-to-end durable affix lifecycle regression proving representative Weapon, Armor, and Relic effects survive deterministic generation → banked durable reward → inventory reconstruction → equipped-slot resolution → live modifier facts after reconnect reconstruction. Full validation and the reproducible build are green.
- PR #352 established the bounded durable Operative Rank map: Initiate → Delver → Pathfinder → Veteran → Vanguard at 0/1/3/6/10 completed expeditions. Rank is derived from already-persisted canonical Boss reward grant identities, so no second DataStore/schema/player-load owner was introduced.
- PR #353 wired a read-only owner-bound Operative Rank runtime through the existing loaded inventory record. The client can request only its own server-derived snapshot; there is no durable-progression mutation RemoteEvent.
- PR #354 surfaced current durable rank, lifetime expedition clears, and clears-to-next-rank inside the existing Character menu.
- PR #356 converted the paused Skills surface into a durable progression map backed by `OperativeProgressionConfig`, while preserving the old temporary run-upgrade topology as run-only authority. Full validation and reproducible build are green; visual/device verification remains pending.
- PR #357 proved the first live personal durable-unlock seam: Rank 2 `Rally Ping` is authored in durable progression, derived server-side from existing durable rank, routed through `SquadPingService`, and cannot be claimed by client intent. No new persistence owner was added.
- PR #360 added Rank 2 `Dual Tactical Markers`: baseline personal capacity remains one, earned capacity becomes two, the squad hard cap remains four, and the existing server ping owner derives eligibility. The second progression unlock reused the established rank/unlock seam without another persistence or network owner.
- PR #362 added Rank 3 `Focused Beam`, proving the same durable unlock seam reaches `PersonalFlashlightService` and `GameplayLightingService` without another persistence owner, remote, or client-authored entitlement.
- PR #363 added Rank 4 `Self-Treatment`, the first ability side-grade: an eligible Medic may spend the existing medical charge on themselves while heal amount, range, channel, cooldown, injury requirement, and interruption rules remain unchanged.
- PR #364 centralized the durable entitlement rule in `OperativeProgressionResolver`, disclosed per-unlock earned state through the owner-bound snapshot, and made the existing RPG progression map render generic `[EARNED]` / `[LOCKED]` state without per-unlock presentation rewrites.
- PR #365 added Rank 5 `Persistent Markers`: earned owners receive a bounded 9-second server-owned marker lifetime versus the 6-second baseline. The third durable variant in `SquadPingService` also consolidated the family's repeated entitlement plumbing behind one fail-closed owner adapter. Full validation and reproducible build are green.
- The Patch 0.4 source map is deliberately small and testable rather than a giant skill tree: five durable unlocks span ranks 2–5 and three existing server consequence owners (`SquadPingService`, `PersonalFlashlightService`, `ClassService`) without permanent raw combat-stat inflation or a second save owner.
- Existing `RunProgressionService` remains explicitly **run-only** shared Field XP + temporary upgrades. Durable Operative Rank does not author those facts.
- The four non-pistol firearms remain intentionally authored as rare in-run discoveries; durable progression has not erased that discovery loop.
- PR #366 repaired the BA-010 expedition-environment lifecycle debt by retaining the controller's Workspace child listeners and disconnecting them on `stop()`. Focused regression coverage now prevents anonymous listener reintroduction; full validation and reproducible build are green.
- **Patch 0.5 — Main World + Environment Expansion:** **BUILDING**.
- BA-010 through BA-014 already define the Main World audit, dedicated-place/source boundary, stable interaction registry, production kits/budgets, and unrun acceptance matrix. These are authority and evidence inputs, not permission to dump or activate the recovered world.
- `MainWorldRepresentationConfig` holds the dedicated Main World boundary, 1:1 authored coordinates, semantic streaming groups, and arrival/return anchor policy. `AuthoredWorldRecoveryCoverageConfig` remains the geometry-admission gate: incomplete evidence cannot be promoted into new geometry.

## 2. NOW → NEXT → LATER

### NOW

**Admit the first coherent `main_world.hub_core` civic review unit from complete evidence — without activating Main World runtime.**

The highest-value first target is the compact arrival/orientation/adventure-gate composition identified by BA-010/BA-013. The arrival anchor and DungeonPortal already have bounded held contracts, but the civic orientation candidates (Central Fountain, Grand Staircase, Hub Archway) do not yet have a complete promoted reconstruction contract. The first source increment should therefore close evidence/admission for **one** coherent civic landmark, preferring Central Fountain when the canonical RBXL evidence supports it.

Target chain:

```text
canonical checksum-pinned RBXL
→ complete supported-property evidence for one coherent HubTown civic group
→ stable main_world.hub_core review-unit identity
→ held source representation + property-parity regression
→ reviewable model asset only after evidence admits it
→ dedicated Main World mapping/bootstrap only after the existing creation gate is satisfied
```

Rules:

- do not create or activate the dedicated Main World project merely to make progress; its creation gate still requires reviewable content plus an explicit bootstrap allowlist and reproducible build check;
- do not map held content into the current operation project or parent recovered content under `LivingKingdomsWorld`;
- preserve authored-overworld coordinates 1:1; no global translation, rotation, or scale to fit the operation forest;
- do not guess Terrain voxels, missing properties, asset IDs, NPC/vendor/quest authority, teleport policy, or legacy gameplay behavior;
- keep `WorldFoundationService` operation-world generation out of the future Main World bootstrap;
- use stable semantic IDs and semantic streaming groups so gameplay/presentation truth survives a locally absent Instance;
- a review unit must be coherent and bounded; never restore all 1,775 recovered rows or the whole `HubTown` / `WorldStructures` root as one production unit;
- keep the existing Forward Operations Hub as the temporary bridge until the authored arrival/preparation/launch/return loop is actually accepted;
- keep Studio/device/streaming/performance evidence pending until BA-014 is run against a real representative build.

### NEXT

1. after the first civic review unit passes property parity, preview the held arrival + orientation landmark + expedition-gate composition without runtime activation;
2. establish the authored Main World return/debrief anchor and cold-join/success/failure/replay re-entry semantics before activation;
3. create the dedicated Main World Rojo project only when the existing gate is satisfied: first property-validated coherent model group + explicit server/client bootstrap allowlists + reproducible offline build;
4. expand `main_world.hub_core` through stable-ID interaction/service forms, preserving canonical class/loadout/inventory/progression/expedition owners rather than recreating state in world objects;
5. replace recovered `WorldPath` slabs with stable route/control data and bounded 64–128-stud render chunks after the hub core is readable;
6. admit terrain, structures, props, foliage, lighting, VFX, and audio only through the BA-013 kit/budget rules and BA-014 evidence matrix;
7. retain the consolidated Studio/device/play-feel evidence lane for Patch 0.1–0.4 while Patch 0.5 source-safe preparation continues.

Rejected shortcuts remain:

- copying the recovered whole world into the active operation place;
- treating recovered hierarchy counts, lights, particles, or 189 path slabs as a production budget/interface;
- creating a second gameplay owner inside reconstructed vendors, quest boards, portal models, NPCs, or prompts;
- inventing Terrain, asset IDs, global Lighting ownership, teleport/session behavior, or streaming radii without their required evidence/authority;
- marking Main World VERIFIED from source-only reconstruction or screenshots without the BA-014 device/traversal/streaming/performance evidence.

### LATER

- deeper Patch 0.5 Main World environment breadth after the hub core is accepted;
- Patch 0.6 systemic replayability;
- Patch 0.7 persistence hardening;
- Patch 0.8 co-op/social/session;
- Patch 0.9 content/pipeline expansion;
- release-candidate hardening.

### WIP limit

- one active implementation PR for the current capability;
- at most one additional non-overlapping feature PR only when the first is externally blocked;
- never duplicate an existing open PR.

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

The two controls answer different questions:

```text
effect route → where the semantic belongs
extension contract → how expensive another family member should be
```

Rules:

- data-first variants should normally touch zero server-authority files;
- a live effect should not require repeated bespoke runtime wiring;
- unresolved effects require a canonical server owner before implementation;
- if the third variant still needs bespoke wiring, improve the seam before scaling breadth;
- repeated budget overruns are engineering friction, not a normal cost of growth;
- genuine new semantics may exceed budgets—explain/escalate instead of hiding complexity.

**North-star engineering metric:** declining marginal implementation cost for proven feature families.

Patch 0.4 closed with these reusable layers:

```text
banked completed-expedition facts already owned by durable inventory
→ pure bounded Operative Rank resolver
→ owner-bound read-only progression snapshot + generic unlock eligibility
→ existing data-driven RPG progression-map presentation
→ server-owned personal unlock consequence adapters
→ authored unlock breadth without another save owner
```

The same seam now spans three consequence owners, and the third squad-ping variant consolidated its repeated entitlement plumbing rather than copying it again.

Patch 0.5 should compound around a different family:

```text
checksum-pinned recovered evidence
→ bounded coherent review unit
→ stable semantic ID + streaming group
→ deterministic property-parity validation
→ held source-managed representation
→ reusable reconstruction/admission path
→ later place mapping only after explicit gates
```

The first admitted hub-core unit should make the **second** coherent unit cheaper. If each landmark needs a bespoke extraction/reconstruction ritual, improve the evidence/admission seam before scaling breadth.

## 4. Studio/device evidence lane

The consolidated pass should cover the representative run, replay, keyboard/controller/touch, combat feel/readability, banking/equip, lifecycle, build-choice readability, durable rank/progression presentation, Rally/marker readability, and representative performance.

For Patch 0.5, source admission and held reconstruction do **not** substitute for the BA-014 Main World matrix. When a representative Main World build exists, BA-014 must cover arrival camera/readability, four-player clearance, traversal/dead travel, interaction visibility, streaming continuity/rebind, quality tiers, performance, memory, and cleanup.

- **pass:** promote applicable BUILT — VERIFICATION PENDING work to VERIFIED;
- **reproducible failure:** make the concrete FIX NOW and preempt expansion;
- **not run:** continue dependency-safe source work while preserving pending-evidence truth.

## 5. Planning snapshot

| Area | Status truth | Compounding target |
|---|---|---|
| Foundation / architecture | mature | stable owners + machine-readable routing + low rediscovery |
| MVP 0.1 | BUILT — VERIFICATION PENDING | regression-protected baseline |
| 0.2 combat/readability | BUILT — VERIFICATION PENDING | reusable feedback/reaction contracts |
| 0.3 loot/builds | BUILT — VERIFICATION PENDING | affix/effect/reward variants are data-first |
| 0.4 RPG progression | BUILT — VERIFICATION PENDING | bounded rank map + generic entitlement/presentation + reusable owner adapters |
| **0.5 Main World** | **NOW — BUILDING** | evidence → stable IDs → bounded review units → reusable admission/reconstruction |
| 0.6 systemic replayability | foundations present | combinatorial output from reusable systems |
| 0.7 persistence | substantial foundations | migration/lifecycle invariants and recovery tests |
| 0.8 co-op/social | basic foundations | multiplayer coverage over existing owners |
| 0.9 content/pipeline | preparation present | mostly data/content + validation |
| RC 1.0 | future | accumulated automation reduces hardening cost |

## 6. Agent task algorithm

When asked to continue:

1. fetch current `main`;
2. inspect open PRs and same-capability branches;
3. read NOW/NEXT;
4. fix concrete safety/authority/data/runtime/validation failures first;
5. otherwise implement the smallest coherent NOW increment;
6. inspect effect-owner route when wiring reusable gameplay semantics;
7. use extension contract when extending a repeated family;
8. prefer existing owners + data/configuration over copied services/controllers/remotes;
9. add focused regression defense;
10. run the matching validation profile;
11. merge successful dependency-safe work;
12. keep manual evidence pending when not run;
13. continue until a real blocker or exhausted roadmap exists.

## 7. Real stop conditions

Stop expansion and fix when continuing would knowingly build on unsafe/false assumptions, including client-authored consequential truth, valuable-state corruption/duplication, competing owners, known lifecycle failure, missing required canonical authority, irreversible unsafe migration, or automated validation failure.

Unrun ordinary Studio/device/play-feel evidence alone is not a stop condition.

> **Build continuously, route effects to one owner, make repeated variants cheaper, automate recurring friction, and stop only for real blockers.**
