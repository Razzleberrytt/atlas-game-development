--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-052 outdoor discovery assertion failed", 2)
	end
end

local runRpgContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()

local routeConfig = {
	RouteId = "outdoor-route.first-descent",
	RuntimeConsumptionActive = false,
	DiscoverySlotIds = {
		LookoutTower = "discovery-slot.outdoor.first-descent.lookout-tower",
	},
}
local worldConfig = {
	ById = {
		["landmark.lookout_tower"] = {
			kind = "landmark",
			active = true,
		},
	},
}

local ROUTE_TOKEN = {}
local WORLD_TOKEN = {}
local RPG_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirstOutdoorDiscoveryConfig.luau"), {
	debugName = "FirstOutdoorDiscoveryConfig",
	environment = {
		script = {
			Parent = {
				FirstOutdoorRouteConfig = ROUTE_TOKEN,
				WorldContentConfig = WORLD_TOKEN,
				Parent = { RPG = { RunRpgContracts = RPG_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ROUTE_TOKEN then
				return routeConfig
			end
			if token == WORLD_TOKEN then
				return worldConfig
			end
			if token == RPG_TOKEN then
				return runRpgContracts
			end
			error("unexpected FirstOutdoorDiscoveryConfig dependency")
		end,
	},
	injectGlobals = true,
})()

assert(config.Version == "BA-052-v1")
assert(config.RuntimeConsumptionActive == false)
assert(#config.Discoveries == 1)

local discovery = config.Discoveries[1]
assert(discovery.Id == "discovery.first-descent.lookout-cache")
assert(discovery.RouteId == routeConfig.RouteId)
assert(discovery.DiscoverySlotId == routeConfig.DiscoverySlotIds.LookoutTower)
assert(discovery.AnchorWorldContentId == "landmark.lookout_tower")
assert(discovery.StreamingIdentityId == "streaming.discovery.first-descent.lookout-cache")
assert(discovery.GameplayMeaningId == "OptionalVantageCache")
assert(discovery.PresentationIntentId == "ReadableOptionalDetour")
assert(discovery.Optional == true)
assert(discovery.RewardSourceId == runRpgContracts.RewardSourceIds.AuthoredContainer)
assert(config.ById[discovery.Id] == discovery)

local source = fs.readFile("games/living-kingdoms/src/shared/Config/FirstOutdoorDiscoveryConfig.luau")
assert(string.find(source, "Workspace/", 1, true) == nil, "discovery definition cannot contain raw Workspace paths")
assert(string.find(source, "DataStore", 1, true) == nil, "discovery definition cannot own persistence")
assert(string.find(source, "FireServer", 1, true) == nil, "discovery definition cannot own networking")

print("BA-052 FirstOutdoorDiscoveryConfig fixture passed")
