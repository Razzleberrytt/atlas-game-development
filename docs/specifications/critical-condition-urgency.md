# Critical Condition Urgency — HROI-0109 v1

## Goal

Make low health feel immediately dangerous from the elevated isometric camera without changing health, damage, ammunition scarcity, enemy behavior, or any other gameplay truth.

## Player-facing behavior

- At or below 25% canonical P3 health while Alive, four blood-red screen edges begin pulsing.
- The warning reads **CRITICAL CONDITION** and includes the current health percentage.
- At or below 10% health, the presentation escalates to **MORTAL CONDITION**, becomes brighter, and pulses faster.
- The warning disappears immediately when health rises above the threshold or the operative is no longer Alive.
- The existing horde HUD remains above the edge treatment and readable.

## Authority

`CriticalConditionController` reads only these existing server-replicated player attributes:

- `LK_P3_CurrentHealth`
- `LK_P3_MaximumHealth`
- `LK_P3_LifeState`

The controller cannot submit a health value, life state, damage event, recovery result, or any other gameplay request. It creates no remote and calls no authoritative service.

## Runtime bounds

- one client controller
- one RenderStepped connection
- four fixed edge frames
- four fixed UI gradients
- one fixed warning label
- zero Instances created after startup
- zero tweens, delayed tasks, spawned tasks, particles, sounds, remotes, or server work
- zero gameplay-state mutation

## Product rationale

Living Kingdoms now has dense horde pressure and a deliberately brutal ammunition economy. The next high-return improvement is not additional reward inflation; it is stronger communication of danger. This presentation turns low health from a small bar-state change into a clear survival emergency while preserving the harsh resource model.

## Acceptance gate

Automated validation must pass StyLua, Selene, every Lune fixture, and Rojo build. Studio review must confirm:

1. no critical overlay appears above 25% health
2. CRITICAL CONDITION appears at 25% health or below while Alive
3. MORTAL CONDITION appears at 10% health or below
4. pulse intensity grows as health falls
5. the overlay hides when healed or when life state changes from Alive
6. the horde HUD, upgrade choices, aiming, and combat space remain readable
7. desktop and touch aspect ratios retain full edge coverage
8. no warnings or runtime errors occur across spawn, damage, heal, incapacitation, revive, death, and respawn
