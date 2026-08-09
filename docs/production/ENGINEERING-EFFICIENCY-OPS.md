# Living Kingdoms — Engineering Efficiency Operations

**Status:** ACTIVE OPERATING PLAYBOOK  
**Adopted:** 2026-08-09

This is the executable companion to `docs/roadmap/DEVELOPMENT-FLYWHEEL.md`. The flywheel defines policy; this document defines the tools and cadence that make it operational.

## 1. Agent bootstrap

At the start of an implementation session, the agent can run:

```bash
python scripts/efficiency.py bootstrap
```

This prints the minimum read path and extracts the current `NOW` section from the execution dashboard. It is intentionally small; agents should not preload the full documentation stack.

## 2. Capability registry

The machine-readable registry lives at:

```text
config/efficiency/capabilities.json
```

Inspect it with:

```bash
python scripts/efficiency.py registry
```

Each stable capability records its owner, maturity, extension points, known consumers, test surface, and whether future variants are intended to become data-driven.

Update the registry when a PR creates a durable reusable owner/seam, materially changes an extension point, or retires a capability. Do not register every helper or one-off module.

## 3. Automated leverage audit

Run:

```bash
python scripts/efficiency.py audit
```

For machine processing:

```bash
python scripts/efficiency.py audit --json
```

The audit currently surfaces:

- large/growing source-owner hotspots;
- substantial cross-file repeated lines as possible generalization candidates;
- remote construction outside canonical networking as an authority review target;
- directional source/test ratios;
- architecture directories not represented by capability extension points.

Audit findings are **candidates, not commands**. A finding is permission to inspect, not permission to refactor. Dependency order, player value, authority, and evidence gates remain controlling.

## 4. Roadmap/task ROI scoring

Use the scorer only when two or more tasks are already similarly valid by dependency order and player value:

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

Every dimension is 0–2. Player value and dependency removal are weighted far above leverage, so the score cannot rationally justify skipping a real blocker for architecture work. Leverage breaks close calls.

## 5. Development telemetry

Use local git history to find repeated-touch and churn hotspots:

```bash
python scripts/dev_metrics.py
```

or:

```bash
python scripts/dev_metrics.py --days 30 --json
```

Repeated high touch plus high churn is evidence to inspect ownership, tests, data conversion, or tooling. It is not evidence by itself that a file should be split.

This gives the project development telemetry without requiring a new external service or committed mutable metrics database.

## 6. Definition/schema scaling rule

Do not create a universal generator before a schema is proven. For a content family (weapons, enemies, effects, loot, quests, encounters, routes):

1. first implementation proves behavior;
2. second/third implementation identifies the repeated fields/invariants;
3. the repeated shape moves into a validated definition/config module;
4. add or extend a repository validator for IDs/references/ranges;
5. only then add a scaffold/generator if authoring the definitions remains repetitive.

This keeps "automation" from becoming a speculative framework while still guaranteeing the path toward mostly declarative content.

## 7. Regression-defense rule

A meaningful bug should normally close with one of:

- a focused Lune regression fixture;
- a source/wiring validator;
- a schema/invariant check;
- a lifecycle/evidence assertion where engine behavior is required.

If none is practical, document why in the PR completion report. Repeated defects of the same class escalate the missing defense to a leverage task.

## 8. Bounded leverage-pass triggers

Run the audit/telemetry and consider a dedicated leverage pass when:

- a pattern reaches its third real implementation;
- a failure class repeats;
- the same mechanical agent step recurs across tasks;
- a file/owner is repeatedly a high-touch/high-churn bottleneck;
- a patch is about to scale content breadth;
- a patch boundary provides a low-risk consolidation point.

A leverage pass must name its immediate consumers and remain small enough to validate coherently.

## 9. Continuous validation

The efficiency construct itself is checked by:

```bash
python scripts/validate_efficiency_construct.py
```

It is also wired into the unified repository validation entry point, so missing registry extension points, invalid capability schema, or disconnected operating instructions fail normal validation rather than silently decaying.

## 10. Expected maturity curve

Success is not "more abstractions." Success is a declining marginal cost for proven content families and fewer repeated failures.

Track qualitative movement in these directions:

```text
bespoke behavior → stable owner → repeated shape → validated data → cheap variants
bug → root cause → regression defense → failure class becomes rarer
manual repeated step → deterministic tool → agent no longer rediscovers/repeats it
unclear ownership → registered capability → known extension point → safer autonomous change
```

Patch 0.9 should be where the accumulated investment becomes obvious: new breadth should be primarily data/content authoring plus automated validation rather than new bespoke authority code.
