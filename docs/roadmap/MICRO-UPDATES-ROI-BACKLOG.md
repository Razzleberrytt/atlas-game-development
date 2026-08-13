# Living Kingdoms — 100 Micro Updates by ROI

**Status:** active ranked micro-update queue  
**Updated:** 2026-08-13  
**Scoring rule:** player value and defect prevention first, then dependency removal, reuse, effort, and verification cost. Re-rank after each five-item pass when repository truth changes.

Status: `DONE` · `NEXT` · `QUEUED` · `GATED`

| Rank | Status | Micro update | Primary return |
|---:|---|---|---|
| 1 | DONE | Add room-ID lookup to composition debug readback | Faster live mismatch diagnosis |
| 2 | DONE | Add aggregate original/applied/delta unit totals | Immediate balance visibility |
| 3 | DONE | Add deterministic whole-composition identity | Reliable replay comparison |
| 4 | DONE | Mount composition readback in the server-only live runtime | Observe actual active composition |
| 5 | DONE | Add server-only `ReadRunVariationComposition` action | Make diagnostics reachable without client authority |
| 6 | DONE | Clear composition readback on every stop/failure path | Prevent stale-run diagnostics |
| 7 | DONE | Regression-test live readback lifecycle | Lock start/read/stop behavior |
| 8 | DONE | Bind readback identity to active run ID | Distinguish concurrent/replayed runs |
| 9 | DONE | Report composed encounter count | Spot missing rooms instantly |
| 10 | DONE | Report modified encounter count | Quantify modifier reach |
| 11 | DONE | Add per-slot aggregate unit deltas | Find pressure concentration |
| 12 | DONE | Add per-archetype aggregate unit deltas | Detect roster skew |
| 13 | DONE | Fail closed on authored encounter/view cardinality mismatch | Prevent partial composition |
| 14 | DONE | Fail closed on duplicate encounter slot within a room | Prevent ambiguous spawning |
| 15 | DONE | Validate composition identity during runtime bootstrap | Catch drift before play |
| 16 | DONE | Add zero-encounter readback coverage | Protect noncombat rooms |
| 17 | DONE | Add no-modifier readback coverage | Protect baseline runs |
| 18 | DONE | Add multi-wave aggregate regression fixture | Protect current Patch 0.6 path |
| 19 | DONE | Add composition failure reason IDs | Faster actionable logs |
| 20 | DONE | Bound diagnostic string sizes | Avoid oversized debug payloads |
| 21 | DONE | Add active-room composition lookup | Support room-scoped debugging |
| 22 | DONE | Expose selected-wave identity in active context | Trace wave choice quickly |
| 23 | DONE | Bind spawned wave to composition identity | Prove runtime uses planned content |
| 24 | DONE | Audit spawned unit totals against composition | Detect runtime plan drift |
| 25 | DONE | Add one-shot warning for composition drift | Surface defects without log spam |
| 26 | DONE | Add deterministic modifier summary text | Easier QA screenshots |
| 27 | DONE | Add encounter intensity summary text | Easier balance review |
| 28 | DONE | Add readback schema version constant | Safer future tooling |
| 29 | DONE | Add identity escaping for delimiter-bearing IDs | Prevent ambiguous signatures |
| 30 | DONE | Add stable record sorting assertion | Preserve reproducible replay |
| 31 | DONE | Add run seed copy/paste debug command | Quicker reproduction |
| 32 | DONE | Add last-start failure readback | Diagnose rejected launches |
| 33 | DONE | Add placement failure cleanup regression | Prevent orphaned state |
| 34 | DONE | Add variation planning failure cleanup regression | Prevent stale bootstrap state |
| 35 | DONE | Add encounter-view failure cleanup regression | Prevent partial active runs |
| 36 | DONE | Reset barrier state on creation failures | Avoid cross-run leakage |
| 37 | DONE | Validate run ID normalization | More stable telemetry keys |
| 38 | DONE | Reject whitespace-only run IDs | Close malformed diagnostic identity |
| 39 | DONE | Add active seed to server debug response | Faster replay setup |
| 40 | DONE | Add room-plan identity to server debug response | Faster source comparison |
| 41 | DONE | Add modifier ID to encounter debug records | Remove cross-reference work |
| 42 | DONE | Add secret-branch presence to run summary | Full variation visibility |
| 43 | DONE | Add optional-objective presence to run summary | Full variation visibility |
| 44 | DONE | Add composition duration timing in development mode | Spot expensive planning |
| 45 | DONE | Add maximum composition-time fixture budget | Guard server startup cost |
| 46 | DONE | Cache immutable authored encounter lookup | Reduce repeated indexing |
| 47 | DONE | Centralize composition identity formatting | Lower extension cost |
| 48 | DONE | Centralize variation debug schema | Lower diagnostic drift |
| 49 | DONE | Document Patch 0.6 debug actions | Improve operator speed |
| 50 | DONE | Add debug action source audit | Keep diagnostics server-only |
| 51 | DONE | Add current encounter phase to readback | Improve live triage |
| 52 | DONE | Add current room ID to readback | Improve live triage |
| 53 | DONE | Add active wave index to readback | Improve live triage |
| 54 | NEXT | Add remaining authored waves count | Improve pacing diagnosis |
| 55 | QUEUED | Add encountered/completed room counters | Improve run progress diagnosis |
| 56 | QUEUED | Add no-active-run explicit diagnostic result | Remove nil ambiguity |
| 57 | QUEUED | Add stopped-service explicit diagnostic result | Remove nil ambiguity |
| 58 | QUEUED | Add stale-run readback rejection | Prevent cross-run inspection mistakes |
| 59 | QUEUED | Bind debug action to expected run ID | Safer internal tooling |
| 60 | QUEUED | Rate-limit internal diagnostic requests | Bound accidental churn |
| 61 | QUEUED | Add deterministic dense-contact fixture seeds | Faster balance QA |
| 62 | QUEUED | Add deterministic quiet-contact fixture seeds | Faster balance QA |
| 63 | QUEUED | Add deterministic no-variation fixture seeds | Baseline comparison |
| 64 | QUEUED | Add boss immutability composition audit | Protect authored climax |
| 65 | QUEUED | Add empty-room immutability composition audit | Protect navigation rooms |
| 66 | QUEUED | Add minimum-retained-units diagnostic detail | Faster failure diagnosis |
| 67 | QUEUED | Add selected unit-group index to readback | Explain count changes |
| 68 | QUEUED | Add selected archetype ID to readback | Explain roster changes |
| 69 | QUEUED | Add per-wave original/applied totals | Explain multi-wave changes |
| 70 | QUEUED | Add per-wave identity to record | Pinpoint replay drift |
| 71 | QUEUED | Add content source IDs to record | Trace spawn/reward ownership |
| 72 | QUEUED | Audit reward source remains unchanged | Protect economy authority |
| 73 | QUEUED | Audit spawn source remains unchanged | Protect enemy authority |
| 74 | QUEUED | Add immutable nested readback audit | Prevent diagnostic mutation |
| 75 | QUEUED | Copy caller-owned room plan inputs in debug fixtures | Guard purity |
| 76 | QUEUED | Add malformed node index rejection | Fail fast on corrupted plans |
| 77 | QUEUED | Add missing room ID rejection | Fail fast on corrupted plans |
| 78 | QUEUED | Add missing encounter slot rejection | Fail fast on corrupted content |
| 79 | QUEUED | Add invalid intensity rejection | Fail fast on corrupted content |
| 80 | QUEUED | Add invalid unit count rejection | Fail fast on corrupted content |
| 81 | QUEUED | Add seed boundary fixtures | Protect runtime limits |
| 82 | QUEUED | Add party-size boundary fixtures | Protect launch validation |
| 83 | QUEUED | Add repeated start idempotency fixture | Prevent duplicate runs |
| 84 | QUEUED | Add repeated stop idempotency fixture | Prevent cleanup errors |
| 85 | QUEUED | Add repeated service start fixture | Prevent duplicate heartbeat |
| 86 | QUEUED | Add repeated service stop fixture | Prevent connection leaks |
| 87 | QUEUED | Preserve step remainder instead of dropping excess delta | More stable low-FPS cadence |
| 88 | QUEUED | Cap catch-up steps per heartbeat | Prevent frame spirals |
| 89 | QUEUED | Add heartbeat catch-up regression | Protect server pacing |
| 90 | QUEUED | Add active-run cleanup after terminal outcome | Reduce stale runtime time |
| 91 | QUEUED | Add terminal composition summary snapshot | Improve completed-run review |
| 92 | QUEUED | Add outcome ID to terminal summary | Improve completed-run review |
| 93 | QUEUED | Add elapsed run seconds to terminal summary | Improve pacing review |
| 94 | QUEUED | Add rooms completed to terminal summary | Improve funnel review |
| 95 | QUEUED | Add modifier outcome correlation fields | Support later balancing |
| 96 | QUEUED | Add optional objective outcome field | Support later balancing |
| 97 | QUEUED | Add secret discovery outcome field | Support later balancing |
| 98 | GATED | Show run modifier on player HUD | Player clarity; needs UI/Studio verification |
| 99 | GATED | Show optional objective variation on HUD | Player clarity; needs UI/Studio verification |
| 100 | GATED | Show post-run variation recap | Replay motivation; needs UX/Studio verification |

## Pass rule

Implement ranks in groups of five when they remain dependency-safe. Each pass must use the smallest truthful risk tier, add focused regression coverage, run the required validation profile, and leave Studio-only claims as **BUILT — VERIFICATION PENDING**.
