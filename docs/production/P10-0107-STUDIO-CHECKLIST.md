# P10-0107 — Full Match-Loop Studio Checklist

> **Status:** `P10-0107` is `[~]`. Its **automated half is complete**
> (`tests/P10MatchLoopValidation.test.luau` proves the composed terminal
> surface: the full cause/race matrix and precedence, single-result assembly per
> run, cleanup-owner coverage, and a server-only loop). The **1/2/4-operative
> Studio matrix below is the outstanding manual gate**, and **P10 is not signed
> off until these rows are recorded.** The current
> [static playable evidence gate](../roadmap/STATIC-PLAYABLE-EVIDENCE-GATE.md)
> also uses this packet for the complete fixed run.
>
> **Current replay contract (main at and after `ca3b0c3`):** a resolved run does
> not restart on a timer. Every connected participant uses **RETURN TO LOBBY**;
> after the server-owned return vote resolves, the squad opens the Expedition
> Lobby and uses **READY** to deliberately launch a fresh run. The server alone
> performs cleanup and launch preparation. Older automatic-20-second-restart
> instructions are superseded.

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
authored operation, resolved once, and deliberately launched again through the
visible return/lobby flow:

- the squad travels the authored route on foot and reaches its terminal outcome
  through ordinary play (or the deliberate scripted action named in the scenario),
  never by editing config or forcing a result directly;
- the operation resolves **exactly once**, with the **cause the scenario
  intends** (verify `causeId` on the debrief, not just the headline);
- for every scenario except abandonment, every connected participant activates
  **RETURN TO LOBBY**; in multiplayer, the UI truthfully shows the waiting count
  before the final vote, while the one-player vote returns immediately;
- after return, the squad opens the Expedition Lobby and uses **READY** to launch
  a **fresh run** without a command-bar action (`operationId` suffix increments
  `…:run-N`);
- the debrief renders and its fields are internally consistent with what was
  observed (a wiped squad shows no survivors, a defeated boss shows
  `bossDefeated`).

If any of these breaks, classify the run **invalid** and note why — an honest
invalid row is more useful than a fabricated valid one.

## Fixtures and exact values referenced

- **Phases / timing** (`MissionConfig.luau`, `MatchResultConfig.luau`):
  `Insertion` → `Infiltration` → `Exfiltration` → `Holdout` (boss fight, **no
  countdown while the boss lives**) → boss defeated → **extraction inbound for
  `ExtractionArrivalWindowSeconds = 15 s`** → `Resolved`. Resolution remains
  stable until the server-owned return vote and a later deliberate lobby launch.
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

1. Record the exact commit SHA, Rojo project (`default.project.json` for the
   operation), published place identity if a published place is used, Studio
   version, date/time, server/client count, and input/device path. Never infer a
   place or universe ID.
2. Confirm the working tree is that SHA. Do not pull, rebase, edit config, or
   change the synced place between comparable runs.
3. `rojo build` / sync the place, or open the synced place in Studio.
4. **Test → Clients and Server.** Set the player count for the scenario (1, 2, or
   4). "Clients and Server" gives you a dedicated Server window whose command bar
   the harness listens to.
5. Press **Start**. Confirm every client spawns at the Ranger Station insertion,
   the mission HUD shows `Insertion`, and Output names no failed bootstrap
   service/controller. Record any warning rather than silently dismissing it.
6. Before running scenario actions, open the Expedition Lobby on every client,
   **JOIN** where required, then use **READY** on every member. Confirm the
   all-ready transition launches exactly one expedition and the mission advances
   from its unarmed insertion state through the ordinary server-owned launch path.

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
8. On every connected client activate **RETURN TO LOBBY**. For the 2P and 4P
   rows, confirm the waiting-for-squad count before the final vote. For the 1P
   row, record that check as **N/A** because the sole vote returns immediately.
   After consensus, confirm the terminal expedition closes and preparation
   becomes available.
9. Open the Expedition Lobby, confirm all members begin unready, then use
   **READY** on each client. Confirm the server launches one fresh operation and
   the next mission snapshot carries the next `…:run-N` identity.

### Squad wipe (`P10-2P-WIPE`)

1. Begin the operation normally and reach `Infiltration`.
2. In the **Server** command bar, kill every operative:
   `ServerStorage.LK0305OperativeLifeDevelopment.Kill:Invoke(<player>)` for each.
   (Use `game.Players:GetChildren()` to enumerate them.)
3. Confirm the operation resolves **`SquadWipe` / Failure** once, and that a later
   viability change cannot undo it.
4. Read and capture the debrief; confirm no operative shows a surviving state.
5. Complete RETURN TO LOBBY consensus, then READY the squad and confirm one fresh operation launches.

### Abandonment (`P10-2P-ABANDON`)

1. Begin the operation and reach `Infiltration`.
2. Close **every** client window (or stop all clients) so no admitted operative
   remains connected.
3. Confirm from server-side evidence in the still-running Studio server that the
   operation resolves **`Abandoned` / Failure** authoritatively (not a wipe), and
   record the exact observable used. If the current session exposes no inspectable
   authoritative result, mark the row **UNKNOWN** rather than inferring it.
4. End this row after the abandonment observation. Record debrief, return-vote,
   and same-server replay fields as **N/A**: the accepted Studio topology cannot
   reconnect a closed client to that same local server. Exercise return/replay in
   the other connected-client rows; do not fabricate a rejoin.

### Disconnect during extraction (`P10-2P-DISCONNECT`)

1. Play the success route to the point where the **boss is defeated** and the
   **15 s extraction window opens**.
2. **During that window**, close **one** client. Keep the other **Alive** and in
   the clearing.
3. Confirm the operation still resolves **`Extracted` / Success** — a mid-window
   disconnect is not a failure, and the remaining operative extracts.
4. Capture the debrief; confirm the disconnected operative's contribution is
   **retained** (their row is present) and the surviving operative extracted.
5. Complete RETURN TO LOBBY consensus, then READY the squad and confirm one fresh operation launches.

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

Return / replay:
  RETURN TO LOBBY visible and understandable? (Y/N)
  Waiting-for-squad count accurate before consensus? (Y/N + observed count; N/A for 1P and abandonment)
  Returned to preparation after consensus? (Y/N)
  Expedition Lobby reachable without coaching? (Y/N)
  All retained members reset to unready? (Y/N)
  Rejoin/JOIN required after disconnect? (Y/N + observed state)
  READY launched exactly one fresh operation? (Y/N)
  Next operationId suffix incremented? (Y/N)

Player-experience observations (raw, not inferred):
  Input/device path:
  What did the player try without coaching?
  First unclear instruction or route:
  Threat/hit/damage/failure readability:
  Objective/navigation clarity:
  Result/reward/build comprehension:
  Return/replay comprehension:
  Frame-time/memory/network observation source (or NOT CAPTURED):
  Accessibility/safe-area issue observed (or NONE OBSERVED):
  Would attempt again unprompted? (Y/N; first-time external tester only)

Notes / deviations / reproducible defects:
```

## Session sign-off

P10-0107 is complete — and P10 may be signed off — only when:

- all six matrix rows are recorded as **valid**, each resolving once with its
  intended `causeId`;
- every non-abandonment run completed the visible RETURN TO LOBBY → Expedition
  Lobby → READY path without developer coaching or command-bar intervention,
  launched exactly once, and carried a fresh `…:run-N` identity;
- the abandonment row records an authoritative server-side `Abandoned` result
  and marks debrief/return/replay fields N/A rather than claiming an unsupported
  same-server Studio rejoin;
- the disconnect-during-extraction run **retained** the disconnected operative's
  contribution and still extracted;
- no defect required developer intervention to reach or leave a terminal state;
- at least three clean result/failure → return → ready → restart cycles are
  recorded with no stale UI, duplicate listener, orphaned entity, or accumulated
  lifecycle state;
- first-time external attempts, when available, report raw
  `unprompted replay / reached legitimate result` counts. The current directional
  signal is at least 50%; record the fraction and do not present a small cohort as
  statistical proof.

Record the outcome here and mirror the disposition into
[`../roadmap/P6-P12-EXECUTION-ROADMAP.md`](../roadmap/P6-P12-EXECUTION-ROADMAP.md)
(the `P10-0107` entry) and the P10 line in
[`../roadmap/MASTER-ROADMAP.md`](../roadmap/MASTER-ROADMAP.md). If any row is
invalid, keep it with its reason and leave P10-0107 open — an honest gap beats a
premature sign-off.

### Session results

_(fill in during the session; one filled capture block per matrix row)_
