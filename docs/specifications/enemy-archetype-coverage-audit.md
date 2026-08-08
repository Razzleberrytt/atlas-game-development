# Enemy archetype coverage audit — BA-040

## Decision summary

A documentation-only gap matrix across every hostile archetype/layer in the live
runtime, scored on three axes: **pressure** (does it create escalating threat),
**counter** (is there a legible, attributable player counterplay), and
**readability** (is the threat visually/mechanically distinct before it hits).
This is not a new `EnemyService` and does not activate, rebalance, or wire
anything. It is sourced from the shipped contracts/config and their governing
specs, not from source-code behavior reading beyond those files.

## Scope and evidence

Sources: `EnemyContracts.luau`, `EnemyConfig.luau`, `SpecialEnemyContracts.luau`,
`SpecialEnemyConfig.luau`, `HordeRolePresentationConfig.luau`,
[`enemy-pressure-runtime.md`](enemy-pressure-runtime.md),
[`special-enemy-and-boss-encounter.md`](special-enemy-and-boss-encounter.md),
[`horde-role-readability.md`](horde-role-readability.md), and the RPG elite-affix
section of `rpg-integration-plan.md` (§7.6–7.7). `horde-special-role-telegraphs.md`
is cited secondhand (cross-referenced by two already-read specs, not opened in
this pass) for the Screamer summon and Bloater burst claims below; verifying it
directly is the first follow-up.

## Disposition vocabulary

- **KEEP** — pressure/counter/readability triad is complete and evidenced.
- **REFINE** — triad is present but one leg is weak or unverified.
- **MISSING** — a leg is documented as absent or contradicted by another doc.

## Coverage matrix

| Archetype / layer | Pressure | Counter | Readability | Disposition |
| --- | --- | --- | --- | --- |
| `enemy.exclusion_walker` (Hollow Infected baseline) | Escalating roam cadence + population cap, `EnemyConfig.Pressure` | Kill priority, positioning outside detection/attack radii | Baseline silhouette, attack windup visible on evaluation pass | **KEEP** |
| HROI role — Razor Runner | None beyond baseline walker facts — `HordeRolePresentationConfig` is explicitly presentation-only and does **not** change movement speed | None distinct from baseline walker | Visual signature only (narrow frame, fast cosmetic stride); the model's own doc calls the six roles "mechanically distinct," which this signature does not deliver | **MISSING** — mechanical/counter leg absent; readability oversells a mechanic that isn't there |
| HROI role — Grave Crawler | Same as Runner: presentation-only, no distinct threat behavior confirmed | None distinct from baseline walker | Visual signature only (low ambush posture, purple eye) | **MISSING** — same gap as Runner |
| HROI role — Choir Screamer | Summon ability (cross-referenced: "a killed Choir Screamer cancels its summon," implying a live summon mechanic) | Kill during summon windup cancels it — an interrupt, mirroring the Spitter's counterplay shape | Distinct tall/beacon silhouette + dedicated telegraph doc (`horde-special-role-telegraphs.md`, not opened this pass) | **REFINE** — mechanic and readability well-evidenced secondhand; telegraph doc itself not directly verified |
| HROI role — Rot Bloater | Death-burst hazard (cross-referenced: "the Bloater's 20-stud/18-damage burst") | Positioning away from the corpse at time of death | Distinct swollen/green silhouette + telegraph doc (not opened this pass) | **REFINE** — same secondhand-evidence caveat as Screamer |
| HROI role — Grief Brute | Not confirmed distinct from baseline walker in any read source | Not confirmed distinct from baseline walker | Distinct heavy/armored silhouette (visual only, confirmed) | **MISSING** — no mechanical or counter differentiator found; may be a pure visual role with no gameplay identity |
| `enemy.blight_spitter` (Blight Spitter) | Ranged area-denial, authored rarity introduced at booster hold | Spread/reposition, or kill during ~1.4s windup to cancel | Ground disc + countdown + label + distinct silhouette, full P9-0105 telegraph | **KEEP** — full triad, P9-0101–0106 complete |
| `boss.progenitor` (The Progenitor) | Three-phase escalation (armored → brood adds under scarcity → enrage) | Phase-specific: timed exposure-window bursts, add clearing, floodlight-repair payoff in phase 3 | Redundant multi-cue telegraphs for every dangerous action, always-visible phase/exposure status label | **KEEP** — full triad, P9-0101–0106 complete |
| RPG elite affix — Frenzied | Speed/cooldown multiplier on ordinary spawns, capped 3 concurrent | Reduced max health (0.85×) trades survivability for pressure | Orange/yellow highlight + world-label prefix | **KEEP** |
| RPG elite affix — Armored / Regenerator / Volatile / Commander | Each modifies pressure distinctly (damage reduction, sustain, death nova, aura buff) | Each has a documented counter (focus through armor pool, burst before regen delay, step off Volatile radius, kill/outrange Commander) | Role-restricted assignment prevents overlap; safe presentation attributes disclosed per §7.7 | **KEEP** |

## Findings

1. **HROI "six mechanically distinct roles" claim is only true for two of the six on current evidence.** `horde-role-readability.md` asserts "the horde runtime already owns six mechanically distinct roles," but `HordeRolePresentationConfig` is explicitly presentation-only, and only Screamer (summon) and Bloater (death burst) have a documented mechanic distinct from the baseline walker. Runner, Crawler, and Brute have confirmed visual signatures but no confirmed mechanical or counterplay identity in any source read for this audit.
2. **Runner and Crawler readability actively mismatches mechanics.** A "razor sprinter" that moves at identical speed to every other walker, or a "grave crawler" with no distinct detection/ambush behavior, teaches players a wrong lesson about what the silhouette means — the opposite of the readability goal the rest of the enemy system holds to (P5/P9 telegraph discipline).
3. **Brute has no confirmed gameplay identity beyond its silhouette.** Unlike Screamer/Bloater, no source read here documents a Brute-specific mechanic (e.g., elevated health/damage, knockback, armor). It may already exist in `HordeExperienceService`/`HordeSpecialTelegraphConfig` and simply wasn't surfaced by the specs read in this pass — flagged as the top follow-up, not asserted as absent.
4. **Special enemy (Spitter) and boss (Progenitor) are the strongest coverage in the game** — both have a complete, evidenced pressure/counter/readability triad end-to-end, including automated security/performance validation (`P9-0106`).
5. **Elite affix layer is complete and orthogonal** — it modifies pressure on top of any compatible base archetype/role without duplicating the base counter or readability contract, and role-incompatibilities are enumerated to prevent unreadable stacking.

## Not in scope / explicitly excluded

No `EnemyService` changes, no new archetype, no rebalancing, no HROI role mechanic
implementation, no config edits. This audit does not activate anything and makes
no runtime claim — E1 (source/static) only.

## Ordered follow-up (not authorized by this document)

1. Open `horde-special-role-telegraphs.md` and `HordeExperienceService.luau` /
   `HordeSpecialTelegraphConfig.luau` directly to confirm or correct the
   Runner/Crawler/Brute finding above — the single highest-value next read for
   whoever picks up horde-role work.
2. If Runner/Crawler/Brute are confirmed mechanically inert, either give each a
   small, bounded, single-owner mechanic (mirroring Screamer/Bloater's shape) or
   soften `horde-role-readability.md`'s "six mechanically distinct roles" claim
   to match reality — the doc and the runtime must agree.
3. No implementation until a future ticket explicitly authorizes it; this audit
   only fixes the map.

## Completion boundary

`BA-040` is complete when the coverage matrix above exists and is evidenced —
as above. It does not authorize P9-style implementation work for Runner/Crawler/
Brute; that remains a separate, explicitly-scoped future ticket if the findings
are confirmed.
