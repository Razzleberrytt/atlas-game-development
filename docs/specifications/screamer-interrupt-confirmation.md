# Living Kingdoms — Screamer Interrupt Confirmation

## Purpose

The Choir Screamer already exposes a 1.25-second server-owned `SCREAMER SUMMONING` warning. Killing it during that windup cancels the pending five-enemy reinforcement commit, but the death-feedback layer currently renders the same `CHOIR SILENCED` punctuation used for an ordinary Screamer kill. The player therefore receives no explicit confirmation that the dangerous summon was successfully interrupted.

This pass makes that existing counterplay result unmistakable without adding rewards, a new remote, or another presentation owner.

## Authoritative behavior

`HordeExperienceService` remains the sole owner of the pending Screamer reinforcement. When a Screamer dies while `pendingSpecialKindId` is `ScreamerReinforcement`, the service:

- clears the pending consequence and commit timestamp so reinforcements cannot spawn;
- preserves the existing replicated special kind;
- changes the existing replicated special state from `Windup` to `Interrupted`; and
- leaves the special sequence unchanged so warning audio cannot replay.

The existing telegraph controller already presents only `Windup`. Its active fixed-pool slot therefore disappears when the authoritative state becomes `Interrupted`, while the durable corpse attribute remains available to the death-feedback owner.

## Player-facing behavior

- A Screamer killed during the summon windup displays `SUMMON INTERRUPTED` above the existing XP line.
- Its death uses a stronger bounded yellow punctuation definition than a normal Screamer kill.
- A Screamer killed outside the windup continues to display `CHOIR SILENCED`.
- Bloater and Brute death punctuation remain unchanged.
- Camera-shake and blood intensity continue to honor the existing client-local presentation comfort settings.

The death-feedback controller accepts either the still-replicated `Windup` state or the durable `Interrupted` state together with `ScreamerReinforcement`. This covers replication ordering without predicting a cancellation: both facts originate from the authoritative special state machine, and a committed summon is never classified as interrupted.

## Authority and runtime bounds

- No new remote, request, event stream, reward, damage path, health or ammunition mutation, targeting change, spawn path, sound, particle, task, tween, or frame connection is added.
- The existing special kind, state, sequence, and commit timestamp attributes remain the complete contract.
- The existing death billboard, blood-pool Part, Debris cleanup, camera-shake channel, and accessibility attenuation are reused.
- No additional object is created per death.
- The interrupt definition remains inside the existing death-punctuation caps: shake at or below `0.5`, duration at or below `0.35` seconds, pool diameter at or below ten studs, and billboard lifetime at or below two seconds.
- Unknown, missing, idle, or committed special facts fall back to ordinary Screamer punctuation.

## Acceptance gates

Automated:

- pinned StyLua formatting;
- Selene with zero findings;
- complete Living Kingdoms Lune fixture suite;
- Rojo build;
- configuration coverage for `SUMMON INTERRUPTED` and stronger-but-bounded intensity;
- source audit proving server-owned cancellation, preserved kind, `Interrupted` state, unchanged sequence, no reinforcement commit, telegraph deactivation, accessibility preservation, and zero new authority.

Roblox Studio remains required to judge:

- readability alongside the disappearing summon warning;
- whether the stronger punctuation feels rewarding without obscuring combat;
- warning-audio cancellation and overlap with the death cue;
- FULL, REDUCED, and OFF comfort-setting behavior;
- dense-kill overlap with massacre crescendo and pattern-hit punctuation;
- two-client consistency and representative 24/96-hostile performance.
