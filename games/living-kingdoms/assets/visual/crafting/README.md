# Crafting presentation source models

This pack provides project-original Roblox model JSON sources for the first crafting presentation set declared by `CraftingPresentationRegistry`.

## Included models

- `Stations/FieldBenchV1.model.json` — the hub field bench, mapped visually to canonical station ref `station.hub.crafting`.
- `Ingredients/ScrapBundleV1.model.json` — inert salvaged-metal ingredient display.
- `Ingredients/FabricRollV1.model.json` — inert field-fabric ingredient display.
- `Tools/HandToolsV1.model.json` — inert workbench hand-tool set.
- `Containers/PartsCrateV1.model.json` — inert parts-storage presentation prop.

## Authority boundary

These files are **presentation source only**. `CraftingPresentationRegistry.luau` owns their presentation IDs, logical model paths, variants, and socket definitions. `CraftingContracts.luau` owns crafting eligibility semantics and remains dormant.

The models do not consume ingredients, grant outputs, enable recipes, harvest resources, persist state, bind remotes, or contain interaction prompts. Every BasePart is anchored so importing the source cannot silently activate world physics or gameplay behavior.

The field bench preserves the registry sockets for left/right ingredient display, centered output display, primary tool rest, work VFX, and work audio. Hand tools and the parts crate preserve their snap sockets.

`asset-manifest.json` intentionally records `runtimeMapped`, `studioApproval`, and `gameplayAuthority` as false. A later Studio approval/import pass may promote these sources into runtime assets without transferring gameplay authority to the models.
