--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local ASSEMBLER_TOKEN = {}
local PLANNER_TOKEN = {}
local VALIDATOR_TOKEN = {}

local contracts = require("../src/shared/Expeditions/RoomAssemblyContracts")
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

local assembler = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomSequenceAssembler.luau"), {
	debugName = "RoomSequenceAssembler",
	environment = {
		script = {
			Parent = {
				RoomAssemblyContracts = CONTRACTS_TOKEN,
				Parent = { Config = { RoomAssemblyConfig = CONFIG_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == CONFIG_TOKEN then
				return config
			end
			error("unexpected RoomSequenceAssembler dependency")
		end,
	},
	injectGlobals = true,
})()

local planner = require("../src/shared/Expeditions/RoomPlacementPlanner")
local validator = require("../src/shared/Expeditions/InstanceLayoutValidator")
local generator = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/ProceduralInstanceGenerator.luau"), {
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

local function layoutSignature(layout: any): string
	local values = {}
	for _, placement in layout.Placements do
		table.insert(values, `{placement.RoomId}@{placement.GridCell.x}:{placement.GridCell.z}:{placement.TurnId}`)
	end
	return table.concat(values, "|")
end

local first = generator.generate(777)
local repeated = generator.generate(777)
assert(first.Accepted and repeated.Accepted, "valid current assembler seed must generate")
assert(first.ReasonId == "ProceduralInstanceGenerated")
assert(first.Validation.Accepted and first.Validation.ReasonId == "LayoutValid")
assert(
	first.RoomPlan.PlanIdentity == repeated.RoomPlan.PlanIdentity,
	"same seed must preserve canonical content identity"
)
assert(layoutSignature(first.Layout) == layoutSignature(repeated.Layout), "same seed must reproduce spatial layout")

local different = generator.generate(778)
assert(different.Accepted, "second valid seed must generate")
assert(
	different.RoomPlan.PlanIdentity ~= first.RoomPlan.PlanIdentity
		or layoutSignature(different.Layout) ~= layoutSignature(first.Layout),
	"different seeds must change canonical content or spatial route"
)

for index, placement in first.Layout.Placements do
	assert(placement.Index == first.RoomPlan.Nodes[index].Index)
	assert(placement.RoomId == first.RoomPlan.Nodes[index].RoomId)
	assert(placement.RoleId == first.RoomPlan.Nodes[index].Role)
end

local malformedPlan = generator.generateFromRoomPlan({ Seed = 777, Nodes = { { Index = 1 } } })
assert(not malformedPlan.Accepted and malformedPlan.ReasonId == "InvalidRoomPlan")

local invalidSeed = generator.generate(0)
assert(not invalidSeed.Accepted and invalidSeed.ReasonId == "RoomAssemblyRejected")

local fractionalSeed = generator.generate(1.5)
assert(not fractionalSeed.Accepted and fractionalSeed.ReasonId == "RoomAssemblyRejected")

print("ProceduralInstanceGenerator: current assembler -> planner -> validator orchestration passed")
