# HubTown Migration Manifest — BA-001

**Task:** BA-001 (build-ahead lane, P0 combined-game migration truth)
**Machine-readable source of truth:** [`hubtown-migration-manifest.json`](hubtown-migration-manifest.json)
**Evidence level:** source-proven only. No Studio or runtime evidence is claimed.
**Runtime posture:** inert. No entry is wired, bootstrapped, or activated.

This is the human-readable view. The JSON is authoritative and is the file CI
validates; this page can only summarize it.

## What HubTown is

The preserved place contains an authored medieval hub, `Workspace/HubTown`, with
80 direct children: a walled plaza, a central fountain, an archway and grand
staircase, torch and crystal lighting, town and vendor banners, four vendor
anchor folders, a quest board, and one dungeon portal folder.

Its server logic was `HubTownService`, which rotated vendor stock and processed
purchases. HubTown has **no canonical owner in `src` today** — no hub, vendor,
quest or social-space system exists in the canonical architecture. That is the
single most important output of this manifest.

## Coverage and its limits

- 81 recovered rows are in scope (`Workspace/HubTown` plus 80 children) and each
  is claimed by exactly one manifest entry. CI enforces this, so the manifest
  cannot silently omit recovered content.
- Depth 2 is complete. **No depth-3 row survives**, so every folder and model
  below is an identity without contents.
- No transform, size, material, colour or attribute survived for any instance.
  The preservation index recorded identity and parentage only.

Both limits come from the damaged preservation archives; see
[`../production/RBXL-IMPORT-INTEGRITY-2026-08-07.md`](../production/RBXL-IMPORT-INTEGRITY-2026-08-07.md).

## Entries

| Entry | Disposition | Legacy rows | Extraction | Canonical owner |
|---|---|---|---|---|
| `hubtown.root` | MIGRATE | 1 | recovered | none yet (BA-010) |
| `hubtown.plaza.floor` | MIGRATE | 1 | recovered | `WorldFoundationConfig.luau` |
| `hubtown.plaza.ring` | MIGRATE | 1 | recovered | `WorldFoundationConfig.luau` |
| `hubtown.plaza.center-emblem` | MIGRATE | 1 | recovered | `VisualAssetConfig.luau`; `VisualAssetContracts.luau` |
| `hubtown.plaza.inner-glow-ring` | REPLACE | 1 | recovered | `GameplayLightingConfig.luau`; `GameplayLightContracts.luau`; `GameplayLightingService.luau` |
| `hubtown.wall.segments` | MIGRATE | 4 | recovered | `WorldFoundationConfig.luau` |
| `hubtown.wall.crenellations` | MIGRATE | 20 | recovered | `WorldFoundationConfig.luau` |
| `hubtown.archway` | MIGRATE | 1 | **needs Studio** | none yet (BA-010) |
| `hubtown.grand-staircase` | MIGRATE | 1 | **needs Studio** | none yet (BA-010) |
| `hubtown.central-fountain` | MIGRATE | 1 | **needs Studio** | none yet (BA-010) |
| `hubtown.banner.town` | MIGRATE | 3 | recovered | `VisualAssetConfig.luau`; `VisualAssetContracts.luau` |
| `hubtown.banner.vendor-signage` | MIGRATE | 3 | recovered | none yet (BA-012) |
| `hubtown.light.standing-torches` | REPLACE | 6 | **needs Studio** | `GameplayLightingConfig.luau`; `GameplayLightContracts.luau`; `GameplayLightDescriptorValidator.luau`; `GameplayLightingService.luau` |
| `hubtown.light.wall-torches` | REPLACE | 8 | **needs Studio** | `GameplayLightingConfig.luau`; `GameplayLightContracts.luau`; `GameplayLightingService.luau` |
| `hubtown.vfx.magic-orbs` | REPLACE | 6 | **needs Studio** | `GameplayLightingConfig.luau`; `PresentationAccessibilityConfig.luau`; `VisualAssetContracts.luau` |
| `hubtown.vfx.plaza-crystals` | REPLACE | 8 | **needs Studio** | `GameplayLightingConfig.luau`; `VisualAssetContracts.luau` |
| `hubtown.structure.crystal-pedestals` | MIGRATE | 8 | recovered | `WorldFoundationConfig.luau` |
| `hubtown.vfx.ground-fog` | REPLACE | 1 | **needs Studio** | `WorldFoundationConfig.luau`; `PresentationAccessibilityConfig.luau` |
| `hubtown.portal.dungeon` | MIGRATE | 1 | **needs Studio** | `ExpeditionLobbyService.luau`; `ExpeditionContracts.luau` |
| `hubtown.vendor.weapon-smith` | MIGRATE | 1 | **needs Studio** | none yet (BA-024) |
| `hubtown.vendor.armor-smith` | MIGRATE | 1 | **needs Studio** | none yet (BA-024) |
| `hubtown.vendor.apothecary` | MIGRATE | 1 | **needs Studio** | none yet (BA-024) |
| `hubtown.vendor.merchant` | MIGRATE | 1 | **needs Studio** | none yet (BA-024) |
| `hubtown.interaction.quest-board` | MIGRATE | 1 | **needs Studio** | none yet (BA-020) |
| `hubtown.script.hub-town-service` | ARCHIVE | 1 | **needs Studio** | `InventoryLiveService.luau`; `PlayerInventoryContracts.luau` |

Totals: 15 MIGRATE, 6 REPLACE, 1 ARCHIVE across 24 instance groups plus 1
script; 3 entries carry no `KEEP` rows because nothing in HubTown is already in
canonical form.

## Findings that change how HubTown should be integrated

**1. Path is not a key.** Ten HubTown names are shared by more than one
instance: `Crenellation` (×20), `WallTorch` (×8), and `PlazaCrystal_1..4` and
`CrystalPedestal_1..4` (×2 each). Canonical content must mint its own stable
ids. Deriving ids from instance names would collide on day one.

**2. Lighting and VFX already have an owner.** Torches, orbs, crystals, the glow
ring and the ground fog are `REPLACE`, not `MIGRATE`. `GameplayLightingConfig`,
`GameplayLightContracts`, `GameplayLightDescriptorValidator` and
`GameplayLightingService` exist and are canonical. Restoring the legacy
`PointLight`/`Fire` instances would create the second presentation path that the
v2.7 rollout is actively trying to eliminate.

**3. The dungeon portal is the integration seam.** `hubtown.portal.dungeon` is
where the hub meets the canonical expedition loop. Launch authority already
belongs to `ExpeditionLobbyService`; the portal contributes eligibility and
destination data (BA-031), never a second launch path. The place contains
exactly one `ProximityPrompt`, a strong candidate for this portal, but its
parent was lost.

**4. Vendors are design work, not a port.** `HubTownService` reads
`HubTownConfig.VendorCatalog`, `HubTownConfig.NPCs` and
`HubTownConfig.RARITY_BASE_VALUE`, but `HubTownConfig` and `HubTownContracts`
were never present in the place. The legacy hub could not have run there. The
catalog, NPC roster and greetings have no surviving source anywhere, so BA-024
must treat them as new canonical design rather than reconstruct them by guessing
from call sites.

**5. Three vendors are confirmed, one is not.** `apothecary`, `armor_smith` and
`weapon_smith` each have a matching `HangingBanner_*`, which is good evidence
they were player-facing. `merchant` has no banner and its instance id (367) sits
far from the 125/145/165 cluster, so its role is unconfirmed.

**6. The art direction conflict is a product decision.** HubTown is a medieval
RPG hub. The canonical authored world in `WorldFoundationConfig` is a forest
extraction setting — Ranger Station, Logging Road, Military Roadblock,
Extraction Clearing — with a survival-horror presentation language. BA-010 has
to record an explicit decision before any geometry is migrated. This manifest
deliberately does not choose.

## Concepts worth keeping from `HubTownService`

Recorded so the ideas survive even though the module is `ARCHIVE`:

- 600-second rotating vendor stock;
- each refresh stocks a random 60–100% subset of the catalog;
- 20% chance of a daily deal at 15–40% off, retaining the original price;
- 5% chance of a "rare find" that upgrades rarity one step and scales stats 1.3×;
- 15% chance of a bonus affix on a purchased item, renamed "Lucky …".

What must not carry over: `os.clock()` as a stock-rotation clock, an unbounded
purchase handler, and trusting a client-supplied payload shape. Under canonical
rules the purchase path validates identity, payload shape and cadence, and all
currency and inventory mutation stays server-owned.

## Open gaps

| Gap | Blocks | Resolution |
|---|---|---|
| `gap.hubtown.depth3` | BA-010, BA-011, BA-012 | Re-extract the Workspace hierarchy from the source place. |
| `gap.hubtown.transforms` | BA-010, BA-011 | Re-extract with properties, or re-author as canonical graybox with the legacy layout as reference. |
| `gap.hubtown.config` | BA-012, BA-024 | Treat the vendor catalog as new canonical design work. |
| `gap.hubtown.theme` | BA-010 | Record an explicit art-direction decision first. |

## What this unblocks

BA-010 (HubTown composition specification) can now start against a known
inventory, a named set of gaps, and an explicit list of which rows already have
canonical owners. BA-011 and BA-012 stay blocked on BA-010 as the queue
specifies.
