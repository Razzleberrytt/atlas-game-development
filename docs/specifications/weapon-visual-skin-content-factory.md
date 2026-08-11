# Living Kingdoms — Custom Weapon Model + Skin Factory

**Status:** SOURCE-PREPARED PRESENTATION BOUNDARY

Living Kingdoms firearms should ultimately use custom first-person/view models and world/drop models rather than generic Roblox Tool geometry. Visual breadth must scale without duplicating weapon behavior.

## Authority boundary

`FirearmConfig`, combat services, ammunition, hit resolution, and existing gameplay owners remain authoritative for weapon behavior. The visual/skin registry contains no damage, cadence, magazine, reload, range, recoil, persistence, or reward policy.

Skins are cosmetic. A skin may change materials, palette, wear, markings, and ornament presentation; it may never change gameplay values.

## Custom model contract

Each canonical firearm receives one default visual identity with:

- a stable visual ID bound to the canonical weapon ID;
- independent view-model and world-model source paths;
- animation-set identity;
- required Grip, Muzzle, Magazine, and Ejection sockets;
- optional support-grip, optic, barrel, stock, underbarrel, and ornament sockets;
- compatible cosmetic skin IDs;
- explicit lifecycle status (`PlannedCustomModel`, `SourceReady`, `ProductionApproved`).

The initial five production-facing identities are:

- Vigil Service Pistol;
- Morrow Breach Shotgun;
- Longwatch Sniper Rifle;
- Razor Compact SMG;
- Blackwater Support LMG.

The legacy compatibility firearm is intentionally not treated as a sixth production art target.

## Visual direction

Weapon families should support a spectrum of **scavenged, frontier-built, military-surplus, experimental, and relic-grade** designs. Progression should be visible through craftsmanship and material language without forcing gameplay rarity to be encoded only through color.

Starter cosmetic material families establish Blackwater Issue, Frontier Worn, and Corruption Scarred as presentation directions, not finished production skins.

## Scaling rule

Adding future guns or skins should primarily require new custom models/material sets plus validated registry rows. New visuals must not require a parallel firing controller, inventory owner, or persistence path.
