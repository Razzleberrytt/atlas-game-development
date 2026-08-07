# Living Kingdoms Merge Status

**Current merge:** Studio `livingkingdoms.rbxl` + canonical Atlas/Living Kingdoms Rojo source  
**Import date:** 2026-08-07  
**Evidence level:** E1 source/reconciliation only

## Canonical rule

The active `src/` tree remains authoritative for combat, enemies, operative life state, inventory, persistence, rewards, expedition runtime, networking, and presentation. The Studio import is additive and inert until each unique feature is reconciled against those owners.

## Preserved Studio material

- 28 Studio-only source files preserved losslessly under `imports/studio-2026-08-07/` as a restorable source archive.
- 1,775 Workspace objects preserved by identity/path in the restorable Workspace hierarchy index.
- Authored HubTown, dungeon portal, resource fields, landmarks/ruins, world structures, lighting/VFX and NPC structures retained as migration inputs.
- Legacy quest, gathering/crafting, vendor/economy, dungeon and UI concepts retained for best-of-both integration.

## Do not boot unchanged

`RPGServerBootstrap`, legacy `CombatService`, `EnemyService`, `InventoryService`, `LootService`, `PlayerDataService`, and `MonetizationService` are reference implementations only. They overlap newer server authority.

## Active v2.7 incident gate

The active-place network/Highlight incident still outranks feature expansion.

Current source containment on `main` now includes:

- an R1 `HordeStateEarlyListener` that binds `HordeNetwork.State` before the remaining client controller graph;
- bounded client diagnostics for listener-bound state, received/invalid message counts, and last revision;
- a conservative `BroadHighlightGuardController` that disables only Workspace/Terrain/very-large top-level world-root Highlight targets;
- bounded diagnostics for rejected broad Highlights and the last rejected target;
- temporary rollout flags in `RuntimeRolloutConfig`;
- rollback branch `archive/pre-v2.7-r1-containment-2026-08-07` at `6d88a33df1742981839c59933289eb0381e82074`;
- prepared runtime packet `../../docs/production/evidence/2026-08-07-336-r1-state-highlight-containment.md`.

Repository-side validation is green. Luau validation run `#800` (`31219832584`) passed repository contract validation, StyLua, Selene, every discovered Lune fixture, the Rojo build, and artifact upload.

### Canonical R1 Studio-test build

Use this exact CI artifact for the R1 runtime packet rather than an unrecorded local build:

- source/build commit: `2c870d270b96064c9a06343cc088b251299373f4`;
- artifact: `living-kingdoms-rbxlx-2c870d270b96064c9a06343cc088b251299373f4`;
- artifact ID: `9009926429`;
- digest: `sha256:587ccc2974f8188bde34a0a757213efb4b9f72e68e940db4615232cace28bf89`;
- artifact retention through 2026-08-21.

These are still E1/source-build facts only. The incident is **not closed** until a Studio/runtime packet proves the R1 behavior.

## Prepared next-stage work

Prepared work is intentionally isolated from `main`. CI success on these branches is not runtime acceptance and does not authorize merging them past their rollout gates.

### Draft PR #221 — single compatibility listener

`[BLOCKED] Prepare v2.7 single-listener Horde state bridge`

- branch: `rollout/v2.7-r1-listener-consolidation-prep-2026-08-07`;
- head: `9311a0978ce3c226462a7a5813346266f69440b0`;
- state: draft / blocked on the R1 Studio evidence packet;
- scope: transport-only migration of `HordeHUDController` and `MassacreCrescendoController` onto `HordeStateEarlyListener.subscribe(onState)`;
- result: `HordeStateEarlyListener` is the only physical `HordeNetwork.State.OnClientEvent` owner on the prepared branch;
- validation: Actions run `#805` (`31220415455`) passed repository contract, StyLua, Selene, all 196 discovered Lune fixtures, Rojo build, and artifact upload;
- prepared artifact: `living-kingdoms-rbxlx-01fb64491453bf2aa05c5107f01db9eed89f27a6`;
- artifact ID: `9010142515`;
- digest: `sha256:4cf474e38f5a39a4e854105e082587e4c1261a3538bfa3691025b0cedca638e0`.

**Do not merge PR #221 until the canonical R1 Studio packet passes.** The canonical R1 test build remains the `2c870d...` artifact listed above, not the prepared #221 build.

### Draft PR #222 — dormant R2 ready-gate primitive

`[STACKED/BLOCKED] Prepare v2.7 R2 ready-gated state publisher`

- branch: `rollout/v2.7-r2-client-ready-prep-2026-08-07`;
- base: PR #221 branch, not `main`;
- head: `e116462bd131021cf3b41c6ee70ac417a341857a`;
- state: stacked draft / blocked;
- adds a transport-agnostic `ReadyGatedStatePublisher` retaining latest pre-ready state by owner + remote ID + semantic key;
- behavioral fixture proves keyed latest-value retention, owner isolation, deterministic ready flush, bounded counters, cleanup, and a second readiness cycle;
- `EnableReadyGatedStatePublisher = false` on the stacked branch;
- source audit forbids a `ClientReady` remote/signal, bootstrap activation, or `HordeExperienceService` wiring while this remains preparation;
- R3 unchanged-state suppression is deliberately absent;
- validation: Actions run `#807` (`31220734943`) passed repository contract, StyLua, Selene, all 198 discovered Lune fixtures, Rojo build, and artifact upload;
- prepared artifact: `living-kingdoms-rbxlx-db68f5eaf92e39e8aaad961a8eed93b6eb86853a`;
- artifact ID: `9010258250`;
- digest: `sha256:f4cc0629ba0f4cec773654ae2dabf7b0de8625346f231d9a64dc6359b8ce9474`.

**Do not merge PR #222 directly to `main`.** It is stacked on #221 and prepares only the dormant R2 primitive. Actual `ClientReady` activation must be a later controlled change after R1 and listener-consolidation evidence permit it.

## Where to continue

1. Run/fill `../../docs/production/evidence/2026-08-07-336-r1-state-highlight-containment.md` using the exact canonical R1 CI artifact above.
2. If R1 passes, update `../../docs/production/V2.7-CUTOVER-LEDGER.md` with measured facts.
3. Recheck and promote PR #221 only after the R1 acceptance gate; then collect the listener-consolidation runtime evidence required by v2.7.
4. After #221 is accepted, use PR #222's tested primitive as the base for a **separate** R2 activation change that adds the ClientReady signal and ready-gates the intended producer path.
5. Do not begin R3 semantic/change-token suppression until R2 delayed-ready and late-join evidence passes.
6. Only after the v2.7 stop conditions are accepted should work resume on the preserved HubTown/preparation bridge, authored-world reconstruction, quest reconciliation, and procedural dungeon integration.

## Merge references

1. `../../docs/production/RBXL-MERGE-2026-08-07.md` — reconciliation matrix and M0–M5 integration order.
2. `../../docs/decisions/2026-08-07-living-kingdoms-rbxl-merge.md` — merge decision and authority rules.
3. `imports/studio-2026-08-07/README.md`, `manifest.json`, and `VALIDATION.md` — preserved Studio import details.

## Recovery

- Untouched pre-RBXL-merge repository: `archive/pre-rbxl-merge-2026-08-07` at `852de4953155379a4cc4733fe8dd05cd6f51477e`.
- Pre-v2.7-R1-containment repository: `archive/pre-v2.7-r1-containment-2026-08-07` at `6d88a33df1742981839c59933289eb0381e82074`.
