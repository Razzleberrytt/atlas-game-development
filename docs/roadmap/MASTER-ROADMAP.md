# Living Kingdoms — Master Roadmap

## Status legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked

## Milestone M0 — Repository and Roblox foundation

- [x] **LK-0001** Create the Rojo-compatible Roblox project scaffold.
- [x] **LK-0002** Add `default.project.json` mappings for client, server, and shared source.
- [x] **LK-0003** Add minimal client and server bootstrap scripts.
- [x] **LK-0004** Document local setup for Roblox Studio, Rojo, and the repository.
- [x] **LK-0005** Add formatting and static-analysis configuration selected for the toolchain.
- [x] **LK-0006** Verify a local Rojo build produces a valid place file or synchronized Studio tree.
- [x] **LK-0007** Add a smoke-test checklist and record the first successful launch.

### M0 exit criteria

The repository can be cloned, synchronized or built, launched in Roblox Studio, and tested without undocumented setup knowledge.

## Milestone M1 — Overhead camera

- [ ] **LK-0010** Create `CameraController` with an explicit public lifecycle.
- [ ] **LK-0011** Switch the local camera to a fixed overhead strategy view.
- [ ] **LK-0012** Add keyboard camera panning.
- [ ] **LK-0013** Add mouse-wheel zoom.
- [ ] **LK-0014** Add configurable camera bounds.
- [ ] **LK-0015** Add smoothing without making input feel delayed.
- [ ] **LK-0016** Add initial touch pan and pinch-zoom design notes.
- [ ] **LK-0017** Run and record the camera manual test suite.

### M1 exit criteria

A desktop player can comfortably inspect the gray-box map without controlling a Roblox avatar.

## Milestone M2 — Selection

- [ ] **LK-0020** Define the selectable-unit interface and ownership attributes.
- [ ] **LK-0021** Spawn five gray-box Worker models for local testing.
- [ ] **LK-0022** Add single-click selection.
- [ ] **LK-0023** Add deselection by clicking empty terrain.
- [ ] **LK-0024** Add visible selection indicators.
- [ ] **LK-0025** Add drag-box selection.
- [ ] **LK-0026** Add Shift-based additive and subtractive selection.
- [ ] **LK-0027** Prevent selection of enemy or unowned units.
- [ ] **LK-0028** Define the initial touch-selection behavior.
- [ ] **LK-0029** Run and record selection regression tests.

### M2 exit criteria

The player can reliably select one or several owned Workers and clearly see the current selection.

## Milestone M3 — Commanded movement

- [ ] **LK-0030** Define the move-command request contract.
- [ ] **LK-0031** Validate unit ownership and destination requests on the server.
- [ ] **LK-0032** Move one selected Worker to a terrain destination.
- [ ] **LK-0033** Move several selected Workers in one command.
- [ ] **LK-0034** Add simple destination spacing so units do not stack exactly.
- [ ] **LK-0035** Add command feedback at the clicked destination.
- [ ] **LK-0036** Handle unreachable or invalid destinations safely.
- [ ] **LK-0037** Cancel or replace an active movement command.
- [ ] **LK-0038** Measure behavior with 25 simultaneously moving units.
- [ ] **LK-0039** Complete the first vertical-slice playtest.

### M3 exit criteria

The player can select five Workers and command them around the map with responsive, predictable behavior.

## Milestone M4 — Wood economy

- [ ] **LK-0040** Specify Wood and Tree resource-node behavior.
- [ ] **LK-0041** Add data-driven Tree configuration.
- [ ] **LK-0042** Implement tree selection and contextual gather commands.
- [ ] **LK-0043** Move Workers into harvest range.
- [ ] **LK-0044** Implement timed wood harvesting.
- [ ] **LK-0045** Add Worker carry capacity.
- [ ] **LK-0046** Return carrying Workers to the Town Hall.
- [ ] **LK-0047** Deposit Wood using server-owned balances.
- [ ] **LK-0048** Add the Wood counter UI.
- [ ] **LK-0049** Handle depleted trees and interrupted gathering.

## Milestone M5 — Construction and production

- [ ] **LK-0050** Specify Town Hall and Barracks behavior.
- [ ] **LK-0051** Add Barracks placement preview.
- [ ] **LK-0052** Validate placement and Wood cost on the server.
- [ ] **LK-0053** Create construction progress and completion states.
- [ ] **LK-0054** Add Barracks selection UI.
- [ ] **LK-0055** Specify Swordsman configuration.
- [ ] **LK-0056** Add a server-authoritative training queue.
- [ ] **LK-0057** Spawn trained Swordsmen at a valid rally location.
- [ ] **LK-0058** Handle blocked spawns and queue cancellation.
- [ ] **LK-0059** Complete the economy-to-army loop playtest.

## Milestone M6 — Combat and match completion

- [ ] **LK-0060** Define Health, Damage, Attack, and Death contracts.
- [ ] **LK-0061** Add attack commands against valid enemy targets.
- [ ] **LK-0062** Implement Swordsman melee range and cooldown.
- [ ] **LK-0063** Apply server-authoritative damage.
- [ ] **LK-0064** Handle death and cleanup.
- [ ] **LK-0065** Add basic enemy defenders.
- [ ] **LK-0066** Add minimal enemy attack behavior.
- [ ] **LK-0067** Detect destruction of the enemy Town Hall.
- [ ] **LK-0068** Add victory and defeat states.
- [ ] **LK-0069** Complete an end-to-end match without developer intervention.

## Backlog policy

New ideas go into `BACKLOG.md`; they do not interrupt the active milestone unless they expose a blocker, security problem, data-loss risk, or fundamental architectural flaw.
