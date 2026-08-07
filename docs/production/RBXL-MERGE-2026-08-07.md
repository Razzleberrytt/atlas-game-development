# Living Kingdoms RBXL Merge Ledger — 2026-08-07

## Objective

Combine the supplied Studio game with the current Atlas/Living Kingdoms source tree while maximizing preservation and preventing duplicate runtime authority.

## Completed source-preservation pass

- [x] Fingerprinted supplied `.rbxl`: `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`
- [x] Inventoried 2,258 instances and 290 scripts/modules.
- [x] Identified 1,775 Workspace instances and preserved their hierarchy.
- [x] Separated current-repo overlaps from Studio-only code.
- [x] Preserved 28 unique Studio-only source files inside an inert, lossless import bundle that restores the original hierarchy.
- [x] Froze the pre-merge repository on `archive/pre-rbxl-merge-2026-08-07`.
- [x] Kept current server-authoritative systems as canonical owners.
- [x] Recorded legacy services that must not boot unchanged.

## Major Studio-only feature families retained

| Family | Preserved material | Merge disposition |
|---|---|---|
| Hub/meta | `HubTown`, vendors, quest board, portal; `HubTownService` | Adapt to current preparation/loadout/value systems |
| Procedural dungeon | legacy `DungeonService`, definitions and modifiers | Mine ideas/content; canonical `Expedition*` runtime owns execution |
| Quests | `QuestService` templates/modifiers | Port into current mission/progression authority |
| Gathering/crafting | resource nodes, Hatchet, gathering/crafting service | Preserve; activate only behind canonical inventory/persistence |
| RPG economy | item/affix/loot/RNG definitions and engines | Reconcile data models; current loot/reward/persistence remains authority |
| UI | RPG HUD, shop UI, survival HUD, RPG client | Presentation reference; avoid duplicate current HUD owners |
| Monetization | old product/shop hooks | Reference only; placeholder IDs and legacy value mutations stay disabled |
| Authored world | 1,775 Workspace objects | Treat as valuable source content; reconstruct/test before active mapping |

## Runtime-danger list

Do not map or require these directly from the active project until rewritten against canonical contracts:

- `RPGServerBootstrap`
- `Services/CombatService`
- `Services/EnemyService`
- `Services/InventoryService`
- `Services/LootService`
- `Services/PlayerDataService`
- `MonetizationService`

## Next merge tickets

- [ ] **M-01 World property reconstruction:** produce a source-managed representation of the authored HubTown/world with geometry, materials, lighting/VFX, prompts and NPC presentation preserved.
- [ ] **M-02 Spatial integration:** choose whether the hub is a separate place/zone or a non-combat region; prevent overlap with `WorldFoundationService` operation geometry.
- [ ] **M-03 Hub contract:** connect preparation, weapon selection, expedition launch/return and vendor interaction to canonical services.
- [ ] **M-04 Dungeon reconciliation:** map old dungeon modifiers/room concepts to current expedition contracts, rewards, boss and enemy director.
- [ ] **M-05 Quest reconciliation:** port useful quest templates/modifiers with canonical server rewards and persistence.
- [ ] **M-06 Gathering feasibility gate:** decide whether gathering/crafting improves the action-RPG loop enough to enter active scope; if yes, implement on canonical inventory/value mutations.
- [ ] **M-07 UI harvest:** selectively move useful layout/feedback patterns into current centralized HUD/menu owners.
- [ ] **M-08 Studio evidence:** build/sync the merged source and capture E2/E3 evidence before declaring the merged game runtime-complete.

## Promotion rule

The import package is intentionally inert. Completing this ledger's preservation pass means **nothing was casually overwritten**; it does not mean all Studio-only systems are production-ready. Active promotion happens subsystem-by-subsystem with one owner and accepted evidence.
