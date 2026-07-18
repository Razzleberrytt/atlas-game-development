# Weapon-Aware Automatic Target Selection

## Purpose

The automatic-combat runtime already gives the Morrow Breach Shotgun a bounded cone cleave and the Longwatch Sniper Rifle one bounded rear pierce. Before this pass, every firearm still selected the closest active threat, otherwise the closest valid hostile. That generic primary choice often pointed the shotgun away from clusters and the sniper away from lineups, leaving their server-authoritative firing identities underused.

This pass changes only primary-target ranking. It does not change visibility, line of sight, weapon range, cadence, ammunition, hit validation, damage, secondary-target geometry, enemy discovery, or client input.

## Selection policy

1. Build the same server-derived candidate set and validate primaries through `TargetCandidateValidator`.
2. If any valid candidate is actively threatening this exact operative, exclude every non-threatening candidate from pattern optimization.
3. For cone-cleave and line-pierce weapons, evaluate each remaining valid primary through the existing pure `WeaponPatternResolver`.
4. Prefer the primary producing the greatest bounded secondary-impact count.
5. Break equal utility by horizontal distance, then lexical entity ID.
6. If no primary produces a secondary opportunity, delegate to `TargetCandidateSelector` exactly as before.
7. Single-target weapons always delegate directly to `TargetCandidateSelector`.

The new selection reasons are `ThreateningPatternUtility` and `ValidPatternUtility`. They describe why a primary was chosen but grant no additional authority or presentation surface.

## Authority boundary

`WeaponTargetSelector` consumes only caller-provided server facts. It performs no raycasts, enemy discovery, firing, ammunition mutation, hit resolution, damage, health commit, networking, timing, or presentation. The client still supplies no target, aim direction, spread seed, lineup, cluster, or utility claim.

Pattern utility excludes candidates that are not both hostile entity-kind and hostile relationship. The eventual shot still passes through `AutomaticFireResolver`, `FirearmHitResolver`, `DamageResolver`, revisioned enemy-health commits, and the existing pattern-impact validation.

## Performance bound

Only candidates that pass the existing primary validator can be scored. Because production line of sight is disclosed only for the nearest `MaximumLineOfSightRaycastsPerEvaluation` candidates, the number of possible utility primaries remains bounded by that existing budget, currently eight per operative per evaluation. Pattern facts reuse the already-built sight candidate set and add no raycasts.

## Expected effect

- Shotgun operatives should turn toward dense close-range groups more often, making one shell visibly clear space.
- Sniper operatives should choose front targets with a rear hostile aligned more often, making pierce opportunities occur naturally.
- Threatening enemies remain more important than non-threatening clusters or lineups.
- LMG, SMG, pistol, legacy firearm, and pattern weapons without a current opportunity behave exactly as before.

## Acceptance

Automated acceptance requires focused deterministic fixtures, source/authority audits, StyLua, Selene, the complete Living Kingdoms Lune fixture suite, and a Rojo build. Roblox Studio remains required to judge target-switch readability, shotgun cluster frequency, sniper lineup frequency, and whether automatic camera-facing changes feel intentional rather than erratic.
