# Blackwater Service Carbine — VIS-0102 source candidate

This folder contains the first original model and animation source package for Living Kingdoms.

## Included source

- `generate_blackwater_carbine.py` — deterministic model generator.
- `blackwater_service_carbine.animations.json` — source curves for `Fire`, `Reload`, and `Empty`.
- `asset-manifest.json` — model names, attachment transforms, ownership, review state, and authority boundary.

Running the generator produces:

- `blackwater_service_carbine.obj` — text-native multi-object mesh with vertex colors;
- `blackwater_service_carbine_preview.svg` — elevated-isometric source preview.

The model is a fictional weathered service carbine created for the project. It is not copied from a branded real-world firearm or downloaded from a toolbox or asset library.

## Source contents

- 19 modeled components.
- Named receiver, handguard, stock, barrel, muzzle, grips, magazine, bolt, sights, trigger, sling mounts, and detail parts.
- Five attachment transforms: `RightGripAttachment`, `LeftGripAttachment`, `Muzzle`, `Magazine`, and `Ejection`.
- Three presentation tracks: `Fire`, `Reload`, and `Empty`.

## Generate the import files

From the repository root, install `numpy`, `matplotlib`, and `trimesh`, then run:

```bash
python games/living-kingdoms/assets/visual/weapon/basic-firearm/generate_blackwater_carbine.py
```

The committed generator and curves are the canonical editable source. Generated OBJ and preview output may be recreated deterministically rather than relying on an opaque uploaded model ID.

## Roblox Studio import procedure

1. Generate `blackwater_service_carbine.obj`.
2. In Studio, choose **File → Import** and select the OBJ.
3. Preserve the separate named component objects rather than flattening the source into an anonymous mesh.
4. Wrap the imported components in a canonical Model named `BasicFirearm` with a stable `WeaponRoot`.
5. Create Roblox `Attachment` instances using the exact transforms in `asset-manifest.json`.
6. Recreate the three presentation tracks from `blackwater_service_carbine.animations.json` against the named `Bolt` and `Magazine` components.
7. Do not publish or register the model as production-approved until the elevated-isometric Studio review passes.

Roblox's current Importer supports `.obj` models. The animation curves are stored separately so their application to the imported hierarchy can be reviewed without an opaque uploaded animation ID.

## Authority boundary

The clips are presentation only. Animation markers and mesh motion cannot commit shots, ammunition, reload completion, targets, hits, or damage. Existing server-owned combat state must accept an event before the corresponding presentation plays.

## Current status

This completes the source creation portion of VIS-0102. It does not complete runtime integration, effects, audio, fallback verification, Studio readability, or performance evidence.
