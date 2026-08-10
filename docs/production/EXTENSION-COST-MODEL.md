# Living Kingdoms — Extension Cost Model

**Status:** ACTIVE ENGINEERING CONTROL  
**Adopted:** 2026-08-09  
**Goal:** make repeated feature/content additions cheaper as the game grows.

The game is scaling successfully when later variants require **less new authority code, fewer touched files, less rediscovery, and more validated data** than earlier variants.

## Core rule

> A repeated feature family must trend toward a narrow canonical extension path. If adding the next variant repeatedly touches many unrelated files, that is engineering friction to fix—not the new normal.

This is not a hard “small diff at all costs” rule. A genuinely new gameplay semantic may need broader work. The purpose is to distinguish **new semantics** from **accidental extension cost**.

## Maturity ladder

```text
bespoke
→ shared owner
→ registry-first / stable extension seam
→ data-first
→ generated/scaffolded only when authoring is still repetitive
```

Do not skip directly to a universal framework. Move a family up the ladder only after the repeated shape is understood.

## Extension contracts

Machine-readable contracts live at:

```text
config/efficiency/extension-contracts.json
```

Each contract records:

- the capability it extends;
- current maturity;
- canonical paths;
- support/seam paths;
- tests;
- preferred change type;
- target changed-file count;
- review threshold;
- server-authority file budget;
- validation profile;
- the normal extension recipe;
- conditions that mean the change is actually a new semantic and should escalate.

Use:

```bash
python scripts/extension_cost.py list
python scripts/extension_cost.py show equipment-affix-variant
python scripts/extension_cost.py check equipment-affix-variant --base main
```

`check` returns non-zero when the implementation exceeds its registered change surface or escapes the intended extension path. That is a **review signal**, not permission to delete necessary correctness work.

## Change-surface law

For repeated variants:

1. start from the registered extension contract;
2. try the canonical data/registry path first;
3. if support/resolver code must change, determine whether the schema truly lacks a needed semantic;
4. if server-authority code must change for what should be a data-only variant, stop and inspect the seam;
5. if the same escalation happens repeatedly, improve the reusable owner/schema before breadth expands further;
6. add a regression defense for any new invariant;
7. update the contract only when the real extension path has changed materially.

The target is **declining marginal implementation cost**, not artificially tiny PRs.

## Practical thresholds

A contract has two file-count numbers:

- **target_changed_files** — the normal cheap path;
- **review_threshold_files** — above this, explicitly determine why the variant has become expensive.

It also has an **authority_file_budget**. A data-first variant should normally touch zero server-authority files. If it does, either:

- the feature is not actually just a variant; or
- the reusable seam is incomplete.

Both are useful discoveries.

## Patch compounding expectations

### Patch 0.3 — Loot + Builds

Affixes, reward definitions, and build variations should trend toward config + focused tests. New affix variants should not require new persistence or combat owners.

### Patch 0.4 — RPG Progression

Archetypes/skills should reuse effect, reward, inventory, and progression boundaries. Repeated class variants should move toward definitions instead of service-per-class logic.

### Patch 0.5 — Main World

Interactions should use stable IDs and registries. New props/NPC services should not become script-per-object islands.

### Patch 0.6 — Systemic Replayability

The payoff should become obvious: encounter, modifier, route, event, enemy, and reward combinations should multiply through existing owners/configuration.

### Patch 0.9 — Content Scale

Most breadth should be data/content authoring plus validation. If content expansion still requires broad authority rewrites, the project has not compounded enough yet.

## When to improve a seam

Prioritize a bounded leverage improvement when one of these happens:

- the third variant still needs bespoke wiring;
- a normal variant exceeds its review threshold twice;
- a supposedly data-first variant repeatedly touches server authority;
- multiple agents rediscover the same extension path;
- the same invariant is implemented/tested separately in multiple places;
- a content family is about to expand significantly.

The improvement must name immediate consumers and must not become a speculative rewrite.

## Success signal

Over time, a healthy Atlas repository should show:

```text
new variant
→ one obvious extension contract
→ mostly data/registry edits
→ focused regression test
→ normal validation
→ merge
```

instead of:

```text
new variant
→ rediscover architecture
→ touch many services/controllers/remotes
→ duplicate logic
→ broad debugging
→ growing fear of changing anything
```

That difference is the compounding advantage.
