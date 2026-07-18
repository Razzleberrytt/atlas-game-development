# Living Kingdoms — Horde-Horror Vertical Slice

> **Superseded in part by [horde-single-source-of-truth.md](horde-single-source-of-truth.md).**
> The stabilization pass consolidated progression into a single authoritative
> pipeline. Where this document describes `HordeExperienceService` minting XP,
> upgrades, loot, healing, ammunition, weapon overcharge, or a second upgrade
> remote, the single-source-of-truth spec is now canonical: Field XP, levels,
> upgrades, and combat modifiers belong to `RunProgressionService`; ammunition
> loot belongs to `EnemyLootService`; `HordeExperienceService` owns only
> spawning, pressure, roles/behaviour, threat, a non-rewarding massacre streak,
> and the event feed.

## Purpose

Turn the technically functional prototype into a dense, rewarding, frightening 8–12 minute operation before investing in a much larger streamed world.

This slice proves four things:

1. Automatic combat can feel violent and satisfying.
2. Enemy pressure can remain intense without abandoning server authority.
3. Kills can feed immediate XP, upgrades, loot, streak, and audiovisual reward loops.
4. The authored mission can build toward a readable extraction climax.

## Player fantasy

A small specialist squad enters Blackwater, activates a relay, draws the attention of the entire exclusion zone, and fights through increasingly strange infected until extraction arrives.

Players begin in the same insertion area rather than at distant isolated map corners. The operation still asks them to regroup, but the regroup should take seconds rather than create a long lonely opening.

## Core loop

1. Regroup during the shortened insertion window.
2. Move toward the relay while ambient hordes begin closing in.
3. Kill enemies to gain shared run XP and build massacre streaks.
4. Choose one of three server-offered upgrades on level-up.
5. Collect ammunition, medical, surge, and weapon-overcharge drops.
6. Restore the relay and trigger larger authored waves.
7. Reach the extraction clearing.
8. Survive a two-minute final horde.
9. Extract or lose the operation.

## Enemy roles

The existing server-owned Exclusion Walker remains the authoritative lifecycle body. Horde roles are server-owned overlays that alter presentation, minimum movement speed, reward value, and special behavior without adding a client enemy-authority surface.

- **Hollow Infected** — primary swarm body.
- **Razor Runner** — faster pressure unit.
- **Grave Crawler** — smaller, low-profile horror silhouette.
- **Choir Screamer** — periodically summons nearby reinforcements.
- **Rot Bloater** — damages living operatives in a server-resolved death burst.
- **Grief Brute** — large elite that returns in a second phase after its first death.

## Pressure model

Two bounded sources create pressure:

- the retained `EnemyDirectorService` roaming and authored-wave systems;
- `HordeExperienceService` horde injections around living operatives.

The global population cap is 96. Spawn cadence and group size increase with a 0–100 threat value derived from elapsed operation time, living-enemy count, and squad kill count. All spawns continue through the existing server fair-spawn and population-cap validation.

No per-enemy heartbeat is added. The horde layer uses one server heartbeat and iterates the bounded enemy collection.

## Run progression

The canonical RunProgressionService awards shared Field XP from confirmed deaths. The horde layer observes Field Level changes and creates three deterministic server-authored upgrade choices without minting XP itself. Consecutive kills remain a combat-feedback streak rather than an XP multiplier.

Implemented upgrades:

- Bloodlust
- Scavenger Instinct
- Ammo Scrounger
- Trauma Kit
- Second Wind
- Executioner

The client sends only the selected offered upgrade ID. The server confirms that the player currently owns that exact offer, applies stack limits, and commits every consequential effect.

## Loot

Server-created world drops use bounded ProximityPrompts and expire automatically.

- Rifle ammunition mutates reserve ammunition through the existing combat-state commit boundary.
- Trauma Gel restores authoritative operative health.
- Adrenal Surge grants a temporary XP multiplier and a small heal.
- Weapon Overcharge raises a run-only weapon tier; bonus damage is committed through the revisioned enemy-health boundary after an authoritative hit disclosure.

A maximum of 32 drops may exist at once.

## Feedback

The unified HUD replaces the separate temporary combat, life, and mission debug overlays. It displays:

- objective and radio text;
- threat and active hostile count;
- health and life state;
- revive progress;
- ammunition and reload feedback;
- level and XP;
- massacre streak and multiplier;
- squad state and distance;
- extraction countdown and outcome;
- loot, threat, heal, weapon, and level-up event feed;
- three-choice upgrade modal.

Client-only effects are gated by server-authored shot/death disclosure:

- blood impact particles;
- blood or corrosive death pools;
- kill XP billboards;
- bounded camera shake.

These effects do not select targets, apply damage, change health, create XP, or report hits.

## Authority boundary

The server owns:

- horde timing and composition;
- enemy role assignment and special behavior;
- threat;
- XP, levels, streak state, upgrade offers, stacks, and effects;
- loot identity, lifetime, collection validation, and rewards;
- healing, ammunition grants, weapon-tier bonus damage, death bursts, and recovery charges.

The client owns only presentation and one upgrade-choice request. Existing reload and revive requests remain unchanged and fully revalidated by their original server owners.

## Performance assumptions

The slice targets 1–4 players first.

- 96 global living-enemy cap.
- 32 global loot-drop cap.
- One horde-service heartbeat.
- Existing one enemy-director heartbeat.
- No new per-enemy timers or heartbeat connections.
- Client death tracking uses at most one attribute connection per bounded replicated enemy.
- Blood and kill effects use Debris cleanup.

The 96-enemy target is a playtest budget, not a proven production guarantee. Studio MicroProfiler evidence is required before merge.

## Deferred

- Enormous streamed world expansion.
- Procedural districts.
- Persistent account XP and unlocks.
- Full weapon rarity inventory.
- Production enemy meshes, animations, sound, gore assets, and accessibility controls.
- Advanced navigation and crowd steering.
- Boss encounters beyond the Brute second phase.
- Final economy and retention balancing.

A larger map remains intentionally deferred until this compact route proves fun.
