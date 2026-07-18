# Firearm Audio — AUD-0101

## Goal

Give the Blackwater Support LMG audible fire and reload feedback without adding
any client combat authority, and keep it audible under the fixed overhead
isometric camera.

## Behaviour

- `WeaponAudioController` (client) listens to the same authoritative
  `CombatNetwork.CombatPresentation` disclosure the visual effects use.
- On a `ShotFired` message for the basic firearm it plays a pooled 2D fire
  sound; on `ReloadStarted` it plays a reload sound.
- The local operative's own fire is louder; other operatives' fire is quieter,
  giving squad awareness without positional attenuation (the listener camera is
  far overhead, so 3D rolloff would make every gun sound distant).
- Each shot claims the next slot of a fixed, reused `Sound` pool
  (`FirearmAudioConfig.FirePoolSize`), so sustained automatic fire never creates
  unbounded instances. A small per-shot pitch scatter keeps it from looping.

## Authority

The controller creates no remote and never requests fire, resolves a hit, spends
ammunition, or reaches the server. It only reacts to messages the server already
chose to broadcast. Fire resolution, ammunition, and reload timing remain owned
by the existing server systems.

## Assets

Approved free Creator Store audio, verified to load in Studio:

- Fire: `rbxassetid://165946267`
- Reload: `rbxassetid://7058441251`

`VisualAssetConfig` records `AudioBasicFirearm` as `TemporaryPresentation` owned
by `WeaponAudioController`; a production-approved firearm audio pass is still
pending.

## Regression protection

`FirearmAudioSourceAudit` locks the client-local, server-deferred, bounded-pool
shape and the single bootstrap start.
