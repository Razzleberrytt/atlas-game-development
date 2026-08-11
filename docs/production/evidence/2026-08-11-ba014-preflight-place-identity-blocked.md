# Main World BA-014 First Run — Preflight Blocked on Place Identity

## 1. Identity

- Date/time: 2026-08-11, America/New_York
- Tester/operator: Claude (Cowork)
- Roadmap ticket(s): BA-014 Main World hub/route acceptance
- Rollout stage: Patch 0.5 Main World, first scoped run attempt
- Git branch: `main`
- Source commit: `00ddba56b4cce360b9eed1f82b9e095c07dbd573`
- Tools: Rojo 7.7.0; Lune 0.10.4; StyLua 2.5.2; Selene 0.31.0
- Roblox Studio version: `0.733.0.7330989`
- Place: `MainWorld-BA014.rbxlx` (built from `games/living-kingdoms/main-world.project.json`)
- Reproducible artifact: SHA-256 `564b31cbdd45dd9bdd11ec3c1707595dc3effb1d1e6169667a8405ca2b66cf0b`, 1,026,674 bytes
- Main World place identity: unpublished — no assigned place ID
- Intended server/client count: not established; no session was started
- Known-good rollback source: `00ddba56b4cce360b9eed1f82b9e095c07dbd573`

## 2. Claim under test

The mapped dedicated Main World build — admitted hub core plus the bounded 12-Part primary
route — satisfies the 10 BA-014 checks its mapped streaming groups can answer.

No part of this claim was tested. See §5.

## 3. Preconditions and baseline

- Source synchronized: yes. Local `main` was fast-forwarded from `eb0211c` to `00ddba5`
  (24 merged PRs, #407–#438) before any step.
- Static baseline: `python scripts/validate.py full` — **green**, 335 Lune fixtures, StyLua,
  Selene, and both Rojo builds (operation place and dedicated Main World).
- Scope re-derived against current `main` rather than taken from the runbook:
  `MainWorldAcceptanceScopeResolver` yields **10 in scope (7 blocking), 21 out of scope** —
  unchanged from the previously recorded partition.
- Output cleared: not reached.
- Baseline counters: not captured; no play session was established.

## 4. Procedure

1. Fast-forwarded `main` to `00ddba5` and confirmed no open PRs or overlapping branches.
2. Ran `python scripts/validate.py full`; all gates green.
3. Generated the blank run record from committed contracts
   (`evaluate-ba014-run.luau`); it yielded exactly the 10 in-scope checks.
4. Built the dedicated Main World from `main-world.project.json` and recorded filename,
   SHA-256, and byte count (§1).
5. Queried the Studio MCP instance list. One instance was advertised and connected:
   `Living Kingdoms 0.5.rbxl`.
6. Probed that instance's `Edit` DataModel for the artifact's expected topology.
7. **Identity mismatch.** `workspace.LivingKingdomsMainWorld` is absent. The connected place
   instead contains the recovered authored world: `WorldPath` (189 slabs), `HubTown`,
   `WorldStructures` (~1,189 descendants), `Resources`, and biome models
   (`SerenityLake`, `CrystalCave`, `DuneWastes`, `Frostmire`, `ShadowDungeon`). Its
   `ServerScriptService` boots quarantined legacy managers — `RPGServerBootstrap`,
   `SurvivalGatheringService`, `MonetizationService`, `EnvironmentAnimationController`.
8. Stopped per runbook §2 step 8. Recorded all 10 in-scope checks as `Blocked`. Gathered no
   substitute observation from the connected place.

## 5. Observations

- The exact artifact built reproducibly and its identity was fully recorded.
- The connected Studio place is **not** that artifact and is not a stale copy of it. It is a
  separate, deliberately divergent work stream: per the repository owner, it holds biome and
  world content authored locally via the Roblox Studio Assistant, to be combined with the
  GitHub version later.
- No BA-014 observation was taken. No screenshots, cameras, traversal timings, congestion
  results, counters, or profiles were captured.
- This is an evidence-transport/identity failure, not evidence that the build passes or fails
  at runtime.

## 6. Defects found

| Severity | Defect | Reproduction | Owner | Blocking? |
|---|---|---|---|---|
| Blocker | Studio bridge exposes a different place than the built BA-014 artifact | Build `main-world.project.json`, query Studio MCP, probe `workspace.LivingKingdomsMainWorld` | Studio session/place selection | Yes |

No source-owned defect was found, because no source behavior was observed.

## 7. Performance and matrix result

- Required gameplay matrix: not run.
- Server/client performance: not captured.
- Runtime counters and before/after rates: not captured.
- Sufficient for E3+: no. Evidence level unchanged.

## 8. Rollback and acceptance decision

Decided mechanically through the committed contracts, not by reading the sheet:

```bash
lune run games/living-kingdoms/tools/evidence/evaluate-ba014-run.luau \
  docs/production/evidence/2026-08-11-ba014-preflight-run-record.json
```

- Packet result: **`PARTIAL`** (exit 1)
- Reported causes: 4 missing identity fields (never established, because no session ran) and
  10 in-scope checks blocked by evidence transport.
- `activation acceptable: false`.
- `PARTIAL`, not `FAIL`, is correct and intended: a bridge failure is not a runtime defect.
- Rollback trigger occurred: no; no runtime observation was possible.
- Patch 0.5 gate: remains open. No check has been executed. Patch 0.5 stays
  **BUILT — VERIFICATION PENDING**; nothing is promoted to VERIFIED.
- Required next action: open the exact artifact
  (`MainWorld-BA014.rbxlx`, SHA-256 `564b31cb…`) in Studio, confirm
  `workspace.LivingKingdomsMainWorld` is present, then rerun from runbook §5 step 2 under a
  **new** packet. Do not edit this packet to fit that result.

## 9. Attachments

- Run record: [`2026-08-11-ba014-preflight-run-record.json`](2026-08-11-ba014-preflight-run-record.json)
- Exact artifact: `C:\Users\Will\atlas-build\MainWorld-BA014.rbxlx`
- Screenshots/video/output/profiler: none; place identity could not be proved.

> This packet records a blocked preflight only. It is not runtime validation, and it is not a
> BA-014 result for any check.
