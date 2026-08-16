# Atlas — Slice Execution Contract

**Status:** EXECUTION PROCESS CONTRACT  
**Scope authority:** `PLAYABLE-MVP-PATCH-EXECUTION.md`  
**Daily authority:** `EXECUTION-DASHBOARD.md`  
**Reality evidence:** `../production/PROJECT-REALITY-MAP.md`  
**Product authority:** `../bible/00-current-product-authority.md`

This document defines how a bounded Atlas development slice is executed by humans or parallel AI sessions. It is process, not a second roadmap.

## Purpose

Atlas must be developable as a finite sequence of coherent playable slices rather than an unlimited stream of locally reasonable improvements.

A slice exists to produce one observable player/system capability with a concrete exit condition.

## Mandatory session envelope

Every implementation session must establish the following before broad code changes:

1. **Current slice** — which accepted product layer/capability is being advanced?
2. **Target concern(s)** — which `LK-###` concerns are touched?
3. **Reality state** — `KEEP`, `HARDEN`, `COMPLETE`, `PROVE`, `LATER`, or explicit product-authority `CUT`.
4. **Canonical owner** — which existing module/service/config owns the behavior?
5. **Blocking gap** — what smallest concrete gap prevents the slice exit condition?
6. **Allowed scope** — what may change in this session?
7. **Non-scope** — what attractive adjacent work must not be expanded?
8. **Acceptance evidence** — what proves success?
9. **Overlap check** — what current/open work already touches this capability?
10. **Integration result** — merge only after the applicable validation gate is green.

If these cannot be answered, the session should audit or measure rather than invent a new subsystem.

## Reality-directed behavior

```text
KEEP
→ preserve canonical ownership
→ repair only demonstrated defects or accepted migrations

HARDEN
→ improve evidence, reliability, lifecycle safety, or regression coverage
→ do not redesign merely because evidence is incomplete

COMPLETE
→ identify the smallest missing end-to-end path
→ finish that path through the existing owner
→ avoid breadth until the path works coherently

PROVE
→ obtain Studio/device/play/runtime evidence
→ record what actually happened
→ promote reproducible defects into implementation work

LATER
→ backlog by default
→ activate only through current dashboard/product scope

CUT
→ do not implement unless product authority explicitly changes
```

## Slice completion law

A slice is complete when its **exit condition is observably satisfied**, not when every related taxonomy concern is complete.

Coverage is diagnostic. Coverage is not the task queue.

A slice may finish with:

- deferred polish;
- later content breadth;
- unimplemented optional systems;
- unanswered future design questions;
- lower-priority taxonomy gaps.

Those do not block advancement unless the accepted exit condition requires them.

## Current finite product sequence

The existing playable patch scope remains authoritative:

```text
MVP 0.1  first complete repeatable run
0.2      combat feel + readability
0.3      loot + build replayability
0.4      RPG progression
0.5      Main World + environment
0.6      procedural/systemic replayability
0.7      durable persistence hardening
0.8      co-op/social/session expansion
0.9      content expansion + production pipeline
RC       production hardening
1.0      release
LIVE     measured upgrades
```

This sequence is not a command to execute the next number automatically. The dashboard selects NOW/NEXT.

## The key 0.1 proof

When MVP 0.1 is the active product slice, the proof target is the smallest coherent end-to-end run:

```text
safe arrival
→ prepare/orient
→ deliberate expedition launch
→ operation spawn
→ traverse/explore
→ combat
→ objective progress
→ reward/loot interaction
→ elite pressure
→ terminal/boss outcome
→ success/failure resolution
→ durable result/reward handling
→ return
→ replay
```

### 0.1 exit condition

A player can complete the entire above loop without developer intervention, the valuable result is server-authoritative, temporary run state resets correctly, and the player can immediately begin another run.

The first proof may be single-player even though canonical architecture preserves the product's co-op direction. Co-op expansion must not be used as an excuse to leave the basic end-to-end run incomplete.

## Parallel-session lanes

Parallel work is useful only when lanes do not create overlapping authority.

Recommended lane types:

- **reliability lane** — concrete defects, bounded waits, lifecycle/recovery;
- **run-loop lane** — launch/objective/result/return continuity;
- **combat/encounter lane** — only when not overlapping another combat owner change;
- **world/readability lane** — measured topology/orientation issues;
- **evidence lane** — automated tests, metrics, Studio evidence capture;
- **documentation/registry lane** — generated truth synchronization only.

Do not run several sessions that independently redesign the same combat, progression, persistence, inventory, networking, or world authority.

## Session prompt template

Use this compact contract when starting an AI development session:

```text
Atlas development session.

Authority:
- Read docs/bible/00-current-product-authority.md.
- Read docs/roadmap/EXECUTION-DASHBOARD.md.
- Read docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md.
- Read docs/production/PROJECT-REALITY-MAP.md.
- Respect AGENTS.md and repository validation rules.

Task:
1. Identify the current accepted slice/capability touched by this request.
2. Map the task to LK concern IDs and existing canonical owners.
3. Classify each touched concern as KEEP/HARDEN/COMPLETE/PROVE/LATER or explicit CUT.
4. Inspect current main and open-overlap risk before implementing.
5. Choose the smallest coherent blocking gap.
6. Reuse/repair canonical owners before creating anything new.
7. Do not expand adjacent LATER/CUT systems.
8. Add/adjust the smallest appropriate regression evidence.
9. Run the applicable validation gate.
10. Merge only when successful.
11. Update canonical coverage/generated reality only when evidence materially changed.
12. Stop when the bounded gap is closed; do not invent follow-on work to keep the lane alive.

Return:
- gap closed
- files/owners changed
- validation evidence
- merge result
- remaining slice blockers, if any
```

## Anti-drift checks

Before merging, ask:

- Did this change close the stated gap?
- Did it create a second owner for existing behavior?
- Did it activate a later feature implicitly?
- Did it increase complexity without improving the slice exit condition?
- Did it replace measurement with speculation?
- Did it turn one bounded task into a broad redesign?
- Does the canonical coverage evidence need to change?

If the first answer is no, or any of the next five are yes without an explicit decision, the change should not merge as-is.

## Definition of done for a development session

A session is done when:

```text
bounded gap identified
+ canonical owner respected
+ implementation/evidence complete
+ validation green
+ no duplicate authority introduced
+ merge completed when eligible
+ reality/coverage updated only if materially warranted
```

It is not required to discover another task before stopping.

## Core rule

> **Finish observable loops, not infinite possibility spaces.**
