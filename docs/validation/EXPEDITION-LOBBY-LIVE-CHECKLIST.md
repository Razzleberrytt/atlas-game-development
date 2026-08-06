# Expedition Lobby Live Checklist

Use this checklist in Roblox Studio before claiming the live lobby path is validated.

## Solo

1. Start one server and one client.
2. Join the expedition lobby.
3. Toggle ready and unready.
4. Ready again.
5. Confirm exactly one expedition starts.
6. Confirm no client-supplied seed or run ID is accepted.

## Two players

1. Start one server and two clients.
2. Join in reverse UserId order.
3. Confirm the displayed roster is deterministic.
4. Ready one player and confirm no launch occurs.
5. Ready the second player and confirm one launch occurs with party size 2.
6. Confirm leaving before all-ready removes the player and clears launch readiness.

## Four players

1. Join four clients and confirm the lobby reaches capacity.
2. Attempt a fifth join and confirm `LobbyFull`.
3. Ready all four and confirm one launch occurs with party size 4.
4. Confirm duplicate ready requests do not start a second expedition.

## Failure cases

- Start an expedition through the server control path while the lobby is preparing, then ready the lobby. Confirm launch rejection is surfaced and readiness resets.
- Disconnect one lobby member before launch. Confirm the roster updates.
- Disconnect a member after launch. Confirm the expedition remains server-authoritative.

## Evidence

Record server output, client screenshots, party size, run ID, and any defect as `EXP-###` in the validation log.
