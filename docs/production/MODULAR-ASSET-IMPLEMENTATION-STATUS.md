# Living Kingdoms — Modular Asset Implementation Status

**Catalog version:** `MODULAR-ASSETS-v1`  
**Current implementation phase:** Phase B — live presentation bindings (5 of 5 starter families live)

## Implemented now

- Modular Dungeon Environment Kit starter library: 18 source-generated modules with stable semantic IDs and standardized north/south/east/west snap sockets plus encounter, puzzle, reward, and boss anchors where applicable.
- Modular Enemy Model Pack starter library: 8 archetypes assembled deterministically from 5 body IDs, 6 head IDs, 5 armor IDs, 6 weapon IDs, and 5 accessory IDs. The base body/head/armor/weapon space is 900 combinations before accessories and treatment variation.
- Weapon Model Pack starter library: Assault Rifle, SMG, Shotgun, Hand Cannon, Sniper Rifle, LMG, Launcher, and Exotic prototypes with stable root/grip/muzzle/secondary socket contracts.
- Environmental Prop Pack starter library: Crate, Barrel, Pipe, Terminal, Desk, Shelf, Broken Machinery, Sign, Lamp, Debris, Rock, and Vegetation prototypes.
- Loot Chest / Reward Container starter library: Common, Rare, Epic, Legendary, Boss, Secret, and Event tiers with stable reward-origin and interaction sockets.
- Runtime bootstrap/readiness: the generated starter library is constructed off-tree, marked `GeneratedPrototypeReady` only after construction succeeds, and then published under `ReplicatedStorage/AtlasAssets/GeneratedModularAssets`. Startup-sensitive consumers retain an immediate fast path plus one tightly bounded, asset-specific readiness wait before falling back, preventing bootstrap/replication races from masquerading as missing content.
- Runtime resolver: presentation consumers can find or clone prototypes by stable `AssetId`; readiness-aware consumers can wait for one exact generated `AssetId` without introducing an unbounded startup wait.
- Live dungeon binding: authoritative expedition rooms retain the current deterministic room plan, 48×64×20 footprints, floor/wall collision, entrance/exit connectors, reveal barriers, encounters, environment decoration, and lifecycle. A presentation-only adapter maps Entry, Traversal, Combat/Elite, Boss, and Secret roles to stable dungeon `AssetId`s, non-uniformly fits generated axis-aligned modules to the existing room envelope, removes boss end walls that would falsely block the live entrance/exit, disables collision/touch/query on every generated shell part, and strips generated sockets/scripts/prompts. Only the matching graybox Floor/WestWall/EastWall visuals are hidden after a successful mount; their gameplay collision remains authoritative. Missing or malformed generated modules leave the complete graybox visible.
- Live environment binding: authored world placements can resolve stable modular environment assets while retaining procedural fallback composition.
- Live enemy binding: standard enemy presentation can consume modular enemy families while preserving special/boss rules and gameplay authority.
- Live weapon binding: all six configured firearms map to stable modular weapon IDs. The generated shell auto-fits from its `Grip` → `Muzzle` socket span and mounts onto the existing mechanical presentation rig, preserving grip, bolt, magazine, recoil, reload, muzzle, ejection, and combat contracts. Missing generated assets fall back to the existing project-original procedural weapon model.
- Live reward-container binding:
  - completed, banked expedition rewards render Common/Rare/Boss modular chests in the existing debrief without creating a claim path;
  - pending run-relic offers render a source-authored Common/Rare/Boss chest in the existing choice HUD while the server remains authoritative for offered relic IDs and replacement rules;
  - survival supply chests use the generated Common reward chest with the original three-part procedural chest as a fallback. Generated shell parts are non-colliding, non-touching, and non-queryable; legacy-sized invisible proxies preserve the previous character collision and ray-query footprint while `SurvivalLootService` retains all loot authority.
- Validation: `scripts/validate_modular_asset_systems.py` checks the 20-pack roadmap, starter library, all six live firearm mappings, socket-fit adapter contract, weapon-factory integration, reward viewport bindings, live relic reward-source mapping, survival chest fallback/query boundary, and retained loot authority. Focused source audits separately lock atomic asset publication/readiness and the live dungeon shell mapping, fit, fallback, collision, connector, reveal-barrier, and authority boundaries.

## Deliberately not claimed complete

All five starter families now have live presentation consumers, but this does **not** mean the separate seeded/RNG spatial-layout rewrite is complete. The live dungeon integration deliberately skins the current canonical deterministic linear room placement instead of replacing `RoomPlacementPlanner`. A future spatial-generation pass can change room positioning/connection topology independently as long as it preserves the same presentation-safe room contract or explicitly migrates it.

Packs 6–20 are cataloged and specified but are not all modeled yet. Authored production meshes are also not claimed complete; current geometry is a source-generated blockout/prototype layer designed to let systems integrate immediately and to be replaced without changing semantic IDs or gameplay authority.

The live weapon binding intentionally keeps the existing procedural rig as a mechanical skeleton. The modular shell replaces static silhouette geometry while the current moving bolt/magazine assemblies continue to drive visible presentation motion. Authored weapon meshes can later replace generated shells without changing gameplay code.

Generic modular blockouts are not treated as automatic upgrades. Existing bespoke ammo-cache and mission-object presentations remain in place where they carry richer state, interaction, or readability information than the current generic prototypes.

## Next highest-ROI implementation passes

1. Studio-verify modular dungeon shell fit, doorway/reveal-barrier visibility, boss entrance/exit readability, floor/wall collision retention, and room-to-room transitions across several seeds.
2. Studio-verify first-person weapon shells, survival chest collision/opening, reward viewports, and device-scaled HUD readability across representative sessions.
3. Replace the most-visible first-person weapon shells and highest-frequency dungeon pieces with authored meshes while preserving stable IDs and socket contracts.
4. Refresh the separate seeded/RNG spatial-layout branch against current `main` only if broader room-topology variation is the next gameplay priority; keep it independent from the now-live modular presentation contract.
5. Add future-pack bindings only where an existing gameplay owner already exposes a presentation-safe state seam; do not replace richer bespoke stateful visuals with lower-information generic blockouts.
