# Deployable Build — Living Kingdoms

> **What this asserts and what it does not.** This build is **technically
> deployable**: it compiles to a valid Roblox place, passes its full automated
> suite, and formats and lints clean. It is **not validated for players** —
> zero live multiplayer Studio sessions have been completed, so the manual gates
> below remain open. "Deployable" here means *shippable as a build*, not
> *verified for a public launch*. Publish accordingly.

## Build facts (verify before any upload)

- **Commit:** `ca2f7d7` (record the exact SHA you upload).
- **Toolchain (`rokit.toml`, pinned):** Rojo 7.7.0, Selene 0.31.0, StyLua 2.5.2,
  Lune 0.10.4.
- **Automated suite:** 160 Lune fixtures — **all passing**.
- **Formatting:** `stylua --check` — clean.
- **Static analysis:** `selene` — 0 errors, 0 warnings, 0 parse errors.
- **Place build:** `default.project.json` → a valid `.rbxlx` (~1.79 MB).

Reproduce, from the repo root:

```bash
# Full gate (matches CI: .github/workflows/luau-validation.yml)
stylua --check games/living-kingdoms/src
selene games/living-kingdoms/src
for f in games/living-kingdoms/tests/*.test.luau; do lune run "$f"; done
rojo build games/living-kingdoms/default.project.json --output LivingKingdoms.rbxlx
```

## How to publish (you run this — it is outward-facing)

The build step is scripted; the actual publish is a deliberate, hard-to-reverse
action taken from your own Roblox account, so it is not automated here.

1. Build the place (command above), **or** open the Rojo-synced place in Studio.
2. In Studio: **File → Publish to Roblox (As…)**, targeting the intended
   experience/place. Choose **private** first if you want a soak before going
   public.
3. Confirm the experience's own settings (max players, genre, access) — those
   live in Roblox, not in this repo.

There is no CI step that publishes, and none should be added without an explicit
decision: a push must never auto-release to players.

## What is validated

- **Server authority and contracts** — the full P1–P10 + RPG + HROI logic is
  covered by 160 fixtures: movement, targeting/fire/hit/damage/reload, life state
  and revival, darkness/visibility, enemy pressure and the boss, ammunition
  scarcity, the objective chain, the twelve relics and their combat/reload/life
  integration, the reward sources and HUD, and the complete terminal match loop
  (causes, precedence, single-result assembly, cleanup/replay, session
  retention).
- **Build and tooling** — the place compiles and the repo passes the same gate CI
  runs on every PR.
- **Audio** — the AUD-0102/AUD-0103 firearm and hostile sets reference real
  imported `rbxassetid` sounds.

## What is NOT validated (open before a real player launch)

These are the milestones' **manual Studio gates**. None has been completed; each
needs a live session, and none is substitutable by automated coverage:

- **P10-0107** — the 1/2/4-operative full-loop matrix (success, squad failure,
  abandonment, disconnect-during-extraction, self-driven replay). Script and
  capture shape: [`P10-0107-STUDIO-CHECKLIST.md`](P10-0107-STUDIO-CHECKLIST.md).
  **P10 is not signed off until these rows exist.**
- **P5** — live pressure-loop playthrough (smoke test).
- **P8-0108** — live objective-chain playtest.
- **P9** — qualitative special-enemy/boss encounter session.
- **RPG-0108** — "three viable build patterns" evidence.
- **RPG-0113** — full multiplayer security/balance/performance matrix.
- **HROI** — representative playtest plus the visual/mix review.

**Unmeasured, by honest admission:**

- **4-client performance** under horde + boss + GUI has never been profiled live.
- **Balance and feel** — boss-kill feasibility for a solo operative, the 15 s
  extraction window, scarcity tension — are prototype intent, not measured
  (the measured scarcity replay is assigned to P12).

## Presentation state

Gameplay-driving **visuals are still graybox** — the VIS production track
(`VISUAL-PRODUCTION-TRACK.md`) is in progress and replaces placeholders in
parallel with the gameplay milestones under the rule that gameplay truth is
stable first and presentation attaches second. A build published now looks like
a functional prototype, not finished art. **Audio** is real imported sound.

## Honest recommendation

Publishing **private** for your own soak testing is reasonable and low-risk — it
is, in fact, how you would run the P10-0107 session. Publishing **public** to
real players is premature until at least the P10-0107 matrix and the P5/P8/P9
qualitative sessions are recorded, because that is precisely the multiplayer
behaviour no automated test can stand in for.
