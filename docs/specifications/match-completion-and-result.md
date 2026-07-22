# Match completion, failure, extraction, and replay — P10-PLAN-001

The plan for P10. It turns the existing mission terminal state — today a single
`resolveMission(Success|Failure)` boundary driven by a holdout timer and the
squad-failure subscription — into a **complete player-facing match loop**: a
final extraction that pays off the P9 boss climax, one authoritative
success/failure result with an understandable cause, server-authored result and
contribution facts (which P11 will weight into XP), deterministic cleanup across
every runtime owner, a safe replay path with a fresh operation identity, and
explicit leave/disconnect/rejoin behavior.

This document is the planning gate. It fixes the terminal causes, the result and
contribution vocabulary, the extraction sequence, cleanup ownership, replay
behavior, the leave/disconnect/rejoin policy, and disclosure. It does **not** add
code — those are `P10-0101` through `P10-0107`. Every constant named here is
authoring intent for the first pass, tunable from evidence in P12.

## Design constraints inherited from the milestone

- **One terminal boundary.** The operation resolves **exactly once**. The existing
  `MissionDirectorService.resolveMission` is already first-commit-wins
  (`if phaseId == Resolved then return`); `P10-0102` extracts this into one
  dedicated authoritative terminal-result resolver that **every** terminal cause
  converges on, so duplicate or racing causes cannot produce two results.
- **Server owns every result fact.** Clients receive only a validated safe result
  snapshot (extending today's `SafeMissionSnapshot`) and may never establish the
  outcome, cause, contribution, or timing.
- **Reuse the existing owners.** The five-phase machine
  (`Insertion → Infiltration → Exfiltration → Holdout → Resolved`),
  `SquadFailureService`, `EnemyDirectorService`, `ClassService`,
  `OperativeLifeService`, `RunProgressionService`, `AmmunitionCacheService`, and
  the objective runtime already own their state. P10 adds the terminal resolver,
  the extraction sequence, the result/contribution record, and the replay reset —
  it does not fork a parallel operation authority.
- **No persistent power in P10.** Result and contribution facts are recorded and
  disclosed, but no XP, rank, or unlock is awarded or promised — that is P11.
  The result screen must never claim an unconfirmed reward.
- **Bridge the P9 deferral.** P9-0104 deferred converging the boss-defeat outcome
  into the terminal boundary to `P10-0102`; this plan makes boss defeat the
  authored success path.

## Terminal causes (all converge on one resolver)

Today the operation resolves from two places (the holdout timer and the
squad-failure subscription). P10 keeps the single boundary but gives every
resolution an explicit, disclosed **cause** alongside the existing
`Success`/`Failure` outcome. First pass vocabulary (`P10-0101`):

| Outcome | Cause (`MissionResultCauseId`) | When |
| --- | --- | --- |
| `Success` | `Extracted` | The Progenitor is defeated and the squad completes the extraction sequence. |
| `Failure` | `SquadWipe` | `SquadFailureService` commits a squad wipe after its grace window (any phase). |
| `Failure` | `Abandoned` | Every operative disconnects (authoritative abandonment). |

- **Boss defeat is the win condition.** The holdout is no longer won by a bare
  timer: the squad must defeat the boss (`EnemyDirectorService.readBossState().isDefeated`),
  which begins the extraction sequence. This finally wires the P9-0104 deferral.
- **One failure family, unchanged authority.** Failure still originates only from
  `SquadFailureService` (wipe) or authoritative abandonment. Objectives remain
  non-terminal (P8), and no new terminal-failure cause is invented.
- **Determinism.** If two causes could commit on the same evaluation (e.g., the
  last operative is downed on the same pass the boss dies), the terminal resolver
  applies a fixed precedence — a committed **squad wipe outranks** a pending
  extraction, because a dead squad cannot extract — and commits exactly one
  result.

## The final extraction sequence (`P10-0103`)

The holdout at the Extraction Clearing becomes a readable climax-and-payoff:

1. **Holdout / boss fight.** The squad holds the clearing and fights The
   Progenitor (P9). Roaming and the boss's Brood surges pressure them.
2. **Boss defeated → extraction inbound.** On the boss's authoritative defeat, the
   mission enters a short **extraction arrival window** (target ~15 s, first pass)
   with a clear "extraction inbound" radio line and countdown. Pressure stands
   down or thins so the payoff is survivable but not free.
3. **Extraction.** At least one **admitted, Alive** operative present in the
   clearing at the arrival deadline resolves `Success`/`Extracted`. If the squad
   wipes during the arrival window, `Failure`/`SquadWipe` still wins (precedence
   above).

All timing, presence, and prerequisites are server-read and revision-safe, and
the boss-defeat check reuses the existing `readBossState` disclosure — the client
declares nothing. Late entry, early departure, incapacitation, death, and
disconnect during the window all resolve through the existing admitted-and-Alive
presence rule (`countAdmittedAliveInsideExtraction`).

## Result and contribution facts (`P10-0101`)

The terminal result carries two record groups. P10 **records and discloses**
them; P11 weights them into XP.

**Operation result facts (squad-level):**

- `operationId` (the per-run identity — see replay), `outcomeId`, `causeId`;
- operation duration and the phase/threat reached;
- objectives completed (relay, booster, optional floodlights), boss defeated,
  authored waves survived.

**Contribution facts (per operative, for P11):**

- kills (already owned by `HordeExperienceService`), damage dealt, revives
  performed, objectives contributed to, class actions committed (Brace, treatment
  charges, resupply charges), boss exposure-window hits, and survival state at
  resolution (Alive / Incapacitated / Dead).

These are **server-recorded during the operation** by the owners that already
observe the events (life, class, horde, objective runtimes) and read at
resolution — never client-reported. P10-0101 fixes the vocabulary and the safe
snapshot shape; a bounded server-owned contribution record accumulates them; P11
consumes them. The result snapshot exposes only these authored facts.

## Result presentation (`P10-0104`)

A result screen, driven only from the validated safe result snapshot, communicates:

- the outcome and its **cause** in plain language ("Extraction complete", "Squad
  lost", "Operation abandoned");
- the key operation events (objectives, boss, waves survived, duration);
- personal and squad **contribution facts**;
- the next action (replay / return to briefing).

It shows **no XP, rank, or unlock** — P11 owns those, and the screen must not imply
an unconfirmed reward. Disclosure stays within the P4 limits (no hidden threat or
distant supply truth after the fact is irrelevant here, but the snapshot carries
only authored result facts).

## Cleanup ownership and replay (`P10-0105`)

**Documented stop order** at resolution and teardown, reusing each owner's existing
lifecycle:

1. `EnemyDirectorService.endOperationPressure` (stand-down; already called by
   `resolveMission`), then on replay `stop`/`start` to clear enemies, the boss,
   Spitters, lingering pools, and pending spawns.
2. Objective runtime, `AmmunitionCacheService`, `ClassService`,
   `OperativeReviveSessionService`, movement restrictions, the presentation/probe
   state, and the contribution record.
3. `SquadFailureService` and the mission director's own timers, connections, and
   revision.

**Replay creates a fresh operation identity.** Today `operationId` is the static
`MissionConfig.OperationId`; P10 mints a **new per-run `operationId`** on each
`start`, so a replayed operation is a distinct result with **zero stale** timers,
connections, revisions, cache/collection history, class resources, enemies, boss
state, contribution records, or terminal result. Replay is a clean restart of the
same authored operation, not a resume.

## Leave, disconnect, rejoin, and shutdown (`P10-0106`)

- **Retained only within the active server session.** Operative identity, life
  state, class selection, ammunition, and contribution are keyed by operative
  entity ID and live only for the running operation.
- **Rejoin.** A reconnecting operative may resume **within the same server
  session** while the operation is unresolved; the operation roster is frozen at
  `Infiltration` (`SquadFailureService.beginOperation`), so a late/new join cannot
  claim admission mid-operation.
- **Abandonment.** When **every** admitted operative has disconnected, the
  operation resolves `Failure`/`Abandoned` (authoritative, not client-driven).
- **No duplication.** A disconnect/rejoin cannot duplicate contribution, class
  resources, ammunition, life, objective credit, or terminal reward — everything
  is keyed by the server-owned operative entity ID and committed once.

## Disclosure

The safe result snapshot extends `SafeMissionSnapshot` with the cause and the
result/contribution facts, validated server-side (`MissionContracts`). Clients
render it and report nothing back; there is no new client-to-server terminal
request (the only client mission input remains the objective/interaction presence
already established).

## Mapping to the P10 implementation tasks

| Task | What this plan hands it |
| --- | --- |
| `P10-0101` | The `MissionResultCauseId` vocabulary, the extraction/readiness/cleanup/replay IDs, the result and per-operative contribution fact shapes, and the safe result snapshot (server-authored facts only, no XP). |
| `P10-0102` | One authoritative terminal-result resolver that every cause (`Extracted`, `SquadWipe`, `Abandoned`) converges on, first-commit-wins, with the fixed wipe-outranks-extraction precedence. |
| `P10-0103` | The boss-defeat → extraction-arrival-window → `Extracted` sequence, server-read and revision-safe, reusing `readBossState` and the admitted-and-Alive presence rule. |
| `P10-0104` | The result screen (outcome, cause, key events, contribution facts, next action) with no XP/unlock promise. |
| `P10-0105` | The documented cleanup stop order and the fresh per-run `operationId` replay reset with zero stale state. |
| `P10-0106` | The session-retention, rejoin-resume, and abandonment rules, keyed by operative entity ID with no disconnect duplication. |
| `P10-0107` | Automated coverage of every terminal cause, race, replay, and cleanup owner, plus the 1/2/4-operative Studio runs across success, squad failure, abandonment, disconnect-during-extraction, and replay. |

## Exit criteria for the plan

`P10-PLAN-001` is complete when the terminal causes, the result and contribution
vocabulary, the extraction sequence, cleanup ownership, replay behavior, the
leave/disconnect/rejoin policy, and disclosure are fixed and mapped to the
existing owners and the single terminal boundary — as above — so `P10-0101` can
begin without further design decisions.

## Implementation status (P10-0101 – P10-0107)

- **Contracts and configuration (`P10-0101`) — complete.**
  `src/shared/Mission/MatchResultContracts.luau` fixes the `MissionResultCauseId`
  (`Extracted`/`SquadWipe`/`Abandoned`) vocabulary and its fixed cause→outcome
  pairing, the `ExtractionReadinessStateId` (`Locked`/`Inbound`/`Arrived`),
  `OperationReplayStateId`, and `CleanupOwnerId` vocabularies, and the
  `SafeMatchResultSnapshot` and per-operative `SafeContributionSnapshot` shapes
  with validators — reusing the existing `MissionContracts` outcome/phase
  vocabulary and the P3 `OperativeLifeContracts` life state, and representing no
  XP or reward. `src/shared/Config/MatchResultConfig.luau` holds the extraction
  arrival window and the documented cleanup stop order (enemies first, mission
  director last, every owner exactly once). Pure declarations and fixtures
  (`tests/MatchResultContracts.test.luau`); no runtime.
- **Terminal-result resolver (`P10-0102`) — complete.**
  `src/server/Systems/TerminalResultResolver.luau` is the one pure, deterministic
  decision: given the server-owned facts (`resolvedCauseId`, `squadWiped`,
  `isAbandoned`, `extractionArrived`, timestamp), it returns the single terminal
  result to commit or a reason the operation is not terminal. Fixed precedence
  (`SquadWipe` > `Abandoned` > `Extracted`) resolves simultaneous conditions to
  exactly one result, and a non-nil `resolvedCauseId` yields `AlreadyResolved`, so
  re-evaluation after a commit never produces a second result. `MatchResultContracts`
  gained the `TerminalDecisionRejectionReasonId`/`TerminalDecision` vocabulary.
  Fixtures in `tests/TerminalResultResolver.test.luau`.
- **Final extraction sequence (`P10-0103`) — complete.**
  `MissionDirectorService` keeps the single terminal boundary and now drives it
  from the pure resolver. The holdout is no longer won by a bare timer: it begins
  with extraction `Locked` and no disclosed countdown, and a living Progenitor can
  never be waited out. On the boss's authoritative defeat
  (`EnemyDirectorService.readBossState().isDefeated` — the client declares
  nothing) extraction becomes `Inbound` for
  `MatchResultConfig.ExtractionArrivalWindowSeconds`, announced by the new
  `ExtractionInbound` radio line, and the existing `holdoutDeadlineServerTimestamp`
  disclosure now carries exactly that countdown. At the deadline, one admitted,
  Alive operative inside the clearing
  (`countAdmittedAliveInsideExtraction`) moves it to `Arrived`, which is the only
  fact that feeds the resolver's `extractionArrived`.

  Squad failure no longer commits an outcome directly: it is one fact
  `evaluateTerminalAt` weighs, and abandonment is read separately from
  `SquadFailureService.readParticipationFacts()`, so a wipe resolves as
  `SquadWipe` and an all-disconnect as `Abandoned`. The already-committed cause is
  fed back as `resolvedCauseId`, so re-evaluation after a commit is inert.

  **Late entry, early departure, incapacitation, death, and disconnect** during the
  window all resolve through that one presence rule. A missed extraction is
  deliberately **not** a failure — the vocabulary has no cause for it — so an empty
  clearing simply leaves the operation unresolved and a squad that stepped out can
  walk back in and extract. Pressure is not thinned in this pass: no new director
  API was invented, so the squad still holds under the existing wave-3 roaming
  pressure with the boss gone; P12 tunes that against evidence.

  `Service.read()` gained `causeId` and `extractionReadinessStateId` for
  `P10-0104`/`P10-0105`; both reset with the operation. Fixtures:
  `tests/ExtractionSequenceIntegration.test.luau`, plus the extended
  `MissionDirectorService` and `P5IntegrationValidation` scenarios.
- **Contribution ledger and result assembly (`P10-0104`, part 1) — complete.**
  `src/server/Systems/MatchResultService.luau` is the bounded per-operative
  contribution record named in the cleanup stop order. It is inert authority: no
  remote, no connection, no timer, and no ability to damage, heal, kill, complete
  an objective, spend a resource, or resolve an operation — it only counts what an
  authoritative owner has already committed. The owners that already observe those
  events record into it: the combat runtime (committed damage, kills, and
  boss-exposure hits, the last gated on the new
  `EnemyDirectorService.isBossEntity`), the revive session owner (the operative who
  performed a committed revive), `ClassService` (an action becoming Active), and
  `MissionDirectorService` (every operative it sampled working a completed
  objective). At the single terminal boundary the mission director hands over the
  squad facts it owns — including the phase actually reached, captured before the
  terminal transition — and the ledger freezes one validated
  `SafeMatchResultSnapshot` with the P3 survival state read per operative. First
  commit wins; an invalid snapshot is refused rather than published; the tracked
  population and every counter are bounded, and the operative ceiling deliberately
  exceeds four so no fixed-squad assumption is baked in. The snapshot carries
  exactly the P10-0101 fields, so no XP, rank, unlock, or reward can ride along.
  Fixture: `tests/MatchResultContribution.test.luau`.
- **Result screen (`P10-0104`, part 2) — complete.**
  The existing `MissionNetwork` gained one server→client `Result` channel beside
  `State`; no request surface was added, because the mission owner accepts nothing
  (the P8 audit enforces this). At resolution the mission director discloses the
  frozen snapshot once, and a client that arrives afterwards is **pushed** the same
  snapshot on join rather than asking for it.
  `src/client/Controllers/MatchResultController.luau` renders only that payload and
  only after the shared validator accepts it, exactly once per operation: the
  outcome and cause in plain language per authored cause ("EXTRACTION COMPLETE",
  "SQUAD LOST", "OPERATION ABANDONED"), the key events (duration, phase reached,
  objectives completed, waves survived, boss outcome), and every operative's
  contribution row with the local operative marked and survival state in words.
  It shows **no XP, rank, or unlock** and **no replay control** — replay does not
  exist until `P10-0105`, so the screen states plainly that nothing has been
  awarded rather than offering a dead button. Fixture:
  `tests/MatchResultPresentation.test.luau`.
- **Deterministic cleanup and replay (`P10-0105`) — complete.**
  `src/server/Systems/OperationLifecycleService.luau` is the one owner of the
  terminal stop/start sequence. It holds no gameplay state: it executes
  `MatchResultConfig.CleanupStopOrder` and the new `ReplayStartOrder` against each
  system's existing lifecycle, so the order lives in shared configuration rather
  than a hand-written sequence, and both orders are asserted to cover every
  declared cleanup owner exactly once. The start order is deliberately not the
  reverse of the stop order — the life and roster owners must be running before the
  mission restarts. The objective runtime releases at its documented place through
  `MissionDirectorService.resetObjectiveRuntime()` while the director tears the
  rest of itself down last.

  Replay is server-driven and needs no developer intervention: the lifecycle owner
  subscribes to the mission's single terminal commit through the new
  `subscribeResolved`, holds the operation at `Resolved` for
  `MatchResultConfig.ReplayDebriefSeconds` so the squad can read the debrief, then
  moves to `Replayable` and restarts. It owns exactly one timer and one
  subscription, both released on teardown, and exposes no remote — a client cannot
  request or delay a replay. `replayNow()` is a server-only immediate path for
  validation.

  **A replayed operation is a fresh run, not a resume.** The mission director now
  mints a per-run `operationId` (`operation.blackwater-relay:run-N`) on every
  start, and that identity is what the mission snapshot publishes and the result
  ledger records — so two runs on one server are two distinct results. The debrief
  screen's next action became real and now names the same configured window.
  Fixture: `tests/OperationLifecycleReplay.test.luau`.
- **`P10-0106` – `P10-0107`** remain not started.

## Deliberate exclusions

No persistent XP, rank, or unlock (that is P11); no new terminal-failure cause
beyond squad wipe and abandonment; no objective-level terminal failure (P8); no
parallel operation authority; no client-to-server terminal request; and no new
licensed assets. Timings named here are first-pass authoring intent to be
confirmed against evidence in P12.
