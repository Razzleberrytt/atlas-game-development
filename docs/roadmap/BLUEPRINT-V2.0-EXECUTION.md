# Blueprint v2.0 Execution Authority

Blueprint v2.0 is the active production authority for Atlas.

## Release intent

Version 2.0 is a consolidation and quality release. It does not claim new runtime functionality. It clarifies authority, evidence, traceability, static quality ratchets, persistence gates, and the critical path toward a proven vertical slice.

## Product promise

Build one polished, replayable five-to-ten-minute cooperative FPS RPG expedition before expanding the world:

`prepare → choose weapon → outdoor route → role-based combat → Pulse Mark clue → short procedural dungeon → elite → randomized item → Gatekeeper → return → replay decision`

## Authority order

When project materials conflict, use this order:

1. Current source and captured evidence.
2. Blueprint v2.0 Production Core and current quality chapters.
3. Blueprint v2.0 canonical specifications and schemas.
4. Historical blueprint checkpoints.
5. Earlier roadmaps and implementation notes.

Existing systems are assets to reconcile, not permission to create parallel authoritative implementations.

## Evidence scale

- **E0** — design only
- **E1** — source assembled and statically audited
- **E2** — Roblox Studio starts successfully
- **E3** — repeatable single-player loop demonstrated
- **E4** — multiplayer and adversarial behavior demonstrated
- **E5** — device, performance, and reliability demonstrated
- **E6** — outside-player fun demonstrated
- **E7** — live telemetry demonstrated

The repository is currently **E1**. Do not promote it without captured evidence.

## Current static evidence

The uploaded `Roblox_RPG_Quality_Baseline_v0.7` verification tools were executed on 2026-08-06.

- Blocking issues: **0**
- Warnings: **1**
- Warning: known type debt remains — **278 `any` tokens**
- Luau files: **115**
- Definitions: **33**
- Remotes: **22**
- Services: **20**
- TODO: **0**
- FIXME: **0**
- Deprecated task API: **0**

This is static evidence only and does not imply Studio runtime acceptance.

## User-directed verification timing

Roblox Studio verification is intentionally reserved for the final integrated verification pass. Until then:

- continue repo-side implementation and fixtures;
- preserve E1 status;
- never claim Studio, multiplayer, device, performance, or player acceptance;
- prepare exact final verification procedures and evidence templates as systems are completed.

## Immediate implementation queue

Because final Studio verification is deferred, proceed through the repo-verifiable safety and integration queue:

1. Owner-only inventory snapshots and cross-player access rejection.
2. Item comparison and equip-to-combat handoff.
3. Dismantle and salvage transaction safety.
4. Capacity retry and durable overflow recovery.
5. Participation eligibility and personal reward isolation.
6. Persistence adapter hardening, session ownership, sequential migrations, quarantine, unknown-write reconciliation, and no-blank-overwrite.
7. Preparation room and Verdant Scar route integration.
8. Underroot Vault runtime integration, elite, and Gatekeeper.
9. Final source audit and type-debt ratchet.
10. Final Studio verification: E2 → E3 → E4 → E5, followed by outside-player testing.

## Quality gates

### Package gate

- integrity and version identity pass;
- strict mode remains universal;
- no service cycle, duplicate definition, or duplicate remote;
- no TODO/FIXME or deprecated task API;
- type and logging debt do not increase silently.

### Runtime gate — final verification

- Studio parses, starts, and runs tests;
- one-player loop repeats three consecutive times;
- two-player ownership and attribution pass;
- malformed and replay attacks fail;
- cleanup returns to baseline;
- no valuable result can be client-authored.

### Persistence gate

- adapter boundary;
- session ownership;
- sequential migrations;
- no-blank-overwrite;
- unknown-write reconciliation;
- overflow recovery;
- shutdown, rejoin, failure, and retry tests;
- durable transaction replay.

### Fun gate

Fresh testers can explain enemy roles, damage causes, Pulse Mark value, item differences, and their next goal—and voluntarily choose another run.

## Scope protection

Do not build yet: multiple continents, housing, auction house or unrestricted trading, PvP, raids, seasons, battle pass, dozens of classes, hundreds of legendaries, live generative dialogue, vehicles, mounts, or a large monetization catalog.

A feature is allowed only when it deepens the proven loop, has an owner and test path, fits performance/security budgets, and does not displace a more important quality requirement.
