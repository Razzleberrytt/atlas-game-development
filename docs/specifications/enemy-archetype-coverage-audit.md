# Enemy-archetype coverage audit — BA-040

## Decision summary

This documentation-only E1 audit compares every hostile archetype/layer in the current source on three axes:

- **pressure** — the distinct tactical problem it creates;
- **counter** — what a player can read and do in response; and
- **readability** — whether source-managed presentation communicates the real mechanic.

The direct runtime/config review corrects an earlier documentation-only assumption: Runner, Screamer, Bloater, and Brute all have source-proven mechanics beyond presentation. Crawler is faster than the baseline and visually distinct, but its “stalking” identity has no separate ambush, detection, or target-selection behavior in the current owner.

No runtime, enemy authority, balance value, spawn rule, or presentation code changes in this task.

## Scope and evidence

Primary source:

- `EnemyContracts.luau`, `EnemyConfig.luau`, and `EnemyDirectorService.luau`;
- `HordeExperienceConfig.luau` and `HordeExperienceService.luau`;
- `HordeRolePresentationConfig.luau`;
- `HordeSpecialTelegraphConfig.luau`;
- `SpecialEnemyContracts.luau`, `SpecialEnemyConfig.luau`, and the boss contracts/config;
- `RunRpgConfig.luau` and `EliteAffixResolver.luau`.

Companion specifications:

- [`enemy-pressure-runtime.md`](enemy-pressure-runtime.md);
- [`horde-role-readability.md`](horde-role-readability.md);
- [`horde-special-role-telegraphs.md`](horde-special-role-telegraphs.md);
- [`special-enemy-and-boss-encounter.md`](special-enemy-and-boss-encounter.md);
- [`rpg-integration-plan.md`](rpg-integration-plan.md).

Source/runtime shape outranks stale prose. In particular, the current Screamer reinforcement count is the value in `HordeExperienceConfig`, even where an older specification sentence describes a larger count.

## Disposition vocabulary

- **KEEP** — the pressure/counter/readability triad is coherent in current source.
- **REFINE** — a real distinction exists, but the mechanic, counter, or presentation promise is too thin or mismatched.
- **MISSING** — no distinct mechanic or readable counter exists.

## Coverage matrix

| Archetype / layer | Pressure | Counter | Readability | Disposition |
| --- | --- | --- | --- | --- |
| `enemy.exclusion_walker` | Baseline roam/pursue/attack pressure with escalation cadence and population caps | Maintain distance, reposition, and focus targets before melee contact | Baseline walker silhouette and attack motion | **KEEP** — reference baseline |
| `horde.role.infected` | Standard horde body at SpeedFloor 12 and ordinary spawn weight | Baseline focus fire and spacing | `standard-hollow` role profile | **KEEP** — horde baseline |
| `horde.role.runner` | SpeedFloor 19 versus baseline 12 creates fast gap-closing pressure | Prioritize early, maintain escape space, avoid treating it like an ordinary walker | Narrow `razor-sprinter` silhouette, orange sensor, five-stride presentation | **KEEP** — mechanic and presentation agree |
| `horde.role.crawler` | SpeedFloor 16 versus baseline 12; otherwise follows the same owned movement/attack path | Current counter is still ordinary spacing/focus fire; no ambush or detection rule changes the decision | Low purple `grave-low-crawl` posture strongly suggests stalking/ambush behavior | **REFINE** — real speed distinction, but the presentation promise is broader than the mechanic |
| `horde.role.screamer` | Periodic server-owned reinforcement windup/commit while alive | Kill during the 1.25-second windup to cancel the summon | Yellow pulsing disc, countdown text, audio, and stable attributes | **KEEP** — complete interruptible special |
| `horde.role.bloater` | On-death 20-stud, 18-damage burst after a 0.85-second warning | Leave the disclosed radius before commit | Green radius disc, countdown text, corpse-anchored warning, audio | **KEEP** — complete positioning special |
| `horde.role.brute` | Slow heavy body with a telegraphed one-time second phase after first death | Account for phase two and reposition during the 0.9-second reanimation warning | Heavy red silhouette plus `BRUTE REANIMATING` radius/countdown/audio | **KEEP** — second phase is source-proven and bounded |
| `enemy.blight_spitter` | Ranged Corrosive Bloom area denial forces spread/relocation | Spread, reposition, or kill during the interruptible windup | Ground disc, countdown, label, and distinct silhouette | **KEEP** — complete pressure/counter/readability triad |
| `boss.progenitor` | Three-phase escalation: Carapace, Brood, Collapse | Burst during exposure, clear adds, and use the floodlight-repair payoff in Collapse | Redundant phase/action telegraphs and always-visible boss state | **KEEP** — complete boss triad; Studio mix/performance evidence remains separate |
| `elite-affix.armored` | Finite extra armor pool | Focus through the pool before ordinary health | Stable affix identity and enemy presentation facts | **KEEP** |
| `elite-affix.frenzied` | Increased movement/cadence with reduced durability | Prioritize the faster but less durable target | Distinct affix presentation; role incompatibility prevents Runner overlap | **KEEP** |
| `elite-affix.regenerator` | Sustain after four uninterrupted seconds without confirmed damage | Maintain pressure or burst before regeneration resumes | Stable affix presentation and bounded heal cadence | **KEEP** |
| `elite-affix.volatile` | Delayed death nova | Leave the disclosed danger area after the kill | Stable Volatile identity and delayed reaction | **KEEP** |
| `elite-affix.commander` | Bounded movement/cadence aura for nearby eligible enemies | Kill the Commander or break aura range | Stable Commander identity; one aura stack maximum | **KEEP** |

## Findings

1. **Five of six horde roles have a coherent current identity.** Basic is the baseline; Runner changes closing speed; Screamer summons; Bloater punishes corpse proximity; Brute returns for a second phase. Their source-managed silhouettes and telegraphs describe real mechanics.
2. **Crawler is the only thin role.** Its SpeedFloor 16 is a real mechanical difference, but the low “stalking” presentation implies an ambush/detection question that the shared movement/attack owner does not implement. A future decision should either add one small bounded canonical behavior or soften the presentation/name promise.
3. **Brute was incorrectly classified as presentation-only in the initial audit pass.** `HordeExperienceConfig.SecondPhase`, `HordeExperienceService`, `HordeSpecialTelegraphConfig`, and the dedicated telegraph specification prove the second-phase consequence and its warning.
4. **The horde special path remains single-owner and bounded.** `HordeExperienceService` owns assignment and consequences; warnings use replicated attributes, one shared evaluation pass, fixed client pools, and no client authority.
5. **Spitter, Progenitor, and the five elite affixes have the strongest end-to-end coverage.** Their mechanics, counters, restrictions, cleanup, and safe presentation are explicit in source and fixtures. Studio readability/performance acceptance remains a separate evidence gate.
6. **Threat display values are not a separate gameplay mechanic.** `HordeThreatValue` is disclosed as an attribute, while global horde pressure is derived from elapsed time, living population, and kills. This audit does not use role Threat values to claim mechanical differentiation.

## Ordered follow-up

1. Make an explicit Crawler identity decision before BA-041 changes runtime: either accept “faster low-profile body” as sufficient and align naming/presentation, or authorize one bounded behavior through `HordeExperienceService`/the canonical enemy owner with focused tests and Studio evidence.
2. Reconcile the stale Screamer reinforcement count in descriptive prose with the current configured value in a separately scoped documentation cleanup; do not change balance merely to match prose.
3. Run the outstanding representative Studio readability, mix, and performance matrices before promoting visual/gameplay evidence.

## Completion boundary

BA-040 is complete when this source-backed matrix identifies the one remaining role-identity weakness without creating a new EnemyService or changing runtime behavior. It does not authorize a Crawler mechanic, role rebalance, new archetype, or evidence promotion.
