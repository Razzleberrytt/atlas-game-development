--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "Patch 0.6 run variation assertion failed", 2)
	end
end

local SECRET_TOKEN = {}
local OBJECTIVE_TOKEN = {}
local MODIFIER_TOKEN = {}

local receivedPlans = {}

local secretPlanner = {
	plan = function(roomPlan: any)
		receivedPlans.Secret = roomPlan
		if roomPlan.Seed % 2 == 0 then
			return nil
		end
		return table.freeze({ PlanIdentity = `secret|seed={roomPlan.Seed}`, SecretRoomId = "cache" })
	end,
}

local objectivePlanner = {
	plan = function(roomPlan: any)
		receivedPlans.Objective = roomPlan
		if roomPlan.Seed % 3 == 0 then
			return nil
		end
		return table.freeze({ PlanIdentity = `objective|seed={roomPlan.Seed}`, ObjectiveId = "salvage" })
	end,
}

local modifierPlanner = {
	plan = function(roomPlan: any)
		receivedPlans.Modifier = roomPlan
		if roomPlan.Seed % 5 == 0 then
			return nil
		end
		return table.freeze({ PlanIdentity = `modifier|seed={roomPlan.Seed}`, ModifierId = "dense-contacts" })
	end,
}

local planner = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RunVariationPlanner.luau"), {
	debugName = "RunVariationPlanner",
	environment = {
		script = {
			Parent = {
				SecretBranchResolver = SECRET_TOKEN,
				OptionalObjectivePlanner = OBJECTIVE_TOKEN,
				RunModifierPlanner = MODIFIER_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == SECRET_TOKEN then
				return secretPlanner
			elseif token == OBJECTIVE_TOKEN then
				return objectivePlanner
			elseif token == MODIFIER_TOKEN then
				return modifierPlanner
			end
			error("unexpected run variation planner dependency")
		end,
	},
	injectGlobals = true,
})()

local function makePlan(seed: number, identitySuffix: string?)
	return {
		Seed = seed,
		PlanIdentity = `room-plan|seed={seed}|variant={identitySuffix or "base"}`,
		Nodes = {
			{ Index = 1, RoomId = "entry", Role = "Entry" },
			{ Index = 2, RoomId = "combat", Role = "Combat" },
			{ Index = 3, RoomId = "boss", Role = "Boss" },
		},
	}
end

local roomPlan = makePlan(7)
local beforeNodeCount = #roomPlan.Nodes
local beforeFirstRoomId = roomPlan.Nodes[1].RoomId
local plan = planner.plan(roomPlan)

assert(plan.Seed == roomPlan.Seed, "variation plan must retain the server-owned seed")
assert(plan.PlannerId == "patch0.6-run-variation-v1", "variation plan must expose a stable planner id")
assert(plan.RoomPlanIdentity == roomPlan.PlanIdentity, "variation plan must bind to the exact room plan identity")
assert(plan.SecretBranch ~= nil and plan.SecretBranch.SecretRoomId == "cache", "secret plan must be composed")
assert(
	plan.OptionalObjective ~= nil and plan.OptionalObjective.ObjectiveId == "salvage",
	"optional objective plan must be composed"
)
assert(plan.RunModifier ~= nil and plan.RunModifier.ModifierId == "dense-contacts", "run modifier plan must be composed")
assert(receivedPlans.Secret == roomPlan, "secret planner must receive the canonical room plan")
assert(receivedPlans.Objective == roomPlan, "objective planner must receive the canonical room plan")
assert(receivedPlans.Modifier == roomPlan, "modifier planner must receive the canonical room plan")
assert(#roomPlan.Nodes == beforeNodeCount, "variation composition must not change room count")
assert(roomPlan.Nodes[1].RoomId == beforeFirstRoomId, "variation composition must not rewrite room data")

assert(string.find(plan.VariationIdentity, roomPlan.PlanIdentity, 1, true) ~= nil, "identity must include room identity")
assert(
	string.find(plan.VariationIdentity, plan.SecretBranch.PlanIdentity, 1, true) ~= nil,
	"identity must include secret identity"
)
assert(
	string.find(plan.VariationIdentity, plan.OptionalObjective.PlanIdentity, 1, true) ~= nil,
	"identity must include objective identity"
)
assert(
	string.find(plan.VariationIdentity, plan.RunModifier.PlanIdentity, 1, true) ~= nil,
	"identity must include modifier identity"
)

local repeated = planner.plan(makePlan(7))
assert(repeated.VariationIdentity == plan.VariationIdentity, "same seed and room identity must replay exactly")

local alternateRoomPlan = planner.plan(makePlan(7, "alternate"))
assert(
	alternateRoomPlan.VariationIdentity ~= plan.VariationIdentity,
	"same seed with a different room-plan identity must remain distinguishable"
)

local noSecret = planner.plan(makePlan(2))
assert(noSecret.SecretBranch == nil, "missing secret must remain explicitly absent")
assert(string.find(noSecret.VariationIdentity, "|secret=none|", 1, true) ~= nil, "identity must encode absent secret")

local noObjective = planner.plan(makePlan(3))
assert(noObjective.OptionalObjective == nil, "missing optional objective must remain explicitly absent")
assert(
	string.find(noObjective.VariationIdentity, "|objective=none|", 1, true) ~= nil,
	"identity must encode absent objective"
)

local noModifier = planner.plan(makePlan(5))
assert(noModifier.RunModifier == nil, "missing modifier must remain explicitly absent")
assert(
	string.find(noModifier.VariationIdentity, "|modifier=none", 1, true) ~= nil,
	"identity must encode absent modifier"
)

local ok = pcall(function()
	(plan :: any).Seed = 99
end)
assert(not ok, "variation plan must be immutable")

print("Patch 0.6 RunVariationPlanner fixture passed")
