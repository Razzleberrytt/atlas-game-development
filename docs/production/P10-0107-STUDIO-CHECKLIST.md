# P10-0107 — Full Match-Loop Studio Checklist

> **Status:** `P10-0107` is `[~]`. Its **automated half is complete**
> (`tests/P10MatchLoopValidation.test.luau` proves the composed terminal
> surface: the full cause/race matrix and precedence, single-result assembly per
> run, cleanup-owner coverage, and a server-only loop). The **1/2/4-operative
> Studio matrix below is the outstanding manual gate**, and **P10 is not signed
> off until these rows are recorded.** This document is the script for that
> session and the place to capture its evidence.

## What this is

A concrete, repeatable script for driving the complete match loop in Studio at
**one, two, and four operatives** across the five required terminal scenarios —
success, squad failure, abandonment, disconnect during extraction, and replay —
and recording the debrief facts each run produces.

**Authority:** the terminal behaviour, causes, and cleanup/replay contract live
in [`../specifications/match-completion-and-result.md`](../specifications/match-completion-and-result.md).
That spec wins on any conflict. This checklist only pins the Studio procedure and
the capture shape to the implemented owners.

## What makes a run valid

A row counts toward the gate only if it was produced by ordinary play through the
authored operation, resolved once, and restarted on its own:

- the squad travels the authored route on foot and reaches its terminal outcome
  through ordinary play (or the deliberate scripted action named in the scenario),
  never by editing config or forcing a result directly;
- the operation resolves **exactly once**, with the **cause the scenario
  intends** (verify `causeId` on the debrief, not just the headline);
- the replay restarts **without developer intervention** after the debrief window,
  as a **fresh run** (`operationId` suffix increments `…:run-N`);
- the debrief renders and its fields are internally consistent with what was
  observed (a wiped squad shows no survivors, a defeated boss shows
  `bossDefeated`).

If any of these breaks, classify the run **invalid** and note why — an honest
invalid row is more useful than a fabricated valid one.

## Fixtures and exact values referenced

- **Phases / timing** (`MissionConfig.luau`, `MatchResultConfig.luau`):
  `Insertion` → `Infiltration` → `Exfiltration` → `Holdout` (boss fight, **no
  countdown while the boss lives**) → boss defeated → **extraction inbound for
  `ExtractionArrivalWindowSeconds = 15 s`** → `Resolved`. After resolution the
  debrief holds for **`ReplayDebriefSeconds = 20 s`**, then the operation restarts
  on its own.
- **Terminal causes** (`MatchResultContracts.luau`), fixed precedence
  **`SquadWipe` > `Abandoned` > `Extracted`**:
  - `Extracted` → `Success` (boss defeated, an admitted **Alive** operative in the
    clearing at the 15 s deadline);
  - `SquadWipe` → `Failure` (`SquadFailureService` commits a wipe);
  - `Abandoned` → `Failure` (every admitted operative disconnected).
- **Objectives are non-terminal by design.** There is no "objective failure"
  terminal cause; failing to progress simply keeps the operation unresolved. The
  objective chain (relay → booster → optional floodlights) is exercised inside the
  success runs.
- **Studio life harness** (studio-only, server): `ServerStorage /
  LK0305OperativeLifeDevelopment`, a folder of `BindableFunction`s. Invoke from the
  **Server** command bar only (Test → Server window), never a client:
  - `Kill:Invoke(player)` — drives one operative to `Dead` through the
    authoritative P3 boundary;
  - `Incapacitate:Invoke(player)` — drives one operative to `Incapacitated`;
  - `ApplyDamage:Invoke(player, amount)` — applies bounded authoritative damage.
- **Boss defeat has no shortcut, by design.** Defeat The Progenitor through real
  combat during its telegraphed exposure window — that this is achievable by a
  1/2/4-operative squad is part of what P10-0107 validates.

## Studio setup (once)

1. Confirm the working tree is the commit under test and record the SHA. Do not
   pull, rebase, or edit config between runs.
2. `rojo build` / sync the place, or open the synced place in Studio.
3. **Test → Clients and Server.** Set the player count for the scenario (1, 2, or
   4). "Clients and Server" gives you a dedicated Server window whose command bar
   the harness listens to.
4. Press **Start**. Confirm every client spawns at the Ranger Station insertion
   and the mission HUD shows `Insertion`.

## The scenario matrix

Run every row. The success loop is run at all three operative counts (it is the
core comparison and also exercises the objective chain, the boss, and replay);
the three failure scenarios each need one clean capture. Add operative counts to
the failure scenarios if time allows, but the required minimum is one clean row
each plus the three success rows.

| ID | Operatives | Scenario | Intended `causeId` |
| --- | --- | --- | --- |
| `P10-1P-SUCCESS` | 1 | Full loop to extraction | `Extracted` |
| `P10-2P-SUCCESS` | 2 | Full loop to extraction | `Extracted` |
| `P10-4P-SUCCESS` | 4 | Full loop to extraction | `Extracted` |
| `P10-2P-WIPE` | 2 | Squad wipe mid-operation | `SquadWipe` |
| `P10-2P-ABANDON` | 2 | Every operative disconnects | `Abandoned` |
| `P10-2P-DISCONNECT` | 2 | One disconnects **during the 15 s extraction window**; the other extracts | `Extracted` |

## Per-scenario scripts

### Success (`…-SUCCESS`, run at 1P, 2P, 4P)

1. Move to Lookout 7 and complete the relay objective; watch the radio line and
   the objective marker.
2. Move to the Military Roadblock and charge the signal booster; confirm
   extraction unlocks (`Exfiltration`).
3. Optionally restore the extraction floodlights (engineer). Note whether you did.
4. Move the squad into the extraction clearing to begin the `Holdout`. Confirm the
   Progenitor spawns and **no extraction countdown is shown while it lives**.
5. Defeat the boss through its exposure windows. On defeat, confirm the
   **"extraction inbound"** radio line and that the countdown now runs for ~15 s.
6. Keep at least one **Alive** operative in the clearing at the deadline. Confirm
   the operation resolves **`Extracted` / Success**.
7. Read the debrief. Capture every field in the table below.
8. **Do nothing.** After ~20 s confirm the operation **restarts on its own** and
   the next debrief (when you reach it) carries the **next** `…:run-N` identity.

### Squad wipe (`P10-2P-WIPE`)

1. Begin the operation normally and reach `Infiltration`.
2. In the **Server** command bar, kill every operative:
   `ServerStorage.LK0305OperativeLifeDevelopment.Kill:Invoke(<player>)` for each.
   (Use `game.Players:GetChildren()` to enumerate them.)
3. Confirm the operation resolves **`SquadWipe` / Failure** once, and that a later
   viability change cannot undo it.
4. Read and capture the debrief; confirm no operative shows a surviving state.
5. Confirm the operation restarts on its own.

### Abandonment (`P10-2P-ABANDON`)

1. Begin the operation and reach `Infiltration`.
2. Close **every** client window (or stop all clients) so no admitted operative
   remains connected.
3. Confirm the operation resolves **`Abandoned` / Failure** authoritatively (not a
   wipe). Read the debrief from the Server view or a rejoining client.
4. Confirm the operation restarts on its own.

### Disconnect during extraction (`P10-2P-DISCONNECT`)

1. Play the success route to the point where the **boss is defeated** and the
   **15 s extraction window opens**.
2. **During that window**, close **one** client. Keep the other **Alive** and in
   the clearing.
3. Confirm the operation still resolves **`Extracted` / Success** — a mid-window
   disconnect is not a failure, and the remaining operative extracts.
4. Capture the debrief; confirm the disconnected operative's contribution is
   **retained** (their row is present) and the surviving operative extracted.
5. Confirm the operation restarts on its own.

## Capture — per run

Copy this block once per row and fill it in from the debrief screen. Field names
match `SafeMatchResultSnapshot`.

```
Run ID:              (e.g. P10-2P-SUCCESS)
Build SHA:
Operatives:
Valid? (Y/N + why):

Operation facts:
  operationId:            (must carry a :run-N suffix; note N)
  outcomeId / causeId:
  durationSeconds:
  phaseReachedId:
  objectivesCompleted:
  bossDefeated:
  wavesSurvived:

Per-operative contribution (one line each):
  <op>  survival= kills= damage= revives= objectives= classActions= bossHits=  relics=[…]

Squad Field Upgrades (upgradeStacks): [ … ]

Replay:
  Restarted without intervention? (Y/N)
  Debrief window observed (~20 s)? (Y/N)
  Next operationId suffix incremented? (Y/N)

Notes / deviations / defects:
```

## Session sign-off

P10-0107 is complete — and P10 may be signed off — only when:

- all six matrix rows are recorded as **valid**, each resolving once with its
  intended `causeId`;
- every run **restarted without developer intervention** and the next run carried
  a fresh `…:run-N` identity;
- the disconnect-during-extraction run **retained** the disconnected operative's
  contribution and still extracted;
- no defect required developer intervention to reach or leave a terminal state.

Record the outcome here and mirror the disposition into
[`../roadmap/P6-P12-EXECUTION-ROADMAP.md`](../roadmap/P6-P12-EXECUTION-ROADMAP.md)
(the `P10-0107` entry) and the P10 line in
[`../roadmap/MASTER-ROADMAP.md`](../roadmap/MASTER-ROADMAP.md). If any row is
invalid, keep it with its reason and leave P10-0107 open — an honest gap beats a
premature sign-off.

### Session results

_(fill in during the session; one filled capture block per matrix row)_
