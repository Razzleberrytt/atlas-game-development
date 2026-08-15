# Living Kingdoms — Modular Asset Implementation Status

**Catalog version:** `MODULAR-ASSETS-v1`  
**Current implementation phase:** Phase A — source-generated starter library

## Implemented now

- Modular Dungeon Environment Kit starter library: 18 source-generated modules with stable semantic IDs and standardized north/south/east/west snap sockets plus encounter, puzzle, reward, and boss anchors where applicable.
- Modular Enemy Model Pack starter library: 8 archetypes assembled deterministically from 5 body IDs, 6 head IDs, 5 armor IDs, 6 weapon IDs, and 5 accessory IDs. The base body/head/armor/weapon space is 900 combinations before accessories and treatment variation.
- Weapon Model Pack starter library: Assault Rifle, SMG, Shotgun, Hand Cannon, Sniper Rifle, LMG, Launcher, and Exotic prototypes with stable root/grip/muzzle/secondary socket contracts.
- Environmental Prop Pack starter library: Crate, Barrel, Pipe, Terminal, Desk, Shelf, Broken Machinery, Sign, Lamp, Debris, Rock, and Vegetation prototypes.
- Loot Chest / Reward Container starter library: Common, Rare, Epic, Legendary, Boss, Secret, and Event tiers with stable reward-origin and interaction sockets.
- Runtime bootstrap: generated prototypes are published under `ReplicatedStorage/AtlasAssets/GeneratedModularAssets` and version-replaced only inside that owned subtree.
- Runtime resolver: presentation consumers can find or clone prototypes by stable `AssetId` rather than depending on generated model names.
- Validation: the 20-pack roadmap and top-five starter-library contract are checked by `scripts/validate_modular_asset_systems.py` through the unified repository gate.

## Deliberately not claimed complete

Packs 6–20 are cataloged and specified but are not all modeled yet. Authored production meshes are also not claimed complete; current geometry is a source-generated blockout/prototype layer designed to let systems integrate immediately and to be replaced without changing semantic IDs or gameplay authority.

## Next highest-ROI implementation passes

1. Bind procedural dungeon layout consumers to the stable dungeon module IDs and snap sockets without duplicating dungeon-generation authority.
2. Bind enemy presentation selection to modular visual IDs while preserving the existing enemy combat/archetype authority.
3. Bind weapon presentation to the eight weapon-family prototypes, then replace the most-visible first-person models with authored meshes first.
4. Bind reward-container visuals to existing loot/reward authority and shared reveal behavior.
5. Begin authored replacements for the highest-frequency dungeon, enemy, weapon, and prop pieces while preserving the prototype contracts.
