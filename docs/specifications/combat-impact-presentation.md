# Combat impact presentation — HROI-0104 v1

Tracking: issue #98, **Horde Pressure & Run Reward Vertical Slice**.

## Goal

Make every confirmed enemy hit and kill visibly legible from the elevated isometric camera without creating a second combat-authority path.

This slice addresses the immediate playtest complaint that shooting enemies feels flat and kills feel unrewarding. It does not yet add XP, loot, audio, camera shake, ragdolls, surface decals, or persistent gore.

## Truth source

The client consumes only the existing ordinary replicated enemy presentation attributes:

- `EnemyPresentationHitSequence`
- `EnemyPresentationLifeStateId`

The server increments the hit sequence only after an accepted monotonic enemy-health commit. The server changes life state to `Dead` only after that same authoritative health boundary reaches zero. The client never reads Humanoid health, predicts a hit, infers death from anchoring, or asks the server to apply an effect.

## Presentation

Each tracked Exclusion Walker receives client-local cosmetic children:

- one attachment on the replicated authoritative root
- one disabled hit-burst particle emitter
- one disabled kill-burst particle emitter
- one disabled occluded highlight

A new confirmed hit sequence emits a seven-particle dark-red burst and a brief warm impact flash. A transition into the confirmed dead life state emits a stronger twenty-two-particle burst and a longer red kill flash. Death takes precedence when the hit and death disclosures arrive together, preventing double spectacle from one killing shot.

Particles use a built-in Roblox texture and exist only on the observing client. They do not replicate, collide, touch, query, alter mass, or survive the authoritative enemy model cleanup.

## Runtime bounds

- maximum tracked enemies: 24 (the current validated global population ceiling)
- maximum effect distance from the active camera: 140 studs
- hit burst: 7 particles
- kill burst: 22 particles
- hit flash: 0.08 seconds
- kill flash: 0.18 seconds
- two folder-level lifecycle connections
- one client RenderStepped connection
- zero per-enemy connections
- zero remotes
- zero delayed tasks
- zero Debris scheduling
- zero persistent splatter parts or decals

The controller tracks the current hard global enemy ceiling and skips cosmetic emission outside the camera-distance budget. Attribute sequences still advance while culled so old effects are never replayed when the camera returns.

## Authority boundary

The controller cannot:

- select a target
- establish a hit
- apply damage
- read or change health
- establish death
- move an enemy
- alter collision or network ownership
- change corpse cleanup
- award XP
- create gameplay loot
- change mission state

The highlight and particle emitters are presentation-only descendants created locally beneath replicated enemy instances.

## Validation

`EnemyImpactPresentationSourceAudit.test.luau` locks:

- immutable numeric budgets
- server-confirmed hit and death attribute consumption
- death-over-hit precedence
- hit and kill emitter calls
- occlusion-respecting highlight use
- camera-distance and enemy-count bounds
- exactly three global connections
- bootstrap integration
- absence of remotes, delayed tasks, damage APIs, movement APIs, health commits, and network-ownership writes

## Remaining HROI-0104 work

- weapon muzzle flash and stronger tracer readability
- local-player hit marker and distinct kill confirmation tied to shooter identity
- firearm and impact audio
- directional hit reaction tuning
- bounded corpse physics or stronger death pose
- optional surface splatter with strict pooling and cleanup
- camera-shake and blood-intensity accessibility controls
- representative Studio review at the current 24-enemy ceiling, then again before any future increase toward forty
