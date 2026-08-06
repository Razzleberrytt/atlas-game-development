# VS-0110 Studio Validation and Integration Gate

**Status:** Required before claiming the expedition foundation is playable or production-ready.

## Automated repository checks

Run from the repository root and capture the exact command output in the PR:

- formatting check;
- Luau lint/type checks;
- all Lune fixtures, including expedition, room, secret, reward, result, and persistence tests;
- Rojo project build/sourcemap validation;
- repository layout and generated-file checks.

A missing CI result is not a passing result.

## Authority audit

Confirm in code review and Studio that:

- clients cannot advance expedition phases;
- clients cannot complete encounters, elites, bosses, or secrets;
- clients cannot generate, select, or insert reward instances directly;
- clients cannot finalize results or present the same reward twice;
- clients cannot write inventory records or equip unowned/mismatched items;
- all remote payloads are treated as untrusted requests and rate-bounded;
- reward instance IDs remain unique and idempotent across reconnects;
- stale encounter tokens and stale phase IDs are rejected.

## DataStore validation

Use a separate Studio test DataStore namespace.

- New player creates schema version 1 record.
- Rejoin restores inventory and equipped slots.
- Applying the same reward twice grants only one item.
- Simulated transient failures exercise retry/backoff.
- Failed writes do not update authoritative cached state.
- Corrupt/future-schema records fail closed and do not overwrite the source record.
- Server shutdown does not lose an accepted mutation.
- Two-server concurrency is tested before production; session locking is still required for the live release gate.

## Encounter adapter validation

Concrete adapters must be added for the existing enemy director, elite owner, and boss owner.

- Each adapter accepts only a server-created encounter context/token.
- Exactly one completion callback fires.
- Cancellation removes spawned enemies and listeners.
- Traversal rooms do not accidentally start combat owners.
- Dungeon room completion advances the room cursor, not the whole dungeon phase.
- Elite completion grants the elite source once.
- Boss completion grants the boss source once and permits final completion.

## Room placement validation

The current assembler produces abstract plans. Before playability is claimed:

- map every room definition ID/version to a Roblox model;
- validate entry/exit socket compatibility;
- reject overlaps and impossible alignments;
- prove entry-to-boss navigation for every supported seed sample;
- place the secret branch without breaking the main route;
- log the seed and chosen room IDs for reproduction.

## Multiplayer matrix

Test fresh servers with **1, 2, and 4 players**.

For each party size capture:

- run start and phase progression;
- join/leave behavior;
- wipe/failure behavior;
- elite and boss completion;
- secret discovery and reward ownership;
- reward distribution policy;
- replay/return decision behavior;
- inventory save and rejoin restoration;
- server and client errors;
- average and worst frame time, memory, network receive/send, and instance count.

## Disconnect/rejoin cases

- Disconnect before an encounter finishes.
- Disconnect after reward generation but before presentation.
- Disconnect after persistence succeeds.
- Rejoin during an active run.
- Party leader disconnects.
- Entire party disconnects.

The expected policy for each case must be explicit before shipping.

## User-facing validation

Do not count the slice complete until outside testers can:

- identify the immediate objective without coaching;
- explain why they took damage or failed;
- notice a meaningful difference between two seeded runs;
- understand the secret as optional;
- compare at least one reward decision;
- complete the result/replay flow;
- voluntarily begin another run.

## Current known exclusions

- Abstract room plans are not yet instantiated.
- Existing live combat systems do not yet have concrete expedition adapters.
- No expedition UI or network presentation has been added.
- Production session locking is not implemented.
- No observed 1/2/4-player results are claimed.
