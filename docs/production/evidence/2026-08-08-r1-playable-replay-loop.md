# Blueprint v2.7 R1 — Pinned CI Capture + Playable Replay Validation

**Status: PASS.** This is a fresh packet. It supersedes the invalid pre-bootstrap-fix R1 artifact packet; it does not rewrite that earlier record.

## 1. Identity

- Date/time: 2026-08-08, approximately 18:51–18:55 America/New_York
- Tester/operator: Codex using the dedicated Roblox Studio integration
- Roadmap tickets: Blueprint v2.7 R1; P10-0105 acceptance defect repair
- Rollout stage: `R1`
- Git branch: `codex/playable-replay-loop`
- Fix commit: `60eba47d766529e52d8b1239da17397deeaa7de9`
- Artifact source/build commit: `c55287fac4ecefc120c541958a6a06049b0a78cd` (PR #245 synthetic merge)
- GitHub workflow run: `31282591558` — success
- Artifact: `living-kingdoms-rbxlx-c55287fac4ecefc120c541958a6a06049b0a78cd`
- Artifact ID: `9028866465`
- Artifact digest: `sha256:4cdb778a37e22c9172216d999a2dfcffec75e05e29baffaad2233a2c5dbf92c5`
- Extracted place SHA-256: `62200adf721685b1d6537d03e6914aaac5d789b21ed00405dac47421931db0d1`
- Tools: Rojo 7.7.0; StyLua 2.5.2; Selene 0.31.0; Lune 0.10.4
- Roblox Studio: `0.733.0.7330989`
- Place: `LivingKingdoms.rbxlx`
- Server/client count: one server, one client
- Device: Windows desktop; keyboard/mouse; normal graphics
- Flags: `EnableRuntimeCounters`, `EnableEarlyStateListener`, and `RejectBroadHighlightTargets` enabled
- Known-good rollback: `26898b21bffd8e4b50001da2e3812e17760bab6a`; containment checkpoint `archive/pre-v2.7-r1-containment-2026-08-07`

## 2. Claims under test

1. On the exact recorded CI artifact, the earliest compatibility listener binds, consumes valid advancing state for at least 60 seconds, and leaves no enabled broad Highlight target or queue/discard warning.
2. After a terminal result and the configured 20-second debrief, a second operation begins with a live, mobile operative, accepts the new run's mission revision, hides the prior debrief, and can advance its opening objective.

## 3. Preconditions and procedure

1. Downloaded artifact ID `9028866465` from successful workflow run `31282591558`; verified the extracted place hash above.
2. Opened that exact place in a new Studio instance, cleared prior play state, and started one client.
3. Captured the R1 diagnostics after the client became controllable.
4. Played the authored route by entering Ranger Station, charging Signal Booster, restoring Floodlight Array, and entering Extraction Pad/Holdout.
5. Captured the same diagnostics 94 seconds after the first capture.
6. Allowed hostile pressure to produce a squad-wipe result, observed the debrief, and waited through the configured 20-second replay timer.
7. Checked health, WalkSpeed, mission phase/objective, and debrief visibility, then entered Ranger Station again.
8. Stopped Play and reviewed the complete Studio output.

The navigation helper moved the ordinary player character between authored interaction areas; it did not call gameplay services, mutate mission/life state, or bypass server-owned presence timers.

## 4. R1 captures

First capture:

```json
{"highlightScan":{"enabled":14,"total":14,"rejectedInstances":[],"stillEnabledBroad":[]},"unixTime":1786229523,"listener":{"messagesReceived":50,"bound":true,"invalidMessages":0,"lastRevision":50},"schema":"LK_V27_R1_CAPTURE_V1","highlightGuard":{"rejectedCount":0,"active":true}}
```

Final capture, 94 seconds later:

```json
{"highlightScan":{"enabled":26,"total":36,"rejectedInstances":[],"stillEnabledBroad":[]},"unixTime":1786229617,"listener":{"messagesReceived":238,"bound":true,"invalidMessages":0,"lastRevision":238},"schema":"LK_V27_R1_CAPTURE_V1","highlightGuard":{"rejectedCount":0,"active":true}}
```

| R1 gate | Observed | Pass? |
|---|---:|---|
| Exact recorded artifact | ID `9028866465`; hashes above | yes |
| Earliest listener bound | `true` at both captures | yes |
| Messages received | 50 → 238 | yes |
| Invalid messages | 0 → 0 | yes |
| Revision | 50 → 238 | yes |
| Queue/discard warnings | 0 | yes |
| Guard active | `true` | yes |
| Enabled broad Highlights | 0 → 0 | yes |
| Broad world wash | not present | yes |
| Narrow Highlight behavior | narrow enabled Highlights remained present during encounter pressure | yes |
| R1-attributable client errors | 0 | yes |

The deterministic evaluator input is stored beside this packet in `2026-08-08-r1-playable-replay-evaluator-input.json`; evaluator result: `PASS`.

## 5. Replay/reset observations

Before the fix, a recorded-artifact run reached a terminal result and the server logged a second mission start, but the client stayed on the run-1 debrief at 0 health. Source inspection found three coupled defects:

- replay called application-level `OperativeLifeService.stop()`, clearing long-lived life/roster subscribers;
- mission client consumers compared revision without the per-run `operationId`, rejecting run 2 when revision restarted;
- the result controller never hid or re-armed its debrief for a new operation.

On the fixed CI artifact, after the same terminal boundary:

| Fact | Run-1 terminal | Run-2 after debrief | Pass? |
|---|---:|---:|---|
| Mission phase | `Resolved` | `Infiltration` | yes |
| Objective | `Operation resolved` | `Secure the ranger station perimeter` | yes |
| Health | 0 | 100 | yes |
| WalkSpeed | 0/immobile terminal state | 16 | yes |
| Debrief enabled | `true` | `false` | yes |
| Second-run opening objective | — | advanced to `Charge the signal booster` after Ranger Station presence | yes |

The life revision advances monotonically in the application scope; the per-run `operationId` supplies the mission reset boundary. Existing life and roster subscriptions are retained.

## 6. Console and visual observations

- Startup completed: world foundation, mission director, server bootstrap, first-person camera, native controls, and client bootstrap all logged successfully.
- The only warning was the expected unpublished-place DataStore fallback to volatile memory.
- No queue, discard, invocation, or disabled-broad-Highlight warning was emitted.
- No new server/client error was emitted.
- Normal shaded world rendering remained visible. The earlier flat green/yellow/blue view was traced to local hidden legacy Studio physics-visualization flags, all disabled before this run; it was not gameplay presentation or a broad Highlight.
- Legitimate narrow encounter Highlights remained enabled while the independent scan found no broad target.

## 7. Producer/consumer and ownership deltas

| Owner/consumer | Scope | Change |
|---|---|---|
| `OperativeLifeService` | Application owner with operation state | Added `resetForReplay()`; preserves player, character, life, and roster subscriptions while clearing operation life/armor/retention state. |
| `OperationLifecycleService` | Operation lifecycle | Uses the in-place life reset instead of application stop/start. |
| `MissionController` | Application client listener | Revision monotonicity is evaluated within the same `operationId`. |
| `MissionObjectPresentationController` | Application client listener | Same operation-aware revision boundary for world-object presentation. |
| `MatchResultController` | Application client presentation | Hides and re-arms the debrief when mission phase becomes `Insertion`. |

No client-to-server request, combat/progression authority, new remote, or alternate state path was added.

## 8. Validation

- repository layout: PASS (`278` Luau source files, `205` fixtures)
- Studio import preservation: PASS (`28/28` sources, `1775/1775` Workspace rows)
- migration manifests: PASS (4 manifests)
- StyLua: PASS
- Selene: PASS (0 errors, 0 warnings, 0 parse errors)
- Lune: PASS (`205/205` fixtures)
- Rojo build: PASS
- GitHub Actions run `31282591558`: PASS, including reproducible artifact upload
- Studio recorded-artifact R1 + replay run: PASS

## 9. Rollback and acceptance

- Rollback trigger occurred: no
- Rollback performed: no
- Compatibility flags remain enabled; no removal is authorized by this packet.
- Packet result: `PASS`
- R1 status: accepted for this pinned artifact
- Evidence level: E1 → E2. The pinned artifact started and all required systems initialized; this packet does not substitute for the later reset/respawn, late-join, multiplayer, streaming, or profiling gates needed for E3–E5 promotion.
- Next dependency-safe runtime task: rebase/revalidate the prepared single-listener consolidation in PR #221, then proceed to R2 only after its own declared evidence gate.

## 10. Open conditions

- This was a one-client run; multiplayer reset/disconnect and late-join matrices remain open.
- No MicroProfiler, device-emulation, streaming, or performance acceptance was attempted.
- Durable rewards/persistence remain outside this operation loop; Studio used the expected volatile fallback.
- PR #222's R2 publisher remains blocked until listener consolidation is accepted.
