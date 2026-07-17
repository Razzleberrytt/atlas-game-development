# Ammunition Scarcity and Supply

**Status:** P6 implementation and balance validation in progress  
**Current task:** P6-0107 — sampled scarcity telemetry and one/two/four-operative validation

## Goal

Turn the P2 prototype ammunition values into a finite, server-owned operation resource that creates meaningful relocation and resupply decisions without making failure unavoidable.

## Authority

The server owns loaded rounds, reserve rounds, magazine and carry limits, supply identity, source, available quantity, collection eligibility, granted quantity, processed supply identities, and every committed ammunition transition.

Clients may present server-disclosed ammunition and locally mark a consumed cache for the collecting operative. They may never submit ammunition totals, capacity, granted quantity, supply source, processed identity, successful collection, or depletion truth.

## Implemented P6 slices

- finite scarcity state, source IDs, rejection reasons, and pure supply collection
- production starting ammunition and carry limits routed through P6 configuration
- three authored cache locations at risky operation landmarks
- server-owned proximity collection with life, distance, capacity, duplicate, and generation checks
- authoritative loaded, magazine, reserve, and exact grant presentation
- per-operative cache depletion presentation without globally consuming a squadmate's cache
- sampled read-only scarcity telemetry and a Studio-only validation probe

## Initial prototype values

- Basic firearm loaded rounds: 12
- Initial reserve rounds: 24
- Maximum carried reserve rounds: 48
- Authored cache grant: 12

These values remain testable starting points, not final tuning.

## Deterministic collection order

1. Validate the current ammunition state.
2. Validate supply identity, source, weapon, and positive whole-round quantity.
3. Reject an already processed supply identity.
4. Reject when reserve capacity is full.
5. Grant the lesser of available supply and remaining reserve capacity.
6. Commit the generation-checked combat state.
7. Record the server-owned collection identity and exact granted amount.
8. Disclose ammunition and per-operative cache depletion only after commit succeeds.

## P6-0107 telemetry

Telemetry is sampled only when an authorized Studio tester invokes the validation probe. It adds no heartbeat, timer, task loop, production remote, client authority, or gameplay mutation.

Accepted shots are derived from conserved server truth:

`initial loaded + initial reserve + committed cache grants - current loaded - current reserve`

Each snapshot reports:

- observed and currently active operative counts
- accepted shots
- cache collections and exact rounds granted
- current loaded and reserve totals
- minimum total ammunition observed
- currently dry operatives
- observed transitions into true ammunition starvation, where loaded plus reserve equals zero
- total, consumed, and remaining per-operative cache opportunities
- the same measurements for each operative, with consumed cache identities

## Studio validation surface

The server creates `ServerStorage.LivingKingdomsAmmunitionValidation` only in Studio.

- `ResetSampling:Invoke()` clears telemetry history before a new run.
- `ReadSnapshot:Invoke()` takes one explicit sample and returns the frozen snapshot.

Capture snapshots at minimum:

1. operation start
2. first objective completion
3. escalation or mid-operation relocation
4. holdout start
5. operation success or failure

Run the protocol with one, two, and four operatives. Do not compare runs that used different enemy tuning or operation paths without recording that difference.

## Balance interpretation

Healthy tension is indicated when ammunition minima fall meaningfully, cache use varies by operative or route, and most runs avoid true dry transitions through good movement and collection decisions.

Likely oversupply is indicated when operatives finish with high totals, consume few cache opportunities, and never approach low ammunition across repeated successful runs.

Likely unavoidable starvation is indicated when dry transitions occur repeatedly despite collecting most available opportunities and otherwise competent play. A dry transition while many opportunities remain is not automatically a tuning defect; it may indicate route choice, missed relocation, or poor distribution.

No ammunition value should change from a single run. Tune only after comparable one/two/four-operative evidence shows a repeated pattern.

## Remaining P6 work

1. Complete and record comparable one-, two-, and four-operative Studio runs.
2. Repair only telemetry or collection defects exposed by those runs.
3. Adjust prototype values only when repeated evidence distinguishes oversupply from unavoidable starvation.
4. Close P6 with multiplayer security, regression, and documented balance findings.
