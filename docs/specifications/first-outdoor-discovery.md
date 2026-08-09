# BA-052 — First Outdoor Discovery

**Status:** DATA-ONLY / DORMANT  
**Runtime activation:** No  
**Primary source:** `games/living-kingdoms/src/shared/Config/FirstOutdoorDiscoveryConfig.luau`

## First discovery: Lookout Cache

BA-052 fills the optional discovery slot reserved by BA-050 at the Forest Service Lookout.

Stable identities:

- discovery: `discovery.first-descent.lookout-cache`
- route slot: `discovery-slot.outdoor.first-descent.lookout-tower`
- landmark anchor: `landmark.lookout_tower`
- streaming identity: `streaming.discovery.first-descent.lookout-cache`
- reward reference: `reward-source.authored-container`

Gameplay meaning is **OptionalVantageCache**: a small detour that rewards curiosity and gives the player a useful vantage/lore moment without becoming mandatory progression.

Presentation intent is **ReadableOptionalDetour**: the discovery should be noticeable from normal route traversal but clearly optional, with no required hidden-pixel search or raw Instance-path dependency.

## Ownership boundaries

BA-052 does not:

- activate the BA-050 route;
- create or move Workspace geometry;
- own streaming logic;
- open/grant a container reward;
- write persistence/account progression;
- fire remotes;
- define client presentation behavior;
- create a second discovery/progression runtime.

`reward-source.authored-container` is an existing Run RPG reward-source vocabulary entry. Its current implementation state remains planned; BA-052 only references it so later integration has a canonical reward seam.

The stable streaming identity is deliberately separate from the landmark content ID. Runtime integration may use the landmark as a streaming anchor while retaining discovery identity across unload/reload, but this task does not implement that behavior.

## Validation

`games/living-kingdoms/tests/FirstOutdoorDiscoveryConfig.test.luau` verifies:

- exactly one discovery is authored for the first route;
- it binds to the BA-050 Lookout Tower discovery slot;
- the anchor is the canonical Lookout Tower landmark;
- the streaming identity is stable and separate from the landmark ID;
- the discovery remains optional;
- the reward reference is `RunRpgContracts.RewardSourceIds.AuthoredContainer`;
- the source contains no raw `Workspace/` path, DataStore ownership, or remote firing.

Studio/manual verification is deferred under the MVP build-through policy because BA-052 is dormant data. Visual discoverability, streaming behavior, interaction feel, and reward presentation belong to later runtime integration / consolidated MVP Studio acceptance.
