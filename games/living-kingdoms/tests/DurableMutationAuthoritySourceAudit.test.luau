--!strict

--[[
	Patch 0.7 #93/#94. Two boundaries that hold today and would be easy to erode
	one convenient shortcut at a time.

	  1. Every durable mutation goes through one owner. A second module reaching
	     the storage adapter directly would write inventory outside the lease
	     that makes concurrent writes safe, and outside the size, replay, and
	     ledger guards that live in the persistence service.

	  2. A client names only an instance it already owns. Every durable value --
	     who owns the record, what an item is worth, which schema it is at -- is
	     derived server-side. A payload field that reached durable state would be
	     a player editing their own inventory.
]]

local fs = require("@lune/fs")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function read(path: string): string
	return fs.readFile(path)
end

-- 1. One durable owner -------------------------------------------------------

local SRC = "games/living-kingdoms/src"
local ADAPTER_CONSUMERS = { "games/living-kingdoms/src/server/Systems/InventoryLiveService.luau" }

local function listLuau(directory: string, into: { string })
	for _, entry in fs.readDir(directory) do
		local path = directory .. "/" .. entry
		if fs.isDir(path) then
			listLuau(path, into)
		elseif string.sub(entry, -5) == ".luau" then
			table.insert(into, path)
		end
	end
	return into
end

local sources = listLuau(SRC, {})
check(#sources > 100, "the audit must actually be scanning the source tree, found " .. tostring(#sources))

local function isAllowedAdapterConsumer(path: string): boolean
	for _, allowed in ADAPTER_CONSUMERS do
		if path == allowed then
			return true
		end
	end
	return false
end

for _, path in sources do
	local source = read(path)
	if string.find(source, "RobloxInventoryDataStoreAdapter", 1, true) ~= nil then
		check(
			isAllowedAdapterConsumer(path) or string.find(path, "RobloxInventoryDataStoreAdapter", 1, true) ~= nil,
			"only the canonical inventory owner may reach the storage adapter: " .. path
		)
	end
	--[[
		The durable key shape is the tell. A module building one is addressing
		storage directly rather than asking the owner for a record.
	]]
	if string.find(source, 'string.format("player:%d:inventory"', 1, true) ~= nil then
		check(
			string.find(path, "PlayerInventoryPersistenceService", 1, true) ~= nil,
			"only the persistence service may build durable inventory keys: " .. path
		)
	end
end

-- 2. No client-authored durable value ----------------------------------------

local network = read("games/living-kingdoms/src/server/inventory-network.server.luau")
local liveService = read("games/living-kingdoms/src/server/Systems/InventoryLiveService.luau")

--[[
	Owner identity comes from the invoking Player on every remote, never from a
	payload. readOwnInventory goes further and rejects the argument outright, so
	a client cannot even name itself.
]]
for _, call in
	{
		"InventoryLiveService.compareOwnedItem(player.UserId, player.UserId,",
		"InventoryLiveService.equipOwnedItem(player.UserId, player.UserId,",
		"InventoryLiveService.dismantleOwnedItem(player.UserId, player.UserId,",
	}
do
	check(string.find(network, call, 1, true) ~= nil, "owner identity must be derived from the Player: " .. call)
end
check(
	string.find(network, "if requestedOwnerId ~= nil then", 1, true) ~= nil,
	"a client must not be able to name an owner at all, even its own"
)
check(
	string.find(liveService, "if requesterId ~= ownerId then", 1, true) ~= nil,
	"the service must enforce the requester/owner match rather than trusting its callers"
)

--[[
	Durable value fields must never be read off a remote payload. The client
	names an instance id and a transaction id; everything else is server-derived.
]]
for _, field in { "SchemaVersion", "Power", "Rarity", "ContentSignature", "GrantId", "OwnerId", "PlayerId" } do
	check(
		string.find(network, "payload." .. field, 1, true) == nil,
		"a durable value must never be read from a client payload: " .. field
	)
	check(
		string.find(network, "request." .. field, 1, true) == nil,
		"a durable value must never be read from a client request: " .. field
	)
end

--[[
	The equip path is the sharpest case: the client names an instance, and the
	server resolves its slot from the durable record. A client-named slot would
	let a player equip a relic into a weapon slot.
]]
check(
	string.find(liveService, "persistence:equip(ownerId, item.Slot, instanceId, nowUnix)", 1, true) ~= nil,
	"the equipped slot must be resolved from the owned item, never named by the client"
)

check(not string.find(network, "FireAllClients", 1, true), "durable state must never be broadcast")

print("DurableMutationAuthoritySourceAudit: one durable owner, no client-authored durable value")
