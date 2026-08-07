# Extraction Beacon Procedural Fallback

This VIS-0105 package provides a project-original client-local extraction package around the unchanged server-created `SignalPillar`. The server creates the beacon only after extraction is authoritatively unlocked, so the presentation cannot reveal a hidden extraction location.

## Readable states

- `EXTRACTION OPEN` appears during authoritative exfiltration.
- `HOLD POSITION` appears during the authoritative extraction holdout.
- `EXTRACTED` appears only after authoritative mission success.
- `EXTRACTION LOST` appears only after authoritative mission failure.
- malformed or inconsistent facts restore the primitive server beacon rather than inventing mission truth.

The fallback uses twelve non-collidable presentation parts: a center base, four landing pads, four mast fins, a crown, beacon lens, and direction panel. Geometry and text carry meaning; color is supplemental.

## Authority boundary

The client never creates extraction early, moves or resizes the server pillar, changes the extraction radius, counts operatives, starts or completes holdout, changes timers, or establishes the mission outcome. It only replaces the primitive pillar/light/marker locally after a validated visible state exists.

## Remaining gates

Roblox Studio gameplay-camera and long-distance readability, extraction-zone alignment, final materials, authored effects/audio, accessibility, and representative performance approval remain pending.
