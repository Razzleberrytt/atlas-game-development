# Crafting Recipe Contracts

**Roadmap ticket:** BA-022  
**Lane:** controlled build-ahead  
**Status:** contract/resolver prepared; runtime consumption held  
**Evidence level:** E1 source/static only

## Decision

Crafting is represented by stable recipe definitions plus a deterministic eligibility resolver. BA-022 defines the shape of a recipe and the reasons a single craft attempt is not eligible; it does not create a live crafting authority or an item mutation path.

The machine-readable contract is [`CraftingContracts.luau`](../../games/living-kingdoms/src/shared/Crafting/CraftingContracts.luau).

## Recipe shape

A recipe contains:

- stable `RecipeId` and `Version`;
- one or more ingredient references, each with an opaque `ItemRefId` and positive integer quantity;
- one or more output references, each with an opaque `ItemRefId` and positive integer quantity;
- optional `RequiredStationRefId`;
- optional `RequiredUnlockId`;
- `RuntimeEnabled`, which remains false for any held authored content until later activation work explicitly promotes it.

Ingredient, output, station, and unlock IDs are references only. BA-022 does not decide whether those IDs exist in another domain. BA-025 owns cross-domain dependency validation.

## Deterministic eligibility order

`evaluateEligibility` checks one proposed craft in this fixed order:

1. runtime enabled;
2. required station match;
3. required unlock present;
4. ingredient availability in recipe order;
5. eligible.

The first failing check is returned. For a missing ingredient, the result includes its item reference, required quantity, and normalized available quantity. Invalid or negative quantity data is treated as zero for eligibility rather than becoming mutation authority.

Denial reasons are:

- `RuntimeDisabled`
- `StationRequired`
- `UnlockRequired`
- `MissingIngredient`

## Authority boundary

BA-022 does **not**:

- remove ingredients;
- grant outputs;
- write persistence;
- create a crafting server owner;
- create prompts, UI, or world interaction placement;
- bind remotes or networking;
- validate referenced item/station/unlock IDs against other domains;
- define prices, salvage values, or economy bands;
- activate the reserved Main World crafting anchor.

A future canonical server owner may consume these definitions only after the relevant roadmap/runtime gates explicitly authorize integration. The client may eventually display eligibility information, but it may never convert this pure resolver into authoritative item mutation.

## Validation rules

Definitions reject:

- empty or overlong IDs;
- unknown fields;
- non-array ingredient/output collections;
- empty ingredient/output collections;
- duplicate ingredient IDs within one recipe;
- duplicate output IDs within one recipe;
- non-positive or non-integer quantities;
- duplicate recipe IDs within a definition set;
- malformed optional station/unlock references.

The focused fixture also proves the module contains no Roblox instance creation, service access, networking primitives, or persistence access.

## Relationship to adjacent work

- **BA-012** reserves the Main World crafting interaction seam but does not activate it.
- **BA-021** may refer an NPC capability toward a crafting domain surface but cannot mutate crafting state.
- **BA-023** will define gathering/resource-node references separately.
- **BA-024** will define vendor/catalog/pricing contracts separately.
- **BA-025** will validate cross-domain IDs and orphan/cycle/impossible-reference problems after BA-020 through BA-024 exist.
- **BA-026** remains the economy/value audit gate and is not bypassed by recipe quantities.

## Completion boundary

BA-022 is complete at E1 when the contract/resolver, focused fixture, formatting, lint, full applicable Lune suite, and Rojo build are green.

This completion does not prove Studio behavior and does not authorize crafting activation.
