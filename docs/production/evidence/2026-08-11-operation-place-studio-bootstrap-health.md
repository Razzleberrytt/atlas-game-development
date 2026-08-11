# Operation Place — Studio Bootstrap Health Observation

## 1. Identity

- Date/time: 2026-08-11, America/New_York
- Tester/operator: Claude (Cowork)
- Roadmap ticket(s): Studio evidence lane (MVP 0.1 / STOP-PLAY-FIX client-bootstrap health)
- Rollout stage: R1
- Git branch: `main`
- Repository commit at observation: `8544730` (PR #440 merged)
- Tools: Rojo 7.7.0; Lune 0.10.4; StyLua 2.5.2; Selene 0.31.0
- Roblox Studio version: `0.733.0.7330989`
- Place observed: Studio instance `LK 0.7`, `game.PlaceId = 75816315684285`
- **Place identity vs repository: NOT PROVEN.** This is an operator working place, not a Rojo
  artifact built from a recorded commit. See §5.
- Intended server/client count: one local server / one client (Play Solo)
- Graphics quality: Studio default, not pinned
- Device profile: operator desktop, not characterized
- Known-good rollback source: `8544730`

## 2. Claim under test

None promoted. This packet records **observations only** about server/client bootstrap health
in an operation-runtime place. It is deliberately not scoped as a BA-014 run, an MVP 0.1
acceptance run, or a promotion of any milestone.

## 3. Preconditions

- `python scripts/validate.py full` green at this commit — 335 Lune fixtures, StyLua, Selene,
  both Rojo builds.
- Studio API access initially **disabled**, then enabled by the operator mid-session (§5.2).

## 4. Procedure

1. Started Play Solo in the connected Studio instance.
2. Waited for `CharacterAdded` and `HumanoidRootPart`, then sampled client state.
3. Counted `PlayerGui` children — the fastest client-bootstrap health probe per `CLAUDE.md`.
4. Read console output for server/client bootstrap lines and errors.
5. Repeated across three sessions as the API-access and lease conditions changed.

## 5. Observations

### 5.1 Client bootstrap is healthy

`PlayerGui` child count: **22**, matching the expected healthy value in `CLAUDE.md`. A count of
1 would indicate the client bootstrap stalled. All expected surfaces were present:

```
BubbleChat, Chat, ClassActionUI, Freecam, HubCloseAffordance, LK_ExpeditionHUD,
LK_ExpeditionLobby, LK_ExpeditionResult, LK_ExpeditionReturn, LK_MatchResultDebrief,
LK_RunBuildHUD, LivingKingdomsConfirmedHitMarker, LivingKingdomsCriticalCondition,
LivingKingdomsFloatingDamageText, LivingKingdomsHordeHUD, PersonalFlashlightPresentation,
PresentationSettings, RPGMenu, SquadPingPresentation, SurvivalHUD,
TemporaryClassSelectionUI, WeaponLoadoutSelectionUI
```

Character spawned alive at 100/100 health. `EnemyEntities` folder present with 0 children
(expected in hub, no active horde). Backpack empty (loadout is granted at expedition launch,
not in hub).

Server bootstrap completed with no errors:

```
[Living Kingdoms] Server bootstrap started
[Living Kingdoms] World foundation ready: MVP-0.1-v3-living-dawn
[Living Kingdoms] Mission director started: Operation Blackwater Relay
[Living Kingdoms] Expedition lobby / live runtime / reward-result owner / diagnostics mounted
[Living Kingdoms] Inventory network and lease lifecycle mounted
[Living Kingdoms] Melee input runtime mounted
[Living Kingdoms] Read-only operative progression network mounted
[Living Kingdoms] Client bootstrap started
[Living Kingdoms] First-person camera activated
[SurvivorController] Native Roblox character controls enabled
```

### 5.2 Studio API access gates the entire play-evidence lane

With Studio API access disabled, `DataStoreService` returned `StudioAccessToApisNotAllowed`,
`AtlasPersistence` failed the inventory lease, and the server **kicked the player out of its own
playtest**:

```
[AtlasPersistence] failed to load <player>: LeaseStoreFailed
Server Kick Message: Your inventory is active on another server or could not be loaded safely.
```

Enabling **Game Settings → Security → Studio Access to API Services** cleared this. Any future
Studio play evidence run requires it.

### 5.3 Inventory lease is correctly bounded — operator note, not a defect

After a play session is terminated abruptly, the next session is kicked with
`LeaseHeldByAnotherServer` until the previous lease expires.

This was investigated and is **working as designed**, not a defect.
`InventorySessionLeaseService` stores `ExpiresAtUnix` and grants acquisition once the stored
lease has expired; `InventoryLiveService.luau:27` constructs it with a **90-second** duration,
and the constructor rejects any duration under 30 seconds.

Operator consequence: after stopping Play abruptly, **wait ~90 seconds before restarting**, or
the session is kicked at join. This is transient and self-healing.

### 5.4 Studio MCP `screen_capture` terminates a running play session

`screen_capture` captures the *edit-time* screen and forced Studio back to Edit mode,
terminating the session mid-run. Combined with §5.3 this costs ~90 seconds per occurrence.
Do not call it during a play session; drive the in-game camera and read state through
`execute_luau` instead.

### 5.5 Arrival spawn ambiguity in this place

Three `SpawnLocation` instances exist at runtime, two enabled:

| SpawnLocation | Position | Enabled |
|---|---|---|
| `LivingKingdomsMainWorld/HubCore/Arrival/SpawnLocation` | `0, 7, 30` | true |
| `LivingKingdomsWorld/Landmarks/RangerStation/SquadInsertion` | `-224, 3.4, -208` | true |
| `BootstrapSafetySpawn` | `-224, 0.5, -208` | true |

The character landed at the RangerStation insertion, ~310 studs from the Main World arrival
anchor. This is expected for an operation-runtime place, and is recorded because
`mwam.arrival.destination_matrix` explicitly measures "any ambiguity between safety and
production spawns" — any place carrying both worlds inherits this ambiguity.

## 6. Defects found

None confirmed. §5.3 was investigated and found correct by design; §5.2 and §5.4 are
environment/tooling conditions, not source defects.

## 7. Performance and matrix result

- Required gameplay matrix: not run.
- Combat, expedition launch, traversal, reward and replay loops: **not exercised.**
- Performance, memory, four-player, and device profiles: not captured.
- Sufficient for E5: no.

## 8. Acceptance decision

- Packet result: **observation only — no acceptance claimed.**
- No milestone is promoted. MVP 0.1 and Patches 0.2–0.4 remain **BUILT — VERIFICATION PENDING**.
- No BA-014 check is recorded; BA-014 requires the dedicated Main World artifact, which this
  place is not (see the 2026-08-11 BA-014 preflight packet).
- What this does establish: the client bootstrap does **not** stall in this build, the full
  server owner set mounts cleanly, and the Studio evidence lane is now operable end to end.
- Required next action for a real acceptance run: pin place identity to a Rojo artifact from a
  recorded commit, characterize device/graphics profile, then exercise the gameplay loop.

## 9. Attachments

- Console output: inline in §5.
- Screenshots/video/profiler: none retained; see §5.4.

> This packet records bootstrap health observations only. It is not runtime acceptance for any
> milestone.
