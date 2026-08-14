# Patch 0.9 — Content Expansion + Production Pipeline Acceptance

**Status:** SOURCE COMPLETE — CONSOLIDATED STUDIO/DEVICE VERIFICATION PENDING  
**Accepted source sequence:** PRs #508–#512  
**Acceptance date:** 2026-08-14

Patch 0.9 is complete at the source-development layer when it has increased useful content breadth in systems that already earned expansion and made the next content addition safer than the previous one. It is **not** complete at the runtime-evidence layer until the consolidated Studio/device pass validates the player-facing results.

The roadmap's Patch 0.9 list is candidate scope, not a command to manufacture one new system in every category. The governing goal is to scale proven systems without destabilizing the loop or multiplying maintenance cost unsafely.

## Acceptance matrix

| Lane | Status | Source evidence | Acceptance / deferral reason |
|---|---|---|---|
| Weapon breadth | SATISFIED | `FirearmConfig`, `EquipmentRewardConfig`, PR #508 | Existing Blackwater Support LMG and Razor Compact SMG now participate in durable equipment rewards instead of ending as one-run discoveries. |
| Weapon reachability pipeline | SATISFIED | `EquipmentRewardConfig`, `Patch09DurableWeaponCoverageSourceAudit` | Every discoverable firearm must have a durable representation and every equipment weapon link must resolve through the authoritative firearm registry. |
| Gear / affix breadth | SATISFIED | `EquipmentAffixConfig`, PR #509 | LMG and SMG roles gained bounded tag-aware affix paths using existing modifier effects. |
| Armor / relic breadth | SATISFIED | `EquipmentRewardConfig`, `EquipmentAffixConfig`, PR #511 | Scout Harness and Storm Catalyst add mobility-armor and offensive-relic build identities without introducing another stat authority. |
| Equipment differentiation pipeline | SATISFIED | `EquipmentAffixConfig`, `Patch09RoleAffixCoverageSourceAudit`, `Patch09GearArchetypeCoverageSourceAudit` | Dead affix tags fail authoring and every durable item must have at least one tag-specific affix path. |
| Dungeon-kit readiness | SATISFIED | `FirstDungeonContentConfig`, PR #510 | Flooded Passage and Fungal Vault received authored encounters; every room in the assembly pool must now be content-covered before a seed may safely expose it. |
| Room-content integrity | SATISFIED | `FirstDungeonContentConfig`, `Patch09RoomContentCoverageSourceAudit` | Room slot, intensity and reward identities are checked against assembly definitions; stale content for removed rooms fails. |
| Reusable room production | SATISFIED | `ExpeditionRoomPlacementService`, `ExpeditionEnvironmentBuilder`, PR #512 | Ordinary room breadth remains role-driven through one deterministic placement/environment path rather than per-room runtime owners. |
| Cross-registry authoring gate | SATISFIED | `PATCH-0.9-CONTENT-PIPELINE.md`, `Patch09ContentPipelineSourceAudit` | Reachability and maintenance invariants are now explicit and regression-audited across firearm, equipment, affix, room and encounter seams. |
| New class/archetype | DEFERRED | Existing class system remains authoritative | A fourth class would add ability, balance, presentation and co-op obligations. No play evidence currently shows that another class is higher ROI than validating the existing roster. |
| New enemy family | DEFERRED | Existing Walker roles + Blight Spitter remain the proven enemy lane | A new special enemy would add behavior, presentation, telegraph and tuning surfaces. Add one after current combat evidence identifies a missing tactical question. |
| Second boss | DEFERRED | Progenitor remains the proven boss path | Another boss is expensive breadth and should follow evidence that the current boss loop, reward cadence and readability are working. |
| New region / biome | DEFERRED | Existing world/environment production remains in place | Region expansion would multiply art/navigation/performance scope before the current exact-build visual pass is complete. |
| New quests / event framework | DEFERRED | Existing mission/run objectives remain authoritative | No separate quest authority is justified until retention/play evidence shows a specific need the current objective/event systems cannot satisfy. |
| New ability family | DEFERRED | Existing class action owners remain authoritative | More abilities would increase combat-balance surface before current class actions are device/runtime verified. |
| Crafting / resource system | DEFERRED | Roadmap explicitly scopes this only “where validated” | No current evidence establishes crafting as necessary to the proven loop, so adding it would be speculative system breadth. |
| Cosmetics / expression system | DEFERRED | No launch-expression requirement blocks the playable loop | Cosmetic infrastructure belongs after the core content and release-quality evidence justify the production/monetization surface. |

## Delivered source increments

### PR #508 — durable weapon variety

- Added durable reward representations for the Blackwater Support LMG and Razor Compact SMG.
- Bound equipment weapon references to `FirearmConfig.isKnownWeaponId`.
- Made discoverable-firearm → durable-equipment coverage an invariant.

### PR #509 — role-aware weapon affixes

- Added LMG and SMG role-specific affix content while reusing existing damage/reload effect owners.
- Rejected affixes that require tags absent from the durable equipment catalog.
- Required durable weapons to expose a role-aware roll path.

### PR #510 — complete room encounter library

- Authored encounter content for `flooded-passage` and `fungal-vault`.
- Upgraded the dungeon content table from current-route-only coverage to complete `RoomAssemblyConfig` coverage.
- Preserved the canonical verification seed rather than activating broader route variation before the pending exact-build pass.

### PR #511 — differentiated armor and relic archetypes

- Added Scout Harness and Storm Catalyst.
- Added mobility and offensive-ability affixes using existing health, movement, ability-power and cooldown modifier consequences.
- Strengthened the rule so every durable item, not only weapons, needs a role-aware affix path.

### PR #512 — reusable content production gate

- Codified the Patch 0.9 reachability and maintenance rules.
- Locked firearm → equipment, equipment → affix, room → encounter and room → generic environment production seams with source coverage.
- Explicitly prohibited using Patch 0.9 as permission to create broad duplicate authorities merely to satisfy a candidate-scope list.

## Patch exit assessment

The source exit question is:

> Can the team add substantial new content without destabilizing the proven loop or multiplying maintenance cost unsafely?

**Source answer: yes for the proven expansion lanes.** Weapon, equipment/affix and room-content additions now have explicit cross-registry failure checks and reuse existing runtime owners. The next author working in those lanes gets an earlier failure when content is unreachable, inert, stale or insufficiently differentiated.

This does **not** claim that arbitrary new classes, bosses, enemy behaviors or regions are now cheap. Those domains intentionally remain deferred because their next addition would expand runtime/balance surface rather than merely content data.

## Verification boundary

Patch 0.9 remains **SOURCE COMPLETE — VERIFICATION PENDING** until the consolidated Studio/device evidence pass validates at minimum:

- new durable weapon rewards can actually drop, bank, equip and affect the next run;
- new armor/relic archetypes roll valid differentiated affixes and their modifiers are visible in play;
- existing canonical dungeon content still completes end to end after the content-library hardening;
- representative keyboard/controller/touch presentation remains usable;
- multiplayer/reconnect/reward behavior from Patch 0.8 is not regressed;
- representative performance remains acceptable.

A real runtime failure immediately preempts later work and returns priority to FIX.

## Next lane

With no known Patch 0.9 source blocker, the next roadmap lane is **Release Candidate 1.0 — Production Readiness**, but only dependency-safe source hardening may build through while the consolidated runtime/device verification remains unavailable. Release-readiness work may not relabel any unverified patch as runtime accepted.
