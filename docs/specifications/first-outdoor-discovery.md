# BA-052 — First Outdoor Discovery

**Status:** RUNTIME-LIVE / SOURCE-VERIFIED  
**Runtime activation:** Yes — Lookout Cache interaction only  
**Primary source:** `games/living-kingdoms/src/shared/Config/FirstOutdoorDiscoveryConfig.luau`  
**Runtime owner:** `games/living-kingdoms/src/server/Systems/FirstOutdoorDiscoveryService.luau`

## First discovery: Lookout Cache

BA-052 fills the optional discovery slot reserved by BA-050 at the Forest Service Lookout.

Stable identities:

- discovery: `discovery.first-descent.lookout-cache`
- route slot: `discovery-slot.outdoor.first-descent.lookout-tower`
- landmark anchor: `landmark.lookout_tower`
- generated landmark identity: `LookoutTower`
- streaming identity: `streaming.discovery.first-descent.lookout-cache`
- reward source: `reward-source.authored-container`

Gameplay meaning is **OptionalVantageCache**: a small detour that rewards curiosity and gives the player a useful vantage/lore moment without becoming mandatory progression.

Presentation intent is **ReadableOptionalDetour**: the discovery is mounted visibly inside the source-generated collapsed Lookout ruin. It uses a proximity prompt with a short hold and does not require hidden-pixel searching or a client-authored reward request.

## Runtime integration

The generated `WorldFoundationService` world already supplies a deterministic Forest Service Lookout and `RuinedFloor` anchor. BA-052 consumes that active source-managed landmark; it does **not** activate the held imported BA-050 `WorldPath` geometry.

`FirstOutdoorDiscoveryService`:

- finds the canonical generated `LookoutTower` model and validates its `LandmarkId`;
- mounts one `LookoutDiscoveryCache` on the existing `RuinedFloor`;
- receives only the triggering `Player` from `ProximityPrompt`;
- re-derives the player's `HumanoidRootPart` position on the server and enforces the configured 10-stud maximum distance;
- requires combat eligibility and a live expedition still in `Approach`;
- asks `ExpeditionLiveRuntimeService` to commit the existing per-run `SecretDiscovered` fact using both expected `RunId` and expected phase guards;
- only after that commit succeeds, fans the reward out through `RunBuildService.offerRelicRewardToParticipants` using `reward-source.authored-container`;
- creates no reward remote, persistence layer, route owner, or parallel discovery state machine.

The existing `ExpeditionRuntime.SecretDiscovered` fact is the duplicate gate. A second trigger in the same run cannot commit and therefore cannot grant again. A deliberate replay creates a fresh expedition runtime/RunId, which naturally restores discovery eligibility without a separate replay-reset owner.

## Ownership boundaries

BA-052 still does not:

- activate the BA-050 imported route;
- move or reinterpret recovered Studio route geometry;
- own streaming logic;
- write persistence/account progression;
- create client-to-server reward networking;
- bypass `RunBuildService` reward validation;
- define a second expedition/discovery lifecycle.

The source-generated lookout presentation remains owned by `WorldFoundationService`. BA-052 adds only its own cache part and interaction under that landmark.

## Validation

Automated validation covers:

- exactly one discovery authored for the first route;
- binding to the BA-050 Lookout Tower discovery slot;
- active canonical Lookout landmark anchoring;
- stable discovery/streaming identities;
- optional status;
- configured interaction bounds;
- canonical `RunRpgContracts.RewardSourceIds.AuthoredContainer` reward source;
- server-side position and Approach-phase checks;
- stale `RunId` / stale phase guards before the existing expedition secret mutation;
- canonical RunBuild reward fan-out after the secret commit;
- absence of new remote or DataStore ownership.

Studio/manual verification remains part of consolidated MVP acceptance for visual discoverability, prompt feel, and the practical detour/readability experience. It is not a hard gate for source implementation/merge under the build-through policy.
