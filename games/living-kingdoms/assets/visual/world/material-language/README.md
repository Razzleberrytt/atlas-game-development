# Blackwater world material language

VIS-0105 planning contract for consistent procedural and future authored world presentation.

## Semantic roles

- Infrastructure metal and signal surfaces
- Security metal and signal surfaces
- Camp fabric and dormant-fire structure
- Crossing wood and washed-out warning surfaces
- Overlook metal and stone surfaces

The runtime definitions live in `src/shared/Config/WorldMaterialLanguageConfig.luau` and are consumed by the safe landmark accent factory.

## Rules

- Materials and colors may improve silhouette, hierarchy, and environmental readability only.
- A material must not encode hidden mission state, future extraction, enemy presence, loot, or interaction eligibility.
- Geometry plus material must carry meaning; color alone is not sufficient.
- No numeric asset IDs are accepted in this planning package.
- Production replacements still require rights, fallback, accessibility, performance, and Studio approval.

This package does not change terrain, collision, navigation, lighting, objectives, extraction, or server authority.
