# Cross-Domain Dependency Validation

**Roadmap ticket:** BA-025  
**Lane:** controlled build-ahead  
**Status:** source/static validator complete; runtime consumption disabled  
**Evidence level:** E1 source/static only

## Decision

BA-025 adds one pure validator for relationships between the already-defined BA-020 through BA-024 domain contracts. It is not a new gameplay owner and it does not replace any domain's local shape validation.

The machine-readable validator is [`CrossDomainDependencyValidator.luau`](../../games/living-kingdoms/src/shared/Validation/CrossDomainDependencyValidator.luau).

## Preconditions

Callers must first pass definitions through the owning domain validators:

- BA-020 `QuestContracts.validateQuestDefinition`;
- BA-021 `NPCContracts.validateNPCDefinition`;
- BA-022 `CraftingContracts.validateRecipeDefinition`;
- BA-023 `GatheringContracts.validateNodeDefinition`;
- BA-024 vendor/catalog definition validators.

BA-025 then checks only cross-definition and cross-registry relationships. Keeping these responsibilities separate prevents a second quest, NPC, crafting, gathering, vendor, reward, inventory or economy authority from emerging inside validation code.

## Reference registry

The validator receives explicit known-ID lists rather than reaching into runtime services or DataStores. The registry covers:

- quest objective progress-source refs;
- reward refs and reward authority-owner refs;
- NPC capability target refs;
- item refs;
- crafting station refs;
- unlock refs;
- gathering resource refs;
- tool refs;
- respawn-policy refs;
- currency refs.

These are validation registries, not runtime ownership declarations. BA-025 does not create content, balances, rewards, items, currencies, stations, unlocks, respawn policies or world instances.

## Checks

### Quest graph

The validator reports:

- unknown prerequisite quest IDs;
- prerequisite cycles, with every quest participating in a detected cycle reported;
- an impossible enabled quest dependency when an enabled quest requires a known prerequisite whose runtime flag is disabled;
- unknown objective progress-source refs;
- unknown reward refs;
- unknown reward authority-owner refs.

The cycle detector ignores already-reported unknown prerequisite IDs so one missing ref cannot create a false graph cycle.

### NPC references

Every capability `TargetRefId` must exist in the supplied NPC-target registry. This catches stale referrals without deciding what the target does or who owns its mutations.

### Crafting references

Every ingredient and output item ref must exist. Optional station and unlock refs must also exist when present. No item quantities are consumed or produced by BA-025.

### Gathering references

Resource, optional required-tool, respawn-policy and reward refs must exist. BA-025 does not harvest/deplete nodes, schedule respawns or grant rewards.

### Vendor references

Every vendor catalog ref must resolve to a supplied catalog. An enabled vendor may not depend on a known disabled catalog. Catalog entry item refs and currency refs must exist.

BA-025 does not define prices, currencies, stock, purchases, refunds, item grants or transaction idempotency. Those remain outside this validator and the economy lane remains gated separately.

## Determinism

Validation issues are sorted by domain, definition ID, issue code and reference ID. The same graph produces the same ordered issue list regardless of table iteration order used by cycle discovery.

## Authority boundary

BA-025 adds no:

- bootstrap or runtime consumer;
- RemoteEvent or RemoteFunction;
- client authority;
- inventory/currency mutation;
- reward grant;
- quest transition;
- crafting execution;
- gathering lifecycle or timer;
- vendor transaction;
- persistence read/write;
- Main World prompt/UI activation.

`RuntimeConsumptionActive = false` and `MutationIntentAllowed = false` are asserted in source.

## Completion boundary

BA-025 is complete at E1 when the focused fixture and the repository's full applicable CI are green. Source/static success proves deterministic graph validation only; it does not advance Studio/runtime evidence and does not activate BA-020 through BA-024 content.

With BA-020 through BA-025 complete, the P2 domain-contract foundation is prepared. BA-026 remains separately gated by the Master ECON decision and must not be inferred as unblocked merely because these source contracts exist.
