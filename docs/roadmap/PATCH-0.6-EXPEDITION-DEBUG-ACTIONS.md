# Patch 0.6 Expedition Debug Actions

The live expedition diagnostic surface is mounted as `ServerStorage.ExpeditionControl` for trusted Studio and server workflows.

## Actions

| Action | Payload | Return |
|---|---|---|
| `Start` | `{ Seed?, PartySize?, RunId? }` | start result and authoritative snapshot |
| `Stop` | optional reason string | stop result and final snapshot |
| `ReadSnapshot` | none | current expedition snapshot |
| `ReadRoomPlan` | none | active deterministic room plan |
| `ReadRunVariationPlan` | none | active variation plan |
| `ReadRunVariationEncounterView` | none | active encounter-view plan |
| `ReadRunVariationComposition` | `{ ExpectedRunId = runId }` | guarded live composition diagnostics |
| `ReadLastStartFailure` | none | most recent rejected-start reason and inputs |

## Fast Studio workflow

```lua
local control = game:GetService("ServerStorage"):WaitForChild("ExpeditionControl")
local started = control:Invoke("Start", { Seed = 321 })
local runId = started.Snapshot.RunId
local debug = control:Invoke("ReadRunVariationComposition", { ExpectedRunId = runId })
print(debug.CurrentEncounterPhaseId, debug.CurrentRoomId, debug.ActiveWaveIndex)
print(debug.RemainingAuthoredWaves, debug.EncounteredRoomCount, debug.CompletedRoomCount)
print(debug.CompositionDurationMs, debug.ActiveCompositionIdentity)
```

`CompositionDurationMs` is populated only in Studio/development mode. `CurrentEncounterPhaseId` and `CurrentRoomId` are live runtime fields. `ActiveWaveIndex`, `AuthoredWaveCount`, and `RemainingAuthoredWaves` project the active authored combat sequence. `EncounteredRoomCount`, `CompletedRoomCount`, and `TotalRoomCount` summarize dungeon progress.

Composition reads are bound to the expected active run ID and capped at 20 accepted reads per second. Guard failures are explicit: `ServiceStopped`, `NoActiveExpedition`, `ExpectedRunIdRequired`, `StaleRun`, or `DiagnosticRateLimited`.

The composition payload also carries the replay seed, room-plan identity, modifier ID, secret/optional-objective presence, and the deterministic composition record set. Use `Composition.SeedCommand` to reproduce a run quickly. Curated replay fixtures are available in `RunVariationReplayFixtures` for dense contacts, quiet approach, and no-variation baseline runs.

## Operating rule

Treat these actions as diagnostics, not gameplay APIs. Gameplay progression, combat, rewards, and run ownership continue through the existing authoritative services. If an action is not listed above, the mount returns `UnknownAction`.
