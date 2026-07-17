# Ammunition Scarcity and Supply

**Status:** P6 foundation in progress  
**First task:** P6-0101 — finite ammunition and pure supply collection contracts

## Goal

Turn the P2 prototype ammunition values into a finite, server-owned operation resource that creates meaningful relocation and resupply decisions without making failure unavoidable.

## Authority

The server owns loaded rounds, reserve rounds, magazine and carry limits, supply identity, source, available quantity, collection eligibility, granted quantity, processed supply identities, and every committed ammunition transition.

Clients may request a later narrow interaction with a disclosed cache. They may never submit ammunition totals, capacity, granted quantity, supply source, processed identity, or a successful result.

## P6-0101 boundary

This first slice is pure and unintegrated:

- defines finite scarcity state and supply records
- defines stable authored-cache and future engineer-resupply source IDs
- defines deterministic rejection reasons
- centralizes prototype initial reserve, maximum reserve, and cache grant values
- resolves collection without overflow or input mutation
- records each accepted supply identity exactly once

It does not alter the current production combat runtime, place caches, add prompts/remotes, change reload behavior, add inventory UI, grant engineer abilities, or claim final balance.

## Initial prototype values

- Basic firearm loaded rounds: 12
- Initial reserve rounds: 24
- Maximum carried reserve rounds: 48
- Authored cache grant: 12

These values are testable starting points, not final tuning.

## Deterministic collection order

1. Validate the current ammunition state.
2. Validate supply identity, source, weapon, and positive whole-round quantity.
3. Reject an already processed supply identity.
4. Reject when reserve capacity is full.
5. Grant the lesser of available supply and remaining reserve capacity.
6. Record the supply identity and return a copied frozen state.

## Next passes

1. Integrate scarcity state into the production combat owner while preserving P2 fire/reload semantics.
2. Add server-owned authored cache records at risky operation landmarks.
3. Add narrow server-validated collection intent and safe presentation.
4. Add scarcity telemetry and one/two/four-operative balance validation.
