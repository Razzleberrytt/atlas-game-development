# BA-005 Quest Board Reconstruction

The Studio-authored `Workspace/HubTown/quest_board` is now represented as a held, property-backed authored-overworld presentation contract:

`games/living-kingdoms/src/shared/Config/RecoveredQuestBoardConfig.luau`

## Recovery coverage

The original subtree contains **16 identity rows**:

- 1 root Folder represented by the generated container
- **15 / 15 non-container nodes with property-backed reconstruction data**
- 0 pending nodes
- 3 known visual-property omissions: the three TextLabel `FontFace` values

Recovered classes:

- 9 Parts
- 1 PointLight
- 1 SurfaceGui
- 1 BillboardGui
- 3 TextLabels

The BillboardGui required no new binary value type. It uses the UDim2, Vector2, Vector3, reference, float, bool, and token decoders already verified by the BA-005 presentation tooling.

## Recovered authored structure

The board is a compact wooden stall centered around Z = `-38` in the authored HubTown coordinate space.

Important recovered geometry includes:

- stall floor: `(0, 0.5, -38)`, size `8 x 1 x 6`
- counter: `(0, 2.5, -35)`, size `8 x 3 x 1`
- canopy: `(0, 8, -38)`, size `8 x 0.5 x 6`
- invisible sign anchor: `(0, 9, -38)`, size `4 x 1 x 0.2`
- main board: `(0, 3.5, -38)`, size `4 x 3 x 0.3`
- four wooden posts at X `±3.5` and Z `-35.5 / -40.5`
- warm PointLight on the stall floor: brightness `1.5`, range `12`

All positions remain 1:1 authored-overworld coordinates. This content is not moved into the current operation forest.

## Recovered board/sign text

The board SurfaceGui fills an `800 x 600` canvas at `PixelsPerStud = 50` and contains:

> `ADVENTURER'S BOARD`  
> `[B] to view bounties`

The invisible sign anchor also owns an always-on-top BillboardGui:

- size `200 x 50` pixels
- offset `(0, 2, 0)` studs
- infinite max distance

Its two recovered labels read:

> `Adventurer's Board`

and:

> `[G] Quest Board`

The old `[B]` and `[G]` text is **presentation evidence only**. It is not a modern input mapping.

## No recovered prompt is invented

This subtree contains no recovered `ProximityPrompt`.

The contract therefore declares:

- `RecoveredPromptExists = false`
- no modern interaction is activated
- no input binding is inferred from legacy sign text

## Gameplay authority boundary

The legacy QuestService must **not** return.

The current `MissionDirectorService` is also not a quest-selection endpoint. It deliberately owns one authoritative operation objective chain and accepts no client-authored objective mutation once the operation is running.

Therefore the future board flow must be:

1. player uses a new, source-managed board interaction in the authored overworld
2. a new **pre-launch operation/mission selection contract** validates the choice server-side
3. the selected operation is handed into the canonical expedition preparation/launch flow
4. once the operation begins, `MissionDirectorService` owns objective progression exactly as it does today

The quest-board reconstruction contract encodes these guardrails:

- `LegacyQuestServiceAuthority = false`
- `FuturePrelaunchSelectionContractRequired = true`
- `DirectMissionDirectorClientMutationAllowed = false`
- `MissionDirectorRemainsOperationRuntimeAuthority = true`
- `CanonicalExpeditionAuthority = "ExpeditionLobbyService"`
- runtime disabled

## Source hold

The quest board remains inert:

- `CoordinateSpaceId = "authored-overworld"`
- `SourceHold = true`
- `RuntimeEnabled = false`

No current operation bootstrap requires this config.

## Billboard recovery tooling

BillboardGui recovery is exposed through:

`scripts/roblox/extract_rbxl_billboard_properties.py`

It is a thin overlay on the existing presentation decoder and introduces no new binary value decoder.

## Known visual omissions

The three TextLabels serialize `FontFace` as type `0x20`, which is not yet decoded. Their text, layout, sizing, alignment, colors, transparency and wrapping behavior are recovered, but exact font parity is not claimed.

## Next safe step

The next implementation task should define the **pre-launch operation-selection contract** in isolation, with no live board binding yet. That contract should answer:

- what operation IDs are selectable
- how availability/unlocks are server-validated
- how a selection becomes expedition preparation state
- how party ownership/consensus works
- how MissionDirector receives only a validated operation definition at launch

Only after that contract is tested should the authored-overworld board become interactive.
