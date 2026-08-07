--!strict

--[[
	Blueprint v2.0 queue item 1 — structural audit of the inventory disclosure
	boundary. Runtime behavior is covered by PlayerInventorySnapshot.test; these
	assertions guard the shape of the client-facing surface, which cannot be
	exercised outside Studio.
]]

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

local network = fs.readFile("games/living-kingdoms/src/server/inventory-network.server.luau")
local liveService = fs.readFile("games/living-kingdoms/src/server/Systems/InventoryLiveService.luau")

-- Ownership is derived from the connection, never from a payload.
assert(contains(network, "player.UserId"), "the boundary must derive ownership from the invoking player")
assert(
	contains(network, 'return rejected("CrossPlayerInventoryAccess")'),
	"a client-supplied owner identity must be rejected outright"
)
assert(contains(network, "readOwnedSnapshot"), "the boundary must read through the owner-only service method")

-- Inventory truth must never be broadcast. FireAllClients would fan one
-- player's inventory to the whole server.
assert(not contains(network, "FireAllClients"), "inventory state must never be broadcast to every client")
assert(contains(network, "FireClient"), "inventory pushes must be addressed to a single owner")

-- The raw record carries replay ledgers and must not be reachable from a remote.
assert(not contains(network, "getRecord"), "the remote boundary must not read raw persistence records")
assert(not contains(network, "applyReward"), "the read boundary must expose no mutation path")

-- Comparison names a candidate by instance id only. Accepting item values would
-- let a client have the server evaluate an item it does not own.
assert(contains(network, "compareOwnedItem"), "the comparison boundary must exist")
assert(contains(network, 'type(candidateInstanceId) ~= "string"'), "the candidate must be an instance id")
assert(not contains(network, "Power ="), "clients must not submit item power")
assert(not contains(network, "Rarity ="), "clients must not submit item rarity")
assert(contains(liveService, "ItemNotOwned"), "the service must reject a candidate the owner does not hold")

-- The service performs the ownership check through the shared pure boundary
-- rather than re-implementing it.
assert(contains(liveService, "PlayerInventorySnapshot.forOwner"), "the service must use the shared owner-only boundary")
assert(contains(liveService, "requesterId"), "the service must take an explicit requester identity")

--[[
	Rojo maps `src/server` to `ServerScriptService.Server`, so `Systems` is a
	sibling of each server script. `ServerScriptService:WaitForChild("Systems")`
	resolves nothing and yields forever, silently disabling the script.
]]
for _, entry in fs.readDir("games/living-kingdoms/src/server") do
	if string.match(entry, "%.server%.luau$") ~= nil or entry == "init.server.luau" then
		local source = fs.readFile("games/living-kingdoms/src/server/" .. entry)
		assert(
			not contains(source, 'ServerScriptService:WaitForChild("Systems")'),
			entry .. " must resolve Systems as a sibling; ServerScriptService has no direct Systems child"
		)
	end
end

print("InventoryOwnershipBoundarySourceAudit.test.luau passed")
