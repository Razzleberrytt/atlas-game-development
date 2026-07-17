# Blackwater Service Carbine — VIS-0102 source candidate

This folder contains the first original model and animation source package for Living Kingdoms.

## Included

- `blackwater_service_carbine.obj` — text-native multi-object mesh source with vertex colors.
- `blackwater_service_carbine.animations.json` — source curves for `Fire`, `Reload`, and `Empty`.
- `asset-manifest.json` — names, locators, animation clips, ownership, and authority boundary.
- `generate_blackwater_carbine.py` — reproducible source generator.

The model is a fictional weathered service carbine created for the project. It is not copied from a branded real-world firearm or downloaded from a toolbox or asset library.

## Source contents

- 19 modeled components.
- Named receiver, handguard, stock, barrel, muzzle, grips, magazine, bolt, sights, trigger, sling mounts, and detail parts.
- Five attachment transforms: `RightGripAttachment`, `LeftGripAttachment`, `Muzzle`, `Magazine`, and `Ejection`.
- Three presentation tracks: `Fire`, `Reload`, and `Empty`.

## Roblox Studio import procedure

1. In Studio, choose **File → Import** and select `blackwater_service_carbine.obj`.
2. Preserve the separate named component objects rather than flattening the source into an anonymous mesh.
3. Wrap the imported components in a canonical Model named `BasicFirearm` with a stable `WeaponRoot`.
4. Create Roblox `Attachment` instances using the exact transforms in `asset-manifest.json`.
5. Recreate or import the three presentation tracks from `blackwater_service_carbine.animations.json` against the named `Bolt` and `Magazine` components.
6. Do not publish or register the model as production-approved until the elevated-isometric Studio review passes.

Roblox's current Importer supports `.obj` models. The animation curves are stored separately so their application to the imported hierarchy can be reviewed without an opaque uploaded animation ID.

## Authority boundary

The clips are presentation only. Animation markers and mesh motion cannot commit shots, ammunition, reload completion, targets, hits, or damage. Existing server-owned combat state must accept an event before the corresponding presentation plays.

## Current status

This completes the source creation portion of VIS-0102. It does not complete runtime integration, effects, audio, fallback verification, Studio readability, or performance evidence.
