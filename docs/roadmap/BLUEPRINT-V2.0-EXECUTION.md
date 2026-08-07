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

The repository's own required validation (`AGENTS.md`, `.github/workflows/luau-validation.yml`) was executed on 2026-08-07.

- Layout contract: **pass** — 259 Luau source files, 189 Lune fixtures
- `stylua --check games/living-kingdoms/src`: **pass**
- `selene games/living-kingdoms/src`: **0 errors, 0 parse errors, 6 warnings**
- Lune fixtures: **189 / 189 pass**
- `rojo build`: **pass**

This is static evidence only and does not imply Studio runtime acceptance.

### Correction to the 2026-08-06 baseline

The previously recorded `Roblox_RPG_Quality_Baseline_v0.7` result ("Blocking issues: 0") did not
reflect the repository's own gates. At that commit `main` failed every one of them:

- `ExpeditionResultService` did not parse (ambiguous call syntax), so result finalization and the
  replay decision could not load at all;
- `EnemyDirectorEncounterAdapter` declared `start`/`cancel` as `:` methods while its only consumer
  invokes them with `.`, so **every** encounter start was rejected and no expedition could leave
  its first phase;
- four server scripts resolved `ServerScriptService:WaitForChild("Systems")`, which does not exist
  under the canonical Rojo mapping (`Systems` is at `ServerScriptService.Server.Systems`), so the
  lobby, foundation bootstrap, diagnostics, and replay-decision bridge yielded forever;
- 35 source files failed `stylua --check`;
- 3 of 187 fixtures failed, two of which had never executed.

All of the above are fixed. The lesson carried forward: an external audit tool's report does not
substitute for the repository's own gates, and a fixture that has never run proves nothing.

## User-directed verification timing

Roblox Studio verification is intentionally reserved for the final integrated verification pass. Until then:

- continue repo-side implementation and fixtures;
- preserve E1 status;
- never claim Studio, multiplayer, device, performance, or player acceptance;
- prepare exact final verification procedures and evidence templates as systems are completed.

## Immediate implementation queue

Because final Studio verification is deferred, proceed through the repo-verifiable safety and integration queue:

1. ~~Owner-only inventory snapshots and cross-player access rejection.~~ **Complete (repo-side).**
   `PlayerInventorySnapshot.forOwner` is the one pure disclosure boundary: it serves only the
   owner, rejects a cross-player read rather than filtering it, fails closed on an
   owner/record mismatch, orders items deterministically, freezes what it returns, and drops the
   server-only replay ledgers (`AppliedRewardInstanceIds`, `AppliedRewardGrantIds`) and each
   item's `GrantId`/`RunId`/`Seed`. `InventoryLiveService.readOwnedSnapshot` is the only service
   read a client can reach, and `inventory-network.server.luau` derives the owner from
   `player.UserId`, rejects any supplied identity, and addresses every push with `FireClient`.
   Covered by `PlayerInventorySnapshot.test` and `InventoryOwnershipBoundarySourceAudit.test`.
   Studio verification remains deferred per the timing rule above.
2. ~~Item comparison and equip-to-combat handoff.~~ **Complete (repo-side).**
   `EquipmentComparisonResolver` states an item's tradeoff as facts: a stat verdict
   (`Upgrade`/`Sidegrade`/`Downgrade`/`SameItem`), signed power and rarity deltas, and the role
   change as sorted gained/lost tags. The verdict deliberately covers stats only, so a stronger
   shotgun replacing a rifle reads as "Upgrade, gains close-range, loses precision" rather than the
   resolver encoding a balance opinion. An empty slot reports zero deltas instead of a fake gain
   measured against zero power, and a slot naming an unowned item fails closed.
   `InventoryLiveService.compareOwnedItem` and the `CompareOwnedItem` remote take only a candidate
   instance id, so a client cannot have the server evaluate an item it does not hold.
   Covered by `EquipmentComparisonResolver.test` and the boundary audit.
   The equip-to-combat handoff (v1.9 Ticket 142) is wired. Each weapon-slot definition carries an
   authored `WeaponId` — `frontier-rifle → sniper-rifle`, `breach-shotgun → breach-shotgun`,
   `warden-sidearm → service-pistol` — validated at load, so an item cannot equip and drive
   nothing, and armor/relic slots must carry none. Equipping bumps the combat state generation,
   which the reload completion path is already gated on, so an in-flight reload cannot land on the
   new weapon; the selected target and processed shot ids are cleared, so shots referencing the
   replaced weapon are rejected.

   The refill exploit is closed. Equipping previously handed over a full magazine, so every swap
   refilled loaded rounds for free. `WeaponSwapAmmunitionResolver` now governs the transfer: a
   swap moves ammunition and never creates it. Carried rounds are preserved, fitted magazine-first
   to the incoming weapon, clamped to its caps, and any overflow is reported as discarded rather
   than hidden. Covered by `WeaponSwapAmmunitionResolver.test` (conservation across every case) and
   `EquipToCombatHandoffSourceAudit.test`.

   The fun gate — a fresh tester explaining a tradeoff unaided — needs a Studio session and stays
   deferred. Persisted `equip()` does not yet drive the live runtime; that belongs with the
   persistence work in item 6.
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
