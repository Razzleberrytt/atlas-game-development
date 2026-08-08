--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "world-content contract assertion failed", 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/World/WorldContentContracts.luau"), {
	debugName = "WorldContentContracts",
	injectGlobals = true,
})()

check(contracts.isValidId("world.operation.forest"))
check(contracts.isValidId("resource.iron_ore"))
check(not contracts.isValidId("World/Bad Id"))
check(not contracts.isValidId(""))

local contractsToken = {}
local replicatedStorage = {
	Shared = {
		World = {
			WorldContentContracts = contractsToken,
		},
	},
}

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/WorldContentConfig.luau"), {
	debugName = "WorldContentConfig",
	environment = {
		game = {
			GetService = function(_: unknown, serviceName: string)
				check(serviceName == "ReplicatedStorage")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			check(token == contractsToken, "unexpected WorldContentConfig dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

check(config.Version == "BA-004-v1")
check(table.isfrozen(config))
check(table.isfrozen(config.Descriptors))
check(config.ById["world.operation.forest"].active == true)
check(config.ById["world.hub.primary"].active == false)
check(config.LegacyAliases.HubTown == "world.hub.primary")
check(config.LegacyAliases.WorldPath == "route.world.primary")
check(config.LegacyAliases.Resources == "zone.resources.primary")
check(config.LegacyAliases.WorldStructures == "zone.structures.primary")
check(config.LegacyAliases.Buildings == "zone.structures.primary")
check(config.LegacyAliases.SpawnLocation == "spawn.operation.insertion")
check(config.LegacyAliases.RangerStation == "landmark.ranger_station")
check(config.LegacyAliases.ExtractionClearing == "landmark.extraction_clearing")

local seen = {}
for _, descriptor in config.Descriptors do
	local valid, reason = contracts.validateDescriptor(descriptor)
	check(valid, reason)
	check(not seen[descriptor.id], "duplicate content id: " .. descriptor.id)
	seen[descriptor.id] = true
end
