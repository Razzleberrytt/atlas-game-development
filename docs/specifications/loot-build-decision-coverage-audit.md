# Loot/build-decision coverage audit — BA-042

## Decision summary

A documentation-only gap matrix over every player-facing build-decision system:
Field Upgrades, Run Relics, temporary combat resources, and the enemy-side elite
affixes that reward those decisions. Sourced entirely from
[`rpg-integration-plan.md`](rpg-integration-plan.md) (its per-task implementation
status is unusually current and cites owners/fixtures directly, so it is treated
as authoritative here without re-reading source). This is not new code and
authorizes no implementation.

## Product-decision boundary — read this first

`rpg-integration-plan.md` §21 **explicitly excludes** classic itemization:
no gear score, no equippable armor pieces, no weapon rarity tiers or random
weapon-stat rolls, no item durability, no stash storage, no dozens of affixes.
**BA-042's own framing ("affix/stat/set/rarity decision gaps") describes a
itemization model this product has deliberately rejected.** The actual
build-decision model is a roguelite run-build: Field Upgrades (frequent, small)
+ Relics (rare, build-defining, 3 slots) + enemy-side Elite affixes (reward
source, not player gear). Any future work must target gaps in *that* model, not
retrofit set/rarity itemization the product decision already ruled out.

## Coverage matrix

| Layer | Decision surface | Status | Evidence |
| --- | --- | --- | --- |
| Layer A — Starting identity | Specialist + firearm choice pre-insertion | Live (pre-RPG-track system) | §6 |
| Layer B — Field Upgrades | 3 server-generated offers per Field Level, stack-capped | **12/12 catalog implemented, but 5 originally-scoped families remain `Planned`** | §7.4: Adrenal Response, Second Pulse, Rescue Instinct, Shared Momentum, Covering Fire are unbuilt — each blocked on a missing fact source (movement modifiers, horde-phase survival events, squad-proximity facts, cooperative threat/action events). Two shipped cards (Trauma Plating, Field Discipline) ship an "interim mechanic" that diverges from the originally planned effect. |
| Layer C — Relics | 2-choice reward on elite/special/objective/milestone events, 3 equipped slots | **12/12 declared relics implemented**, but the RPG-0108 exit gate ("three viable build patterns") is explicitly unconfirmed | §15 RPG-0108: "Implementation complete; Studio validation outstanding." No Studio evidence claimed anywhere in the doc. |
| Layer C — Relic reward sourcing | Elite kill, special interrupt, squad-kill milestone, objective, container, boss milestone | **3 of 6 sources wired; 3 stale-blocked** | §15 RPG-0110: objective/container sources correctly still wait on P8. **Boss milestone sources are recorded as waiting on P9 — but BA-040's audit confirms P9 (`special-enemy-and-boss-encounter.md`) is now complete.** This is a stale cross-document dependency, not a real blocker. |
| Layer D — Temporary combat resources | Short-duration surges, no slot cost | Live per §6 Layer D description | No implementation-status subsection in the doc — not tracked per-item the way Field Upgrades/Relics are. |
| Elite affixes (reward source, not player gear) | 5/5 affixes, role-restricted | **Complete** — already fully evidenced in [`enemy-archetype-coverage-audit.md`](enemy-archetype-coverage-audit.md) (BA-040) | Cross-reference; not re-audited here to avoid duplicate work. |
| Security/balance/multiplayer validation | Forged choices, replay, reconnect, ceilings, representative-horde performance | **Not started** | §15 RPG-0113: "Not started." |

## Findings

1. **BA-042's premise needs correcting, not just answering.** There is no rarity/set/stat-roll system to audit because the product explicitly rejected one (§21). The real gap is coverage *within* the roguelite model, captured above.
2. **Five Field Upgrade families are stubbed on missing fact sources**, not missing balance work — implementing them requires the upstream facts (movement modifiers, horde-phase survival events, squad-proximity tracking, cooperative-action events) to exist first. This is dependency-ordering information for whoever picks up Field Upgrade expansion, not a "just add these" task.
3. **The boss-reward-source dependency in `rpg-integration-plan.md` §15/RPG-0110 is now stale.** It still reads "boss milestones wait for P9," but P9 is complete (confirmed independently in BA-040). Wiring the boss-defeat relic reward source is now a dependency-safe next RPG task, gated only by P10-0102's boss-outcome→terminal-result convergence (per the special-enemy-and-boss-encounter.md status note), not by P9 itself.
4. **RPG-0108's "three viable build patterns" claim and RPG-0113's full validation matrix are both outstanding Studio-evidence gates**, not implementation gaps — every relic and elite affix is implementation-complete. This belongs on the evidence ledger, not a build-ahead code task.
5. **No enemy carries more than one affix, and no player build can exceed three relics or the modifier ceilings in §19** — the scarcity/readability pillars (§5.2, §5.3) are honored everywhere audited here.

## Not in scope / explicitly excluded

No itemization system, no new relic/upgrade implementation, no rebalancing, no
Studio evidence capture. This audit does not activate the stale boss-reward
source or implement any `Planned` Field Upgrade.

## Ordered follow-up (not authorized by this document)

1. Update `rpg-integration-plan.md` §15/RPG-0110's boss-source dependency note
   from "wait for P9" to "wait for P10-0102" — a one-line doc correction, not a
   code change, and the cheapest fix from this audit.
2. When the missing fact sources land (any of: movement modifiers, horde-phase
   survival events, squad-proximity facts, cooperative-action events), flip the
   corresponding `Planned` Field Upgrade to `Implemented` per the existing
   RPG-0103 pattern — do not add a parallel upgrade path.
3. RPG-0113's full security/balance/multiplayer validation matrix is the
   highest-value remaining RPG-track gate; it requires Studio evidence, not
   build-ahead work.

## Completion boundary

`BA-042` is complete when the coverage matrix above exists and is evidenced —
as above. It does not authorize implementing any `Planned` upgrade, wiring the
boss reward source, or capturing Studio evidence; those remain separate,
explicitly-scoped future tickets.
