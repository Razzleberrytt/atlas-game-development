# HROI-0106 immediate loot — Studio acceptance checklist

Automated validation covers deterministic drop resolution, healing rules, server authority, connection bounds, full fixture compatibility, and Rojo build. This checklist records the remaining Roblox Studio evidence required before calling the loot presentation production-approved.

## Solo session

- Kill at least 20 Exclusion Walkers and confirm ammunition, field dressing, field intel, and no-drop outcomes all occur.
- Confirm pickups appear at corpse positions and remain readable from the elevated isometric camera.
- Confirm each pickup disappears immediately after a successful claim.
- Confirm an unclaimed pickup expires after approximately 18 seconds.
- Confirm a full-ammunition operative cannot waste an ammunition bundle.
- Confirm a full-health operative cannot waste a field dressing.
- Confirm field dressing healing updates the canonical operative health presentation.
- Confirm field intel increases shared Field XP without incrementing squad kills.
- Confirm a collected or expired pickup never returns after corpse cleanup.

## Two-client session

- Confirm both clients see the same server-owned pickup.
- Confirm only one player can successfully claim a pickup.
- Confirm a pickup rejected for one player remains available for the other player.
- Confirm collection beyond eight studs is rejected even if the prompt was previously visible.
- Confirm a downed or dead operative cannot collect loot.
- Confirm field intel updates the same shared Field XP and pending upgrade state for both clients.

## Pressure and cleanup

- Reach the 24-living-enemy ceiling while allowing temporary drops to accumulate.
- Confirm the active drop count never exceeds 20.
- Confirm corpse cleanup does not delete a valid drop early.
- Confirm loot expiry and collection do not produce console errors or leaked prompts.
- Record client and server frame cost with 24 living enemies, several corpses, and 20 active drops.

No Studio approval is claimed until these checks are completed on representative hardware.
