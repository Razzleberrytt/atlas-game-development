# Living Kingdoms — Massacre Crescendo

## Purpose

The horde runtime already owns a four-second, non-rewarding kill streak and the unified HUD previously rendered it as a single static `MASSACRE xN` line. That left a high-value authoritative combat signal almost completely inert.

This pass turns the existing streak into escalating audiovisual feedback without creating a new reward economy or changing combat balance.

## Player-facing behavior

The presentation becomes visible at two kills inside the existing authoritative streak window and escalates through five readable tiers:

| Streak | Tier | Secondary line |
|---:|---|---|
| 2 | `KILL CHAIN` | `KEEP MOVING` |
| 4 | `SLAUGHTER` | `PRESS THE HORDE` |
| 7 | `MASSACRE` | `NO BREATHING ROOM` |
| 11 | `ANNIHILATION` | `BREAK THEIR LINE` |
| 16 | `APOCALYPSE` | `THE HORDE IS BLEEDING` |

Every confirmed streak increase punches the fixed panel through a brief scale pulse and subtle full-screen color flash. Crossing a tier plays one throttled stinger. A narrow bar drains against the exact server-authored streak expiry and disappears when the four-second chain ends.

The presentation is deliberately non-rewarding. It grants no Field XP, upgrade progress, loot, ammunition, healing, damage, fire-rate, movement, targeting, threat reduction, or mission advantage.

## Authority boundary

`HordeExperienceService` remains the sole streak owner. It already derives streak count from server-observed enemy deaths and resets the streak using `HordeExperienceConfig.Streak.KillStreakWindowSeconds`.

The existing `HordeNetwork.State` snapshot gains one disclosure:

- `streakExpiresServerTimestamp`

For visible streaks, that value is exactly `lastKillServerTimestamp + KillStreakWindowSeconds`; otherwise it is zero. The client cannot submit a kill, extend the deadline, choose a tier, or request any reward.

## Presentation ownership and bounds

`MassacreCrescendoController` owns the feature as fixed client-local presentation:

- one `HordeNetwork.State` connection;
- one `RenderStepped` connection;
- one fixed `ScreenGui` and fixed descendants;
- one fixed `Sound` for tier crossings;
- zero per-kill Instances, tweens, tasks, or particles;
- no remotes sent to the server;
- no gameplay-state reads beyond the existing horde disclosure.

The stinger reuses the project’s Studio-verified firearm asset at bounded lower playback speeds. Unique production-approved UI stingers and a Studio mix review remain future polish.

The previous static streak label is removed from `HordeHUDController` so there is exactly one streak presentation owner.

## Late join and lifecycle behavior

- First sight of an existing streak renders silently, preventing a stale tier stinger on join.
- Subsequent authoritative streak increases pulse immediately.
- A tier stinger plays only when crossing into a higher tier and is globally throttled.
- The exact server deadline drives the drain bar; local frame rate cannot extend the chain.
- Teardown disconnects both connections, destroys the fixed GUI and Sound, and resets all cached state.

## Acceptance gates

Automated:

- StyLua formatting;
- Selene with zero findings;
- complete Living Kingdoms Lune fixture suite;
- Rojo build;
- config fixture locking thresholds, copy, verified sound reuse, and bounds;
- source audit locking authoritative expiry disclosure, fixed construction, single ownership, and zero reward authority.

Roblox Studio remains required to judge:

- readability under bright and dark terrain;
- whether pulses and flashes feel satisfying without obscuring combat;
- tier timing under shotgun cleave, sniper pierce, and automatic-fire chains;
- stinger mix against weapons, hostile cues, and special-role warnings;
- desktop and touch safe-area behavior;
- two-client consistency and representative horde performance.
