--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/server/inventory-network.server.luau")

local function contains(needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

assert(contains("local LEASE_RENEW_INTERVAL_SECONDS = 30"), "inventory lease renewal cadence must remain explicit")
assert(
	contains("InventoryLiveService.loadPlayer(player.UserId, os.time())"),
	"connected players must acquire/load durable inventory"
)
assert(contains("Players.PlayerAdded:Connect"), "future joins must enter the inventory lifecycle")
assert(contains("for _, player in Players:GetPlayers() do"), "players already present at mount must also load")
assert(
	contains("InventoryLiveService.renewPlayer(player.UserId, nowUnix)"),
	"live inventory leases must renew during long runs"
)
assert(
	contains("InventoryLiveService.releasePlayer(player.UserId)"),
	"disconnect must release the player's inventory lease"
)
assert(contains("InventoryLiveService.destroy()"), "shutdown must release all remaining inventory leases")
assert(contains("if loaded.Accepted ~= true then"), "snapshot disclosure must fail closed when inventory load fails")
assert(contains("loadedPlayerIds[player.UserId] = true"), "only successfully loaded players may enter renewal tracking")

assert(not contains("FireAllClients"), "owner inventory state must never be broadcast")
assert(not contains("requestedOwnerId: number"), "client payload must not gain an owner identity field")

print("InventoryLiveLifecycleSourceAudit: join load, lease renewal, leave release, and owner-only disclosure passed")
