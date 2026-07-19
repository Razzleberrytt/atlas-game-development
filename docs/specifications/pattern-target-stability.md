# Pattern target stability

Status: implemented pending Roblox Studio feel review.

## Problem

Weapon-aware automatic targeting reevaluates every combat pass. Before this pass,
two shotgun cluster primaries or sniper lineup primaries with equal pattern utility
were ordered only by exact horizontal distance and lexical entity ID. Small enemy
movement could therefore make equivalent targets alternate, producing unnecessary
server target disclosures and visible facing changes even though combat value had
not improved.

## Server behavior

`WeaponTargetSelector` receives the operative's current authoritative target ID.
For cone-cleave and line-pierce weapons, it first computes the same threat cohort,
validation results, and bounded secondary-impact utility used by the existing
weapon-aware selector.

The current target is retained only when all of the following remain true:

- it is still a valid primary under `TargetCandidateValidator`;
- it remains inside the same absolute active-threat cohort as the best candidate;
- it exposes exactly the same number of bounded secondary impacts as the best
  candidate; and
- its horizontal distance is no more than six studs farther than the newly ranked
  best candidate.

A candidate with greater pattern utility switches immediately. A valid active
threat switches immediately over a non-threatening current target. Death,
untargetability, invisibility, lost line of sight, range failure, empty ammunition,
or disabled weapon readiness prevents retention immediately.

Single-target firearms and pattern firearms with no secondary opportunity continue
to delegate exactly to `TargetCandidateSelector`; this pass adds no generic lock-on
or time-based hold. Retention is recalculated from current server facts every combat
pass and contains no minimum duration, cooldown, grace timer, or stale target cache.

## Authority and runtime bounds

- Server-owned current target state is the only added input.
- No client target, aim vector, preference, timing, or hysteresis request exists.
- No new remote, raycast, timer, task, damage path, ammunition mutation, health
  commit, reward, or presentation owner is added.
- Candidate discovery and the eight-candidate LOS budget are unchanged.
- Utility still reuses `WeaponPatternResolver`, the same bounded resolver used for
  accepted shotgun and sniper shots.
- Target disclosures remain deduplicated by the existing runtime owner.

## Validation

Automated coverage must prove equivalent-utility retention inside the allowance,
switching beyond the allowance, immediate switching for greater utility and active
threats, invalid-current rejection, and unchanged single-target fallback behavior.

Roblox Studio remains required to judge whether shotgun and sniper facing appears
steadier without feeling sluggish during fast horde movement.
