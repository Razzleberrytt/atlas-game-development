# Atlas — Execution Dashboard v1.10

**Status:** CURRENT DAILY EXECUTION AUTHORITY  
**Refreshed:** 2026-08-10  
**Purpose:** answer quickly: **what is true, what is NOW, what is NEXT, and how do we keep later development cheaper?**

For detailed acceptance use `PLAYABLE-MVP-PATCH-EXECUTION.md`. For long-range scope use `MASTER-ROADMAP.md`. `MVP-BUILD-THROUGH-TESTING-POLICY.md` controls cadence. Repeated families use `../production/EXTENSION-COST-MODEL.md`; reusable gameplay effects use `../production/EFFECT-OWNER-ROUTING.md`.

## 1. Current truth

- **MVP 0.1 source:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.2 combat/readability source pass:** **BUILT — VERIFICATION PENDING**.
- **Patch 0.3 — Loot + Build Replayability source pass:** **BUILT — VERIFICATION PENDING**.
- Studio/device/play/performance evidence remains a parallel lane; unrun evidence is not a source-development lock and is never called VERIFIED.
- Patch 0.3 has live canonical routes for all six current durable effect families: `DamagePercent`, `ReloadSpeedPercent`, `MaxHealthPercent`, `MoveSpeedPercent`, `AbilityHastePercent`, and `AbilityPowerPercent`.
- PR #350 proved the compounding seam by expanding the authored affix pool from 8 to 16 with only config + pure fixture changes and **zero server-authority changes**.
- PR #351 added a composed end-to-end durable affix lifecycle regression proving representative Weapon, Armor, and Relic effects survive deterministic generation → banked durable reward → inventory reconstruction → equipped-slot resolution → live modifier facts after reconnect reconstruction. Full validation and the reproducible build are green.
- **Patch 0.4 — RPG Progression:** **BUILDING**.
- PR #352 established the bounded durable Operative Rank map: Initiate → Delver → Pathfinder → Veteran → Vanguard at 0/1/3/6/10 completed expeditions. Rank is derived from already-persisted canonical Boss reward grant identities, so no second DataStore/schema/player-load owner was introduced.
- PR #353 wired a read-only owner-bound Operative Rank runtime through the existing loaded inventory record. The client can request only its own server-derived snapshot; there is no durable-progression mutation RemoteEvent.
- PR #354 surfaced current durable rank, lifetime expedition clears, and clears-to-next-rank inside the existing Character menu.
- PR #356 converted the paused Skills surface into a durable progression map backed by `OperativeProgressionConfig`, while preserving the old temporary run-upgrade topology as run-only authority. Full validation and reproducible build are green; visual/device verification remains pending.
- PR #357 proved the first live personal durable-unlock seam: Rank 2 `Rally Ping` is authored in durable progression, derived server-side from existing durable rank, routed through `SquadPingService`, and cannot be claimed by client intent. No new persistence owner was added.
- PR #360 added Rank 2 `Dual Tactical Markers`: baseline personal capacity remains one, earned capacity becomes two, the squad hard cap remains four, and the existing server ping owner derives eligibility. The second progression unlock reused the established rank/unlock seam without another persistence or network owner.
- Existing `RunProgressionService` remains explicitly **run-only** shared Field XP + temporary upgrades. Durable Operative Rank must not become a second author of those facts.
- The four non-pistol firearms remain intentionally authored as rare in-run discoveries; Patch 0.4 should not casually convert them into permanent insertion unlocks and erase that discovery loop.

## 2. NOW → NEXT → LATER

### NOW

**Prove Patch 0.4 progression breadth outside the squad-ping family by choosing the smallest personal long-term side-grade/access/identity unlock whose consequence can route through a different existing canonical owner.**

Target chain:

```text
existing durable rank facts
→ OperativeProgressionConfig unlock definition
→ existing owner-bound OperativeProgressionService eligibility
→ a different existing server consequence owner
→ existing RPG progression-map presentation
→ focused ownership/regression proof
```

Rules:

- do not add another persistence schema, unlock DataStore, duplicate runtime service, or client-authored entitlement;
- prefer choice/access/identity and bounded utility over permanent raw damage/health inflation;
- prefer an existing server owner with an already-safe client intent or no new client intent at all;
- do not weaken the rare in-run firearm discovery loop;
- do not attach personal durable rank to shared Field XP/run-choice authority unless co-op ownership policy is explicitly solved first;
- keep the progression map data-driven: a new authored unlock should appear through existing presentation seams rather than another menu rewrite;
- if the next candidate requires a genuinely new semantic, improve one reusable owner seam once instead of scattering rank checks through callers;
- keep visual/device verification pending until Studio/device evidence is actually run.

### NEXT

1. after one non-ping unlock proves cross-owner breadth, choose the first bounded **class/archetype or ability side-grade** that reuses an existing server ability/class owner;
2. prefer alternate behavior, utility, access, or identity over additive permanent combat-stat growth;
3. keep each durable unlock personal and server-derived while shared run progression remains temporary and squad-scoped;
4. continue Patch 0.4 breadth through authored config and stable owner adapters so the marginal cost of later unlocks declines;
5. retain the consolidated Studio/device/play-feel evidence lane for Patch 0.1–0.4 source work.

Rejected shortcuts remain:

- rank-based shared run-upgrade rerolls/extra cards: current run-upgrade choices are squad-wide while Operative Rank is personal, creating ambiguous co-op/carry policy;
- permanent insertion access to the rare LMG/shotgun/sniper/SMG: current firearm contract intentionally preserves those weapons as rare in-run discoveries;
- raw permanent combat-stat inflation: weakens the current-run loop instead of adding RPG choice;
- client-only cosmetic eligibility presented as a server-owned gameplay unlock: identity presentation is valid only when entitlement truth still comes from a canonical server-owned fact.

### LATER

- deeper Patch 0.4 RPG progression: broader class/archetype progression, ability/skill side-grades, activity/world unlocks, quests/NPCs, limited crafting, achievements/codex;
- Patch 0.5 Main World/environment;
- Patch 0.6 systemic replayability;
- Patch 0.7 persistence hardening;
- Patch 0.8 co-op/social/session;
- Patch 0.9 content/pipeline expansion;
- release-candidate hardening.

### WIP limit

- one active implementation PR for the current capability;
- at most one additional non-overlapping feature PR only when the first is externally blocked;
- never duplicate an existing open PR.

## 3. Compounding-development target

The repository must become **cheaper to extend as it grows**.

For repeated feature/content families:

```bash
python scripts/extension_cost.py list
python scripts/extension_cost.py show <contract-id>
python scripts/extension_cost.py check <contract-id> --base main
```

For reusable gameplay effects:

```bash
python scripts/effect_routes.py validate
python scripts/effect_routes.py list
python scripts/effect_routes.py show <EffectId>
python scripts/effect_routes.py next
```

The two controls answer different questions:

```text
effect route → where the semantic belongs
extension contract → how expensive another family member should be
```

Rules:

- data-first variants should normally touch zero server-authority files;
- a live effect should not require repeated bespoke runtime wiring;
- unresolved effects require a canonical server owner before implementation;
- if the third variant still needs bespoke wiring, improve the seam before scaling breadth;
- repeated budget overruns are engineering friction, not a normal cost of growth;
- genuine new semantics may exceed budgets—explain/escalate instead of hiding complexity.

**North-star engineering metric:** declining marginal implementation cost for proven feature families.

Patch 0.4 reusable layers are now:

```text
banked completed-expedition facts already owned by durable inventory
→ pure bounded Operative Rank resolver
→ owner-bound read-only progression snapshot + generic unlock eligibility
→ existing RPG progression-map presentation
→ server-owned personal unlock consequence adapters
→ authored unlock breadth without another save owner
```

The Rally + Dual Tactical Marker pair proves one owner family. The next leverage test is **cross-owner reuse**: the same durable unlock seam should drive a different existing server owner without creating parallel progression infrastructure.

## 4. Studio/device evidence lane

The consolidated pass should cover the representative run, replay, keyboard/controller/touch, combat feel/readability, banking/equip, lifecycle, build-choice readability, durable rank/progression presentation, Rally/marker readability, and representative performance.

- **pass:** promote applicable BUILT — VERIFICATION PENDING work to VERIFIED;
- **reproducible failure:** make the concrete FIX NOW and preempt expansion;
- **not run:** continue dependency-safe source work while preserving pending-evidence truth.

## 5. Planning snapshot

| Area | Status truth | Compounding target |
|---|---|---|
| Foundation / architecture | mature | stable owners + machine-readable routing + low rediscovery |
| MVP 0.1 | BUILT — VERIFICATION PENDING | regression-protected baseline |
| 0.2 combat/readability | BUILT — VERIFICATION PENDING | reusable feedback/reaction contracts |
| 0.3 loot/builds | BUILT — VERIFICATION PENDING | affix/effect/reward variants are data-first |
| **0.4 RPG progression** | **NOW — BUILDING** | rank facts → data-driven map → reusable cross-owner personal unlock seams |
| 0.5 Main World | preparation partial | stable IDs + registry-driven interactions |
| 0.6 systemic replayability | foundations present | combinatorial output from reusable systems |
| 0.7 persistence | substantial foundations | migration/lifecycle invariants and recovery tests |
| 0.8 co-op/social | basic foundations | multiplayer coverage over existing owners |
| 0.9 content/pipeline | preparation present | mostly data/content + validation |
| RC 1.0 | future | accumulated automation reduces hardening cost |

## 6. Agent task algorithm

When asked to continue:

1. fetch current `main`;
2. inspect open PRs and same-capability branches;
3. read NOW/NEXT;
4. fix concrete safety/authority/data/runtime/validation failures first;
5. otherwise implement the smallest coherent NOW increment;
6. inspect effect-owner route when wiring reusable gameplay semantics;
7. use extension contract when extending a repeated family;
8. prefer existing owners + data/configuration over copied services/controllers/remotes;
9. add focused regression defense;
10. run the matching validation profile;
11. merge successful dependency-safe work;
12. keep manual evidence pending when not run;
13. continue until a real blocker or exhausted roadmap exists.

## 7. Real stop conditions

Stop expansion and fix when continuing would knowingly build on unsafe/false assumptions, including client-authored consequential truth, valuable-state corruption/duplication, competing owners, known lifecycle failure, missing required canonical authority, irreversible unsafe migration, or automated validation failure.

Unrun ordinary Studio/device/play-feel evidence alone is not a stop condition.

> **Build continuously, route effects to one owner, make repeated variants cheaper, automate recurring friction, and stop only for real blockers.**
