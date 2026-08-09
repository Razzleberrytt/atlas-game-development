# Living Kingdoms Agent Guide

Applies to `games/living-kingdoms/**`.

Living Kingdoms is repository-first. Most gameplay work should be inspectable, modifiable, testable, and reviewable without Roblox Studio.

## Minimum startup context

Always read:

1. `../../docs/roadmap/EXECUTION-DASHBOARD.md`
2. this file

Load other authority **only when relevant**:

- product/design conflict → `../../docs/bible/00-current-product-authority.md`
- detailed current-patch acceptance → `../../docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md`
- long-range scope lookup → `../../docs/roadmap/MASTER-ROADMAP.md`
- runtime state/remotes/lifecycle/rollback → v2.7 Blueprint/Production Core/Active Place Rollout
- replicated or presentation ownership migration → Cross-System Traceability + cutover ledger
- Main World/environment → applicable `../../docs/specifications/main-world-*`
- Studio evidence intended to close a gate → evidence packet template
- newer `.rbxl/.rbxlx` reconciliation → `../../docs/production/RBXL-IMPORT-MIGRATION.md`

Do not preload every roadmap/specification for a routine isolated change.

## Execution cadence

Follow dashboard NOW/NEXT/LATER. Inspect open PRs before starting. Do not duplicate overlapping work.

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

## Canonical layout

```text
games/living-kingdoms/
├── default.project.json
├── src/
│   ├── client/
│   ├── server/
│   └── shared/
├── tests/
├── tools/
├── assets/
└── imports/
```

Rojo maps client → `StarterPlayerScripts/Client`, server → `ServerScriptService/Server`, shared → `ReplicatedStorage/Shared`. Mapping changes require migration notes, build validation, and Studio smoke evidence.

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
- `default.project.json` is canonical DataModel mapping.
- `tests` is regression coverage.
- `imports` is preservation/reference, never an automatic replacement source tree.
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

- [ ] current dashboard and open PR overlap checked
- [ ] smallest coherent high-ROI increment selected
- [ ] authority boundaries preserved
- [ ] focused regression coverage added/updated
- [ ] correct validation profile passed
- [ ] Studio-only claims reported truthfully
- [ ] roadmap updated only if meaningful status/next-task truth changed
- [ ] no generated artifacts or secrets committed
- [ ] completion report names status, pending evidence, blocker if any, and next task