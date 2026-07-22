# Special enemy and boss encounter — P9-PLAN-001

The plan for P9. It adds **one special enemy** that disrupts the squad's most
reliable tactic and **one authored boss climax** that tests the lessons the
operation has already taught — movement and relocation (P1), darkness and
positioning (P4), the three classes (P7), the authored objective route (P8),
ammunition scarcity (P6), and teammate rescue (P3).

This document is the planning gate. It fixes the disrupted tactic, the special
enemy's ability and counterplay, its telegraphs and spawn policy, the boss's
phases, arena, objective connection, class contributions, failure readability,
accessibility, and performance budgets. It does **not** add code, contracts, or
configuration — those are `P9-0101` through `P9-0106`. Every constant named here
is authoring intent for the first pass, tunable from evidence in P12.

## Design constraints inherited from the milestone

- **Reuse, do not rebuild.** The production enemy owner
  (`EnemyDirectorService` + `EnemyBehaviorResolver` + `EnemyContracts` /
  `EnemyConfig`, see [`enemy-pressure-runtime.md`](enemy-pressure-runtime.md))
  already owns enemy identity, fair spawning, health, movement intent, melee
  attacks through the P3 damage boundary, death, corpse cleanup, and stand-down
  on a single bounded evaluation pass. The special enemy is a **new director
  archetype**, and the boss is **one director-owned instance**. There is no
  second enemy runtime — the parallel-P5 "two enemy runtimes cannot share the
  mission" failure recorded in the master roadmap is not repeated.
- **Server owns every enemy fact.** There is no enemy remote surface. Clients
  see the special enemy, the boss, their telegraphs, and their adds only as
  ordinary server-owned replicated Workspace instances and replicated model
  attributes, exactly as the walker and the horde special-role telegraphs do
  today (see [`horde-special-role-telegraphs.md`](horde-special-role-telegraphs.md)).
- **One terminal failure.** P9 adds **no new terminal-failure cause**. The only
  ways the operation ends in failure remain a committed squad wipe after its
  grace window and authoritative abandonment, exactly as today. The boss adds a
  terminal *success* path (its defeat resolves the holdout) but routes through
  the existing single first-commit-wins mission boundary that P8 preserved and
  P10 will formalize. A missed telegraph, a lost exposure window, or a bad
  positioning read is a setback the squad recovers from, never an instant loss.
- **Disclosure stays within P4.** Telegraphs may show a dangerous action's
  position, area, timing, and identity once the action is committed to. They may
  not reveal an undisclosed enemy early, expose hidden threats, or legalize a
  client-predicted hit. The special enemy and the boss are only visible under the
  existing darkness engagement bound until they close to it.
- **Respect prior decisions.** The boss encounter reads facts the squad already
  produced — most concretely the P8 optional floodlight repair — and rewards or
  penalizes those choices through readability, never through a hidden stat wall.

## What this is *not* — relationship to the parallel tracks

Two cross-cutting tracks already put "special" enemies on screen; P9 is neither,
and P9 does not modify either:

- **HROI horde roles** (Choir Screamer, Rot Bloater, Grief Brute, Razor Runner,
  Grave Crawler, Hollow Infected) are a *presentation-and-consequence layer*
  owned by `HordeExperienceService` over the shared Exclusion Walker shell
  (see [`horde-role-readability.md`](horde-role-readability.md) and
  [`horde-special-role-telegraphs.md`](horde-special-role-telegraphs.md)). They
  are population flavour and one-shot consequences, not a distinct director
  archetype.
- **RPG elite affixes** (Frenzied, Armored, Regenerator, Volatile, Commander)
  are a *roguelite modifier layer* owned by `EliteAffixResolver`
  (see [`rpg-integration-plan.md`](rpg-integration-plan.md)). They decorate
  ordinary hostiles with bounded modifiers and relic-reward hooks.

The P9 **special enemy** is a first-class canonical director archetype with its
own health, body, and telegraphed ability — a genuinely new hostile the squad
must learn, not a re-skin of a walker. The P9 **boss** is a unique
director-owned instance with authored phases. P9 reuses the telegraph
*mechanism* proven by the horde special-role warnings (fixed presentation pool,
replicated commit-timestamp attributes, no new remote) but owns its own
authority. Keeping these three tracks separate is a hard rule: the special
enemy and boss never route their consequences through `HordeExperienceService`
or `EliteAffixResolver`, and those services are not touched by P9.

## Part A — The special enemy

### The reliable tactic being disrupted

In the current build the dominant, low-risk tactic is **turtle-and-autofire**:
the squad clusters tightly on one piece of authored cover (the roadblock convoy
during the booster hold, the lookout deck, the center of the extraction
clearing), lets the server-owned automatic combat mow the horde as it funnels
into the 60-stud darkness engagement radius, and leans on medics and revives to
outlast the wave. Because targeting, fire, and threat priority are all
automatic, a stationary clustered ball is the safest configuration: overlapping
fields of auto-fire, short revive distances, and no exposure from repositioning.
This quietly undercuts the operation's relocation theme — the squad that never
moves is the squad that wins.

### The special enemy — the **Blight Spitter**

A bloated, fungal-infected hostile (archetype `enemy.blight_spitter`) that does
not melee like the walker. It keeps its distance and, on a telegraphed cadence,
lobs a **Corrosive Bloom** onto the *densest cluster of operatives* — a short
area-denial hazard that damages and then briefly lingers on the ground it lands
on. It directly punishes standing clustered on held ground and rewards spreading
out and relocating: exactly the behaviors the operation is built around.

The Spitter is deliberately not a walker re-skin. It is slower and squishier in
melee terms but ranged, so ignoring it while it plants blooms on your firing
position is a mistake, and rushing it out of position is itself a relocation.

#### The Corrosive Bloom ability (for `P9-0101`)

A pure, deterministic ability with an explicit lifecycle mirroring the walker's
attack windup vocabulary (`None → Begin → Continue → Commit`, plus `Cancel`):

- **Target selection.** The server computes the **centroid of the densest
  operative cluster** among Alive operatives within the Spitter's engagement
  range, deterministically. Ties (equal cluster density) break to the cluster
  containing the lexically smallest operative entity ID, mirroring the walker's
  LK-0203 tie rule. Only Alive operatives count, matching the existing "no
  finishing blows on the downed" rule.
- **Windup (telegraph).** After acquiring a target the Spitter enters a
  `WindingUp` state for a configured **~1.4 s** and publishes the bloom's exact
  landing position and radius. This window is the whole counterplay budget.
- **Interruption.** Killing the Spitter during windup cancels the pending
  commit — a dead record cannot resolve a living action, exactly as a killed
  Choir Screamer cancels its summon. Nothing is banked; a fresh windup starts
  only after the ability cooldown.
- **Commit.** At the commit timestamp, every Alive operative inside the bloom
  radius (**~16 studs**, first pass) takes one authoritative damage event
  (**~14 damage**, first pass) through the existing P3 boundary
  (`applyAuthoritativeDamage`) with a deterministic duplicate-protected event ID
  (`spitterbloom:<spitterId>:<operativeId>:<commitTimestamp>`). No client fact,
  position, or timestamp is trusted.
- **Lingering denial (bounded).** The landed bloom persists for a short
  configured window (**~3 s**, first pass) and re-applies a smaller tick
  (**~5 damage** on a **~1 s** interval) to Alive operatives still standing in
  it, on the existing enemy evaluation pass — no new scheduler. Active bloom
  zones are capped low (first pass: **4** concurrent) and evicted oldest-first;
  the pool bound keeps the worst case flat. The lingering pool is what actually
  denies the held ground and forces the reposition; a single instantaneous burst
  would be forgettable.
- **Cooldown.** A configured **~6 s** cooldown between blooms keeps the Spitter a
  pressure source, not a stunlock. Death is inert (no windup, no commit, no
  lingering re-ignition), and stand-down at resolution ends all Spitter actions.

All of the above is a side-effect-free resolver decision (`P9-0101`): given the
Spitter's facts, the operative facts, and a server timestamp, it returns the
next behavior state, the ability action, and — on commit — the bounded set of
authoritative damage events and the new lingering-zone descriptor. No Roblox
services, loops, or randomness.

#### Counterplay and class contributions

- **Positioning (primary):** spread out so a single bloom cannot catch the whole
  squad, and step off the landed pool. This breaks the turtle — the intended
  disruption.
- **Focus fire:** kill the Spitter during its windup to cancel the bloom; a
  learnable, attributable interrupt.
- **Combat specialist:** Brace stabilizes a firing angle to burst the Spitter
  down before it commits.
- **Medic:** sustains an operative who has to eat chip damage to hold a
  necessary angle, and revives anyone caught by a full bloom.
- **Engineer:** Field Resupply covers the extra ammunition the ranged priority
  target costs.

Missing any class changes efficiency, never possibility — consistent with the
P7 and P8 "opportunity, not gate" rule.

#### Spawn policy and director integration (for `P9-0102`)

- The Spitter is spawned by `EnemyDirectorService` through the existing
  fair-spawn validation, health, body, death, corpse-cleanup, and stand-down
  paths. It obeys the existing fair-spawn minimum distance, so it never
  materialises inside the squad's engagement radius.
- **Rarity is authored, not random-heavy.** First pass: at most **1** concurrent
  Spitter for a 1–2-operative squad and **2** for a 3–4-operative squad,
  introduced once the **booster hold (P8 objective 2)** begins — the strongest
  turtle incentive in the operation — and thereafter maintained as a low-count
  special within the existing population budget. Its ability runs on the
  existing bounded enemy evaluation pass; no per-enemy scheduler, no per-enemy
  connection, no new remote.
- The Spitter counts against, and is bounded by, the existing population caps and
  evaluation budgets; it does not raise them.

#### Telegraph and presentation (for `P9-0105`)

The Spitter reuses the horde special-role telegraph mechanism: a fixed
presentation pool and replicated model attributes (`kind`, `sequence`, `state`,
`commit server timestamp`, landing position, radius), no new remote. Redundant
cues for the bloom: a world-space ground disc at the **exact** authoritative
radius, a countdown to commit, a `CORROSIVE BLOOM` text label, a distinct
Spitter silhouette (per the horde-role-readability approach), and role-specific
audio. Color is reinforcement, never the only signal. The lingering pool renders
as a persistent hazard footprint for its configured lifetime so the ground it
denies is unambiguous.

## Part B — The boss encounter

### Arena, objective connection, and the single terminal boundary

The boss is the authored climax of the **extraction holdout** at the
`ExtractionClearing` landmark (center 218, 58, radius 58) — the operation's final
location, already the holdout arena and the site of the existing "extraction
nightmare" wave. When `Holdout` begins, `EnemyDirectorService` spawns exactly
one boss, **The Progenitor** (`boss.progenitor`), the fungal source anchoring the
zone. Surviving the holdout *is* defeating the Progenitor:

- **Boss defeated →** the holdout resolves as operation success through the
  existing mission terminal boundary (the same boundary the current holdout
  timer resolves through today). P9 replaces the fixed holdout timer with the
  boss-defeat condition; it does not add a second terminal owner.
- **Squad wipe during the boss →** existing squad-failure resolution from the
  `Holdout` phase, unchanged.

No new terminal-failure cause, one first-commit-wins resolution, so P10's later
result loop inherits a single boundary intact.

### Phases (for `P9-0103` — pure phase resolver)

Phase transitions are deterministic and **monotonic** (they never regress),
derived by a pure resolver from server-owned facts only: boss health thresholds,
phase-scoped timers, the count of active adds, and the P8 floodlight-repair fact.
Precedence is fixed and documented so two facts crossing on the same pass resolve
identically every time.

1. **Phase 1 — Carapace (armored; vulnerability windows).** The Progenitor is
   armored and takes **no** damage except during telegraphed **exposure
   windows** that open for a configured duration after it performs a **Slam** — a
   heavy, telegraphed melee AoE at the clearing center. Teaches focus-fire timing
   and positioning: you damage it on *its* rhythm, and you stand out of the slam
   disc. Light roaming pressure continues underneath. The exposure window is
   visibly distinct (the carapace opens) so a shot that lands versus a shot that
   bounces is legible — counterplay is attributable.
2. **Phase 2 — Brood (summons under scarcity).** At a health threshold the boss
   roots, raises a spore shroud that **shrinks the gameplay visibility radius**
   (a bounded, server-owned reduction that ties the darkness lesson into the
   climax), and calls a **bounded brood surge** of adds through the existing
   director wave path — within the existing population cap, never beyond it.
   Exposure windows shorten. The squad must clear adds, manage ammunition
   (scarcity now bites), and rescue anyone the shroud-blinded adds drop, all
   while chipping the boss on tighter windows. Teaches crowd control under
   scarcity plus rescue.
3. **Phase 3 — Collapse (enrage; prior-decision payoff).** Below a lower
   threshold the Progenitor enrages: faster, more frequent slams and a shorter
   exposure cadence. This is where the **P8 optional floodlight repair pays
   off** — if the squad restored the extraction floodlights, the arena is lit and
   every telegraph reads clearly; if they skipped it, the arena stays dark and
   the same telegraphs are harder (never *impossible*) to read. The choice made
   two objectives ago changes the climax's readability, honoring "respects prior
   resource decisions" without any hidden stat wall. The final health commit at
   zero marks the boss dead and resolves the holdout as success.

Vulnerability, attack cadence, summon counts, shroud radius reduction, and the
three health thresholds all live in `BossConfig` (`P9-0103`) with validated
invariants (thresholds strictly ordered and monotonic, add counts within the
population cap, every dangerous action's windup shorter than its cooldown and no
shorter than the evaluation interval — mirroring the walker's attack-windup
invariant).

### Runtime and arena integration (for `P9-0104`)

One boss instance is owned through the production enemy and operation boundaries:

- Identity, body, health commits (revisioned, monotonic-down, duplicate-safe),
  death, and cleanup reuse the director's existing enemy boundaries.
- Slam damage and brood-add damage commit through the existing P3
  `applyAuthoritativeDamage` boundary with deterministic duplicate-protected
  event IDs.
- Phase transitions, exposure windows, slams, the brood surge, and the shroud
  ride the existing bounded evaluation pass — no per-boss scheduler, no per-boss
  connection, no new remote. Boss and phase state disclose through replicated
  model attributes and the existing mission/horde snapshot, like the special-role
  telegraphs.
- `Holdout` entry spawns the boss; mission stand-down / teardown tears it down
  with everything else, clears its adds, and cancels any pending telegraphed
  action — no residual timers or connections.

### Class contributions

- **Combat specialist:** Brace to burst inside the exposure windows.
- **Medic:** keeps focus-fire operatives alive through slams and revives under
  boss pressure (the P3 rescue lesson at its hardest).
- **Engineer:** Field Resupply for the ammunition the phases burn, and the P8
  floodlight repair whose payoff lands in phase 3.

Every starting class contributes; no class is required to defeat the boss.

### Telegraphs, accessibility, and failure readability (for `P9-0105`)

Every dangerous boss action — slam, brood surge, shroud, enrage transition — and
every exposure window carries redundant **position, timing, shape, text,
animation, and audio** cues through the fixed telegraph pool. No cue is
color-only or audio-only. Phase transitions are announced. The exposure window
is unmistakable so players learn *when* damage lands. Telegraphs never disclose
an undisclosed enemy early or legalize a client-predicted hit.

### Performance budgets (for `P9-0106`)

- One boss instance; adds strictly within the existing population caps
  (6/operative, 96 absolute).
- Telegraphs reuse the existing fixed presentation pool (16 slots) and the shared
  hostile-audio owner; zero per-event Instances, tasks, particles, or Sounds.
- Zero new server connections, zero per-enemy connections, zero new remotes; the
  boss and Spitter both ride the existing enemy evaluation pass within the
  existing raycast budget.
- Representative 1/2/4-operative profiling of horde + Spitter + boss load is the
  `P9-0106` gate.

## Failure conditions (summary)

- **Encounter-level:** none are terminal. A missed telegraph, a lost exposure
  window, an eaten bloom, or a caught operative is a recoverable setback.
- **Operation-level (unchanged):** committed squad wipe after grace, or
  authoritative abandonment, through the existing `SquadFailureService`.
- **Continuity:** all special-enemy and boss state is keyed by mission-scoped
  facts and entity IDs, never `Player` references, so a disconnect mid-encounter
  cannot regress a phase or duplicate a consequence.

## Mapping to the P9 implementation tasks

| Task | What this plan hands it |
| --- | --- |
| `P9-0101` | Blight Spitter archetype ID, ability-state and rejection vocabulary, `SpecialEnemyConfig` values (health, engagement range, bloom windup/radius/damage, lingering lifetime/tick/interval, active-zone cap, cooldown), and a pure resolver for densest-cluster targeting, legal ability use, cooldown, windup interruption, death inertness, and deterministic tie-breaks. |
| `P9-0102` | The Spitter integrated into `EnemyDirectorService` — reusing identity/health/spawn/damage/cleanup/stand-down and the bounded evaluation pass — with the authored rarity/introduction policy and no new scheduler, connection, or remote. |
| `P9-0103` | `BossContracts` and `BossConfig` (phase/transition/vulnerability/attack/summon/objective/outcome vocabulary; three ordered health thresholds; slam/exposure/shroud/brood values) and a pure `BossPhaseResolver` with deterministic, monotonic transitions and fixed precedence. |
| `P9-0104` | The single Progenitor instance owned through the production enemy/operation boundaries, spawned at `Holdout`, resolving the holdout on defeat through the existing single terminal boundary, and torn down on stand-down/teardown. |
| `P9-0105` | Redundant, accessible telegraphs for the bloom and every boss action via the fixed telegraph pool and replicated attributes; no new remote, no early disclosure, no client-legalized hit. |
| `P9-0106` | Security (forged phase/health/target/action facts, stale transitions, disconnect, wipe, stand-down, replay, cleanup), representative 1/2/4 horde+Spitter+boss profiling, and Studio proof that counterplay is attributable and no unexplained resource wall invalidates prior choices. |

## Exit criteria for the plan

`P9-PLAN-001` is complete when the disrupted tactic, the special enemy's ability
and counterplay, its telegraphs and spawn policy, the boss's arena, phases,
objective connection, class contributions, failure readability, accessibility,
and performance budgets are fixed and mapped to the existing owners and the
single terminal boundary — as above — so `P9-0101` can begin without further
design decisions.

## Implementation status (P9-0101 – P9-0106)

- **Contracts, configuration, and pure decisions (`P9-0101`) — complete.**
  `src/shared/Combat/SpecialEnemyContracts.luau` fixes the `enemy.blight_spitter`
  archetype ID, the behavior-state (`Roaming`/`Approaching`/`Charging`/`Recovering`/`StandDown`/`Dead`)
  and ability-action (`None`/`Begin`/`Continue`/`Cancel`/`Commit`) vocabulary,
  the `InvalidFacts`/`InvalidTimestamp` rejection reasons, and the fact, decision,
  and lingering-zone shapes (reusing the P3-compatible `AuthoritativeEnemyAttack`).
  `src/shared/Config/SpecialEnemyConfig.luau` is the balance home — health,
  ranged engagement, the Corrosive Bloom windup/radius/damage/cooldown, the
  cluster radius, the lingering pool, the active-zone cap, and the authored
  rarity — with invariants asserted against `EnemyConfig`.
  `src/server/Systems/SpecialEnemyBehaviorResolver.luau` is the pure,
  deterministic resolver: it targets the densest operative cluster (lexical
  tie-break), runs the `Begin → Continue → Commit` charge lifecycle, emits one
  authoritative damage event per Alive operative inside the impact radius at
  commit plus the lingering-zone descriptor, stays inert while dead or
  stood-down, and derives each pool tick through `resolveLingeringDamage`.
  Fixtures `tests/SpecialEnemyContracts.test.luau` and
  `tests/SpecialEnemyBehaviorResolver.test.luau` cover the vocabulary/config
  invariants and the full decision surface (validation, targeting, tie-breaks,
  the charge lifecycle, the commit burst, the lingering ticks, inertness, and
  determinism/immutability). No runtime, remote, movement, or telegraph exists
  yet.
- **Director integration (`P9-0102`) — complete.** `EnemyDirectorService` owns the
  Blight Spitter as a first-class archetype through its existing boundaries.
  `commitSpawn` is archetype-aware: a Spitter carries its own health and roam
  speed and bypasses the RPG elite layer entirely. On the shared evaluation pass,
  `applySpitterBehavior` runs the pure resolver, applies movement intent, discloses
  the charge telegraph via replicated model attributes, and — at commit — commits
  the burst against every Alive operative in radius and registers the lingering
  pool; `tickBloomZones` then ticks live pools (bounded by the active-zone cap,
  oldest-first eviction) and prunes expired ones. Every operative damage event
  commits through the existing P3 boundary with the same squad Iron Hide mitigation
  the walker melee uses. The Spitter is introduced on the roaming pass once
  escalation reaches the configured level and is bounded by `MaximumConcurrent`;
  death frees its slot, and stand-down/teardown clear its charge, telegraph, and
  all lingering pools. The shared archetype registry (`EnemyContracts.EnemyArchetypeIds`)
  now lists the Spitter so the existing fair-spawn resolver validates it; every
  walker-only system (loot, XP, walker presentation/audio, horde telegraphs) filters
  by the walker archetype and cleanly ignores the Spitter. Bounds are unchanged:
  one heartbeat, one evaluation pass, zero per-enemy connections/timers/raycasts/remotes
  and no randomness. The readable client telegraph presentation is `P9-0105`.
- **Boss contracts, configuration, and phase resolver (`P9-0103`) — complete.**
  `src/shared/Combat/BossContracts.luau` fixes The Progenitor's `boss.progenitor`
  archetype (sourced from the shared `EnemyContracts` registry), the monotonic
  `Carapace → Brood → Collapse → Defeated` phases and their fixed order, the Slam
  action lifecycle (`None`/`Begin`/`Continue`/`Cancel`/`Commit`), the
  `Pending`/`Defeated` outcome, rejection reasons, and the fact/decision shapes.
  `src/shared/Config/BossConfig.luau` is the balance home — boss health, the
  strictly-ordered Brood/Collapse health thresholds, per-phase Slam
  windup/cooldown/exposure values that tighten monotonically (enrage), the Slam
  radius/damage, the Brood surge count (within the population budget), and the
  spore-shroud / Collapse-darkness visibility reductions — with invariants asserted
  against `EnemyConfig`. `src/server/Systems/BossPhaseResolver.luau` is the pure,
  deterministic resolver: monotonic health-driven phase transitions with fixed
  precedence (never regressing), the post-Slam exposure window that alone makes the
  boss vulnerable, the Slam AoE against every Alive operative in radius at commit,
  the one-shot Brood surge signal, the shroud/darkness visibility override (the P8
  floodlight repair pays off in Collapse), and terminal defeat. Fixtures
  `tests/BossContracts.test.luau` and `tests/BossPhaseResolver.test.luau` cover the
  vocabulary/config invariants and the full decision surface. No runtime, arena,
  telegraph, or summon integration exists yet.
- **`P9-0104` – `P9-0106`** remain not started; they add the boss runtime and
  arena integration, the readable telegraphs, and the encounter validation.

## Deliberate exclusions

No second enemy runtime, no per-enemy scheduler, no new client remote, no new
terminal-failure cause, no change to the HROI horde-role or RPG elite-affix
systems, no persistent reward from the encounter (that is P11), no pathfinding
around obstacles (still deferred), and no new licensed assets — telegraphs and
bodies remain graybox with the project's existing verified audio. Every timing,
radius, damage, threshold, and count named here is first-pass authoring intent to
be confirmed against evidence in P12.
