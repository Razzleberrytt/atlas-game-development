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

`EnemyPresentationService` attaches an 18-part procedural fallback named `ExclusionWalkerPresentation` to each replicated Exclusion Walker model. Five presentation-only Motor6Ds expose the torso, forearms, and legs without changing the authoritative root.

The existing authoritative `HumanoidRootPart` remains exactly `3 x 5.6 x 3` studs and continues to own collision, movement, network ownership, targeting position, and gameplay footprint. The fallback parts are massless, non-collidable, non-touchable, and non-queryable. A stable `AttackOrigin` attachment is retained for future presentation effects only.

`EnemyPresentationController` is a client-local pose controller. It reads only replicated movement speed, movement direction, the existing health label, and anchored death/stand-down state. It provides:

- alternating roaming and pursuit stride poses;
- a raised non-strike threat-ready pose when a pursuit-speed Walker is stationary;
- a brief hit reaction after the authoritative health label decreases;
- distinct stand-down and death silhouettes;
- sensor brightness changes that supplement, but do not replace, the pose cues.

The server runtime owner uses one `EnemyEntities.ChildAdded` connection. The client state layer uses one `RenderStepped` connection plus two folder-level lifecycle connections. Both layers use zero per-enemy connections, zero remotes, and zero per-enemy timers. Motor writes occur only when the resolved pose ID changes.

This slice does **not** claim an attack telegraph or committed strike. The current enemy contract applies authoritative contact damage immediately, so anticipation and server-confirmed strike/recovery presentation remain pending rather than being fabricated from proximity.

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
5. Preserve the five stable motor names and create `AttackOrigin` using the transform in `asset-manifest.json`.
6. Compare the imported candidate against the procedural fallback from the gameplay camera with representative 1-, 2-, and 4-operative horde counts.
7. Verify roaming, pursuit, threat-ready, hit, stand-down, and death readability without relying on sensor color alone.
8. Do not mark the candidate production-approved until attack anticipation/strike/recovery, effects, audio, cleanup, and representative performance gates pass.

## Authority boundary

The model, motors, pose resolver, and future animation clips are presentation only. Geometry, attachments, animation markers, particles, and sounds cannot spawn enemies, steer movement, choose targets, commit attacks, change health, redefine hit volume, cause death, or delay cleanup.

## Current status

The deterministic source, motorized procedural fallback, and client-local replicated-state pose layer are implemented. Imported mesh review, server-confirmed attack presentation, effects, audio, accessible anticipation, cosmetic variants, and representative horde performance evidence remain pending.
