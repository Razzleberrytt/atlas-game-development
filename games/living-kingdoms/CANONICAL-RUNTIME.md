# Living Kingdoms — Canonical Runtime

**Compatibility pointer — not an independent status authority document.**

This path is retained for old links. Current runtime rules and changing status are intentionally owned elsewhere so they cannot drift across multiple root documents.

Use:

- [`AGENTS.md`](AGENTS.md) for canonical source layout, client/server/shared authority boundaries, import rules, risk tiers, and completion discipline.
- [`../../docs/roadmap/EXECUTION-DASHBOARD.md`](../../docs/roadmap/EXECUTION-DASHBOARD.md) for current implementation/status truth.
- [`../../docs/bible/00-current-product-authority.md`](../../docs/bible/00-current-product-authority.md) for current Atlas product identity and conflict resolution.
- [`../../docs/README.md`](../../docs/README.md) when documentation authority itself is unclear.
- [`../../docs/migration/`](../../docs/migration/) plus [`imports/`](imports/) for Studio preservation/reconstruction evidence.
- applicable [`../../docs/specifications/`](../../docs/specifications/) documents for focused Main World, expedition, runtime, or migration contracts.

## Durable runtime invariants

`games/living-kingdoms/src/` is the gameplay-authoritative Luau source tree.

Canonical Rojo mappings are place-specific:

- `default.project.json` — operation/expedition runtime mapping;
- `main-world.project.json` — dedicated Main World mapping.

Neither generated place output nor imported Studio content is a second source tree.

The recovered authored overworld and the modern operation/expedition runtime remain separate lifecycle/coordinate spaces. Imported legacy services must not be booted beside current owners.

The accepted macro direction remains:

```text
authored overworld / Main World
→ canonical expedition launch
→ modern operation / expedition runtime
→ return
```

When systems overlap, retain the canonical modern owner and reconcile missing content through it rather than creating or reviving a second authority.

Broad cross-system gaps may be classified through `LK-001`–`LK-300`, but the development taxonomy never establishes runtime ownership; source/registries/contracts do.

Detailed reconstruction counts, current world-content status, completed batches, open PR lists, and next-integration queues belong to their evidence/dashboard owners and are deliberately not copied into this file.
