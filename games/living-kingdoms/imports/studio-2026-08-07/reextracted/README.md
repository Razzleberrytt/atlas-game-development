# Direct Studio Re-extraction — 2026-08-07

This directory repairs the preservation gap discovered in the first GitHub archive of `livingkingdoms.rbxl`.

The repair was produced by parsing the original uploaded Roblox place again, not by attempting to reconstruct missing data from the damaged archive.

## Source identity

- Source: `livingkingdoms.rbxl`
- Bytes: `1,639,392`
- SHA-256: `e00fc74dcd9fd7d8a0ba003ba0dc88840a6ee43acba555e7facf260aff586f16`
- Parsed instances: `2,258`
- Parsed classes: `98`
- Parsed scripts/modules: `290`
- Workspace identity/hierarchy rows: `1,775`

## What this repair preserves

The small Studio-only files recovered earlier remain readable under `../recovered/legacy-src/`. Five additional exact source files were also restored there directly.

The six larger Studio-only files that were still missing are preserved losslessly in this checksum-pinned bundle:

- `ServerScriptService/SurvivalGatheringService.server.luau`
- `StarterGui/RPGUI.client.luau`
- `StarterGui/ShopUI.client.luau`
- `StarterGui/SurvivalHUD.client.luau`
- `StarterPack/Hatchet/SwingController.client.luau`
- `StarterPlayer/StarterPlayerScripts/RPGClientController.client.luau`

The bundle also contains the complete `1,775`-row Workspace identity/hierarchy index.

Run:

```bash
python restore-reextracted.py
```

A successful restore reports:

```text
REEXTRACTION_OK bundle_sha=812da7ce92d77ad69c4b1d9ffc0454c85a5b12e9b10499bc8be266535c08e156
verified_sources=6
workspace_rows=1775
```

`REEXTRACTION-MANIFEST.json` pins the source RBXL identity, bundle identity, each remaining source file, and the Workspace index.

## Important boundary

This closes the **source and hierarchy preservation** gap. It does not claim property-perfect reconstruction of the authored Roblox world. Exact CFrames, materials, terrain state, particles/VFX, lighting properties, and other instance properties still require the separate world-property reconstruction lane.

Nothing in this directory is mapped into the canonical Rojo runtime. The legacy RPG bootstrap and duplicate combat, persistence, inventory, loot, enemy, and monetization authorities remain inactive. The current repository runtime stays authoritative while useful Studio content is migrated through explicit contracts.
