# Confirmed Screamer Interrupt Reward

## Goal

Turn the Choir Screamer's interrupt window into a real tactical reward, not only a presentation beat. A successful kill during the server-owned reinforcement windup now grants **10 bonus shared Field XP** on top of the ordinary 20-XP death award.

## Player-facing result

- ordinary Screamer death: **+20 Field XP**
- confirmed reinforcement interruption: **+30 total Field XP**
- the existing `SUMMON INTERRUPTED` billboard displays the combined total
- the shared XP bar and level-up flow consume the bonus immediately
- the entire squad receives the same run progression; the interrupt creates no kill-stealing incentive

The bonus is deliberately half an ordinary kill. It rewards awareness without letting one special enemy erase the four-kill first-upgrade pacing target.

## Authority and duplicate defense

`HordeExperienceService` remains the owner of Screamer windup and interruption state. `ScreamerInterruptRewardService` reads only server-authored facts:

- `HordeRoleId == horde.role.screamer`
- authoritative enemy life state is `Dead`
- confirmed hit sequence is positive
- special kind is `ScreamerReinforcement`
- special state is exactly `Interrupted`
- special sequence is a positive integer
- `CombatEntityId` is non-empty

The service accepts no client request and owns no remote. It derives `screamer-interrupt:<CombatEntityId>:<SpecialSequence>` and commits the configured amount through the existing idempotent `RunProgressionService.awardFieldIntel` boundary. Startup-baseline suppression and per-model sequence tracking prevent pre-existing corpses, repeated scans, and corpse overlap from duplicating the award.

## Runtime bounds

- one Heartbeat connection
- one scan every 0.1 seconds
- at most 64 inspected enemy models per scan
- zero per-enemy connections
- zero delayed tasks
- zero raycasts, path requests, damage writes, ammunition writes, or enemy spawns
- stale model history is removed when the model leaves the bounded enemy folder

## Presentation boundary

`HordeDeathPunctuationConfig.XpBonus` is copy-only metadata. `HordeEffectsController` adds that value to the already replicated base role XP solely for the death billboard. The client cannot award XP, change the bonus, report an interruption, or establish any combat fact.

## Validation

Automated fixtures lock the 10-XP tuning, 0.1-second cadence, 64-model ceiling, exact authoritative attributes, deterministic event identity, existing duplicate defense, bootstrap order, absence of client mutation surfaces, and equality between the server reward and presentation copy.

Studio validation should confirm:

1. a Screamer killed before windup receives only the ordinary 20 XP
2. a Screamer killed during windup receives 30 total XP
3. a completed scream receives no interruption bonus
4. corpse cleanup and repeated scans cannot duplicate the bonus
5. the combined billboard remains readable from the isometric camera
6. the extra bounded scan does not measurably affect the representative horde load
