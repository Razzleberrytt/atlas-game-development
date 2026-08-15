--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "procedural instance assertion failed", 2)
	end
end

local CONTRACTS_TOKEN = {}
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomAssemblyContracts.luau"), {
	debugName = "RoomAssemblyContracts",
	injectGlobals = true,
})()

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RoomAssemblyConfig.luau"), {
	debugName = "RoomAssemblyConfig",
	environment = {
		script = { Parent = { Parent = { Expeditions = { RoomAssemblyContracts = CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == CONTRACTS_TOKEN, "unexpected RoomAssemblyConfig dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local ASSEMBLER_CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local assembler = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomSequenceAssembler.luau"), {
	debugName = "RoomSequenceAssembler",
	environment = {
		script = {
			Parent = {
				RoomAssemblyContracts = ASSEMBLER_CONTRACTS_TOKEN,
				Parent = { Config = { RoomAssemblyConfig = CONFIG_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ASSEMBLER_CONTRACTS_TOKEN then
				return contracts
			end
			if token == CONFIG_TOKEN then
				return config
			end
			error("unexpected RoomSequenceAssembler dependency")
		end,
	},
	injectGlobals = true,
})()

local planner = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomPlacementPlanner.luau"), {
	debugName = "RoomPlacementPlanner",
	injectGlobals = true,
})()
local validator = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/InstanceLayoutValidator.luau"), {
	debugName = "InstanceLayoutValidator",
	injectGlobals = true,
})()

local ASSEMBLER_TOKEN = {}
local PLANNER_TOKEN = {}
local VALIDATOR_TOKEN = {}
local generator =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/ProceduralInstanceGenerator.luau"), {
		debugName = "ProceduralInstanceGenerator",
		environment = {
			script = {
				Parent = {
					RoomSequenceAssembler = ASSEMBLER_TOKEN,
					RoomPlacementPlanner = PLANNER_TOKEN,
					InstanceLayoutValidator = VALIDATOR_TOKEN,
				},
			},
			require = function(token: unknown)
				if token == ASSEMBLER_TOKEN then
					return assembler
				elseif token == PLANNER_TOKEN then
					return planner
				elseif token == VALIDATOR_TOKEN then
					return validator
				end
				error("unexpected ProceduralInstanceGenerator dependency")
			end,
		},
		injectGlobals = true,
	})()

local requestedLength = config.Route.MaximumVariableRooms
local first = generator.generate(42, { VariableRoomCount = requestedLength })
local replay = generator.generate(42, { VariableRoomCount = requestedLength })
local different = generator.generate(43, { VariableRoomCount = requestedLength })

assert(first.Accepted == true and replay.Accepted == true and different.Accepted == true)
assert(first.RoomCount == requestedLength + 3, "requested route length must be honored")
assert(first.RoomPlan.VariableRoomCount == requestedLength)
assert(first.ReproductionKey == replay.ReproductionKey, "same seed/options must reproduce the instance")
assert(first.ReproductionKey ~= different.ReproductionKey, "different seeds need distinct reproduction identities")
assert(first.Validation.Accepted == true)
assert(first.Rooms[1].RoleId == "Entry")
assert(first.Rooms[#first.Rooms].RoleId == "Boss")
assert(first.Rooms[1].SpawnPoints[1].Kind == "Player", "entry must expose a party spawn hook")
assert(first.Rooms[#first.Rooms].SpawnPoints[1].Kind == "Boss", "boss room must expose a boss spawn hook")

local occupied = {}
for index, room in first.Rooms do
	assert(room.SocketProfileId == "CardinalDoorway10-v1")
	assert(room.Index == index and room.Placement.Index == index)
	local grid = room.Placement.Grid
	local key = `{grid.x}:{grid.z}`
	assert(occupied[key] == nil, "generated rooms must not reuse grid cells")
	occupied[key] = true
	if room.EncounterSlotId ~= "None" then
		assert(#room.SpawnPoints > 0, "encounter rooms must expose spawn-point metadata")
	end
	if room.RewardSourceId ~= nil then
		assert(room.RewardSourceId == "Elite" or room.RewardSourceId == "Boss")
	end
end

local brokenConnectors = table.clone(first.Layout.Connectors)
local badConnector = table.clone(brokenConnectors[1])
badConnector.Axis = if badConnector.Axis == "X" then "Z" else "X"
brokenConnectors[1] = badConnector
local brokenLayout = table.clone(first.Layout)
brokenLayout.Connectors = brokenConnectors
local invalidConnection = validator.validate(first.RoomPlan, brokenLayout)
assert(invalidConnection.Accepted == false and invalidConnection.ReasonId == "ConnectorGeometryMismatch")

for seed = 1, 50 do
	local count = config.Route.MinimumVariableRooms
		+ (seed % (config.Route.MaximumVariableRooms - config.Route.MinimumVariableRooms + 1))
	local generated = generator.generate(seed, { VariableRoomCount = count })
	assert(generated.Accepted == true, `seed {seed} must generate without an unbounded retry loop`)
	assert(generated.RoomCount == count + 3)
	assert(generated.Debug.GenerationAttempt >= 1 and generated.Debug.GenerationAttempt <= 17)
end

local invalidLength = generator.generate(101, { VariableRoomCount = config.Route.MaximumVariableRooms + 1 })
assert(invalidLength.Accepted == false and invalidLength.ReasonId == "RoomAssemblyFailed")
assert(type(invalidLength.ReproductionKey) == "string")

local malformed = generator.generateFromRoomPlan({
	Seed = 9,
	Nodes = {
		{ Index = 2, RoomId = "bad-entry", Role = "Entry" },
		{ Index = 2, RoomId = "bad-boss", Role = "Boss" },
	},
})
assert(malformed.Accepted == false and malformed.ReasonId == "LayoutPlanningFailed")

local placementSource = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRoomPlacementService.luau")
assert(string.find(placementSource, "ProceduralInstanceGenerator.generateFromRoomPlan", 1, true) ~= nil)
assert(string.find(placementSource, "ExpeditionSpawnPoint", 1, true) ~= nil)
assert(string.find(placementSource, "activeGeneration = nil", 1, true) ~= nil)
assert(string.find(placementSource, "function Service.getGeneration()", 1, true) ~= nil)

print("ProceduralInstanceGenerator fixture passed")
