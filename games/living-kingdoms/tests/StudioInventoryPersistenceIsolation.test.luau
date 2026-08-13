--!strict

--[[
	Studio must never reach production inventory storage, even with Studio Access
	to API Services enabled: an evidence or playtest session must not acquire
	production leases or mutate/migrate live records.

	This used to pin the adapter's exact `return createVolatileStore(), true`
	spelling. Store selection has since moved into
	InventoryDataStoreResolutionPolicy, so the guarantee is now checked by
	running that policy rather than by matching the line that used to implement
	it -- including the part that matters most, that the production opener is
	never so much as called in Studio.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "StudioInventoryPersistenceIsolation assertion failed", 2)
	end
end

local adapterPath = "games/living-kingdoms/src/server/Systems/RobloxInventoryDataStoreAdapter.luau"
local liveServicePath = "games/living-kingdoms/src/server/Systems/InventoryLiveService.luau"
local adapterSource = fs.readFile(adapterPath)
local liveServiceSource = fs.readFile(liveServicePath)

local policy =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/InventoryDataStoreResolutionPolicy.luau"), {
		debugName = "InventoryDataStoreResolutionPolicy",
		injectGlobals = true,
	})()

-- The guarantee, exercised rather than pattern-matched.

local productionOpenerCalls = 0
local function productionOpener(): any
	productionOpenerCalls += 1
	return { Name = "ProductionDataStore" }
end

local studio = policy.resolve(true, productionOpener)
check(studio.Mode == "StudioVolatile", "Studio must resolve to volatile storage")
check(productionOpenerCalls == 0, "Studio must never open the production DataStore, not even to discard it")
check(type(studio.Store) == "table", "Studio must still receive a usable store")

studio.Store:UpdateAsync("probe", function()
	return { Marker = "studio" }
end)
check(studio.Store:GetAsync("probe").Marker == "studio", "the Studio store must be writable in-session")

local second = policy.resolve(true, productionOpener)
check(
	second.Store:GetAsync("probe") == nil,
	"each Studio resolution must start empty; nothing may persist between them"
)

local live = policy.resolve(false, productionOpener)
check(live.Mode == "LiveDurable", "a live server must resolve to the durable store")
check(productionOpenerCalls == 1, "a live server must open the production DataStore exactly once")
check(live.Store.Name == "ProductionDataStore", "a live server must receive the production store itself")

--[[
	A live server whose store cannot be opened must fail closed. Falling soft to
	volatile storage would let a published server run an entire session on
	progress that silently evaporates.
]]
local unavailable = policy.resolve(false, function(): any
	error("simulated GetDataStore failure")
end)
check(unavailable.Mode == "LiveUnavailable", "an unopenable live store must be reported, not substituted")
check(not pcall(function()
	unavailable.Store:GetAsync("probe")
end), "an unavailable live store must refuse reads rather than answer with fiction")
check(not pcall(function()
	unavailable.Store:UpdateAsync("probe", function()
		return {}
	end)
end), "an unavailable live store must refuse writes")

-- The adapter must consume that policy rather than re-deriving the decision.
local studioCheckStart = string.find(adapterSource, "RunService:IsStudio()", 1, true)
local productionStoreAccessStart = string.find(adapterSource, "DataStoreService:GetDataStore(dataStoreName)", 1, true)

check(studioCheckStart ~= nil, "inventory adapter must explicitly detect Studio")
check(productionStoreAccessStart ~= nil, "inventory adapter must retain production DataStore access")
check(
	(studioCheckStart :: number) < (productionStoreAccessStart :: number),
	"Studio isolation must be evaluated before production DataStore access"
)
check(
	string.find(adapterSource, "ResolutionPolicy.resolve(RunService:IsStudio()", 1, true) ~= nil,
	"the adapter must delegate store selection to the canonical resolution policy"
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

print("StudioInventoryPersistenceIsolation: Studio volatile, live durable, unavailable fails closed")
