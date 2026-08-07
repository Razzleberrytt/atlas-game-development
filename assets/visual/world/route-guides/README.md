# Authored Route Guide Procedural Fallback

This VIS-0105 package adds paired client-local guide posts to the existing authored logging-road and switchback-trail segments.

## Coverage

- `LoggingRoad*` segments receive a paired high-contrast road-post silhouette.
- `SwitchbackTrail*` segments receive a paired low stone-cairn silhouette.
- Creek pieces, landmarks, objectives, mission objects, and the extraction clearing receive no route-guide presentation.
- No text labels, destination names, arrows, or future-objective hints are created.

Each route segment receives exactly two massless, non-collidable, non-touchable, non-queryable parts welded to the existing server-owned route part. The segment keeps its original transform, dimensions, collision, material, and navigation role.

## Runtime bounds

The controller uses two global workspace lifecycle connections, zero per-segment connections, zero frame loops, zero timers, zero remotes, and no server runtime changes. Streaming removal and controller shutdown destroy every client guide model.

## Remaining gates

Roblox Studio gameplay-camera readability, low-quality graphics review, terrain clipping checks, final materials, accessibility, and representative performance approval remain pending.
