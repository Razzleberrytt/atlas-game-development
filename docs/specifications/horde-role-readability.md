# Horde Role Readability

## Purpose

The horde runtime already owns six mechanically distinct roles, but the procedural fallback presents them through one Exclusion Walker shell. Highlights and a few whole-model scale calls are not enough to communicate danger under an elevated isometric camera, and scaling the enemy model risks changing the authoritative root footprint.

This pass gives every existing role a distinct presentation signature while preserving one shared 18-component shell.

## Role signatures

- **Hollow Infected** — baseline rotting infantry silhouette.
- **Razor Runner** — narrow frame, long limbs and claws, forward sprint posture, fast stride, orange eye.
- **Grave Crawler** — low forward torso, reduced legs, oversized forelimbs and claws, purple eye.
- **Choir Screamer** — tall head, sensor and spine, raised arms, bright yellow beacon and canister.
- **Rot Bloater** — swollen torso and hip, enlarged pressure canister, green palette and slow gait.
- **Grief Brute** — broad armored torso, oversized shoulders, forearms and claws, heavy forward posture and red eye.

## Authority boundary

`HordeRolePresentationConfig` contains presentation-only component proportions, RGB tuples, eye-light bounds, stride timing, and base-pose offsets. The stateless `HordeRolePresentationService` applies those values only to massless, non-colliding, non-queryable parts and the five presentation motors inside `ExclusionWalkerPresentation`. Both `EnemyPresentationService` and `HordeExperienceService` invoke the same applicator so the correct role is resolved whether the shell or server-authored role arrives first. `EnemyPresentationController` keeps its existing single frame loop and reads only a bounded `HordeRoleStrideScale` attribute before composing its existing behavior poses from the role-adjusted motor bases.

The authoritative `HumanoidRootPart` remains `3 × 5.6 × 3`. The pass changes no movement speed, health, damage, targeting, attack timing, spawning, rewards, network ownership, remotes, or server combat decisions.

## Lifecycle and performance bounds

- one existing server `EnemyEntities.ChildAdded` listener;
- one existing client `RenderStepped` connection;
- a stateless role applicator with zero connections;
- zero per-enemy attribute or property connections;
- zero new parts, motors, remotes, timers, raycasts, or particles;
- the existing 18 components and five presentation motors remain canonical;
- all component multipliers are constrained to 0.55–1.60;
- role posture stays within one stud of the authoritative root;
- the client accepts only a 0.5–2.0 stride scalar.

## Acceptance

Automated acceptance requires StyLua, Selene, the complete Lune fixture suite, and a Rojo build. Roblox Studio remains required to judge isometric silhouette separation, color-vision redundancy, occluded-highlight balance, animation clipping, and representative 24/96-hostile performance.
