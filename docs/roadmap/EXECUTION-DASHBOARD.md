# Atlas — Execution Dashboard v1.6

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-09  
**Purpose:** answer quickly: **what is true, what is NOW, what is NEXT, and how do we keep later development cheaper?**

For detailed acceptance use `PLAYABLE-MVP-PATCH-EXECUTION.md`. For long-range scope use `MASTER-ROADMAP.md`. `MVP-BUILD-THROUGH-TESTING-POLICY.md` controls cadence. Repeated feature/content families use `../production/EXTENSION-COST-MODEL.md`.

## 1. Current truth

- **MVP 0.1 source:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.2 combat/readability source pass:** **BUILT — VERIFICATION PENDING**.
- Studio/device play/performance evidence remains a parallel lane; unrun evidence is not a source-development lock.
- **Patch 0.3 — Loot + Build Replayability:** **BUILDING**.
- PR #330 established deterministic, validated, data-driven equipment affixes.
- PR #332 carried affix rolls through the retained reward/result/inventory/persistence path.
- PR #333 added deterministic comparison facts including affix gains/losses.
- PR #334 added a bounded pure `DamagePercent` → canonical damage-modifier adapter; it is not yet wired into live damage authority.
- PR #335 adds affix-aware build-choice presentation to the existing durable RPG inventory and makes sanitized inventory views share the same comparison path as reward records.
- Verification truth remains strict: pending manual/engine evidence is never called VERIFIED.

## 2. NOW → NEXT → LATER

### NOW

**Apply equipped durable `DamagePercent` affixes through the existing server-owned combat damage path using the shared bounded modifier adapter from PR #334.**

Desired architecture:

```text
existing durable inventory/equip owner
→ equipped item affix facts
→ EquipmentAffixModifierResolver
→ existing canonical player damage calculation
→ existing server-owned damage consequence
```

Rules for this slice:

- do not create per-weapon affix services;
- do not let the client submit affix values or damage multipliers;
- do not create a second damage authority;
- resolve the currently equipped authoritative item on the server;
- legacy/no-affix gear remains neutral;
- preserve the canonical global modifier ceiling;
- add a regression path proving equip changes affect the modifier source without bypassing combat authority.

### NEXT

1. wire additional affix effects only through their existing canonical owners as those seams are identified (`ReloadSpeedPercent`, health, movement, ability effects);
2. keep the shared affix resolver/adapter vocabulary generic so later affix variants remain mostly configuration;
3. expand reward/build variety primarily through validated equipment/affix definitions rather than new services;
4. improve reward reveal/comparison presentation using the same shared build-choice formatter where useful;
5. protect generation, ownership, equip/application, replay, and persistence boundaries with focused regression coverage;
6. continue into Patch 0.4 when Patch 0.3 source is coherently built, while keeping manual evidence pending rather than inventing a lock.

### LATER

- Patch 0.4 RPG progression;
- Patch 0.5 Main World/environment;
- Patch 0.6 systemic replayability;
- Patch 0.7 persistence hardening;
- Patch 0.8 co-op/social/session;
- Patch 0.9 content/pipeline expansion;
- release-candidate hardening.

Later patches are sequencing priorities, not blanket locks. A real known runtime/data/security failure preempts them.

### WIP limit

- one active implementation PR for the current capability;
- at most one additional non-overlapping feature PR only when the first is externally blocked;
- never duplicate an existing open PR.

## 3. Compounding-development target

The repository must become **cheaper to extend as it grows**.

For a repeated feature/content family, agents use a registered extension contract before implementation:

```bash
python scripts/extension_cost.py list
python scripts/extension_cost.py show <contract-id>
python scripts/extension_cost.py check <contract-id> --base main
```

The contract defines the normal canonical path, maturity, target file count, review threshold, server-authority budget, and escalation reasons.

Rules:

- data-first variants should normally touch zero server-authority files;
- if the third variant still needs bespoke wiring, improve the seam before scaling breadth;
- if a normal variant repeatedly exceeds its change-surface budget, treat that as engineering friction;
- a genuinely new semantic may exceed the budget—explain/escalate it rather than forcing it through the wrong abstraction;
- do not build speculative frameworks with no immediate consumer.

**North-star engineering metric:** declining marginal implementation cost for proven feature families.

Patch 0.3 is now deliberately separating three reusable layers:

```text
authored affix data
→ deterministic affix/comparison/modifier facts
→ existing gameplay + presentation owners consume those facts
```

That separation is the compounding payoff: adding another ordinary affix should increasingly be a configuration/test change rather than a new runtime subsystem.

## 4. Studio/device evidence lane

The consolidated pass should still cover the representative run, replay, keyboard/controller/touch, combat feel/readability, banking/equip, lifecycle, build-choice readability, and representative performance.

Evidence outcomes:

- **pass:** promote applicable BUILT — VERIFICATION PENDING work to VERIFIED;
- **reproducible failure:** make the concrete FIX NOW and preempt expansion;
- **not run:** continue dependency-safe source work while preserving the pending-evidence label.

## 5. Planning snapshot

| Area | Status truth | Compounding target |
|---|---|---|
| Foundation / architecture | mature | stable owners + low rediscovery |
| MVP 0.1 | BUILT — VERIFICATION PENDING | regression-protected baseline |
| 0.2 combat/readability | BUILT — VERIFICATION PENDING | reusable feedback/reaction contracts |
| **0.3 loot/builds** | **NOW — BUILDING** | affix/reward/equipment variants become data-first |
| 0.4 RPG progression | foundations present | reuse effect/reward/progression owners |
| 0.5 Main World | preparation partial | stable IDs + registry-driven interactions |
| 0.6 systemic replayability | foundations present | combinatorial output from reusable systems |
| 0.7 persistence | substantial foundations | migration/lifecycle invariants and recovery tests |
| 0.8 co-op/social | basic foundations | multiplayer coverage over existing owners |
| 0.9 content/pipeline | preparation present | mostly data/content + validation |
| RC 1.0 | future | accumulated automation reduces hardening cost |

Do not optimize for roadmap percentage. Optimize for coherent player value **and lower cost of the next similar feature**.

## 6. Agent task algorithm

When asked to continue:

1. fetch current `main`;
2. inspect open PRs;
3. read NOW/NEXT;
4. fix any known concrete safety/authority/data/runtime/validation failure first;
5. otherwise implement the smallest coherent NOW increment;
6. if the task extends a repeated family, use its extension contract and budget;
7. prefer existing owners + data/configuration over copied services/controllers/remotes;
8. add focused regression defense for new invariants;
9. classify risk and run the matching `python scripts/validate.py` profile;
10. merge successful dependency-safe work;
11. keep manual evidence pending when not yet run;
12. continue until a real blocker or exhausted roadmap exists.

## 7. Real stop conditions

Stop expansion and fix when continuing would knowingly build on unsafe/false assumptions, including:

- client-authored consequential truth;
- valuable state that can blank, duplicate, replay, or corrupt;
- competing authoritative owners;
- known reset/replay/respawn or current-state delivery failure;
- required canonical owner/interface missing with no safe bounded path;
- irreversible persistence/security migration requiring proof before dependent work;
- automated validation failure invalidating the implementation.

Unrun ordinary Studio/device/play-feel evidence alone is not a stop condition.

> **Build continuously, make repeated variants cheaper, automate recurring friction, validate automatically, and stop only for real blockers.**
