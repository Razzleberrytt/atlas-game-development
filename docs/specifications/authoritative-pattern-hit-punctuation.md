# Authoritative Pattern-Hit Punctuation

## Purpose

Make the existing shotgun cone cleave and sniper line pierce unmistakable when one accepted shot damages multiple hostiles. The pass strengthens weapon identity without adding damage, rewards, targeting input, or another HUD owner.

## Authoritative input

`OperativeCombatRuntimeService` already emits one server-authored `ShotFired` presentation disclosure containing the primary impact and up to three bounded `secondaryImpacts`. Each secondary entry carries its target entity ID, committed damage amount, and impact world position.

`ConfirmedHitMarkerController` may render those facts only when:

- the shooter is the local operative;
- the shot ID is new;
- primary damage was committed;
- the weapon has a known `WeaponPatternConfig` definition;
- every secondary impact is structurally valid; and
- the count does not exceed both the weapon definition and the global cap of three.

## Presentation

- Ordinary and single-target hits retain the existing `HIT CONFIRMED` / rapid-confirmation treatment.
- Shotgun cone damage with at least one secondary target renders `BREACH CLEAVE xN`.
- Sniper penetration with one secondary target renders `LINE PIERCE x2`.
- Pattern confirmation uses a mode-specific color, a seven-pixel radius bonus, and a restrained fixed scale pulse.
- Existing authoritative secondary tracers remain the spatial explanation of which hostiles were damaged.

## Runtime and authority bounds

- No new remote, request, controller, frame loop, audio source, particle system, reward, or server state.
- The existing marker keeps exactly one disclosure connection, one `RenderStepped` connection, four fixed arms, one label, and one fixed `UIScale`.
- Maximum secondary-impact work is three entries per accepted local shot.
- The client cannot establish targeting, hits, damage, death, XP, loot, ammunition, health, cadence, movement, or mission progress.

## Studio acceptance

Review from the isometric gameplay camera with the breach shotgun and sniper rifle. Confirm that multi-target shots are immediately legible, ordinary hits remain quiet, text does not collide with damage numbers, pattern colors remain readable, the pulse is comfortable, and rapid horde combat does not produce distracting overlap.
