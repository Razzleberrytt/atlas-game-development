# Main World Source Representation and Placement Strategy

**Roadmap ticket:** BA-011

**Lane:** controlled build-ahead

**Status:** strategy complete; runtime activation held

**Evidence level:** E1 source/static only

This specification turns the BA-010 environment audit and the accepted authored-overworld coordinate decision into a reviewable source, place, streaming and anchor boundary. It does not activate the recovered world, create a Roblox place, assign a place ID, reconstruct Terrain or change the current operation runtime.

## Decision

The authored Main World will use a **dedicated place/project boundary** in the same Roblox experience. The current [`default.project.json`](../../games/living-kingdoms/default.project.json) remains the canonical modern operation build.

The future Main World project must:

- map a single `Workspace/LivingKingdomsMainWorld` root;
- preserve recovered authored coordinates at 1:1 scale with no global translation or rotation;
- share only canonical source modules and deliberately selected lifecycle bootstraps;
- exclude `WorldFoundationService` operation-world generation from the Main World bootstrap;
- exclude every preserved legacy gameplay service;
- omit place and universe IDs until real values are supplied through an authorized publishing workflow.

A second Rojo project file is not added by BA-011 because there is not yet a reviewable model/Terrain payload to map. Creating an empty project would imply a runnable boundary that does not exist. Its creation gate is the first property-validated coherent Main World model group plus an explicit bootstrap allowlist and reproducible offline build check.

The machine-readable held contract is [`MainWorldRepresentationConfig.luau`](../../games/living-kingdoms/src/shared/Config/MainWorldRepresentationConfig.luau).

## Why a dedicated place boundary

The recovered world spans approximately X `-1844..2832`, Y `0..1400`, Z `-3184..1900`; the current operation is intentionally bounded around a ±640-stud forest. Loading both under one Workspace would couple unrelated streaming, lighting, lifecycle, replication and performance budgets while making accidental cross-world parenting easier.

The dedicated boundary preserves the intended loop:

```text
authored Main World
→ canonical expedition selection / readiness
→ modern operation place/runtime
→ explicit result and return handoff
→ authored Main World return anchor
```

This is a representation decision, not a teleport/session implementation. Party ownership, reserved-server policy, handoff payloads, reconnect behavior and failure recovery remain gated design work.

## Source ownership matrix

| Artifact | Canonical representation | Ownership and review rule |
|---|---|---|
| Recovered identities/properties | Strict Luau configs under `src/shared/Config` | Evidence-derived, deterministic and fixture-tested; never interpreted as active gameplay. |
| Stable gameplay references | `WorldContentConfig` and shared contracts | Stable IDs bridge presentation to canonical owners; legacy instance names are aliases only. |
| Reconstructed static groups | Future `.rbxmx` model assets under `assets/recovered-world/models` | One coherent authored group per review unit after property parity validation; never one whole-world dump. |
| WorldPath | Route/control-point data plus bounded render chunks | Preserve the 1:1 path; do not promote 189 loose slabs as the canonical authoring interface. |
| Terrain voxels | Studio-owned, accompanied by a source manifest and captures | No recovered Terrain evidence currently authorizes reconstruction. Hash, bounds, origin, tool/process and Studio evidence are required. |
| Lighting/audio/environment profiles | Source-managed profile data plus approved Studio assets | One lifecycle owner per active profile; asset IDs must be real and permission-verified. |
| Generated `.rbxl`/`.rbxlx` and sourcemaps | Build output | Reproducible and ignored as source; never committed as the canonical world. |
| Legacy scripts/imports | Preservation/reference only | Never mapped into an active bootstrap or made authoritative. |

## Rojo layout target

When its creation gate is satisfied, the dedicated project should compose existing canonical source selectively rather than copy it:

```text
DataModel
├── ReplicatedStorage
│   └── Shared                         ← canonical shared modules
├── ServerScriptService
│   └── MainWorldServer               ← explicit Main World bootstrap allowlist
├── StarterPlayer
│   └── StarterPlayerScripts
│       └── MainWorldClient           ← explicit Main World presentation/input allowlist
└── Workspace
    └── LivingKingdomsMainWorld
        ├── HubCore
        ├── Routes
        │   └── Primary
        ├── Resources
        ├── Structures
        └── Atmosphere
```

The project must not map held configs directly into Workspace. A deterministic reconstruction tool may convert validated configs into reviewable model assets, but generated output must be compared against evidence and committed only in the coherent model-asset form selected above.

## Placement invariants

The accepted [`RecoveredWorldPlacementConfig.luau`](../../games/living-kingdoms/src/shared/Config/RecoveredWorldPlacementConfig.luau) remains controlling:

- `CoordinateSpaceId = authored-overworld`;
- uniform scale `1.0`;
- translation `(0, 0, 0)`;
- rotation `(0, 0, 0)`;
- no recovered root may descend from `LivingKingdomsWorld`;
- the operation forest remains a separate runtime space.

Per-group pivots may be authored for model editing and streaming only if every child retains its recovered world-space transform after reconstruction. Pivot metadata cannot become a hidden global offset.

## Streaming groups

Streaming policy is organized around semantic/spatial ownership, not the recovered top-level hierarchy alone.

| Group | Source | Target | Candidate policy | Boundary rule |
|---|---|---|---|---|
| `main_world.hub_core` | `HubTown` + recovered spawn | `HubCore` | Persistent core candidate | Compact arrival/preparation core; persistence must be measured before adoption. |
| `main_world.primary_route` | `WorldPath` | `Routes/Primary` | Spatial chunks | Chunk by contiguous route segments and navigation continuity; never one 189-part atomic model. |
| `main_world.resources` | `Resources` | `Resources` | Spatial clusters | Group by authored cluster/region, not resource type across the entire map. |
| `main_world.structures` | `WorldStructures` | `Structures` | Per authored structure | No whole-root atomic model; hero structures may use bounded atomic submodels after cost measurement. |
| `main_world.atmosphere` | fireflies/clouds | `Atmosphere` | Local volumes + profile data | No giant global particle Adornee; streamable local emitters cannot own semantic world state. |

Exact `ModelStreamingMode`, target radii and budgets are BA-013/BA-014 decisions backed by Studio measurements. BA-011 deliberately records candidates, not unmeasured production settings.

All gameplay and presentation state must survive a locally absent Instance by stable semantic ID. Stream-out suspends local rendering; it never completes a quest, discovery, interaction, route or operation.

## Arrival and return anchors

Two semantic anchors are required even if they eventually share a nearby composition:

| ID | Current evidence/status | Rule |
|---|---|---|
| `spawn.main_world.arrival` | Recovered `Workspace/SpawnLocation` at `(0, 7, 30)` | Evidence-backed held arrival anchor; disabled until the Main World lifecycle is accepted. |
| `spawn.main_world.return` | Stable ID reserved; position unassigned | Must be placed through return/debrief composition so an expedition return is not indistinguishable from a cold join. |

The old `SpawnLocation` alias now resolves to the Main World arrival ID. `BootstrapSafetySpawn` remains the alias for the active operation insertion. No runtime behavior changes because both Main World descriptors remain inactive and the representation contract remains held.

Before activation, BA-012/BA-014 or a dedicated lifecycle ticket must define and verify:

- cold join, respawn, success return, failure return and replay-decline behavior;
- server-owned destination and eligibility decisions;
- four-player spawn safety, facing and camera clearance;
- a return/debrief surface near `spawn.main_world.return`;
- fallback behavior when teleport/session handoff fails;
- streaming availability for the destination before character placement.

## Reconstruction workflow

Each coherent group advances through the same reviewable sequence:

1. Select a group from current re-extracted identity/property evidence.
2. Record source paths, instance IDs, supported properties and known omissions.
3. Generate or author one bounded model/data unit without changing world transforms.
4. Validate identity/property parity and stable-ID references in CI.
5. Review the model diff independently of runtime wiring.
6. Keep the asset unmapped and held until its place/bootstrap/streaming gate opens.
7. Capture Studio views, collision, streaming, memory and performance evidence before promotion.

Unknown properties remain explicit omissions. They are not guessed from names or historical screenshots.

## Activation gates

The Main World project/runtime cannot activate until all of the following are true:

- v2.7 runtime dependencies required by the promoted integration are accepted;
- the dedicated project and bootstrap allowlists exist and build reproducibly;
- arrival and return anchors have accepted placement/lifecycle behavior;
- every mapped group has property/identity validation and disposition approval;
- streaming policy passes continuity, semantic rebind and no-completion-on-stream-out tests;
- Terrain has a manifest and visual/performance evidence if Terrain is included;
- legacy-service resurrection audit remains green;
- canonical expedition launch/return and party/session authority are explicitly designed;
- a rollback build/place checkpoint is recorded.

## BA-011 completion and next dependency

BA-011 closes the source/place/placement ambiguity at E1. It changes no active world, bootstrap, streaming setting, Terrain, presentation or gameplay behavior.

The next sequencing-safe Main World task is **BA-012 — Canonical Hub interaction registry**, using the root/group and anchor IDs defined here. BA-013 may then set measured production budgets and profile ownership without binding to an accidental hierarchy.
