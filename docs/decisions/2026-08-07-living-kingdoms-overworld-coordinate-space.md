# Decision — Preserve the recovered authored world as a separate overworld coordinate space

**Date:** 2026-08-07  
**Status:** Accepted for BA-005 reconstruction; runtime activation remains held

## Context

The repaired Studio import and BA-005 property decoder changed what is known about the older Living Kingdoms world.

The original authored content is not a small collection of decorations that can be pasted into the current operation forest:

- legacy `HubTown` is centered around the original world origin and spans roughly ±60 studs
- legacy `WorldPath` runs from near that hub to Z = -1500
- the Destiny Monolith core is centered at `(0, 200, -1500)` and is `80 x 400 x 80` studs
- the Crystal Tower begins around `(1500, 15, 0)`
- recovered `WorldStructures` Part positions span approximately X `-1844..2832`, Y `0.5..1400`, Z `-3184..1900`
- the current source-managed operation world is intentionally designed around a ±640-stud playable half extent

Scaling or translating the recovered authored world simply to make it fit inside the modern operation would destroy spatial relationships that are now recoverable from the original RBXL.

At the same time, running the legacy HubTown/gameplay services beside the modern combat, inventory, persistence, mission, class, weapon, and expedition owners would violate the merge authority boundary.

## Decision

Treat the recovered Studio-authored world as a **separate authored overworld coordinate space**.

### Authored Overworld

The following recovered roots belong to the authored-overworld space:

- `Workspace/HubTown`
- `Workspace/Resources`
- `Workspace/WorldPath`
- `Workspace/WorldStructures`
- `Workspace/SpawnLocation`
- `Workspace/AmbientFireflies`
- `Workspace/WorldClouds`

Reconstruction policy:

- preserve authored coordinates 1:1
- preserve scale at `1.0`
- apply no translation solely to fit the modern operation
- apply no global rotation solely to fit the modern operation
- reconstruct presentation/content from evidence
- do not resurrect legacy gameplay authority

### Modern Operation Space

The current `LivingKingdomsWorld` / `WorldFoundationService` forest remains a separate operation coordinate space and retains its current scale, landmarks, runtime ownership and ±640-stud design.

Recovered authored roots must not be parented under the operation foundation as a shortcut.

### Transition model

The intended architecture is:

**authored overworld / safe preparation world → canonical expedition launch → modern operation/expedition runtime**

`ExpeditionLobbyService` and the existing expedition runtime remain the gameplay authorities for launch/readiness/operation lifecycle.

The current Ranger Station Forward Operations Hub remains a transitional bridge until a dedicated overworld lifecycle/place boundary exists.

## Why this fits the combined game

This preserves the strongest parts of both versions instead of forcing one map to overwrite the other:

- the older game contributes its authored RPG overworld, hub, resources, landmarks and visual worldbuilding
- the newer repo retains its substantially stronger server-authoritative combat, progression, mission, expedition, persistence and networking architecture

It also matches the intended RPG structure better than placing every system in one combat arena: players can prepare/explore in a persistent safe world and launch into bounded co-op operations.

## Consequences

### Positive

- no destructive map scaling
- no collision between the old huge coordinate envelope and the current operation map
- HubTown can eventually become a real persistent social/preparation area
- major legacy world structures retain their authored spatial relationships
- current combat runtime does not need to be destabilized to recover old world content
- Rojo/source reconstruction can proceed group-by-group behind a hold

### Costs

- a dedicated overworld lifecycle/place boundary still has to be implemented
- cross-place/session persistence and party handoff must be designed deliberately
- the temporary Ranger Station hub remains necessary until that cutover
- full overworld reconstruction is larger than a simple geometry paste

## Guardrails

The source contract is:

`games/living-kingdoms/src/shared/Config/RecoveredWorldPlacementConfig.luau`

Until the dedicated overworld boundary is implemented and validated:

- `SourceHold = true`
- `RuntimeEnabled = false`
- no recovered authored-world renderer may start from the normal operation bootstrap
- no legacy HubTown/Dungeon/Quest/Gathering service becomes authoritative

## Next step

Reconstruct the authored overworld as source-managed **data/presentation groups** behind the hold, starting with high-value coherent groups rather than dumping all recovered Parts into runtime at once.

Recommended order:

1. HubTown static shell and dungeon-portal presentation
2. Resources presentation definitions
3. major authored landmark groups (Destiny Monolith, Crystal Tower, Grand Entrance, Ancient Bridge)
4. remaining WorldStructures / vegetation / atmosphere
5. dedicated overworld project/lifecycle boundary
6. canonical interactions and expedition handoff
