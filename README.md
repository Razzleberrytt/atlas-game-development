# Atlas Game Development

Atlas is the GitHub-first development home for a **cooperative first-person action RPG on Roblox**.

The game combines readable FPS combat, randomized loot and buildcraft, long-term progression and world access, secrets, and replayable cooperative expeditions.

## Player promise

Every meaningful session should provide:

1. **Discovery** — something the player did not fully expect.
2. **Growth** — power, options, access, knowledge, mastery, collection, or social progress.
3. **Story** — at least one moment worth describing to another player.

## Primary production rule

> Build one polished, replayable expedition before expanding into a large world.

The first product is a five-to-ten-minute vertical slice containing preparation, an outdoor route, an optional secret, a short procedurally assembled dungeon, three enemy roles, one elite, the Gatekeeper boss, randomized equipment, saving, and cooperative play.

## Source of truth

The active implementation and quality authority is **Blueprint v2.3** (refined release, 2026-08-07):

- [`docs/roadmap/BLUEPRINT-V2.3-EXECUTION.md`](docs/roadmap/BLUEPRINT-V2.3-EXECUTION.md) — authority, ticket 211–240 queue, and gates
- [`docs/roadmap/PRODUCTION-CORE-V2.3.md`](docs/roadmap/PRODUCTION-CORE-V2.3.md) — daily reference and immediate critical path
- [`docs/roadmap/STUDIO-TRIAGE-CHECKLIST-V2.3.md`](docs/roadmap/STUDIO-TRIAGE-CHECKLIST-V2.3.md) — the current incident checklist
- [`docs/roadmap/README.md`](docs/roadmap/README.md) — full roadmap index, precedence, and historical checkpoints

When documents conflict, **captured runtime evidence wins, then Blueprint v2.3**. Existing systems are assets to reconcile with the blueprint, not permission to maintain parallel authoritative implementations. Historical checkpoints (v1.4–v2.2) remain valuable context; their closing directives are not orders.

## Evidence status

The project uses the v2.3 evidence scale:

`E0 design → E1 source → E2 Studio start → E3 solo loop → E4 multiplayer/adversarial → E5 device/reliability → E6 outside-player fun → E7 live telemetry`

**Current level: E1, with unresolved active-Studio incidents.** The layout contract passes at 262 Luau sources and 194 Lune fixtures; `stylua`, `selene`, the fixture sweep, and `rojo build` were last recorded green under v2.0 and are enforced by CI. Static acceptance does not imply Roblox Studio acceptance, and v2.3 makes no claim that the active Studio place has been repaired.

Two release blockers are visible in the active place, evidenced by a 2026-08-07 Studio screenshot: `ReplicatedStorage.HordeNetwork.State` queue-exhaustion warnings, and escaped broad blue/yellow `Highlight` presentation. The screenshot proves symptoms, not causes — instrument before attributing.

Studio work is now authorized for incident instrumentation, triage, and soak capture (tickets 211–220), superseding the v2.0 rule that deferred all Studio verification to a final pass. No Studio, multiplayer, device, performance, or player result may still be claimed without a captured evidence packet.

## Current checkpoint — incident closure and integrated runtime baseline

The active queue is v2.3 tickets 211–240, in dependency order:

- **211–220 incident closure** — instrument `HordeNetwork.State` producers and listeners, listener-before-ready startup, snapshot plus revisioned semantic deltas, five-reset/three-respawn leak test, enumerate every Highlight producer, migrate to the lease registry, broad-target rejection, clean ten-minute soak;
- **221–230 integrated visual/runtime baseline** — neutral validation scene, Emberwatch and Verdant Scar greybox captures, stream-out/rebind test, Frontier Rifle FP blockout, 100-play marker-listener test, Pursuer/Shooter/Warden cue integration, Pulse Mark presentation, two-player attribution;
- **231–240 quality and evidence** — accepted network/connection/effect baselines, device frame-time captures, quality-tier and reduced-motion sets, cross-system traceability, authority-critical type debt, three consecutive solo loops, two-player adversarial loop, first E3 and E4 evidence packets.

Ticket 240 is a hard gate: durable persistence and the next vertical-slice system resume only after 236–239 produce evidence. The v2.0 persistence queue (capacity retry and overflow recovery, participation eligibility and personal reward isolation, persistence adapters, session ownership, sequential migration, quarantine, unknown-write reconciliation, failure recovery) is not cancelled — it is blocked behind that gate.

No broader world, loot-category, social, monetization, or live-service expansion is allowed until this gate is passed.

## Repository map

- `docs/roadmap/` — canonical roadmap and active execution queue
- `docs/bible/` — supporting product vision and design history
- `docs/specifications/` — source-of-truth system behavior
- `docs/architecture/` — technical boundaries and engineering rules
- `docs/decisions/` — design and architecture decisions
- `docs/production/` — workflow, validation, and Definition of Done
- `games/living-kingdoms/` — Roblox/Rojo project
- `prompts/` — reusable agent prompts
- `templates/` — task, specification, decision, and bug templates

## Engineering laws

1. The server owns valuable game truth.
2. `main` stays playable.
3. Each implementation task produces one testable result.
4. Stable IDs and explicit versions are mandatory.
5. Valuable mutations use idempotent transaction IDs.
6. Clients submit intent, never outcomes.
7. Reusable engines outrank one-off content piles.
8. No runtime, Studio, CI, performance, or player result is claimed without evidence.
9. Do not create parallel authoritative systems.
10. The polished core loop outranks the eventual feature list.
11. Source assembly is E1, not gameplay acceptance.
12. Type and logging debt must not increase silently.

## Agent start order

1. Read this file.
2. Read `docs/roadmap/BLUEPRINT-V2.3-EXECUTION.md`, then `docs/roadmap/PRODUCTION-CORE-V2.3.md`.
3. Read the nearest `AGENTS.md` for files being changed.
4. Inspect existing contracts, registries, services, and tests before adding anything.
5. Implement the lowest-numbered incomplete v2.3 ticket that can honestly be completed in the current environment.
6. Preserve E1 status until a Studio evidence packet exists.
7. Record acceptance evidence honestly and prepare the verification path.

## Project status

**Phase:** runtime incident closure and integrated visual/runtime baseline  
**Evidence:** E1 — source assembled and statically audited, active-Studio incidents unresolved  
**Active milestone:** Blueprint v2.3 tickets 211–240, gated at 240  
**Working title:** unresolved  
**Roblox project path:** `games/living-kingdoms/`
