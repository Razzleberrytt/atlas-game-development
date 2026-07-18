# Exclusion Walker Audio — AUD-0103

## Goal

Give the standard hostile audible alert, windup, strike, hit, and death
feedback — the five cues the visual production track recommends for VIS-0103 —
without adding any client authority, per-enemy Sound instances, or a horde
cacophony, and keep it audible under the fixed overhead isometric camera.

## Behaviour

- `EnemyAudioController` (client) reads the same replicated server-authored
  presentation attributes the walker pose and impact controllers already use
  (`EnemyPresentationBehaviorStateId`, `EnemyPresentationLifeStateId`, and the
  windup/attack/hit sequences) on one frame connection.
- **Alert** plays when a walker transitions from `Roaming` or `StandDown` into
  `Pursuing` — the moment it acquires the squad.
- **Windup** plays when the windup sequence advances, reinforcing the existing
  cancelable pose telegraph before a strike.
- **Strike** plays when the attack sequence advances — a committed,
  server-resolved strike.
- **Hit** plays when the hit sequence advances — a server-confirmed round
  striking the walker.
- **Death** plays when the replicated life state becomes `Dead`.
- All cues share one small round-robin `Sound` pool (2D, non-positional; true
  3D rolloff sounds uniformly distant under the overhead camera). Volume
  scales down with camera distance and is silent beyond a configured maximum,
  mirroring the combat-impact effect distance gate.
- Each cue has a global minimum interval spanning the whole population, so a
  full 24-enemy horde reinforces state changes without stacking one cue into
  noise.
- First sight of a walker records its replicated state silently; joining a
  session mid-operation cannot trigger a burst of stale cues.

## Authority

The controller creates no remote and never moves an enemy, applies damage,
establishes death, or reads Humanoid health. It reacts only to attributes the
server already replicates on every client's copy of the enemy models, so it
discloses nothing the replicated geometry does not already carry. Audio is
redundant reinforcement: every cue mirrors an existing non-audio pose, sensor,
or effect cue, so no critical information is audio-only.

## Assets

No approved hostile sound set exists yet. Every AUD-0103 cue is a temporary
derivation of the project's two Studio-verified firearm audio assets (fire
`rbxassetid://165946267`, reload `rbxassetid://7058441251`) replayed at
shifted speeds — mechanical clicks, rattles, and thuds that fit the walker's
mechanized rotting-horror design. No unverified asset ID is introduced.

`VisualAssetConfig` records `AudioStandardHostile` as `TemporaryPresentation`
owned by `EnemyAudioController`. Unique production-approved hostile assets
(organic alert/pursuit vocalization included) and a Studio mix review remain
pending before this family can pass the production-approval gates.

## Regression protection

`EnemyAudioSourceAudit` locks the shape: real asset IDs and positive throttles
for all five cues, one pooled Sound construction site, the bounded tracking
ceiling and distance gate, reaction to the five replicated attribute families,
prohibited authority tokens, and the single bootstrap start.
