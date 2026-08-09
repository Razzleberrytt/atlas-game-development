# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Scope

`AGENTS.md` (root) and `games/living-kingdoms/AGENTS.md` are the operating contract — read them for task selection, roadmap authority, and the completion-report format. This file covers commands and architecture that require reading many files to reconstruct.

The only game is `games/living-kingdoms/`. Task prompts often say bare `src/server/...`; prepend `games/living-kingdoms/`. Repo-root `src/` does not exist.

## Commands

All tools are pinned in `rokit.toml` (rojo 7.7.0, selene 0.31.0, stylua 2.5.2, lune 0.10.4) and resolve from PATH via `~/.rokit/bin`. **Run everything from the repository root** — `selene.toml`/`stylua.toml` live there and every Lune fixture reads source via repo-root-relative `fs.readFile("games/living-kingdoms/src/...")` paths.

```bash
# Full gate set, in CI order (.github/workflows/luau-validation.yml)
python scripts/validate_living_kingdoms_layout.py
python scripts/verify_studio_import_package.py
python scripts/validate_migration_manifests.py
python scripts/roblox/extract_rbxl_world_properties.py --self-test
python scripts/roblox/extract_rbxl_presentation_properties.py --self-test
python scripts/roblox/extract_rbxl_billboard_properties.py --self-test
python scripts/validate_reextracted_property_evidence.py
python scripts/validate_reextracted_presentation_evidence.py

stylua --check games/living-kingdoms/src games/living-kingdoms/tests games/living-kingdoms/tools
selene games/living-kingdoms/src

find games/living-kingdoms/tests -type f -name '*.test.luau' -print0 | sort -z | xargs -0 -n1 lune run

rojo build games/living-kingdoms/default.project.json --output /tmp/LivingKingdoms.rbxlx
```

Run one fixture:

```bash
lune run games/living-kingdoms/tests/BraceResolver.test.luau
```

Windows/PowerShell equivalent of the fixture sweep:

```powershell
Get-ChildItem games/living-kingdoms/tests -Recurse -Filter *.test.luau | Sort-Object Name | ForEach-Object { lune run $_.FullName }
```

Scope notes: StyLua covers `src`, `tests`, `tools`. **Selene covers `src` only** — it downloads the Roblox API dump from `setup.rbxcdn.com`, so it is CI-only in network-blocked sandboxes.

## Test architecture

Roughly 200 `*.test.luau` fixtures sit flat under `games/living-kingdoms/tests/` (no subdirectories). They are plain Lune scripts that `error()` on failure — there is no test framework, no runner config, and no `describe`/`it`. `scripts/validate_living_kingdoms_layout.py` prints the authoritative current source/fixture counts if you need exact numbers.

A bare `require("../src/...")` cannot load any module that touches `game:GetService`. The working pattern is `luau.load(fs.readFile(path), { environment = { game = <stub>, require = <token dispatcher>, script = <fake tree> } })` — dependencies are handed in as sentinel tokens and the injected `require` asserts it only ever sees expected ones. `tests/ExpeditionRuntime.test.luau` is the reference for a multi-module graph; `tests/BraceResolver.test.luau` for a single resolver.

About 60 of them are `*SourceAudit.test.luau`: they `fs.readFile` a source file and assert on token presence/absence to lock an architectural invariant (e.g. `AuthoritativeShotEffectsSourceAudit` forbids `SoundId =` inside `WeaponShotEffectPresenter`). When one fails, decide whether the invariant or only its syntactic expression changed — audits that pin exact call shapes break on correct refactors and should be rewritten to hold the guarantee, not the spelling. Do not loosen an audit to make a change pass.

## Runtime architecture

Rojo (`games/living-kingdoms/default.project.json`) maps:

| Source | DataModel |
| --- | --- |
| `src/client` | `StarterPlayer/StarterPlayerScripts/Client` |
| `src/server` | `ServerScriptService/Server` |
| `src/shared` | `ReplicatedStorage/Shared` |

Changing a destination requires a migration note, build validation, and a Studio smoke test.

**Networking is folder-per-domain RemoteEvents under `ReplicatedStorage`.** Two declaration sites exist and they are deliberately *not* symmetric:

- `default.project.json` statically declares `CombatNetwork`, `MissionNetwork`, `HordeNetwork`, `FlashlightNetwork`, `SquadPingNetwork`. `tests/P5IntegrationValidation.test.luau` pins this committed surface at **9 remotes** — adding one there fails that fixture until the count is updated deliberately.
- `src/server/init.server.luau` runs nine idempotent `ensure*Network()` functions at boot that create-or-assert class shape. These cover the statically declared folders *except* `HordeNetwork`, and additionally create `SurvivalNetwork`, `ClassNetwork`, `WeaponLoadoutNetwork`, `ProgressionNetwork`, and `RunBuildNetwork`, which exist only at runtime.

So check which site a folder actually lives in before adding to it, and reuse the existing folder for its authority boundary rather than allocating a parallel remote.

**Bootstrap is a flat sequence in both processes.** `src/server/init.server.luau` requires ~30 services from `script.Systems` and calls `.start()` in a deliberate order (`WorldFoundationService` first; `MatchResultService` before any owner that can commit a fact; `OperationLifecycleService` last so the replay/cleanup owner subscribes to an already-running mission). `src/client/init.client.luau` starts ~50 controllers the same way, preceded by two rollout-flagged listeners (`HordeStateEarlyListener`, `BroadHighlightGuardController`, gated by `RuntimeRolloutConfig`) bound ahead of the controller graph so no publish window opens unlistened. The order carries meaning — read the inline comments before reordering.

Layer roles:

- `src/server/Systems/` (~85 modules) — authoritative services, one `.start()` owner each.
- `src/server/Domain/` — pure resolvers pulled out of services for direct fixture testing.
- `src/shared/` — contracts, `Config/` (all balance constants centralized here), and deterministic resolvers testable under Lune. Do not couple these to live Roblox services.
- `src/client/Controllers/` (~50 modules) — input, camera, HUD, intent sending. `src/client/Presentation/` — factories/resolvers that build visuals. Client establishes no consequential truth.

**Single-owner rule.** Exactly one production owner per responsibility. Concretely: `RunProgressionService` owns all XP/levels/upgrades via `ProgressionNetwork` (`ChooseUpgrade` is the only upgrade remote); `EnemyLootService` owns ammunition loot; `HordeExperienceService` owns spawning/pressure/threat and must not own XP, upgrades, loot, or healing; `HordeHUDController` is the single combat HUD (`RunProgressionHUDController` still exists as code but is intentionally never started). Highlights route through the shared lease/ownership architecture, never competing allocations.

`games/living-kingdoms/imports/` is preservation material for the recovered 2026-08-07 Studio place. Nothing under it may become a second gameplay authority — do not boot its legacy managers alongside the modern runtime. See `games/living-kingdoms/CANONICAL-RUNTIME.md` for what is live versus held.

## Traps that pass every gate

These produce no error at authoring time and no failing fixture, but silently disable code:

1. **`ServerScriptService:WaitForChild("Systems")` yields forever.** Rojo puts modules at `ServerScriptService.Server.Systems`. From a sibling `*.server.luau`, use `script.Parent.Systems`.
2. **`})` followed on the next line by `(expr).field = x` is a parse error** — Luau reads it as calling the table, and the whole module fails to load. Assign through a local first.
3. **Dot-call vs colon-call adapter contracts.** `ExpeditionEncounterCoordinator.EncounterAdapter` declares `start`/`cancel` self-less and invokes them with `.`; an adapter defining them as `:` methods silently receives `self = context` and returns false forever. Bind such functions on the instance in `new()`.
4. **An unbounded `WaitForChild` in any controller halts every controller after it.** The client bootstrap has no per-controller isolation — no `pcall`, no `task.spawn`. Commit `91a1ebe` fixed the one live instance (`SurvivorController` awaiting `PlayerModule`, which is not in the Rojo place because `default.project.json` builds `StarterPlayerScripts` from `$className` while `PlayerModule` ships with the Studio template) by bounding that wait and warning, but the structural hazard remains for every new controller. Always bound waits in controller `start()`.
5. **Module-level `GetDataStore()` throws in an unpublished place** and load-errors the entire require chain behind it.
6. **Workspace folder identity must survive a replay.** ~15 modules reference `EnemyEntities`, and the server presentation/loot/experience/probe owners plus the client presentation/impact/audio/telegraph controllers each cache the instance and bind `ChildAdded` to it once. Destroying the folder on stop orphans every binding, so post-replay enemies keep a bare server root and never get a presentation rig. `EnemyDirectorService` now clears children instead (see its `clearEnemyFolder` comment) — hold that rule for any folder with cached consumers.

## Studio evidence discipline

Every fixture, StyLua, Selene, and the Rojo build can be green while the game is visibly broken in Studio. Source/static gates cannot observe bootstrap ordering, instance identity across a lifecycle, device behavior, or the renderer.

For any "it looks broken" report, play the build and probe the live datamodel before reading source: `get_console_output`, then `#PlayerGui:GetChildren()` (expect ~22, not 1 — the fastest client-health probe), then the relevant Workspace folder. Some symptoms are machine-local Studio settings that do not live in the repo at all (`settings().Rendering.EnableFRM = false` causes wire-like outlines; `settings().Physics.AreOwnersShown` adds network-ownership adorns).

Never claim runtime, multiplayer, performance, device, or visual acceptance from CI. The evidence ladder is `E0 design → E1 source/static → E2 Studio init → E3 single-player → E4 multiplayer → E5 device/perf → E6 outside-player fun → E7 live telemetry`. Read the current accepted evidence level from the current roadmap/evidence packet; do not hard-code it from this companion file. Studio-only claims need a fresh evidence packet (`docs/production/V2.7-EVIDENCE-PACKET-TEMPLATE.md`) with exact build/commit/place identity — never edit an older packet to fit a later result.

A source implementation can still be complete while Studio evidence is open. Label that state **BUILT — VERIFICATION PENDING** and continue dependency-safe work unless a concrete safety/evidence dependency makes further work unsafe or misleading.

## Assets

`src/shared/Config/VisualAssetConfig.luau` (VIS-0101) is the registry: every presentation surface has a `statusId` and owner path, and `sourceReference` text may not contain `rbxassetid://`. To add a real asset: new config with the id + a dedicated client-local owner + a registry entry bumped to `TemporaryPresentation` + a source audit locking the bounded/no-authority shape. Verify ids actually load through the Roblox Studio MCP (`search_asset`, then `insert_asset` and check `Sound.IsLoaded`/`TimeLength`) and delete the probe instances afterward. Never invent asset, animation, product, place, or universe IDs.

## Roadmap authority

Use the roadmap layers for different jobs:

- `docs/roadmap/MVP-BUILD-THROUGH-TESTING-POLICY.md` controls execution cadence and status meaning. General roadmap locks are retired; use **BUILT — VERIFICATION PENDING** versus **VERIFIED**, and use **BLOCKED** only for a concrete named reason.
- `docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md` supplies the preferred player-facing milestone sequence and highest-ROI visible target.
- `docs/roadmap/MASTER-ROADMAP.md` describes the complete destination and requirement inventory.
- `docs/roadmap/BLUEPRINT-V2.7-EXECUTION.md` protects current runtime safety/stabilization boundaries where downstream work genuinely depends on them.
- `docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md` is prepared-work and dependency context, not a permission list. Historical `READY`, `PREPARED`, or `[L]` labels do not by themselves prohibit useful dependency-safe implementation.

Later-phase work may be implemented when it directly advances the current playable milestone, removes a real dependency, establishes a needed canonical interface, or is a small isolated high-value improvement. Avoid broad speculative expansion with no near-term payoff.

Never trust a status line in a stale doc blindly. Re-fetch current `main`, check overlapping open PRs, reconcile status against the current Build-Through policy, and preserve actual evidence truth.

Generated `.rbxl`/`.rbxlx`/sourcemap files are gitignored build output, not source — do not edit them, and do not replace `src/` from an imported place.