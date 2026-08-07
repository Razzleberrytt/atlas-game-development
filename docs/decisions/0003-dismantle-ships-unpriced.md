# 0003 — Dismantle ships unpriced; salvage is a capacity action, not an economy

**Status:** Accepted — 2026-08-07
**Context:** Blueprint v2.0 queue item 3 (v1.9 Ticket 143)

## Decision

Dismantle destroys an owned item and yields **no currency, material, or credit**. Its purpose in
the vertical slice is to make room in a bounded inventory. The dismantle boundary records the
*facts* of what was destroyed — `SalvagedDefinitionId`, `SalvagedRarity`, `SalvagedPower` — so an
economy can price them later without this boundary being rewritten.

## Why not add a salvage currency now

1. **The blueprint forbids it in this order.** Engineering law 10 is "do not expand content
   categories until ownership, retry, migration, and recovery are proven." A currency is a content
   category. Overflow recovery is queue item 4 and persistence hardening is item 6 — both still
   ahead of this work.
2. **It would require inventing balance values.** A price per rarity and power band is a tuning
   decision, and the blueprint's evidence rule forbids unmeasured tuning. There is no playtest
   evidence to set it from.
3. **Dismantle is already useful without it.** In a bounded inventory the reason to destroy an item
   is to make room, which is exactly the mechanism queue item 4 (capacity retry and durable
   overflow recovery) needs. Pairing dismantle with capacity is coherent; pairing it with a
   currency is a separate feature.

## What was built instead

The transaction boundary, in full. `InventoryDismantleResolver` is the pure decision and
`PlayerInventoryPersistenceService:dismantle` owns the durable parts.

The one schema change made here is **not** an economy: the dismantle idempotency ledger
(`AppliedDismantleTransactions`) is persisted, taking the record schema from 2 to 3. This is
required by engineering law 4 — "valuable mutations require idempotent transaction IDs." A ledger
held only in memory loses replay protection across a rejoin, which would let a retried dismantle
be answered as though it had never happened.

Schema support is now an explicit list (`SupportedSchemaVersions = {1, 2, 3}`) rather than a
hardcoded pair. The previous check accepted only version 1 or the current version, so bumping the
current version would have made every existing version 2 record fail to load — stranding live
inventories. That list only grows until a migration is proven to have retired a version.

## Revisit when

Queue item 6 (persistence adapter hardening, sequential migrations, quarantine, unknown-write
reconciliation) lands, and there is playtest evidence about inventory pressure. At that point
pricing salvage is an additive change: the destroyed-item facts are already recorded, and the
migration infrastructure needed to add a balance field will exist.

## Consequences

- Players can free inventory space but receive nothing for it until an economy exists.
- The audit fixture asserts no currency appears at the inventory boundary, so this decision cannot
  be reversed silently.
- Any future economy must price from the recorded facts rather than re-deriving them from an item
  that no longer exists.
