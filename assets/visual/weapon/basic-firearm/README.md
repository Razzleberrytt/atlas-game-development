# Living Kingdoms basic-firearm visual source candidates

This folder contains original, reproducible model and animation source packages for the current `visual.weapon.basic-firearm.model` footprint.

## Current runtime fallback — Blackwater Support LMG

The current procedural fallback uses `blackwater-support-lmg.v1`: a fictional belt-fed squad support weapon designed for a strong elevated-isometric silhouette.

Included source:

- `generate_blackwater_support_lmg.py` — deterministic 45-component model generator.
- `blackwater_support_lmg.animations.json` — source curves for `Fire`, `Reload`, and `Empty`.
- `blackwater-support-lmg.manifest.json` — attachment transforms, ownership, review state, and authority boundary.

Running the generator produces:

- `blackwater_support_lmg.obj` — text-native multi-object mesh with vertex colors.
- `blackwater_support_lmg_preview.svg` — elevated-isometric source preview.

The design uses broad light-machine-gun visual language—belt feed, ammunition box, carrying handle, long barrel, heat shield, and bipod—but is project-original rather than a replica of the M249 or another branded real-world firearm.

### Generate the support-LMG import files

From the repository root, install `numpy`, `matplotlib`, and `trimesh`, then run:

```bash
python games/living-kingdoms/assets/visual/weapon/basic-firearm/generate_blackwater_support_lmg.py
```

### Roblox Studio import procedure

1. Generate `blackwater_support_lmg.obj`.
2. In Studio, choose **File → Import** and select the OBJ.
3. Preserve the separate named component objects rather than flattening the source into an anonymous mesh.
4. Wrap the imported components in a canonical Model named `BasicFirearm` with a stable `WeaponRoot`.
5. Create Roblox `Attachment` instances using the exact transforms in `blackwater-support-lmg.manifest.json`.
6. Recreate the three presentation tracks from `blackwater_support_lmg.animations.json` against the named `Bolt` and `Magazine` components.
7. Compare the imported model against the procedural fallback at the survivor-follow gameplay camera.
8. Do not publish or register the model as production-approved until the elevated-isometric Studio review and performance gate pass.

## Retained source candidate — Blackwater Service Carbine

The first VIS-0102 source package remains available for comparison and rollback:

- `generate_blackwater_carbine.py`
- `blackwater_service_carbine.animations.json`
- `asset-manifest.json`

Running that generator produces `blackwater_service_carbine.obj` and `blackwater_service_carbine_preview.svg`.

## Stable contract

Both candidates use:

- Model wrapper: `BasicFirearm`
- Root: `WeaponRoot`
- Attachments: `RightGripAttachment`, `LeftGripAttachment`, `Muzzle`, `Magazine`, and `Ejection`
- Presentation tracks: `Fire`, `Reload`, and `Empty`
- Gameplay footprint: `weapon.basic-firearm`

The committed generators and curves are the canonical editable source. Generated OBJ and preview output may be recreated deterministically instead of relying on opaque uploaded model or animation IDs.

## Authority boundary

The clips and model are presentation only. Animation markers, mesh motion, belt geometry, and ammunition-box motion cannot commit shots, spend ammunition, finish reloads, select targets, validate hits, or apply damage. Existing server-owned combat state must accept an event before the corresponding presentation plays.

## Current status

The support LMG is integrated as an honestly labeled client-only procedural fallback and has deterministic import source. Roblox Studio mesh import, grip/readability review, animation verification, and performance evidence remain pending before production approval.
