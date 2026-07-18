# Floating Damage Text v1

Status: source-complete; Roblox Studio visual acceptance pending.

## Goal

Make every locally authored, server-confirmed damaging firearm hit feel immediately legible without moving any combat authority to the client.

## Player-facing behavior

- A bold integer appears at the authoritative impact world position for each damaging shot fired by the local operative.
- The number pops, rises, fans slightly sideways, and fades in under one second.
- Baseline damage is warm ivory; upgraded damage escalates to orange and then red.
- Rapid automatic fire can occupy a fixed pool of at most 18 simultaneous labels. When saturated, the oldest label is recycled.
- Misses, blocked shots, rejected damage, squadmate shots, duplicate ShotIds, malformed values, and off-screen impacts do not create a visible number.

## Authority boundary

- `DamageResolver` remains the only damage calculator.
- `OperativeCombatRuntimeService` copies `damageResolution.damageEvent.damageAmount` into the existing server-to-client `ShotFired` presentation disclosure only when an authoritative damage event exists.
- The client never infers damage from weapon configuration, enemy health, progression state, or target appearance.
- No new remote, client request, health mutation, death decision, reward decision, XP change, loot creation, or targeting behavior is introduced.

## Runtime bounds

- One fixed `ScreenGui`.
- Eighteen preallocated `TextLabel`/`UIScale` pairs.
- One existing combat-presentation connection.
- One `RenderStepped` connection.
- No per-hit instances, delayed tasks, spawned loops, or unbounded ShotId history.

## Acceptance gates

Automated source and build validation must pass before merge. Roblox Studio review remains required for:

- readability over bright, dark, and blood-heavy terrain;
- sustained automatic-fire overlap against dense hordes;
- desktop and touch viewport scaling;
- camera replacement, respawn, revive, and extraction transitions;
- final rise, fan, color, and duration tuning.
