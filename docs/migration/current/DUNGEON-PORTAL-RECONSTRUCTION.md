# BA-005 DungeonPortal Reconstruction

The first property-backed authored-overworld object group is now represented as an **inert source contract**:

`games/living-kingdoms/src/shared/Config/RecoveredDungeonPortalConfig.luau`

Source group:

`Workspace/HubTown/DungeonPortal`

## What is recovered now

The original group contains **10 identity rows**. BA-005 currently represents them as:

- 1 generated container (`DungeonPortal` folder)
- 6 property-backed recovered nodes
- 3 identity-backed nodes whose remaining presentation properties are intentionally pending

### Property-backed nodes

| Source node | Class | Recovered evidence |
|---|---|---|
| `PortalFrame` | Part | position `(0, 8, 22)`, size `10 x 16 x 4`, material enum `800`, RGB `70/65/60`, collidable |
| `PortalGlow` | PointLight | brightness `3`, range `25`, purple color, enabled |
| `PortalEffect` | Part | position `(0, 8, 22)`, size `8 x 14 x 2`, material enum `288`, RGB `100/200/255`, transparency `0.4`, non-collidable |
| `PointLight` | PointLight | brightness `3`, range `20`, blue color, enabled |
| `PortalSwirlAttach` | Attachment | identity CFrame at the PortalEffect origin |
| `PortalSign` | Part | position `(0, 17, 22)`, size `8 x 2 x 0.5`, material enum `528`, RGB `80/55/25`, collidable |

All three recovered Parts use identity rotation and preserve their original authored-overworld coordinates.

### Pending property nodes

The following nodes are preserved by identity but are **not yet claimed as property-perfect**:

- `PortalEffect/PortalSwirlAttach/PortalSwirl` — `ParticleEmitter`
- `PortalSign/SurfaceGui` — `SurfaceGui`
- `PortalSign/SurfaceGui/TextLabel` — `TextLabel`

Their class/path/source IDs are preserved. Their remaining particle sequence and UI layout/font properties stay pending until the RBXL property decoder is extended and verified for those types.

No substitute values should be invented merely to make the portal look complete.

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

DungeonPortal is a useful proof of the combined-game architecture because it connects the strongest ideas from both versions without creating duplicate authority:

- the older Studio game contributes the authored portal structure and its original location inside HubTown
- the modern repo retains expedition membership, readiness, launch and runtime authority

That is the merge pattern to repeat throughout the authored overworld: **recover the old world faithfully; route gameplay through modern owners.**

## Next safe work

The strongest next step is to extend the property decoder for the basic `SurfaceGui` / `TextLabel` types required by the recovered sign. ParticleEmitter sequence support can follow separately.

After those properties are verified, the portal presentation contract can reach a higher visual-parity level without guessing. It should still remain held until the dedicated authored-overworld lifecycle/place boundary exists.
