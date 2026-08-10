# Effect Owner Routing

## Purpose

Repeated gameplay effects should become cheaper to add because agents should not rediscover authority ownership for damage, reload, health, movement, or abilities on every task.

The machine-readable authority map is:

`config/efficiency/effect-owner-routes.json`

The inspection/validation tool is:

```bash
python scripts/effect_routes.py validate
python scripts/effect_routes.py list
python scripts/effect_routes.py show DamagePercent
python scripts/effect_routes.py next
```

## Core rule

An equipment-affix effect is not allowed to exist as an untracked semantic. Every effect ID declared by `EquipmentAffixContracts.luau` must have exactly one route entry.

Each route records:

- effect ID;
- routing status;
- capability;
- authoritative owner;
- composition seam;
- shared adapter, once one exists;
- authoritative equipped-item selector;
- focused regression tests;
- risk tier;
- the normal extension rule.

## Status ladder

### `unresolved`

The effect vocabulary exists, but the canonical owner has not yet been confirmed. Do not implement the live effect yet. Resolve the existing server authority first and update the registry.

### `owner-confirmed`

The existing authoritative owner and composition seam are known. The next coherent task is normally one bounded pure adapter plus focused wiring/regression coverage through that owner.

### `live`

The effect is already routed through its canonical authority. New ordinary affix definitions using that effect should normally be data/configuration plus focused regression coverage rather than new runtime wiring.

## Why this compounds

Without a route registry, each new modifier causes repeated archaeology:

```text
find effect vocabulary
→ search runtime
→ guess owner
→ inspect remotes
→ rediscover tests
→ decide where to wire
```

With the registry:

```text
python scripts/effect_routes.py show <EffectId>
→ use named owner/seam/adapter/tests
→ add the smallest coherent change
```

That converts architectural rediscovery into a constant-time lookup and makes ownership drift mechanically visible.

## Extension rules

1. Never create a second owner because an affix needs a consequence.
2. Never let the client submit effect values, multipliers, cooldowns, health, movement, or other consequential facts.
3. If a route is `unresolved`, owner discovery is the task; implementation waits until the owner is named.
4. If a route is `owner-confirmed`, create one generic bounded adapter where possible, then wire it through the existing owner.
5. If a route is `live`, ordinary variants should reuse it. Repeated runtime edits for the same effect are a leverage smell.
6. Update routing status only when the source implementation proves the new state.
7. Keep focused tests named in the registry so the next agent knows the cheapest relevant regression surface.

## Current Patch 0.3 route order

`DamagePercent` is the first live reference implementation.

`ReloadSpeedPercent` is the next owner-confirmed route because `ReloadResolver.luau` already owns authoritative reload duration and `RelicModifierService.luau` is already the server composition seam for per-operative modifiers.

The remaining effect types stay explicitly unresolved until their existing authoritative owners are confirmed. That is intentional: the registry should remove guessing, not encode it.

## Relationship to extension-cost contracts

Extension-cost contracts answer: **how expensive should another member of this family be?**

Effect-owner routes answer: **where does this semantic belong?**

Use both when applicable:

```text
route registry → correct owner/seam
extension contract → expected change surface
validation → enforce both over time
```
