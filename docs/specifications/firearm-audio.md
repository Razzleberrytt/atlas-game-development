# Firearm Audio — AUD-0101 / AUD-0102

## Goal

Give the firearm roster audible fire, reload, empty, and handling feedback
without adding any client combat authority, and keep it audible under the fixed
overhead isometric camera.

## Behaviour

- `WeaponAudioController` (client) listens to the same authoritative
  `CombatNetwork.CombatPresentation` disclosure the visual effects use.
- On a `ShotFired` message for a configured firearm it plays a pooled 2D fire
  sound; on `ReloadStarted` it plays a reload sound.
- On `ReloadCompleted` it stops that operative's reload sound and plays a short
  handling (rack) cue; on `ReloadInterrupted` it stops the reload sound with no
  completion cue, so an interrupted reload no longer keeps ringing.
- When the server's personal ammunition disclosure (`AmmunitionState` /
  `AmmunitionCollected`) reports the local operative's loaded rounds reaching
  zero from a positive count, a quiet empty click plays — the "you're dry,
  reload" cue. The click is throttled by a configured minimum interval so
  repeated disclosures read as feedback rather than noise.
- The local operative's own fire is louder; other operatives' fire is quieter,
  giving squad awareness without positional attenuation (the listener camera is
  far overhead, so 3D rolloff would make every gun sound distant).
- Each shot claims the next slot of a fixed, reused `Sound` pool
  (`FirearmAudioConfig.FirePoolSize`), so sustained automatic fire never creates
  unbounded instances. The reload, empty, and handling cues are single reused
  `Sound` instances. A small per-shot pitch scatter keeps fire from looping.
- Per-weapon `WeaponFeelConfig` profiles scale volume and playback speed only,
  so the five-weapon roster reads distinctly from one shared asset set.

## Authority

The controller creates no remote and never requests fire, resolves a hit, spends
ammunition, or reaches the server. It only reacts to messages the server already
chose to broadcast; the empty click derives from the personal ammunition
disclosure the HUD already receives. Fire resolution, ammunition, and reload
timing remain owned by the existing server systems.

## Assets

Approved free Creator Store audio, verified to load in Studio:

- Fire: `rbxassetid://165946267`
- Reload: `rbxassetid://7058441251`

The AUD-0102 empty click and handling cue are temporary derivations of the
verified reload asset replayed at raised speed, so the set covers fire, reload,
empty, and handling today without introducing unverified asset IDs.

`VisualAssetConfig` records `AudioBasicFirearm` as `TemporaryPresentation` owned
by `WeaponAudioController`. Unique production-approved empty and handling
assets and a Studio mix review remain pending before this family can pass the
production-approval gates.

## Regression protection

`FirearmAudioSourceAudit` locks the client-local, server-deferred, bounded-pool
shape: real asset IDs for all four cues, exactly one construction site per
Sound, the empty-click throttle, reload stop-on-interrupt, and the single
bootstrap start.
