# Blueprint v2.7 R1 — Horde Single-Listener Consolidation

**Status: PASS.** This packet records the exact-build Studio run for PR #221 after the kill-chain popup/stinger was disabled at client bootstrap by product decision.

## 1. Identity

- Date/time: 2026-08-08, approximately 21:10–21:16 America/New_York
- Tester/operator: Codex using the dedicated Roblox Studio integration
- Roadmap ticket: Blueprint v2.7 Gate 0 / R1 single-listener consolidation; PR #221
- Rollout stage: `R1`
- Git branch: `rollout/v2.7-r1-listener-consolidation-prep-2026-08-07`
- Git commit SHA: `1ecbbf3b0300e9ee74a9c0d0ad9b239e2f294c3d`
- Tools: Rojo 7.7.0; StyLua 2.5.2; Selene 0.31.0; Lune 0.10.4
- Roblox Studio: `0.733.0.7330989`
- Place: `LivingKingdoms-pr221-1ecbbf3.rbxlx`
- Place file SHA-256: `f1d9317685f672f949d850970acd46c5f3a245896de1394d6f48718282ee8d19`
- Server/client count: one server, one client
- Device: Windows desktop; keyboard/mouse; normal graphics
- Flags: `EnableRuntimeCounters`, `EnableEarlyStateListener`, and `RejectBroadHighlightTargets` enabled
- Known-good rollback: `archive/pre-v2.7-r1-containment-2026-08-07`; pinned R1 artifact 9028866465

## 2. Claim under test

On the exact PR #221 build, `HordeStateEarlyListener` owns exactly one active physical `HordeNetwork.State.OnClientEvent` connection; active HUD and ambience consumers receive state through its bridge; a subscriber added after startup receives exactly one retained replay plus each subsequent live message; repeated messages and three complete Studio play lifecycles do not grow the listener count; and the disabled kill-chain popup/stinger remains absent.

## 3. Preconditions

- Required source synchronized: yes; clean commit `1ecbbf3b0300e9ee74a9c0d0ad9b239e2f294c3d`
- Required fixtures/data: canonical Rojo project and all 205 Lune fixtures
- Output cleared before run: fresh Studio process and fresh exact-build place
- Diagnostics enabled: yes
- Baseline packet used: [`2026-08-08-r1-playable-replay-loop.md`](2026-08-08-r1-playable-replay-loop.md)
- Known defects intentionally present: unpublished-place DataStore uses the expected volatile fallback
- Invalidating conditions: listener count other than one, invalid Horde payload count above zero, replay count other than one, duplicate callbacks, queue/discard warning, missing HUD/ambience mutation, or any massacre GUI/stinger instance

## 4. Baseline snapshot

Baseline: `B0` cold application after client startup.

| Gauge / rate | Expected | Start | Peak | End | Pass? |
|---|---:|---:|---:|---:|---|
| Legacy `HordeNetwork.State` listeners | 1 | 1 | 1 | 1 | yes |
| Invalid Horde state messages | 0 | 0 | 0 | 0 | yes |
| Queue/discard warnings | 0 | 0 | 0 | 0 | yes |
| Massacre GUI/stinger instances | 0 | 0 | 0 | 0 | yes |

Other managed-connection, Highlight-lease, streaming-rebind, viewmodel, camera, animation-marker, and transient-object gauges were not measured by this focused packet.

## 5. State-delivery counters

| Semantic key | Producer/owner | Attempts | Accepted | Suppressed unchanged | Sent | Buffered latest | Suppressed before ready | Avg sends/s | Peak sends/s |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Horde compatibility bundle | `HordeExperienceService` plus three diagnostic sends | not rate-measured | 3 diagnostic snapshots | R3 not implemented | 3 diagnostic snapshots | 1 latest retained by bridge | R2 not implemented | not measured | not measured |

Queue/discard warning count: **0**.

## 6. Producer / consumer inventory deltas

No producer changed in this PR. The compatibility producer remains `HordeExperienceService`.

| Listener/controller | Lifecycle scope | Bound before first publish? | Recreated on reset? | Recreated on respawn? | Presentation mutation | Ledger row updated? |
|---|---|---|---|---|---|---|
| `HordeStateEarlyListener` | Application | yes | no | no | none; bridge and retention owner | CL-001 |
| `HordeHUDController` | Application | bridge replay available after UI construction | no | no | threat/day/hostile/event HUD | CL-002 |
| `EnvironmentAmbienceController` | Application | bridge replay available after effect construction | no | no | threat color grade and bloom | CL-004 |
| `MassacreCrescendoController` | Not active | no | no | no | none; disabled at bootstrap | CL-003 |

## 7. Highlight ownership report

No Highlight owner or lease changed. Broad-target evidence was not re-profiled by this focused packet; the prior accepted R1 containment packet remains authoritative for HL-006.

## 8. Procedure

1. Ran all repository authority/import validators, StyLua, Selene, all 205 Lune fixtures, a Rojo build, and `git diff --check`.
2. Verified successful GitHub Actions run `31287571620` for commit `1ecbbf3b0300e9ee74a9c0d0ad9b239e2f294c3d`.
3. Built `LivingKingdoms-pr221-1ecbbf3.rbxlx`, verified its SHA-256, opened that exact file in a fresh Studio process, and started one client.
4. Captured the live diagnostics after startup.
5. Added a temporary client LocalScript subscriber through `HordeStateEarlyListener.subscribe`, waited through four live compatibility messages, disconnected it, and recorded callback and listener counters.
6. Fired three server-authored diagnostic snapshots with revisions 950001–950003 and inspected the HUD, ambience effects, physical-listener counter, invalid counter, and disabled presentation instances.
7. Stopped and restarted Play twice more and captured the cold-start gauges in each new lifecycle.
8. Stopped Play and reviewed the complete Studio output.

## 9. Observations

- Startup baseline: listener count `1`, bound `true`, HUD present, massacre GUI absent, invalid messages `0`.
- Late subscriber probe: base messages `76`, end messages `80`, live delta `4`, callbacks `5`, therefore exactly one retained replay and four live callbacks; in-game API count and diagnostic count were both `1`.
- Diagnostic snapshot 950003 rendered `NIGHT 93 // CORRUPTION TIER 3 // 90%`, `HOSTILES 023`, an 83% threat fill, and event text `PR221 CLEAN BRIDGE PROBE 3`.
- Ambience changed from contrast `0.01509`, saturation `-0.04741`, bloom `0.14074` to contrast `0.03075`, saturation `-0.11630`, bloom `0.26600`; tint also moved toward the alert grade.
- `LivingKingdomsMassacreCrescendo` and `LivingKingdomsMassacreTierStinger` remained absent.
- Play cycles 1, 2, and 3 each reported listener count `1`, bound `true`, advancing messages, and invalid count `0`.
- Console emitted no queue, discard, invocation, or client/server error. The only warning was the expected unpublished-place DataStore fallback.
- This was not a delayed-ready client, new-player late join, respawn, multiplayer, streaming, soak, or profiling run.

## 10. Required matrix result

Focused three-play lifecycle matrix actually run:

| Play lifecycle | Listener count | Bound | Invalid messages | HUD present | Massacre presentation absent | Queue warnings | Pass? |
|---|---:|---|---:|---|---|---:|---|
| 1 | 1 | true | 0 | yes | yes | 0 | yes |
| 2 | 1 | true | 0 | yes | yes | 0 | yes |
| 3 | 1 | true | 0 | yes | yes | 0 | yes |

The template's five-reset, three-respawn, delayed-ready/new-player late-join, two-player disconnect, animation, and ten-minute-soak matrices were not run and remain open for their later rollout gates.

## 11. Performance / profiling evidence

- Capture type: none
- This packet is sufficient for E5: no; it is focused E2 runtime evidence, not profiling evidence.

## 12. Defects found

None in the declared single-listener scope. Product play feedback separately identified an overwhelming HUD and click-only chest-loot UI; those are outside PR #221 and must be handled on a separate playable-patch branch.

## 13. Before / after comparison

| Metric | Before | After | Expected direction | Result |
|---|---:|---:|---|---|
| Physical Horde state listeners | 3 known consumer paths before consolidation | 1 | one owner | pass |
| Queue/discard warnings | 0 in accepted R1 baseline | 0 | 0 | pass |
| Invalid Horde messages | 0 | 0 | 0 | pass |
| Active kill-chain presentation | 1 bootstrap owner before product decision | 0 | disabled | pass |

## 14. Rollback decision

- Rollback trigger occurred: no
- Rollback performed: no
- Rollback checkpoint: `archive/pre-v2.7-r1-containment-2026-08-07`; pinned artifact 9028866465
- The build remains acceptable because all focused counters and presentation checks passed and the compatibility flag remains available.

## 15. Acceptance decision

- Packet result: `PASS`
- Ticket status after packet: PR #221 single-listener consolidation eligible to merge after final CI
- Ledger rows eligible for compatibility removal: no
- Evidence level before: E2
- Evidence level after: E2; confidence increased within R1, but no E3 matrix was claimed
- Reviewer/approver: Codex runtime operator; repository review/merge still required
- Open conditions before promotion: delayed-ready/new-player late join, multiplayer reset/disconnect, streaming, soak, and profiling evidence remain governed by later rollout tickets

## 16. Evidence attachments

- GitHub Actions: run `31287571620`
- Counter export: observations and exact values embedded above
- Output log: reviewed through the Studio integration; no queue/discard warning
- Screenshots/video/profiler capture: none
