# Decision — Preserve and Reconcile the 2026-08-07 Studio Place

**Status:** Accepted for reconciliation  
**Date:** 2026-08-07  
**Source place SHA-256:** `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`

## Context

The supplied `livingkingdoms.rbxl` contains both a substantial subset of the current repo runtime and an older/open-world RPG layer that is not represented one-for-one in the active source tree. Blindly replacing either side would lose useful work or reintroduce duplicate runtime authority.

The Studio place also contains authored Workspace content: a hub town, resource areas, ruins/landmarks, dungeon portal, world structures, lighting/effects, and other environmental work. The current repo independently contains a deterministic operation world, newer expedition systems, server-authoritative combat/life/enemy/inventory/persistence, and a large tested source surface.

## Decision

Use a **best-of-both reconciliation**, with the current repo remaining authoritative for overlapping runtime responsibilities and the Studio place preserved as an inert import source for unique features and world content.

### Current repo remains authoritative for

- combat and hit/damage authority;
- operative health/life/revive state;
- enemy lifecycle and encounter ownership;
- inventory, loot mutation, and persistence;
- expedition lifecycle, rooms, results, and rewards;
- replication/network boundaries;
- centralized presentation ownership;
- current production/evidence rules.

### Preserve/adapt from the Studio place

- HubTown authored content and hub/meta-game concepts;
- vendor/daily-deal/rarity-upgrade ideas;
- quest generation/modifiers;
- gathering/hatchet/crafting concepts, feature-gated until scoped;
- dungeon encounter/modifier ideas that can enrich the newer expedition assembly;
- useful RPG/shop UI concepts without duplicating current presentation owners;
- authored world landmarks, structures, resource zones, portal, ambience, and environmental composition.

## Safety rule

Legacy source is stored under `games/living-kingdoms/imports/studio-2026-08-07/`, which is **not** mapped by the live Rojo project. It is reference/recovery material until a focused integration ports a capability into canonical `src/` with current authority and tests.

Never activate the old `RPGServerBootstrap`, `CombatService`, `EnemyService`, `InventoryService`, `LootService`, `PlayerDataService`, or `MonetizationService` wholesale. They overlap current authority and some reference dependencies absent from the supplied place.

## Loss policy

No unique old-RPG source is intentionally discarded during this reconciliation. Every unique source file is preserved in the import archive. Every Workspace instance identity/path is recorded in the world index. The exact incoming binary is fingerprinted so future recovery can verify provenance.

## Rollback

The pre-import repository is permanently checkpointed at branch:

`archive/pre-rbxl-merge-2026-08-07`

The preservation import is additive and inert; removing it from an active build does not require deleting historical source.

## Integration priority

1. Preserve/fingerprint incoming material.
2. Keep current runtime authority unchanged.
3. Reconcile hub/preparation concepts with the current expedition lobby/preparation flow.
4. Reconcile quest/dungeon ideas into data-driven canonical systems.
5. Reconstruct/promote selected authored world content into source-managed assets with tests/evidence.
6. Only then consider gathering/crafting/monetization activation, based on product-scope evidence.
