# Landmark silhouette accents

Project-original VIS-0105 procedural fallback for five always-present, non-mission-dependent Blackwater landmarks.

## Covered landmarks

- Ranger Station: paired roof-edge rails and two radio-mast signal bands.
- Military Roadblock: checkpoint-cabin frame accents and crossed emergency-lamp fins.
- Campground: paired tent ridges and two muted dead-fire structure bars.
- Creek Crossing: washed-out warning braces and paired fallen-tree bands.
- Rocky Overlook: guardrail sleeves and paired cliff-edge bands.

## Bounds

- Four client-only parts per covered landmark except Military Roadblock, which uses six.
- Twenty-two parts total when all five landmarks are present.
- Every part is massless, non-collidable, non-touchable, non-queryable, and welded to an existing authored anchor.
- Two global workspace lifecycle connections and zero per-landmark connections.
- No new lights, labels, arrows, billboards, sounds, particles, timers, frame loops, remotes, or server runtime changes.

## Material language

All accent colors and materials come from `WorldMaterialLanguageConfig`. The shared roles distinguish infrastructure, security, camp, crossing, and overlook surfaces without encoding destination, objective, extraction, or enemy information.

## Exclusions

The Forest Service Lookout, extraction clearing, relay console, caches, routes, enemies, and all mission-dependent objects are intentionally outside this package.

## Authority

The server-authored landmark models continue to own geometry, collision, spawn placement, environmental lights, navigation, and world lifecycle. This client package may only attach and remove presentation geometry.

Roblox Studio gameplay-camera, terrain-clipping, low-quality graphics, accessibility, and performance approval remain pending.
