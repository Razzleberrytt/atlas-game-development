# First playable operation (P5-0103)

Living Kingdoms' first complete vertical slice: one authored operation from insertion through extraction, built entirely on the systems delivered in P1–P4 and the P5-0101/P5-0102 world. The milestone exists to answer one question — *is Living Kingdoms fun to play?* — with one polished prototype mission, not a content-complete game.

## Operation overview

**Operation Blackwater Relay** takes place in the P5-0102 Appalachian exclusion-zone graybox. A squad of one to four operatives inserts at the Ranger Station, crosses the forest to the Forest Service Lookout, restores the emergency communications relay, and exfiltrates through the authored Forest Extraction Clearing while pressure mounts. A full-squad run is shaped for roughly 10–15 minutes: a 20-second regroup, several minutes of darkness navigation each way, one simple interaction, and a 90-second holdout.

## Mission phases

The authoritative phase vocabulary lives in `src/shared/Mission/MissionContracts.luau`; every timing and position constant lives in `src/shared/Config/MissionConfig.luau`.

| Phase | Entry condition | What happens |
| --- | --- | --- |
| `Insertion` | Server start | Squad spawns at the Ranger Station staging area (existing P5-0101 spawn and lighting). No combat. Radio: "Insertion complete." |
| `Infiltration` | `InsertionHoldSeconds` (20 s) elapse | The operation roster freezes (`SquadFailureService.beginOperation`), the objective becomes `Active`, and its interaction prompt enables. Radio directs the squad to Lookout 7. Navigation is environmental: the existing logging road, switchback trail, creek, and landmark lighting — no new walls or rails. |
| `Exfiltration` | Objective completed | Extraction unlocks: an orange beacon pillar with an `EXTRACTION` marker appears on the clearing, the objective text updates, and escalation begins. |
| `Holdout` | An admitted, alive operative is inside the extraction zone (34-stud radius, checked every 0.5 s) | The bounded `ArrivalSeconds` (90 s) countdown starts and replicates as a server deadline timestamp. Radio: "Hold your position." The final escalation wave spawns. |
| `Resolved` | Countdown expiry, or squad failure at any time | Success if at least one admitted, alive operative is inside the clearing when extraction arrives; otherwise failure. Terminal — no later event can change the outcome. |

## Objective system

The single authored objective is **restore the emergency communications relay** at the Forest Service Lookout. A graybox `RelayConsole` (body, red status lamp, `ProximityPrompt`) is generated at a config position validated to sit on the `LookoutTower` landmark.

Completion is server-authoritative and deterministic. The prompt is input only; `MissionDirectorService.requestObjectiveInteraction` revalidates everything on the server in a stable first-failure order:

1. service running (`ServiceStopped`)
2. not already completed (`AlreadyCompleted`)
3. phase is `Infiltration` (`InvalidPhase`)
4. requester is a registered operative (`UnknownOperative`)
5. requester is `Alive` in `OperativeLifeService` (`InvalidLifeState`)
6. requester has a readable `HumanoidRootPart` (`MissingPosition`)
7. that server-read position is within the configured interaction radius of the console (`OutOfRange`)

Acceptance commits once: objective `Completed`, completing operative and server timestamp recorded, prompt destroyed, status lamp turned green. The mission — not the player — owns completion, so the completing operative disconnecting afterwards changes nothing.

## Extraction sequence

Objective completion unlocks extraction at the authored clearing (`ExtractionClearing` landmark; the zone radius is validated to stay on it). Players receive the beacon marker, a radio confirmation, and the updated objective line. A bounded heartbeat presence check (no per-player connections) begins the holdout when the first admitted living operative stands inside the zone. The holdout deadline is a fixed server timestamp; clients render the countdown from `Workspace:GetServerTimeNow()` against the disclosed deadline and never report time back. At the deadline the server counts admitted, alive operatives inside the zone: one or more is **Mission Success**, zero is **Mission Failure**.

## Escalation

Pressure mounts in three authored waves that reuse the existing LK-0207 stationary hostile fixtures — no new enemy archetypes, bosses, or abilities:

1. **Objective completed** — two hostiles on the descent between the lookout and the campground.
2. **`SecondWaveDelaySeconds` (45 s) after completion** — two hostiles along the creek crossing and eastern approach, with a "pressure rising" transmission.
3. **Holdout begins** — three hostiles around the clearing perimeter.

Waves spawn exactly once each and escalation level is monotonic, even if a fast squad reaches holdout before wave 2's timer. `AutomaticCombatDevelopmentHarness.spawnMissionHostile` is the only addition to the combat harness; because that harness is Studio-only, escalation currently produces combat pressure only in Studio (a documented prototype limitation), and the mission flow is unaffected elsewhere.

## Failure, death, and disconnects

- Individual death and incapacitation remain owned by the P3 life systems; the mission continues while the squad is viable.
- `MissionDirectorService` subscribes to `SquadFailureService`; a committed `Failed` status (squad wipe after its grace window, or authoritative abandonment when everyone disconnects) resolves the mission as failure from any phase.
- Mission state is keyed by operative entity IDs and mission-scoped facts, never `Player` references, so disconnects cannot regress the phase, the objective, or the countdown. Roster admission is frozen at `Infiltration`, matching the P3 participation rules.

## Client presentation

`MissionController` renders a temporary placeholder UI from the validated safe snapshot only: the current objective line, an `EXTRACTION AVAILABLE` tag, transient radio text (auto-hides after six seconds), the holdout countdown, and a centered `MISSION SUCCESS` / `MISSION FAILURE` card. All radio transmissions are placeholder text lines from `MissionConfig.RadioLines`; no licensed assets. The controller sends nothing to the server — the mission network is one server→client `MissionNetwork.State` RemoteEvent, and stale or malformed snapshots are dropped by contract validation.

## Reusable mission framework

`MissionDirectorService` is intentionally minimal so later operations (P8+) can reuse it rather than outgrow it:

- **Phase machine** — the five-phase vocabulary and terminal `Resolved` state generalize to any insertion→objective→exfiltration operation.
- **Deterministic timers** — every deadline is an absolute server timestamp evaluated through one `evaluateTimersAt(serverTimestamp)` entry point (one scheduled thread, re-armed per commit), so fixtures can drive the whole mission without wall-clock time.
- **Objective commit boundary** — the validation-chain-then-commit-once shape extends to multiple objectives by adding objective records, not new authority paths.
- **Safe disclosure** — one revisioned snapshot per commit, validated by `MissionContracts.validateSafeMissionSnapshot` on both ends.

## Validation

Run from the repository root:

- `lune run games/living-kingdoms/tests/MissionContracts.test.luau` — vocabulary stability, snapshot validation, and authored-config invariants (objective on its landmark, extraction zone on its clearing, wave positions inside the playable extent, bounded timings).
- `lune run games/living-kingdoms/tests/MissionDirectorService.test.luau` — full mission success, holdout failure (zone left, or survivor dead), squad wipe from any phase, full-squad disconnect, double-completion rejection, the objective validation chain, mid-operation disconnect resilience, presence-heartbeat holdout entry, restart, and stop/cleanup; plus bootstrap wiring and a no-client-remote source audit.
- All pre-existing fixtures, StyLua, Selene (`games/living-kingdoms/src`), `rojo sourcemap`, and `rojo build` must continue to pass.

A live Studio squad playthrough remains required for the actual "is it fun" answer; repository validation proves the flow, authority, and cleanup, not the feel.

## Known limitations and future extension points

- Hostile pressure exists only in Studio because the only hostile implementation is the Studio-only development harness; a production enemy lifecycle is the remaining P5 work.
- Hostile fixtures are stationary and do not pursue — escalation is currently about presence and radio tension, not chasing pressure.
- One mission per server lifetime: `Resolved` is terminal with no replay/reset flow (P10).
- Placeholder timings, placeholder UI, and text-only radio; no audio assets.
- Environmental escalation (power failures, deeper lighting shifts) is limited to radio urgency in this slice.
- No inventory, crafting, progression, saves, matchmaking, additional operations, procedural missions, cutscenes, new weapons, or new enemy classes — all deliberately excluded.
