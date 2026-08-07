# Decision: merge Studio Living Kingdoms into Atlas without dual authority

**Date:** 2026-08-07  
**Status:** Accepted for source preservation / E1 reconciliation  
**Source place SHA-256:** `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`

## Context

The supplied `livingkingdoms.rbxl` contains two kinds of material:

1. a large set of scripts that substantially mirrors the current Rojo repository; and
2. unique older RPG/open-world content, including an authored hub/world, dungeon/gathering/quest/shop systems, legacy data/combat services, and related configuration.

Blindly replacing the repository with the place would regress tested server authority and reintroduce duplicate managers. Ignoring the place would lose useful authored content and design work.

## Decision

Adopt a **canonical-runtime + preserved-import** merge.

- The current repository remains canonical for combat, health/life state, enemy authority, inventory, persistence, rewards, expedition runtime, networking, and presentation ownership.
- Unique Studio-only code is preserved as chunked `legacy-src.tar.gz.b64.part*` files with a deterministic restore helper and is deliberately outside the active Rojo mapping.
- The complete Workspace identity/hierarchy is preserved in the import package as a migration input.
- No legacy bootstrap or overlapping server authority is enabled merely because it existed in the place.
- Useful legacy features are ported **into** current services/contracts rather than booted beside them.

## Reconciliation priority

1. **Hub / preparation layer:** preserve the authored HubTown and connect it to the current expedition preparation/loadout flow.
2. **World content:** reconstruct/promote the authored landmarks, resource areas, portal, ruins, lighting and environmental content into source-managed world assets without overlapping the current operation geometry.
3. **Dungeon ideas:** adapt old room/modifier/encounter ideas to the canonical `ExpeditionRuntime`, `RoomSequenceAssembler`, `ExpeditionRoomPlacementService`, boss, loot and reward systems.
4. **Quest ideas:** port useful templates/modifiers to the current mission/progression authority; do not use the legacy reward mutation path.
5. **Gathering/crafting:** preserve as optional future scope; when activated, resources/items must mutate through canonical inventory/persistence and server-authoritative interaction validation.
6. **Vendor/economy:** adapt rotating vendor/daily-deal concepts only after the durable value model is accepted.
7. **Monetization/UI:** retain presentation/design references; do not ship placeholder product IDs or monetization that bypasses canonical value mutation.

## Explicitly superseded runtime owners

The preserved legacy versions of `RPGServerBootstrap`, `CombatService`, `EnemyService`, `InventoryService`, `LootService`, and `PlayerDataService` are **not production owners**. They are reference implementations only.

## Evidence boundary

This decision is a source-level merge and preservation action. It does **not** promote the game above E1 and does not claim the supplied Studio place or merged runtime has passed E2+ startup/integration evidence.

## Rollback

The pre-import repo is frozen at `archive/pre-rbxl-merge-2026-08-07` (commit `852de4953155379a4cc4733fe8dd05cd6f51477e`).
