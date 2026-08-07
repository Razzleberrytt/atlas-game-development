# Legacy Script Disposition Matrix — BA-003

**Task:** BA-003 (build-ahead lane, P0 combined-game migration truth)
**Machine-readable source of truth:** [`legacy-script-disposition-matrix.json`](legacy-script-disposition-matrix.json)
**Evidence level:** source-proven only. No Studio or runtime evidence is claimed.
**Runtime posture:** inert. Nothing here is booted, required, or mapped.

## Scope

The preserved place held 290 scripts. 262 were already represented by canonical
repository source and the import recorded them as "canonical repo wins"; they
are not Studio-only and are out of scope. The 28 `unique_files` entries in the
import manifest are the complete Studio-only set, and every one of them is
classified below exactly once. CI enforces that completeness.

17 were classified from recovered byte-exact source. 11 were classified from
import-manifest identity plus, where one exists, a normalized reference copy —
their source was lost with the damaged preservation archive, recorded in
[`../production/RBXL-IMPORT-INTEGRITY-2026-08-07.md`](../production/RBXL-IMPORT-INTEGRITY-2026-08-07.md).

## Classifications

| Value | Meaning | Count |
|---|---|---|
| `CANONICAL_REPLACEMENT` | A canonical system already owns this responsibility; the module is superseded outright. | 6 |
| `REUSABLE_LOGIC_CANDIDATE` | Behaviour or tuning worth porting into a canonical owner, once made deterministic, bounded and server-authoritative. | 8 |
| `CONTENT_ONLY_REFERENCE` | Data, not behaviour. Design input only. | 7 |
| `DEAD_OR_STALE` | Not worth carrying forward. | 2 |
| `REQUIRES_MANUAL_STUDIO_INSPECTION` | Cannot be classified from the repository; source lost and no reference copy survives. | 5 |

## Matrix

| Script | Classification | Disposition | Source | Canonical owner / next task |
|---|---|---|---|---|
| `ReplicatedStorage/Shared/Config/AffixDefinitions.luau` | Content Only Reference | MIGRATE | recovered | `EliteAffixResolver.luau`; `EquipmentRewardConfig.luau` |
| `ReplicatedStorage/Shared/Config/DungeonDefinitions.luau` | Content Only Reference | REPLACE | recovered | `RoomAssemblyConfig.luau`; `RoomAssemblyContracts.luau`; `RoomSequenceAssembler.luau` |
| `ReplicatedStorage/Shared/Config/EnemyDefinitions.luau` | Content Only Reference | REPLACE | recovered | `EnemyConfig.luau`; `EnemyContracts.luau`; `EnemyDirectorService.luau` |
| `ReplicatedStorage/Shared/Config/ItemDefinitions.luau` | Content Only Reference | REPLACE | recovered | `EquipmentRewardContracts.luau`; `EquipmentRewardConfig.luau`; `PlayerInventoryContracts.luau` |
| `ReplicatedStorage/Shared/Config/LootTables.luau` | Content Only Reference | REPLACE | recovered | `LootDropConfig.luau`; `EnemyLootConfig.luau`; `LootDropContracts.luau`; `EnemyLootResolver.luau` |
| `ReplicatedStorage/Shared/Config/RNGConfig.luau` | Reusable Logic Candidate | MIGRATE | recovered | BA-043 |
| `ReplicatedStorage/Shared/Types/CombatTypes.luau` | Content Only Reference | REPLACE | recovered | `CombatContracts.luau`; `EnemyContracts.luau` |
| `ReplicatedStorage/Shared/Types/ItemTypes.luau` | Content Only Reference | REPLACE | recovered | `EquipmentRewardContracts.luau`; `PlayerInventoryContracts.luau` |
| `ReplicatedStorage/Shared/Types/PlayerDataTypes.luau` | Reusable Logic Candidate | REPLACE | recovered | `RunProgressionResolver.luau`; `RunProgressionConfig.luau`; `HordeExperienceConfig.luau`; `PlayerInventoryContracts.luau` |
| `ReplicatedStorage/Shared/Utility/NumberUtility.luau` | Dead Or Stale | ARCHIVE | recovered | none intended |
| `ReplicatedStorage/Shared/Utility/RNGEngine.luau` | Reusable Logic Candidate | MIGRATE | recovered | BA-043 |
| `ReplicatedStorage/Shared/Utility/RandomUtility.luau` | Reusable Logic Candidate | MIGRATE | recovered | BA-043 |
| `ServerScriptService/MonetizationService.server.luau` | Dead Or Stale | ARCHIVE | recovered | none intended |
| `ServerScriptService/RPGServerBootstrap.server.luau` | Canonical Replacement | ARCHIVE | recovered | `init.server.luau`; `ExpeditionServerBootstrap.luau`; `ExpeditionFoundationBootstrap.server.luau` |
| `ServerScriptService/Services/CombatService.luau` | Canonical Replacement | ARCHIVE | recovered | `DamageResolver.luau`; `OperativeCombatRuntimeService.luau`; `FirearmHitResolver.luau`; `CombatContracts.luau` |
| `ServerScriptService/Services/DungeonService.luau` | Reusable Logic Candidate | ARCHIVE | recovered | `RoomSequenceAssembler.luau`; `RoomPlacementPlanner.luau`; `SecretBranchResolver.luau`; `ExpeditionRoomPlacementService.luau` |
| `ServerScriptService/Services/EnemyService.luau` | Canonical Replacement | ARCHIVE | recovered | `EnemyDirectorService.luau`; `EnemyBehaviorResolver.luau`; `EnemyPresentationService.luau`; `EnemyContracts.luau` |
| `ServerScriptService/Services/HubTownService.luau` | Reusable Logic Candidate | ARCHIVE | **lost** | `InventoryLiveService.luau`; `PlayerInventoryContracts.luau` |
| `ServerScriptService/Services/InventoryService.luau` | Canonical Replacement | ARCHIVE | **lost** | `InventoryLiveService.luau`; `InventorySessionLeaseService.luau`; `PlayerInventoryContracts.luau` |
| `ServerScriptService/Services/LootService.luau` | Canonical Replacement | ARCHIVE | **lost** | `LootDropResolver.luau`; `EnemyLootService.luau`; `SurvivalLootService.luau`; `LootDropContracts.luau` |
| `ServerScriptService/Services/PlayerDataService.luau` | Canonical Replacement | ARCHIVE | **lost** | `PlayerInventoryPersistenceService.luau`; `RobloxInventoryDataStoreAdapter.luau`; `PlayerInventorySnapshot.luau` |
| `ServerScriptService/Services/QuestService.luau` | Reusable Logic Candidate | ARCHIVE | **lost** | BA-020 |
| `ServerScriptService/SurvivalGatheringService.server.luau` | Reusable Logic Candidate | ARCHIVE | **lost** | BA-023 |
| `StarterGui/RPGUI.client.luau` | Requires Manual Studio Inspection | ARCHIVE | **lost** | BA-063 |
| `StarterGui/ShopUI.client.luau` | Requires Manual Studio Inspection | ARCHIVE | **lost** | BA-063 |
| `StarterGui/SurvivalHUD.client.luau` | Requires Manual Studio Inspection | ARCHIVE | **lost** | BA-063 |
| `StarterPack/Hatchet/SwingController.client.luau` | Requires Manual Studio Inspection | ARCHIVE | **lost** | BA-062 |
| `StarterPlayer/StarterPlayerScripts/RPGClientController.client.luau` | Requires Manual Studio Inspection | ARCHIVE | **lost** | `init.client.luau` |

## Findings

**1. The six `CANONICAL_REPLACEMENT` modules are the resurrection risk.**
`RPGServerBootstrap`, `CombatService`, `EnemyService`, `InventoryService`,
`LootService` and `PlayerDataService` each duplicate a canonical authority.
Booting any of them beside its replacement is a named stop condition. BA-071
adds the source audit that fails if one is ever wired in.

**2. `RPGServerBootstrap` could never have run in the place it came from.** It
requires `AbilityDefinitions`, `HubTownConfig` and `HubTownContracts`, and none
of the three existed in the place. The same is true of `HubTownService`. The
legacy RPG stack in this place was already broken, which is useful context: it
is a source of ideas, not a working game to be restored.

**3. The genuinely valuable recovered material is the RNG layer.**
`RNGConfig` (15 KB), `RNGEngine` (14.8 KB) and `RandomUtility` together are a
coherent luck-weighted rarity system — base weights from Common 1000 down to
Mythic 1, a `LuckMultiplier` of 0.5 per luck point, and a separate 3% Corrupted
roll that ramps with item level. Nothing canonical does this, and BA-042/BA-043
need exactly this shape.

**4. Two defects must not be ported with it.** Every RNG entry point defaults to
`rng = rng or Random.new()`, so omitting a seed silently produces
non-reproducible results — unacceptable for a seedable resolver.
`RandomUtility.choice(table, rng)` names its parameter `table`, shadowing the
global inside the function, and `shuffle` mutates the caller's table, which
conflicts with the canonical rule that pure resolvers return copies.

**5. `PlayerDataTypes.levelFromExp` iterates without a bound.** It walks the
experience curve one level at a time until the remainder is exhausted, so a
corrupt or hostile total spins. Any canonical port needs a closed form or an
explicit cap.

**6. `DungeonService` is the richest reusable service and the easiest to misuse.**
At 18.5 KB it holds procedural room, corridor, secret-room and modifier logic
worth mining for BA-030/BA-032, but the Expedition room stack already owns
sequencing, placement and secret branches. Ideas only; never a second generator.

**7. Client UI is the largest permanent loss.** All four client scripts —
`RPGUI` (31 KB), `ShopUI`, `SurvivalHUD`, `SwingController` — are gone with no
reference copy: 66.5 KB of interface behaviour known only by file identity.
BA-063 should design from the canonical loop rather than wait for re-extraction,
and treat any later recovery as comparison material.

**8. Gathering survived as design, not as code.** `SurvivalGatheringService` is
lost, but its mechanics were extracted beforehand into
`GATHERING-CRAFTING-CONCEPTS.md` — 7-stud range, 0.55 s swing cooldown, 45 s
node respawn, 10% critical harvest, 5% rare discovery, nine recipes. The
`Workspace/Resources` folders recovered in the hierarchy index (Trees, Rocks,
IronOre) are this service's content, which makes BA-023 tractable despite the
loss.

## Open gaps

| Gap | Blocks | Resolution |
|---|---|---|
| `gap.scripts.lost-sources` | BA-020, BA-023, BA-024, BA-062, BA-063 | Re-extract the 11 lost files from the source place. |
| `gap.scripts.ui-unknown` | BA-063 | Design from the canonical loop; treat re-extraction as comparison only. |
| `gap.scripts.missing-dependencies` | BA-012, BA-024 | `AbilityDefinitions`, `HubTownConfig` and `HubTownContracts` never existed. Do not reconstruct from call sites. |

## What this unblocks

BA-020 (quest contracts), BA-023 (gathering model), BA-042/BA-043 (loot and item
generation) and BA-040 (enemy archetype coverage) all now have a named,
classified input set instead of an undifferentiated pile of legacy code. BA-071
has an explicit list of the six modules its audit must guard against.
