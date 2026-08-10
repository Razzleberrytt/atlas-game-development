# Living Kingdoms — Engineering Efficiency Operations

**Status:** ACTIVE OPERATING PLAYBOOK  
**Adopted:** 2026-08-09

This is the executable companion to `docs/roadmap/DEVELOPMENT-FLYWHEEL.md`. The flywheel defines policy; this document defines the tools and cadence that make it operational.

## 1. Agent bootstrap

At the start of an implementation session:

```bash
python scripts/efficiency.py bootstrap
```

This prints the minimum read path and current NOW section. Agents should not preload the full documentation stack.

## 2. Capability registry

The reusable-owner registry lives at:

```text
config/efficiency/capabilities.json
```

Inspect it with:

```bash
python scripts/efficiency.py registry
```

Register durable owners/seams, not every helper. A capability records ownership, extension points, consumers, tests, maturity, and whether future variants should become data-driven.

## 3. Extension-cost contracts

Repeated feature/content families use:

```text
config/efficiency/extension-contracts.json
```

The contract answers the practical question: **how should the next one of these be added cheaply and safely?**

Use:

```bash
python scripts/extension_cost.py list
python scripts/extension_cost.py show <contract-id>
python scripts/extension_cost.py check <contract-id> --base main
```

The check measures implementation-file surface, server-authority touches, and whether the branch escaped the registered extension path.

A non-zero budget result is a deliberate review point:

- if the change introduces a genuinely new semantic, escalate and explain it;
- if it is merely another normal variant, inspect/improve the reusable seam before accepting permanent complexity growth.

See `docs/production/EXTENSION-COST-MODEL.md`.

## 4. Automated leverage audit

Run:

```bash
python scripts/efficiency.py audit
```

For machine processing:

```bash
python scripts/efficiency.py audit --json
```

The audit surfaces large/growing owners, substantial repeated code shapes, remote-construction review targets, source/test direction, and capability-registry gaps. Findings are candidates, not automatic refactor orders.

## 5. Roadmap/task ROI scoring

Use only when candidates are already similarly valid by dependency order and player value:

```bash
python scripts/efficiency.py score "candidate name" \
  --player-value 2 \
  --dependency-removal 1 \
  --near-term-reuse 2 \
  --future-effort-reduction 2 \
  --risk-reduction 1 \
  --data-scalability 2 \
  --agent-autonomy 1
```

Player value and dependency removal remain dominant; leverage breaks close calls.

## 6. Development telemetry

Use git history to surface repeated-touch/high-churn hotspots:

```bash
python scripts/dev_metrics.py
```

or:

```bash
python scripts/dev_metrics.py --days 30 --json
```

High touch + high churn is a signal to inspect ownership, tests, data conversion, or tooling—not proof that a file must be split.

## 7. Definition/schema scaling rule

For a content family (weapons, enemies, effects, loot, quests, encounters, routes):

1. first implementation proves behavior;
2. second/third implementation reveals the repeated shape;
3. move the common shape into a validated definition/config module;
4. register the canonical extension contract and a realistic file/authority budget;
5. add validators for IDs/references/ranges;
6. add a scaffold/generator only if definition authoring is still materially repetitive.

The target is not “more automation.” It is **declining marginal cost**.

## 8. Regression-defense rule

A meaningful bug should normally close with one of:

- focused Lune regression fixture;
- source/wiring validator;
- schema/invariant check;
- lifecycle/evidence assertion where engine behavior is required.

Repeated defects of the same class escalate the missing defense to leverage work.

## 9. Bounded leverage triggers

Consider a bounded leverage pass when:

- a pattern reaches its third implementation;
- a normal extension exceeds its contract review threshold more than once;
- a data-first variant repeatedly touches server authority;
- the same mechanical agent step recurs;
- a failure class repeats;
- a file/owner is repeatedly high-touch/high-churn;
- a patch is about to scale content breadth.

The pass must name immediate consumers and remain small enough to validate coherently.

## 10. Continuous validation

The efficiency construct is checked by:

```bash
python scripts/validate_efficiency_construct.py
```

It is wired into the unified repository validator, so disconnected instructions, invalid capability/extension schemas, missing canonical paths, or broken operating hooks fail normal validation rather than silently decaying.

## 11. Expected maturity curve

```text
bespoke behavior
→ stable owner
→ repeated shape
→ registered extension contract
→ validated data/registry path
→ cheap variants
```

Alongside:

```text
bug → root cause → permanent regression defense
manual repeated step → deterministic tool
unclear ownership → registered capability → known extension path
```

Patch 0.9 should cash in the accumulated work: new breadth should mostly be data/content authoring plus automated validation rather than bespoke authority code.
