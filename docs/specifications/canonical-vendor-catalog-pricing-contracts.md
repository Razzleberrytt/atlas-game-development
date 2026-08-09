# Canonical Vendor / Catalog / Pricing Contracts

**Roadmap ticket:** BA-024  
**Lane:** controlled build-ahead  
**Status:** contract and quote resolver complete; runtime dormant  
**Evidence level:** E1 source/static only

## Decision

BA-024 defines one canonical, source-managed shape for vendors, catalogs, catalog entries and prices, plus a deterministic quote/eligibility resolver. It does not create a live transaction authority.

The machine-readable contract is [`VendorContracts.luau`](../../games/living-kingdoms/src/shared/Vendor/VendorContracts.luau).

## Stable reference model

A vendor definition contains:

- `VendorId`
- `Version`
- one or more opaque `CatalogRefIds`
- `RuntimeEnabled`

A catalog definition contains:

- `CatalogId`
- `Version`
- one or more catalog entries
- `RuntimeEnabled`

Each catalog entry contains:

- stable `EntryId`
- opaque `ItemRefId`
- price `{ CurrencyRefId, UnitAmount }`
- optional positive `MaxQuantityPerRequest`
- `Available`

Item and currency references intentionally remain opaque in BA-024. BA-025 owns cross-domain existence/orphan validation. BA-026 owns the economy model, including approved currencies, sources/sinks, value bands and economic balance.

## Pricing representation

`UnitAmount` is a non-negative integer. This is a **representation contract**, not an authored economy decision. BA-024 publishes no live prices and does not choose a canonical currency.

Test-only fixture IDs and values under `vendor.fixture.*`, `catalog.fixture.*`, `entry.fixture.*`, `item.fixture.*`, and `currency.fixture.*` are not game content.

## Deterministic quote resolver

`evaluateQuote(vendor, catalog, entryId, quantity, context)` is pure and returns either an eligible quote or one explicit denial reason.

Resolution order is:

1. `VendorDisabled`
2. `CatalogUnavailable` when the vendor does not reference the supplied catalog
3. `CatalogDisabled`
4. `EntryUnavailable` when the entry is missing or disabled
5. `QuantityInvalid`
6. `QuantityLimitExceeded`
7. `InsufficientCurrency`
8. eligible quote

An eligible or insufficient-funds result may expose the selected item/currency refs, quantity, unit amount, total amount and available balance. That output is descriptive only; it does not reserve stock, debit currency or grant an item.

Malformed or negative balances are normalized to zero for deterministic source-level evaluation. The future authoritative transaction owner must validate fresh server-owned state again at commit time.

## Authority boundary

BA-024 adds no:

- currency debit or refund path;
- item grant, inventory mutation or stock mutation;
- purchase idempotency or receipt ledger;
- persistence writes;
- remote or client purchase authority;
- prompt, vendor UI or NPC binding;
- live vendor bootstrap/runtime owner;
- dynamic pricing, discounts, reputation pricing or market simulation;
- canonical currency definition or economy value bands;
- cross-domain ID validation;
- authored vendor catalogs or live prices.

The recovered Main World vendor groups remain presentation/placement evidence only. `hub.anchor.vendor.apothecary`, `hub.anchor.vendor.armor_smith`, `hub.anchor.vendor.weapon_smith`, and `hub.anchor.vendor.merchant` remain held by the BA-012 registry and are not activated here.

## Validation guarantees

The source validator rejects:

- empty or malformed stable IDs;
- duplicate vendor IDs;
- duplicate catalog IDs;
- duplicate catalog refs within one vendor;
- empty catalog-ref or catalog-entry lists;
- duplicate entry IDs within one catalog;
- malformed/negative prices;
- zero/negative/non-integral quantity limits;
- unknown fields.

The focused Lune fixture also source-guards against Roblox instance creation, service lookup, remotes and persistence APIs so the BA-024 module cannot silently become a transaction owner.

## Activation gates

A live vendor flow remains blocked until at least:

- BA-025 cross-domain dependency validation is accepted;
- BA-026 economy model/audit defines approved currencies, sources/sinks and value bands;
- the canonical server transaction owner and persistence/idempotency policy are explicit;
- inventory/currency mutation ownership is accepted without duplication;
- NPC/vendor presentation ownership and device-neutral interaction behavior are accepted;
- Main World placement/lifecycle/runtime gates permit activation;
- Studio evidence covers denial feedback, repeated requests, reconnect/retry behavior and lifecycle cleanup.

## Completion boundary

BA-024 is complete at E1 when the contract, quote resolver, focused fixture and normal repository validation are green. It does not advance runtime evidence and does not authorize any purchase transaction.
