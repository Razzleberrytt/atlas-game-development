# Atlas — Execution Dashboard v1.8

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
- PR #343 routes equipped durable `ReloadSpeedPercent` through the existing server-owned reload authority with full automated validation green: **BUILT — VERIFICATION PENDING** until ordinary Studio/device evidence is run.
- PR #344 routes equipped Armor `MaxHealthPercent` through `OperativeLifeService` with ratio-preserving equip/unequip reconciliation, bounded variable-max life validation, replay/reconnect protection, and full automated validation green: **BUILT — VERIFICATION PENDING** until ordinary Studio/device evidence is run.
- PR #345 routes equipped Armor `MoveSpeedPercent` through the existing server-owned `OperativeLifeService` locomotion application, derives speed from the stable bound base to prevent compounding, preserves hard-zero incapacitated/dead movement, and passed full automated validation: **BUILT — VERIFICATION PENDING** until ordinary Studio/device evidence is run.
- `DamagePercent`, `ReloadSpeedPercent`, `MaxHealthPercent`, and `MoveSpeedPercent` are now live effect-owner routes; same-family variants should be data/config plus focused regression rather than bespoke runtime wiring.
- The effect-owner routing registry prevents affix effect vocabulary from existing without an explicit authority-routing state.
- Verification truth remains strict: pending manual/engine evidence is never called VERIFIED.

## 2. NOW → NEXT → LATER

### NOW

**Resolve and route `AbilityHastePercent` through the canonical server-owned class-action cooldown path without creating a parallel ability timer.**

Start with:

```bash
python scripts/effect_routes.py show AbilityHastePercent
```

Current ownership evidence:

```text
authoritative equipped durable item
→ slot-aware durable-equipment modifier fact
→ existing server composition seam
→ ClassService-owned authoritative class action state
→ pure class action resolvers compute cooldownEndServerTimestamp
```

`ClassService` is the leading canonical owner because it owns action lifecycle/state and server timestamps. `FieldTreatmentResolver`, `FieldResupplyResolver`, and `BraceResolver` currently derive cooldown deadlines from server-authored config. Confirm the narrowest shared timing seam before wiring haste so one modifier applies consistently without duplicating cooldown authority.

Rules:

- cooldown legality and timestamps remain server-owned;
- no client-provided cooldown, haste value, duration, or completion timestamp;
- reuse authoritative equipped-item selection and the existing server composition seam;
- use one bounded cooldown-duration multiplier shared by all eligible class actions rather than per-action bespoke affix math;
- derive modified cooldown from the configured base duration, never from an already-modified deadline;
- malformed/legacy/no-affix equipment remains neutral;
- preserve action resource costs, targeting, channel requirements, cancel rules, and effect commit authority;
- add focused resolver + integration regression coverage;
- after successful wiring, promote `AbilityHastePercent` from `unresolved` to `live` and name the canonical owner/tests.

### NEXT

1. resolve and route `AbilityPowerPercent` through the canonical server-owned ability-consequence path;
2. expand affix/reward variety primarily through validated definitions once effect routes are live;
3. add end-to-end regression coverage across generation → reward → inventory → equip → application → replay/persistence;
4. continue into Patch 0.4 when Patch 0.3 source is coherent, keeping Studio evidence pending rather than inventing a lock.

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
