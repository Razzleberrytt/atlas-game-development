# MVP 0.1 — Direct Loot Interaction and Contextual HUD Evidence

**Status: PASS for this focused MVP 0.1 slice.** This packet closes the exact-build interaction rerun requested by PR #251. It does not accept the complete MVP 0.1 loop or promote the repository beyond E2.

## 1. Identity

- Date/time: 2026-08-08, approximately 22:58–23:10 America/New_York
- Tester/operator: Codex using the dedicated Roblox Studio integration
- Roadmap scope: MVP 0.1 direct world loot interaction, contextual HUD and discovered-weapon handoff
- Git branch: `codex/mvp01-rpg-opening`
- Git commit SHA: `9b1e2fff672efeff09ecdda8ae41465940c949ba`
- Artifact: `LivingKingdoms-mvp01-9b1e2ff.rbxlx`
- Artifact SHA-256: `0B9115F63D3B82F4016C79942F4F12D70CBEB63F6EFF3D0389922122F7C09F28`
- Tools: Rojo 7.7.0; StyLua 2.5.2; Selene 0.31.0; Lune 0.10.4
- Roblox Studio: `0.733.0.7330989`
- Server/client count: one server, one client
- Device/input: Windows desktop; keyboard/mouse; native `E` ProximityPrompt input
- Evidence level before/after: E2 / E2

## 2. Claims under test

1. Holding the native chest `E` prompt collects server-staged wood and ammunition, equips a discovered weapon without mutating a readonly ammunition table, and disables the prompt when nothing remains.
2. When capacity prevents one staged item from being collected, the chest retains that item and keeps a `Take Remaining` prompt available.
3. Ordinary survival presentation contains one contextual toast and no click-only chest cards, large chest-loot overlay or always-on backpack surface.

## 3. Preconditions and world fit

- The exact corrected artifact named above was opened in Studio and started with one client.
- The generated modern operation world remained under `Workspace.LivingKingdomsWorld` with 2,998 descendants.
- `ForwardOperationsHub` remained the preparation bridge and retained its specialist, loadout and expedition-lobby prompts.
- The player arrived at approximately `(-229, 7, -207)`; the nearest supply chest was at approximately `(-243, 3.7, -220)`.
- The change did not activate the held authored overworld, alter the Rojo mapping, or add another lobby, mission, inventory, combat or world owner.

## 4. Procedure

1. Started the exact artifact and confirmed server/client bootstrap, the modern operation world, Forward Operations Hub prompts, survival chest prompts and active HUD surfaces.
2. Read the initial server-authored survival snapshot: zero wood, zero pending loot, no discovered weapon and zero opened chests.
3. Navigated the ordinary player character to `LootChest1` and held the physical keyboard `E` action for longer than its 0.25-second hold duration.
4. Read the resulting server-authored survival snapshot, equipped-weapon attribute, chest prompt state, HUD structure and output.
5. Collected ordinary world firewood until the 30-slot wood capacity was full. The setup used server-side character repositioning only to reduce traversal time; every resource mutation still came from the existing native prompt and production server owner.
6. Approached `LootChest2`, held `E`, and read the staged-loot and prompt state.
7. Held `E` again while still full and confirmed the remaining wood stayed staged with the prompt enabled.

## 5. Observations

### Empty-capacity primary path

| Fact | Before | After | Pass? |
|---|---:|---:|---|
| Opened chests | 0 | 1 | yes |
| Wood | 0 | 4 | yes |
| Pending loot | 0 | 0 | yes |
| Discovered weapon | false | true | yes |
| Equipped weapon | starting sidearm | `weapon.submachine-gun` | yes |
| Chest prompt | `Open Chest`, enabled | `Take Remaining`, disabled | yes |
| Readonly ammunition mutation error | — | absent | yes |

The contextual toast reported `Razor Compact SMG EQUIPPED`. No click card appeared.

### Full-capacity edge path

After reaching 30/30 wood capacity, opening `LootChest2` collected its ten ammunition rounds but retained three wood:

```json
{"wood":30,"openedChests":2,"pendingLoot":[{"chestId":"chest.2","quantity":3,"kindId":"wood","itemId":"chest.2.wood"}]}
```

The prompt remained enabled with `ActionText == "Take Remaining"`. A second `E` attempt preserved the same pending item and produced `BACKPACK FULL — firewood remains in the chest`.

### HUD and ownership

- `SurvivalHUD` contained zero `TextButton` descendants.
- No `CHEST LOOT` or `BACKPACK` text remained in `SurvivalHUD`.
- The compact `ContextToast` remained the only survival-specific HUD surface.
- `CollectItem` was absent; the client supplied no item ID, quantity, inventory state, ammunition state or weapon outcome.
- `SurvivalLootService` remained the consequential loot/proximity/capacity owner and `OperativeCombatRuntimeService` remained the weapon/ammunition owner.

## 6. Console review

- Expected unpublished-place DataStore fallback warning: present.
- Product runtime errors on the corrected chest/equip path: zero.
- Readonly-table mutation error: zero.
- Queue/discard warnings: zero observed during this focused run.
- One `AssistantCommand` formatting error was produced by an operator-authored read-only HUD inspection snippet. It did not originate from repository source or a gameplay controller/service and did not alter the tested state.

## 7. Acceptance and open conditions

- Packet result: `PASS`
- MVP 0.1 status: still active / incomplete
- Rollback trigger occurred: no
- Runtime/presentation compatibility removal authorized: no
- Evidence level promotion: none
- Studio-only checks still open: full first-run completion/replay, safe-arrival launch gating, elite/boss/result/return flow, multiplayer, controller/touch interaction, device safe areas, streaming and performance.
- Next highest-ROI task: add the minimal server-authoritative safe-arrival and deliberate expedition-launch boundary before hostile pressure begins, reusing the Forward Operations Hub and canonical expedition owners.
