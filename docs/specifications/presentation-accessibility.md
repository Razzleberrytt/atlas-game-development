# Presentation Accessibility — Camera Shake and Blood Comfort Settings

## Status

Implemented as the HROI-0104 accessibility acceptance item ("accessibility
toggles for camera shake and blood intensity"). Client-local presentation
preference only; Roblox Studio visual review remains the acceptance gate for
panel placement, touch ergonomics, and readability at every level.

## What the player gets

A small fixed **FX** button (bottom-left) opens a **PRESENTATION COMFORT**
panel with one text-labeled cycle button per setting:

- **CAMERA SHAKE: FULL → REDUCED → OFF**
- **BLOOD: FULL → REDUCED → OFF**

Each activation advances one level and wraps. The current level is always
written as text on the button, so the control never depends on color or audio
alone. Both settings default to **FULL** so reviews and screenshots judge the
authored presentation.

## What each level does

| Setting | FULL | REDUCED | OFF |
|---|---|---|---|
| Camera shake | Authored magnitude | 40% magnitude | No camera offset at all |
| Blood | Authored bursts and pools | ~45% particle counts and pool diameter | No blood particles or pools |

Non-gore combat readability is deliberately preserved at every level: hit and
kill flash highlights, kill/XP billboards, hit markers, floating damage text,
and all audio cues are unaffected by these settings.

## Authority and trust boundary

- Levels live in one client-local session store
  (`PresentationAccessibilityState`); there is no remote, no replication, no
  persistence, and no server awareness of the chosen level.
- Scales are configuration-driven (`PresentationAccessibilityConfig`) and may
  only attenuate: FULL is exactly `1`, OFF is exactly `0`, REDUCED is strictly
  between, and fixtures reject any scale outside `[0, 1]`.
- Consumers apply the scale at effect time inside the existing bounded
  presentation owners (`HordeEffectsController` shake/death pools,
  `EnemyImpactPresentationController` hit/kill bursts). No new connection,
  scheduler, remote, or per-frame work is added by the settings themselves.
- No level can change damage, health, death, targeting, XP, loot, threat, or
  any other consequential gameplay fact, and no level reveals information a
  full-intensity client would not receive.

## Runtime budget

- One ScreenGui with fixed instances created at startup.
- Three `Activated` connections (FX toggle plus one per setting) and one
  plain-Lua change listener; zero RenderStepped/Heartbeat connections.
- `stop()` disconnects everything and destroys the ScreenGui.

## Validation

- `PresentationAccessibilityConfig.test.luau` — bounded attenuation-only
  scales, FULL default, complete wrap-around cycle order.
- `PresentationAccessibilitySourceAudit.test.luau` — the store and panel stay
  client-local and inert; effects/impact controllers honor the scales; flash
  readability survives every blood level; bootstrap wiring.
- `EnemyImpactPresentationSourceAudit.test.luau` — updated for the scaled
  emit path while keeping the existing connection, particle, and authority
  budgets.

## Studio acceptance checklist

- [ ] FX button and panel are reachable and readable with mouse and touch and
      do not cover the ammunition HUD, threat readout, or upgrade cards.
- [ ] REDUCED and OFF visibly change shake and blood while hit/kill flashes,
      damage text, and markers remain readable.
- [ ] Settings survive respawn (ResetOnSpawn is false) and reset to FULL on a
      fresh session.

## Explicit exclusions

- No persistence of the chosen levels across sessions (would require P11
  ownership).
- No server-driven or squad-wide settings.
- No additional comfort settings in this slice; new settings require their own
  configuration entry, scales, and audit coverage.
