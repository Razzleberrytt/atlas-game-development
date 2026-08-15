# Living Kingdoms — Modular Asset Production Roadmap

**Status:** ACTIVE CONTENT PRODUCTION SPEC  
**Scope:** `games/living-kingdoms`  
**Primary loop:** Explore → Fight → Loot → Upgrade → Repeat  
**Strategy:** build reusable combinable systems before one-off assets.

## Production rules

1. Gameplay authority stays in gameplay systems. Asset packs provide presentation, sockets, collision hints, and stable semantic IDs.
2. Never require a marketplace asset ID for a prototype. Source-generated primitives are valid placeholders until authored meshes replace them.
3. Every reusable asset gets a stable semantic `AssetId` and `PackId` so geometry can change without breaking consumers.
4. Dungeon pieces expose standardized snap sockets. Enemy parts expose standardized equipment/body slots.
5. Generated prototypes live under `ReplicatedStorage/AtlasAssets/GeneratedModularAssets`; the bootstrap only replaces that owned folder.
6. Prefer a small library with high combinatorial yield over a large library of unique objects.
7. No per-prop scripts. Shared systems own behavior, interaction, destruction, VFX, and replication.

The machine-readable catalog is `games/living-kingdoms/src/shared/Config/ModularAssetProductionCatalog.luau` and the runtime prototype factory is `games/living-kingdoms/src/shared/Assets/ModularAssetFactory.luau`.

## Highest-ROI build order

1. **Modular Dungeon Environment Kit**
2. **Modular Enemy Model Pack**
3. **Weapon Model Pack**
4. **Environmental Prop Pack**
5. **Loot Chest / Reward Containers**

These five form the scalable content loop: procedural spaces → readable threats → high-frequency first-person weapons → reusable dressing → visible rewards.

---

## 1. Modular Enemy Model Pack

Build enemies from interchangeable heads, bodies/torsos, armor overlays, weapons, and accessories. Core archetypes: Grunt, Shooter, Heavy, Melee Attacker, Sniper, Support Unit, Elite Variant, and Corrupted/Mutated Variant.

**Starter combinatorics:** 5 bodies × 6 heads × 5 armor sets × 6 weapons = **900 visual combinations** before accessory, color, material, and VFX variation. The runtime must generate combinations on demand rather than storing 900 models.

## 2. Weapon Model Pack

Create a unified stylized FPS weapon language with Assault Rifles, SMGs, Shotguns, Hand Cannons, Sniper Rifles, LMGs, Rocket/Grenade Launchers, and Exotic/Special Weapons. Each prototype must expose a root, muzzle socket, grip socket, and optional magazine/secondary socket.

## 3. Modular Dungeon Environment Kit

Reusable pieces: straight/curved/broken corridors; combat/puzzle/loot/empty rooms; standard/locked/destructible/hidden doors; staircases; bridges; platforms; dead ends; boss arenas; treasure rooms; secret rooms. Pieces use standardized snap attachments so procedural generation can compose rooms without knowing their mesh implementation.

## 4. Boss Models

Boss concepts: Corrupted Knight, Mechanical Colossus, Ancient Guardian, Mutated Scientist, Eldritch Floating Entity, and Dungeon Core Guardian. Bosses are milestone and marketing assets; silhouettes must remain readable at thumbnail distance.

## 5. Environmental Prop Packs

Reusable dressing: crates, barrels, pipes, terminals, tables/desks, shelves, broken machinery, signs, lamps, debris, rocks, and vegetation. Props carry collision intent and semantic category rather than gameplay scripts.

## 6. Loot Chest / Reward Container Models

Tiers: Common, Rare, Epic, Legendary, Boss, Secret, and Event. Tiers share a visual grammar while escalating silhouette, trim, emissive treatment, and reveal intensity.

## 7. Armor Set Models

Slots: helmets, chest plates, gloves, boots, shoulder armor, and back accessories. Themes: Light Scout, Heavy Tank, Tech/Cyber, Corrupted, and Elite Faction.

## 8. Enemy Weapon Models

Faction-readable examples: Alien Energy Rifle, Scrap Cannon, Arcane Energy Staff, Plasma Sidearm, Heavy Siege Turret Gun, and Corrupted Blade.

## 9. Main Hub Environment Kit

Weapon Vendor Station, Armor Upgrade Station, Crafting Bench, Mission Terminal, Storage/Vault, Upgrade/Enhancement Station, Portal/Dungeon Entry Gate, Social Gathering Area, and Training/Firing Range.

## 10. Biome Environment Packs

Ancient Ruins, Underground Caverns, Abandoned Laboratory, Frozen Fortress, Corrupted Forest, Industrial Facility, Alien Temple, and Volcanic Depths. Biome identity should be expressed through material palettes, prop weights, lighting profiles, landmarks, and encounter dressing rather than bespoke gameplay code.

## 11. Interactive Object Models

Switches, consoles, levers, pressure plates, manual/automated doors, elevators, power generators, hackable terminals, and explosive containers. Interaction logic remains centralized; models expose interaction sockets and semantic IDs.

## 12. Elite Enemy Variants

Armored, Flaming, Frozen, Toxic, Electric, Corrupted, Shielded, and Berserker. Variants should reuse base enemy rigs and AI while adding clear visual modifiers and gameplay tags.

## 13. Ability / Skill Visual Effects

Energy Blast, Ground Slam Shockwave, Healing Field Aura, Protective Shield Dome, Teleport Burst, Grenade Explosion variants, Chain Lightning, Fire Explosion, and Ice Burst/Freeze Wave. Use a consistent color/shape language for damage, protection, healing, control, and traversal.

## 14. World Landmark Models

Massive Tower Structures, Crashed Spaceships, Ancient Statues, Giant Portal Structures, Floating Crystals, Wrecked Vehicles, Colossal Skeletons, and Ruined Fortresses. Landmarks should aid navigation as well as visual storytelling.

## 15. Resource / Crafting Material Models

Ore Deposits, Crystals, Biome Plants, Monster Parts, Scrap Metal, Energy Cores, and Ancient Relics. One collectible can simultaneously support crafting, upgrades, quests, and exploration.

## 16. Quest NPC Models

Gunsmith, Scientist, Scout, Merchant, Engineer, Expedition Leader, Mysterious Stranger, and Faction Commander. NPC silhouettes and station placement should make role readable before text is read.

## 17. Enemy Spawn / Encounter Objects

Alien Portals, Monster Nests, Drop Pods, Summoning Altars, Corruption Growths, Teleportation Gates, and Enemy Dropships. These visually justify encounter starts and give players readable threat sources.

## 18. Destructible Environment Models

Crates, Barricades, Computers, Glass Panels, Structural Pillars, Explosive Tanks, Doors, and Machinery Units. Destruction behavior is shared and data-driven; authored models expose fracture/destruction groups.

## 19. Random Event Asset Pack

Supply Drops, Enemy Beacons, Ritual Altars, Convoy Vehicles, Excavation Machines, Fallen Satellites, Treasure Caches, and Corruption Crystals. Event props should be composable with existing encounter/objective systems.

## 20. Rare / Exotic Item Models

Unique Weapons, Legendary Armor Sets, Ancient Relics, Energy Artifacts, Special Backpacks, Power Cores, and Cosmetic Trophies. Exotic presentation must be recognizable in first person, inventory previews, drops, and social spaces.

---

## Implementation phases

### Phase A — source-generated starter library

Ship functional primitive prototypes for the five highest-ROI packs. They exist to make composition, procedural generation, gameplay binding, and art replacement testable immediately.

### Phase B — gameplay bindings

Bind existing enemy, dungeon, loot, and weapon systems to stable asset IDs through presentation resolvers. Gameplay code must not directly depend on generated geometry names.

### Phase C — authored mesh replacement

Replace individual source-generated prototypes with imported authored models while preserving semantic IDs, root/snap/equipment sockets, and collision policy.

### Phase D — long-tail packs

Implement packs 6–20 in ROI order as their consuming gameplay systems become active.

## Acceptance criteria for the first five packs

- The server bootstrap deterministically creates one generated asset root in ReplicatedStorage.
- Dungeon starter modules include standardized snap attachments.
- Enemy variants are assembled from independent body/head/armor/weapon libraries and can be generated deterministically from a seed.
- All eight weapon categories have usable prototype models and a muzzle socket.
- All twelve environmental prop categories have at least one prototype.
- All seven reward-container tiers have a prototype with stable tier metadata.
- Generated assets carry stable `AssetId`, `PackId`, and catalog-version attributes.
- No generated prototype owns combat, loot, reward, AI, persistence, or interaction authority.
- No fake or placeholder marketplace asset IDs are committed.
- Static validation fails if the production contract loses any of the 20 packs or the top-five implementation surface.

## Force-multiplier target

The system succeeds when adding one authored part multiplies available content instead of merely adding one object. Enemy parts should recombine across compatible archetypes; dungeon pieces should recombine across encounter/objective/prop/lighting sets; reward containers should reuse shared reveal behavior; props should dress multiple biomes. That is the content-scaling edge this roadmap is designed to protect.
