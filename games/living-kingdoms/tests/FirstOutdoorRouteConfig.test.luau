--!strict

-- BA-050 outdoor-route fixture: pin the authored landmark/slot sequence to
-- canonical world IDs and the First Descent entry while proving the recovered
-- 189-Part path remains held and no runtime consumer is activated.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-050 first outdoor route assertion failed", 2)
	end
end

local worldContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/World/WorldContentContracts.luau"), {
	debugName = "WorldContentContracts",
	injectGlobals = true,
})()

local WORLD_CONTRACTS_TOKEN = {}
local replicatedStorage = {
	Shared = {
		World = {
			WorldContentContracts = WORLD_CONTRACTS_TOKEN,
		},
	},
}
local worldConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/WorldContentConfig.luau"), {
	debugName = "WorldContentConfig",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "WorldContentConfig requested an unexpected Roblox service")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			assert(token == WORLD_CONTRACTS_TOKEN, "unexpected WorldContentConfig dependency")
			return worldContracts
		end,
	},
	injectGlobals = true,
})()

local recoveredPathConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RecoveredWorldPathConfig.luau"), {
		debugName = "RecoveredWorldPathConfig",
		injectGlobals = true,
	})()

local roomContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomAssemblyContracts.luau"), {
		debugName = "RoomAssemblyContracts",
		injectGlobals = true,
	})()

local enemyContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau"), {
	debugName = "EnemyContracts",
	injectGlobals = true,
})()

local hordeConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau"), {
	debugName = "HordeExperienceConfig",
	injectGlobals = true,
})()

local ROOM_CONTRACTS_TOKEN = {}
local roomConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RoomAssemblyConfig.luau"), {
	debugName = "RoomAssemblyConfig",
	environment = {
		script = { Parent = { Parent = { Expeditions = { RoomAssemblyContracts = ROOM_CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == ROOM_CONTRACTS_TOKEN, "unexpected RoomAssemblyConfig dependency")
			return roomContracts
		end,
	},
	injectGlobals = true,
})()

local ENEMY_CONTRACTS_TOKEN = {}
local HORDE_CONFIG_TOKEN = {}
local FIRST_ROOM_CONFIG_TOKEN = {}
local FIRST_ROOM_CONTRACTS_TOKEN = {}
local firstDungeon = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirstDungeonContentConfig.luau"), {
	debugName = "FirstDungeonContentConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					Combat = { EnemyContracts = ENEMY_CONTRACTS_TOKEN },
					Expeditions = { RoomAssemblyContracts = FIRST_ROOM_CONTRACTS_TOKEN },
				},
				HordeExperienceConfig = HORDE_CONFIG_TOKEN,
				RoomAssemblyConfig = FIRST_ROOM_CONFIG_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_TOKEN then
				return enemyContracts
			end
			if token == HORDE_CONFIG_TOKEN then
				return hordeConfig
			end
			if token == FIRST_ROOM_CONFIG_TOKEN then
				return roomConfig
			end
			if token == FIRST_ROOM_CONTRACTS_TOKEN then
				return roomContracts
			end
			error("unexpected FirstDungeonContentConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local WORLD_CONFIG_TOKEN = {}
local RECOVERED_PATH_TOKEN = {}
local FIRST_DUNGEON_TOKEN = {}
local route = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirstOutdoorRouteConfig.luau"), {
	debugName = "FirstOutdoorRouteConfig",
	environment = {
		script = {
			Parent = {
				WorldContentConfig = WORLD_CONFIG_TOKEN,
				RecoveredWorldPathConfig = RECOVERED_PATH_TOKEN,
				FirstDungeonContentConfig = FIRST_DUNGEON_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == WORLD_CONFIG_TOKEN then
				return worldConfig
			end
			if token == RECOVERED_PATH_TOKEN then
				return recoveredPathConfig
			end
			if token == FIRST_DUNGEON_TOKEN then
				return firstDungeon
			end
			error("unexpected FirstOutdoorRouteConfig dependency")
		end,
	},
	injectGlobals = true,
})()

assert(route.Version == "BA-050-v1", "route fixture version changed unexpectedly")
assert(route.RouteId == "outdoor-route.first-descent", "first outdoor route stable ID changed unexpectedly")
assert(route.RuntimeConsumptionActive == false, "BA-050 must remain data-only")
assert(route.WorldPathContentId == "route.world.primary", "route must preserve the canonical recovered path identity")
assert(recoveredPathConfig.SourceHold == true, "recovered WorldPath source hold must remain active")
assert(recoveredPathConfig.RuntimeEnabled == false, "recovered 189-Part WorldPath must remain runtime-disabled")
assert(worldConfig.ById[route.WorldPathContentId].active == false, "BA-050 must not activate held route geometry")

local expectedLandmarks = {
	"landmark.ranger_station",
	"landmark.logging_road",
	"landmark.lookout_tower",
	"landmark.campground",
	"landmark.creek_crossing",
	"landmark.rocky_overlook",
	"landmark.military_roadblock",
	"landmark.extraction_clearing",
}

local encounteredLandmarks = {}
local encounteredSet = {}
local encounterSlots = {}
local discoverySlots = {}
local handoff = nil

for index, routeStep in route.Steps do
	assert(routeStep.Order == index, "route order must stay contiguous")
	if routeStep.WorldContentId ~= nil then
		local descriptor = worldConfig.ById[routeStep.WorldContentId]
		assert(descriptor ~= nil, "route fixture references unknown world content")
		assert(descriptor.kind == "landmark", "route fixture traversal anchors must remain landmarks")
		assert(descriptor.active == true, "route fixture cannot depend on an inactive landmark")
		if encounteredSet[routeStep.WorldContentId] ~= true then
			encounteredSet[routeStep.WorldContentId] = true
			table.insert(encounteredLandmarks, routeStep.WorldContentId)
		end
	end
	if routeStep.Kind == route.StepKinds.EncounterSlot then
		table.insert(encounterSlots, routeStep.EncounterSlotId)
	elseif routeStep.Kind == route.StepKinds.DiscoverySlot then
		table.insert(discoverySlots, routeStep.DiscoverySlotId)
		assert(routeStep.Optional == true, "first route discovery slot must stay optional")
	elseif routeStep.Kind == route.StepKinds.DungeonHandoff then
		handoff = routeStep
	end
end

assert(#encounteredLandmarks == #expectedLandmarks, "authored route landmark count changed unexpectedly")
for index, landmarkId in expectedLandmarks do
	assert(encounteredLandmarks[index] == landmarkId, "authored route landmark order changed at index " .. index)
end

assert(#encounterSlots == 3, "BA-050 must expose three encounter slots for BA-051")
assert(encounterSlots[1] == route.EncounterSlotIds.LoggingRoad)
assert(encounterSlots[2] == route.EncounterSlotIds.Campground)
assert(encounterSlots[3] == route.EncounterSlotIds.MilitaryRoadblock)
assert(#discoverySlots == 1, "BA-050 must expose one optional discovery slot for BA-052")
assert(discoverySlots[1] == route.DiscoverySlotIds.LookoutTower)

assert(route.Steps[1].Kind == route.StepKinds.Entrance, "first route step must remain the Ranger Station entrance")
assert(route.Steps[1].WorldContentId == "landmark.ranger_station")
assert(handoff ~= nil, "first outdoor route requires one First Descent handoff")
assert(handoff == route.Steps[#route.Steps], "First Descent handoff must remain the final route step")
assert(
	handoff.DungeonSequenceId == firstDungeon.SequenceId,
	"outdoor route must hand off to the canonical dungeon sequence"
)
assert(handoff.DungeonEntryRoomId == "descent-entry", "outdoor route must enter First Descent at descent-entry")
assert(handoff.WorldContentId == nil, "dungeon handoff must not borrow the launch portal's world-content identity")

local routeSource = fs.readFile("games/living-kingdoms/src/shared/Config/FirstOutdoorRouteConfig.luau")
assert(string.find(routeSource, "Workspace/", 1, true) == nil, "BA-050 route data cannot contain raw Workspace paths")
assert(
	string.find(routeSource, 'WorldContentId ~= "portal.expedition.primary"', 1, true) ~= nil,
	"route module must guard against confusing launch presentation with dungeon handoff"
)

print("BA-050 FirstOutdoorRouteConfig fixture passed")
