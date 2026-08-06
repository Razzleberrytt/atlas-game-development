--!strict

-- VS-0104 deterministic room-plan fixture: reproducibility, bounded variation,
-- role guarantees, unique handcrafted rooms, and entry-to-boss connectivity.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "VS-0104 room sequence assertion failed", 2)
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

local function signature(plan: any): string
	local ids = {}
	for _, node in plan.Nodes do
		table.insert(ids, node.RoomId)
	end
	return table.concat(ids, ">")
end

local function validatePlan(plan: any)
	local minimumNodes = config.Route.MinimumVariableRooms + 3
	local maximumNodes = config.Route.MaximumVariableRooms + 3
	assert(#plan.Nodes >= minimumNodes and #plan.Nodes <= maximumNodes, "plan length is outside bounded route size")
	assert(plan.EntryIndex == 1, "entry must be first")
	assert(plan.EliteIndex == #plan.Nodes - 1, "elite must immediately precede boss")
	assert(plan.BossIndex == #plan.Nodes, "boss must be terminal")
	assert(plan.Nodes[1].Role == contracts.RoleIds.Entry, "first node must be entry")
	assert(plan.Nodes[plan.EliteIndex].Role == contracts.RoleIds.Elite, "elite role missing")
	assert(plan.Nodes[plan.BossIndex].Role == contracts.RoleIds.Boss, "boss role missing")

	local combatCount = 0
	local seenIds = {}
	for index, node in plan.Nodes do
		assert(node.Index == index, "node indexes must be contiguous")
		assert(node.Depth == index - 1, "node depth must match linear position")
		assert(node.PreviousIndex == (if index > 1 then index - 1 else nil), "previous link is invalid")
		assert(node.NextIndex == (if index < #plan.Nodes then index + 1 else nil), "next link is invalid")
		assert(seenIds[node.RoomId] == nil, "non-repeatable room was selected twice")
		seenIds[node.RoomId] = true
		if node.Role == contracts.RoleIds.Combat then
			combatCount += 1
		end
	end
	assert(combatCount == config.Route.RequiredCombatRooms, "plan must include required combat count")
end

local first = assembler.assemble(12_345)
local repeated = assembler.assemble(12_345)
validatePlan(first)
validatePlan(repeated)
assert(signature(first) == signature(repeated), "same seed must produce the same room plan")

local signatures = {}
for seed = 1, 30 do
	local plan = assembler.assemble(seed)
	validatePlan(plan)
	signatures[signature(plan)] = true
end

local variationCount = 0
for _ in signatures do
	variationCount += 1
end
assert(variationCount >= 4, "seed range should produce multiple valid routes")

local okZero = pcall(function()
	assembler.assemble(0)
end)
assert(not okZero, "zero seed must be rejected")

local okFraction = pcall(function()
	assembler.assemble(1.5)
end)
assert(not okFraction, "fractional seed must be rejected")

print("VS-0104 RoomSequenceAssembler fixture passed")
