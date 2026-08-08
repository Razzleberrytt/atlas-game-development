# BA-005 WorldPath Reconstruction Contract

The recovered Studio `Workspace/WorldPath` is now represented by a source-managed, **inert** reconstruction contract:

`games/living-kingdoms/src/shared/Config/RecoveredWorldPathConfig.luau`

## Why it is canonicalized

The original place contains 189 `Part` instances named `PathSegment_1` through `PathSegment_189`.

Property extraction proved every segment shares the same authored properties:

- size: `6 x 0.2 x 6` studs
- X center: `0`
- Y center: `0.1`
- identity rotation (`rotation_id = 2`)
- material enum value: `880`
- color bytes: `100, 95, 90`
- transparency: `0`
- reflectance: `0`
- shape enum value: `1`
- anchored: `true`
- collision/query/touch: `true`
- cast shadow: `true`

Only the Z center changes.

The first recovered center is:

`(0, 0.1, -2.9629626274108887)`

The final recovered center is:

`(0, 0.1, -1500)`

Linear interpolation across the 189 centers differs from the recovered float values by at most approximately `0.000104` studs. The contract therefore stores one route definition plus the original segment count and a `0.00011`-stud evidence tolerance instead of promoting 189 legacy Parts into canonical gameplay data.

## Source hold

The contract explicitly declares:

- `SourceHold = true`
- `RuntimeEnabled = false`

No current runtime module requires it.

`route.world.primary` remains preserved/inactive in the world-content registry until the route is reconciled with the modern operation world and its much smaller current coordinate envelope.

## Why it is not activated yet

The recovered authored world uses a much larger coordinate system than the current operation foundation. For example, recovered `WorldStructures` extend beyond ±2,800 studs and below Z = -3,100, while the current operation world is designed around a ±640-stud playable extent.

Activating the old route at absolute legacy coordinates before that coordinate/lifecycle decision would be technically faithful but architecturally wrong.

The next safe step is to define the **legacy-to-canonical placement policy** for recovered authored groups, then render reconstruction data behind an explicit hold/preview boundary before any live cutover.
