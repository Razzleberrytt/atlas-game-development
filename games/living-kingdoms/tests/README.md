# Living Kingdoms test layout

The test tree is organized by semantic ownership rather than by fixture type.

- `architecture/` — bootstrap, dependency-boundary, and structural contract audits.
- `classes/` — class selection, class presentation, silhouettes, and class-specific behavior.
- `crafting/` — crafting contracts and crafting presentation registries/models.
- `equipment/` — equipment affixes, comparisons, rewards, and stat integration.
- `input/` — device-family resolution, action maps, bindings, hints, and mobile controls.
- `presentation/` — cross-cutting UI, accessibility, responsive layout, and menu presentation.

Fixtures should move into a domain folder when ownership is clear. Keep a fixture at the test root only when it is intentionally cross-domain, temporarily awaiting classification, or consumed by tooling that currently requires an exact root-relative filename.

In particular, the focused `persistence-hardening` validation profile currently resolves its fixture allowlist directly from `games/living-kingdoms/tests/<name>.test.luau`; those fixtures remain at the root until that runner is migrated to semantic discovery.

The canonical full/fast validators already discover `*.test.luau` recursively, so nested domain suites participate in normal validation without special registration.
