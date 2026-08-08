# BA-005 DungeonPortal Reconstruction

The first property-backed authored-overworld object group is represented as an **inert source contract**:

`games/living-kingdoms/src/shared/Config/RecoveredDungeonPortalConfig.luau`

Source group:

`Workspace/HubTown/DungeonPortal`

## Current recovery level

The original group contains **10 identity rows**. BA-005 now represents them as:

- 1 generated container (`DungeonPortal` folder)
- **9 / 9 non-container nodes with decoded reconstruction properties**
- 0 property-pending nodes
- 1 known visual-property omission: the TextLabel `FontFace` binary value

This is substantially stronger than the first portal contract, which deliberately held the particle and UI descendants until their binary types were verified.

## Recovered geometry and lights

| Source node | Class | Recovered evidence |
|---|---|---|
| `PortalFrame` | Part | position `(0, 8, 22)`, size `10 x 16 x 4`, material enum `800`, RGB `70/65/60`, collidable |
| `PortalGlow` | PointLight | brightness `3`, range `25`, purple color, enabled |
| `PortalEffect` | Part | position `(0, 8, 22)`, size `8 x 14 x 2`, material enum `288`, RGB `100/200/255`, transparency `0.4`, non-collidable |
| `PointLight` | PointLight | brightness `3`, range `20`, blue color, enabled |
| `PortalSwirlAttach` | Attachment | identity CFrame at the PortalEffect origin |
| `PortalSign` | Part | position `(0, 17, 22)`, size `8 x 2 x 0.5`, material enum `528`, RGB `80/55/25`, collidable |

All recovered Parts use identity rotation and preserve their original authored-overworld coordinates.

## Recovered sign presentation

The SurfaceGui is now property-backed:

- canvas size: `800 x 600`
- face enum value: `5`
- `PixelsPerStud = 50`
- brightness `1`
- enabled
- not always-on-top
- zero light influence / Z offset

The recovered TextLabel fills the full SurfaceGui and contains the original text:

> `ENTER THE DEPTHS`  
> `[G] to enter dungeon`

Recovered label behavior includes:

- `Position = UDim2(0, 0, 0, 0)`
- `Size = UDim2(1, 0, 1, 0)`
- background transparency `1`
- text scaled and wrapped
- visible
- pale-blue recovered text color
- X alignment enum value `2`
- Y alignment enum value `1`

The old `[G]` wording is **presentation evidence only**. It is not a modern input contract and must not be interpreted as permission to revive the old dungeon interaction code.

### Known UI omission

`TextLabel.FontFace` is serialized as binary type `0x20`, which is outside the current BA-005 presentation decoder scope.

The contract records that omission explicitly. Do not invent a font and call it exact parity.

## Recovered portal swirl

The portal ParticleEmitter is now property-backed, including its sequence types:

- texture: `rbxassetid://241876674`
- enabled
- rate: `40`
- lifetime: `2..3` seconds
- speed: `1..3`
- acceleration: `(0, 2, 0)`
- spread angle: `(360, 360)`
- purple color sequence from time `0` through `1`
- size sequence: `1 → 2 → 0.5`
- transparency sequence: approximately `0.8 → 0.2 → 0.8`
- no rotation speed
- time scale `1`
- zero velocity inheritance / drag / Z offset

The decoder extension that produced this evidence lives at:

`scripts/roblox/extract_rbxl_presentation_properties.py`

Committed evidence lives at:

`docs/migration/current/reextracted-presentation-evidence.json`

## No recovered prompt is invented

The recovered `DungeonPortal` subtree does **not** contain a `ProximityPrompt`.

Therefore this reconstruction contract does not fabricate one.

When the dedicated authored overworld eventually becomes live, its portal interaction should be added deliberately through current source-managed interaction code and should delegate to:

- canonical content ID: `portal.expedition.primary`
- canonical gameplay authority: `ExpeditionLobbyService`

The old DungeonService/HubTownService portal authority must not return.

## Source hold

The contract explicitly declares:

- `CoordinateSpaceId = "authored-overworld"`
- `SourceHold = true`
- `RuntimeEnabled = false`
- `LegacyGameplayAuthority = false`
- interaction `RuntimeEnabled = false`

No current runtime module requires this reconstruction config.

## Why this is the first HubTown slice

DungeonPortal demonstrates the merge pattern for the rest of the authored overworld:

- the older Studio game contributes authored structures, signs, lighting, atmosphere and spatial identity
- the modern repo retains expedition membership, readiness, launch and runtime authority

The rule remains: **recover the old world faithfully; route gameplay through modern owners.**

## Next safe work

The presentation decoder now also covers the UI/particle types used by other HubTown content. The next high-value reconstruction slice should reuse that capability on a coherent authored group such as the quest board, Central Fountain, or vendor presentation rather than widening runtime authority.

The portal itself remains held until the dedicated authored-overworld lifecycle/place boundary exists.
