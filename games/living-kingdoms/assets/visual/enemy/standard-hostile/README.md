# Exclusion Walker — VIS-0103 source candidate

This folder contains the first project-original standard-hostile source package for Living Kingdoms.

## Included source

- `generate_exclusion_walker.py` — deterministic 18-component model generator.
- `asset-manifest.json` — source ownership, stable root/attachment contract, runtime bounds, authority boundary, and Studio review state.

Running the generator produces:

- `exclusion_walker.obj` — text-native multi-object mesh with vertex colors.
- `exclusion_walker_preview.svg` — elevated-isometric source preview.

The design is an original grounded biomechanical horde enemy. It uses a broad armored torso, long striking arms, a readable sensor face, heavy feet, and a back canister so the hostile remains recognizable from the survivor-follow camera without copying a branded creature or toolbox asset.

## Runtime fallback

`EnemyPresentationService` attaches an 18-part procedural fallback named `ExclusionWalkerPresentation` to each replicated Exclusion Walker model.

The existing authoritative `HumanoidRootPart` remains exactly `3 x 5.6 x 3` studs and continues to own collision, movement, network ownership, targeting position, and gameplay footprint. The fallback parts are massless, non-collidable, non-touchable, and non-queryable. A stable `AttackOrigin` attachment is added for future presentation effects only.

The runtime owner uses one `EnemyEntities.ChildAdded` connection, no per-enemy connections, no heartbeat, no timer, no remote, and a fixed part count.

## Generate the import files

From the repository root, install `numpy`, `matplotlib`, and `trimesh`, then run:

```bash
python games/living-kingdoms/assets/visual/enemy/standard-hostile/generate_exclusion_walker.py
```

## Roblox Studio import procedure

1. Generate `exclusion_walker.obj`.
2. In Studio, choose **File → Import** and select the OBJ.
3. Preserve the named component objects rather than flattening the hierarchy.
4. Wrap the imported components in a canonical model named `ExclusionWalker` bound to the stable `HumanoidRootPart`.
5. Create `AttackOrigin` using the transform in `asset-manifest.json`.
6. Compare the imported candidate against the procedural fallback from the gameplay camera with representative 1-, 2-, and 4-operative horde counts.
7. Do not mark the candidate production-approved until movement, pursuit, attack anticipation/strike/recovery, hit reaction, death, stand-down, cleanup, and performance gates pass.

## Authority boundary

The model and future animation clips are presentation only. Geometry, attachments, animation markers, particles, and sounds cannot spawn enemies, steer movement, choose targets, commit attacks, change health, redefine hit volume, cause death, or delay cleanup.

## Current status

The deterministic source and static procedural fallback are implemented. Imported mesh review, state animation, attack/death effects, audio, accessible telegraphs, cosmetic variants, and representative horde performance evidence remain pending.
