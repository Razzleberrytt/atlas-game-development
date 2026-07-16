# Living Kingdoms — Minimum Viable Product

## MVP promise

One to four players enter one authored operation as separated specialists, regroup using limited information, manage finite ammunition and health resources, complete two or three objectives under escalating enemy pressure, defeat or survive a boss encounter, and reach a clear extraction, holdout, success, or failure result.

The MVP proves the complete emotional and systemic arc in one operation map. Its networking and player-slot assumptions must not prevent later support for up to eight players.

## Match structure

1. **Briefing and class choice:** players understand the operation goal and choose from the available specialists without seeing every upcoming event.
2. **Separated insertion:** each operative spawns at an authored, fair location away from some or all teammates.
3. **Isolation and orientation:** darkness and limited personal vision restrict certainty; local landmarks and a periodic squad-location aid support navigation without removing tension.
4. **Regrouping:** players locate one another, communicate status, and establish a working formation.
5. **Objective advance:** the squad completes two or three authored objectives and searches risky locations for ammunition or other supplies.
6. **Temporary defense and relocation:** buildings and chokepoints can improve survival briefly, but resource depletion, objectives, roaming threats, or escalation prevent permanent camping.
7. **Climax:** a boss encounter and final extraction or holdout demand class coordination and disciplined resource use.
8. **Resolution:** the match records success or failure, explains the result, and awards persistent XP according to contribution and outcome.

If the entire squad becomes unrecoverable or a critical authored objective fails, the operation ends in failure. Exact incapacitation and recovery edge cases will be specified before implementation.

## MVP content

- 1 authored operation map
- 1–4 players, architected for a later maximum of 8
- 3 starting classes: combat specialist, medic, and engineer
- 1 unlockable specialist class
- 1 basic firearm family
- Finite ammunition and ammunition pickups or supply caches
- Health, incapacitation, teammate revival, and death
- Limited personal vision
- A periodic location ping or equivalent squad-location aid
- Separated player spawns
- Basic enemy hordes
- 1 special enemy
- 1 boss encounter
- 2–3 operation objectives
- 1 final extraction or holdout sequence
- Persistent XP and a small initial military-rank ladder
- Successful and failed match result screens

## Cooperative class philosophy

Classes own responsibilities, not merely damage profiles.

- **Combat specialist:** provides dependable damage and helps stabilize threatened positions, but cannot sustain the squad alone.
- **Medic:** stabilizes, heals, and restores downed teammates; recovery capacity is limited enough that prevention still matters.
- **Engineer:** repairs relevant operation equipment and produces, restores, or improves access to ammunition within strict resource limits.
- **Unlockable specialist:** adds a distinct team capability such as reconnaissance; its final identity and unlock rank remain open design decisions.

Every MVP class must have at least one frequent, legible contribution that teammates value, at least one meaningful limitation, and at least one interaction with another class. Class stacking rules and duplicate-role support require playtesting; no class should make a run automatically unwinnable when absent, but a balanced squad should have materially better options.

## Scarcity and ammunition philosophy

- Ammunition is a shared strategic concern even when inventories are personal.
- Firing solves immediate danger at the cost of future safety.
- Supply caches are placed at risky authored locations to create route and timing decisions.
- The engineer improves ammo resilience but does not create unlimited ammunition.
- Medical recovery follows the same principle: enough to enable rescues, not enough to erase repeated mistakes.
- The UI must communicate current personal resources clearly while preserving uncertainty about distant supplies.
- Scarcity targets are tuned so careful teams can recover from some errors; starvation must not feel predetermined by unknowable choices.

## Visibility, darkness, communication, and location

Each player has limited personal visibility around their operative. Darkness hides threats, routes, and teammates outside that information boundary. The server remains authoritative over meaningful visibility-dependent gameplay state; the client presents local lighting, occlusion, indicators, and effects without being trusted to declare discoveries or targets valid.

The MVP includes a periodic location ping or comparable squad-location aid. It should reduce aimless wandering while preserving intervals of uncertainty. Communication should support concise status sharing—location, danger, ammunition, injury, and intent—without requiring a complex communication wheel in the MVP. Voice and text chat may be used through Roblox-native capabilities; exact accessibility aids remain to be designed.

## Enemy pressure and waves

Enemy pressure combines authored waves, roaming threats, and objective-triggered escalation. Basic hordes test movement, formation, ammo discipline, and recovery. One special enemy disrupts a reliable tactic and demands a clear response. Spawn rules must avoid unfair immediate appearances in validated player sight or unavoidable damage.

Waves are pacing tools, not isolated arenas. Their purpose is to force decisions about whether to hold, move, spend resources, rescue a teammate, or abandon a position. Pressure should escalate across the operation while still allowing short recovery windows.

## Automatic combat targeting

Operatives automatically acquire and fire on valid hostile targets within their weapon range. A target is valid only when all of the following are true:

- The hostile is visible to the operative under gameplay-relevant visibility rules.
- The operative has line of sight to the hostile.
- The operative is in a state that permits combat.
- The weapon has ammunition and is ready to fire.
- The hostile is alive, targetable, in range, and legal for that operative to attack.

Initial target priority is deterministic:

1. The closest valid hostile actively threatening the operative.
2. Otherwise, the closest valid hostile in range.

Automatic target acquisition, firing cadence, ammunition consumption, hit validation, damage, and target legality are server-authoritative. The client may immediately present a likely target, facing response, muzzle event, tracer, or equivalent feedback, but that presentation cannot establish ammunition truth, a legal hit, or damage.

A lightweight manual priority-target override may be considered later. It is not required for the first combat implementation or the MVP unless playtesting proves automatic priority insufficient.

## Boss encounter philosophy

The MVP boss is the authored climax, not merely a larger horde enemy. It must have readable behaviors, at least one coordination demand, and opportunities for multiple classes to contribute. The encounter should test lessons already taught by the operation and should not invalidate remaining ammo or recovery choices through an unexplained requirement. Failure must be attributable to decisions or execution players can improve.

## Movement and automatic-combat tradeoffs

Moving, positioning, reloading, reviving, repairing, using class abilities, interacting, and retreating compete for attention, position, and time. Firing is automatic when the server confirms a valid target and ready weapon, but players control the conditions that make effective fire possible.

- Effective or sustained automatic fire should require some commitment of range, line of sight, movement, facing, or positioning.
- Reloading creates a readable vulnerability window.
- Retreating preserves life and distance but may break line of sight, leave weapon range, reduce fire effectiveness, or expose slower teammates.
- Players should be able to make deliberate fighting withdrawals; movement must not be disabled so aggressively that combat becomes static.
- Class actions create protect-the-teammate moments without routinely removing a player from play for long periods.

## Chokepoints and temporary defensive positions

Buildings, narrow routes, and terrain can reduce exposure or concentrate enemies. No position is permanently safe. Limited supplies, multiple approach routes, special enemies, objective deadlines, or escalation should eventually make relocation preferable or necessary. The map must support dramatic retreats and last stands without offering a single dominant camping location.

## Progression, unlocks, and rewards

Persistent player XP advances a small military-style rank ladder. Rank expresses career experience and unlocks specialist classes or side-grade options; it is not a license to bypass core difficulty.

- **Failure rewards:** limited XP for meaningful participation and contribution, with safeguards against idle farming. Failure should preserve a sense of forward motion without becoming the optimal progression strategy.
- **Victory rewards:** a clear outcome bonus plus contribution-based XP. Higher difficulty or optional challenge rewards may be considered later.
- **Class unlocks:** at least one specialist class becomes available through attainable rank progression. Unlocks broaden squad strategies rather than replace starting classes with stronger versions.
- **Permanent bonuses:** absent from the MVP unless a later specification proves a very small bonus improves motivation without reducing meaningful difficulty.

Exact rank names, XP curves, contribution rules, and data-store failure behavior require dedicated specifications.

## MVP success criteria

The MVP succeeds when:

- A complete 1–4 player operation can end in success or failure without developer intervention.
- Separated spawning produces tension without prolonged confusion.
- Players value regrouping and can identify why each class matters.
- Ammunition and recovery decisions change team behavior.
- At least one defensive position is useful temporarily but not indefinitely optimal.
- Enemy escalation, the special enemy, and the boss have readable counterplay.
- Movement and firearm use create meaningful tactical tradeoffs.
- Failed runs teach useful lessons and grant limited persistent progress.
- Victory depends primarily on coordination, knowledge, execution, and resource management.
- Persistent XP, ranks, an unlockable class, and both result screens function reliably.

## Explicit MVP exclusions

- Open world
- MMORPG structure
- Player-versus-player combat
- Large social hubs
- Trading
- Crafting trees
- Dozens of weapons
- Large class roster
- Multiple operation maps
- Clans or guilds
- Battle pass
- Paid power
- Mandatory paid progression shortcuts
- Procedurally generated world
- Vehicles
- Base building
- RTS unit selection
- Worker economy
- Barracks production
- Army command
- Multiple factions
- Detailed final art beyond what is necessary for readability

## Deferred design questions

Operation duration, auto-target switching behavior, the definition of an actively threatening hostile, whether manual priority override becomes necessary, control support beyond desktop, friendly fire, class duplication, solo scaling, incapacitation limits, inventory transfer, reconnaissance mechanics, rank names, XP curves, and the final unlockable class are intentionally unresolved. Each must be answered by focused specification or prototype work rather than assumed during unrelated implementation.
