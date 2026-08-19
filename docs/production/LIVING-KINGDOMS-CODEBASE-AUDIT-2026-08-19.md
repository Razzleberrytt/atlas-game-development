# Living Kingdoms — Codebase Audit and Fix/Upgrade Plan

**Status:** DERIVED AUDIT SNAPSHOT — NOT AN AUTHORITY
**Audited commit:** `e456e57fda9488f8ab1fd16e14840cd90115e473` (`main`, 2026-08-19)
**Auditor:** repository-first static audit; no Roblox Studio access in this environment
**Supersedes nothing.** Execution selection stays with `docs/roadmap/EXECUTION-DASHBOARD.md`; the
current product gate stays `docs/roadmap/STATIC-PLAYABLE-EVIDENCE-GATE.md`. This document is a
findings + sequencing proposal, not a new roadmap layer and not an evidence packet.

---

## 1. What was actually run

Every claim below is either a command result or a file/line citation. Nothing here is a runtime,
device, performance, or visual claim.

| Check | Command | Result |
|---|---|---|
| Docs/authority profile | `python scripts/validate.py docs` | **PASS** |
| Repository layout | `scripts/validate_living_kingdoms_layout.py` | **PASS** — 435 Luau sources, 446 Lune fixtures |
| Formatting | `stylua --check src tests tools` | **PASS** |
| Lune fixtures | all 446 `*.test.luau` (443 flat + 3 under `tests/presentation/`) | **PASS — 0 failures** |
| Rojo build (operation place) | `rojo build default.project.json` | **PASS** |
| Rojo build (Main World) | `rojo build main-world.project.json` | **PASS** |
| Lint | `selene games/living-kingdoms/src` | **NOT RUN — environment-blocked**, see F-C3 |
| Backlog coordination | `backlog/living-kingdoms/materialize_backlog.py --check` | **PASS** — 1000 tickets, mutex UNLOCKED, 0 BUILDING |
| Coverage registry | `scripts/development_coverage.py report` | health **46.5/100**, `studio` evidence on **0 / 300** concerns |
| Leverage audit | `scripts/efficiency.py audit` | 100 advisory findings (40 printed: 16 repeat, 16 hotspot, 8 authority; 60 omitted by the tool) |

**Honest gate statement:** the repository is green on everything CI can prove here except Selene,
which cannot fetch the Roblox API dump through this sandbox's TLS-terminating proxy. Selene is
therefore CI-only, exactly as `CLAUDE.md` warns. No runtime, multiplayer, device, performance, or
visual acceptance is claimed by this audit.

**Reproduction note:** tools are pinned in `rokit.toml` but were absent from this environment.
Lune 0.10.4, Rojo 7.7.0, StyLua 2.5.2 and Selene 0.31.0 were installed from their pinned upstream
releases before running the sweeps above.

---

## 2. Headline reading

The codebase is unusually disciplined for its size: 435/435 files are `--!strict`, there is not a
single `TODO`/`FIXME`/`HACK` marker, every `stop()` that opens connections closes them, time
handling is consistent (`GetServerTimeNow` for authority, `os.clock` for durations, no `tick()`),
and the documented lifecycle traps in `CLAUDE.md` #1, #3, #5 and #6 are all genuinely closed in
current source.

The risk has therefore moved off "is the code sloppy" and onto three other axes:

1. **Boot-time failure containment is asymmetric.** The client bootstrap was hardened; the server
   bootstrap was not. This is the single most likely way the current build fails the product gate's
   Gate A while every static check stays green.
2. **Evidence is stale relative to velocity.** 1,300 commits in 14 days; last real Studio
   observation is 2026-08-11 at `8544730`; the coverage registry records Studio evidence on zero of
   300 concerns.
3. **Two guard rails are narrower than the claims made about them**, and one validator produces
   false failures in the default agent checkout — so agents are getting misleading signal in both
   directions.

---

## 3. Findings

Severity is scoped to this project's own priorities: a finding is High if it can plausibly break
the current NOW gate or corrupt the signal agents execute against.

### A. Runtime correctness and robustness

#### F-A1 — Server bootstrap has no failure containment (High) — **FIXED in this branch**

`games/living-kingdoms/src/server/init.server.luau:115-179` requires 28 services at module level
and then calls 29 bare `.start()` functions in a deliberate order, with no `pcall`, no `task.spawn`,
and no isolation of any kind. One error in any require or any `start()` aborts the whole script and
silently kills **every service after it in the list** — including `MissionDirectorService`,
`WeaponLoadoutService`, `SurvivalLootService`, `NightCorruptionService` and, last,
`OperationLifecycleService`, the replay/cleanup owner.

The client already solved exactly this. `src/client/init.client.luau:5-38` documents the incident
("a client ends up with a single PlayerGui child instead of the ~22 a healthy session has") and
wraps every require and every step in `safeRequire`/`safeStep`, naming the failing controller and
continuing. The server never received the counterpart.

Why this matters now: Gate A of the static playable gate is boot/reset. A mid-list server failure
presents as "the expedition never starts / loot never drops / the run cannot be replayed" with no
single obvious error — the most expensive possible failure mode for a first-time-tester session.

Implementation constraint: 37 fixtures read `init.server.luau`, and several pin literal `X.start()`
tokens (`ServerBootstrapNetworkOrderSourceAudit`, `P4IntegrationValidation`,
`ReleaseCandidateRemoteSurfaceSourceAudit`, and others). The client refactor documents the same
constraint at `src/client/init.client.luau:28-32`: the call must stay written out at each site
rather than routed through a string. Any server fix must preserve those literal tokens.

Design caveat, decided explicitly: on the server, "continue past a failed owner" is not
automatically safer than stopping. `MatchResultService` starts before any owner that can commit a
fact precisely so facts are never committed without a ledger.

**Resolution (Phase 1.1).** All 29 service requires now load through `safeRequire` and all 29
starts run through `safeStep`, mirroring the client helpers, with every literal `X.start()` token
and its relative order preserved. `WorldFoundationService` and `MatchResultService` use a
`criticalStep` that warns by name and then re-raises, so the two owners whose absence would let the
server commit facts against a missing world root or a missing ledger still abort the bootstrap
rather than failing open. Contained failures are collected and warned by name at the end, as on the
client.

`ServerBootstrapIsolationSourceAudit` pins the guarantee and was mutation-tested against four
regressions: a bare `X.start()`, a bare `require(script.Systems.X)`, a critical owner downgraded to
`safeStep`, and `criticalStep` losing its abort. Each is caught.

Which owners are critical was decided deliberately and is worth reviewing. Only the two above
abort. Every other owner fails **closed** rather than wrong when skipped — an unstarted
`OperativeCombatRuntimeService` leaves `FireIntent` unlistened, so no damage resolves at all rather
than resolving unvalidated. `MovementValidationSystem` is the one contained owner that is a
validation boundary; it stays contained because its own module documents itself as "a prototype
sanity boundary, not production-grade exploit prevention", and because a skipped owner is now named
in the console rather than inferred. If that module is ever promoted to a real trust boundary, it
belongs in the critical set.

One existing audit had to change. `ServerBootstrapNetworkOrderSourceAudit` located the first service
require by matching `\nlocal %w+ = require(script.Systems.` — a spelling, not the guarantee. Once
requires load through the helper, that pattern matched nothing and the audit failed on a refactor
that preserves what it protects. It now matches any `require(script.Systems.` occurrence, which is
strictly **stronger**: it finds the genuinely first load rather than the first one that still looks
like the old form. This is the rewrite `CLAUDE.md` asks for — hold the guarantee, not the spelling —
and not a loosening; no assertion was removed or weakened.

#### F-A2 — Unbounded `WaitForChild` on Workspace folders, including in two started services (Medium)

Eleven untimed `WaitForChild` sites remain outside `src/client`:

| Site | Wait |
|---|---|
| `src/server/Systems/HordeExperienceService.luau:619` | `Workspace:WaitForChild("EnemyEntities")` inside `start()` |
| `src/server/Systems/HubPreparationService.luau:114` | `Workspace:WaitForChild(WorldRootName)` inside `start()` |
| `src/server/WorldVisualDressing.server.luau:186,192` | world root, `Landmarks` |
| `src/server/ModularEnvironmentDressing.server.luau:193` | world root |
| `src/server/modular-enemy-assets.server.luau:15` | `EnemyEntities` |
| `src/server/enemy-archetype-presentation.server.luau:11` | `EnemyEntities` |
| `src/main-world/server/MainWorldServer.server.luau:6,8,12` | `Shared`, stabilizer module, world root |
| `src/main-world/client/MainWorldClient.client.luau:5` | `ReplicatedStorage:WaitForChild("Shared")` |

The two inside started services are the material ones. In the current order they are satisfied —
`WorldFoundationService.start()` runs first and `EnemyDirectorService.start()` immediately precedes
`HordeExperienceService.start()` — but that is an ordering coincidence, not a bound. Note also that
containment from F-A1 would not help here: `pcall` catches errors, it does not interrupt a yield.
An unsatisfied `WaitForChild` inside `start()` stalls the bootstrap forever regardless.

`MeleeIntentService.luau:20-31` is the pattern to copy: a named `NETWORK_WAIT_SECONDS = 20` bound
plus an `assert` with a specific message.

#### F-A3 — The bootstrap-wait audits are narrower than the claim recorded against them (Medium)

Two audits exist and neither covers the gap above:

- `tests/ClientBootstrapDependencyWaitSourceAudit.test.luau:5-7` flags **any** untimed
  `WaitForChild`, but scans only `games/living-kingdoms/src/client`.
- `tests/ServerBootstrapDependencyWaitSourceAudit.test.luau:5-9` scans `src/server`, `src/shared`
  **and** `src/main-world`, but its two patterns only match `*Network` waits, so every `Workspace`
  and `Shared` wait passes by construction.

The consequence: `src/main-world/client/MainWorldClient.client.luau:5` — a live mapped client script
in `main-world.project.json:75-76` — carries an untimed wait that neither audit can see, while the
LKB-0033 closeout note in `backlog/living-kingdoms/status.csv` records that the client audit
"enforces zero untimed WaitForChild calls across the client tree."

The code is not currently dangerous (Rojo maps `Shared`, and the script is an allowlist-gated
no-op). The defect is that the guard rail is believed to be broader than it is, and the closeout
note tells the next agent not to open another wait-hardening ticket.

#### F-A4 — Dead defensive branch in `RelicModifierService` (Medium)

`src/server/Systems/RelicModifierService.luau:20-35` reads:

```lua
local equippedEquipmentModifierResolverModule = if ReplicatedStorage.Shared.Equipment == nil
    then nil
    else ReplicatedStorage.Shared.Equipment.EquippedEquipmentModifierResolver
```

with a comment stating that "narrow resolver fixtures and partial runtimes may omit them. Missing
composition dependencies therefore fail closed to neutral multipliers instead of crashing unrelated
relic behavior."

In the Roblox engine, indexing an `Instance` with a missing child name **raises** ("Equipment is not
a valid member of Folder"); it does not return `nil`. So in the exact scenario the comment
describes, this module errors at load, taking the whole require chain behind it — the opposite of
failing closed. Line 32 (`script.Parent.InventoryLiveService`) has the same shape.

This passes every fixture because the Lune harness hands modules plain Lua tables, where a missing
key legitimately is `nil`. The fixture stub and the engine disagree, and the fixture is the one
being believed. Fix is one word each: `:FindFirstChild("Equipment")`.

This is worth flagging beyond the single site because it is a **class**: any `--!strict` nil-guard
written against a dot-indexed Instance child is dead code that our test harness cannot detect.

### B. Trust and abuse surface

#### F-B1 — Inventory remotes validate everything except call rate (Medium)

`src/server/inventory-network.server.luau:241-306` handles `readOwnInventory`, `compareOwnedItem`,
`equipOwnedItem`, `unequipOwnedSlot` and `dismantleOwnedItem`. Identity is forced to the invoking
player, cross-player access is rejected, payload types are checked, and mutation goes through
`InventoryLiveService` with owner/lease validation. That part is correct — there is no duping or
authority hole here.

What is absent is cadence bounding, which `games/living-kingdoms/AGENTS.md` requires ("Repeatable
intents must be bounded"). Each accepted `equipOwnedItem` runs `reconcileEquipmentEffects`, a weapon
activation queue step, and `pushTo(player)` replication. A client can invoke these as fast as it can
round-trip. This is a server-cost/DoS shape, not a correctness one.

Per the current dashboard this is explicitly **not** NOW work ("generic hardening without a measured
defect"). It is listed so it is not rediscovered as novel, and so it can be picked up the moment the
gate produces a measured symptom.

### C. Validation system

#### F-C1 — `validate.py` reports false failures in a shallow clone (High for agent throughput) — **FIXED in this branch**

`scripts/validate_roadmap_authority.py:85-103` resolves every backticked commit hash cited by an
authority document. `commit_exists` already returns `None` (skip) when git is unavailable, but a
**shallow** clone is not handled: `git cat-file -e` fails, `git rev-parse --is-inside-work-tree`
succeeds, so the function returns `False` and the hash is reported as dangling.

On the checkout this session started from (depth 96), `python scripts/validate.py docs` failed with
five "dangling commit reference" errors in `EXECUTION-DASHBOARD.md` and `V2.7-CUTOVER-LEDGER.md`.
After `git fetch --unshallow`, the identical command passed. CI uses `fetch-depth: 0`
(`.github/workflows/luau-validation.yml:56-58,117-119`) so CI is unaffected — which is worse, not
better: an agent sees a red gate that CI will never reproduce, and the documented advice in
`CLAUDE.md` ("a red run here looks exactly like a red `main` and is not") does not cover this cause.

**Resolution (Phase 0.1).** `commit_exists` now treats a shallow repository as unanswerable rather
than as evidence of a bad hash, and the OK line names which of the two reasons applied
(`commit checks skipped: shallow clone`) instead of always claiming git was unavailable. Detection
uses `git rev-parse --is-shallow-repository`, falling back to the `shallow` marker file for git
older than 2.15. A genuinely dangling hash in a complete clone still fails.

The self-test now builds a real origin, a full clone and a `--depth 1` clone in a temp directory and
asserts the whole decision table, including that the full clone still rejects a bad hash; it is
wired into the `docs` profile so the behavior is gated rather than asserted in prose. Verified
end-to-end against a fresh `--depth 5` clone of this repository: five dangling-reference errors
before, clean with the skip reason after.

#### F-C2 — No Luau type-check gate (Medium)

`validate.py` runs layout, StyLua, Selene, 446 Lune fixtures, and two Rojo builds. Nothing type-
checks Luau. All 435 source files declare `--!strict` and there are 259 `:: any` escapes, so the
strict annotations are currently decorative: neither the declarations nor the escapes are verified
by anything. `rokit.toml` does not pin an analyzer.

This is the highest-leverage *new* gate available, because it catches the F-A4 class of defect
(among others) that neither StyLua, Selene, nor a table-stubbed Lune fixture can see.

#### F-C3 — Selene is the only network-dependent gate and cannot run in a proxied sandbox (Medium)

Selene 0.31.0 fetches the Roblox API dump over rustls with compiled-in roots and ignores
`SSL_CERT_FILE`, so it fails with `invalid peer certificate: UnknownIssuer` behind this session's
TLS-terminating proxy even though the dump URL itself is reachable by `curl`. `selene
generate-roblox-std` offers no offline input. The result is that no agent in a proxied environment
can reproduce the exact gate CI runs, and the profile aborts at Selene *before* the 446 fixtures and
both Rojo builds — so one environment limitation hides all the checks that would otherwise work.

Two independent improvements: commit a generated `roblox.yml` with a refresh script so Selene runs
offline, and reorder `validate_toolchain_and_game` so fixtures and builds run before the one step
that needs the network.

#### F-C4 — The suite leans hard on source-text audits (Low–Medium)

159 of 446 fixtures are `*SourceAudit*`; 441 read source text with `fs.readFile`; 280 actually load
and exercise a module with `luau.load`. `CLAUDE.md` already warns that audits pinning exact call
shapes "break on correct refactors and should be rewritten to hold the guarantee, not the spelling."
F-A3 is the other failure mode of the same technique — an audit whose pattern is narrower than the
guarantee it is cited as proving. No sweeping rewrite is warranted; the actionable version is to
re-express an audit whenever it is touched, and to prefer `luau.load` for new coverage.

### D. Architecture and dead weight

#### F-D1 — 73 of 407 modules have no runtime path (Medium)

Transitive require-reachability from all 28 entry scripts (`*.server.luau` / `*.client.luau`,
following both dotted and string requires) reaches 334 of 407 non-entry modules. The other 73 —
about 18% of the source tree — are formatted, linted, counted in the layout gate and covered by
fixtures, but are never executed by either place. They include:

- 7 server systems: `AutomaticCombatDevelopmentHarness`, `DiscoveryMemoryService`,
  `EnemyArchetypeRuntimeBridge`, `EnemyEncounterComposer`, `EnemyEncounterService`,
  `EquipmentRewardDeterminismProbe`, plus `server/Networking/ReadyGatedStatePublisher`;
- 2 client controllers: `MassacreCrescendoController`, `RunProgressionHUDController`;
- ~35 shared configs, including every `MainWorld*Config`, every `EnvironmentAssetKitRegistryWave2-7`,
  every `Recovered*Config`, and `VisualAssetConfig`;
- ~25 shared contracts/resolvers (`Perception`, `Quest`, `Vendor`, `NPC`, `Gathering`, `Crafting`).

Some of this is deliberate and documented: `RunProgressionHUDController` is called out in
`CLAUDE.md`, and `MassacreCrescendoController` is *pinned* dormant by
`tests/MassacreCrescendoSourceAudit.test.luau:88-89`, which asserts the bootstrap does **not** start
it. That is the right pattern. Most of the other 71 carry no such marker, so a reader cannot
distinguish "prepared seam, intentionally dormant" from "wired up and quietly broken" from "orphaned."

The valuable output is not deletion — it is a one-time classification into
{dormant-by-design, should-be-wired, retire}, with the dormant set given the same explicit treatment
`MassacreCrescendoController` already has.

#### F-D2 — 40 independent per-frame bindings (Low)

20 `RunService.Heartbeat:Connect` on the server and 20 `RenderStepped`/`BindToRenderStep`/`PreRender`
bindings on the client, each carrying its own accumulator-and-threshold block. That is a coherent
per-owner design and nothing is wrong with it, but it is also the shape that `AGENTS.md`'s
compounding rule names as a leverage trigger, and it is the natural seam if the gate produces a
frame-time symptom. Do not refactor it speculatively; note it as the pre-identified response if
Gate B or a device pass reports responsiveness problems.

#### F-D3 — Advisory leverage findings (informational)

`scripts/efficiency.py audit` reports 100 findings and prints the top 40: 16 `repeat`, 16 `hotspot`,
8 `authority`. The authority ones flag 8 sites creating remotes outside canonical `Networking` (`init.server.luau`,
`inventory-network`, `expedition-lobby`, `expedition-presentation`, `expedition-reward-results`,
`melee-input`, `operative-progression`, `OperativeReviveSessionService`). Per `AGENTS.md` these are
advisory candidates, not refactor orders; several are the documented runtime-only `ensure*Network()`
owners described in `CLAUDE.md`. Listed for completeness, not proposed as work.

### E. Documentation and status integrity

#### F-E1 — `CLAUDE.md` has drifted from the tree it describes (Medium)

`CLAUDE.md` is the agent contract, so its errors propagate into every session:

| `CLAUDE.md` says | Actual |
|---|---|
| "Roughly 355 `*.test.luau` fixtures" | 446 |
| "About 60 of them are `*SourceAudit.test.luau`" | 159 |
| "sit flat under `tests/` (no subdirectories)" | `tests/presentation/` holds 3 |
| "`src/server/Systems/` (~85 modules)" | 106 |
| "`src/client/Controllers/` (~50 modules)" | 56 top-level, 60 recursive |
| Trap #4: "The client bootstrap has no per-controller isolation — no `pcall`, no `task.spawn`" | **False** since the `safeRequire`/`safeStep` refactor; the residual client hazard is the *yield*, not the error — and the statement is now true of the **server**, where it is not stated |

Trap #4 is the damaging one: it points agents at a hazard that has moved, and away from the one
that is live (F-A1).

#### F-E2 — Evidence is stale relative to development velocity (Medium)

`scripts/dev_metrics.py` reports 1,300 commits and ±120k lines churn in 14 days. Against that:

- the coverage registry records `studio` evidence on **0 of 300** concerns and `section-inferred`
  on 206;
- the most recent substantive Studio observation is `docs/production/evidence/2026-08-11-operation-place-studio-bootstrap-health.md`
  at commit `8544730` — healthy, 22 PlayerGui children, but explicitly "observations only", place
  identity **not proven**, and roughly 1,300 commits behind current `main`;
- the three other recent evidence files are all blocked runs (client-bootstrap stall, Studio bridge
  blocked, place identity blocked);
- four LKB tickets are `VERIFIED` in `status.csv` on validation-and-merge evidence, while the status
  vocabulary in `AGENTS.md` reserves `VERIFIED` for "required evidence passed."

Nothing here is dishonest — each closeout note states exactly what evidence backs it. But the
aggregate reading is that the project's confidence is entirely source-derived, which is precisely
why the dashboard's current NOW is the right call and why it should not be deferred again.

#### F-E3 — Open-PR debt (Low)

12 open PRs, most last touched 2026-08-15. Several are stacked on non-`main` bases (#579 → `agent-4/
progression-core-wave-1`, #566 → `main` but from that same chain) and #578 is `main` → an agent
branch. `AGENTS.md` asks for one active implementation PR, at most two. Four days of `main` drift on
a repo moving ~90 commits/day means most of these need a fresh base/overlap audit before anyone
treats them as current work — which is exactly what `AGENTS.md` warns about ("an old open PR is not
automatically current work").

---

## 4. Plan

Sequenced so that nothing blocks the current NOW gate, and so the two findings that could *cause* a
gate failure land before the gate runs.

### Phase 0 — Restore honest tooling signal (R0/R1, no gameplay risk)

| # | Work | Files | Validation |
|---|---|---|---|
| 0.1 | **DONE** — shallow repository treated as "hash checks unanswerable" (F-C1) | `scripts/validate_roadmap_authority.py`, `scripts/validate.py` | `validate.py docs` green; self-test exercises full and `--depth 1` clones |
| 0.2 | Commit a generated `roblox.yml` + refresh script; move Selene after fixtures/builds in `validate_toolchain_and_game` (F-C3) | `selene.toml`, `scripts/`, `validate.py` | `validate.py full` offline |
| 0.3 | Refresh `CLAUDE.md` counts; rewrite trap #4 to say the client error path is contained, the client *yield* path is not, and the server has neither (F-E1) | `CLAUDE.md` | `validate.py docs` |

Rationale for going first: 0.1 and 0.2 are what make every later phase's "green" believable to an
agent working outside CI, and 0.3 is what stops the next session from re-deriving a hazard that
moved.

### Phase 1 — Boot/reset safety, i.e. the Gate A prerequisites (R2)

| # | Work | Notes |
|---|---|---|
| 1.1 | **DONE** — client containment mirrored into `src/server/init.server.luau` (F-A1) | Literal `X.start()` tokens and order preserved; `WorldFoundationService` and `MatchResultService` abort by name via `criticalStep`; `ServerBootstrapIsolationSourceAudit` added and mutation-tested |
| 1.2 | Bound the two in-service Workspace waits, then the five root-script waits (F-A2) | Copy `MeleeIntentService.luau:20-31`: named timeout constant + `assert` with a specific message |
| 1.3 | Widen both wait audits (F-A3) | Client audit: add `src/main-world/client` (and any future client root). Server audit: flag every untimed `WaitForChild`, not only `*Network` ones. Correct the LKB-0033 closeout note to state the audits' real scope |
| 1.4 | Replace the dot-index nil-guards in `RelicModifierService.luau:20-35` with `FindFirstChild` (F-A4) | Add a fixture whose stub *raises* on a missing child, so the harness stops disagreeing with the engine. Then sweep for the same class repo-wide |

Phase 1 is the only phase that should precede the gate run. Each item maps to an existing canonical
owner and adds no new authority, no new remote, and no new state — consistent with the gate's
"do not rebuild the game" rule.

### Phase 2 — Run the static playable evidence gate (blocked here)

Unchanged from `docs/roadmap/STATIC-PLAYABLE-EVIDENCE-GATE.md`: Gates A–D on the fixed layout, with
a fresh evidence packet from `docs/production/V2.7-EVIDENCE-PACKET-TEMPLATE.md` carrying exact
build/commit/place identity.

**This phase cannot be executed from this environment** — it requires Roblox Studio. It is the
project's actual bottleneck, and after Phase 1 it is also the only remaining NOW work. Record the
result as a new packet; do not edit `2026-08-11-operation-place-studio-bootstrap-health.md`.

If the gate FAILs, its own rule applies and overrides everything below: one measured failure, one
canonical owner, one smallest focused FIX, rerun the affected gate.

### Phase 3 — Add the missing type gate (R1)

3.1 Pin an analyzer in `rokit.toml` and add a **report-only** analyze step, so the current 259
`:: any` escapes and any latent strict-mode violations become visible without turning `main` red.
3.2 Triage the report; fix or explicitly waive.
3.3 Promote to a blocking step in `validate.py` once clean.

Deliberately after Phase 2: it is the highest-leverage new gate, but it proves nothing about whether
the game is fun, and the gate result may reorder everything.

### Phase 4 — Dead weight, leverage, and hardening (R1/R2, gate-informed)

4.1 Classify the 73 unreached modules into {dormant-by-design, should-be-wired, retire}; give the
dormant set the explicit audit treatment `MassacreCrescendoController` already has, so the state is
readable from source rather than inferred (F-D1).
4.2 Bound cadence on the inventory remotes (F-B1) — pick this up when the gate or a load observation
produces a symptom, or when adjacent inventory work is already open.
4.3 Hold the single-scheduler consolidation (F-D2) unless Gate B or a device pass reports a
frame-time symptom.

### Phase 5 — Process hygiene (R0, parallel-safe)

5.1 Triage the 12 open PRs against current `main`: rebase, close as superseded, or convert to
recorded candidate evidence the way #666 was (F-E3).
5.2 Reduce dashboard churn. `EXECUTION-DASHBOARD.md` is the single most-touched and highest-churn
file in the repo (53 touches, 4,449 lines churned in 14 days), ahead of every source file. Some of
that is the coordination protocol working as designed; the part that is re-litigation is pure
overhead against a 1,300-commit fortnight.

---

## 5. Explicitly not proposed

- No rebuild or replacement of any camera, combat, enemy, mission, loot, inventory, persistence,
  expedition, or world owner.
- No procedural/spatial work. LKB-0481 stays DEFERRED with PR #666 preserved as candidate evidence;
  re-audit is a post-gate decision.
- No new remotes, no new authority, no second presentation path.
- No content, class, crafting, economy, social, or monetization breadth.
- No loosening of any existing audit to make a change pass. F-A3 asks for the audits to be
  **widened**, not relaxed.

## 6. Status

**Audit: complete.** Findings are static-source and tooling facts, reproducible from the commands in
§1 at `e456e57`.

**Plan: Phase 0.1 and Phase 1.1 implemented on this branch** (F-C1 and F-A1). Everything else in
§4 remains proposed and unexecuted. Phase 1.1 is **BUILT — VERIFICATION PENDING**: it changes server
bootstrap behavior, so its intended effect under a real service failure is a Studio observation, not
something the fixture suite can prove.

**Blocked:** Phase 2 requires Roblox Studio, unavailable in this environment. Selene (F-C3) is
environment-blocked here and remains CI-verified.

**Next highest-ROI action:** Phase 1.2 and 1.3 — bound the two in-service `Workspace` waits (F-A2)
and widen both bootstrap-wait audits to the scope their recorded claim already asserts (F-A3).
Together they close the remaining boot/reset hazard that containment cannot reach, because a yield
is not an error and `pcall` does not interrupt one.
