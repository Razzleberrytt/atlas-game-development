# Horde Vertical Slice — Single Source of Truth

## Why

The horde vertical slice grew several parallel implementations of progression:
`HordeExperienceService` mirrored Field XP and levels, ran its own upgrade
system on a second `HordeNetwork.ChooseUpgrade` remote, and spawned its own
`HordeLoot` (ammo, medical, adrenal surge, weapon overcharge) with per-player
duplication — alongside the canonical `RunProgressionService` and
`EnemyLootService`. Two client HUDs (`RunProgressionHUDController` and
`HordeHUDController`) each drew an XP bar and an upgrade overlay, wired to
different remotes. This stabilization pass consolidates ownership so the core
loop is predictable, playable, balanceable, and testable.

## Canonical ownership

| Concern | Sole owner | Surface |
| --- | --- | --- |
| Field XP, levels, XP from confirmed kills | `RunProgressionService` | `ProgressionNetwork.State` / `ReadState` |
| Upgrade offers, selection validation, combat-modifier publication | `RunProgressionService` | `ProgressionNetwork.ChooseUpgrade` (the only upgrade remote) |
| Operation-scoped upgrade stacks and future per-operative relic/effect state | `RunBuildService` | Server-only; no client mutation surface |
| Enemy ammunition loot (7% common / 1% rare / 92% none, one roll per death) | `EnemyLootService` | `EnemyLootDrops` folder, `AmmunitionSupplyResolver` |
| Horde spawning, pressure, enemy roles/behaviour, threat, massacre streak, event feed | `HordeExperienceService` | `HordeNetwork.State` |
| Unified combat HUD | `HordeHUDController` | reads the sources above + player attributes |

## What `HordeExperienceService` no longer does

Removed: XP/level ownership and mirroring, the upgrade system and its
`HordeNetwork.ChooseUpgrade` remote, all loot (`HordeLoot`), healing (bloodlust,
trauma kit, second-wind recovery), ammunition grants (ammo scrounger, adrenal
surge), and weapon overcharge. Retained: every enemy role (Infected, Runner,
Crawler, Screamer, Bloater, Brute), the Screamer reinforcement wave, the Bloater
authoritative death burst, the Brute second phase, threat tracking, and the
non-rewarding massacre-streak display.

## Unified HUD data flow

`HordeHUDController` is the single combat HUD:

- `HordeNetwork.State` → threat, hostile count, massacre streak, horde event feed.
- `ProgressionNetwork.State` + `ReadState` → one XP bar, Field Level, and the one
  upgrade overlay. Upgrade buttons submit one offered ID via
  `ProgressionNetwork.ChooseUpgrade`; the server revalidates offer, cap, and shape.
- Player attributes (`LK_P3_*`, `LK_HUD_*`) → health, ammunition, mission, revive.

`RunProgressionHUDController` is preserved as reusable code but is no longer
initialized, so there is exactly one XP bar and one upgrade overlay.

## Regression protection

`HordeVerticalSliceSourceAudit`, `RunProgressionSourceAudit`,
`EnemyLootSourceAudit`, and `P5IntegrationValidation` fail if a second service
grants XP, `HordeExperienceService` regains upgrades/loot/healing/ammo/overcharge,
a second upgrade remote reappears, both HUD controllers start, or the committed
remote surface drifts.

## Studio validation

The consolidation is validated by the full automated suite (StyLua, Selene, all
Lune fixtures, Rojo build). A live Studio play session of the pre-branch build
confirmed the shared substrate this PR builds on: clean server and client
bootstrap with no errors, all enemy roles spawning to the per-operative cap
(peak 24), the threat/HUD systems rendering, and — as direct evidence of the
duplication removed here — **both** `HordeNetwork.ChooseUpgrade` and
`ProgressionNetwork.ChooseUpgrade` present simultaneously. The branch was not
Rojo-synced into Studio, so the single-source behaviours are enforced by the
audits above; see the manual checklist in the pull request for post-sync
confirmation.
