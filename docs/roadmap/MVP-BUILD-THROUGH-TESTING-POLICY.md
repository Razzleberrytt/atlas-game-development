# Atlas — Build-Through + Milestone Verification Policy

**Status:** CURRENT EXECUTION-CADENCE AND ROADMAP-STATUS AUTHORITY  
**Adopted:** 2026-08-08  
**Updated:** 2026-08-09  
**Scope:** Implementation cadence, roadmap status meaning, and manual Roblox Studio testing during development of the playable game.  
**Supersedes for execution:** any interpretation of `PLAYABLE-MVP-PATCH-EXECUTION.md`, `MASTER-ROADMAP.md`, `AGENT-BUILD-AHEAD-QUEUE.md`, or agent instructions that treats an ordinary future-phase lock, intermediate ticket, patch fragment, or unverified implementation as a reason development must stop.  
**Does not supersede:** current runtime safety gates, server-authority/security requirements, data-loss protections, accepted evidence truth, explicit architecture decisions, or validation that can be performed automatically.

## Decision

Atlas will use a **build-through-first, milestone-verification-second** workflow.

The roadmap is a development guide, not a permission system. Agents should keep implementing useful dependency-safe work, keep the current game buildable/playable, and verify coherent milestones instead of repeatedly stopping for roadmap locks or tiny manual-test gates.

The target workflow is:

```text
choose highest-ROI useful work
→ implement a small diagnosable increment
→ run automated/static validation
→ mark its real status honestly
→ continue through the coherent milestone
→ run the milestone Studio/playtest pass
→ fix integration/gameplay defects
→ replay until the milestone is verified
→ continue building
```

The intent is to remove self-imposed bureaucracy without removing engineering discipline.

## Roadmap status model

New and actively maintained roadmap entries should use these meanings:

- **NOT STARTED** — no meaningful implementation exists yet.
- **BUILDING** — implementation is actively in progress or only partially complete.
- **BUILT — VERIFICATION PENDING** — the implementation exists and applicable automated/static checks pass, but required Studio, device, integration, or human evidence has not been completed yet.
- **VERIFIED** — the intended behavior has passed its applicable acceptance evidence.
- **DEFERRED** — intentionally lower priority for now; it may still be implemented when it becomes high ROI or directly supports the current milestone.
- **BLOCKED** — work genuinely cannot proceed safely or correctly because of a named dependency, safety issue, broken owner/interface, or required evidence boundary.
- **HISTORICAL** — retained for provenance but not current execution authority.

Agents must not blur **BUILT — VERIFICATION PENDING** into either **NOT STARTED** or **VERIFIED**. This is the key distinction that allows implementation to keep moving without pretending untested work is finished.

## Lock migration rule

General roadmap locks are retired as an execution concept.

When an older document uses `[L]`, `LOCKED`, `held`, or similar scheduling language for an ordinary future phase, interpret it as **DEFERRED**, not as a prohibition on implementation.

Do not add new `[L]` statuses merely to preserve phase order.

A task becomes **BLOCKED** only when the blocking reason is concrete and named. Examples include:

- implementing it would violate server authority or a security boundary;
- durable player data could be corrupted or irreversibly migrated;
- a canonical owner/interface it must depend on is currently broken or undefined;
- the implementation would necessarily destroy a known-good rollback point;
- required engine/runtime behavior cannot be bounded safely without earlier evidence.

Milestone order still defines what should be **verified and promoted first**. It does not normally forbid agents from implementing useful work ahead of that verification point.

## Implementation freedom with scope discipline

Agents may implement work from later roadmap areas when it is dependency-safe and one of the following is true:

- it directly advances the current playable milestone;
- it removes a known blocker or expensive future dependency;
- it creates a reusable canonical owner/interface needed by near-term work;
- it is a small isolated improvement with clear value and low integration risk.

This is not permission for unlimited speculative breadth. Prefer work that produces visible playable progress or reduces a real dependency. Large unrelated systems can remain **DEFERRED** until their value becomes concrete.

## What no longer blocks implementation

The following are **not** normal stop conditions:

- completion of a single roadmap task;
- completion of one implementation ticket;
- a small player-facing increment that is only part of a larger milestone;
- a code merge that passes applicable automated/static validation but still needs milestone-level Studio evidence;
- a documentation/specification milestone;
- an intermediate version label;
- an older roadmap entry marked `[L]` solely because it belongs to a future phase;
- work that is **BUILT — VERIFICATION PENDING**, provided its unresolved evidence does not make continued development unsafe or misleading.

An agent may record `BUILT — VERIFICATION PENDING` and continue with the next useful dependency-safe task.

## What remains required during build-through

For every implementation change, agents must still run all applicable non-manual checks available in their environment, including as relevant:

- repository/layout validators;
- roadmap-authority validation;
- StyLua formatting checks;
- Selene linting when the API dump/environment permits it;
- Lune/unit/regression tests;
- Rojo build validation;
- reference/content validators;
- server-authority/security tests;
- deterministic/seeded tests where applicable;
- migration/schema validation where applicable.

Known deterministic failures must be fixed or explicitly bounded before continuing. Build-through is not permission to stack known breakage.

## Milestone manual gates

Manual Studio testing should happen at **coherent player-facing milestones**, not after every small implementation increment.

For MVP 0.1, the normal consolidated acceptance pass should exercise the representative loop:

```text
spawn / arrive
→ safe preparation
→ deliberate expedition launch
→ explore
→ fight
→ loot/reward decision
→ elite
→ boss / terminal encounter
→ result
→ return to safety
→ bank/apply upgrade
→ start another run
```

A milestone is **VERIFIED** only after the required evidence passes. Until then, completed implementation remains **BUILT — VERIFICATION PENDING**.

After MVP 0.1, keep the same rhythm:

```text
build coherent layer
→ automated/regression validation
→ integrate the layer completely
→ manual milestone playtest
→ debug/replay
→ mark verified
→ continue
```

A patch number by itself does not force an immediate human test if the work is still part of the same coherent integration milestone.

## Exceptions — manual/runtime evidence may still be mandatory earlier

Do not defer manual/runtime evidence when an unfinished change could create an unacceptable hidden risk that automated validation cannot reasonably bound. Examples include:

1. **Data-loss or irreversible persistence risk** — migrations, valuable-state writes, destructive reconciliation, or anything that could corrupt durable player data.
2. **Security/authority boundary changes** — consequential client/server trust changes that require runtime proof beyond tests.
3. **Current v2.7 rollout safety gates** — where the controlling runtime stabilization documents explicitly require exact-build Studio/runtime evidence before a migration or activation may safely proceed.
4. **Engine-only behavior** — streaming, replication timing, reset/respawn lifecycle, multiplayer timing, device behavior, asset permissions, Terrain/visual composition, or similar behavior that cannot be truthfully validated from source/static tests when later work depends on the result being correct.
5. **A known blocker that makes further work unsafe or misleading** — for example, a broken canonical owner or state-delivery path that later work would necessarily build on incorrectly.

These exceptions should be narrow. Agents should not convert ordinary uncertainty into a manual handoff or artificial roadmap lock by default.

## Agent task-selection rule

When asked to `continue`, `implement the next roadmap task`, or equivalent:

1. inspect current `main` and overlapping open work;
2. preserve current security, data-safety, canonical-ownership, and active v2.7 runtime-safety requirements;
3. identify the current playable milestone and its most valuable missing capability;
4. choose the highest-ROI dependency-safe task that advances that milestone or removes a real dependency;
5. later-phase work is allowed when it directly helps, but avoid broad speculative expansion with no near-term payoff;
6. run applicable automated/static validation;
7. mark the work **BUILT — VERIFICATION PENDING** when implementation is complete but milestone/manual evidence remains;
8. continue implementing unless a concrete **BLOCKED** condition applies;
9. at a coherent milestone boundary, stop expansion long enough to run the consolidated Studio/debug/replay pass;
10. mark the milestone **VERIFIED** only after its required evidence passes.

## Rationale

The previous lock-heavy and STOP / PLAY / FIX interpretations optimized for isolation, but they also created too many artificial handoffs and made the roadmap compete with development momentum.

The new model separates two questions that should never have been conflated:

1. **Has this been built?**
2. **Has this been verified?**

That distinction lets Atlas keep moving quickly while preserving truthful evidence. Some integration bugs may accumulate before a milestone pass, but automated regression checks, small commits, canonical ownership rules, rollback discipline, and narrow early-test exceptions keep that risk bounded.

## Success condition

This policy is working when agents can keep adding and implementing useful game work without fighting roadmap locks, while every item still has an honest state and player-facing milestones receive real test/debug/replay evidence before being called verified.