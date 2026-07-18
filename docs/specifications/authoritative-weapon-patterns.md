# Living Kingdoms — Authoritative Weapon Patterns v1

## Purpose

Make the selectable firearms differ in server-owned firing behavior, not only balance values and presentation.

## Patterns

- Blackwater Support LMG: one target per accepted round.
- Morrow Breach Shotgun: the primary target plus up to three currently sighted hostiles inside a bounded close-range cone.
- Longwatch Sniper Rifle: the primary target plus up to one currently sighted hostile aligned behind it.
- Vigil Service Pistol: one target per accepted round.
- Razor Compact SMG: one target per accepted round.

## Authority

The client supplies no aim vector, spread seed, secondary target, damage multiplier, impact position, penetration result, or extra ammunition request. Pattern selection consumes the same bounded server-derived sight facts and line-of-sight results already used by primary automatic targeting.

Primary hits retain the existing FirearmHitResolver identity contract. Secondary impacts use derived server-only ShotIds, a dedicated reduced-damage DamageResolver path, and the existing revisioned EnemyDirectorService health commit.

## Bounds

- zero additional raycasts;
- zero new remotes;
- zero extra ammunition expenditure per trigger;
- maximum three shotgun secondaries;
- maximum one sniper secondary;
- secondary damage never exceeds primary damage;
- one muzzle flash, one casing or shell, one recoil event, and one audio report per accepted trigger.

## Presentation

The existing ShotFired disclosure may include up to three already committed secondary impacts. Clients validate the bound and may draw additional tracer and impact cues without replaying muzzle flash, casing ejection, recoil, or audio.

## Acceptance

Automated acceptance requires StyLua, Selene, the complete Lune fixture suite, and a Rojo build. Studio remains required to tune cone readability, penetration readability, crowd lethality, ammunition pressure, and performance under representative horde density.
