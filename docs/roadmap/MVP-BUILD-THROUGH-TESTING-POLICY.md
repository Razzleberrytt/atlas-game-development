# Atlas — Continuous Build-Through + Deferred Verification Policy

**Status:** CURRENT BUILT-VS-VERIFIED AUTHORITY  
**Adopted:** 2026-08-08  
**Refreshed:** 2026-08-16  
**Scope:** source-completion status, deferred manual evidence, and the relationship between implementation and verification.  
**Task selection authority:** [`EXECUTION-DASHBOARD.md`](EXECUTION-DASHBOARD.md).  
**Automated cadence authority:** [`AUTOMATED-FIRST-EXECUTION-POLICY.md`](AUTOMATED-FIRST-EXECUTION-POLICY.md).

## Decision

Atlas uses a **continuous-build, deferred-verification** workflow.

Manual Studio/device/play evidence is tracked honestly but does not ordinarily stop dependency-safe source work after automated validation succeeds.

```text
dashboard-selected work
→ implement coherent increment
→ automated validation
→ merge when green
→ BUILT — VERIFICATION PENDING when engine/manual facts remain
→ continue dependency-safe source work
→ grouped Studio/device/play evidence when useful/required
→ VERIFIED only when the stated evidence passes
→ reproducible failure becomes immediate FIX
```

## Status model

- **NOT STARTED** — no meaningful implementation exists.
- **BUILDING** — implementation is active or partial.
- **BUILT — VERIFICATION PENDING** — intended source behavior exists and applicable automated/static checks pass; relevant engine/device/human evidence remains unmeasured.
- **VERIFIED** — the required evidence for the stated claim passed.
- **DEFERRED** — intentionally lower priority or explicitly postponed.
- **BLOCKED — <concrete reason>** — implementation cannot safely/correctly proceed for a named reason.
- **HISTORICAL** — provenance only.

Source-complete work remains built when manual evidence is pending. Pending evidence is not proof, but it is also not a source-development freeze.

Development-coverage states are separate. `substantial` coverage does not equal `VERIFIED`.

## Valid blockers

A task may be blocked by a concrete condition such as:

- a known server-authority/security defect downstream work would depend on;
- durable player data can be corrupted, duplicated, lost, blanked, or irreversibly migrated;
- a required canonical owner/interface is missing or known broken and cannot be safely defined;
- a known lifecycle/state-delivery failure makes dependent implementation incorrect;
- an irreversible persistence/security cutover needs runtime proof before a dependent step;
- applicable deterministic validation is red in a way that invalidates the work;
- a real runtime observation already exposed a reproducible failure;
- a direct branch/owner conflict cannot be isolated safely.

**Not a blocker by itself:** “ordinary Studio/device/manual verification has not been run yet.”

## Patch progression

Patch boundaries are organizational/product milestones, not global source locks.

- The execution dashboard chooses the current lane.
- A coherent source layer may proceed while earlier manual evidence remains pending when dependencies are safe.
- If later evidence exposes a real defect, that defect immediately preempts dependent expansion.
- Do not resurrect old patch queues, old PR numbers, or old “next task” text from dated documents after the dashboard has moved on.

This creates two conceptual lanes:

```text
SOURCE: current dashboard task → next dependency-safe source work
EVIDENCE: grouped Studio/device/play checks → VERIFIED promotions or concrete FIXes
```

The evidence lane can lag. Status labels make the lag explicit.

## Implementation freedom with scope discipline

Build-through is not permission for giant speculative breadth.

Prefer:

1. current dashboard defects/tasks;
2. player value and dependency removal;
3. reusable canonical owners/interfaces;
4. data/configuration seams that reduce future implementation cost;
5. focused regression/tooling improvements that protect imminent work;
6. broad taxonomy gaps only after the above are considered.

For exhaustive cross-system requests, classify gaps through `LK-001`–`LK-300`, then route them into existing owners. Do not turn the taxonomy into 300 parallel projects.

## Manual evidence policy

Studio/device/play testing remains valuable for:

- game feel;
- actual input/device behavior;
- Terrain/world composition;
- streaming/live timing;
- multiplayer behavior;
- performance/memory/network profiling;
- animation/assets;
- audio/lighting;
- publishing configuration.

When evidence runs:

- passing results may promote the supported claim to **VERIFIED**;
- reproducible failures become immediate FIX candidates;
- unavailable/incomplete evidence leaves source work **BUILT — VERIFICATION PENDING** when appropriate.

Earlier evidence is mandatory only when continuing would knowingly risk irreversible/high-consequence harm or depend on an engine fact that cannot be safely bounded by source/tests.

## Automated validation remains mandatory

Run the risk-appropriate repository gate before merge. Continuous build-through never means stacking known deterministic breakage.

```bash
python scripts/validate.py docs
python scripts/validate.py fast
python scripts/validate.py full
```

## Relationship to STOP / PLAY / FIX

STOP / PLAY / FIX is a useful response to a **known** failure, not an automatic phase ceremony.

```text
no known failure + automated gate green → KEEP BUILDING
manual evidence pending → TRACK PENDING, KEEP BUILDING
real reproducible failure → STOP DEPENDENT EXPANSION, FIX, VALIDATE, CONTINUE
```

## Agent rule

When asked to continue:

1. fetch current main and inspect open PRs for freshness/overlap;
2. read the dashboard;
3. fix a concrete blocker if present;
4. otherwise implement the smallest coherent selected increment;
5. run required automated validation;
6. merge when green within WIP rules;
7. record manual/engine evidence truthfully;
8. update dashboard/coverage only if their truth materially changed;
9. continue rather than inserting an artificial manual handoff.

> **Built means source truth. Verified means evidence truth. Neither word should be used to fake the other.**
