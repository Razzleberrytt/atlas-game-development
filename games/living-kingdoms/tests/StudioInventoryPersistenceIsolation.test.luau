--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "StudioInventoryPersistenceIsolation assertion failed", 2)
	end
end

local adapterPath = "games/living-kingdoms/src/server/Systems/RobloxInventoryDataStoreAdapter.luau"
local liveServicePath = "games/living-kingdoms/src/server/Systems/InventoryLiveService.luau"
local adapterSource = fs.readFile(adapterPath)
local liveServiceSource = fs.readFile(liveServicePath)

local studioCheckStart = string.find(adapterSource, "RunService:IsStudio()", 1, true)
local productionStoreAccessStart = string.find(adapterSource, "DataStoreService:GetDataStore(dataStoreName)", 1, true)

check(studioCheckStart ~= nil, "inventory adapter must explicitly detect Studio")
check(productionStoreAccessStart ~= nil, "inventory adapter must retain production DataStore access")
check(
	studioCheckStart < productionStoreAccessStart,
	"Studio isolation must be evaluated before production DataStore access"
)
check(
	string.find(adapterSource, "return createVolatileStore(), true", studioCheckStart, true) ~= nil,
	"Studio path must return volatile storage"
)
check(
	string.find(adapterSource, "Studio session detected; using volatile in-memory storage", 1, true) ~= nil,
	"Studio isolation should be explicit in operator diagnostics"
)

-- Production owner/configuration stays unchanged. The safety boundary belongs in
-- the adapter, so live servers continue to use the established store/namespace
-- while Studio cannot reach it even when API access is enabled.
check(string.find(liveServiceSource, 'DataStoreName = "AtlasPlayerInventoryV1"', 1, true) ~= nil)
check(string.find(liveServiceSource, 'KeyPrefix = "atlas-prod"', 1, true) ~= nil)
