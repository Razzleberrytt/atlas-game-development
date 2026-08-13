--!strict

--[[
	Patch 0.6 deterministic run-variation composition.

	This planner gives the already-independent room, secret, optional-objective,
	and run-modifier planners one stable read model for a server-owned run seed.
	It is descriptive only: it does not mutate room topology, start encounters,
	complete objectives, grant rewards, or apply encounter-intensity overrides.
]]

local SecretBranchResolver = require(script.Parent.SecretBranchResolver)
local OptionalObjectivePlanner = require(script.Parent.OptionalObjectivePlanner)
local RunModifierPlanner = require(script.Parent.RunModifierPlanner)

export type RunVariationPlan = {
	Seed: number,
	PlannerId: string,
	RoomPlanIdentity: string,
	SecretBranch: SecretBranchResolver.SecretBranchPlan?,
	OptionalObjective: OptionalObjectivePlanner.OptionalObjectivePlan?,
	RunModifier: RunModifierPlanner.RunModifierPlan?,
	VariationIdentity: string,
}

local PLANNER_ID = "patch0.6-run-variation-v1"

local RunVariationPlanner = {}

local function componentIdentity(component: any?): string
	if component == nil then
		return "none"
	end
	assert(type(component.PlanIdentity) == "string" and component.PlanIdentity ~= "", "component plan identity is required")
	return component.PlanIdentity
end

function RunVariationPlanner.plan(roomPlan: any): RunVariationPlan
	assert(type(roomPlan) == "table", "room plan is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0 and roomPlan.Seed > 0, "invalid room plan seed")
	assert(type(roomPlan.Nodes) == "table", "room plan nodes are required")
	assert(type(roomPlan.PlanIdentity) == "string" and roomPlan.PlanIdentity ~= "", "room plan identity is required")

	local secretBranch = SecretBranchResolver.plan(roomPlan)
	local optionalObjective = OptionalObjectivePlanner.plan(roomPlan)
	local runModifier = RunModifierPlanner.plan(roomPlan)

	local identity = `{PLANNER_ID}|seed={roomPlan.Seed}|room={roomPlan.PlanIdentity}|secret={componentIdentity(
		secretBranch
	)}|objective={componentIdentity(optionalObjective)}|modifier={componentIdentity(runModifier)}`

	return table.freeze({
		Seed = roomPlan.Seed,
		PlannerId = PLANNER_ID,
		RoomPlanIdentity = roomPlan.PlanIdentity,
		SecretBranch = secretBranch,
		OptionalObjective = optionalObjective,
		RunModifier = runModifier,
		VariationIdentity = identity,
	})
end

return table.freeze(RunVariationPlanner)
