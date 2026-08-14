# Patch 0.9 Content Production Gate

**Status:** ACTIVE SOURCE GATE  
**Scope:** Living Kingdoms content expansion and reusable authoring pipeline

Patch 0.9 scales systems that already survived earlier playable construction. It does not authorize a second combat, reward, encounter, persistence, class, or world authority merely to add breadth.

## Production law

A new content definition is not complete because its table exists. Before merge, it must be reachable through the proven runtime path that gives the definition meaning, and the owning registry must reject broken cross-links.

For the current Patch 0.9 lanes:

1. **Firearms → durable equipment**
   - `FirearmConfig` owns combat firearm definitions.
   - Every `DiscoverableWeaponId` must have a durable `EquipmentRewardConfig` representation.
   - Equipment weapon links must resolve through `FirearmConfig.isKnownWeaponId`.
   - The opening Service Pistol must retain a durable sidearm representation.

2. **Equipment → role-aware affixes**
   - `EquipmentRewardConfig` owns durable item identity, slot and authoring tags.
   - `EquipmentAffixConfig` may only require tags present in the durable catalog.
   - Every durable item must have at least one tag-specific affix path in its own slot; generic rolls are fallback breadth, not sufficient item identity.
   - Affix effects remain limited to the existing `EquipmentAffixModifierResolver` consequences and their existing runtime owners.

3. **Room assembly → authored encounters**
   - `RoomAssemblyConfig` owns the selectable room pool.
   - `FirstDungeonContentConfig.Encounters` must cover every room in that pool, not only the current canonical seed.
   - Encounter entries for deleted/unknown rooms are invalid.
   - Slot, intensity and reward-source identity must match the room definition.
   - `ExpeditionServerBootstrap` continues resolving encounter content by the assembled `RoomId`; no per-seed runtime branch is allowed.

4. **Room identity → environment production**
   - `ExpeditionRoomPlacementService` and `ExpeditionEnvironmentBuilder` remain role-driven and deterministic.
   - Adding an ordinary traversal/combat room must not require a second placement or environment owner.
   - Bespoke geometry or behavior is allowed only when a new content requirement actually needs it and receives its own validated integration seam.

## Expansion discipline

Patch 0.9 prefers adding content to these proven seams over creating broad new systems. A new class, enemy family, boss, region, crafting loop, quest framework, or cosmetic system is not automatically required by the patch candidate list. Such breadth is deferred when it would create a new authority or balance surface without play evidence that the current product needs it.

The content gate asks two questions before accepting an expansion:

- **Reachability:** can the existing runtime actually select, present and apply this content?
- **Maintenance:** will a future authoring mistake fail at configuration/test time instead of appearing as missing, inert or contradictory content in a live run?

If either answer is no, fix the pipeline before adding more breadth.

## Verification boundary

Passing this source gate does **not** promote Patch 0.9 to runtime verified. The consolidated Studio/device pass remains required for player-facing feel, visual readability, multi-client behavior and representative performance. Any runtime evidence that invalidates these assumptions preempts later work and returns priority to FIX.
