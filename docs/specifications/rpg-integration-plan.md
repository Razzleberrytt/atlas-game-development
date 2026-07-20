# Living Kingdoms — Run-Based RPG Integration Plan

**Document ID:** RPG-PLAN-001  
**Status:** Proposed  
**Target:** Post-HROI gameplay expansion  
**Primary objective:** Turn each operation into a distinct, replayable character-build journey while preserving Living Kingdoms' brutal cooperative survival identity.

## 1. Purpose

Living Kingdoms already contains the foundation of a lightweight action RPG:

- specialist selection;
- independent weapon selection;
- shared Field XP;
- server-generated level-up choices;
- stackable run upgrades;
- enemy loot;
- special-enemy counterplay;
- authoritative combat and mission state.

The current systems do not yet create sufficiently different builds between operations. Most progression modifies firearm statistics, the upgrade pool is narrow, and enemy loot primarily restores ammunition.

This integration adds:

1. meaningful run-build choices;
2. elite enemy modifiers;
3. run-only relics;
4. controlled item-slot pressure;
5. synergies between weapons, specialists, enemy counterplay, and squad behavior;
6. a readable end-of-operation build summary;
7. a clean seam for later permanent unlock progression.

The system must strengthen the active combat loop rather than shift the game toward menus, inventory management, crafting, or gear-score grinding.

## 2. Product decision

### Run-based RPG depth comes first

The first RPG implementation is entirely operation-bound.

Field levels, upgrades, relics, buffs, and elite rewards reset when the operation ends. No player may enter an operation with additional combat power earned through previous play.

Permanent progression remains a later layer and may unlock additional options, sidegrades, cosmetics, codex entries, challenge modifiers, or new starting possibilities. It must not provide paid or grind-based statistical superiority.

### Genre position

The target is:

> **Cooperative isometric survival horror with roguelite RPG builds.**

The target is not:

- a traditional MMORPG;
- a full looter-shooter;
- a crafting survival game;
- an inventory-management simulator;
- a permanent gear treadmill;
- an idle stat-progression game.

## 3. Roadmap authority and sequencing

This specification defines the RPG integration behavior and decomposes it into PR-sized tasks. It does not override the canonical P6–P12 execution roadmap or mark any gameplay milestone complete.

Planning, declarations, and pure invariant fixtures may be prepared while manual gates are pending. Consequential RPG runtime must enter the production sequence only when its dependencies are unblocked and must reuse the existing progression, combat, life, horde, loot, class, objective, and result owners rather than creating parallel authority paths.

Permanent progression begins only after the authoritative match-result loop exists.

## 4. Player experience target

During one normal operation, the player should:

1. select a specialist and firearm before insertion;
2. earn the first Field Level early enough to establish a build direction;
3. encounter at least one elite enemy with readable counterplay;
4. obtain at least one run relic;
5. make at least one decision between immediate survival and longer-term build power;
6. recognize how their weapon, specialist, upgrades, and relics interact;
7. reach the final encounter with a noticeably different build from the one they started with;
8. see a concise summary of their completed build and contribution when the operation ends.

Two players using the same weapon should still be able to develop meaningfully different builds.

## 5. Core RPG pillars

### 5.1 Build identity

Choices should alter how the player approaches combat, not merely increase numbers.

Examples include:

- a shotgun build that rewards close-range multi-target kills;
- an LMG build that becomes stronger during sustained fire;
- a sniper build focused on elite interruption and line penetration;
- a low-ammunition desperation build;
- a support build that gains value from revives, treatment, resupply, or squad proximity.

### 5.2 Immediate readability

Players must understand:

- what an upgrade does;
- why an elite is dangerous;
- when a relic activates;
- what resource or condition powers the effect;
- whether an effect is ready, active, exhausted, or unavailable.

No important effect may depend only on color, sound, or hidden arithmetic.

### 5.3 Meaningful scarcity

The player cannot collect unlimited effects. Relic-slot limits, stack caps, mutually exclusive upgrade branches, bounded proc rates, and global modifier ceilings prevent uncontrolled scaling.

### 5.4 Cooperative value

RPG systems should reward cooperative actions without forcing one rigid squad composition.

Useful triggers may include:

- reviving a teammate;
- treating an injured teammate;
- interrupting a special enemy;
- fighting near another operative;
- defending an objective;
- resupplying an ally;
- surviving a horde pulse together.

### 5.5 Server authority

The server remains the only authority for:

- Field XP and run levels;
- upgrade offers and selection validity;
- elite identity and affixes;
- relic rewards and ownership;
- relic slot capacity and replacement;
- effect activation, cooldowns, charges, counters, and proc rolls;
- damage, healing, armor, movement, reload, and ammunition modifiers;
- loot collection;
- operation reset;
- match results;
- eventual persistent unlocks.

Clients may request a displayed choice and present confirmed results. They may not submit effect values, rarity, proc success, eligibility, damage, healing, XP, loot identity, or ownership.

## 6. Operation build layers

### Layer A — Starting identity

Chosen before insertion:

- specialist;
- firearm;
- future optional sidegrade or starting doctrine.

Specialists and firearms remain independent choices.

### Layer B — Field Upgrades

Earned through Field Levels.

- Three server-generated offers.
- A selected upgrade applies immediately.
- Effects may stack up to a configured limit.
- Upgrades are frequent, predictable, and build-shaping.
- All stacks reset at operation end.

### Layer C — Relics

Earned from elites, special enemies, objectives, and rare reward events.

- More mechanically distinctive than Field Upgrades.
- Normally non-stackable.
- Limited equipped slots.
- May contain conditions, cooldowns, counters, charges, or once-per-operation effects.
- All relic state resets at operation end.

### Layer D — Temporary combat resources

Short-duration effects such as temporary armor, damage surge, fire-rate surge, movement burst, emergency healing, or pickup-radius increase. They do not occupy relic slots and expire after a bounded duration or use count.

## 7. Field Upgrade expansion

Expand the initial pool from four definitions to **12–16 upgrades** while retaining three choices per level.

### 7.1 Upgrade families

#### Firepower

- **Overpressure Rounds** — increased firearm damage.
- **Hair Trigger** — increased automatic fire rate.
- **Cull Protocol** — increased damage against wounded enemies.
- **Pattern Amplifier** — increased secondary shotgun or sniper pattern damage.
- **Specialist Munitions** — increased damage against special and elite enemies.

#### Ammunition and reload

- **Echo Chamber** — chance not to consume ammunition.
- **Combat Loader** — reduced reload duration.
- **Expanded Feed** — increased magazine capacity with a bounded reserve adjustment.
- **Scavenger Reach** — increased automatic loot-collection radius.
- **Last Magazine** — increased damage while reserve ammunition is critically low.

#### Survival

- **Trauma Plating** — temporary armor after leveling.
- **Adrenal Response** — movement increase while critically wounded.
- **Second Pulse** — bounded healing after surviving a horde phase.
- **Rescue Instinct** — increased movement or resistance while approaching an incapacitated ally.

#### Cooperative utility

- **Shared Momentum** — nearby squad kills contribute to a bounded personal combat benefit.
- **Covering Fire** — attacking enemies near a threatened teammate grants a short defensive effect.
- **Field Discipline** — revives, treatment, resupply, and objective contributions grant additional Field XP under strict anti-farming rules.

### 7.2 Offer rules

The server must:

- exclude upgrades already at maximum stacks;
- exclude effects incompatible with the current weapon or state;
- prevent all three offers from belonging to the same narrow family;
- prefer at least one broadly useful option;
- generate offers deterministically from server-owned operation and level facts;
- prevent rerolling through reconnects, replayed requests, or UI reopening;
- preserve the pending offer until one valid selection is accepted.

### 7.3 Branching

V1 does not implement a large skill tree. A small number of mutually exclusive branches may be added later, but branch restrictions must be configuration-driven and visible before selection.

### 7.4 Implementation status (RPG-0103 twelve-upgrade slice)

The centralized RPG-0102 run-build owner holds the live Field Upgrade stacks consumed by `RunProgressionService` / `RunUpgradeResolver` / `RunProgressionConfig`. RPG-0103 implements twelve upgrades under canonical RPG-0101 catalog IDs. Deterministic offer generation removes maxed and weapon-incompatible cards, prefers a broadly useful card, and prevents a three-card mono-family offer whenever a diverse legal pool remains. `RunRpgReconciliation.test` locks catalog identity and shared global ceilings.

| Upgrade | Family | Status | Shipped mechanic vs plan |
|---|---|---|---|
| Overpressure Rounds | Firepower | Implemented | Matches (+damage). |
| Hair Trigger | Firepower | Implemented | Matches (+fire rate). |
| Echo Chamber | Ammunition/Reload | Implemented | Matches (ammo conservation). |
| Cull Protocol | Firepower | Implemented | Matches (wounded-enemy damage). |
| Combat Loader | Ammunition/Reload | Implemented | Matches: reduced reload duration, consumed by `ReloadResolver` at reload begin, floored at the global `minimumReloadDurationMultiplier`. |
| Pattern Amplifier | Firepower | Implemented | Matches: raises shotgun cleave / sniper pierce secondary damage in `DamageResolver`'s pattern path toward full primary damage (effective secondary multiplier capped at 1.0), bounded by the global `maximumPatternDamageMultiplier`. |
| Specialist Munitions | Firepower | Implemented | Matches for existing Screamer, Bloater, and Brute server-owned role facts; RPG-0105 elite identity will extend the same context to elites. |
| Expanded Feed | Ammunition/Reload | Implemented | Matches: raises each firearm's configured magazine capacity while moving only the newly created slot count from reserve, so no ammunition is minted. |
| Scavenger Reach | Ammunition/Reload | Implemented | Matches: adds a bounded radius bonus to the existing automatic server-owned enemy-loot collection pass. |
| Last Magazine | Ammunition/Reload | Implemented | Matches: raises damage only when authoritative reserve rounds are at or below the floored 20% carry-cap threshold. |
| Trauma Plating | Survival | Implemented — **interim mechanic** | Plan: post-level *temporary armor* buffer. Interim: flat bounded squad incoming-damage reduction consumed at the enemy attack source. The temporary-armor form is deferred until a temporary-armor health buffer exists. |
| Field Discipline | Cooperative | Implemented — **interim mechanic** | Plan: bonus Field XP from *cooperative actions* (revive/treatment/resupply/objective) under anti-farming rules. Interim: bounded Field XP bonus on confirmed kills, because cooperative-action XP sources are not yet built (they remain deferred in `run-field-xp.md`). |

The pool now satisfies the RPG-0103 12–16 target. Adrenal Response, Second Pulse, Rescue Instinct, Shared Momentum, and Covering Fire remain `Planned` because movement modifiers, horde-phase survival events, squad-proximity facts, and cooperative threat/action events are not yet available. When any lands it must flip its catalog entry to `Implemented` or `RunRpgReconciliation` fails.

### 7.5 Shared modifier resolution (RPG-0104)

`RunModifierResolver` is the pure shared arithmetic boundary for run-build power. It validates nonnegative finite contributions, supplies immutable neutral defaults, and clamps damage, cadence, reload duration, ammunition conservation and capacity, healing, temporary armor, movement, loot, Field XP, kill-chain, pattern, special-enemy, conditional-damage, incoming-damage-reduction, and general-proc outputs to `RunRpgConfig.ModifierCeilings`. Malformed or unknown contributions fail closed to the complete neutral modifier set.

The twelve RPG-0103 upgrades still own only their configured per-stack contributions. `RunUpgradeResolver` validates server-owned stack facts, accumulates those contributions, and delegates all modifier arithmetic to the shared resolver. Existing attribute names, consumers, and player-facing tuning are unchanged. `RunModifierResolver.test` fixture-locks every ceiling and neutral default; `RunUpgradeResolver.test` exercises the live upgrade pipeline through the real shared resolver.

## 8. Elite enemy affixes

Some otherwise normal enemies become elites. Assignment occurs when the server spawns the enemy; the client cannot request or influence elite creation.

### 8.1 Initial frequency targets

- ordinary pressure: approximately 3–6% of eligible enemies;
- horde pulse: approximately 5–9%;
- maximum simultaneous elites: 3;
- no elite assignment during protected opening seconds;
- no elite combination beyond the encounter-performance budget.

Exact values require Studio evidence and tuning.

### 8.2 Initial affix roster

#### Armored

Reduced damage from a clearly communicated direction or until armor breaks. Armor cannot create total invulnerability, and pattern weapons or squad positioning must provide counterplay.

#### Frenzied

Increased movement and attack cadence, potentially offset by reduced durability. Requires unmistakable posture, trail, icon, or label.

#### Regenerator

Restores health slowly after avoiding confirmed damage for a configured delay. Healing stops when pressure resumes and cannot continue after death or exceed maximum health.

#### Volatile

Begins a short, clearly telegraphed death reaction that creates a bounded danger zone. It must remain mechanically and visually distinct from the existing Bloater.

#### Commander

Grants a bounded benefit to nearby ordinary enemies. The aura ends immediately on death or range exit and cannot stack beyond a strict cap.

### 8.3 Elite restrictions

V1 elites receive exactly one affix. The system rejects:

- affixes incompatible with the enemy role;
- unreadable overlap with existing special mechanics;
- elite assignment to bosses;
- elite spawning beyond simultaneous caps;
- hidden or non-telegraphed damage rules.

### 8.4 Elite rewards

A confirmed elite death may provide:

- increased Field XP;
- improved relic-reward probability;
- improved temporary-resource probability;
- stronger kill punctuation;
- elite contribution credit for participating operatives.

Reward duplication must be impossible after corpse rescans, reconnects, delayed replication, or repeated death events.

## 9. Run Relics

Relics are operation-bound items that meaningfully alter behavior.

### 9.1 Capacity

Initial capacity:

- three equipped relic slots;
- one copy of a relic unless explicitly marked stackable;
- no backpack or reserve inventory;
- a fourth relic forces a keep-or-replace decision;
- replacement destroys the discarded relic for the current operation.

### 9.2 Acquisition

Relics may be awarded by:

- elite enemy rewards;
- special-enemy interruption;
- objective completion;
- authored reward containers;
- rare horde-clear rewards;
- boss or operation milestones.

The server generates the reward and confirms collection.

### 9.3 Initial relic roster

#### Blood Battery

Every configured number of confirmed kills restores a small bounded amount of health. It cannot revive, heal Dead operatives, or exceed maximum health.

#### Grave Momentum

Extends the authoritative kill-chain expiry window by a bounded amount. It awards no direct XP and cannot exceed the configured global streak ceiling.

#### Choir Breaker

Increases damage against enemies performing interruptible special actions. Activation uses server-owned special state, not client-observed animation.

#### Last Light

Provides a bounded damage benefit while authoritative reserve ammunition remains below a configured threshold.

#### Emergency Chamber

Reduces reload duration while critically wounded. It applies only to reloads accepted after the condition begins and preserves the server-owned reload timeline.

#### Salvager's Mark

Improves the chance or value of eligible ammunition drops while preserving active-drop caps and the overall scarcity ceiling.

#### Execution Protocol

Increases damage to enemies below a configured health percentage and shares the global damage ceiling with Cull Protocol.

#### Breach Doctrine

Improves confirmed shotgun secondary impacts without increasing the maximum secondary-target cap.

#### Longwatch Doctrine

Improves confirmed sniper penetration or elite-interrupt value without adding unbounded penetration or exceeding the additional-ray budget.

#### Suppression Engine

Sustained LMG or SMG fire builds a short-lived bounded effect that resets after firing stops and cannot bypass cadence or ammunition authority.

#### Guardian Signal

A legitimate revive or protective class action grants bounded temporary armor. Repeated interruption cannot farm the effect.

#### Second Wind

Prevents one otherwise incapacitating event per operation and leaves the operative at critical health. It cannot prevent scripted terminal failure, trigger after Dead state, or be consumed client-side.

### 9.4 Definition requirements

Every relic definition states:

- stable relic ID;
- display name and description;
- trigger and effect;
- cooldown, charge, duration, or counter;
- compatible weapons or systems;
- maximum stacks;
- server owner;
- reset behavior;
- presentation state;
- failure and exclusion rules.

No relic may rely on an unbounded listener, per-enemy scheduler, unlimited history, or client-declared trigger.

## 10. Relic reward choice flow

Relic rewards normally present **two choices** rather than an unidentified random item.

1. The server confirms an eligible reward event.
2. The server generates two valid relic choices.
3. The choices are stored against the operative, operation generation, and reward sequence.
4. The client displays the choices.
5. The player submits only the reward sequence and chosen relic ID.
6. The server validates that the relic was offered and the request is current.
7. The server equips it or begins replacement selection when slots are full.
8. The server discloses the safe updated relic state.

### Failure behavior

- Combat continues while a choice is pending.
- The panel may not completely obscure combat.
- A configured timeout may use a deterministic safe fallback or preserve the reward until a recovery window.
- Reconnecting cannot generate new choices.
- Simultaneous rewards enter a bounded queue.
- Operation termination clears unresolved choices.

## 11. Synergy and modifier architecture

Synergy should emerge from compatible mechanics, not hidden set bonuses.

Examples:

- shotgun + Breach Doctrine + Blood Battery;
- sniper + Choir Breaker + Grave Momentum;
- LMG + Suppression Engine + Last Light;
- medic + Guardian Signal + Rescue Instinct;
- engineer + Salvager's Mark + Expanded Feed.

All damage, cadence, reload, ammunition, healing, armor, movement, loot, and XP effects must pass through consolidated server-owned modifier resolvers. The implementation must not scatter relic-specific arithmetic across unrelated services.

Recommended pure domains:

- `RunBuildResolver`;
- `DamageModifierResolver`;
- `ReloadModifierResolver`;
- `AmmunitionModifierResolver`;
- `SurvivalModifierResolver`;
- `LootModifierResolver`;
- `ContributionRewardResolver`.

Each resolver accepts immutable server-owned facts, returns bounded deterministic results, enforces global ceilings, and exposes modifier reasons for tests and diagnostics.

## 12. UI and presentation

### 12.1 Combat HUD

The always-visible HUD should show:

- current Field Level and XP progress;
- equipped relic icons;
- limited charges or cooldowns;
- temporary armor and active buffs;
- elite warning and affix name;
- concise relic activation feedback.

### 12.2 Build panel

A compact optional panel may show specialist, firearm, upgrade stacks, equipped relics, active synergies, and plain-language effect descriptions. It does not pause combat.

### 12.3 World presentation

Elite enemies require redundant identification through at least two of:

- silhouette attachment;
- world-space label;
- icon;
- material or pattern;
- animation or posture;
- effect shape;
- audio cue.

Color alone is insufficient.

Relic rewards require a readable name, concise effect summary, confirmed selection feedback, and bounded world/UI objects.

## 13. Match-result integration

Before permanent progression exists, the authoritative result screen should display:

- final Field Level;
- selected specialist and firearm;
- upgrade stacks;
- equipped relics;
- elites defeated;
- special attacks interrupted;
- revives and class contributions;
- objective contribution;
- peak kill chain;
- operation outcome.

The result screen must clearly state that the build was operation-bound.

## 14. Future permanent progression seam

Permanent progression begins only after one authoritative match result exists.

Future persistence may unlock:

- additional relics entering the possible reward pool;
- additional sidegrade upgrades;
- new specialists;
- new firearms or firearm sidegrades;
- challenge modifiers;
- codex entries;
- cosmetic rewards;
- alternate starting doctrines.

Permanent progression must not grant direct universal damage, permanent health advantages, paid combat power, unlimited starting ammunition, grind-only superior versions of the same weapon, or mandatory upgrades required for standard completion.

A new account must remain capable of completing the operation through skill, cooperation, and run choices.

## 15. Implementation sequence

### RPG-0101 — Define RPG contracts and configuration — **Complete (PR #142)**

Create stable definitions for relic IDs, affix IDs, modifier categories, effect triggers and states, reward sequences, slot and replacement states, rejection reasons, safe snapshots, and global modifier ceilings. No runtime behavior.

Delivered as `RunRpgContracts` and `RunRpgConfig` with declaration-only invariant fixtures (`RunRpgContractsConfig.test`, `RunRpgRewardSourceConfig.test`). The upgrade-ID vocabulary shares the live HROI namespace, so the four original run upgrades plus the newly implemented Trauma Plating, Field Discipline, and Combat Loader are marked `Implemented` in the catalog; the rest remain `Planned`. `RunRpgReconciliation.test` binds the live HROI run-progression pool to this catalog and its global ceilings (see §7.4).

**Exit:** Frozen vocabulary and invariant fixtures pass. ✔

### RPG-0102 — Centralize run-build state — **Complete**

Add one server-owned run-build owner for each operative. State includes upgrade stacks, equipped relics, charges, cooldowns, counters, pending reward choices, replacement state, and operation generation. Integrate existing Field Upgrade state rather than creating a parallel owner.

Delivered as the pure `RunBuildStateStore` behind the server-only `RunBuildService`. One operation generation owns a bounded record for each of the four admitted operatives; disconnect retains the record for same-operation reconnect, while operation reset and teardown erase it. The live shared Field Upgrade stacks moved out of `RunProgressionService` and commit through this owner with bounded request replay protection. Three empty relic slots establish the future charge, cooldown, counter, reward, and replacement state boundary without activating relic behavior or adding a client remote.

**Exit:** Reset, disconnect/reconnect, replay, stale-generation, duplication, population-bound, copied-snapshot, and teardown fixtures pass. ✔

### RPG-0103 — Expand Field Upgrade pool — **Complete**

Add the first 12–16 upgrade definitions and compatibility filtering. Do not add elites or relics yet.

Delivered as the twelve-upgrade v5 pool. Four new functional cards add special-role damage, ammunition-conserving magazine growth, automatic loot reach, and low-reserve damage. Server-owned squad weapon facts filter Pattern Amplifier from incompatible rosters; deterministic fixtures lock max-stack removal, broad-choice preference, and family diversity. No elite identity, elite assignment, relic, reward, persistence, or client authority was added.

**Exit:** Level-up offers create distinct but bounded early builds without invalid choices. ✔

### RPG-0104 — Add modifier resolver framework

Centralize bounded calculation for damage, cadence, reload duration, ammunition conservation and capacity, healing, armor, movement, loot, and XP bonuses. Migrate existing run-upgrade calculations into the shared pipeline.

**Exit:** Existing behavior remains compatible and every modifier ceiling is fixture-locked.

### RPG-0105 — Add elite identity and one affix

Implement the elite framework with **Frenzied** as the first vertical slice, including server assignment, replicated safe identity, bounded behavior modification, readable presentation, elite XP reward, and cleanup coverage.

**Exit:** Frenzied elites are unmistakable, consequential, and bounded.

### RPG-0106 — Complete initial elite roster

Add Armored, Regenerator, Volatile, and Commander. One affix per elite in v1.

**Exit:** Every affix has readable counterplay and role compatibility rules.

### RPG-0107 — Add relic reward and slot framework

Implement relic definitions, three equipped slots, two-choice rewards, pending reward storage, replacement flow, safe snapshots, and operation reset. Start with passive relics that consume existing server facts.

**Exit:** Relics cannot duplicate, reroll through reconnects, exceed slots, or survive operation teardown.

### RPG-0108 — Add first six relics

Recommended first batch: Blood Battery, Grave Momentum, Choir Breaker, Last Light, Emergency Chamber, and Execution Protocol.

**Exit:** At least three clearly different viable build patterns emerge.

### RPG-0109 — Add weapon and cooperation relics

Add Salvager's Mark, Breach Doctrine, Longwatch Doctrine, Suppression Engine, Guardian Signal, and Second Wind. This task depends on the relevant class and result boundaries being available.

**Exit:** Weapon identity and cooperative contribution materially affect build direction.

### RPG-0110 — Integrate elite and objective reward sources

Relic rewards may originate from elite kills, special interruption, authored objectives, horde milestones, and boss milestones. Every source receives deterministic reward IDs and anti-duplication coverage.

**Exit:** Rewards are frequent enough to matter without overwhelming scarcity.

### RPG-0111 — Add complete RPG HUD and build panel

Add the relic bar, charge/cooldown state, elite affix presentation, reward-choice interface, replacement interface, build summary panel, and activation feedback.

**Exit:** Players can explain their current build without developer tools.

### RPG-0112 — Add operation-result build summary

Connect final build and contribution facts to the authoritative match result. No persistent XP is awarded in this task.

**Exit:** Success and failure screens explain the completed run build.

### RPG-0113 — Balance, security, and multiplayer validation

Validate solo and 2/4-player squads, every firearm, duplicate specialists, low-ammunition conditions, elite overlap, relic replacement, reconnects, death and revival, operation restart, squad wipe, forged choices, replayed selections, stale generations, modifier ceilings, and performance under representative horde load.

**Exit:** RPG integration is secure, readable, performant, and produces multiple viable run builds.

## 16. Execution order and high-ROI checkpoint

`RPG-0101` → `RPG-0102` → `RPG-0103` → `RPG-0104` → `RPG-0105` → `RPG-0106` → `RPG-0107` → `RPG-0108` → `RPG-0109` → `RPG-0110` → `RPG-0111` → `RPG-0112` → `RPG-0113`

The highest-ROI playable checkpoint is **RPG-0101 through RPG-0108**. At that point the game has expanded Field Upgrades, elites, three relic slots, reward choices, and six meaningful relics without waiting for persistence or the complete content roster.

## 17. Performance budgets

Initial constraints:

- maximum three simultaneous elites;
- maximum one affix per enemy;
- maximum three equipped relics per operative;
- maximum two relic choices per reward;
- maximum three queued unresolved rewards;
- no per-relic frame loops;
- no per-relic Heartbeat connections;
- no per-enemy affix scheduler;
- no unbounded kill or event history;
- no relic-created raycast loops;
- no client-originated proc requests;
- no new damage or health remote;
- no permanent world-loot accumulation.

Effects should evaluate through existing combat, horde, life, objective, and reward passes wherever possible.

## 18. Security requirements

Tests must reject:

- selecting a relic that was not offered;
- selecting after the reward expired or operation changed;
- selecting for another operative;
- replaying a completed reward;
- equipping more than the slot cap;
- retaining discarded relic effects;
- forging charges or cooldown completion;
- client-declared elite identity;
- client-declared proc success;
- duplicate XP from corpse rescans;
- duplicate relic rewards from one elite;
- reconnect-based offer rerolls;
- prohibited effects continuing after death;
- effects continuing after operation teardown;
- arithmetic exceeding global modifier ceilings.

## 19. Balance rules

Initial global ceilings:

- total damage multiplier: no more than 3×;
- cadence multiplier: preserve the existing minimum cadence floor;
- ammunition-conservation chance: no more than 50%;
- movement increase: no more than 35%;
- reload reduction: no more than 50%;
- temporary armor: no more than 40% of maximum health;
- kill-chain extension: no more than 2 additional seconds;
- automatic healing cannot replace medic or resource-based recovery;
- proc chance is normally no more than 35% unless charge-limited.

These are starting constraints, not final tuning claims.

A build must not require one exact relic to remain viable. Relics may make a strategy stronger, safer, or more expressive, but standard operation completion must remain possible without receiving a particular random reward.

## 20. Acceptance criteria

The RPG integration is successful when:

- the first meaningful build choice appears early in normal combat;
- an operation normally produces at least two meaningful RPG decisions;
- players can identify elite behavior before or shortly after engagement;
- relics change decisions rather than only increasing background statistics;
- at least three distinct build patterns are viable;
- the same firearm can support multiple builds;
- specialist contributions interact with RPG rewards without becoming mandatory;
- reward selection remains fully server-authoritative;
- no build survives operation reset;
- no modifier exceeds configured ceilings;
- no reward can be duplicated through reconnect, replay, corpse observation, or remote abuse;
- the HUD communicates active effects without obscuring combat;
- representative horde performance remains within the established quality-tier budget.

## 21. Explicit non-goals

The first RPG integration does not include:

- permanent character levels or stat increases;
- gear score;
- equippable armor pieces;
- weapon rarity tiers or random weapon-stat rolls;
- crafting, vendors, currencies, or trading;
- item durability;
- stash storage;
- large inventory grids;
- procedural skill trees;
- battle passes or paid power;
- daily-login combat bonuses;
- dozens of affixes;
- multi-affix enemies;
- unlimited relic stacking.

## 22. Success metric

The primary qualitative test is:

> After completing an operation, can the player describe what their build became, which choices caused it, and how it changed the way they fought?

Useful balancing and validation signals include:

- Field Level reached;
- upgrade selections by family;
- relic selection and replacement rates;
- elite kill and interruption rates;
- relic activation frequency;
- damage and survival contribution by effect;
- ammunition economy by build;
- unused or consistently rejected choices;
- operation success rate by weapon/build combination;
- modifier-cap encounters;
- reward duplication or rejection counts;
- server evaluation cost under representative horde load.

These signals support balancing and validation, not monetized optimization.

## 23. Final product boundary

Living Kingdoms should feel deeper because the player develops a dangerous, improvised combat doctrine during each operation.

It should not feel as though the player stopped surviving a horror operation to organize a spreadsheet.
