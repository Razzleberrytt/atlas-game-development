# Main World BA-014 Studio Evidence Runbook

**Roadmap ticket:** BA-014  
**Status:** operator runbook only — **NO RUN RECORDED / NO ACCEPTANCE CLAIMED**  
**Authority:** [`main-world-acceptance-matrix.md`](../specifications/main-world-acceptance-matrix.md) and `MainWorldAcceptanceMatrixConfig.luau` remain the acceptance definition.

This runbook turns the existing 31-check BA-014 definition into a repeatable operator sequence for the currently mapped dedicated Main World. It does **not** contain outcomes and must never be cited as evidence that a check passed.

Every actual run must create a new packet from [`V2.7-EVIDENCE-PACKET-TEMPLATE.md`](../production/V2.7-EVIDENCE-PACKET-TEMPLATE.md) under `docs/production/evidence/`. Do not edit an older packet to fit a later build.

## 1. Current first-run candidate scope

The first BA-014 run should exercise the dedicated Main World source build, not the operation project or recovered whole world.

Expected source topology at the start of the run:

- project: `games/living-kingdoms/main-world.project.json`;
- hub presentation: admitted arrival, Central Fountain, Grand Staircase, Hub Archway and Dungeon Portal;
- primary route presentation: `Workspace/LivingKingdomsMainWorld/Routes/PrimaryRoute`;
- route truth: `route.world.primary` + `main_world.primary_route`;
- primary route presentation: 12 source-managed Parts, one per bounded route chunk;
- recovered 189 `WorldPath` slabs: not mapped and not authoritative;
- dedicated place: unpublished;
- Main World runtime activation: held;
- inter-place transport: undefined/held;
- exact streaming radii, `ModelStreamingMode` and quality-tier behavior: **not approved until measured**.

If current `main` no longer matches this scope, update the candidate description before using this runbook. Never silently run a materially different build against stale assumptions.

## 2. Hard preflight — prove evidence transport before testing

The prior Studio attempt on 2026-08-09 was `INVALID`: the exact Rojo artifact opened in Studio, but the Studio MCP proxy exposed only an older disconnected instance. No gameplay observation from that attempt counted.

Before spending time on the 31 checks:

1. Fetch the exact candidate commit and record its full SHA.
2. Run the repository validation profile and confirm the candidate's required CI is green.
3. Build the dedicated Main World from `games/living-kingdoms/main-world.project.json`.
4. Record the generated place filename and SHA-256.
5. Open that exact artifact in Roblox Studio.
6. Record Studio version, Rojo/tool versions, operator, date/timezone, device profile, graphics quality, server/client count and feature/config state.
7. Verify the Studio evidence path exposes the **same artifact identity** that was just built/opened.
8. If exact artifact identity cannot be proved, stop the run and record the affected checks as `Blocked`; do not gather substitute screenshots or observations from another open place.

A bridge/tool failure is not a runtime failure. A run missing required identity fields is `Invalid`, never `Pass`.

## 3. Required run identity

Copy all of these into the new evidence packet before recording a pass/fail result:

- capture date and timezone;
- operator;
- repository commit;
- branch/ref;
- Rojo/tool versions;
- Roblox Studio version;
- place filename;
- place artifact SHA-256 or equivalent reproducible source identity;
- Main World place identity;
- server/client count;
- device profile ID;
- graphics quality level;
- feature/config state;
- rollback checkpoint commit/build.

If any required identity is missing, the run is `Invalid`.

## 4. Result vocabulary

Use only the matrix vocabulary:

| Status | Use when |
|---|---|
| `NotRun` | The check was not executed. |
| `Pass` | The exact recorded build was observed and met the requirement. |
| `Fail` | The exact recorded build was observed and a real defect reproduced. |
| `Blocked` | Evidence transport/tooling prevented observation. |
| `Invalid` | Observation occurred but required run identity is incomplete. |

Never convert `Blocked`, `Invalid` or `NotRun` into `Pass` to unblock development.

## 5. Capture order

Use this order so cheap structural failures stop the run before expensive profiling:

1. **Identity + bridge preflight.** Prove the exact artifact is observable.
2. **Arrival + four-player clearance.** Catch spawn/camera/prompt blockers first.
3. **Navigation + route seams.** Traverse the complete mapped route and preparation loop.
4. **Readability + fixed cameras.** Capture all required quality/device modes from the matrix-defined cameras.
5. **Streaming + lifecycle.** Exercise semantic group stream-out/rebind and prove stream-out never mutates consequential state.
6. **Audio + environment ownership.** Run only against assets/profiles actually present; missing required content is a failure/blocker according to the matrix, not permission to invent it during the run.
7. **Performance + memory.** Warm up, capture steady-state samples, then perform cleanup comparison.
8. **Decision.** Evaluate every result through the BA-014 source definition; do not hand-wave a blocking failure.

## 6. BA-014 check sheet

The source config is authoritative for thresholds, blocking flags, capture modes and evaluation. This table is an operator index only.

### Arrival and flow

| Check ID | Result | Evidence reference / notes |
|---|---|---|
| `mwam.arrival.destination_matrix` | `NotRun` | |
| `mwam.arrival.four_player_simultaneous` | `NotRun` | |
| `mwam.arrival.orientation_recognition` | `NotRun` | |
| `mwam.arrival.preparation_reachability` | `NotRun` | |
| `mwam.arrival.return_debrief_context` | `NotRun` | |
| `mwam.arrival.character_release_gating` | `NotRun` | |

### Navigation and composition

| Check ID | Result | Evidence reference / notes |
|---|---|---|
| `mwam.navigation.core_loop_traversal` | `NotRun` | |
| `mwam.navigation.dead_travel` | `NotRun` | |
| `mwam.navigation.multiplayer_congestion` | `NotRun` | |
| `mwam.navigation.boundary_and_metrics` | `NotRun` | |
| `mwam.navigation.optional_branch_payoff` | `NotRun` | |

### Landmark and readability

| Check ID | Result | Evidence reference / notes |
|---|---|---|
| `mwam.readability.landmark_recognition_distance` | `NotRun` | |
| `mwam.readability.independent_channels` | `NotRun` | |
| `mwam.readability.cues_under_atmosphere` | `NotRun` | |
| `mwam.readability.minimum_tier_preserves_meaning` | `NotRun` | |

### Visual environment

| Check ID | Result | Evidence reference / notes |
|---|---|---|
| `mwam.visual.fixed_camera_capture_set` | `NotRun` | |
| `mwam.visual.geometry_defects` | `NotRun` | |
| `mwam.visual.environment_profile_ownership` | `NotRun` | |
| `mwam.visual.ambient_ceilings` | `NotRun` | |

### Audio

| Check ID | Result | Evidence reference / notes |
|---|---|---|
| `mwam.audio.asset_permission` | `NotRun` | |
| `mwam.audio.crossfade_and_reentry` | `NotRun` | |
| `mwam.audio.mix_review` | `NotRun` | |
| `mwam.audio.accessibility` | `NotRun` | |

### Streaming and lifecycle

| Check ID | Result | Evidence reference / notes |
|---|---|---|
| `mwam.streaming.semantic_group_rebind` | `NotRun` | |
| `mwam.streaming.no_completion_on_stream_out` | `NotRun` | |
| `mwam.streaming.hitch_budget` | `NotRun` | |
| `mwam.lifecycle.cleanup_drift` | `NotRun` | |

### Performance and memory

| Check ID | Result | Evidence reference / notes |
|---|---|---|
| `mwam.performance.desktop_full_traversal` | `NotRun` | |
| `mwam.performance.mobile_minimum_traversal` | `NotRun` | |
| `mwam.performance.four_player_census` | `NotRun` | |
| `mwam.performance.static_replication_churn` | `NotRun` | |

## 7. Required capture set

Use the capture modes and device profiles defined by BA-014; do not substitute a convenient single screenshot for a required mode.

Fixed camera IDs:

- `camera.arrival_threshold`;
- `camera.orientation_center`;
- `camera.preparation_ring`;
- `camera.interaction_edge`;
- `camera.adventure_gate`;
- `camera.exploration_branch`;
- `camera.return_seam`.

Required capture modes:

- `capture.neutral_editor` — Full/editor;
- `capture.gameplay_full` — Full/desktop 16×9;
- `capture.gameplay_reduced` — Reduced/desktop 16×9;
- `capture.gameplay_minimum` — MinimumReadable/desktop 16×9;
- `capture.mobile_portrait` — MinimumReadable/mobile portrait;
- `capture.mobile_landscape` — MinimumReadable/mobile landscape.

Record the real hardware identity for each device profile. Do not infer hardware from the profile name.

## 8. Measurements to record, never guess

The BA-014 config owns the exact threshold values and provenance. The run packet must record observed values for applicable checks, including at minimum:

- orientation-recognition time;
- four-player arrival result and congestion observations;
- preparation-loop traversal time;
- longest dead-travel segment;
- landmark recognition at 32 / 128 / 512 studs;
- visible ambient-cost census by quality tier;
- post-warmup streaming hitch duration;
- cleanup baseline/start/peak/end values and drift percentage;
- desktop Full median and p95 frame time;
- MinimumReadable mobile p95 frame time;
- four-player instance/memory/render/network census;
- static replication churn per minute;
- actual streaming configuration used by the run.

Do **not** choose or bless streaming radii, `ModelStreamingMode`, quality reductions or content density merely to make the runbook look complete. If a measured failure points to one of those settings, open a bounded FIX NOW change, validate it, build a new artifact, and create a new evidence packet for the rerun.

## 9. Defect handling

For each reproducible defect record:

- severity;
- BA-014 check ID;
- exact artifact SHA/source commit;
- device/quality profile;
- server/client count;
- reproduction steps;
- expected behavior;
- observed behavior;
- logs/screenshots/video/profile references;
- suspected canonical owner;
- fix PR/commit if known;
- rerun packet reference.

A blocking `Fail` preempts Main World environment breadth. Fix the smallest source-owned cause; do not compensate by adding unrelated scenery or resurrecting recovered runtime.

## 10. Acceptance decision

The run may promote Main World acceptance only when:

- the identity record is complete;
- every required BA-014 check has a result for the exact artifact;
- every blocking check evaluates `Pass` through the source matrix;
- required record-only evidence is captured;
- no unresolved blocker/high-severity authority or lifecycle defect invalidates the run;
- the evidence packet links all required captures/profiles/logs;
- the rollback checkpoint is recorded.

If the matrix does not accept the run, record why and keep Patch 0.5 verification pending.

## 11. Resume conditions

- **Bridge blocked:** repair/reconnect the exact Studio evidence path, then start a new packet.
- **Blocking BA-014 failure:** implement the smallest FIX NOW change, merge only when repository validation is green, then build a new artifact and rerun.
- **All blocking checks pass:** execution authority may advance to the next smallest evidence-backed Main World family; activation/publishing and inter-place transport remain separately gated.

> This document makes the run repeatable. Only a completed evidence packet can make the run real.
