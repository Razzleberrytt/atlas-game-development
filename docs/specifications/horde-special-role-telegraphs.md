# Living Kingdoms — Horde Special-Role Telegraphs

## Purpose

The six-role horde is visually readable, but the three consequential role effects previously disclosed themselves at the same moment they committed:

- the Choir Screamer published its scream sequence and spawned reinforcements in one evaluation;
- the Rot Bloater damaged nearby operatives as soon as its death was observed;
- the Grief Brute created phase two immediately on first-phase death.

This pass gives those effects short, server-owned warnings so the roles create fear, recognition, and positioning decisions instead of surprise damage or unexplained reinforcement spikes.

## Player-facing behavior

| Role | Warning | Consequence |
|---|---|---|
| Choir Screamer | 1.25-second yellow pulsing disc and `SCREAMER SUMMONING` countdown | five configured reinforcements spawn when the authoritative commit timestamp is reached |
| Rot Bloater | 0.85-second green disc covering the exact 20-stud damage radius and `BLOATER BURST` countdown | the existing 18 authoritative damage commits occur only at the warning commit |
| Grief Brute | 0.9-second red resurrection disc and `BRUTE REANIMATING` countdown | the existing second-phase Brute spawn occurs at commit |

Each warning has redundant shape, world-space area, text, countdown timing, and role-specific audio. Color is reinforcement, not the only signal.

## Authority boundary

`HordeExperienceService` remains the sole owner of role assignment and special consequences.

The server publishes ordinary replicated model attributes:

- `HordeSpecialKindId`
- `HordeSpecialSequence`
- `HordeSpecialStateId`
- `HordeSpecialCommitServerTimestamp`

Clients cannot request a special, select its kind, choose its origin, alter its radius, set its commit time, spawn reinforcements, apply Bloater damage, or create Brute phase two. No new remote exists.

The Bloater warning radius is sourced directly from `HordeExperienceConfig.Roles.Bloater.DeathBurstRadiusStuds`; presentation cannot drift from the authoritative damage radius.

## Runtime bounds

- Consequences ride the existing 10 Hz horde evaluation pass; no delayed tasks or new server connections.
- One client frame loop and two folder lifecycle connections serve every enemy.
- Zero per-enemy attribute connections.
- A fixed pool of 16 telegraph slots is created once at startup.
- At most 128 enemy models are tracked, covering the current 96-enemy absolute living cap plus bounded corpse overlap.
- The existing `EnemyAudioController` frame loop and eight-Sound pool own warning audio; no second hostile-audio owner is created.
- No raycasts, particles, tweens, per-event Sounds, or per-event Instances.

## Failure and lifecycle behavior

- Killing a Screamer during its warning cancels the pending reinforcement commit because dead records cannot resolve the living Screamer action.
- Bloater and first-phase Brute warnings continue from their anchored corpses and commit before the five-second corpse cleanup window.
- Phase-two Brutes do not create a third phase.
- Joining during an active warning presents the remaining countdown; joining after commit does not replay stale warnings.
- If the fixed visual pool is saturated, the slot with the earliest commit is reused; gameplay still commits authoritatively.
- Teardown disconnects the three client connections, destroys the fixed presentation folder, and clears tracking state.

## Acceptance gates

Automated:

- StyLua formatting
- Selene with zero findings
- complete Living Kingdoms Lune fixture suite
- Rojo build
- configuration fixture for timings, exact radius, vocabulary, and caps
- source audit for authority, fixed pools, shared audio ownership, and lifecycle shape

Roblox Studio remains required to judge:

- isometric visibility on bright and dark terrain;
- whether the countdown feels actionable without making specials harmless;
- exact Bloater radius comprehension;
- overlapping warnings under dense waves;
- role-specific warning audio mix;
- late join, corpse cleanup, and two-client synchronization;
- representative 24/96-hostile performance.
