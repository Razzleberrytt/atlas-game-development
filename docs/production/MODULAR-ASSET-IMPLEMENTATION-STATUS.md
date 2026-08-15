# Living Kingdoms — Modular Asset Implementation Status

**Catalog version:** `MODULAR-ASSETS-v1`  
**Current implementation phase:** Phase B — live presentation bindings (4 of 5 starter families live)

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
- Live reward-container binding:
  - completed, banked expedition rewards render Common/Rare/Boss modular chests in the existing debrief without creating a claim path;
  - pending run-relic offers render a source-authored Common/Rare/Boss chest in the existing choice HUD while the server remains authoritative for offered relic IDs and replacement rules;
  - survival supply chests use the generated Common reward chest with the original three-part procedural chest as a fallback. Generated shell parts are non-colliding, non-touching, and non-queryable; legacy-sized invisible proxies preserve the previous character collision and ray-query footprint while `SurvivalLootService` retains all loot authority.
- Validation: `scripts/validate_modular_asset_systems.py` checks the 20-pack roadmap, starter library, all six live firearm mappings, socket-fit adapter contract, weapon-factory integration, reward viewport bindings, live relic reward-source mapping, survival chest fallback/query boundary, and retained loot authority through the unified repository gate.

## Deliberately not claimed complete

The top-five starter library is implemented, but the modular dungeon kit is not yet bound to the live seeded expedition renderer. The existing seeded-layout work must be refreshed against current `main` and Studio-verified before modular floor/wall modules can replace graybox geometry without risking route, barrier, collision, or encounter-authority drift.

Packs 6–20 are cataloged and specified but are not all modeled yet. Authored production meshes are also not claimed complete; current geometry is a source-generated blockout/prototype layer designed to let systems integrate immediately and to be replaced without changing semantic IDs or gameplay authority.

The live weapon binding intentionally keeps the existing procedural rig as a mechanical skeleton. The modular shell replaces static silhouette geometry while the current moving bolt/magazine assemblies continue to drive visible presentation motion. Authored weapon meshes can later replace generated shells without changing gameplay code.

Generic modular blockouts are not treated as automatic upgrades. Existing bespoke ammo-cache and mission-object presentations remain in place where they carry richer state, interaction, or readability information than the current generic prototypes.

## Next highest-ROI implementation passes

1. Refresh the seeded dungeon foundation against current `main`, then bind stable dungeon module IDs/snap sockets while preserving canonical room order, encounter/barrier authority, and the existing traversal collision contract.
2. Verify modular asset bootstrap ordering so live consumers reliably see the generated library and fall back only when assets are genuinely unavailable, not because of startup timing.
3. Studio-verify first-person weapon shells, survival chest collision/opening, reward viewports, and device-scaled HUD readability across several representative sessions.
4. Replace the most-visible first-person modular weapon shells and highest-frequency dungeon pieces with authored meshes while preserving stable IDs and socket contracts.
5. Add future-pack bindings only where an existing gameplay owner already exposes a presentation-safe state seam; do not replace richer bespoke stateful visuals with lower-information generic blockouts.
