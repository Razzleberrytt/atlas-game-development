# Loot/build-decision coverage audit — BA-042

## Decision summary

The repository contains two different reward/build tracks:

1. the current operation-bound RPG build made from Field Upgrades and Run Relics; and
2. an older but still source-mapped persistent equipment pipeline that rolls rarity and Power for elite/boss rewards and writes those items to the canonical inventory owner.

The run-build track provides real player choices. The persistent equipment track generates and persists rewards, but its player loop is incomplete: source inspection found no client equip request, no client consumer of the inventory read/compare/dismantle remotes, and no authoritative combat use for armor/relic Power. Expanding that track with procedural item affixes or sets would also conflict with the first RPG integration's explicit exclusions unless a focused product/ownership decision reconciles the two systems.

This is a documentation-only E1 audit. It changes no runtime, reward, inventory, persistence, or balance behavior.

## Authority and evidence

The current product authority permits run-based build/loot choices and bounded equipment decisions, but rejects mandatory power inflation and an unbounded permanent gear treadmill. The narrower [`rpg-integration-plan.md`](rpg-integration-plan.md) deliberately excludes equippable armor, weapon rarity tiers, random weapon-stat rolls, stash storage, and large inventory management from its **first RPG integration**.

Source nevertheless proves that the mapped modern runtime still contains those concepts:

- `EquipmentRewardContracts` declares four slots, three rarity tiers, and scalar Power;
- `EquipmentRewardConfig` declares five persistent reward definitions and separate elite/boss rarity and Power bands;
- `EquipmentRewardService` deterministically rolls one reward per source and creates server-owned grant/instance identities;
- `expedition-reward-results.server.luau` mounts from the canonical server source tree, claims elite/boss rewards, and sends them through `ExpeditionRewardDistributionService` to `InventoryLiveService`;
- `PlayerInventoryPersistenceService` durably applies rewards and contains a server-side equip transition;
- `inventory-network.server.luau` exposes owner-only read, compare, and dismantle calls, but exposes no equip call;
- no client source references `InventoryNetwork`.

Source existence does not settle product intent, and the newer RPG plan does not make the older mapped pipeline disappear. That conflict must be resolved explicitly before BA-043 adds another item-generation layer.

## Coverage matrix

| Layer | Current decision surface | Source-backed status | Gap / disposition |
| --- | --- | --- | --- |
| Starting identity | Specialist + firearm choice before insertion | Live through existing class/loadout owners | Meaningful starting choice; not a loot or rarity system. |
| Field Upgrades | Three server-generated offers at each Field Level; bounded stacks | **12 implemented of 17 declared** in `RunRpgConfig`; five remain `Planned` | Adrenal Response, Second Pulse, Rescue Instinct, Shared Momentum, and Covering Fire still lack their required movement, horde-survival, proximity, or cooperative-action facts. |
| Run Relics | Two deterministic choices, three non-stacking slots, explicit replacement | **12/12 declared relics implemented** through the single run-build owner | Implementation exists; the RPG-0108 “three viable build patterns” and RPG-0113 solo/2/4-player security/readability/performance gates remain Studio evidence, not source claims. |
| Relic reward sources | Elite kill, special interrupt, squad-kill milestone, objective, container, boss milestone | **3 configured/wired; 3 absent** from `RelicRewardSourceConfig` | The RPG plan's P8/P9 dependency prose is stale relative to current source progress. Objective and boss facts now have canonical owners, but wiring either source is a separate gated task; authored containers still lack a current reward owner. |
| Temporary combat resources | Proposed short-duration armor/surge/heal/pickup effects outside relic slots | **No independent catalog, offer, or reward-choice owner found** | Temporary armor and other bounded effects exist as upgrade/relic/class mechanics, not as the distinct Layer D decision surface described by the plan. Do not claim this layer live from descriptive prose. |
| Elite affixes | Five deterministic enemy-side affixes, maximum one per enemy | **5/5 implemented** | Complete enemy pressure/reward-source layer; these are not player-owned item affixes or sets. See [`enemy-archetype-coverage-audit.md`](enemy-archetype-coverage-audit.md). |
| Persistent equipment rewards | One deterministic elite reward and one boss reward per run; five definitions across Primary/Secondary/Armor/Relic; Common/Uncommon/Rare + scalar Power | **Mapped grant/persistence path exists; player choice/application path incomplete** | Rewards are shown at debrief and persisted. No client equip path was found; no client consumes inventory read/compare/dismantle; armor/relic Power has no confirmed gameplay effect. |
| Player-owned item affixes / sets | None | **Missing by design in the run-RPG track; absent from canonical equipment contracts** | Recovered legacy affix/RNG data is reference material only. Do not create affix or set authority until the persistent-equipment conflict and value model are decided. |
| Validation | Static fixtures cover deterministic run-build and equipment transitions | **E1/source only for this audit** | RPG-0108/RPG-0113 Studio matrices remain open; durable equipment behavior cannot be promoted from fixtures alone. |

## Findings

1. **The repository has an unresolved reward-authority/product-scope conflict.** The operation-bound RPG plan excludes rarity/stat equipment from its first integration, while canonical mapped server scripts still generate and persist exactly that older equipment shape. Neither fact may be hidden by documentation.
2. **Persistent equipment currently produces rewards, not meaningful build decisions.** The grant, persistence, snapshot, comparison, equip resolver, and dismantle primitives exist, but the live player path stops short of choosing/equipping an owned reward. Scalar Power for armor/relic items has no confirmed authoritative consumer.
3. **The strongest current build-decision loop is the run build.** Field Upgrade offers and two-choice Run Relics are bounded, server-owned, reset with the operation, and expose explicit tradeoffs without hidden set bonuses.
4. **The Field Upgrade catalog is 12 implemented of 17 declared, not 12 of 12.** The five planned cards are blocked on missing authoritative fact sources rather than missing random-generation machinery.
5. **Rarity exists, but sets and player-item affixes do not.** Common/Uncommon/Rare and Power belong to the persistent equipment pipeline. Elite affixes modify enemies and must not be confused with equipment affixes.
6. **Relic reward-source status prose is stale.** The config still wires only elite kills, special interrupts, and a horde-kill milestone. P8 objective and P10 terminal-result source work has advanced beyond the old dependency notes, but BA-042 does not authorize new runtime wiring.
7. **Evidence remains the limiting factor for the implemented run build.** “Three viable build patterns,” readable reward cadence, multiplayer behavior, cleanup, and representative-horde cost remain Studio/runtime questions.

## Ordered follow-up

1. Record an explicit product/architecture decision for the persistent equipment pipeline: retain it as bounded sidegrade equipment, hold it as dormant compatibility data, or plan a migration/removal after saved-data and rollback requirements are known. Do not silently delete existing inventory data or silently expand permanent Power.
2. Inventory the mapped equipment producers and consumers before any runtime change, including the automatically mounted reward/result and inventory network scripts, the durable store, the unexposed equip transition, and the absence of a client inventory consumer.
3. Correct `rpg-integration-plan.md` reward-source dependency prose in a separately scoped documentation update, then assign any objective/boss relic-source wiring through the active queue rather than treating this audit as authorization.
4. Run the RPG-0108/RPG-0113 Studio matrices when the active runtime lane permits representative evidence.
5. Keep BA-043 blocked until item ownership and product intent are reconciled. If item affixes are later authorized, extend the existing equipment/inventory contracts with stable IDs and a seedable bounded resolver; do not create a parallel loot or persistence owner.

## Completion boundary

BA-042 is complete when this source-backed matrix records both current tracks, identifies where player decisions actually exist, and names the authority conflict without changing runtime behavior. It does not authorize item-affix generation, equipment activation/removal, new reward sources, rebalancing, persistence migration, or Studio evidence promotion.
