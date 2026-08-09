# Main World acceptance matrix

**Roadmap ticket:** BA-014

**Lane:** controlled build-ahead, Main World / Hub Track 1

**Status:** matrix defined; no run recorded, no Main World content accepted

**Evidence level:** E1 definition only — defining acceptance does not raise the evidence level

**Playable-patch mapping:** Gate 0 / Patch 0.5 acceptance instrument; not an MVP 0.1 prerequisite

**Runtime behavior:** none

## Decision

Main World acceptance is a **repeatable measured run**, not a reviewer's
impression. BA-010 produced a Studio checklist and BA-013 produced provisional
budgets; neither can be executed twice and compared. BA-014 turns both into 31
named checks with explicit thresholds, capture modes, device profiles and
required evidence artifacts, locked in
[`MainWorldAcceptanceMatrixConfig.luau`](../../games/living-kingdoms/src/shared/Config/MainWorldAcceptanceMatrixConfig.luau)
and validated by `tests/MainWorldAcceptanceMatrixConfig.test.luau`.

The matrix ships **unrun**. Every check carries `status = "NotRun"`, the
committed table is frozen, and `isActivationAcceptable()` with no argument
returns `false`. Nothing in BA-014 creates geometry, Terrain, streaming,
lighting, audio, placement, prompts, networking, persistence or any Main World
runtime.

Recorded outcomes never live in the definition. A Studio run produces a separate
`RunRecord` (`identity` plus `results` keyed by check ID), and `evaluateRun`
decides it against these definitions, returning `accepted` plus a reason for
every rejection. So the contract that describes acceptance can never also claim
to have passed it, and the gate is still a real evaluator rather than a constant
`false`.

## Why a config and not only a document

The BA-010 checklist is prose, so its items cannot be counted, cross-checked or
diffed between runs. Encoding the matrix as source gives three properties a
document cannot:

1. **Cross-contract references resolve.** Every streaming group a check names
   must exist in BA-011's `MainWorldRepresentationConfig`, and every interaction
   anchor must exist in BA-012's `HubInteractionConfig`. A renamed group or a
   deleted anchor fails the fixture instead of silently orphaning a check.
2. **Coverage is provable.** All five BA-011 semantic streaming groups are
   covered by at least one check, all seven BA-010 composition beats have a
   fixed camera, and all three quality tiers have a capture mode.
3. **An unrun matrix cannot be cited as acceptance.** The gate is a function,
   not a claim in prose. It rejects until a run record supplies a complete
   identity, a result for every check, and `Pass` on every blocking check.

## Result vocabulary

| Status | Meaning |
|---|---|
| `NotRun` | The check has never been executed against a recorded build. |
| `Pass` | Executed and met its requirement on the recorded build. |
| `Fail` | Executed and observed a real defect. |
| `Blocked` | Evidence transport failed; the check never observed the build. |
| `Invalid` | Executed, but the run's identity record is incomplete. |

`Blocked` is deliberately distinct from `Fail`. The 2026-08-09 first-run repair
attempt is the reference case: the Studio MCP bridge never registered the exact
artifact, so no gameplay was observed. That outcome is neither a pass nor a
defect, and recording it as either would corrupt the evidence chain.

## Run identity

A result is evidence only when the run records all of:

```text
captureDateAndTimezone      operator                repositoryCommit
rojoVersion                 studioVersion           placeFileName
placeArtifactSha256         mainWorldPlaceIdentity  serverAndClientCount
deviceProfileId             graphicsQualityLevel    featureFlagState
rollbackCheckpointCommit
```

A run missing any of these is `Invalid`, not `Pass`. Per
[`../production/V2.7-EVIDENCE-PACKET-TEMPLATE.md`](../production/V2.7-EVIDENCE-PACKET-TEMPLATE.md),
each run produces a **new** packet pinned to its exact build; an older packet is
never edited to fit a later result.

## Capture geometry

Seven fixed cameras, one per BA-010 composition beat, are reused across every
quality tier so tier captures are directly comparable:

```text
camera.arrival_threshold     camera.orientation_center   camera.preparation_ring
camera.interaction_edge      camera.adventure_gate       camera.exploration_branch
camera.return_seam
```

Camera transforms are assigned when the composition exists. BA-014 does not
invent coordinates.

| Capture mode | Quality tier | Aspect |
|---|---|---|
| `capture.neutral_editor` | Full | editor |
| `capture.gameplay_full` | Full | desktop 16×9 |
| `capture.gameplay_reduced` | Reduced | desktop 16×9 |
| `capture.gameplay_minimum` | MinimumReadable | desktop 16×9 |
| `capture.mobile_portrait` | MinimumReadable | mobile portrait |
| `capture.mobile_landscape` | MinimumReadable | mobile landscape |

| Device profile | Quality tier | Hardware identity |
|---|---|---|
| `DesktopReference` | Full | recorded per run, never assumed |
| `LowGraphicsDesktop` | Reduced | recorded per run, never assumed |
| `MobileMinimum` | MinimumReadable | recorded per run, never assumed |

Portrait and landscape are separate capture modes on purpose. A single "mobile"
mode would let one image satisfy a requirement meant to expose
orientation-specific composition and safe-area failures, so the two
orientation-sensitive checks —
`mwam.readability.landmark_recognition_distance` and
`mwam.visual.fixed_camera_capture_set` — require both.

Landmark recognition is tested at 32, 128 and 512 studs. BA-010 requires
near/mid/far review but names no distances, so those three values are invented
here and carry `ba-014-authoring-target` provenance like any other unmeasured
starting line.

## Thresholds and their provenance

Every threshold records where its number came from, so inherited targets stay
visibly separate from starting lines invented here.

| Threshold | Value | Direction | Provenance |
|---|---:|---|---|
| `OrientationRecognitionSeconds` | 10 s | at most | BA-010 checklist |
| `SimultaneousArrivalPlayers` | 4 | at least | BA-010 checklist |
| `ReadableChannelsPerMajorDestination` | 2 | at least | BA-010 checklist |
| `DesktopFullMedianFrameMs` | 16.7 ms | at most | BA-013 provisional |
| `DesktopFullP95FrameMs` | 25.0 ms | at most | BA-013 provisional |
| `MobileMinimumReadableP95FrameMs` | 33.3 ms | at most | BA-013 provisional |
| `PostWarmupStreamingHitchMs` | 100 ms | at most | BA-013 provisional |
| `CleanupDriftPercent` | 5 % | at most | BA-013 provisional |
| `TraversalCycleMinutes` | 10 min | at least | BA-013 provisional |
| `StaticReplicationChurnPerMinute` | 0 | at most | BA-013 provisional |
| `CharacterReleaseBeforeRequiredContent` | 0 | at most | BA-013 provisional |
| `PreparationLoopSeconds` | 60 s | at most | **BA-014 authoring target** |
| `DeadTravelSegmentSeconds` | 8 s | at most | **BA-014 authoring target** |
| `WarmupSeconds` | 30 s | at least | **BA-014 authoring target** |
| `SteadyCaptureSeconds` | 60 s | at least | **BA-014 authoring target** |

The four `ba-014-authoring-target` thresholds, plus the three recognition
distances above, are unmeasured starting lines. The first recorded run is
expected to revise them; they carry no more authority than that label gives
them. `ReadableChannelsPerMajorDestination = 2` is *not* one of them — it is
inherited from BA-010's navigation rules ("at least two readable channels among
silhouette, path alignment, signage, light, audio and UI fallback").

BA-013's provisional values are likewise starting budgets, not device evidence —
a failure lowers density or splits units rather than being excused.

The BA-013 visible-scene ceilings are carried forward verbatim, and the fixture
asserts each lower tier only ever reduces cost:

| Ambient cost | Full | Reduced | Minimum readable |
|---|---:|---:|---:|
| Visible enabled local dynamic lights | 16 | 8 | 4 |
| Visible shadow-casting local lights | 1 | 0 | 0 |
| Visible ambient particle emitters | 12 | 6 | 0 |
| Estimated live ambient particles | 300 | 120 | 0 |
| Client-animated decorative parts | 32 | 16 | 0 |
| Audible localized environment emitters | 4 | 2 | 1 |
| Steady-state ambient / music beds | 1 + 1 | 1 + 1 | 1 + 0 |

These bound optional ambient presentation visible to one client. They never
bound combat telegraphs or canonical gameplay state.

## The matrix

`Blocking` checks gate Main World activation. `Threshold` checks compare against
a named threshold or tier ceiling, `Binary` checks are met or not, and
`RecordOnly` checks produce required evidence but have no pass/fail line yet —
the config forbids a `RecordOnly` check from being blocking.

### Arrival and flow

| Check | Decided by | Blocking |
|---|---|:--:|
| `mwam.arrival.destination_matrix` — cold join, respawn, success, failure and replay-decline each land at the intended anchor and facing | Binary | yes |
| `mwam.arrival.four_player_simultaneous` — four players spawn at once without overlap, fall-through, blocked camera or prompt contention | `SimultaneousArrivalPlayers` | yes |
| `mwam.arrival.orientation_recognition` — landmark and adventure direction identified from the gameplay camera without a menu | `OrientationRecognitionSeconds` | yes |
| `mwam.arrival.preparation_reachability` — class, loadout and expedition anchors reachable without dead ends | Binary | yes |
| `mwam.arrival.return_debrief_context` — return presents result, reward and replay context | Binary | yes |
| `mwam.arrival.character_release_gating` — no character released before required arrival content exists | `CharacterReleaseBeforeRequiredContent` | yes |

### Navigation and composition

| Check | Decided by | Blocking |
|---|---|:--:|
| `mwam.navigation.core_loop_traversal` — the preparation loop stays compact | `PreparationLoopSeconds` | no |
| `mwam.navigation.dead_travel` — no long stretch without a decision, landmark or interaction | `DeadTravelSegmentSeconds` | no |
| `mwam.navigation.multiplayer_congestion` — four-player congestion points enumerated | RecordOnly | no |
| `mwam.navigation.boundary_and_metrics` — boundaries read as geography; no false cover, invisible blocker or camera clip | Binary | yes |
| `mwam.navigation.optional_branch_payoff` — branches pay off and loop back | Binary | no |

### Landmark and readability

| Check | Decided by | Blocking |
|---|---|:--:|
| `mwam.readability.landmark_recognition_distance` — landmarks identifiable at 32/128/512 studs in all three tiers | Binary | yes |
| `mwam.readability.independent_channels` — two independent recognition channels; no color-only critical cue | `ReadableChannelsPerMajorDestination` | yes |
| `mwam.readability.cues_under_atmosphere` — route, prompt, hostile and objective cues survive fog, bloom and particles | Binary | yes |
| `mwam.readability.minimum_tier_preserves_meaning` — Minimum-readable removes cost, never meaning | Binary | yes |

### Visual environment

| Check | Decided by | Blocking |
|---|---|:--:|
| `mwam.visual.fixed_camera_capture_set` — the complete camera × mode capture set exists for the run | Binary | yes |
| `mwam.visual.geometry_defects` — no terrain seam, floating prop, silhouette collision or scale break | Binary | no |
| `mwam.visual.environment_profile_ownership` — one profile owns global Lighting across day/night, corruption and expedition transitions | Binary | yes |
| `mwam.visual.ambient_ceilings` — visible ambient cost inside the active tier ceiling | tier ceilings | yes |

`mwam.visual.environment_profile_ownership` exists because BA-010 found four
layers writing `Lighting` — `WorldFoundationService`, `NightCorruptionService`,
`EnvironmentAmbienceController` and `ExpeditionAtmosphereController` — with no
single profile owner and a possible restore race between server updates and a
client's remembered expedition values. That is exactly the class of defect no
source gate can observe.

### Audio

| Check | Decided by | Blocking |
|---|---|:--:|
| `mwam.audio.asset_permission` — every environment audio asset is permission-verified before its ID enters source | Binary | yes |
| `mwam.audio.crossfade_and_reentry` — rapid zone re-entry produces no pop, stacking or unintended silence | tier ceilings | yes |
| `mwam.audio.mix_review` — hub, interaction, transition and debrief mix reviewed together | RecordOnly | no |
| `mwam.audio.accessibility` — no critical fact is audio-only; environment volume separately controllable | Binary | yes |

### Streaming and lifecycle

| Check | Decided by | Blocking |
|---|---|:--:|
| `mwam.streaming.semantic_group_rebind` — every group streams out and rebinds by stable ID with no orphan | Binary | yes |
| `mwam.streaming.no_completion_on_stream_out` — stream-out never completes, cancels or mutates semantic state | Binary | yes |
| `mwam.streaming.hitch_budget` — no post-warmup transition exceeds the hitch budget | `PostWarmupStreamingHitchMs` | yes |
| `mwam.lifecycle.cleanup_drift` — a full traversal-and-return cycle returns to baseline | `CleanupDriftPercent` | yes |

### Performance and memory

| Check | Decided by | Blocking |
|---|---|:--:|
| `mwam.performance.desktop_full_traversal` — desktop median and p95 frame time targets | `DesktopFullMedianFrameMs`, `DesktopFullP95FrameMs` | yes |
| `mwam.performance.mobile_minimum_traversal` — lowest supported mobile p95 target | `MobileMinimumReadableP95FrameMs` | yes |
| `mwam.performance.four_player_census` — instance, memory, render and network census for a four-player join and traversal | RecordOnly | no |
| `mwam.performance.static_replication_churn` — loaded static content stops replicating | `StaticReplicationChurnPerMinute` | yes |

## What this matrix cannot do

- It cannot promote the Main World runtime. Activation remains controlled by
  Blueprint v2.7 gates and a later integration ticket that records its own
  rollback checkpoint.
- It cannot substitute for the MVP 0.1 STOP / PLAY / FIX pass. MVP 0.1 needs
  only the smallest coherent preparation/return surface; BA-014 must never
  become a prerequisite for it.
- It cannot be satisfied by CI. Every check requires Studio observation, and
  the repository gates can see none of them.
- It cannot accept its `ba-014-authoring-target` values as validated. They are
  starting lines awaiting their first measurement.

## Open dependency

Running this matrix requires a working Studio evidence path. The last recorded
attempt on any build,
[`../production/evidence/2026-08-09-mvp01-first-run-repair-studio-bridge-blocked.md`](../production/evidence/2026-08-09-mvp01-first-run-repair-studio-bridge-blocked.md),
was `INVALID` because the exact artifact never registered with the Studio MCP
proxy. Until that transport is repaired, every check in this matrix can only be
recorded as `Blocked`. Repairing it is the human/Studio lane's task, not a
build-ahead one.

BA-014's checks also assume placement exists for the anchors BA-012 left
unassigned (`hub.anchor.character`, `hub.anchor.inventory`, `hub.anchor.skills`
and the held authored-world anchors). Those anchors are not covered by
`mwam.arrival.preparation_reachability`, which binds only the three enabled
Forward Operations bridge anchors; extending it is part of the placement work,
not of this matrix.

## Completion boundary

BA-014 is complete at E1 when this matrix, its config lock and its fixture are
green. It records no result, accepts no content and advances no evidence level.
Main World Track 1 (BA-010 → BA-011 → BA-012 → BA-013 → BA-014) is complete as
a preparation sequence; the next Main World step is measurement, which belongs
to the human/Studio lane and to a later gated integration ticket.
