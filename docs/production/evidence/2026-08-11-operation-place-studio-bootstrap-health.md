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

### 5.2 Studio API access observation — corrected safety interpretation

At the recorded `8544730` build, with Studio API access disabled, `DataStoreService` returned
`StudioAccessToApisNotAllowed`, `AtlasPersistence` failed the inventory lease, and the server
**kicked the player out of its own playtest**:

```
[AtlasPersistence] failed to load <player>: LeaseStoreFailed
Server Kick Message: Your inventory is active on another server or could not be loaded safely.
```

Enabling **Game Settings → Security → Studio Access to API Services** cleared that observed
bootstrap failure in this historical run. **That observation must not be interpreted as a safe
operator prerequisite for the recorded source.** At that time `InventoryLiveService` supplied
production inventory identity (`AtlasPlayerInventoryV1` / `atlas-prod`) and the adapter would use
the real DataStore whenever Studio API access made it available. A Studio evidence session could
therefore acquire a production lease or mutate/migrate live inventory.

Follow-up source hardening makes Studio inventory explicitly process-local/volatile **before**
any production `GetDataStore` call. Future Studio evidence may enable API access for unrelated
Studio tooling only when that isolation guard is present in the exact tested artifact. Never use
this historical packet as permission to connect an older build to production inventory storage.

### 5.3 Inventory lease behavior observed on the historical build

After a play session was terminated abruptly, the next session was kicked with
`LeaseHeldByAnotherServer` until the previous lease expired.

This matched the production lease contract at the observed build:
`InventorySessionLeaseService` stores `ExpiresAtUnix` and grants acquisition once the stored
lease has expired; `InventoryLiveService` constructs it with a **90-second** duration, and the
constructor rejects any duration under 30 seconds.

This observation is retained for historical accuracy, but **future Studio runs using the
Studio-isolated volatile adapter must not be expected to create or wait on production leases**.
A production-style lease delay seen during Studio after the isolation fix should be investigated
rather than normalized as an operator wait step.

### 5.4 Studio MCP `screen_capture` terminates a running play session

`screen_capture` captures the *edit-time* screen and forced Studio back to Edit mode,
terminating the session mid-run. In the historical build, that could also leave the observed
90-second production-style lease active. Do not call it during a play session; drive the in-game
camera and read state through `execute_luau` instead.

### 5.5 Arrival spawn ambiguity in this place

Three `SpawnLocation` instances exist at runtime, and the captured state recorded **all three as
enabled**:

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

The historical observation exposed one later-confirmed safety defect: enabling Studio API access
could connect the Studio inventory path to production persistence. That defect is handled by the
follow-up Studio-only volatile-storage guard; it does not retroactively promote this observation
into acceptance evidence.

The `screen_capture` behavior in §5.4 remains an environment/tooling condition. The spawn-state
count in §5.5 is corrected to match the captured table: three present, three enabled.

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
- What this does establish: the client bootstrap did **not** stall in this observed build and the
  expected server owner set mounted, but the Studio persistence path required safety hardening
  before a future gameplay evidence run could be trusted not to touch production inventory.
- Required next action for a real acceptance run: use an exact artifact containing the
  Studio-isolated inventory adapter, prove artifact identity, characterize device/graphics
  profile, then exercise the applicable gameplay/evidence matrix.

## 9. Attachments

- Console output: inline in §5.
- Screenshots/video/profiler: none retained; see §5.4.

> This packet records bootstrap health observations only. It is not runtime acceptance for any
> milestone.
