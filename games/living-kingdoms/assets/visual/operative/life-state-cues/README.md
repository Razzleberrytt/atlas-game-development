# Operative life-state cue fallback

This source package documents the project-original procedural world cues used by `OperativeLifeWorldPresentationController`.

## Truth source

The client reads only existing server-disclosed Player attributes for operative identity, life state, solo-recovery status, and active revive target/progress. It does not infer life state from Humanoid health, movement, animation, avatar posture, or local input.

## Cue vocabulary

- `Downed`: rescue-cross geometry plus explicit `DOWNED` text.
- `Reviving`: rescue-cross geometry plus authoritative percentage text and a progress bar.
- `SoloRecovery`: upward-chevron geometry plus explicit `SELF RECOVERY` text.
- `Dead`: X geometry plus explicit `KIA` text.
- `Alive` or malformed/unknown life state: no world cue.

Critical states use geometry plus explicit text rather than color alone. Palette changes are supplemental. The BillboardGui is occlusion-respecting (`AlwaysOnTop = false`) and range-bounded so it does not create a through-world information beacon.

## Runtime bounds

Each visible cue uses exactly two massless, non-collidable, non-touchable, non-queryable parts welded to the replicated torso. The controller owns two global player lifecycle connections and two connections per player, with zero frame connections, timers, new remotes, or server changes.

## Authority boundary

The cue has zero gameplay authority. It cannot change operative identity, health, life state, revive progress, movement, collision, network ownership, weapons, ammunition, objectives, mission state, or cleanup ownership.

## Remaining gates

Roblox Studio gameplay-camera readability, avatar-scale coverage, low-quality rendering, representative 1/2/4-operative performance, canonical operative rig integration, and production visual approval remain pending.
