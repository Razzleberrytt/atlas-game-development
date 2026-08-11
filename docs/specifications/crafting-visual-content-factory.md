# Living Kingdoms — Crafting Visual Content Factory

**Status:** SOURCE-PREPARED PRESENTATION BOUNDARY

Crafting needs enough visual breadth that ingredients, tools, containers, workstations, and finished-result displays feel like part of the world rather than menu-only abstractions. This factory prepares that art pipeline without creating crafting or inventory authority.

## Canonical binding rule

A presentation may bind `canonicalRefId` only when the referenced production ID already exists. The first real binding is the reserved Main World crafting surface `station.hub.crafting` from `HubInteractionConfig`.

Ingredient/output IDs remain opaque under BA-022 and no production recipe set currently promotes specific item IDs. Therefore starter scrap/fabric/tool/container visuals remain **unbound visual families** rather than inventing canonical inventory items. When real recipes/resources are authored, they can bind these or later families through a reviewed registry update.

## Presentation families

The initial factory prepares:

- Field Bench workstation;
- salvaged-metal bundle ingredient family;
- field-fabric roll ingredient family;
- hand-tool family;
- parts-crate/container family.

Every definition carries a model family/path, lifecycle status, scale class, material identity, cosmetic variants, and optional sockets for ingredient/output display, tool rests, snapping, VFX, and audio.

Starter cosmetic directions are Frontier Worn, Mine Grimed, and Corruption Touched. These may change physical wear/material presentation only.

## Authority boundary

Crafting visuals do not:

- evaluate recipes;
- consume ingredients;
- grant outputs;
- alter output quantities;
- own inventory or persistence;
- create networking/remotes;
- activate the held Main World crafting surface.

`CraftingContracts` remains the eligibility contract and later canonical server ownership must remain separate. Presentation variants are prohibited from carrying gameplay modifiers.

## Scaling rule

The long-term target is that adding a new material, tool family, workstation, container, or recipe-result display is primarily model + registry work. Damaged, rare, biome, faction, and corruption variants should reuse family conventions where practical instead of multiplying one-off runtime scripts.
