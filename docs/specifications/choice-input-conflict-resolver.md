# Numbered choice input conflict resolver

**Roadmap ticket:** BA-062 C4 foundation  
**Evidence level:** E1 source/static only

## Decision

Numbered choice input must be **fail closed** when more than one choice surface is active.

`ChoiceInputConflictResolver` is a pure shared contract that receives the IDs of currently active presentation owners and returns one of four outcomes:

- `NoneActive` — no dispatch;
- `SingleActive` — dispatch is allowed to the one returned owner;
- `Conflict` — two or more owners are active, so no numbered choice may dispatch;
- `InvalidInput` — malformed or duplicate owner IDs, so no dispatch.

The active owner list is normalized into deterministic sorted order. No priority is invented between progression upgrades and Run Relic choices.

## C4 boundary

The current live HUD controllers still own their existing `1`/`2`/`3` listeners. This increment therefore **does not claim C4 is runtime-remediated yet**.

The later integration slice must:

1. establish one numbered-choice input listener;
2. gather active choice owners at the moment of input;
3. call this resolver;
4. dispatch only when `DispatchAllowed == true` and `OwnerId` is present;
5. submit nothing when the result is `Conflict` or `InvalidInput`.

This preserves current single-surface behavior while defining a deterministic safe result for an overlap that current pacing normally avoids.

## Authority boundary

This module does not bind input, create GUI, fire remotes, mutate progression or relic state, choose rewards, persist data, or become a presentation owner. Server-side choice validation remains unchanged.

## Validation

`ChoiceInputConflictResolver.test.luau` covers zero-owner, single-owner, overlap, deterministic order, duplicate IDs, malformed IDs, immutability intent, and source guardrails against runtime/network/persistence APIs.

Real keyboard/gamepad/touch behavior remains for the consolidated Studio/device pass after runtime integration.
