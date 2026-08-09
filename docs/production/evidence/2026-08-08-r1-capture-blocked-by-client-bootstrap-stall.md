# Blueprint v2.7 R1 — Capture Precondition Finding + Local-Build Observation

**Status: NOT accepted R1 evidence.** This document records two things:

1. a defect that made valid R1 capture structurally impossible on the pinned artifact, and
2. an informational R1 capture taken on a local build, which is explicitly outside the pinned-artifact
   rule in `2026-08-07-336-r1-state-highlight-containment.md`.

It does not promote the evidence level. The project remains at its prior claimed level until a capture
is taken on a re-pinned CI artifact.

## 1. Finding — the pinned R1 artifact cannot produce valid evidence

`2026-08-07-336-r1-state-highlight-containment.md` lists among its invalidating conditions:

```text
unrelated script errors prevent client bootstrap
```

That condition was met unconditionally on the pinned artifact.

`SurvivorController.start()` is the fourth call in `src/client/init.client.luau`. Until commit
`91a1ebe3d04b6d99495f19e7a809bc2b4135fd97` it acquired Roblox's native controls through an unbounded
`playerScripts:WaitForChild("PlayerModule")`. `default.project.json` declares `StarterPlayerScripts`
with `$className`, and `PlayerModule` ships with the Studio place template rather than with this Rojo
tree, so a place built from this project contains no `PlayerModule` at all. The bootstrap thread
parked on that call permanently and none of the ~40 controllers after it ever started.

Observed in Studio on the pre-fix build:

- `PlayerGui` held exactly one ScreenGui, the CoreScript-owned `Freecam`
- `[Living Kingdoms] Client bootstrap started` never printed
- no HUD, crosshair, weapon loadout, class selection, expedition, horde or survival UI existed
- the client-side enemy pose controller never ran, so server-rigged enemies were unanimated

The pinned artifact commit `2c870d270b96064c9a06343cc088b251299373f4` predates the fix. Any R1 run on
that artifact is invalid by the packet's own criteria.

`HordeStateEarlyListener` is unaffected in isolation — it starts at line 11, ahead of the stall — so
the listener gauges could still read `true`. That is precisely why this matters: the R1 packet could
have been filled in and reported as passing while the client under test was, in fact, dead from the
fourth controller onward.

### Required action

Re-pin the R1 packet to a CI artifact built at or after
`91a1ebe3d04b6d99495f19e7a809bc2b4135fd97`, then re-run the capture procedure unchanged.

## 2. Informational local-build capture

Taken to confirm the R1 slice behaves as designed once the client actually boots. **Not a substitute
for the pinned-artifact run.**

- Date: 2026-08-08
- Source commit: `91a1ebe3d04b6d99495f19e7a809bc2b4135fd97`
- Build: local Rojo-synced Studio session, **not** a recorded CI artifact
- Session: 1 server / 1 client, desktop Studio
- Deviation from packet: Section 1 requires the exact pinned CI artifact; this run does not use one

### Captures

First capture, shortly after the client became controllable:

```json
{"schema":"LK_V27_R1_CAPTURE_V1","unixTime":1786206708,
 "listener":{"bound":true,"messagesReceived":370,"invalidMessages":0,"lastRevision":370},
 "highlightGuard":{"active":true,"rejectedCount":0},
 "highlightScan":{"total":28,"enabled":21,"rejectedInstances":[],"stillEnabledBroad":[]}}
```

Second capture, 91 seconds later:

```json
{"schema":"LK_V27_R1_CAPTURE_V1","unixTime":1786206799,
 "listener":{"bound":true,"messagesReceived":547,"invalidMessages":0,"lastRevision":547},
 "highlightGuard":{"active":true,"rejectedCount":0},
 "highlightScan":{"total":34,"enabled":24,"rejectedInstances":[],"stillEnabledBroad":[]}}
```

Both reported `PASSABLE=true`.

### Observations against the packet's gauge table

| Gauge / fact | Expected | Observed | Pass? |
|---|---|---|---|
| `V27_EarlyStateListenerBound` | `true` | `true` | yes |
| `V27_StateMessagesReceived` | `> 0` | 370 → 547 | yes |
| `V27_StateInvalidMessages` | `0` | 0 | yes |
| `V27_StateLastRevision` | numeric/nondecreasing | 370 → 547 | yes |
| `V27_BroadHighlightGuardActive` | `true` | `true` | yes |
| Broad visible world-root Highlight | none | `stillEnabledBroad` empty in both captures | yes |
| `HordeNetwork.State` queue/discard warnings | `0` | 0 | yes |
| Other new client errors caused by R1 slice | `0` | 0 | yes |

### Highlight containment

- rejected count at start, peak, and final: `0`
- `V27_BroadHighlightLastTarget`: never set
- no `[Living Kingdoms] Disabled broad Highlight` line appeared
- all 34 Highlights were narrow enemy-model and loot-chest targets; no world wash observed

The guard rejected nothing because nothing broad was produced in this run. This is an absence of the
symptom, not a demonstration that the guard rejects a broad target. The guard's rejection path
remains unproven at runtime.

### Replay coverage

`[Living Kingdoms] Mission director started: Operation Blackwater Relay` printed twice during the
session, so the `OperationLifecycleService` replay path executed. Enemies spawned after the restart
still carried their `ExclusionWalkerPresentation` rig, exercising the folder-identity fix from commit
`3b0d8e3`.

## 3. What this does and does not establish

Establishes:

- the client bootstrap now completes; 22 ScreenGuis present
- the R1 listener and Highlight guard behave as designed on a booting client
- no state queue/discard warnings under ~90 seconds of single-player play

Does not establish:

- anything about the pinned CI artifact
- multiplayer, late join, streaming, reset, respawn or disconnect behavior
- that the broad-Highlight rejection path works, since it never triggered
- any E-level promotion
