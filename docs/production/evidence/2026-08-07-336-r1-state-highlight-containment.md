# Blueprint v2.7 R1 Evidence Packet — Early State Listener + Broad Highlight Containment

This packet is prepared for the first Studio/runtime validation of the R1 containment slice. It is **not accepted evidence until the runtime fields below are filled from an actual run**.

## 1. Identity

- Date/time: 2026-08-07; runtime time to be recorded
- Tester/operator: to be recorded
- Roadmap ticket(s): 334, 335, 336; containment precursor for 348
- Rollout stage: `R1`
- Git branch: `main`
- Source-under-test Git commit SHA: `2c870d270b96064c9a06343cc088b251299373f4`
- CI validation run: `31219832584` / Luau validation run `#800`
- CI result: **PASS** — repository contract, StyLua, Selene, all discovered Lune fixtures, Rojo build, and artifact upload completed successfully
- Reproducible build artifact: `living-kingdoms-rbxlx-2c870d270b96064c9a06343cc088b251299373f4`
- GitHub artifact ID: `9009926429`
- Artifact digest: `sha256:587ccc2974f8188bde34a0a757213efb4b9f72e68e940db4615232cace28bf89`
- Artifact retention through: 2026-08-21
- Roblox Studio version: to be recorded
- Place name: Living Kingdoms / active development place
- Place/source identity: use the CI artifact above for this packet; do not substitute an unrecorded local build
- Server/client count: begin with 1 server / 1 client
- Device(s): desktop Studio client for this packet
- Feature flags/configuration:
  - `EnableRuntimeCounters = true`
  - `EnableEarlyStateListener = true`
  - `RejectBroadHighlightTargets = true`
- Known-good rollback branch: `archive/pre-v2.7-r1-containment-2026-08-07`
- Known-good rollback commit: `6d88a33df1742981839c59933289eb0381e82074`

## 2. Claim under test

```text
On a cold client start, HordeStateEarlyListener binds early enough that HordeNetwork.State has an
effective listener before the slower client controller graph completes startup. During the run,
V27_StateMessagesReceived increases, V27_StateInvalidMessages remains 0, and Roblox produces zero
HordeNetwork.State invocation-queue/discard warnings. BroadHighlightGuardController is active and
prevents any Workspace/Terrain/large-world-root Highlight from remaining visible while leaving
narrow enemy-model Highlights functional.
```

## 3. Preconditions

- Required source/build: CI artifact `living-kingdoms-rbxlx-2c870d270b96064c9a06343cc088b251299373f4`
- Output cleared before run: **yes**
- Diagnostics enabled: `EnableRuntimeCounters = true`
- R1 listener enabled: `EnableEarlyStateListener = true`
- Broad-target containment enabled: `RejectBroadHighlightTargets = true`
- Baseline packet used: active-place screenshot/incident evidence from 2026-08-07
- Known defects intentionally present: legacy server publisher still uses the 0.5-second compatibility snapshot path; two domain controllers still directly listen in addition to the R1 bridge
- Invalidating conditions: artifact/source/flags differ from this packet, unrelated script errors prevent client bootstrap, or Output was not cleared before test

## 4. Required R1 diagnostics

In the **client** context, inspect:

### `ReplicatedStorage.HordeNetwork` attributes

- `V27_EarlyStateListenerBound` — expected `true`
- `V27_StateMessagesReceived` — expected to increase during play
- `V27_StateInvalidMessages` — expected `0`
- `V27_StateLastRevision` — expected numeric and nondecreasing

### `Workspace` attributes

- `V27_BroadHighlightGuardActive` — expected `true`
- `V27_BroadHighlightRejectedCount` — record actual value
- `V27_BroadHighlightLastTarget` — record when count is greater than zero

Preferred capture path: use `games/living-kingdoms/tools/studio/V27R1Capture.client.luau` from the Studio Command Bar in the **client** context. The helper lives outside `src/`, is not included in the Rojo place, only reads existing diagnostics/Highlights, and prints a machine-readable line beginning with:

```text
LK_V27_R1_CAPTURE {json}
```

Run it once shortly after the cold client becomes controllable and once again after at least 60 seconds. Keep both lines with this packet. Full operator instructions are in `docs/production/V2.7-R1-STUDIO-CAPTURE-RUNBOOK.md`.

Fallback manual Studio command-bar capture:

```lua
print("Horde diagnostics", game:GetService("ReplicatedStorage").HordeNetwork:GetAttributes())
print("Highlight diagnostics", workspace:GetAttributes())
```

## 5. Baseline snapshot

- Baseline: `B0` cold application startup

| Gauge / fact | Expected | Observed | Pass? |
|---|---|---|---|
| `V27_EarlyStateListenerBound` | `true` | | |
| `V27_StateMessagesReceived` | `> 0` after server begins publishing | | |
| `V27_StateInvalidMessages` | `0` | | |
| `V27_StateLastRevision` | numeric/nondecreasing | | |
| `V27_BroadHighlightGuardActive` | `true` | | |
| Broad visible world-root Highlight | none | | |
| `HordeNetwork.State` queue/discard warnings | `0` | | |
| Other new client errors caused by R1 slice | `0` | | |

## 6. Highlight containment observations

| Observation | Result |
|---|---|
| `V27_BroadHighlightRejectedCount` at start | |
| Peak rejected count | |
| Final rejected count | |
| `V27_BroadHighlightLastTarget` | |
| Legitimate enemy hit/kill flash still visible | |
| Horde role visuals still readable | |
| Any blue/yellow world wash appears | |

If a broad target is rejected, copy the exact warning line beginning with:

```text
[Living Kingdoms] Disabled broad Highlight
```

That target becomes the next producer-attribution lead; do not infer the producer from color alone.

## 7. Procedure

1. Download/open the exact CI artifact named in Section 1.
2. Confirm the place under test corresponds to artifact commit `2c870d270b96064c9a06343cc088b251299373f4`.
3. Confirm the three rollout flags listed in this packet are `true`.
4. Clear Studio Output.
5. Start a one-player play session from a cold client start.
6. As soon as the client is controllable, run `games/living-kingdoms/tools/studio/V27R1Capture.client.luau` in the client Command Bar and retain the `LK_V27_R1_CAPTURE` output line.
7. Confirm the first capture reports `listener.bound == true`; record its received count/revision.
8. Play for at least 60 seconds, including enough time for normal horde-state publishing and ordinary enemy hit/kill feedback.
9. Run the same capture helper again; retain the second JSON line and compare received count/revision against the first capture.
10. Confirm `highlightScan.stillEnabledBroad` is empty in the second capture and record the guard rejected count/last target.
11. Observe ordinary enemy hit/kill feedback to verify narrow enemy-model Highlights were not suppressed.
12. Search Output for `HordeNetwork.State`, `invocation`, `queue`, `discard`, and `[Living Kingdoms] Disabled broad Highlight`.
13. Stop play and record all facts before changing any flag or source.

## 8. Observations

- Startup behavior:
- First `LK_V27_R1_CAPTURE` line:
- Final `LK_V27_R1_CAPTURE` line:
- First/final `V27_StateMessagesReceived`:
- `V27_StateInvalidMessages`:
- Initial/final `V27_StateLastRevision`:
- Queue/discard warning count:
- Guard active:
- Broad Highlight rejected count:
- Last rejected target:
- `highlightScan.stillEnabledBroad` final count:
- Narrow enemy Highlight behavior:
- Visible broad world wash:
- Any console warnings/errors unrelated to the known legacy publisher:

## 9. R1 acceptance decision

R1 may be considered for acceptance only if all are true:

- [ ] Exact CI artifact from Section 1 was used.
- [ ] `V27_EarlyStateListenerBound == true` during the run.
- [ ] `V27_StateMessagesReceived > 0`.
- [ ] `V27_StateInvalidMessages == 0`.
- [ ] Zero `HordeNetwork.State` invocation-queue/discard warnings occur.
- [ ] No startup regression is introduced.
- [ ] Broad world-root Highlight wash does not remain visible.
- [ ] `highlightScan.stillEnabledBroad` is empty at the final capture.
- [ ] Legitimate narrow enemy Highlight feedback still works.
- [ ] Any rejected broad target is recorded by exact target path for producer attribution.

Packet result: `PASS` / `FAIL` / `PARTIAL` / `INVALID` — **unfilled**

## 10. Next gate after a PASS

Do not jump to gameplay expansion. After accepted R1 evidence:

1. update `V2.7-CUTOVER-LEDGER.md` with measured facts;
2. migrate `HordeHUDController` and `MassacreCrescendoController` from direct `State` listeners onto the application bridge, reducing the effective compatibility listener count toward one;
3. implement R2 `ClientReady` delivery gating;
4. then implement R3 semantic-key/change-token suppression and measure before/after send rate.

> Repository validation and the reproducible build are green, but they do not substitute for runtime evidence. Until this packet is filled from Studio, the repository remains E1 and the incident remains open.
