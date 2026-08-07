# Readable Studio Reference Layer

These files make the highest-value Studio-only systems easy for humans and coding agents to inspect while the game is being reconciled.

## Important: this directory is not production source

- Nothing here is mapped by `default.project.json`.
- Nothing here should be booted or required directly by the live game.
- These copies are convenience/reference material and may be normalized for readability.
- The exact preserved Studio source-of-truth is the checksum-verified archive one directory up: `legacy-src.tar.gz.b64.part*`, restored with `../restore-import.py` and validated by `../VALIDATION.md`.
- Current `src/` services remain authoritative wherever responsibilities overlap.

## High-value references exposed directly

- `ServerScriptService/Services/HubTownService.luau` — rotating vendors, daily deals, rarity upgrades and hub interaction ideas.
- `ServerScriptService/Services/QuestService.luau` — procedural short-session quests, modifiers and progression hooks.
- `ServerScriptService/Services/DungeonService.luau` — procedural room/corridor, secret-room, modifier and encounter ideas to adapt into the current `Expedition*` stack.
- `GATHERING-CRAFTING-CONCEPTS.md` — extracted design/mechanics from the legacy gathering/hatchet/crafting system, with its exact Luau source still preserved in the verified archive.

## Authority rule

Do not revive the legacy `RPGServerBootstrap`, combat, enemy, inventory, loot, player-data or monetization managers beside the current implementations. Port useful behavior into current contracts and services so there is exactly one authoritative path for combat, inventory, persistence, rewards and networking.

## Suggested integration order

1. Reconstruct and source-manage the authored HubTown/world presentation.
2. Connect hub preparation, loadout selection and expedition launch/return to the canonical runtime.
3. Adapt vendor/economy ideas behind canonical value mutations.
4. Port quest archetypes/modifiers to current mission/progression authority.
5. Fold useful dungeon ideas into `ExpeditionRuntime`, room placement/sequence, enemy director, boss and reward systems.
6. Gate gathering/crafting behind a gameplay-fit decision; if retained, use canonical inventory, persistence and server-authoritative interaction/combat validation.
