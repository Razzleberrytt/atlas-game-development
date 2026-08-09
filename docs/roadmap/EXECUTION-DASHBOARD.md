# Atlas — Execution Dashboard v1.4

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-09  
**Purpose:** answer four questions quickly: **what is true, what is NOW, what is NEXT, and what must wait?**

For detailed patch acceptance, use `PLAYABLE-MVP-PATCH-EXECUTION.md`. For complete long-range scope, use `MASTER-ROADMAP.md`. `MVP-BUILD-THROUGH-TESTING-POLICY.md` controls implementation cadence and explicitly forbids using ordinary manual verification as a source-development lock.

## 1. Current truth

- **MVP 0.1 source implementation:** **100% BUILT — VERIFICATION PENDING**.
- **Known required MVP 0.1 source gaps:** none currently identified.
- **Studio/device lane:** consolidated MVP 0.1 / Patch 0.2 play, device, and performance evidence remains pending and should be run when available.
- **Agent/source lane:** Patch 0.2 source-safe combat/readability pass is built; source development may continue into **Patch 0.3 — Loot + Build Replayability** without waiting for manual verification.
- **Merged Patch 0.2 increments:** PR #322 teammate melee swing readability; PR #323 confirmed melee impact + broader enemy reactions; PR #324 directional teammate firearm reports; PR #325 directional hostile/special/boss telegraph audio.
- **Engineering leverage policy:** active; comparable dependency-safe tasks favor reusable/data-driven/testable/toolable implementations without delaying player value for speculative abstraction.
- **Verification truth remains strict:** unrun Studio/device evidence means BUILT — VERIFICATION PENDING, never VERIFIED.

## 2. NOW → NEXT → LATER

### NOW

**Begin Patch 0.3 — Loot + Build Replayability source implementation using the retained equipment/reward/inventory owners.**

Highest-ROI first slice: deterministic item/affix generation rules and validated data definitions that extend the existing `EquipmentReward*` / inventory path rather than creating a second loot authority.

Manual Studio/device verification is a parallel evidence lane, not a source-development permission gate. If a real runtime failure is discovered later, that concrete failure becomes NOW and preempts new work until fixed.

### NEXT

Continue Patch 0.3 in small coherent increments:

1. deterministic item/affix generation under the retained equipment owner;
2. meaningful build-choice presentation/application using existing authority boundaries;
3. reward-pool and build-variety expansion primarily through validated data;
4. regression coverage for generation, ownership, equip/application, replay, and persistence boundaries;
5. continue to later patches when Patch 0.3 source work is coherently built, even if manual verification remains pending.

### LATER

Later roadmap patches are **sequencing priorities, not locks**:

- Patch 0.4 RPG progression;
- Patch 0.5 Main World/environment expansion;
- Patch 0.6 systemic replayability;
- Patch 0.7 persistence hardening;
- Patch 0.8 co-op/social/session expansion;
- Patch 0.9 content/pipeline expansion;
- release-candidate hardening.

Agents may move forward through these when earlier source work is coherent and applicable automated validation is green. Do not mark a patch VERIFIED until its evidence exists.

### WIP limit

- one active implementation PR for the current capability;
- at most one additional non-overlapping feature PR when the first is externally blocked;
- documentation/workflow maintenance does not count as a feature PR;
- never duplicate work already present in an open PR.

## 3. Studio/device evidence lane

Studio/device evidence remains important, but it no longer blocks ordinary source progression.

The consolidated pass should still cover the representative run, replay, keyboard/controller/touch, combat feel/readability, banking/equip, lifecycle, and representative performance.

Evidence outcomes are handled as follows:

- **pass:** promote applicable BUILT — VERIFICATION PENDING work to VERIFIED;
- **reproducible failure:** immediately prioritize the concrete FIX over further expansion;
- **not yet run:** keep building dependency-safe source work and preserve the pending-evidence label.

## 4. Planning snapshot

| Area | Status truth |
|---|---|
| Foundation / architecture | mature |
| MVP 0.1 source | **BUILT — VERIFICATION PENDING** |
| 0.2 combat feel/readability | **BUILT — VERIFICATION PENDING** for current source pass |
| 0.3 loot/builds | **NOW — BUILDING** |
| 0.4 RPG progression | NOT STARTED / foundations present |
| 0.5 Main World/environment | preparation partial |
| 0.6 systemic replayability | foundations present |
| 0.7 persistence hardening | substantial foundations present |
| 0.8 co-op/social/session | basic foundations present |
| 0.9 content/pipeline | preparation present |
| Release-candidate hardening | future |

Do not optimize for percentage movement. Optimize for coherent playable capability, automated correctness, and declining future implementation cost.

## 5. Patch path

| Patch | Goal | Compounding target |
|---|---|---|
| **0.2 Combat Feel** | make the existing run satisfying/readable | reusable feedback/reaction contracts |
| **0.3 Loot + Builds** | create build-driven replay motivation | validated item/affix/reward data |
| **0.4 RPG Progression** | create durable anticipation | reuse stat/effect/reward owners |
| **0.5 Main World** | create a memorable readable home | stable IDs, registries, composition data |
| **0.6 Systemic Replayability** | multiply variety from reusable systems | encounter/modifier/route/event combinatorics |
| **0.7 Persistence Hardening** | make valuable state trustworthy | lifecycle/migration regression defenses |
| **0.8 Co-op/Social** | make co-op easier and more valuable | multiplayer coverage over existing owners |
| **0.9 Content/Pipeline** | scale proven systems efficiently | cash in accumulated tooling and schemas |
| **RC 1.0** | production readiness | accumulated tests/audits reduce hardening cost |

## 6. Status vocabulary

Use only:

```text
NOT STARTED
BUILDING
BUILT — VERIFICATION PENDING
VERIFIED
DEFERRED
BLOCKED — concrete reason required
HISTORICAL
```

`BLOCKED` requires a concrete technical/safety dependency. Missing ordinary manual play evidence alone is not a blocker.

## 7. Agent task algorithm

When asked to continue:

1. fetch current `main`;
2. inspect open PRs;
3. read NOW/NEXT/LATER;
4. check for a **known concrete** runtime-safety, authority, lifecycle, security, or data-safety failure;
5. if one exists, fix it first;
6. otherwise take NOW and continue through coherent source milestones without waiting for ordinary manual verification;
7. choose the smallest coherent increment that advances the current patch;
8. use leverage tooling when useful;
9. classify risk using root `AGENTS.md`;
10. run the matching automated validation;
11. merge successful dependency-safe work;
12. mark engine/manual evidence as pending rather than stopping;
13. continue to the next source task until a real blocker, exhausted roadmap, or known unsafe condition exists.

## 8. Real stop conditions

Stop expansion and fix only when continuing would knowingly build on unsafe or false assumptions, including:

- client input can author consequential truth;
- valuable state can blank, duplicate, replay, or corrupt;
- two systems compete for the same authoritative ownership;
- a known reset/replay/respawn leak invalidates downstream work;
- a known state-delivery failure makes downstream behavior incorrect;
- a required canonical owner/interface does not exist and cannot be safely defined;
- an irreversible persistence/security migration requires runtime proof before dependent work can safely proceed;
- automated validation fails in a way that invalidates the current implementation.

Unrun ordinary Studio/device/play-feel evidence is **not** itself a stop condition.

## 9. Scope control

Removing locks does not mean uncontrolled breadth. Prefer the current patch, high player value, dependency removal, reusable owners, and data-driven expansion. Avoid giant speculative systems with no near-term consumer.

> **Build continuously, validate automatically, merge coherent increments, track manual evidence separately, and stop only for real blockers.**