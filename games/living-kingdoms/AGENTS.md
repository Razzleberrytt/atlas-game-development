# Living Kingdoms Agent Guide

Applies to `games/living-kingdoms/**`.

Living Kingdoms is repository-first. Most gameplay work should be inspectable, modifiable, testable, and reviewable without Roblox Studio.

## Minimum startup context

Always read:

1. `../../docs/roadmap/EXECUTION-DASHBOARD.md`
2. this file

Load other authority **only when relevant**:

- documentation/coherence work → `../../docs/README.md`
- product/design conflict → `../../docs/bible/00-current-product-authority.md`
- detailed current-patch acceptance → `../../docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md`
- long-range scope lookup → `../../docs/roadmap/MASTER-ROADMAP.md`
- broad development coverage / gap classification → `../../docs/architecture/DEVELOPMENT_TAXONOMY.md`, `../../docs/architecture/DEVELOPMENT-ATLAS.md`, `../../config/coverage/living-kingdoms-development.json`
- repeated feature/content extension or implementation friction → `../../docs/production/EXTENSION-COST-MODEL.md`
- gameplay modifier/effect ownership → `../../docs/production/EFFECT-OWNER-ROUTING.md`
- broader leverage decision → `../../docs/roadmap/DEVELOPMENT-FLYWHEEL.md` and `../../docs/production/ENGINEERING-EFFICIENCY-OPS.md`
- runtime state/remotes/lifecycle/rollback → v2.7 Blueprint/Production Core/Active Place Rollout
- replicated or presentation ownership migration → Cross-System Traceability + cutover ledger
- Main World/environment → applicable `../../docs/specifications/main-world-*`
- Studio evidence intended to close a gate → evidence packet template
- newer `.rbxl/.rbxlx` reconciliation → `../../docs/production/RBXL-IMPORT-MIGRATION.md`

Do not preload every roadmap/specification for a routine isolated change.

## Execution cadence

Follow dashboard NOW/NEXT/LATER. Inspect open PRs before starting. Do not duplicate overlapping work, and do not assume an old open PR is current merely because it remains open; re-check its base, overlap, contracts, and validation first.

Implementation may continue through dependency-safe increments after automated validation. Do not require a Studio handoff after every small merge. At coherent player-facing milestones, run the integrated Studio/playtest/debug/replay pass and mark VERIFIED only after evidence passes.

A known runtime failure, unsafe authority assumption, persistence risk, or concrete safety blocker preempts later expansion.

## Status meanings

- **NOT STARTED** — no meaningful implementation.
- **BUILDING** — incomplete active work.
- **BUILT — VERIFICATION PENDING** — intended source behavior exists and applicable source checks pass; required engine/device/human evidence remains.
- **VERIFIED** — required evidence passed.
- **DEFERRED** — lower priority, not prohibited by phase order.
- **BLOCKED — <reason>** — a concrete dependency/safety/runtime boundary prevents safe progress.
- **HISTORICAL** — provenance only.

Coverage ontology state is separate from patch status. A concern may be `substantial` in the development registry while player-facing Studio verification remains pending.

## Canonical layout

```text
games/living-kingdoms/
├── default.project.json
├── main-world.project.json
├── src/
│   ├── client/
│   ├── server/
│   └── shared/
├── tests/
├── tools/
├── assets/
└── imports/
```

Rojo maps client → `StarterPlayerScripts/Client`, server → `ServerScriptService/Server`, shared → `ReplicatedStorage/Shared` in the canonical operation project. `main-world.project.json` owns the dedicated Main World mapping. Mapping changes require migration notes, build validation, and Studio smoke evidence appropriate to the affected place.

## Authority boundaries

### Client may own

- input collection;
- camera/HUD/menu/audio/visual presentation;
- non-authoritative prediction/interpolation;
- narrowly scoped intent messages.

Client code must not establish consequential game truth.

### Server owns

- combat legality/damage;
- enemy state/spawning;
- health/down/revive/death;
- loot/rewards/inventory/progression/run builds;
- mission/operation lifecycle;
- validation of client intent;
- persistence/economy/monetization when present.

Remote handlers validate identity, state, range, cadence, permission, and payload shape as applicable. Repeatable intents must be bounded.

### Shared should own

- stable contracts/types;
- configuration;
- deterministic testable resolvers;
- intentionally presentation-safe disclosed data.

Avoid live-service coupling in pure shared modules.

## Coding rules

- Use strict Luau for new source.
- Reuse established lifecycle patterns (`init/start/stop/destroy`) and make repeated calls safe when expected.
- Prefer deterministic pure functions where possible.
- Return copied state rather than mutating caller-owned inputs in resolvers.
- Prefer explicit reason IDs/contracts over hidden coupling.
- Reuse existing network folders/contracts; do not create duplicate remotes for the same authority boundary.
- Keep balance/configuration centralized under `src/shared/Config` when appropriate.
- Preserve mobile/controller/accessibility behavior when changing controls or presentation.
- Never invent asset, animation, product, place, universe IDs, or secrets.

## Development coverage routing

The 300-area taxonomy is a **coverage ontology, not a runtime decomposition**. Before a broad cross-system implementation or audit:

```bash
python scripts/development_coverage.py report
```

Then:

1. identify the relevant `LK-###` concern(s);
2. use the Development Atlas to identify the conceptual engine(s);
3. search current source/capability/extension/effect registries for the real owner;
4. extend that owner or stable data seam first;
5. create a new owner only when a genuinely missing responsibility boundary exists;
6. update the coverage registry only when the coherent change materially changes coverage/evidence;
7. run `python scripts/development_coverage.py sync` after registry changes.

Never create one service, module, metric, or registry per LK row merely to make the taxonomy look complete.

## Scaling / compounding rule

The marginal cost of repeated features must trend **down**, not up.

Before adding another member of a repeated family (affix, enemy variant, presentation profile, class/archetype, hub interaction, and future registered families):

```bash
python scripts/extension_cost.py list
python scripts/extension_cost.py show <contract-id>
```

Implement through the registered canonical extension path first. Before completion, check the branch surface:

```bash
python scripts/extension_cost.py check <contract-id> --base main
```

Interpretation:

- **WITHIN BUDGET** — normal extension path stayed narrow.
- **REVIEW REQUIRED** — do not merely shrink the diff; decide whether this is a genuinely new semantic or whether the reusable seam has become too expensive.
- A data-first variant should normally touch **zero server-authority files**.
- Repeated budget overruns are a leverage trigger: improve the owner/schema/validator before scaling that family further.
- Never force a necessary new semantic through an inadequate abstraction just to satisfy a number.

Extension contracts live at `../../config/efficiency/extension-contracts.json`. Update a contract only when the real reusable path materially changes.

### Gameplay effect routing

Before wiring a reusable affix/progression/relic effect into live gameplay, inspect its registered authority route:

```bash
python scripts/effect_routes.py show <EffectId>
python scripts/effect_routes.py next
```

Routing statuses mean:

- **live** — reuse the named owner/seam/adapter; ordinary variants should not need new runtime wiring;
- **owner-confirmed** — the owner is known; add one bounded adapter and wire through that owner rather than creating another service;
- **unresolved** — owner discovery is the task. Do not guess or implement the consequence until the canonical server owner is confirmed.

The registry lives at `../../config/efficiency/effect-owner-routes.json`. Every `EquipmentAffixEffectId` must have exactly one route, and validation fails if that coverage drifts.

The desired maturity curve is:

```text
bespoke → shared owner → stable registry/seam → data-first → generated only when still repetitive
```

Do not build generators before the repeated shape is proven.

## Risk and validation

Use the repository risk tiers from root `AGENTS.md`:

- **R0 docs/metadata:** `python scripts/validate.py docs`
- **R1 presentation/pure/config/tooling:** `python scripts/validate.py fast`
- **R2 gameplay authority/remotes/lifecycle/inventory/progression:** `python scripts/validate.py full`
- **R3 persistence/security/migrations/rollback-critical cutovers:** `python scripts/validate.py full` plus focused targeted checks and early runtime evidence where downstream safety depends on it

Gameplay-rule changes normally add a focused `*.test.luau`. Integration changes should add a fixture or source audit proving intended wiring and trust boundaries.

Do not delete or loosen an existing test merely because new code fails it unless the documented requirement intentionally changed.

## Source/import rules

- `src` is canonical runtime source.
- `default.project.json` and `main-world.project.json` are canonical DataModel mappings for their places.
- `tests` is regression coverage.
- `imports` is preservation/reference, never an automatic replacement source tree.
- development coverage metadata lives outside runtime source and never establishes gameplay truth.
- Do not commit generated place/build artifacts.
- Never overwrite `src` from an extracted Studio place without review and reconciliation.

## Studio-only checks

CI cannot prove:

- actual multiplayer/physics behavior;
- terrain/world appearance and readability;
- animation or asset permissions;
- device safe areas and real input feel;
- streaming/network timing;
- DataStore behavior in an appropriate environment;
- performance/memory;
- lighting/audio feel;
- publishing configuration.

Record source-complete work as **BUILT — VERIFICATION PENDING** until applicable evidence exists. Group ordinary engine checks into coherent milestone passes; run them earlier only when the risk tier or a concrete blocker requires it.

## Completion checklist

- [ ] current dashboard and open PR overlap/base freshness checked
- [ ] smallest coherent high-ROI increment selected
- [ ] relevant LK coverage concerns classified for broad cross-system work
- [ ] registered extension contract used when adding a repeated family variant
- [ ] effect owner route checked when wiring a reusable gameplay modifier
- [ ] extension-cost budget checked or deliberate semantic escalation explained
- [ ] authority boundaries preserved
- [ ] focused regression coverage added/updated
- [ ] development coverage registry updated only if material coverage/evidence changed
- [ ] correct validation profile passed
- [ ] Studio-only claims reported truthfully
- [ ] roadmap/dashboard updated only if meaningful status/next-task truth changed
- [ ] no generated artifacts or secrets committed
- [ ] completion report names status, pending evidence, blocker if any, and next task
