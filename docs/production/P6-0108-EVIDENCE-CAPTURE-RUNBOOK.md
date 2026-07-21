# P6-0108 — Single-Sitting Evidence Capture Runbook

> **Status:** P6 was signed off *qualitatively* for the current prototype in
> PR #165 (owner-reported multiplayer pass; no tuning applied, no numbers
> invented). The **numeric** competent-route matrix below was **not** captured
> at sign-off — the measured 1/2/4-operative scarcity replay is deferred to
> **P12**. This runbook is the procedure for that P12 measured replay; the
> references to the "P6 gate" below describe the original P6-0108 framing.

## What this is

A concrete, repeatable script for capturing the three controlled runs that
populate the **P6-0108 required evidence table** — `P6-1P-01`, `P6-2P-01`, and
`P6-4P-01` — in one Studio sitting. It exists because the automated
`P6-AUTO-*` probes recorded on 2026-07-21 admit clients into the session but
leave them stationary: they never travel to caches, issue reload intent, or
apply pressure, so they are marked *invalid for balance comparison*. This
runbook is the competent-route counterpart that produces valid rows.

**Authority:** the controlled evidence *process*, the required table columns,
and the run classification live in
[`../specifications/ammunition-scarcity-and-supply.md`](../specifications/ammunition-scarcity-and-supply.md)
(§ "P6-0108 controlled evidence process"). That spec wins on any conflict. This
runbook only pins the route, cache order, and snapshot checkpoints to
**Operation Blackwater Relay** so the three runs stay comparable.

## What makes a run valid

A row counts toward the balance gate only if the operative(s) played the
operation the way a real squad would:

- travel the authored route on foot (Ranger Station → Lookout 7 → Extraction
  Clearing), not teleport or idle;
- fire at real pressure and **issue reload intent** through ordinary play;
- visit the **same caches in the same order** every run (see below);
- reach a terminal outcome (success or failure) through ordinary play, not a
  defect or developer intervention.

If any of these breaks, classify the run *invalid for balance comparison* and
note why — an honest invalid row is more useful than a fabricated valid one.

## Fixtures referenced

- **Route / phases** (`Insertion` 20 s → `Infiltration` → `Exfiltration` →
  `Holdout` 90 s → `Resolved`): `MissionConfig.luau`,
  [`../specifications/first-playable-operation.md`](../specifications/first-playable-operation.md).
- **Three authored caches** (12 rounds each), in `AmmunitionCacheConfig.luau`:
  1. `ammo-cache.campground-medical-tent` (Campground landmark)
  2. `ammo-cache.military-roadblock-checkpoint` (MilitaryRoadblock landmark)
  3. `ammo-cache.rocky-overlook-vehicle` (RockyOverlook landmark)
- **Telemetry probe** (Studio-only, server): `ServerStorage
  .LivingKingdomsAmmunitionValidation` with `ResetSampling` and `ReadSnapshot`.

## Pre-flight (once, before the first run)

1. Confirm the build/commit is identical for all three runs and record the SHA.
   Do **not** rebase, pull, or edit config between runs.
2. Decide the **one** cache-visit order you will follow in every run and write
   it into the "Route/objective order" cell. Pick the order that a competent
   squad crossing the authored route would naturally take, and keep it fixed for
   1P, 2P, and 4P so the three rows compare like-for-like.
3. Have the evidence table open (in the spec) to paste into.

## Per-run script — repeat for 1, then 2, then 4 operatives

Start each run from a **fresh** Studio *Server & Clients* session with the
required client count. Never carry a session or telemetry across runs.

### A. Baseline

1. Launch Server & Clients; confirm every client spawns, moves, sees
   authoritative ammunition, and has not consumed a cache.
2. From the **Server** command bar:
   ```luau
   local probe = game:GetService("ServerStorage"):WaitForChild("LivingKingdomsAmmunitionValidation")
   probe.ResetSampling:Invoke()
   ```
3. Record run ID (`P6-1P-01` / `P6-2P-01` / `P6-4P-01`), date, operative count,
   commit, intended route, and any known limitation.
4. Capture the **operation-start baseline** snapshot:
   ```luau
   local probe = game:GetService("ServerStorage"):WaitForChild("LivingKingdomsAmmunitionValidation")
   print(probe.ReadSnapshot:Invoke())
   ```

### B. Route with checkpoints

Play the route once, in order, capturing a `ReadSnapshot` at each ★ checkpoint
and recording per-cache facts as you collect (which operative, whether the grant
was capacity-clamped, whether depletion showed only for that operative).

| Phase | Do this | Capture |
| --- | --- | --- |
| `Insertion` (20 s) | Regroup at Ranger Station; no combat. | — (baseline already taken) |
| `Infiltration` | Cross the logging road / switchback / creek toward Lookout 7, fighting roaming pressure and visiting caches in the locked order. Reload through ordinary play. | ★ after your first cache collection |
| Objective | Restore the relay at the Lookout Tower console. | ★ **first objective completion** |
| `Exfiltration` | Descend toward the Extraction Clearing (wave 1: two hostiles between lookout and campground). | ★ **mid-operation escalation / major relocation** |
| `Holdout` (90 s) | Stand inside the 34-stud extraction zone; survive the final converging wave. | ★ **holdout start** |
| `Resolved` | Countdown expiry or squad failure. | ★ **terminal outcome** |

### C. Reconcile and classify

1. Verify the final aggregate accepted-shot count reconciles:
   `initial loaded + initial reserve + committed cache grants − current loaded − current reserve`.
2. Confirm consumed cache identities and remaining opportunities match what you
   observed, per operative.
3. Classify only after reviewing the facts: **oversupplied candidate** /
   **healthy tension candidate** / **starvation candidate** /
   **invalid for balance comparison**.
4. Paste the row into the required evidence table (add per-operative detail
   beneath the row when players diverge materially).
5. Stop the session before starting the next operative count.

## After all three runs

- With `P6-1P-01`, `P6-2P-01`, and `P6-4P-01` recorded and reconciled, the
  P6-0108 gate has its first comparable matrix. If the runs disagree or a count
  is under-sampled, capture repeat runs (`-02`, `-03`) before drawing any
  conclusion — one run per count is a sample, not evidence.
- Only with that measured evidence in hand should any scarcity **tuning** be
  applied: choose the smallest configuration-backed lever the evidence supports,
  re-run this script to revalidate, and lock final values. Do not tune from a
  single run or from the calculated projection alone. (At the P6 prototype
  sign-off in #165 no tuning was applied; this measured pass is the P12 basis
  for any later change.)

## Do not

- invoke the probe from a client command bar (server only);
- change firearm, cache, enemy, or mission config between comparable runs;
- deliberately waste ammunition unless the run is explicitly labeled a stress
  probe and classified accordingly;
- record a stationary/no-reload/no-route session as anything other than
  *invalid for balance comparison*.
