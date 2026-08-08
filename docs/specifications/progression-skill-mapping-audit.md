# Progression/skill mapping audit — BA-044

## Decision summary

The historical P11 plan and current v2.8 authority agree on the durable
progression guardrails: server-owned account XP and ranks, bounded side-grade
unlocks, no material permanent-power escalation, and no client-authored reward
facts. Current authority is broader than P11, adding an explicit
skill/progression map plus starting-option, world-access, codex, challenge and
cosmetic seams.

The runtime does not yet implement a career XP, rank or unlock domain. It does,
however, already contain four relevant foundations that must not be mistaken
for that domain or duplicated:

1. an operation-scoped Field XP and run-build system;
2. an authoritative terminal result and contribution record;
3. a pure class-selection availability check, currently fed only the three
   default starting classes by `ClassService`;
4. a domain-specific persistent inventory stack with DataStore retry,
   versioned records, session leases and idempotent transactions.

The smallest useful future progression slice is therefore one complete,
server-authored match award flowing through a duplicate-safe career profile
into a minimal configured XP/rank ladder and one approved non-power side-grade
unlock. A persisted completion counter or cosmetic alone would be a useful
Phase D infrastructure probe, but it would not exercise the XP/rank/unlock
contract BA-044 is mapping.

This audit is documentation-only. It activates neither blocked Phase D nor
locked Phase M and authorizes no persistence or gameplay change.

## Authority mapping

Current Product Authority and `MASTER-ROADMAP.md` control. The historical
charter and P11 plan are reusable design input, not executable status.

| Durable concern | Historical intent | Current authority | Current implementation |
|---|---|---|---|
| Account XP and ranks | P11 requires duplicate-safe XP from complete matches and a small military-style rank ladder. | Phase M names account/career XP and ranks. | No career XP profile, award resolver, rank configuration or rank presentation exists. |
| Class/side-grade unlock | P11 ends with one attainable side-grade specialist and no material permanent stat power. | Phase M permits class/side-grade unlocks; permanent power must remain bounded and justified. | Three starting classes are available to everyone. The pure selection resolver accepts an availability set, but the live service constructs that set from `startingClassIds`; no profile-backed provider is wired. |
| Skill/progression mapping | P11 sequences XP, rank and one class unlock but does not define a broader skill map. | Phase M explicitly requires skill/progression mapping and adds starting options, access, codex, challenges, cosmetics, respec and catch-up policy. | The current UI's "skill trees" are operation-scoped Field Upgrades, not durable skills. No durable nodes, prerequisites, points or respec model exists. |
| Reward facts | P10 records only server-owned result and contribution facts for later P11 weighting. | Server authority remains mandatory for progression, rewards and ownership. | `MatchResultService` freezes one first-commit-wins terminal snapshot. It intentionally contains no XP, rank or unlock. |
| Persistence safety | P11 calls for versioning, session ownership, recovery, retry and duplicate-award defense. | Phase D expands the required sequence and is blocked until R + E3/E4. | Persistent inventory already demonstrates several reusable mechanisms, but there is no career-profile schema or owner and Phase D's full exit evidence is not complete. |
| Power and monetization | No raw paid power, best-in-slot class sale or mandatory shortcut; permanent bonuses remain very small. | Permanent combat power must remain bounded; monetization remains locked behind the outside-player fun/repeat-intent gate. | No durable progression reward currently changes combat power. |

There is no product-direction conflict to resolve. The remaining work is to
make Phase M's broader durable-value categories explicit when its gate opens,
without relabeling the existing run-build trees as permanent skills.

## Current ownership map

### Operation-scoped progression is complete but non-durable

[`run-field-xp.md`](run-field-xp.md) explicitly defines Field XP, Field Level
and Field Upgrades as run-only state with no DataStore access. The live
`RunProgressionConfig` contains 12 selectable upgrades across Predator,
Gunslinger and Survivor; `RunRpgConfig` declares 17 upgrade IDs, so the broader
catalog remains 12 implemented and five planned. Run Relics likewise reset at
the operation boundary. These systems are evidence for run-build choice, not
for Phase D or M.

This distinction matters because `RPGMenuController` uses progression-shaped
language and tree presentation. Future durable UI must name career rank,
account unlocks and run upgrades distinctly so players and maintainers do not
infer persistence where none exists.

### Terminal reward input exists; award ownership does not

`MatchResultService` records bounded contribution facts from the combat,
revive, class and mission owners, then freezes them with the authoritative
terminal result. `MatchResultContracts` intentionally excludes XP, rank and
unlock data. That snapshot is the correct read-only input seam for a future
pure award resolver; it must not be expanded into a second result owner.

Two identity/commit details remain for the future P11 plan to lock:

- map each terminal operative entity to its authoritative account identity at
  the award boundary rather than trusting a client-supplied player ID;
- define a stable per-operation award identity and durable replay record so
  reconnects, retries and duplicate terminal delivery cannot grant twice.

### The class unlock seam is partial

`ClassSelectionResolver` accepts `availableClassIds` as server facts and rejects
an unavailable request with `ClassUnavailable`. That pure contract can support
durable unlocks. The live `ClassService`, however, creates its module-local
availability set from every `ClassConfig.Selection.startingClassIds` entry and
passes that same set for all players. There is no external profile-backed
availability provider today.

Consequently, a future unlock does not require replacing the selection
resolver, but it does require one canonical server-owned integration from the
career profile into `ClassService`. The unlockable class identity and balance
remain a P11 planning decision; this audit does not invent an ID, kit or rank.

### Persistence infrastructure exists, but not a career profile

`RobloxInventoryDataStoreAdapter`, `InventorySessionLeaseService`,
`PlayerInventoryPersistenceService` and `InventoryLiveService` already provide
real inventory-domain mechanisms including bounded retry, `UpdateAsync`,
versioned record migration, leases and applied transaction/grant records. That
means it would be inaccurate to say the repository has no persistence work.

It would also be unsafe to treat `AtlasPlayerInventoryV1` as an automatic
career profile. BA-042 found that the older persistent equipment path has an
unresolved product/authority decision, and its schema owns inventory items,
equipment slots and item transactions—not XP, ranks or class availability.
Phase D should reuse proven mechanisms or extract an approved shared boundary,
not bolt career fields onto that record or create an unreviewed parallel owner.

## Gap matrix

| Gap | Why it matters | Required owner/decision |
|---|---|---|
| No career profile contract or stable schema | XP, rank, unlocks, load state and applied awards have no canonical durable representation. | Phase D/P11 plan: profile ownership, versioning, migration and degraded-mode policy. |
| No pure XP award resolver | Raw contribution counts have no weighting, caps, success/failure policy or anti-idle treatment. | P11-PLAN-001 and P11-0103; consume only terminal server facts. |
| No deterministic rank configuration | There is no authoritative curve, cap, unlock rank or derivation rule. | P11-0101/P11-0104; configuration plus pure fixtures. |
| No duplicate match-award ledger | First-commit-wins in memory does not survive retry, reconnect or another server. | Phase D commit boundary keyed by a stable operation award identity. |
| Operative-to-account award mapping is unspecified | Result rows use operative identity; durable state belongs to an account. | Mission/session owner supplies the server-authored mapping at terminal commit. |
| Class availability is global in the live service | The resolver can reject unavailable classes, but all players receive the same starting set. | One profile-backed server provider integrated into `ClassService`; no client unlock claims. |
| Unlock content is not selected | Inventing a class or reward now would bypass the required side-grade and product review. | P11-PLAN-001 selects one concrete, attainable, non-dominating reward. |
| Durable and run-scoped "skills" can be confused | Players could misread temporary tree choices as account progression. | Phase M taxonomy and presentation contract before implementation. |
| Phase D evidence gate remains unmet | Persistence activation before ownership/cleanup evidence risks durable duplication or loss. | R consolidation plus required E3/E4 evidence and Phase D authorization. |

## Smallest useful vertical slice after the gate opens

The first product-useful slice should be narrow but end-to-end:

1. **Plan the slice.** P11-PLAN-001 selects XP sources and bounds, victory and
   failure weighting, anti-idle treatment, a minimal configured rank ladder,
   one unlock rank, one concrete side-grade/non-power reward, schema ownership,
   retry/failure behavior and telemetry. No IDs or balance values are invented
   by this audit.
2. **Consume one existing authoritative terminal result.** A new progression
   owner reads the frozen match result and server-recorded contribution facts;
   it does not accept client award values or become another mission-result
   owner.
3. **Resolve the award purely.** A deterministic resolver produces a bounded
   award from validated result facts, including explicit success/failure and
   legitimate medic/engineer contribution handling.
4. **Commit once to a versioned career profile.** The server applies the award
   under session ownership and records its stable operation award identity in
   the same atomic durable update. Load/save failure cannot affect match
   correctness or imply success to the client.
5. **Derive rank and grant one approved unlock.** Rank comes from configured
   committed XP. The first reward is a reviewed side-grade or non-power option;
   if it is a class, the profile-backed availability provider feeds the existing
   class-selection resolver through `ClassService`.
6. **Disclose confirmed state.** Presentation distinguishes career XP/rank and
   unlock status from Field XP and run upgrades, and shows loaded, saving,
   confirmed and degraded/error states honestly.
7. **Prove recovery.** Fixtures and Studio/runtime evidence cover duplicate
   delivery, reconnect, leave, shutdown, retry, old/corrupt schema, unavailable
   DataStore, multiplayer identity mapping and no-award degraded operation.

This slice is deliberately larger than a counter-only persistence smoke test:
it is the minimum that proves the actual player-value loop and the authority
handoffs P11 requires. Broader skill maps, multiple unlock paths, respec,
catch-up, world access, equipment interaction and permanent stat bonuses remain
outside the slice.

## Gate and evidence status

- The repository's accepted program evidence is **E2** on pinned R1 artifact
  9028866465. This audit is **E1 source/document evidence only** and does not
  promote that level.
- Phase D remains **`[!] BLOCKED UNTIL R + E3/E4`**. Phase M remains **`[L]`**.
- No runtime code, DataStore, schema, remote, UI, economy, inventory owner,
  class definition, cutover-ledger row, compatibility flag or evidence packet
  changes here.
- BA-043's equipment/run-build authority decision remains independent and
  blocked; durable progression must not settle it incidentally.

## Completion boundary

BA-044 is complete with this current-vs-historical mapping, source ownership
inventory, gap matrix and dependency-gated vertical-slice proposal. The next
progression implementation task must come from an explicit checked-in
Codex/Claude assignment after Phase D's authority and evidence gates open.
