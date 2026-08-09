# BA-052 — First Outdoor Discovery

**Status:** IMPLEMENTED / AUTOMATED-VERIFICATION PENDING  
**Runtime activation:** Yes — `ApproachLookoutCacheOnly`  
**Primary source:** `games/living-kingdoms/src/shared/Config/FirstOutdoorDiscoveryConfig.luau`  
**Runtime owner:** `games/living-kingdoms/src/server/Systems/OutdoorDiscoveryService.luau`

## First discovery: Lookout Cache

BA-052 fills the optional discovery slot reserved by BA-050 at the Forest Service Lookout.

Stable identities:

- discovery: `discovery.first-descent.lookout-cache`
- route slot: `discovery-slot.outdoor.first-descent.lookout-tower`
- landmark anchor: `landmark.lookout_tower`
- source-managed runtime landmark: `LookoutTower`
- streaming identity: `streaming.discovery.first-descent.lookout-cache`
- reward source: `reward-source.authored-container`

Gameplay meaning is **OptionalVantageCache**: a small detour that rewards curiosity without becoming mandatory progression.

Presentation intent is **ReadableOptionalDetour**. The live cache is placed from the source-managed `WorldFoundationConfig` Lookout landmark, not from a raw Workspace path or the held imported BA-050 route geometry.

## Live behavior

The server creates one Lookout Cache with a `ProximityPrompt`. A trigger is only accepted when:

- the triggering player still has a character root within the configured server-side interaction distance;
- an expedition is active;
- the expedition is still `InProgress`;
- the current phase is `Approach`;
- the observed run ID still matches at commit time; and
- the expedition's existing `SecretDiscovered` state has not already been committed.

The live expedition composition root commits the existing `ExpeditionRuntime.markSecretDiscovered()` state. No parallel discovery state machine is introduced. A successful claim then reuses `RunBuildService.offerRelicRewardToParticipants(...)` with `reward-source.authored-container`, so the optional co-op detour produces the existing bounded relic-choice reward for current participants.

The claim is globally one-time per expedition run. A fresh deliberate replay receives a fresh expedition runtime/run ID and therefore a fresh unclaimed discovery without requiring account persistence.

## Ownership boundaries

BA-052 does not:

- activate BA-050 imported route geometry (`FirstOutdoorRouteConfig.RuntimeConsumptionActive` remains false);
- own expedition phase advancement;
- create a second discovery/progression runtime;
- create account persistence;
- create a client-authoritative mutation path;
- create a new reward economy or relic-selection owner; or
- create a new remote surface.

`OutdoorDiscoveryService` owns only the source-managed cache part, prompt lifecycle, server-side proximity validation, and handoff to the existing expedition/reward authorities.

## Automated validation

`games/living-kingdoms/tests/FirstOutdoorDiscoveryConfig.test.luau` verifies the active bounded config, canonical IDs, held BA-050 route state, reward source, and interaction limits.

`games/living-kingdoms/tests/OutdoorDiscoveryRuntimeSourceAudit.test.luau` verifies the Approach-only authoritative secret claim seam, server-side proximity validation, canonical squad reward fan-out, mounted runtime, absence of a parallel remote/DataStore path, and continued BA-050 route hold.

Repository Luau validation remains the merge gate. Studio/manual verification remains deferred to consolidated MVP acceptance; it is not a hard implementation gate.
