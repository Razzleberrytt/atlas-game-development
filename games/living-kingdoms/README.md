# Living Kingdoms

Living Kingdoms is the working game/runtime inside Atlas. Atlas is currently a **cooperative action RPG on Roblox**; historical Living Kingdoms documents may describe earlier RTS, isometric-survival, or narrower prototype directions and are provenance unless current authority explicitly preserves them.

This README is a **navigation map**, not a roadmap, changelog, implementation diary, or duplicate status dashboard.

## Start here

Read these in order for ordinary work:

1. [`AGENTS.md`](AGENTS.md) — local operating rules, authority boundaries, layout, risk tiers, and completion discipline.
2. [`../../docs/roadmap/EXECUTION-DASHBOARD.md`](../../docs/roadmap/EXECUTION-DASHBOARD.md) — current daily execution/status authority.
3. [`../../docs/bible/00-current-product-authority.md`](../../docs/bible/00-current-product-authority.md) — current product direction and conflict resolution.

Load deeper roadmap, specification, migration, production, or historical documents only when the task needs them. `AGENTS.md` contains the routing guide.

## Runtime authority

`games/living-kingdoms/src/` is the only gameplay-authoritative source tree.

- **Client** owns input and non-authoritative presentation.
- **Server** owns consequential gameplay truth: combat, enemies, life state, rewards, inventory/progression, operation lifecycle, validation, and persistence/economy boundaries.
- **Shared** owns stable contracts, configuration, deterministic reusable logic, and intentionally disclosed presentation-safe data.

`default.project.json` is the canonical Rojo/DataModel mapping.

Content under `imports/` is preservation/reference material. Never boot imported legacy gameplay services beside the canonical runtime and never overwrite `src/` from an extracted Studio place without explicit reconciliation.

## Project layout

```text
games/living-kingdoms/
├── AGENTS.md
├── README.md
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

Rojo maps:

| Source | Roblox destination |
| --- | --- |
| `src/client` | `StarterPlayer/StarterPlayerScripts/Client` |
| `src/server` | `ServerScriptService/Server` |
| `src/shared` | `ReplicatedStorage/Shared` |

Do not infer architectural ownership from a filename alone. Follow current contracts, tests, source, and the authority documents above.

## Product/runtime relationship

The current runtime is a valuable implementation asset inside the broader Atlas direction. Existing camera, combat, survival pressure, classes, objectives, run-build systems, persistence boundaries, and authored-operation work remain in force until an explicit accepted decision replaces them.

The accepted world direction is:

```text
authored overworld / Main World
→ canonical expedition launch
→ modern operation / expedition runtime
→ return
```

The recovered authored overworld and modern operation space are separate lifecycle/coordinate spaces. Do not squeeze one into the other or reactivate legacy authority to obtain presentation content.

## Where current truth lives

Use one owner for each kind of truth:

| Question | Canonical source |
| --- | --- |
| What should I work on now? | `docs/roadmap/EXECUTION-DASHBOARD.md` |
| What is the current product? | `docs/bible/00-current-product-authority.md` |
| How should Living Kingdoms code be changed? | `games/living-kingdoms/AGENTS.md` |
| What is the long-range destination? | `docs/roadmap/MASTER-ROADMAP.md` |
| What is the current playable-patch intent? | `docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md` |
| What did the Studio import/recovery prove? | `docs/migration/` current evidence and `imports/` |
| How is local/tool/build validation run? | `docs/production/` and `scripts/validate.py` |

`MERGE-STATUS.md` and `CANONICAL-RUNTIME.md` are retained only as compatibility pointers for old links. They are not independent status or authority documents.

## Validation

From the repository root, choose the smallest appropriate risk profile described in `AGENTS.md`:

```bash
python scripts/validate.py docs
python scripts/validate.py fast
python scripts/validate.py full
```

CI is the canonical automated result. Engine/device/play facts that CI cannot prove remain unmeasured until actual evidence is recorded; they must not be silently promoted to verified.

## Historical material

Older milestone narratives, ticket-by-ticket implementation notes, superseded genre descriptions, first-archive recovery counts, and obsolete NEXT-task lists belong in Git history or explicitly historical documents—not in this README.

When historical and current documents conflict, follow the current authority chain above. Preserve useful implementation and evidence; do not preserve stale scheduling or duplicated truth merely because it was once accurate.
