# Atlas — MVP Build-Through Testing Policy

**Status:** CURRENT MANUAL-TESTING CADENCE AUTHORITY  
**Adopted:** 2026-08-08  
**Scope:** Manual Roblox Studio testing cadence during implementation of the first complete playable version.  
**Supersedes only:** any interpretation of `PLAYABLE-MVP-PATCH-EXECUTION.md`, `MASTER-ROADMAP.md`, or agent instructions that requires a human/manual Studio playtest after every small implementation increment, ticket, patch fragment, or intermediate version before eligible work may continue.  
**Does not supersede:** current runtime safety gates, server-authority/security requirements, data-loss protections, accepted evidence truth, explicit architecture decisions, or validation that can be performed automatically.

## Decision

Atlas will use a **build-through-first, consolidated-playtest-second** workflow for MVP 0.1.

Agents should implement the complete dependency-safe MVP 0.1 player loop before requiring the user to manually playtest every intermediate slice.

The target workflow is:

```text
implement eligible MVP 0.1 work
→ run automated/static validation continuously
→ keep changes small enough to diagnose and revert
→ continue through remaining MVP 0.1 blockers
→ reach MVP 0.1 code-complete
→ perform one consolidated exact-build Studio playtest/debug pass
→ fix integration/gameplay defects
→ replay until the complete loop is accepted
→ begin post-MVP upgrade patches
```

The intent is to remove unnecessary human handoffs, not to remove engineering discipline.

## What no longer blocks implementation

The following are **not** hard manual-test gates while MVP 0.1 is still being assembled:

- completion of a single roadmap task;
- completion of one implementation ticket;
- a small player-facing increment that is only part of the First Complete Run;
- a code merge that passes applicable automated/static validation;
- a documentation/specification milestone;
- an intermediate version label that does not represent the complete MVP 0.1 loop.

An agent may record `Studio/manual verification pending at MVP integration pass` and continue with the next dependency-safe MVP 0.1 task.

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

Known failures in these checks must be fixed or explicitly bounded before continuing. Build-through is not permission to stack known deterministic failures.

## MVP 0.1 hard manual gate

The first normal mandatory human/Studio acceptance gate is **MVP 0.1 code-complete: First Complete Run**.

Before Patch 0.2 becomes the normal implementation focus, an exact-build Studio pass must exercise the representative loop:

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

That consolidated pass is where gameplay feel, navigation, visual readability, atmosphere, transitions, lifecycle behavior, and cross-system integration are debugged together.

## Exceptions — manual/runtime evidence may still be mandatory earlier

Do not defer manual/runtime evidence when an unfinished change could create an unacceptable hidden risk that automated validation cannot reasonably bound. Examples include:

1. **Data-loss or irreversible persistence risk** — migrations, valuable-state writes, destructive reconciliation, or anything that could corrupt durable player data.
2. **Security/authority boundary changes** — consequential client/server trust changes that require runtime proof beyond tests.
3. **Current v2.7 rollout gates** — where the controlling runtime stabilization documents explicitly require exact-build Studio/runtime evidence before a migration or activation may safely proceed.
4. **Engine-only behavior** — streaming, replication timing, reset/respawn lifecycle, multiplayer timing, device behavior, asset permissions, Terrain/visual composition, or similar behavior that cannot be truthfully validated from source/static tests.
5. **A known blocker that makes further work unsafe or misleading** — for example, a broken canonical owner or state-delivery path that later work would necessarily build on incorrectly.

These exceptions should be narrow. Agents should not convert ordinary implementation uncertainty into a manual handoff by default.

## Post-MVP patch cadence

After MVP 0.1 is accepted, manual testing should be **milestone-based rather than reflexively version-based**.

- Automated/static validation remains continuous.
- Small implementation increments may be grouped into a coherent player-facing milestone before manual acceptance.
- Manual Studio testing is required before declaring a milestone/player-facing patch accepted, before release-candidate promotion, and whenever an exception above applies.
- A patch number by itself does not force an immediate human test if the work is still part of the same coherent integration milestone.

The preferred rhythm is:

```text
build coherent layer
→ automated/regression validation
→ integrate the layer completely
→ manual milestone playtest
→ debug/replay
→ continue
```

## Agent task-selection rule

When asked to `continue`, `implement the next roadmap task`, or equivalent:

1. fetch current `main` and inspect overlapping open PRs;
2. honor any still-active v2.7 safety/evidence dependency;
3. otherwise remain focused on the current MVP 0.1 code-complete target;
4. choose the highest-ROI dependency-safe unfinished task that advances the complete First Run;
5. run applicable automated/static validation;
6. if the task is complete and no narrow exception requires manual evidence now, record manual Studio verification as deferred to the consolidated MVP 0.1 integration pass and continue;
7. do not ask the user to manually test merely because an intermediate task or version finished;
8. once MVP 0.1 is code-complete, stop expansion and perform the consolidated Studio/debug/replay gate before Patch 0.2 becomes the normal focus.

## Rationale

The previous STOP / PLAY / FIX interpretation optimized for isolation but created too many human handoffs while the game was still missing pieces of one complete experience. For the current stage, the higher-ROI approach is to finish the first integrated playable version, then debug it as a whole.

The tradeoff is accepted deliberately: some integration bugs may accumulate before the consolidated pass, but automated regression checks, small commits, canonical ownership rules, rollback discipline, and the narrow early-test exceptions keep that risk bounded.

## Success condition

This policy is working when agents can keep implementing MVP 0.1 without repeatedly stopping for routine manual testing, while the repository still reaches the first complete Studio playtest with failures that are diagnosable, reversible, and safe to fix.