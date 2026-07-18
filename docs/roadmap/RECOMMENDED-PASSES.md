# Living Kingdoms — Recommended and Suggested Passes

## Purpose

Throughout the canon, a **pass** is a bounded production sweep over one concern —
an art pass, an audio pass, a tuning pass, an accessibility pass — executed once
its prerequisites exist and reviewed against its own gates. Recommendations for
future passes are scattered across the roadmap, specifications, and the asset
registry. This document collects every pass the project currently recommends,
suggests, or defers, with its source, gating milestone or track, and status.

**This document is descriptive only.** It controls no task IDs, dependencies,
execution order, or acceptance gates. [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md)
controls unfinished gameplay tasks and [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md)
controls presentation sequencing; when this list drifts from them, they win.

## A. Recommended and pending passes

### Audio passes

| Pass | What it covers | Source | Gate / track | Status |
|---|---|---|---|---|
| Production firearm audio pass | Approved fire, reload, empty, and handling set owned by `WeaponAudioController`. AUD-0102 completed client-local coverage of all four cues (empty click on authoritative dry transitions, handling cue on reload completion, reload stop-on-interrupt); unique production-approved empty/handling assets and the Studio mix review remain the outstanding gates. | [`../specifications/firearm-audio.md`](../specifications/firearm-audio.md); `VisualAssetConfig.luau` (`AudioBasicFirearm` = `TemporaryPresentation`) | VIS-0102 | In progress |
| Standard-hostile audio pass | Approved alert, pursuit, attack, hit, and death set for the Exclusion Walker, owned by `EnemyAudioController`. AUD-0103 completed bounded client-local coverage of all five cues from replicated presentation attributes; unique production-approved hostile assets and the Studio mix review remain the outstanding gates. | [`../specifications/enemy-audio.md`](../specifications/enemy-audio.md); [`../specifications/visual-placeholder-inventory.md`](../specifications/visual-placeholder-inventory.md) | VIS-0103 | In progress |
| World ambience audio-content pass | Wind, insects, wildlife, distant sirens, helicopters, and radio chatter; thunder for the distant-storm flash. Deferred until approved source assets and a mix budget exist. | [`../specifications/living-kingdoms-world-foundation.md`](../specifications/living-kingdoms-world-foundation.md) | VIS-0105 / VIS-0108 | Deferred |

### Art, effects, and presentation passes

| Pass | What it covers | Source | Gate / track | Status |
|---|---|---|---|---|
| Final world art pass | Primitive tree crowns, buildings, vehicles, rocks, tents, and signs are composition references "for a later art pass, not final assets"; landmark labels may be reduced during this pass. | [`../specifications/living-kingdoms-world-foundation.md`](../specifications/living-kingdoms-world-foundation.md) | VIS-0105 | Pending |
| Authored-place conversion pass | Converting the runtime-generated graybox world into an authored place while preserving stable landmark IDs and route intent. | [`../specifications/living-kingdoms-world-foundation.md`](../specifications/living-kingdoms-world-foundation.md) | After world art approval | Suggested |
| Burning-wreckage effects pass | VFX wreckage and burning-wreckage particles, deferred until an effects budget and authored assets exist; emergency light stands in today. | [`../specifications/living-kingdoms-world-foundation.md`](../specifications/living-kingdoms-world-foundation.md) | Effects budget | Deferred |
| Firearm presentation completion | Studio import/readability review, final effects and audio, and performance evidence for the existing model, state motion, and temporary shot effects. | [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) | VIS-0102 | In progress |
| Standard-hostile presentation completion | Canonical swap of the Exclusion Walker silhouette plus effects, audio, and horde performance evidence. | [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) | VIS-0103 | In progress |
| Operative and class presentation completion | Canonical rig/animation, class-action cues, avatar-scale review, and squad performance evidence over the existing silhouettes, life-state cues, and carry poses. | [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) | VIS-0104 | In progress |
| World and interactable material replacement pass | Cache, relay, extraction, routes, and landmark material replacement after the pending Studio visual/accessibility/performance review. | [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) | VIS-0105 review gate | Blocked on review |
| Special enemy and boss visual pass | The special-enemy and boss presentation package. | [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) | VIS-0106, after P9 contracts | Blocked |
| Cosmetic-variant pass | A very small earned/default variant set limited to the basic firearm, operative body/equipment, the three starting-class sets, and hostile non-gameplay surface variation. | [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md); [`../specifications/visual-placeholder-inventory.md`](../specifications/visual-placeholder-inventory.md) | VIS-0107, after canonical fallbacks and P11 | Blocked |
| Release-candidate closure pass | Final UI, ambience, accessibility, and performance polish closing the visual track. | [`VISUAL-PRODUCTION-TRACK.md`](VISUAL-PRODUCTION-TRACK.md) | VIS-0108, with P12 | Blocked |

**Recorded anti-recommendation:** the visual track's current decision gate is
explicit — *"Do not add another broad procedural-geometry pass before Roblox
Studio review."* The next world-presentation step is review of the existing
VIS-0102–VIS-0105 output from the gameplay camera, not more generated geometry.

### Tuning passes

| Pass | What it covers | Source | Gate / track | Status |
|---|---|---|---|---|
| P6 scarcity tuning pass(es) | Smallest evidence-supported ammunition adjustments after the 1/2/4-operative evidence matrix, changing "one logical lever per tuning pass where practical," with re-runs and locked final values. | [`../specifications/ammunition-scarcity-and-supply.md`](../specifications/ammunition-scarcity-and-supply.md) | P6-0109, blocked on P6-0108 evidence | Blocked |
| Pressure-scaling tuning pass | Solo-to-four-player pressure scaling; evidence-supported configuration adjustments only, avoiding fixed player slots. | [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) | P12-0102 | Not started |
| Class-dependence tuning pass | Balanced squads gain materially better options while solo and duplicate-role squads keep a difficult but possible path. | [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) | P12-0103 | Not started |
| Pacing tuning pass | Aligned ammunition, medical, objective, recovery, defense, disruption, and climax pacing without dominant camping routes or predetermined starvation. | [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) | P12-0104 | Not started |

### Audit and quality passes

| Pass | What it covers | Source | Gate / track | Status |
|---|---|---|---|---|
| Performance profiling and optimization pass | Horde, special-enemy, boss, visibility, and UI load; measure first, then focused changes to cadence, budgets, instances, replication, rendering, and cleanup. | [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) | P12-0105 | Not started |
| Accessibility and readability pass | Redundant text/shape/position/timing cues, readable contrast, understandable controls, and non-audio-only warnings across every critical state. | [`MASTER-ROADMAP.md`](MASTER-ROADMAP.md); [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) | P12-0106 | Not started |
| Fixed-four-player assumption audit pass | Sweep every contract, roster, spawn, UI, scaling, result, persistence, and cleanup path for fixed slots; add synthetic-identity tests beyond four. | [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) | P12-0107 | Not started |
| Full security and regression audit pass | Re-run every client abuse case across all systems; prove no client can establish consequential state and no owner leaks after replay or shutdown. | [`P6-P12-EXECUTION-ROADMAP.md`](P6-P12-EXECUTION-ROADMAP.md) | P12-0108 | Not started |

## B. Completed passes (history)

- **P5-0102 readability and landmark-identity pass** — gameplay-camera
  readability, landmark identity, and authored segment clearance over the
  P5-0101 world ([`../specifications/living-kingdoms-world-foundation.md`](../specifications/living-kingdoms-world-foundation.md)).
- **HROI-ENV-001 environment mood pass** — presentation-only threat-responsive
  ambience owned by `EnvironmentAmbienceController`; still registered as
  temporary presentation pending the ambience audio-content pass.
- **Enemy-pressure runtime tuning pass** — faster first contact, grouped fills
  to the existing population ceiling, detection-range pressure spawns, and
  reduced walker health without raising caps
  ([`../specifications/enemy-pressure-runtime.md`](../specifications/enemy-pressure-runtime.md)).
- **Horde progression-pacing pass** — removed opening pressure overlap without
  weakening enemy combat or server authority
  ([`../specifications/horde-progression-pacing.md`](../specifications/horde-progression-pacing.md)).
- **Horde single-source-of-truth stabilization pass** — consolidated progression
  into a single authoritative owner
  ([`../specifications/horde-single-source-of-truth.md`](../specifications/horde-single-source-of-truth.md)).
- **Horde role readability pass** — six visually distinct role presentations
  composed over the shared 18-part Exclusion Walker shell by rescaling only
  massless non-colliding presentation parts; the Studio isometric-separation,
  color-vision, and representative-performance review remains the VIS-0103
  acceptance gate
  ([`../specifications/horde-role-readability.md`](../specifications/horde-role-readability.md)).
- **Horde special-role telegraph pass** — short server-owned warning windows,
  exact-radius Bloater disclosure, pooled world presentation, and role-specific
  warning audio for Screamer reinforcement, Bloater burst, and Brute phase two
  ([`../specifications/horde-special-role-telegraphs.md`](../specifications/horde-special-role-telegraphs.md)).

## C. Explicitly excluded

A **battle pass** is a monetization construct, not a production sweep, and the
canon excludes it from the MVP alongside paid power
([`../bible/01-mvp.md`](../bible/01-mvp.md),
[`../specifications/visual-asset-production.md`](../specifications/visual-asset-production.md),
[`../specifications/run-field-xp.md`](../specifications/run-field-xp.md)). It is
listed here only so the term is not confused with the passes above.
