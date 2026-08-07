# Roblox Cooperative FPS RPG
## Cross-System Traceability Matrix — Version 2.3

This matrix answers: **what player promise is being protected, who owns it, what presents it, and what proves it?**

| Promise / state | Mechanical owner | Presentation owner | Visual/asset dependency | Evidence gate |
|---|---|---|---|---|
| Rifle shot | WeaponService + CombatService | Weapon/Combat feedback | FP rifle, muzzle, impacts | E3 fire/reload/hit trace |
| Player health | HealthService | HUD/damage feedback | HUD, hit cue | E3 damage/death/recovery |
| Pursuer lunge | Enemy attack controller | enemy presentation | Pursuer rig/telegraph | E3 no-damage readability + hit-once |
| Shooter burst | ranged attack controller | enemy presentation | Shooter rig/VFX/audio | E3 cover blocks + exactly 3 shots |
| Warden link | CombatModifierService | shield presentation | Warden link VFX | E3 modifier math + cleanup |
| Mixed encounter | EncounterService | objective/presentation bus | arena + enemy readability | E3/E4 completion once |
| Pulse Mark | Ability/Status services | mark presentation | pulse + outline + audio | E3 cooldown/targets/expiry |
| Secret reveal | DiscoverableService | secret presentation | authored clue/cache | E3 correct audience + expiry |
| Loot roll | LootService | reward UI | item icon/name treatment | E3 deterministic roll |
| Item ownership | Inventory/Profile | inventory UI | inventory/item compare UI | E3 owner-only mutation |
| Equip | Inventory/Weapon state | inventory + viewmodel | weapon FP/world models | E3 stats and model agree |
| Route | gameplay/quest state | route controller | authored anchors/landmarks | E3 wayfinding + stream rebind |
| Landmark | world semantic state | landmark controller | hero environment asset | E3 narrow highlight + stream rebind |
| Dungeon room | generator/run state | environment presentation | modular kit/socket metadata | E3 seed valid; E5 performance |
| Boss phase | boss state machine | boss presentation | Gatekeeper rig/VFX/audio | E3 phase sync; E6 learnability |
| Durable reward | Transaction + persistence | reward/inventory UI | none required | E4/E5 retry/rejoin/failure |

## Acceptance rule

A row does not become accepted because only one column works. If the mechanical owner is correct but presentation lies, the player experience is wrong. If presentation is beautiful but mechanical authority is weak, player trust is wrong.
