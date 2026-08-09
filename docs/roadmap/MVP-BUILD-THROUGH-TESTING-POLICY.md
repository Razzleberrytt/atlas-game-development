# Atlas — Continuous Build-Through + Deferred Verification Policy

**Status:** CURRENT EXECUTION-CADENCE AND ROADMAP-STATUS AUTHORITY  
**Adopted:** 2026-08-08  
**Revised:** 2026-08-09  
**Scope:** Implementation cadence, roadmap status meaning, and manual Roblox Studio testing during development of the playable game.  
**Supersedes for execution:** any roadmap, patch, queue, checklist, STOP/PLAY/FIX wording, future-phase lock, verification gate, or agent instruction that treats ordinary missing manual/Studio/device/play evidence as a reason source development must stop.  
**Does not supersede:** server-authority/security requirements, data-loss protections, known runtime failures, accepted evidence truth, explicit architecture decisions, irreversible persistence/migration safeguards, or automated validation failures.

## Decision

Atlas uses a **continuous-build, deferred-verification** workflow.

The roadmap is a priority system and destination map, not a permission system. Agents should continue implementing and merging useful dependency-safe source work for as long as eligible work exists. Manual Studio/device/play evidence is tracked separately and does not ordinarily gate the next source patch.

```text
choose highest-ROI eligible source task
→ implement a small diagnosable increment
→ run applicable automated/static validation
→ merge when successful
→ record BUILT — VERIFICATION PENDING when engine/manual evidence remains
→ continue to the next coherent task or patch
→ run grouped Studio/device/play evidence when available
→ convert reproducible failures into immediate FIX tasks
→ promote passing work to VERIFIED
```

## Lock retirement rule

**General execution locks are retired.**

Older language such as `[L]`, `LOCKED`, `hard gate`, `STOP`, `THEN EXPAND`, `may not begin`, `blocked until play evidence`, or similar scheduling language must not prevent ordinary dependency-safe source development merely because a prior milestone has not yet been manually verified.

Interpret ordinary phase-order locks as **priority guidance / DEFERRED verification order**, not permission barriers.

Do not add new manual-verification locks.

A task may be **BLOCKED** only when a concrete technical or safety condition makes implementation unsafe or invalid. The blocker must be named.

Valid blockers include:

- a known server-authority/security defect that downstream work would depend on;
- durable player data can be corrupted, duplicated, blanked, or irreversibly migrated;
- a required canonical owner/interface is missing or known broken and cannot yet be safely defined;
- a known lifecycle/state-delivery failure makes dependent implementation incorrect;
- an irreversible persistence/security cutover requires runtime proof before further dependent activation;
- applicable automated validation is failing and invalidates the work;
- a real runtime test has already exposed a reproducible failure that invalidates downstream assumptions.

**Not valid by itself:** “Studio/device/manual verification has not been run yet.”

## Status model

- **NOT STARTED** — no meaningful implementation exists.
- **BUILDING** — implementation is active or partial.
- **BUILT — VERIFICATION PENDING** — source implementation exists and applicable automated/static checks pass, while manual/engine/device/integration evidence is still outstanding.
- **VERIFIED** — applicable acceptance evidence has passed.
- **DEFERRED** — lower priority, not prohibited.
- **BLOCKED — <concrete reason>** — implementation cannot safely/correctly proceed for a named technical reason.
- **HISTORICAL** — provenance only.

Source-complete work remains built even when manual evidence is pending. Pending evidence does not become proof, but it also does not freeze development.

## Patch progression rule

Patch boundaries are **organizational milestones, not source locks**.

When a patch's coherent source scope is built and automated validation is green, agents may proceed to the next patch while the earlier patch remains **BUILT — VERIFICATION PENDING**.

If later manual evidence finds a concrete defect, that defect immediately preempts new expansion and becomes the highest-priority FIX until the invalid assumption is repaired.

This creates two simultaneous lanes:

```text
SOURCE LANE: 0.2 → 0.3 → 0.4 → ... continuously when safe
EVIDENCE LANE: grouped Studio/device/play passes → VERIFIED promotions / concrete FIXes
```

The evidence lane can lag the source lane. Status labels must make that lag explicit.

## Implementation freedom with scope discipline

Agents may continue to later roadmap areas when prior source work is coherent and doing so is dependency-safe. Prefer, in order:

1. current/next patch player value;
2. known blocker removal;
3. reusable canonical owners/interfaces;
4. data-driven conversion that reduces future implementation cost;
5. focused regression/tooling improvements that protect imminent work.

Removing locks is not permission for giant speculative breadth. Broad unrelated systems remain lower priority unless they remove a real dependency or become the current roadmap target.

## Manual evidence policy

Manual Studio/device/play testing remains valuable for facts source validation cannot establish: game feel, actual device input, streaming, Terrain/world composition, live timing, audio/visual readability, multiplayer timing, memory/performance, and publishing behavior.

However, these checks are normally **evidence obligations**, not permission gates.

When evidence can be run:

- passing results promote applicable work to **VERIFIED**;
- reproducible failures become immediate FIX tasks;
- incomplete/unavailable evidence leaves work **BUILT — VERIFICATION PENDING** while source development continues.

Early runtime evidence is mandatory only when continuing would knowingly risk irreversible data/security damage or depend on an engine fact that cannot be bounded safely by source/tests.

## Automated validation remains mandatory

For every implementation change, run all applicable non-manual checks available in the environment, including as relevant:

- repository/layout and roadmap-authority validators;
- efficiency-construct validation;
- StyLua/Selene;
- Lune/unit/regression tests;
- Rojo builds;
- content/reference/schema validators;
- server-authority/security tests;
- deterministic/seeded tests;
- migration/persistence validation.

Known deterministic failures must be fixed or concretely bounded. Continuous build-through does not permit stacking known automated breakage.

## Agent task-selection rule

When asked to continue or implement the roadmap:

1. fetch current `main`;
2. inspect open PRs for overlap;
3. identify the highest-ROI current/next roadmap capability;
4. check for a **known concrete** safety/authority/data/lifecycle failure;
5. fix such a failure first when present;
6. otherwise implement the smallest coherent source increment;
7. run applicable automated validation;
8. merge successful work;
9. mark manual/engine evidence pending rather than stopping;
10. proceed to the next task or patch;
11. repeat until roadmap work is exhausted or a real named blocker makes further implementation unsafe/impossible.

Do not stop merely because a Studio pass, playtest, device pass, patch exit question, or experiential acceptance question remains unanswered.

## Relationship to older STOP / PLAY / FIX language

STOP / PLAY / FIX remains useful as a **debugging response after an actual failure is known**, not as an automatic phase lock.

Correct interpretation:

```text
no known failure + source validation green → KEEP BUILDING
manual evidence pending → TRACK PENDING, KEEP BUILDING
real reproducible failure discovered → STOP DEPENDENT EXPANSION, FIX, THEN CONTINUE
```

Any older roadmap text that says the next patch “must not begin” solely because the previous patch lacks manual evidence is superseded by this policy.

## Success condition

This policy is working when agents can continuously implement, validate, merge, and compound progress across the roadmap without artificial manual-testing handoffs, while runtime truth remains honest through BUILT — VERIFICATION PENDING / VERIFIED separation and genuine safety failures still preempt expansion.