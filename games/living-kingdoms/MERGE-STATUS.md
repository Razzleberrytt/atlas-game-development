# Living Kingdoms Merge Status

**Current merge:** original Studio `livingkingdoms.rbxl` + canonical Atlas/Living Kingdoms Rojo source  
**Import date:** 2026-08-07  
**Current main milestone:** BA-005 property-backed authored-overworld reconstruction in progress  
**Runtime evidence posture:** repository/CI proven; single-player Studio boot verified 2026-08-08 after three runtime defects were fixed; full Studio multiplayer acceptance is still outstanding

## Read this first

This file is the current human-facing merge status.

Older migration documents that say only **122 / 1,775** Workspace rows survived describe the damaged first archive. They are historical planning evidence, not the current preservation state.

Current repaired/reconstruction evidence lives in:

- `../../docs/migration/REEXTRACTED-WORLD-EVIDENCE.md`
- `../../docs/migration/current/reextracted-world-evidence.json`
- `../../docs/migration/current/reextracted-property-evidence.json`
- `../../docs/migration/current/reextracted-presentation-evidence.json`
- `imports/studio-2026-08-07/reextracted/`

## Canonical rule

`games/living-kingdoms/src/` is the only gameplay-authoritative source tree.

The Studio import is preservation and migration input. It must never become a second combat, persistence, inventory, loot, enemy, mission, networking, monetization, quest, dungeon, gathering, or expedition authority.

Do **not** boot the imported duplicate runtime services beside the modern runtime.

## Preservation status

The original uploaded RBXL is intact and has been re-extracted directly.

Verified facts:

- source RBXL: `1,639,392` bytes
- source SHA-256: `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`
- Studio-only sources: **28 / 28** preserved exactly
- Workspace identity/hierarchy: **1,775 / 1,775** rows preserved
- Workspace index SHA-256: `320d1ec49b0bc3a0feaed7fdc07348a18ebc248682bddc1a338514c82421b6c3`

## Property-backed recovery status

BA-005 is no longer identity-only.

### Geometry/property decoder

PR **#232** added the tested binary world-property decoder and committed evidence.

Verified current base coverage:

- **1,699 Workspace property rows**
- 1,305 Parts
- 211 Models
- 146 PointLights
- 22 Fire instances
- 12 Attachments
- 2 SpawnLocations
- 1 ProximityPrompt
- zero failures among the base allowlisted property types

The decoder reproduces the known source-managed bootstrap floor/spawn positions and sizes directly from the RBXL, providing positive controls for CFrame/Vector3/flags decoding.

### UI/particle decoder

PR **#236** extended recovery into presentation types:

- UDim2
- Vector2
- transformed Int32
- NumberSequence
- ColorSequence
- SurfaceGui
- TextLabel
- ParticleEmitter

Expanded evidence now covers **1,742 Workspace property rows** with zero failures among the expanded allowlist.

## Recovered world scale

Current evidence proves:

- `Workspace/WorldStructures` — **1,190 identity rows**, including all 894 Part transforms in the current property scope
- `Workspace/HubTown` — **270 identity rows**, including all 157 Part transforms in the current property scope
- `Workspace/WorldPath` — **190 identity rows**, including all 189 segment transforms/sizes
- `Workspace/Resources` — **113 identity rows**, including all 62 Part transforms

Representative recovered authored geometry:

- Destiny Monolith core — `(0, 200, -1500)`, size `80 x 400 x 80`
- Crystal Tower spire base — `(1500, 15, 0)`, size `120 x 30 x 120`
- legacy DungeonPortal frame — `(0, 8, 22)`, size `10 x 16 x 4`

## Combined-game architecture

PR **#234** established the placement decision:

### Authored Overworld

The legacy authored world remains at **1:1 scale and original coordinates** as a separate future overworld coordinate space:

- HubTown
- Resources
- WorldPath
- WorldStructures
- original overworld spawn/environment presentation

Do not scale, translate, or parent this recovered world under the current operation foundation just to make it fit.

### Modern Operation Space

The current source-managed forest/expedition runtime remains a separate ±640-stud operation space and retains modern gameplay authority.

### Intended bridge

**safe/persistent authored overworld + HubTown → canonical expedition launch → modern operation/expedition runtime**

The current Ranger Station Forward Operations Hub remains a temporary bridge until the dedicated authored-overworld lifecycle/place boundary is implemented.

## Reconstruction contracts already merged

### WorldPath — PR #233

`src/shared/Config/RecoveredWorldPathConfig.luau`

The 189 identical legacy path slabs are represented as one deterministic held route contract rather than 189 canonical runtime instances.

- `SourceHold = true`
- `RuntimeEnabled = false`
- sampled canonicalization drift stays within `0.00011` studs of recovered float evidence

### DungeonPortal — PRs #235 and #236

`src/shared/Config/RecoveredDungeonPortalConfig.luau`

All 10 portal identities are accounted for:

- 1 generated container
- **9 / 9 non-container nodes property-backed**
- recovered parts, lights, attachment, SurfaceGui, TextLabel, and ParticleEmitter
- one explicitly known visual omission: TextLabel `FontFace`

Recovered presentation includes the original portal sign text and particle sequences, but the old `[G]` instruction is evidence only — not a modern input binding.

Future interaction still delegates to:

- `portal.expedition.primary`
- `ExpeditionLobbyService`

No legacy DungeonService/HubTownService authority is restored.

## What is live now

### Modern runtime

The modern source tree remains authoritative for:

- combat and weapons
- enemies and encounter direction
- operative life / revive / failure
- missions and results
- inventory, loot, survival resources and persistence boundaries
- class selection and class actions
- run progression and build state
- expedition lobby/runtime/lifecycle
- world foundation and operation landmarks

### Forward Operations Hub

PR **#230** added the live source-managed preparation shell at the Ranger Station/insertion area.

It exposes the existing Specialist Assignment, Armory Rack, and Expedition Terminal without creating duplicate gameplay owners. The existing `C` / `I` / `K` RPG menu remains canonical for character/inventory/skills.

The archived Studio HubTown remains held reconstruction input, not a live legacy runtime.

## Studio runtime defects fixed 2026-08-08

Three defects found by playing the build in Studio, each of which produced visible damage and none of
which any repository gate could catch:

1. **Client bootstrap halted at controller four.** `SurvivorController.start()` awaited
   `PlayerModule` with an unbounded `WaitForChild`. `default.project.json` builds
   `StarterPlayerScripts` from `$className`, and `PlayerModule` ships with the Studio place template,
   so a place built from this project has none. The bootstrap parked forever and none of the ~40
   controllers after it started: `PlayerGui` held only the CoreScript `Freecam`, and no HUD,
   crosshair, weapon, class, expedition or horde UI existed. Fixed in `91a1ebe`; `PlayerGui` now
   holds 22 ScreenGuis and `[Living Kingdoms] Client bootstrap started` prints.

2. **Enemy presentation rigs lost on replay.** `EnemyDirectorService.stop()` destroyed the
   `EnemyEntities` folder and `start()` created a new one. Roughly a dozen server and client
   consumers bind `ChildAdded` once and cache the instance, so every enemy spawned after the first
   replay stayed a bare root part. Fixed in `3b0d8e3` by reusing the folder across replay.

3. **DataStore construction cascade.** `RobloxInventoryDataStoreAdapter.new()` called `GetDataStore`
   unguarded, which throws in an unpublished place. That load-error propagated through
   `InventoryLiveService`, `inventory-network`, `expedition-reward-results` and
   `ExpeditionFoundationBootstrap`, leaving `ExpeditionResultNetwork` uncreated and two consumers in
   infinite yield. Fixed in `3b0d8e3` with a volatile in-memory fallback; live servers are unaffected.

The reported "wire-like outlines on everything" was **not** a source defect. It was
`settings().Rendering.EnableFRM = false` in the operator's local Studio, with
`settings().Physics.AreOwnersShown = true` adding network-ownership adorns. Both are machine-local
Studio settings and were reset.

### Consequence for v2.7 R1

Defect 1 meets the R1 evidence packet's own invalidating condition, "unrelated script errors prevent
client bootstrap", on every run of the pinned artifact. The R1 packet is therefore **blocked pending
a re-pin** to a build at or after `91a1ebe`. An informational local-build capture — listener bound,
547 messages, 0 invalid, guard active, no broad Highlights — is recorded in
`../../docs/production/evidence/2026-08-08-r1-capture-blocked-by-client-bootstrap-stall.md` and is
explicitly not accepted evidence.

## Current validation

The latest merged BA-005 presentation recovery PR **#236** passed Luau validation run **#854** (`31236157100`), including:

- repository contract validation
- complete Studio preservation verification
- historical migration-manifest validation
- base RBXL property decoder self-test
- presentation decoder self-test
- base property-evidence validation
- presentation-evidence validation
- StyLua
- Selene
- all discovered Lune fixtures
- Rojo build
- reproducible build artifact upload

PR #236 merged to `main` as `19c9999a20958969ee113f2294f97cfeedfd86ba`.

## What is not complete

Do not describe the games as fully fused yet.

Still open:

- dedicated authored-overworld place/lifecycle boundary
- actual held renderer/preview for recovered overworld groups
- broader HubTown static reconstruction beyond DungeonPortal
- TextLabel FontFace decoding for closer sign parity
- quest-board adaptation into modern mission contracts
- vendor/economy adaptation into canonical currency/inventory owners
- gathering/crafting through canonical inventory/persistence transaction boundaries
- remaining WorldStructures / vegetation / atmosphere reconstruction
- Terrain voxel recovery/parity
- Studio runtime / multiplayer evidence for the combined build

## Next highest-ROI task

**BA-005 — reconstruct the authored HubTown quest board as a held presentation contract, then design its adapter into the current mission system.**

Why next:

- the new presentation decoder already recovered its board/sign text and SurfaceGui/TextLabel properties
- its old interaction wording can be preserved as evidence without reviving QuestService
- it is a natural bridge between the old RPG overworld and the modern `MissionDirectorService`
- its one remaining major presentation gap is the BillboardGui container, which can be recovered with already-supported binary value types

Keep the same merge rule: recover old presentation faithfully; route future gameplay through modern owners.

## Recovery / milestone history

- rollback branch: `archive/pre-rbxl-merge-2026-08-07` at `852de4953155379a4cc4733fe8dd05cd6f51477e`
- PR #228 — repaired full Studio preservation
- PR #229 — canonical runtime/world-content ownership cleanup
- PR #230 — Forward Operations Hub shell
- PR #231 — replaced stale 122-row planning truth
- PR #232 — property-backed RBXL recovery tooling
- PR #233 — canonical held WorldPath contract
- PR #234 — separate authored-overworld coordinate-space decision
- PR #235 — first held DungeonPortal reconstruction contract
- PR #236 — UI/particle decoder + upgraded DungeonPortal presentation evidence
