# Blueprint v2.7 R1 — Current-main CI re-pin and capture attempt

**Status: BLOCKED — no Roblox Studio instance is connected to the Studio tools.**

**Packet result: PARTIAL.** The CI build and artifact pin are complete; no runtime capture has been taken. This is a preparation/attempt record, not accepted runtime evidence. All unobserved runtime facts below are **UNMEASURED**, never inferred as zero or passing.

This is the successor capture pin for the [blocked original packet](2026-08-07-336-r1-state-highlight-containment.md) and its [bootstrap finding](2026-08-08-r1-capture-blocked-by-client-bootstrap-stall.md). Historical packets are preserved. The later [accepted replay packet](2026-08-08-r1-playable-replay-loop.md) remains evidence for its own artifact; its measurements are not transferred to this build.

## 1. Identity and reproducibility

- Preparation date: 2026-09-15 America/New_York / 2026-09-16 UTC.
- Operator: Codex; runtime tester not yet established.
- Tickets: 334, 335, 336; containment precursor for 348.
- Rollout stage: R1. Repository change risk: R0 (evidence documentation only).
- Source branch: `main`, fetched before dispatch.
- Source-under-test SHA: `fcaab2c9244a3fafa6014b815992e507398ca4cf`.
- The source contains bootstrap-fix commit `91a1ebe3d04b6d99495f19e7a809bc2b4135fd97`, verified with `git merge-base --is-ancestor` (exit 0).
- [CI run 35047062601](https://github.com/Razzleberrytt/atlas-game-development/actions/runs/35047062601), manually dispatched on `main` with `profile=full`.
- CI result: PASS; `[validate] executed 447 Lune fixtures`; `[validate] OK — profile=full`; both Rojo builds and artifact uploads succeeded.
- Documentation validation: `python scripts/validate.py docs` passed with `[validate] OK — profile=docs`. Initial local attempt failed because dashboard commit `6acbe11fd2e95c664d85e941c28f7570d5262413` was absent from the local object database; fetching that exact commit resolved the failure without source changes.
- Artifact: `living-kingdoms-rbxlx-fcaab2c9244a3fafa6014b815992e507398ca4cf`.
- [GitHub artifact 10427820756](https://github.com/Razzleberrytt/atlas-game-development/actions/runs/35047062601/artifacts/10427820756).
- GitHub archive digest: `sha256:690a505d4bf41131dd31710c4107bf40868ec8515cbb7c3960c42b66e3ec69ab` (reported by GitHub's artifact API).
- Artifact creation: `2026-09-16T02:12:46Z`; expiration: `2026-09-30T02:12:45Z`.
- Extracted `LivingKingdoms.rbxlx` SHA-256: `a230aa028320a3c8eb1a102a186e2ff7d32136c0a9b53994a84e5f51cc8b0c45`, computed locally after `gh run download`.
- Local place: `C:/Users/Will/atlas-r1-capture/35047062601/LivingKingdoms.rbxlx`.
- Canonical project: `games/living-kingdoms/default.project.json`; this packet uses the operation place, not the separately uploaded Main World artifact.
- Pinned tools: Rojo 7.7.0, Lune 0.10.4, StyLua 2.5.2, Selene 0.31.0.
- Studio version / loaded place identity: UNMEASURED. Launching the file does not prove Studio loaded it.
- Intended session: one server / one desktop client. Actual session count, graphics and reduced-motion settings: UNMEASURED.
- Source configuration: `EnableRuntimeCounters = true`, `EnableEarlyStateListener = true`, `RejectBroadHighlightTargets = true`. Loaded-place flags: UNMEASURED.
- Historical rollback checkpoint: `archive/pre-v2.7-r1-containment-2026-08-07`, commit `6d88a33df1742981839c59933289eb0381e82074`; not newly runtime-validated here.

To download the pin while retained:

```powershell
gh run download 35047062601 -n living-kingdoms-rbxlx-fcaab2c9244a3fafa6014b815992e507398ca4cf -D C:/Users/Will/atlas-r1-capture/35047062601
Get-FileHash C:/Users/Will/atlas-r1-capture/35047062601/LivingKingdoms.rbxlx -Algorithm SHA256
```

## 2. Claim and preconditions

On a cold client start, the early listener binds before slow controller startup completes, received messages increase with no invalid messages or revision regression, and no HordeNetwork.State queue/discard warnings occur. The broad-Highlight guard is active, no enabled broad world-root Highlight remains, and legitimate narrow enemy feedback works without a startup regression.

Exact downloaded artifact identity, all three loaded flags, cleared Output, and a controllable bootstrapped client must be confirmed before capture. Wrong artifact/flags, uncleared Output, or unrelated errors preventing bootstrap invalidate the run. Do not use historical listener counts or historical controller inventory as observations of current main.

## 3. Exact capture procedure to resume

The [R1 runbook](../V2.7-R1-STUDIO-CAPTURE-RUNBOOK.md) procedure is unchanged; Section 1 of this successor packet supplies the new build identity instead of the runbook's historical build identity.

1. Open the exact downloaded CI artifact and confirm its hash and loaded identity against Section 1.
2. Confirm all three rollout flags are true in the loaded place.
3. Clear Studio Output.
4. Start one-player Play from a cold client start.
5. As soon as the client is controllable, run the complete `games/living-kingdoms/tools/studio/V27R1Capture.client.luau` from source SHA above in the **client** Command Bar. Retain its `LK_V27_R1_CAPTURE` JSON line.
6. Confirm the first snapshot reports `listener.bound == true`; record count/revision.
7. Play at least 60 seconds, including ordinary enemy hit/kill feedback.
8. Run the same unmodified helper again in the client context. Retain the second JSON line and compare counts, revision, and elapsed time.
9. Record guard active/rejected count/last target and verify final `highlightScan.stillEnabledBroad` is empty.
10. Observe narrow enemy feedback, horde-role readability, and any broad blue/yellow world wash.
11. Search Output for `HordeNetwork.State`, `invocation`, `queue`, `discard`, and `[Living Kingdoms] Disabled broad Highlight`. Keep exact warning/target paths and unrelated errors.
12. Stop play and record observations before changing source or flags.

Helper file SHA-256 as checked out locally: `3f71918f3ff4faee302d1fe718180a721188ef9b5a70619b4a5a5afd8d9410b5`.

## 4. Actual attempt and observed gauges

The Studio discovery tool returned `{"studios":[]}` before launch and after launch. Studio was launched with the exact local artifact path and a `RobloxStudioBeta` process was observed. No connected Studio ID was available, so loaded identity, Output clearing, Play, and client capture could not be performed. The operator was asked to finish startup/sign-in if needed and enable the Studio MCP connection. No sign-in dialog or other particular startup cause was observed.

| Gauge / fact | Required result | First | Final |
|---|---|---|---|
| Listener bound | true | UNMEASURED | UNMEASURED |
| Messages received | positive and increasing | UNMEASURED | UNMEASURED |
| Invalid messages | zero | UNMEASURED | UNMEASURED |
| Last revision | numeric, nondecreasing | UNMEASURED | UNMEASURED |
| Broad guard active | true | UNMEASURED | UNMEASURED |
| Rejected count / peak / exact last target | actual values | UNMEASURED | UNMEASURED |
| Highlight total / enabled | actual values | UNMEASURED | UNMEASURED |
| Still-enabled broad targets | final empty list | UNMEASURED | UNMEASURED |
| Capture timestamp / elapsed seconds | at least 60 seconds apart | UNMEASURED | UNMEASURED |
| Queue/discard warnings | zero | UNMEASURED | UNMEASURED |
| Startup regression / new R1 client errors | absent / zero | UNMEASURED | UNMEASURED |
| Narrow enemy feedback works | yes | UNMEASURED | UNMEASURED |
| Broad world wash appears | no | UNMEASURED | UNMEASURED |

First capture JSON: not captured. Final capture JSON: not captured. Output log, screenshots, video, counter export, and profiling captures: none. Reset, respawn, delayed-ready, late-join, disconnect, multiplayer, streaming, animation and soak matrices: not run. No runtime defect or success is inferred from unavailable tooling.

## 5. Acceptance and cutover decision

- Packet result: **PARTIAL** (operator decision; no runtime run).
- Exact CI build created/downloaded: yes. Exact artifact used in a confirmed Studio session: not established.
- All runtime acceptance conditions: untested; none marked passing.
- Cutover ledger: unchanged. No rows become eligible for compatibility removal from this attempt.
- Prior accepted evidence level: preserved; no promotion or demotion based on this attempt.
- Rollback performed: no; no runtime cutover or publication performed.
- Runtime rollback trigger occurrence: UNMEASURED.
- Authority/data/lifecycle boundaries changed: none.
- Next step: connect Studio, confirm the downloaded artifact, then execute every capture step above and record actual values in a new run packet linked to this preparation record.

The existing `V27R1EvidenceEvaluator.luau` is deliberately pinned to historical artifact `9028866465`, commit `c55287fac4ecefc120c541958a6a06049b0a78cd`. It was not run against this attempt and would reject this new identity. Do not relabel new evidence with the old identity to obtain PASS. Before using automated evaluation of a completed new capture, explicitly add the new trusted pin with regression coverage while preserving historical evidence validation and all acceptance conditions.
