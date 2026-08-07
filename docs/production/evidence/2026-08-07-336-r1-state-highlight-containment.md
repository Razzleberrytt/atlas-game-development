# Blueprint v2.7 R1 Evidence Packet — Early State Listener + Broad Highlight Containment

This packet is prepared for the first Studio/runtime validation of the R1 containment slice. It is **not accepted evidence until the runtime fields below are filled from an actual run**.

## 1. Identity

- Date/time: 2026-08-07; runtime time to be recorded
- Tester/operator: to be recorded
- Roadmap ticket(s): 334, 335, 336; containment precursor for 348
- Rollout stage: `R1`
- Git branch: `main`
- Source-under-test Git commit SHA: `5d5edae561d8d7d900f9e87394c57886189e0a30`
- Roblox Studio version: to be recorded
- Place name: Living Kingdoms / active development place
- Place/source identity: Rojo-sync `games/living-kingdoms/default.project.json`; exact active place identity to be recorded
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

- Required source synchronized: current `main` at or after the source-under-test commit above
- Output cleared before run: **yes**
- Diagnostics enabled: `EnableRuntimeCounters = true`
- R1 listener enabled: `EnableEarlyStateListener = true`
- Broad-target containment enabled: `RejectBroadHighlightTargets = true`
- Baseline packet used: active-place screenshot/incident evidence from 2026-08-07
- Known defects intentionally present: legacy server publisher still uses the 0.5-second compatibility snapshot path; two domain controllers still directly listen in addition to the R1 bridge
- Invalidating conditions: source/flags differ from this packet, unrelated script errors prevent client bootstrap, or Output was not cleared before test

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

Optional Studio command-bar capture in client context:

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

1. Sync/open the active development place from current repository source.
2. Confirm the three rollout flags listed in this packet are `true`.
3. Clear Studio Output.
4. Start a one-player play session from a cold client start.
5. As soon as the client is controllable, inspect `ReplicatedStorage.HordeNetwork` attributes.
6. Confirm `V27_EarlyStateListenerBound == true` and record the initial received count/revision.
7. Play for at least 60 seconds, including enough time for normal horde-state publishing.
8. Inspect the same attributes again; record received count, invalid count, and revision.
9. Inspect `Workspace` diagnostics and record guard active/rejected count/last target.
10. Observe ordinary enemy hit/kill feedback to verify narrow enemy-model Highlights were not suppressed.
11. Search Output for `HordeNetwork.State`, `invocation`, `queue`, `discard`, and `[Living Kingdoms] Disabled broad Highlight`.
12. Stop play and record all facts before changing any flag or source.

## 8. Observations

- Startup behavior:
- First observed `V27_StateMessagesReceived`:
- Final `V27_StateMessagesReceived`:
- `V27_StateInvalidMessages`:
- Initial/final `V27_StateLastRevision`:
- Queue/discard warning count:
- Guard active:
- Broad Highlight rejected count:
- Last rejected target:
- Narrow enemy Highlight behavior:
- Visible broad world wash:
- Any console warnings/errors unrelated to the known legacy publisher:

## 9. R1 acceptance decision

R1 may be considered for acceptance only if all are true:

- [ ] `V27_EarlyStateListenerBound == true` during the run.
- [ ] `V27_StateMessagesReceived > 0`.
- [ ] `V27_StateInvalidMessages == 0`.
- [ ] Zero `HordeNetwork.State` invocation-queue/discard warnings occur.
- [ ] No startup regression is introduced.
- [ ] Broad world-root Highlight wash does not remain visible.
- [ ] Legitimate narrow enemy Highlight feedback still works.
- [ ] Any rejected broad target is recorded by exact target path for producer attribution.

Packet result: `PASS` / `FAIL` / `PARTIAL` / `INVALID` — **unfilled**

## 10. Next gate after a PASS

Do not jump to gameplay expansion. After accepted R1 evidence:

1. update `V2.7-CUTOVER-LEDGER.md` with measured facts;
2. migrate `HordeHUDController` and `MassacreCrescendoController` from direct `State` listeners onto the application bridge, reducing the effective compatibility listener count toward one;
3. implement R2 `ClientReady` delivery gating;
4. then implement R3 semantic-key/change-token suppression and measure before/after send rate.

> This packet records a run. Until it is filled from Studio, the repository remains E1 and the incident remains open.
