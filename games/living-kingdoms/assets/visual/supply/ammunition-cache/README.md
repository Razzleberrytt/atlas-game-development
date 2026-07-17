# Authored Supply Cache Procedural Fallback

## Status

This package is a project-original, client-local procedural fallback for the authored rifle-ammunition cache in VIS-0105. It is not a canonical imported prop. Roblox Studio approval remains pending.

## Gameplay boundary

The existing server-created `3.6 x 1.8 x 2.6` BasePart remains the authoritative position, collision volume, cache identity, and ProximityPrompt parent. The server remains the sole owner of eligibility, distance, line of sight, duplicate history, carry capacity, granted rounds, and collection commit.

The local client hides only that root's rendering with `LocalTransparencyModifier` and welds a 13-part procedural supply case to it. The presentation cannot move, resize, disable collision on, or replace the authoritative root.

## Readability

Available state uses:

- a broad olive metal body;
- raised lid, side rails, latches, and carrying handle;
- a high-contrast signal band;
- an occlusion-respecting surface label reading `RIFLE AMMO`.

After the existing server sends the local operative's consumed message, the same case opens, darkens, exposes an empty tray, fades the latches and signal band, changes the label to `EMPTY`, and disables only that client's prompt. This is per-operative depletion; another player does not inherit the local consumed view.

Consumed messages are remembered before cache lookup, so a message that arrives before the cache streams in is applied when the authoritative root appears.

## Runtime bounds

- 13 presentation parts per cache, including one motorized lid;
- three global connections total;
- zero per-cache connections;
- zero frame loops;
- zero timers;
- zero new remotes;
- zero server runtime changes.

Cleanup restores the root's prior local transparency and the prompt's prior local enabled state before destroying the client presentation.

## Remaining gates

Roblox Studio gameplay-camera review, interaction-distance review, low-quality readability, representative cache-count performance evidence, final materials, effects, and audio remain pending.
