# VS-0110 Expedition Playtest Matrix

Use the same seed for the 1-, 2-, and 4-player runs so route, encounter order, and room placement can be compared directly.

## Standard test seed

- Seed: `12345`
- Expected party sizes: `1`, `2`, and `4`
- Start from the Studio server command bar through `ServerStorage.ExpeditionControl`
- Record the exact commit SHA, Studio version, device type, and server/client output logs

## Start command

```lua
local control = game:GetService("ServerStorage"):WaitForChild("ExpeditionControl")
print(control:Invoke("Start", { Seed = 12345, PartySize = 1 }))
```

Change only `PartySize` for the two- and four-player runs.

## Required checks for every run

1. `Workspace.ExpeditionRooms` appears once and contains one model per planned room.
2. Every room is reachable through the generated bridges without jumping unintended gaps.
3. The HUD appears after start and displays the correct phase, objective, phase index, and party size.
4. Approach enemies spawn once and the phase does not advance until their exact authored IDs are defeated.
5. Traversal rooms advance without spawning combat enemies.
6. Combat rooms spawn their own bounded authored wave and ignore unrelated enemies.
7. The elite phase starts once and cannot be completed by a stale encounter token.
8. The existing boss starts once and the run advances only after authoritative boss defeat.
9. Rewards and Results phases are reached in order.
10. Results finalizes the run as `Completed` exactly once and the read-only debrief appears.
11. Stopping the run removes `Workspace.ExpeditionRooms` and hides expedition UI.
12. Starting another run with the same seed reproduces the same route.

## Party-specific checks

### Solo

- One player can complete every required interaction.
- No encounter assumes a second player exists.
- Enemy pressure is survivable with the default loadout.
- HUD remains legible at the minimum supported desktop and mobile resolutions.

### Two players

- Both clients receive the same phase/outcome revision.
- A late-joining second client receives the current snapshot through `ReadState`.
- Enemy completion is shared and does not require both clients to land damage.
- One disconnect does not duplicate rooms, encounters, or result presentation.

### Four players

- All four clients receive identical phase and result state.
- No duplicate authored enemy IDs appear.
- Room bridges and spawn positions do not trap or overlap the party.
- Capture server frame time, client frame time, memory, and network receive/send rates during the largest combat room and boss.

## Defect log

For each defect, record:

- ID: `EXP-###`
- Severity: blocker / high / medium / low
- Commit SHA
- Party size
- Seed
- Phase and room ID
- Exact reproduction steps
- Expected behavior
- Observed behavior
- Server log excerpt
- Client log excerpt
- Screenshot or video reference
- Reproduces on second attempt: yes / no
- Suspected owner module
- Fix commit and verification result

## Exit criteria

VS-0110 is not complete until:

- all three party-size runs are observed,
- no blocker or high-severity authority defect remains,
- the route is traversable for the fixed seed,
- the result debrief appears exactly once,
- persistence and duplicate reward checks have captured evidence,
- and repository formatting/lint/test/build checks have recorded results.
