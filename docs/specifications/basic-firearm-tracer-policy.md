# Living Kingdoms — Basic Firearm Tracer Policy

## Status

Temporary VIS-0102 presentation policy for the Blackwater Service Carbine.

Runtime owner: `src/client/Presentation/WeaponShotEffectPresenter.luau`.

## Purpose

The elevated isometric camera benefits from a very short visual connection between a visible operative's muzzle and a server-confirmed damage endpoint. The tracer is a readability cue, not a projectile, hit resolver, or source of gameplay truth.

## Authority boundary

A tracer may appear only when all of the following are already true:

1. the server accepted the shot;
2. the server confirmed that damage was applied;
3. the server disclosed an authoritative impact world position; and
4. the client resolved the disclosed operative to the correct visible firearm rig.

The client derives only the presentation start from that rig's canonical `Muzzle` attachment. It may not infer a target, obstruction, miss endpoint, hit result, damage, health change, or ammunition state.

## Temporary implementation

- Use one thin, non-collidable, non-queryable neon Part.
- Keep the streak visible for approximately 0.055 seconds.
- Mark it `PresentationOnly` and attach the source shot ID for debugging.
- Remove it through bounded `Debris` cleanup.
- Skip degenerate paths shorter than 0.5 studs.
- Do not render a persistent beam, projectile simulation, bullet drop, ricochet, penetration, or client-predicted miss.

## Blocked and unconfirmed shots

Blocked, rejected, duplicate, or otherwise non-damaging shots must not display a tracer because the current server disclosure does not provide a truthful obstruction or miss endpoint. Muzzle flash and casing presentation may still occur for an accepted shot, but no path may be invented.

## Known limitation

The current endpoint is the server-owned enemy combat fact position rather than a precise surface contact point. The streak therefore communicates confirmed shot direction and target connection, not exact anatomy or material contact. A future server-owned surface-hit contract may replace this endpoint without widening client authority.

## Production replacement

The temporary Part may later be replaced by an approved Beam, particle, or authored effect if the same authority, lifetime, cleanup, accessibility, and no-fabrication rules remain intact.
