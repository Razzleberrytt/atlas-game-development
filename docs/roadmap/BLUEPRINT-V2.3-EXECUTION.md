# Blueprint v2.3 Execution Authority

Blueprint v2.3 (`Roblox_RPG_Refined_v2.3`, released 2026-08-07) is the active production
authority for Atlas. It supersedes [`BLUEPRINT-V2.0-EXECUTION.md`](BLUEPRINT-V2.0-EXECUTION.md).

## Release intent

Version 2.3 is a refinement and integration release. It adds no feature scope. It exists because
the project already has more design than the next milestone needs, and the remaining quality
problem is coordination: the same enemy, route, mark, highlight, animation, remote, and item can
each be described correctly in isolation and still fail when all of them run together.

The release must make five things easier:

1. **Find current truth quickly** — no contributor should read ten historical closing directives
   to learn what to build.
2. **Know who owns runtime state** — every durable, replicated, visual, and temporary state has
   one mechanical owner and one presentation owner.
3. **Prove cleanup** — restart, respawn, stream-out, encounter reset, and controller shutdown
   return measurable state to baseline.
4. **Preserve readability across quality levels** — a mobile or low-graphics player still
   understands route, threat, cover, target priority, secrets, and major cooldowns.
5. **Turn incidents into tests** — the queue-exhaustion and runaway-highlight symptoms become
   repeatable regression scenarios, not anecdotes.

### Explicit non-goals

Version 2.3 does not add a second biome, new classes or subclasses, new enemy families, new
monetization, final persistence implementation, final art assets, a final animation graph
architecture, or speculative optimization with no measured bottleneck.

## Product promise

Unchanged from v2.0 — build one polished, replayable five-to-ten-minute cooperative FPS RPG
expedition before expanding the world:

```text
prepare → choose weapon → outdoor route → fight Pursuer / Shooter / Warden
→ Pulse Mark for danger and optional clue → short procedural Underroot run → elite
→ receive and equip randomized item → Gatekeeper → return → voluntarily begin another run
```

## Authority order

When project materials conflict, use this order:

```text
accepted runtime evidence / current platform behavior
→ Production Core v2.3 + master chapters 181–196
→ latest specialist bible (visual, Studio integration)
→ canonical architecture chapters 33–63
→ earlier design
→ historical checkpoints (v1.4 – v2.2)
```

Historical closing directives are context, not orders. A historical file path, API wrapper, or
ticket number may be replaced when the replacement preserves the underlying product law and
passes stronger evidence.

### Authority classes

Every requirement belongs to exactly one class, and a sentence must never silently move between
them. An animation marker can request a presentation cue; it does not become mechanical authority
because its timing looks good.

| Class | Meaning | Example |
|---|---|---|
| Mechanical | Server-owned gameplay truth | damage, cooldown, loot grant |
| Presentation | Client-visible interpretation | outline, HUD marker, recoil |
| Authoring | Asset/content creation rule | pivot, silhouette, material family |
| Operational | Build/test/release procedure | soak test, rollback, evidence capture |
| Historical | Prior reasoning or checkpoint | old ticket queue, superseded source shape |

### Conflict rule

1. Identify whether both values claim the same authority class.
2. Prefer accepted runtime evidence over authored prose.
3. If both are prose, prefer the newer canonical layer.
4. If the newer value is explicitly provisional and the older value is accepted evidence, keep the
   evidence.
5. Record the resolution in `docs/decisions/` and update the Production Core.

## Evidence scale

- **E0** — design only
- **E1** — source assembled and statically audited
- **E2** — Studio starts and systems initialize
- **E3** — single-player integrated behavior demonstrated
- **E4** — multiplayer and adversarial behavior demonstrated
- **E5** — device, performance, and reliability demonstrated
- **E6** — outside-player fun demonstrated
- **E7** — live telemetry demonstrated

The repository is **E1**, with unresolved active-Studio presentation and network incidents. Do not
report E3 because code exists. Do not report E5 because a desktop test ran once.

## Current static evidence

The v2.3 adoption is a documentation change; it touches no gameplay behavior.

- Layout contract: **pass** — 262 Luau source files, 194 Lune fixtures, canonical Rojo mappings
  present (re-run on 2026-08-07 at adoption).
- `stylua --check` and `selene`: **pass** as of this adoption. Selene reports 0 errors, 0 warnings,
  0 parse errors.
- Lune fixture sweep and `rojo build`: enforced by CI
  (`.github/workflows/luau-validation.yml`), which is the controlling result. The pinned
  `rokit.toml` toolchain was unavailable in the adoption environment, so these were not run locally.

### Correction to the v2.0 static-evidence record

The v2.0 execution authority recorded every repository gate as passing on 2026-08-07, including
"`selene`: 0 errors, 0 parse errors, 6 warnings" reported as a **pass**. That was wrong in a way
worth naming, because it is the same failure mode v2.0 itself documented one paragraph later about
the v0.7 baseline.

`selene` exits non-zero when any lint fires. Six warnings is a failing gate, not a passing one with
a footnote. The consequence is visible in the run history: `luau-validation` last succeeded on
`576c65ee` (2026-08-06 04:16 UTC) and then failed on **eleven consecutive `main` pushes**, through
both the v1.9 and v2.0 adoption commits and through the commit titled "Restore a green main". Every
one of those commits was authored and merged while the recorded evidence said the gates passed.

The two surviving lints are fixed as part of this adoption — an unused loop variable in
`EquipmentRewardDeterminismProbe` and a manual table clone in `ExpeditionDiagnosticsService`. Both
are mechanical; neither changes behavior. `main` is green again.

The lesson carried forward, alongside the v2.0 lesson about external audit tools: **a gate's own
exit code is the result.** A summary that says "pass" next to a non-zero exit is not evidence, and
a green badge nobody read is not a green build. Engineering law 2 — `main` stays playable — is only
meaningful if the check that proves it is actually consulted.

This is static evidence only. It does not imply Studio runtime acceptance, and v2.3 makes no claim
that the active Studio place has been repaired.

## Release blockers — active Studio incidents

The v2.3 package ships a Studio screenshot dated 2026-08-07 showing two symptoms in the active
place:

1. `ReplicatedStorage.HordeNetwork.State` remote-invocation queue-exhaustion warnings.
2. Escaped broad blue/yellow `Highlight` presentation.

**The screenshot proves symptoms, not causes.** Instrument before attributing. The v2.3 audit
records these as deliberately un-guessed unknowns: the exact producing scripts, the actual producer
rate and whether it grows after reset, client listener lifetime, the bad `Adornee` selection, and
whether the current `.rbxl` contains systems outside the documented source baseline.

### Change to verification timing

Blueprint v2.0 reserved all Roblox Studio verification for a final integrated pass. That timing
rule is **superseded for incident closure only**. Captured runtime evidence outranks authored
prose (conflict rule 2), and a queue-exhaustion warning in normal play is a v2.3 critical stop
condition — it cannot wait for a final pass. Studio work is now authorized, and required, for the
instrumentation, triage, and soak steps in tickets 211–220. Everything else still holds: no
Studio, multiplayer, device, performance, or player result may be claimed without a captured
evidence packet, and E1 stands until one exists.

## Cross-system runtime ownership

Default ownership map for the vertical slice. Full matrix in
[`CROSS-SYSTEM-TRACEABILITY-V2.3.md`](CROSS-SYSTEM-TRACEABILITY-V2.3.md) and master chapter 183.

| State | Mechanical owner | Replication owner | Presentation owner | Cleanup trigger |
|---|---|---|---|---|
| Player health | HealthService | gameplay state channel | HUD/combat feedback | death/respawn |
| Weapon ammo/reload | WeaponService | weapon result/state | WeaponController/HUD | respawn/equip |
| Enemy life/target | EnemyService/component | enemy state | enemy presentation | death/reset |
| Encounter phase | EncounterService | runtime snapshot/delta | objective/HUD presentation | reset/end |
| Pulse Mark | Status/Ability services | status/presentation delta | mark presentation | expiry/death/reset |
| Warden shield | CombatModifierService | modifier delta | shield-link presentation | source/target/range/reset |
| Objective | quest/encounter domain | objective delta | objective controller | completion/reset |
| Route guidance | semantic route state | presentation delta | RouteGuide controller | target change/reset |
| Landmark accent | semantic landmark state | presentation delta | Landmark controller | context change/stream-out |
| Secret clue | DiscoverableService | eligible audience delta | secret presentation | expiry/discovery/reset |
| Highlight instance | none | none | HighlightLeaseRegistry only | lease release/owner destroy |
| VFX instance | none | presentation event | effect pool/scope | duration/reset |
| Animation track | none | none | animation controller | state/character destroy |
| Camera modifier | none | none | camera stack | scope release/respawn |
| Item ownership | Inventory/Profile | inventory snapshot/delta | inventory UI | profile release |

**Ownership law.** If two controllers both think they own the same visual primitive, neither does.
They must request the same centralized presentation service through semantic leases or channels.

## Runtime presentation contract

```text
client constructs controllers → binds listeners → ClientReady
→ one authoritative RuntimeSnapshot → revisioned semantic RuntimeDelta messages
→ unreliable channel only for disposable high-frequency cosmetic signals
```

Do not send unchanged state because a frame elapsed. Do not funnel every presentation concern back
into one generic state remote. Production highlights may not target `Workspace` or broad region
roots. Stable semantic IDs survive streaming; local instances may come and go.

## Dependency-ordered queue — tickets 211–240

This queue replaces the v2.0 implementation queue as the controlling execution order. Items 1–6 of
the v2.0 queue are complete (repo-side) and are preserved as history in
[`BLUEPRINT-V2.0-EXECUTION.md`](BLUEPRINT-V2.0-EXECUTION.md); its remaining items 4–10 are
subsumed by ticket 240 and the persistence gate below.

### Incident closure (211–220)

| # | Ticket |
|---|---|
| 211 | Instrument every producer of `HordeNetwork.State` and capture per-producer send rates. |
| 212 | Instrument client bindings and controller connection counts. |
| 213 | Implement/verify listener-before-ready startup. |
| 214 | Implement one runtime snapshot and revisioned semantic deltas. |
| 215 | Remove unchanged recurring state broadcasts. |
| 216 | Run five-reset and three-respawn network leak test. |
| 217 | Enumerate every runtime Highlight producer and target. |
| 218 | Migrate route/landmark/mark highlights into the lease registry. |
| 219 | Add broad-target sanity rejection and debug reporting. |
| 220 | Capture clean ten-minute presentation soak. |

### Integrated visual/runtime baseline (221–230)

| # | Ticket |
|---|---|
| 221 | Build neutral validation scene using v2.1 metrics and v2.3 runtime counters. |
| 222 | Capture Emberwatch greybox route with route/landmark presentation enabled. |
| 223 | Capture Verdant Scar greybox with cover truth and mixed encounter. |
| 224 | Run stream-out/rebind test for one route target, landmark, objective, and secret. |
| 225 | Integrate Frontier Rifle FP blockout with a single viewmodel/camera owner. |
| 226 | Run 100-play rifle fire/reload marker-listener test. |
| 227 | Integrate Pursuer lunge blockout and no-damage readability test. |
| 228 | Integrate Shooter and Warden cue stack at minimum graphics. |
| 229 | Integrate Pulse Mark mark/secret presentation through centralized ownership. |
| 230 | Run two-player visual-attribution test. |

### Quality and evidence (231–240)

| # | Ticket |
|---|---|
| 231 | Establish accepted steady-state network/connection/effect baseline. |
| 232 | Establish mobile/desktop representative-scene frame-time captures. |
| 233 | Add quality-tier toggles and reduced-motion capture set. |
| 234 | Complete cross-system traceability for every vertical-slice critical cue. |
| 235 | Resolve authority-critical type debt touched by the integration path. |
| 236 | Run single-player integrated loop three consecutive times. |
| 237 | Run two-player adversarial loop with reset, death, and disconnect. |
| 238 | Create first accepted E3 evidence packet. |
| 239 | Create first accepted E4 evidence packet. |
| 240 | **Only after 236–239**, resume persistence/durable-value implementation or the next dependency-complete vertical-slice system. |

Ticket 240 is a hard gate. The v2.0 persistence work — capacity retry and durable overflow
recovery, participation eligibility and personal reward isolation, persistence adapter hardening,
session ownership, sequential migrations, quarantine, unknown-write reconciliation, and
no-blank-overwrite — is not cancelled. It is blocked until 236–239 produce evidence packets.

## Quality gates

### Package gate

- integrity and version identity pass;
- strict mode remains universal;
- no service cycle, duplicate definition, or duplicate remote;
- no TODO/FIXME or deprecated task API;
- type and logging debt do not increase silently.

### Runtime gate — v2.3 promotion

Promotion requires all of the following captured facts:

```text
0 remote queue/discard warnings in supported normal play
0 broad production Highlight adornees
stable connection count after reset and respawn
stable presentation-object count after cleanup
late join receives correct snapshot
revision gaps recover safely
streamed targets rebind without false completion
100 animation plays do not multiply marker listeners
minimum graphics preserves critical cues
mobile capture preserves combat readability
single-player loop repeats cleanly
multiplayer attribution and cleanup pass
```

Once these facts are captured, update the evidence ledger and remove every provisional budget that
measurement has replaced.

### Persistence gate

Unchanged from v2.0, and now gated behind ticket 240: adapter boundary; session ownership;
sequential migrations; no-blank-overwrite; unknown-write reconciliation; overflow recovery;
shutdown, rejoin, failure, and retry tests; durable transaction replay.

### Accessibility gate

Full, Reduced, and Minimum Readable modes may change density and spectacle. They may not remove
route truth, cover truth, major enemy tells, objective identity, Pulse Mark state, Warden link
state, or essential shot/damage confirmation. Reduced-motion mode reduces camera shake, roll, FOV
pumping, bob, and secondary viewmodel kick **before** it removes essential gameplay feedback.

### Fun gate

Fresh testers can explain enemy roles, damage causes, Pulse Mark value, item differences, and their
next goal — and voluntarily choose another run.

## Stop conditions

Stop and fix before adding scope when:

- remote queue/discard warnings occur in supported normal play;
- connections or transient presentation objects grow across reset/respawn;
- a broad highlight hides gameplay;
- damage, loot, cooldown, or ownership can be client-authored;
- attack presentation lies about a hit window;
- cover art and collision disagree;
- reward retries duplicate or reroll;
- fresh testers cannot explain enemy roles or their next goal;
- low-graphics or mobile presentation loses critical information.

## Scope protection

Do not build yet: multiple continents, housing, auction house or unrestricted trading, PvP, raids,
seasons, battle pass, dozens of classes, hundreds of legendaries, live generative dialogue,
vehicles, mounts, or a large monetization catalog.

A feature is allowed only when it deepens the proven loop, has an owner and test path, fits
performance and security budgets, and does not displace a more important quality requirement.

## Companion documents

- [`PRODUCTION-CORE-V2.3.md`](PRODUCTION-CORE-V2.3.md) — daily decisions, provisional numbers, and
  the immediate critical path.
- [`STUDIO-TRIAGE-CHECKLIST-V2.3.md`](STUDIO-TRIAGE-CHECKLIST-V2.3.md) — the one-page checklist for
  the active queue and highlight incidents.
- [`CROSS-SYSTEM-TRACEABILITY-V2.3.md`](CROSS-SYSTEM-TRACEABILITY-V2.3.md) — promise, owner,
  presentation, asset, and evidence gate per vertical-slice cue.
- [`QUALITY-AUDIT-V2.3.md`](QUALITY-AUDIT-V2.3.md) — structural checks, refinements over v2.2, and
  the remaining runtime unknowns.
- [`REFINEMENT-CHANGELOG-V2.3.md`](REFINEMENT-CHANGELOG-V2.3.md) — what v2.3 changed and what it
  deliberately did not.
- [`../bible/studio-integration-presentation-bible-v2.3.md`](../bible/studio-integration-presentation-bible-v2.3.md)
  — runtime presentation architecture.
- [`../bible/visual-environment-animation-bible-v2.3.md`](../bible/visual-environment-animation-bible-v2.3.md)
  — environment, art, and animation production.

> The next version should be earned by runtime evidence. Clean the state channel. Contain the
> highlights. Prove the camera and animation lifecycles. Then build outward from a stable picture.
