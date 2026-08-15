# Living Kingdoms — Modular Asset Implementation Status

**Catalog version:** `MODULAR-ASSETS-v1`  
**Current implementation phase:** Phase B — live presentation bindings

## Implemented now

- Modular Dungeon Environment Kit starter library: 18 source-generated modules with stable semantic IDs and standardized north/south/east/west snap sockets plus encounter, puzzle, reward, and boss anchors where applicable.
- Modular Enemy Model Pack starter library: 8 archetypes assembled deterministically from 5 body IDs, 6 head IDs, 5 armor IDs, 6 weapon IDs, and 5 accessory IDs. The base body/head/armor/weapon space is 900 combinations before accessories and treatment variation.
- Weapon Model Pack starter library: Assault Rifle, SMG, Shotgun, Hand Cannon, Sniper Rifle, LMG, Launcher, and Exotic prototypes with stable root/grip/muzzle/secondary socket contracts.
- Environmental Prop Pack starter library: Crate, Barrel, Pipe, Terminal, Desk, Shelf, Broken Machinery, Sign, Lamp, Debris, Rock, and Vegetation prototypes.
- Loot Chest / Reward Container starter library: Common, Rare, Epic, Legendary, Boss, Secret, and Event tiers with stable reward-origin and interaction sockets.
- Runtime bootstrap: generated prototypes are published under `ReplicatedStorage/AtlasAssets/GeneratedModularAssets` and version-replaced only inside that owned subtree.
- Runtime resolver: presentation consumers can find or clone prototypes by stable `AssetId` rather than depending on generated model names.
- Live environment binding: authored world placements can resolve stable modular environment assets while retaining procedural fallback composition.
- Live enemy binding: standard enemy presentation can consume modular enemy families while preserving special/boss rules and gameplay authority.
- Live weapon binding: all six configured firearms map to stable modular weapon IDs. The generated shell auto-fits from its `Grip` → `Muzzle` socket span and mounts onto the existing mechanical presentation rig, preserving grip, bolt, magazine, recoil, reload, muzzle, ejection, and combat contracts. Missing generated assets fall back to the existing project-original procedural weapon model.
- Validation: `scripts/validate_modular_asset_systems.py` checks the 20-pack roadmap, starter library, all six live firearm mappings, socket-fit adapter contract, and live weapon-factory integration through the unified repository gate.

## Deliberately not claimed complete

Packs 6–20 are cataloged and specified but are not all modeled yet. Authored production meshes are also not claimed complete; current geometry is a source-generated blockout/prototype layer designed to let systems integrate immediately and to be replaced without changing semantic IDs or gameplay authority.

The live weapon binding intentionally keeps the existing procedural rig as a mechanical skeleton. The modular shell replaces static silhouette geometry while the current moving bolt/magazine assemblies continue to drive visible presentation motion. Authored weapon meshes can later replace generated shells without changing gameplay code.

## Next highest-ROI implementation passes

1. Complete the in-progress seeded dungeon consumer integration against stable dungeon module IDs and snap sockets without duplicating dungeon-generation authority.
2. Bind reward-container visuals to existing loot/reward authority and shared reveal behavior.
3. Replace the most-visible first-person modular weapon shells with authored meshes while preserving the same stable asset IDs and `Grip`/`Muzzle` contract.
4. Expand authored replacements for the highest-frequency dungeon, enemy, and prop pieces while preserving prototype contracts.
5. Add modular presentation bindings for high-frequency interactive objects only where an existing gameplay authority already owns the interaction state.
