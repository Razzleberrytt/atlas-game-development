# Canonical Gathering / Resource-Node Contracts

**Roadmap ticket:** BA-023  
**Lane:** controlled build-ahead  
**Status:** contract/model complete; runtime dormant  
**Evidence level:** E1 source/static only

## Decision

Gathering uses one canonical, data-only resource-node shape before any live harvesting authority is introduced.

[`GatheringContracts.luau`](../../games/living-kingdoms/src/shared/Gathering/GatheringContracts.luau) defines stable node, resource, tool, respawn-policy and reward references plus pure validation and eligibility evaluation.

BA-023 deliberately does not harvest a node, mutate availability, schedule a respawn, grant a reward, write persistence, bind networking, create prompts/UI, or activate `hub.anchor.gathering`.

## Resource-node definition

A node definition contains:

- `NodeId` — stable node-definition identity;
- `Version` — contract/content version;
- `ResourceRefId` — opaque resource identity;
- optional `RequiredToolRefId` — opaque required-tool identity;
- `RespawnPolicyRefId` — opaque respawn/lifecycle policy identity;
- one or more `RewardRefs` with positive integer quantities;
- `RuntimeEnabled` — explicit activation hold.

All cross-domain references remain opaque in BA-023. BA-025 owns checks that referenced resource/tool/respawn/reward IDs actually exist and are mutually coherent.

## Eligibility

The pure resolver answers only whether an already-described node could be gathered under a supplied context. Denials are deterministic and ordered:

1. `RuntimeDisabled`
2. `NodeUnavailable`
3. `ToolRequired`

An eligible result grants nothing and changes nothing. It is not a harvest transaction.

## Respawn boundary

BA-023 records only `RespawnPolicyRefId`. It intentionally does not define or execute timers, cooldown jobs, world-instance replacement, streaming lifecycle, persistence, server clocks or anti-exploit state.

That separation prevents a source/static resource definition from accidentally becoming a second world-state authority.

## Reward boundary

`RewardRefId` is an opaque reference with a positive quantity. BA-023 does not decide whether the eventual reward resolves to inventory items, currencies, quest credit, progression, loot rolls or another domain.

Reward-reference existence and orphan detection belong to BA-025. Economy/value policy remains gated by BA-026.

## Hub / Main World boundary

The canonical hub registry reserves `hub.anchor.gathering`, but that seam has no presentation or mutation owner yet. BA-023 does not activate it or infer that an authored world object is gatherable merely because a resource-like model exists.

Future activation requires an explicit canonical server owner, accepted interaction/prompt policy, streaming/lifecycle behavior, idempotent reward handling, relevant economy decisions and Studio evidence.

## Validation

`GatheringContracts.test.luau` verifies:

- strict shape validation and unknown-field rejection;
- unique node IDs and reward refs;
- positive reward quantities;
- required resource/respawn references;
- optional tool requirements;
- deterministic disabled/unavailable/tool-required/eligible outcomes;
- source guardrails against Roblox instance creation, networking, persistence and timer execution.

## Completion boundary

BA-023 is complete at E1 when the contract, focused fixture and normal repository CI are green. It does not raise runtime evidence level or authorize live gathering behavior.
