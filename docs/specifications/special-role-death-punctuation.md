# Living Kingdoms — Special-Role Death Punctuation

## Purpose

The horde death-feedback owner already created one blood pool, one XP billboard, and bounded camera shake for every server-confirmed enemy death. Special roles nevertheless died with the same generic `ROLE +XP` copy as ordinary infected, so killing a Screamer, triggering a Bloater death burst, breaking a Brute's first phase, or finally ending its second phase lacked distinct payoff.

This pass makes those high-value deaths unmistakable without adding a reward system, a new presentation owner, or more objects per death.

## Player-facing behavior

| Authoritative role fact | Billboard | Existing-channel emphasis |
|---|---|---|
| Choir Screamer | `CHOIR SILENCED` | yellow role color, six-stud blood pool, stronger shake |
| Rot Bloater | `ROT BURST ARMED` | green role color and pool, reinforced warning that the death burst is still pending |
| First-phase Grief Brute | `BRUTE PHASE BROKEN` | larger red pool and heavy shake before the existing reanimation telegraph |
| Second-phase Grief Brute | `BRUTE ERADICATED` | largest bounded pool, longest billboard, and strongest bounded shake |

The existing XP amount remains visible on the second billboard line. Ordinary infected, Runners, and Crawlers retain the previous role-name-and-XP presentation.

## Authority boundary

The controller reacts only after the canonical replicated enemy life-state attribute becomes `Dead`.

Role selection comes from the server-authored `HordeRoleId`. Brute phase distinction comes from the existing `CombatEntityId`: the authoritative second-phase spawn uses the `brute-phase2` prefix, and the client only maps that replicated identity to presentation copy.

The pass adds no server edit, remote, client request, kill report, damage path, XP mutation, loot mutation, health mutation, ammunition mutation, targeting decision, or combat modifier.

## Runtime and object bounds

`HordeEffectsController` remains the sole owner of this layer and reuses its existing lifecycle:

- the existing life-state attribute connection per tracked enemy remains the only death trigger;
- one existing blood-pool `Part` is created per death and removed through `Debris`;
- one existing billboard attachment, `BillboardGui`, and `TextLabel` are created per death and removed through `Debris`;
- no additional per-death object is introduced;
- no particle emitter, sound, task, tween, remote, or new frame connection is introduced;
- special shake magnitude is capped at `0.5`, duration at `0.35` seconds, blood diameter at ten studs, and billboard lifetime at two seconds;
- unknown or missing role/identity facts fail closed to the existing generic presentation.

## Acceptance gates

Automated:

- pinned StyLua formatting;
- Selene with zero findings;
- complete Living Kingdoms Lune fixture suite;
- Rojo build;
- configuration fixture locking copy, phase distinction, bounded intensities, and fail-closed behavior;
- source audit locking authoritative replicated facts, reused objects, bounded cleanup, and zero gameplay authority.

Roblox Studio remains required to judge:

- billboard readability from the isometric camera;
- whether `ROT BURST ARMED` remains readable alongside the Bloater radius telegraph;
- whether first- and second-phase Brute deaths are clearly distinct;
- shake comfort on desktop and touch devices;
- overlap with massacre crescendo and pattern-hit punctuation during dense kills;
- representative 24/96-hostile performance.
