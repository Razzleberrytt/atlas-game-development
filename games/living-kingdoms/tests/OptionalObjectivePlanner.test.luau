--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "Patch 0.6 optional objective assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/OptionalObjectiveConfig.luau"), {
	debugName = "OptionalObjectiveConfig",
	injectGlobals = true,
})()

local CONFIG_TOKEN = {}
local planner = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/OptionalObjectivePlanner.luau"), {
	debugName = "OptionalObjectivePlanner",
	environment = {
		script = { Parent = { Parent = { Config = { OptionalObjectiveConfig = CONFIG_TOKEN } } } },
		require = function(token: unknown)
			assert(token == CONFIG_TOKEN, "unexpected optional objective planner dependency")
			return config
		end,
	},
	injectGlobals = true,
})()

local function makePlan(seed: number)
	return {
		Seed = seed,
		Nodes = {
			{ Index = 1, Depth = 0, RoomId = "entry", Role = "Entry", PreviousIndex = nil, NextIndex = 2 },
			{ Index = 2, Depth = 1, RoomId = "early", Role = "Traversal", PreviousIndex = 1, NextIndex = 3 },
			{ Index = 3, Depth = 2, RoomId = "crossing", Role = "Traversal", PreviousIndex = 2, NextIndex = 4 },
			{ Index = 4, Depth = 3, RoomId = "ambush", Role = "Combat", PreviousIndex = 3, NextIndex = 5 },
			{ Index = 5, Depth = 4, RoomId = "switchback", Role = "Traversal", PreviousIndex = 4, NextIndex = 6 },
			{ Index = 6, Depth = 6, RoomId = "elite", Role = "Elite", PreviousIndex = 5, NextIndex = 7 },
			{ Index = 7, Depth = 7, RoomId = "boss", Role = "Boss", PreviousIndex = 6, NextIndex = nil },
		},
	}
end

local definitionById = {}
for _, objective in config.Objectives do
	definitionById[objective.Id] = objective
end

local selected = nil
local selectedSeed = nil
for seed = 1, 500 do
	local candidate = planner.plan(makePlan(seed))
	if candidate ~= nil then
		selected = candidate
		selectedSeed = seed
		break
	end
end
assert(selected ~= nil and selectedSeed ~= nil, "fixture requires at least one optional-objective seed")

local repeated = planner.plan(makePlan(selectedSeed :: number))
assert(repeated ~= nil, "same seed should reproduce an optional objective")
assert(repeated.PlanIdentity == selected.PlanIdentity, "same seed must reproduce objective identity")
assert(repeated.ObjectiveId == selected.ObjectiveId, "same seed must reproduce objective")
assert(repeated.HostIndex == selected.HostIndex, "same seed must reproduce objective host")
assert(selected.ConfigVersion == config.Version, "objective plan must record config version")
assert(
	string.find(selected.PlanIdentity, `seed={selected.Seed}`, 1, true) ~= nil,
	"objective identity must record the run seed"
)

local definition = definitionById[selected.ObjectiveId]
assert(definition ~= nil, "planned objective must exist in config")
local selectedHost = makePlan(selectedSeed :: number).Nodes[selected.HostIndex]
assert(selectedHost.RoomId == selected.HostRoomId, "objective host identity must be stable")
assert(definition.EligibleHostRoles[selectedHost.Role] == true, "objective must use an eligible host role")
assert(
	selectedHost.Depth >= config.MinimumHostDepth and selectedHost.Depth <= config.MaximumHostDepth,
	"objective host must stay inside bounded depth"
)

local original = makePlan(selectedSeed :: number)
local beforeLinks = {}
for _, node in original.Nodes do
	beforeLinks[node.Index] = { node.PreviousIndex, node.NextIndex }
end
planner.plan(original)
for _, node in original.Nodes do
	assert(node.PreviousIndex == beforeLinks[node.Index][1], "objective planning must not rewrite previous links")
	assert(node.NextIndex == beforeLinks[node.Index][2], "objective planning must not rewrite next links")
end

local seenObjectiveIds = {}
local sawNoObjective = false
for seed = 1, 1000 do
	local plan = planner.plan(makePlan(seed))
	if plan == nil then
		sawNoObjective = true
	else
		seenObjectiveIds[plan.ObjectiveId] = true
		assert(plan.RequiredProgress >= 1 and plan.RequiredProgress <= 5, "objective progress target must stay bounded")
	end
end
assert(sawNoObjective, "appearance chance must preserve runs with no optional objective")
for _, objective in config.Objectives do
	assert(seenObjectiveIds[objective.Id] == true, "bounded seed range must exercise every curated objective")
end

print("Patch 0.6 OptionalObjectivePlanner fixture passed")
