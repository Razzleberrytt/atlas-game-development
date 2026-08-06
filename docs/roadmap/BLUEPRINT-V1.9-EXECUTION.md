# Roblox Cooperative FPS RPG — Blueprint v1.9 Execution

**Status:** Active source of truth  
**Blueprint version:** 1.9  
**Current checkpoint:** Secure rewards, randomized items, inventory, equipment, salvage, and persistence  
**Primary rule:** Build and prove one polished, replayable expedition before expanding scope.

## Product promise

Every meaningful session delivers discovery, growth, and a memorable story. The first product remains a five-to-ten-minute cooperative FPS RPG expedition with preparation, an approach route, one optional secret, a short procedural dungeon, three enemy families, one elite, one boss, randomized equipment, equipment decisions, saving, and cooperative play.

## Locked engineering laws

1. The server owns valuable truth.
2. Stable content IDs and explicit versions are mandatory.
3. Clients submit intent, never outcomes.
4. Valuable mutations require idempotent transaction IDs.
5. Definitions are data; runtime state never mutates definitions.
6. Services have explicit lifecycle and ownership.
7. Main remains playable after each merge.
8. Runtime and Studio evidence must be reported honestly.
9. Do not create parallel authoritative systems when an existing service can be extended.
10. Do not expand content categories until ownership, retry, migration, and recovery are proven.

## Blueprint v1.9 queue

- [ ] **Ticket 136 — Execute v0.6 in Studio.** Capture all runtime discrepancies before adding persistence.
- [ ] **Ticket 137 — Prove registry expansion.** Positive and malformed fixtures for every new category and cross-reference.
- [ ] **Ticket 138 — Prove deterministic loot.** Compare at least 100 repeated contexts and several thousand distinct contexts; verify content signatures and instance-ID uniqueness.
- [ ] **Ticket 139 — Prove exactly-once encounter reward.** Repeat, replay, and concurrently invoke completion and reward paths.
- [ ] **Ticket 140 — Prove inventory snapshot ownership.** Sanitized, owner-only snapshots with correction after rejected mutations.
- [ ] **Ticket 141 — Prove item comparison.** Outside testers can explain an item's tradeoff without coaching.
- [ ] **Ticket 142 — Prove equipment handoff.** Rifle and shotgun variants update runtime stats, invalidate reload correctly, reject old weapons, and prevent combat refill exploits.
- [ ] **Ticket 143 — Prove dismantle and salvage.** Locked, equipped, unknown, foreign, valid, replayed, and rate-limited requests.
- [ ] **Ticket 144 — Prove inventory-full retry.** Preserve the exact reward transaction through capacity failure and retry.
- [ ] **Ticket 145 — Two-player reward security.** Personal rewards stay isolated under repeated and adversarial requests.
- [ ] **Ticket 146 — Real participation eligibility.** Reward only trusted encounter members who satisfy contribution policy.
- [ ] **Ticket 147 — Overflow recovery.** A valid reward cannot disappear because normal capacity is full.
- [ ] **Ticket 148 — Persistence adapter.** In-memory, failure-injection, and DataStore adapters without gameplay-service rewrites.
- [ ] **Ticket 149 — Session ownership and migration.** Session leases, schema validation, sequential migration, quarantine, revision checks, and no-blank-overwrite behavior.
- [ ] **Ticket 150 — Persistence failure matrix.** Leave/rejoin, rapid reconnect, shutdown, throttling, write/load errors, old schema, malformed item, duplicate transaction, and controlled crash between reward and save.

## Repository status against v1.9

Already present in some form:

- deterministic expedition seeds and room plans;
- server-authoritative encounter completion;
- deterministic elite and boss equipment rewards;
- idempotent reward instance insertion;
- inventory/equipment persistence foundation;
- per-player session leases;
- participant roster freezing;
- server-only reward distribution;
- read-only reward and run presentation;
- source audits around client authority.

Must now be reconciled or strengthened:

- canonical rarity, affix, legendary, material, and loot-table registries;
- deterministic content signatures separate from globally unique instance IDs;
- inventory capacity and overflow recovery;
- owner-only inventory snapshots and versioned deltas;
- atomic equip/dismantle/salvage transactions;
- item-derived weapon runtime handoff and refill-exploit protection;
- real contribution-based reward eligibility;
- profile quarantine and sequential migration;
- no-blank-overwrite persistence rules;
- complete Ticket 136–150 fixtures and Studio evidence.

## Promotion gate

Do not proceed to broader procedural rewards or additional loot categories until:

- Studio accepts the registry and service graph;
- exactly-once rewards pass replay and concurrency attempts;
- inventory ownership passes adversarial tests;
- equip and dismantle create no duplication or refill exploit;
- legendary presentation matches behavior;
- two-player rewards remain isolated;
- persistent recovery passes Ticket 150.

## Current highest-ROI repository task

**Build the v1.9 deterministic loot proof harness and canonical content-signature contract, while preserving globally unique server-created instance IDs.**

Studio execution remains a manual gate. Repository-side work may continue only where it directly improves Tickets 137–150 and does not pretend Ticket 136 has passed.
