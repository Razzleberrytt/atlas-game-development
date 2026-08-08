# Pre-launch Operation Selection Contract

The recovered authored-overworld quest board now has a safe integration seam without becoming a backdoor into the live mission runtime.

Shared contract:

`games/living-kingdoms/src/shared/Operations/OperationSelectionContracts.luau`

Held catalog:

`games/living-kingdoms/src/shared/Config/OperationSelectionConfig.luau`

## Current status

This is **contract-only** work.

- runtime selection service: not implemented
- network binding: disabled
- quest-board binding: disabled
- launch handoff: not ready
- selection state: `Held`
- current selected/default operation: `first-expedition`
- current catalog size: 1

No server bootstrap or client controller requires these modules yet.

## Why a new layer is required

The recovered quest board is a pre-launch overworld concept. The current mission runtime is not a quest-picker: once an operation is running, its mission owner controls the authoritative objective chain and accepts no client-authored objective mutation.

The current expedition runtime also still starts its single configured expedition without consuming a validated operation-definition ID from the lobby.

Therefore the safe architecture is:

**authored-overworld quest board → server-validated pre-launch operation selection → expedition preparation/readiness → validated launch handoff → authoritative operation mission runtime**

The selection layer belongs before launch, not inside the running mission state machine.

## Initial catalog

Only one operation is exposed because it is the only expedition the current runtime can launch safely:

- operation ID: `first-expedition`
- display name: `The First Descent`
- minimum players: 1
- maximum players: 4
- target duration: 480 seconds
- current launch compatibility: true

The fixture compares these values directly against `ExpeditionConfig.Definitions.FirstExpedition`, so the catalog cannot silently drift from the real expedition definition.

## Safe payloads

The shared contract defines four bounded payload shapes:

### Safe operation summary

Client-readable metadata only:

- operation ID
- display name
- minimum/maximum players
- target duration
- whether the operation is currently launch-compatible

### Selection snapshot

Server-authored state:

- catalog revision
- selection revision
- state ID (`Held`, `Open`, or `Locked`)
- selected operation ID
- safe operation summaries

A snapshot is rejected by the validator if:

- it contains unknown keys
- revisions are invalid
- the state ID is unknown
- operation IDs are duplicated
- the selected operation does not exist in the disclosed catalog

### Selection intent

Future client request shape only:

- `requestId`
- `operationId`
- `expectedSelectionRevision`

Shape validation does **not** grant permission. A future server owner must separately verify operation availability, lobby membership, selection state, revision, and whatever party-consensus policy is eventually adopted.

### Safe rejection

A bounded server-authored rejection may disclose only the request ID, current selection revision, and a known rejection reason.

## No invented party leader

The current expedition lobby does not have a host/leader ownership model. It tracks membership and readiness only.

This contract therefore does not invent leader-only mutation semantics.

Current config explicitly records:

- party-leader concept required: false
- party-leader concept exists today: false
- selection mutation policy: `pending-server-policy`

The future policy can be designed deliberately once the desired co-op UX is chosen. Possible policies such as unanimous selection, first-join owner, majority vote, or server-assigned owner are intentionally **not** chosen in this contract-only pass.

## Mission-runtime boundary

The contract explicitly forbids client mutation of the live mission runtime.

A future launch adapter must consume a **server-validated operation definition**. After launch, the existing mission runtime remains authoritative for objective progression.

The quest board should never send objective-completion facts, mission phase changes, rewards, enemy state, or persistence mutations.

## Why launch handoff is still held

The current expedition start options contain seed, party size, and run ID. They do not yet carry an operation/expedition definition ID through the launch boundary, and the runtime still uses the first configured expedition definition directly.

Until that seam is refactored and tested:

- `RuntimeEnabled = false`
- `NetworkBindingEnabled = false`
- `LaunchHandoffReady = false`
- `QuestBoardBindingEnabled = false`

## Next safe implementation step

Add the server-side selection state owner **without binding it to the authored quest board yet**.

That owner should:

1. build safe snapshots from the held catalog
2. reject all mutation while runtime selection remains disabled
3. establish revision semantics and server-side operation lookup
4. integrate read-only state with the existing expedition lobby
5. only later open mutation after a party-consensus policy and operation-ID launch handoff are implemented and tested

The authored quest board remains visually recoverable and source-held until those prerequisites are complete.
