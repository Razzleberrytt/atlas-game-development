# Atlas — Execution Dashboard v1.7

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-10  
**Purpose:** answer quickly: **what is true, what is NOW, what is NEXT, and how do we keep later development cheaper?**

For detailed acceptance use `PLAYABLE-MVP-PATCH-EXECUTION.md`. For long-range scope use `MASTER-ROADMAP.md`. `MVP-BUILD-THROUGH-TESTING-POLICY.md` controls cadence. Repeated families use `../production/EXTENSION-COST-MODEL.md`; reusable gameplay effects use `../production/EFFECT-OWNER-ROUTING.md`.

## 1. Current truth

- **MVP 0.1 source:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.2 combat/readability source pass:** **BUILT — VERIFICATION PENDING**.
- Studio/device play/performance evidence remains a parallel lane; unrun evidence is not a source-development lock.
- **Patch 0.3 — Loot + Build Replayability:** **BUILDING**.
- PR #330 established deterministic data-driven equipment affixes.
- PR #332 carried affix rolls through reward/result/inventory/persistence.
- PR #333 added deterministic affix comparison facts.
- PR #334 added bounded pure affix modifier translation.
- PR #335 added affix-aware durable gear comparison/presentation.
- PR #337 wired equipped durable `DamagePercent` through the existing server-owned damage authority with full validation green.
- `ReloadSpeedPercent` is now **live**: the shared affix adapter translates it into the canonical `reloadDurationReduction` contribution, `RelicModifierService` composes it per operative, and `ReloadResolver` bakes it into the authoritative completion timestamp inside the existing 0.5 reload floor. No equipment reload service was created.
- The effect-owner routing registry now prevents affix effect vocabulary from existing without an explicit authority-routing state.
- Verification truth remains strict: pending manual/engine evidence is never called VERIFIED.

## 2. NOW → NEXT → LATER

### NOW

**Resolve and register the canonical server owner for `MaxHealthPercent`, then route it.**

Start with:

```bash
python scripts/effect_routes.py next
python scripts/effect_routes.py show MaxHealthPercent
```

Owner discovery is the task — the route is `unresolved`, so the existing authoritative maximum-health owner must be identified and registered before any consequence is implemented.

Desired architecture (mirroring the two live routes):

```text
authoritative equipped durable item
→ existing equipment modifier composition seam
→ the shared bounded affix adapter
→ the canonical server life owner
→ existing server-owned health state
```

Rules:

- no equipment-specific health service;
- never write a Humanoid's health from an affix adapter;
- no client-provided multiplier or health value;
- legacy/no-affix gear remains neutral;
- equip changes must affect the authoritative source;
- after successful wiring, promote the route to `live` and name focused tests.

### NEXT

1. use `python scripts/effect_routes.py next` to select the next owner-confirmed/unresolved reusable effect rather than rediscovering architecture;
2. resolve canonical owners for `MoveSpeedPercent`, `AbilityHastePercent`, and `AbilityPowerPercent` before live implementation;
3. expand affix/reward variety primarily through validated definitions once effect routes are live;
4. add end-to-end regression coverage across generation → reward → inventory → equip → application → replay/persistence;
5. continue into Patch 0.4 when Patch 0.3 source is coherent, keeping Studio evidence pending rather than inventing a lock.

### LATER

- Patch 0.4 RPG progression;
- Patch 0.5 Main World/environment;
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
- an effect marked `live` should not require repeated bespoke runtime wiring;
- an effect marked `unresolved` must have its canonical server owner identified before implementation;
- if the third variant still needs bespoke wiring, improve the seam before scaling breadth;
- repeated budget overruns are engineering friction, not a normal cost of growth;
- genuine new semantics may exceed budgets—explain/escalate instead of hiding complexity.

**North-star engineering metric:** declining marginal implementation cost for proven feature families.

Patch 0.3 reusable layers:

```text
authored affix data
→ deterministic affix/comparison/modifier facts
→ effect-owner route
→ existing gameplay/presentation owner
```

## 4. Studio/device evidence lane

The consolidated pass should cover the representative run, replay, keyboard/controller/touch, combat feel/readability, banking/equip, lifecycle, build-choice readability, and representative performance.

- **pass:** promote applicable BUILT — VERIFICATION PENDING work to VERIFIED;
- **reproducible failure:** make the concrete FIX NOW and preempt expansion;
- **not run:** continue dependency-safe source work while preserving pending-evidence truth.

## 5. Planning snapshot

| Area | Status truth | Compounding target |
|---|---|---|
| Foundation / architecture | mature | stable owners + machine-readable routing + low rediscovery |
| MVP 0.1 | BUILT — VERIFICATION PENDING | regression-protected baseline |
| 0.2 combat/readability | BUILT — VERIFICATION PENDING | reusable feedback/reaction contracts |
| **0.3 loot/builds** | **NOW — BUILDING** | affix/effect/reward variants become data-first |
| 0.4 RPG progression | foundations present | reuse effect/reward/progression owners |
| 0.5 Main World | preparation partial | stable IDs + registry-driven interactions |
| 0.6 systemic replayability | foundations present | combinatorial output from reusable systems |
| 0.7 persistence | substantial foundations | migration/lifecycle invariants and recovery tests |
| 0.8 co-op/social | basic foundations | multiplayer coverage over existing owners |
| 0.9 content/pipeline | preparation present | mostly data/content + validation |
| RC 1.0 | future | accumulated automation reduces hardening cost |

## 6. Agent task algorithm

When asked to continue:

1. fetch current `main`;
2. inspect open PRs;
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
