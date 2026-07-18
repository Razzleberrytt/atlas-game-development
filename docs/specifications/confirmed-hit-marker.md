# Confirmed Hit Marker — HROI-0110 v1

## Goal

Make automatic firearm combat feel immediately responsive from the elevated isometric camera without changing any gameplay truth or inflating rewards.

The existing weapon presentation already provides muzzle flash, tracer, casing, and impact geometry. This slice closes the remaining local-feedback gap by placing a crisp shooter-specific marker directly over the accepted server-disclosed impact position.

## Player-facing behavior

- A confirmed damaging shot from the local operative produces a four-arm impact marker at the enemy's world position.
- Misses, blocked shots, malformed disclosures, other players' shots, and duplicate ShotIds produce no marker.
- Consecutive confirmed hits within 0.72 seconds build a visible `CONFIRMED xN` chain.
- At four hits the marker warms to orange; at eight hits it escalates to red.
- The marker rapidly expands and fades over 0.34 seconds, preserving combat visibility.
- The marker tracks the impact world position through the active camera for its short lifetime instead of pretending the screen center is the target.

## Truth and authority

`ConfirmedHitMarkerController` consumes only the existing `CombatPresentation/ShotFired` server disclosure and requires:

- a unique non-empty ShotId
- the local operative entity identity
- the configured basic firearm identity
- a non-empty target entity identity
- `didApplyDamage == true`
- a server-disclosed Vector3 impact position
- a finite server timestamp

The controller creates no remote and cannot request fire, choose a target, spend ammunition, resolve a hit, apply damage, establish death, award Field XP, select an upgrade, create loot, or alter mission state.

## Runtime bounds

- one fixed ScreenGui
- one fixed marker root
- four fixed marker arms
- one fixed center point
- one fixed text label
- one CombatPresentation connection
- one RenderStepped connection
- at most 128 remembered ShotIds
- zero Instances created per shot
- zero per-shot tasks, tweens, particles, sounds, remotes, or server work

## Product rationale

Living Kingdoms now has dense horde pressure, blood impact, Field XP, upgrades, loot, and a unified HUD. The highest-return remaining presentation improvement is shooter ownership: the player needs an unmistakable signal that *their* automatic fire connected. Anchoring the confirmation to the real server-disclosed impact keeps the effect useful in an isometric auto-targeting game and avoids a misleading center-screen crosshair.

## Acceptance gate

Automated validation must pass StyLua, Selene, every Lune fixture, and Rojo build. Studio review must confirm:

1. accepted local hits display at the struck enemy position
2. misses and blocked shots display nothing
3. another operative's hits display nothing
4. duplicate ShotIds display once
5. rapid automatic hits build the chain cleanly
6. the marker remains readable over bright and dark terrain
7. the marker does not obscure the target, upgrade overlay, or critical-condition warning
8. desktop and touch aspect ratios retain accurate world-to-screen placement
9. no warnings or runtime errors occur across spawn, respawn, camera replacement, death, revive, and extraction
