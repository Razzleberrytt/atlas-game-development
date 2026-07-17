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

`EnemyDirectorService` now writes six ordinary replicated model attributes for presentation only: exact behavior state, life state, confirmed attack sequence/timestamp, and confirmed hit sequence/timestamp. `EnemyPresentationController` consumes those server-authored facts plus replicated movement direction. It provides:

- alternating roaming and pursuit stride poses;
- a raised non-strike threat-ready pose while the authoritative state is `Pursuing` or `Attacking`;
- alternating left/right active-strike and recovery poses only after authoritative damage commits;
- a brief hit reaction only after authoritative enemy health decreases;
- distinct stand-down and death silhouettes;
- sensor brightness changes that supplement, but do not replace, the pose cues.

The server runtime owner uses one `EnemyEntities.ChildAdded` connection. The client state layer uses one `RenderStepped` connection plus two folder-level lifecycle connections. Both layers use zero per-enemy connections, zero remotes, and zero per-enemy timers. Attribute writes occur only on committed state/event changes, and motor writes occur only when the resolved pose ID changes.

This slice still does **not** claim attack anticipation. The current contact-damage contract has no windup phase, so the presentation begins only after the server confirms damage and never predicts a strike from proximity.

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
7. Verify roaming, pursuit, threat-ready, confirmed active-strike/recovery, hit, stand-down, and death readability without relying on sensor color alone.
8. Do not mark the candidate production-approved until attack anticipation, effects, audio, cleanup, and representative performance gates pass.

## Authority boundary

The model, motors, pose resolver, and future animation clips are presentation only. Geometry, attachments, animation markers, particles, and sounds cannot spawn enemies, steer movement, choose targets, commit attacks, change health, redefine hit volume, cause death, or delay cleanup.

## Current status

The deterministic source, motorized procedural fallback, server-authored presentation disclosure, and client-local confirmed strike/recovery, hit, locomotion, death, and stand-down poses are implemented. Imported mesh review, attack anticipation, effects, audio, cosmetic variants, and representative horde performance evidence remain pending.
