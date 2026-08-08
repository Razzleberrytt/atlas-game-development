# Living Kingdoms — Project Charter

> **Historical product charter.** This document records the cooperative-survival/isometric direction that shaped the current Living Kingdoms runtime and remains useful for preserved design principles. It is **not the current top-level Atlas product authority**. For new roadmap interpretation and product-scope decisions, read [`00-current-product-authority.md`](00-current-product-authority.md) first. Existing runtime camera/combat behavior remains preserved until an explicit decision changes it; this historical notice does not itself authorize a rewrite.

## High-concept pitch

Living Kingdoms is a brutally difficult cooperative isometric survival game for up to eight players. Each player controls one specialized operative who begins isolated on a dark, hostile operation map. The team must find one another, share scarce ammunition and medical support, move between temporary defensive positions, and survive escalating threats long enough to complete an authored objective and extract. Victory comes primarily from knowledge, execution, resource management, and coordination—not permanent power.

The MVP supports 1–4 players and is architected so a later release can support 8.

## Player fantasy

The player is one capable but vulnerable member of a squad, not the commander of an army. Alone, their information and options are incomplete. Together, specialists become a functioning unit: combat expertise holds a line, medical expertise recovers teammates, engineering keeps equipment and ammunition available, and reconnaissance turns uncertainty into actionable information.

Players directly control movement, positioning, interaction, reload timing, class abilities, and resource decisions. Operatives automatically acquire and fire on valid hostile targets in range. This keeps the player's attention on squad movement and survival decisions while server-authoritative combat rules preserve scarcity, target legality, and difficulty.

The desired arc is to begin lost and exposed, feel genuine relief upon finding teammates, become dependent on their specialties, and earn a memorable victory through disciplined cooperation under pressure.

## Design pillars

1. **Isolation becomes solidarity:** separated spawns and limited personal visibility make regrouping the first emotional objective.
2. **Interdependence over parallel play:** classes solve different team problems and cannot be reduced to different damage numbers.
3. **Scarcity creates decisions:** ammunition, medical recovery, and supplies are finite enough that expenditure and resupply routes matter.
4. **Safety expires:** defensible buildings and chokepoints provide temporary advantages, but objectives, depletion, roaming threats, and escalation force movement.
5. **Hard but learnable:** failure should reveal patterns, improve team knowledge, and make later success feel earned rather than arbitrary.
6. **Authored operations create stories:** each match has deliberate objectives, escalation, a climax, and a clear success or failure state.
7. **Mastery outweighs account power:** ranks and class unlocks create long-term pride while permanent statistical bonuses remain absent or very small.
8. **Positioning drives combat:** automatic attacks convert range, visibility, line of sight, ammunition, readiness, and hostile pressure into tactical movement decisions rather than manual aim execution.

## Emotional goals

The design must preserve:

1. Isolation at the beginning.
2. Relief when players find one another.
3. Dependence on specialized teammates.
4. Fear of running out of ammunition or medical resources.
5. Pressure to leave temporary safety.
6. Dramatic retreats and last stands.
7. Runs that produce memorable player stories.
8. Strong satisfaction from finally completing a difficult operation.
9. Long-term pride in rank and class mastery.

## Core gameplay loop

Spawn separated → Orient with limited information → Locate the squad → Assign roles and pool knowledge → Position operatives and manage automatic engagements → Scavenge and complete objectives → Defend briefly → Relocate under escalating pressure → Confront the operation climax → Extract or make a final stand → Earn career progress → Apply learned tactics to the next run

## Product direction

Living Kingdoms is a session-based cooperative survival game built around finite authored operations. It is not an open world, MMORPG, PvP game, base-building game, or army-command RTS.

Matches begin with uncertainty, develop through regrouping and objective-driven movement, and end with an extraction, final holdout, or other authored climax. Failure is expected during learning, but must remain legible and worthwhile.

## Audience and session promise

The initial audience is cooperative Roblox players who enjoy difficult team PvE, tactical decision-making, class mastery, and replayable authored challenges. A session should be long enough to build tension and a story, but always have a finite endpoint. Exact operation length remains a playtest question.

## North-star question

> Does this create a tense, learnable situation in which teammates genuinely need one another?

Features that do not clearly support that question should be postponed or rejected.

## Difficulty philosophy

- Early failures are acceptable; unclear or unteachable failures are not.
- Threat rules, objective states, and resource consequences must be consistent enough to learn.
- Pressure may be severe, but the game should provide readable signals and meaningful counterplay.
- Difficulty should test positioning, communication, target priority, resource discipline, and coordinated retreat.
- Scaling must preserve class value and scarcity without turning enemies into opaque health sponges.
- Experienced players should win through knowledge and execution, not accumulated numerical superiority.

## Progression and monetization guardrails

Persistent XP and military-style ranks recognize participation, improvement, and difficult victories. Ranks can unlock additional specialist classes and side-grade options. Failure grants limited progress; victory grants meaningfully more. Any permanent statistical bonuses must remain very small and must not trivialize operation difficulty.

Monetization must never sell raw combat power, exclusive best-in-slot classes or equipment, mandatory progression shortcuts, additional match resources, or paid recovery from failure. Acceptable future directions may include cosmetics, presentation, or other non-power expression, but monetization is not part of the MVP.

## Naming and originality

Living Kingdoms remains the temporary working title and internal identifier. Final public branding is unresolved, and naming work is explicitly deferred. The project may learn from the cooperative tension and survival structure of classic custom maps, but it will use original neutral terminology, lore, characters, maps, classes, assets, and implementation.
