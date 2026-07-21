# Ammunition Scarcity and Supply

**Status:** P6 complete for the current prototype; measured balance replay deferred to P12

**Current task:** Closed — no unsupported tuning change applied
**Execution roadmap:** `docs/roadmap/P6-P12-EXECUTION-ROADMAP.md`

## Goal

Turn the P2 prototype ammunition values into a finite, server-owned operation resource that creates meaningful relocation and resupply decisions without making failure unavoidable.

## Authority

The server owns loaded rounds, reserve rounds, magazine and carry limits, supply identity, source, available quantity, collection eligibility, granted quantity, processed supply identities, and every committed ammunition transition.

Clients may present server-disclosed ammunition and locally mark a consumed cache for the collecting operative. They may never submit ammunition totals, capacity, granted quantity, supply source, processed identity, successful collection, or depletion truth.

## Implemented P6 slices

- finite scarcity state, source IDs, rejection reasons, and pure supply collection
- production starting ammunition and carry limits routed through P6 configuration
- three authored cache locations at risky operation landmarks
- server-owned proximity collection with life, distance, capacity, duplicate, and generation checks
- authoritative loaded, magazine, reserve, and exact grant presentation
- per-operative cache depletion presentation without globally consuming a squadmate's cache
- sampled read-only scarcity telemetry and a Studio-only validation probe

## Initial prototype values

- Basic firearm loaded rounds: 12
- Initial reserve rounds: 24
- Maximum carried reserve rounds: 48
- Authored cache grant: 12

These values remain testable starting points, not final tuning.

## Deterministic collection order

1. Validate the current ammunition state.
2. Validate supply identity, source, weapon, and positive whole-round quantity.
3. Reject an already processed supply identity.
4. Reject when reserve capacity is full.
5. Grant the lesser of available supply and remaining reserve capacity.
6. Commit the generation-checked combat state.
7. Record the server-owned collection identity and exact granted amount.
8. Disclose ammunition and per-operative cache depletion only after commit succeeds.

## P6 telemetry

Telemetry is sampled only when an authorized Studio tester invokes the validation probe. It adds no heartbeat, timer, task loop, production remote, client authority, or gameplay mutation.

Accepted shots are derived from conserved server truth:

`initial loaded + initial reserve + committed cache grants - current loaded - current reserve`

Each snapshot reports:

- observed and currently active operative counts
- accepted shots
- cache collections and exact rounds granted
- current loaded and reserve totals
- minimum total ammunition observed
- currently dry operatives
- observed transitions into true ammunition starvation, where loaded plus reserve equals zero
- total, consumed, and remaining per-operative cache opportunities
- the same measurements for each operative, with consumed cache identities

## Studio validation surface

The server creates `ServerStorage.LivingKingdomsAmmunitionValidation` only in Studio.

- `ResetSampling:Invoke()` clears telemetry history before a new run.
- `ReadSnapshot:Invoke()` takes one explicit sample and returns the frozen snapshot.

From the Studio **Server** command bar:

```luau
local probe = game:GetService("ServerStorage"):WaitForChild("LivingKingdomsAmmunitionValidation")
probe.ResetSampling:Invoke()
```

At each capture point:

```luau
local probe = game:GetService("ServerStorage"):WaitForChild("LivingKingdomsAmmunitionValidation")
print(probe.ReadSnapshot:Invoke())
```

Use the server output to copy the aggregate and per-operative facts into the evidence record. Do not invoke the probe from a client command bar.

## P6-0108 controlled evidence process

Complete these steps separately for one, two, and four operatives. For a
turnkey single-sitting script that pins this process to the Blackwater Relay
route, cache order, and snapshot checkpoints, follow
[`../production/P6-0108-EVIDENCE-CAPTURE-RUNBOOK.md`](../production/P6-0108-EVIDENCE-CAPTURE-RUNBOOK.md);
this section remains the authority on the required columns and classification.

### Before each run

1. Confirm the branch/build contains the same firearm, cache, enemy, and mission configuration for every comparable run.
2. Start a fresh Studio Server & Clients session with the required operative count.
3. Confirm every client has spawned, can move, sees authoritative ammunition, and has not consumed a cache.
4. Invoke `ResetSampling` once from the server command bar.
5. Record the run ID, date, operative count, configuration commit, intended route, and any known test limitation.
6. Invoke `ReadSnapshot` and record the **operation-start** baseline.

### During each run

7. Follow the same intended route and objective order where practical.
8. Play normally enough to expose real automatic-fire, reload, movement, rescue, cache, and pressure behavior; do not deliberately waste ammunition unless the run is explicitly labeled a stress probe.
9. Record route deviations, missed caches, deaths, disconnects, unusual enemy behavior, or developer intervention immediately.
10. Capture and record snapshots at:
   - first objective completion;
   - mid-operation escalation or major relocation;
   - holdout start;
   - terminal success or failure.
11. For each cache collection, note which operative collected it, whether the grant was clamped by capacity, and whether the world feedback became locally depleted only for that operative.
12. When an operative reaches loaded plus reserve equal to zero, record whether meaningful unconsumed cache opportunities remained and whether the operative could reasonably reach them.

### After each run

13. Record terminal outcome, duration, objective reached, deaths/incapacitations, and whether the run ended through ordinary play or a defect.
14. Verify the final aggregate accepted-shot count reconciles with starting ammunition, exact grants, and final ammunition.
15. Verify consumed cache identities and remaining opportunities match observed play for every operative.
16. Classify the run only after reviewing the facts:
   - **oversupplied candidate**;
   - **healthy tension candidate**;
   - **starvation candidate**;
   - **invalid for balance comparison** because of a defect, route/config mismatch, or developer intervention.
17. Stop the session and confirm no telemetry claim is carried into the next run; the next run must begin with a fresh session and `ResetSampling`.

## Required evidence table

Create one row for every captured run. Add per-operative detail beneath the row when players diverge materially.

| Run ID | Commit/config | Operatives | Route/objective order | Duration | Outcome | Accepted shots | Cache collections | Exact rounds granted | Final loaded | Final reserve | Minimum ammo observed | Dry transitions | Remaining opportunities | Deaths/incapacitations | Classification | Deviations/notes |
| --- | --- | ---: | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| P6-1P-01 |  | 1 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| P6-2P-01 |  | 2 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| P6-4P-01 |  | 4 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |

### 2026-07-21 calculated and unattended Studio evidence

These rows are deliberately separated from the controlled matrix above. They
unblocked the local Studio workflow and verified 1/2/4-operative admission,
but stationary unattended clients neither travel to caches nor issue reload
intent. They are stress/integration probes, not competent-route balance runs.

| Probe | Operatives | Observed integration result | Ammunition snapshot | Classification |
| --- | ---: | --- | --- | --- |
| P6-AUTO-1P-01 | 1 | One operative admitted; insertion advanced to the live objective instead of resolving an empty roster. | After a late sampling reset: loaded `19 → 0`, reserve `48`, 3 opportunities remained, no dry transition. | Invalid for balance comparison; stationary/no reload/no route. |
| P6-AUTO-2P-01 | 2 | Both operatives admitted Alive and the operation remained active. | Loaded `0 + 0`, reserve `48 + 48`, 6 opportunities remained, no dry transition. | Invalid for balance comparison; snapshot began after magazine expenditure. |
| P6-AUTO-4P-01 | 4 | All four operatives admitted Alive with the shared objective and stable squad disclosure. | Aggregate loaded `1`, reserve `192`, 12 opportunities remained, no dry transition. | Invalid for balance comparison; stationary/no reload/no route. |

The same configuration was also evaluated with a transparent demand/supply
projection. It assumes 45-health hostiles; representative per-operative kill
loads of 60/38/26 for 1/2/4 operatives; weapon-specific accuracy and bounded
multi-target effectiveness; all three authored caches; and the configured
expected enemy-ammunition recovery of `0.76` rounds per kill. A negative margin
means the modeled shots exceed initial ammunition, cache grants, and expected
loot combined.

| Operatives | LMG margin | Shotgun margin | Sniper margin | Pistol margin | SMG margin |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | -95 | +31 | +14 | -61 | -275 |
| 2 | +1 | +36 | +19 | +2 | -109 |
| 4 | +53 | +40 | +22 | +37 | -18 |

Perceived result: the current roster is not uniformly balanced under a
kill-heavy route. Shotgun and sniper retain recovery margin; solo LMG/pistol
and all tested SMG squad sizes are projected to starve, while duo LMG/pistol
sit on effectively zero margin. This is a high-value hypothesis for the next
controlled run, not authority to tune: the operation permits evasion, actual
accuracy and multi-target hits vary, and no comparable routed run has yet
measured cache access or successful completion.

Recommended minimum before tuning:

- at least two comparable valid one-operative runs;
- at least two comparable valid two-operative runs;
- at least two comparable valid four-operative runs;
- one additional stress probe only when a repeated pattern needs clarification.

A single run may expose a defect, but it cannot justify a balance tune by itself.

## Balance interpretation

Healthy tension is indicated when ammunition minima fall meaningfully, cache use varies by operative or route, and most runs avoid true dry transitions through good movement and collection decisions.

Likely oversupply is indicated when operatives finish with high totals, consume few cache opportunities, and never approach low ammunition across repeated successful runs.

Likely unavoidable starvation is indicated when dry transitions occur repeatedly despite collecting most available opportunities and otherwise competent play. A dry transition while many opportunities remain is not automatically a tuning defect; it may indicate route choice, missed relocation, or poor distribution.

Do not compare runs that used different enemy tuning, firearm configuration, cache definitions, mission path, or intentional waste behavior without recording and separating that difference.

## P6-0109 tuning process

1. Group only comparable valid runs by operative count.
2. Identify a repeated pattern across more than one run; do not tune from an isolated outcome.
3. Choose the smallest configuration-backed lever that addresses the evidence:
   - initial reserve;
   - cache grant size;
   - cache location;
   - maximum reserve capacity;
   - only when necessary, enemy/operation pressure owned by its own milestone configuration.
4. Change one logical lever per tuning pass where practical.
5. Record the hypothesis before changing the value.
6. Re-run the affected operative-count scenarios using the same capture protocol.
7. Reject the change if it merely moves the problem to another squad size or removes meaningful cache/route decisions.
8. Keep the tune only when the repeated evidence moves toward healthy tension without introducing oversupply or unavoidable starvation.
9. Run the full automated validation gate after every committed tuning change.
10. Record final values, evidence, known limitations, and remaining P12 balance questions.

## P6 sign-off checklist

P6 may be marked complete only when:

- valid comparable one-, two-, and four-operative evidence is recorded;
- telemetry conservation and cache identity facts match observed play;
- no collection, per-operative depletion, HUD, revive-preservation, or replay defect remains;
- tuning changes, if any, are supported by repeated evidence and revalidated;
- careful runs can avoid predetermined starvation;
- ammunition and cache decisions still materially affect route, timing, and safety;
- malicious clients still cannot set ammunition, grants, collection truth, supply identity, or another operative's cache history;
- StyLua, Selene, every Living Kingdoms Lune fixture, and Rojo build pass;
- Studio findings and limitations are recorded in the smoke-test/evidence record;
- the roadmap is updated from P6 in progress to P6 complete.

## P6 disposition and deferred measurement

P6 is complete for the current prototype by owner direction. The requested local multiplayer tests were reported as running fine, no blocker was reported, and no configuration tune was made without retained measurement. The detailed routed telemetry rows above remain blank rather than being reconstructed from memory.

The remaining work is intentionally reassigned to P12: repeat measured routed 1/2/4-player runs, retain raw snapshots, and revisit scarcity only if repeated evidence supports a change. Engineer Field Resupply receives its own focused conservation and balance validation during P7 implementation.
