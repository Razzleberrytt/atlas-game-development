# Expedition Lobby Authority Notes

The live lobby bridge accepts only three client actions: `Join`, `Leave`, and `SetReady`.

The invoking player's `UserId` is always used as the target identity. Clients cannot choose another player, supply a seed, supply a run ID, set party size directly, or invoke expedition completion. A launch occurs only after the server-owned lobby freezes an all-ready party and consumes that launch decision once.
