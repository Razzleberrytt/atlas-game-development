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

local hubConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/HubPreparationConfig.luau"), {
	debugName = "HubPreparationConfig",
	injectGlobals = true,
})()

check(config.Version == "BA-012-v1-hub-interaction-content")
check(table.isfrozen(config))
check(table.isfrozen(config.Descriptors))
check(config.ById["world.operation.forest"].active == true)
check(config.ById["world.hub.primary"].active == false)
check(config.ById["zone.hub.forward_operations"].active == true)
check(config.ById["station.hub.class"].kind == "station")
check(config.ById["station.hub.weapon"].kind == "station")
check(config.ById["station.hub.operation_board"].active == false)
check(config.ById["vendor.hub.apothecary"].kind == "vendor")
check(config.ById["vendor.hub.merchant"].active == false)
check(config.ById["station.hub.crafting"].active == false)
check(config.ById["station.hub.social"].active == false)
check(config.ById["portal.expedition.primary"].kind == "portal")
check(config.LegacyAliases.HubTown == "world.hub.primary")
check(config.LegacyAliases.WorldPath == "route.world.primary")
check(config.LegacyAliases.Resources == "zone.resources.primary")
check(config.LegacyAliases.WorldStructures == "zone.structures.primary")
check(config.LegacyAliases.Buildings == "zone.structures.primary")
check(config.LegacyAliases.SpawnLocation == "spawn.main_world.arrival")
check(config.LegacyAliases.BootstrapSafetySpawn == "spawn.operation.insertion")
check(config.LegacyAliases.quest_board == "station.hub.operation_board")
check(config.LegacyAliases.apothecary == "vendor.hub.apothecary")
check(config.LegacyAliases.armor_smith == "vendor.hub.armor_smith")
check(config.LegacyAliases.weapon_smith == "vendor.hub.weapon_smith")
check(config.LegacyAliases.merchant == "vendor.hub.merchant")
check(config.LegacyAliases.DungeonPortal == "portal.expedition.primary")
check(config.ById["spawn.main_world.arrival"].active == false)
check(config.ById["spawn.main_world.return"].active == false)
check(config.LegacyAliases.RangerStation == "landmark.ranger_station")
check(config.LegacyAliases.ExtractionClearing == "landmark.extraction_clearing")

local seen = {}
for _, descriptor in config.Descriptors do
	local valid, reason = contracts.validateDescriptor(descriptor)
	check(valid, reason)
	check(not seen[descriptor.id], "duplicate content id: " .. descriptor.id)
	seen[descriptor.id] = true
end

check(hubConfig.Version == "HUB-SHELL-v1")
check(hubConfig.ZoneContentId == "zone.hub.forward_operations")
check(#hubConfig.Stations == 3)
local hubActions = {}
for _, station in hubConfig.Stations do
	check(config.ById[station.contentId] ~= nil, "hub station content ID must be registered")
	check(config.ById[station.contentId].active == true, "hub station content ID must be active")
	check(not hubActions[station.actionId], "duplicate hub action: " .. station.actionId)
	hubActions[station.actionId] = true
end
check(hubActions.OpenClass == true)
check(hubActions.OpenWeapon == true)
check(hubActions.OpenExpedition == true)
