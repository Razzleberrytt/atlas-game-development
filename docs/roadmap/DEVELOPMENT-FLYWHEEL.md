# Living Kingdoms — Compounding Development Flywheel

**Status:** ACTIVE ENGINEERING POLICY  
**Adopted:** 2026-08-09  
**Purpose:** make each completed milestone reduce the cost, risk, and ambiguity of future milestones.

This policy supplements the execution dashboard, patch roadmap, and master roadmap. It does not authorize agents to skip runtime, authority, persistence, or evidence gates.

## North-star engineering rule

> When two dependency-safe tasks have similar player value, prefer the task that also increases the efficiency, safety, or reuse of future development.

Do not optimize for abstraction by itself. A leverage investment must have a concrete near-term consumer or remove repeated measurable friction.

## The flywheel

```text
reusable foundation
→ data-driven feature/content
→ focused automated validation
→ safer/faster merge
→ observed repeated friction
→ tooling/generalization
→ cheaper next feature
→ broader reuse
→ stronger validation corpus
→ increasingly autonomous agent execution
```

Every patch should leave the repository easier to extend than it found it whenever doing so is proportionate to the task.

## Five leverage layers

### 1. Reusable owners before bespoke feature piles

Prefer extending a stable existing owner or creating a narrowly reusable owner when multiple known features need the same behavior.

High-value examples include:

- combat/status-effect resolution;
- item, loot, affix, and reward definitions;
- enemy archetype/ability definitions;
- interaction and prompt contracts;
- mission/objective state;
- spawning/encounter composition;
- inventory/equipment/progression boundaries;
- presentation/VFX/audio event contracts;
- configuration and feature flags;
- lifecycle cleanup and observability.

Do not create a second authoritative state path merely to gain reuse.

### 2. Data-driven content expansion

When behavior is stable, prefer definitions/configuration over copied scripts. The target progression is:

```text
first example proves behavior
→ second/third example expose common shape
→ common shape becomes validated data/schema
→ later examples become primarily content work
```

A new weapon, enemy, encounter, loot entry, quest, effect, or route should increasingly require less new authority code.

### 3. Tool repeated friction

If an agent performs the same mechanical operation repeatedly, evaluate whether a repository tool should own it. Candidates include:

- definition/schema validation;
- source/wiring audits;
- content ID/reference checks;
- duplicate-owner detection;
- generated coverage reports;
- migration helpers;
- test/build/evidence commands;
- roadmap/status consistency checks.

Rule of thumb: automate when the operation is repeated, deterministic, error-prone, and likely to recur. Do not build a framework for a one-off inconvenience.

### 4. Bugs become permanent defenses

For every meaningful defect, ask whether the defect class can be prevented or detected automatically.

Preferred closure sequence:

```text
reproduce or characterize
→ fix root cause
→ add focused regression coverage or validator when practical
→ document invariant only when code/tests cannot express it sufficiently
```

The goal is that the same class of failure becomes progressively harder to reintroduce.

### 5. Optimize agent entry and execution

Agents should not rediscover repository truth on every session. Keep the shortest authoritative path current:

```text
EXECUTION-DASHBOARD.md
→ scoped AGENTS.md
→ only task-specific authority/specification
→ implementation + focused tests
→ validation
→ merge
→ update status only when truth changed
```

Prefer machine-checkable contracts, stable IDs, explicit ownership, exact validation commands, and clear exit signals over prose that requires interpretation.

## Leverage test for roadmap tasks

Before implementing a normal roadmap increment, evaluate these questions quickly:

1. **Player value:** does this advance the current patch exit signal or remove a real dependency?
2. **Reuse:** will an existing owner support it, or is there a proven repeated shape worth generalizing?
3. **Data conversion:** can future variants become definitions/configuration after this implementation?
4. **Validation:** can this change add a regression test, audit, or invariant that protects future work?
5. **Friction:** did this task expose repeated deterministic work worth tooling?
6. **Agent clarity:** can the next agent understand ownership, extension points, and verification without rediscovery?

A task does not need to score on every dimension. Player value and dependency truth remain primary.

## Leverage scoring for ties

Use this only to choose among similarly valuable, dependency-safe candidates. Score each 0–2:

| Dimension | 0 | 1 | 2 |
|---|---|---|---|
| Near-term reuse | one-off | plausible second consumer | multiple identified consumers |
| Future effort reduction | negligible | modest | substantial |
| Risk reduction | none | focused guard | prevents a recurring failure class |
| Data/content scalability | bespoke | partially configurable | future variants mostly data |
| Agent autonomy | no improvement | clearer path | removes repeated discovery/manual work |

Prefer the higher leverage score when player value, dependency order, and risk are otherwise comparable. Never use the score to bypass a blocker or active safety gate.

## Leverage passes

Do not interrupt every feature to refactor. Run a small leverage pass when one of these triggers appears:

- the same pattern is implemented for a third time;
- the same manual/mechanical agent step recurs across multiple tasks;
- a bug class has appeared more than once;
- a patch is about to expand content breadth significantly;
- a patch exit exposes a clean opportunity to consolidate without destabilizing accepted behavior.

A leverage pass should remain bounded and must identify its immediate consumers. If it cannot, defer it.

## Patch-level compounding targets

The current patch sequence should compound deliberately:

- **0.2 Combat Feel:** establish reusable presentation/reaction contracts so weapon and enemy feedback variants do not become bespoke wiring.
- **0.3 Loot + Builds:** push items, affixes, upgrades, relics, and rewards toward validated data-driven definitions.
- **0.4 RPG Progression:** reuse stable stat/effect/reward contracts rather than adding parallel progression authority.
- **0.5 Main World:** use registries, stable IDs, interaction contracts, and composition data so world expansion is not script-per-object work.
- **0.6 Systemic Replayability:** explicitly multiply output from reusable encounter, modifier, route, event, and enemy systems.
- **0.7 Persistence:** convert lifecycle failures into migration tests, invariants, rollback tooling, and durable validation.
- **0.8 Co-op/Social:** extend existing server authority and lifecycle owners; add multiplayer regression coverage for previously single-player assumptions.
- **0.9 Content/Pipeline:** cash in the flywheel: proven systems should permit breadth primarily through data/content plus automated validation.
- **RC 1.0:** use the accumulated tests, audits, tooling, observability, and stable ownership to reduce release hardening cost.

## Definition-of-done addition

For each meaningful implementation PR, the completion report should include a short **Leverage outcome** only when applicable:

- reused/extended owner;
- new reusable seam and its immediate consumers;
- future variants converted to data/config;
- regression defense added;
- repeated friction automated;
- no leverage change because bespoke implementation was intentionally cheaper/safer.

Do not manufacture leverage work to fill this field.

## Anti-patterns

Avoid:

- speculative frameworks with no immediate consumer;
- premature generic abstractions before the repeated shape is understood;
- giant refactors hidden inside gameplay tasks;
- replacing a stable owner solely for architectural elegance;
- generated systems that make debugging harder than explicit data;
- duplicated authority in the name of modularity;
- measuring success by lines of code, task count, or roadmap percentage rather than player value and reduced future cost.

## Expected long-term result

The repository should exhibit a declining marginal implementation cost: later weapons, enemies, effects, encounters, loot, quests, world interactions, and progression content should increasingly reuse proven owners and validated definitions. At the same time, the regression corpus and tooling should make autonomous agent changes safer and faster rather than more fragile as the game grows.
