--!strict

--[[
	Patch 0.6 deterministic optional-objective planner.

	This planner derives at most one authored objective placement from the same
	server-owned room-plan seed. It is descriptive only: it does not mutate room
	links, spawn content, grant rewards, or own objective completion at runtime.
]]

local Config = require(script.Parent.Parent.Config.OptionalObjectiveConfig)

export type OptionalObjectivePlan = {
	Seed: number,
	ConfigVersion: string,
	PlanIdentity: string,
	ObjectiveId: string,
	ObjectiveVersion: string,
	ObjectiveType: string,
	RequiredProgress: number,
	HostIndex: number,
	HostRoomId: string,
}

local OptionalObjectivePlanner = {}

local function nextValue(value: number): number
	return (value * 48_271) % 2_147_483_647
end

local function eligible(objective: any, node: any): boolean
	return objective.EligibleHostRoles[node.Role] == true
		and node.Depth >= Config.MinimumHostDepth
		and node.Depth <= Config.MaximumHostDepth
end

function OptionalObjectivePlanner.plan(roomPlan: any): OptionalObjectivePlan?
	assert(type(roomPlan) == "table", "room plan is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0 and roomPlan.Seed > 0, "invalid room plan seed")
	assert(type(roomPlan.Nodes) == "table", "room plan nodes are required")

	-- SecretBranchResolver consumes the first three LCG values. Advancing four
	-- times gives optional objectives their own deterministic stream position
	-- while preserving one shared server-owned run seed.
	local rollState = roomPlan.Seed
	for _ = 1, 4 do
		rollState = nextValue(rollState)
	end

	local appearanceRoll = (rollState % 100) + 1
	if appearanceRoll > Config.AppearanceChancePercent then
		return nil
	end

	local candidates = {}
	for _, objective in Config.Objectives do
		for _, node in roomPlan.Nodes do
			if eligible(objective, node) then
				table.insert(candidates, {
					Objective = objective,
					Host = node,
				})
			end
		end
	end
	if #candidates == 0 then
		return nil
	end

	rollState = nextValue(rollState)
	local selection = candidates[(rollState % #candidates) + 1]
	local objective = selection.Objective
	local host = selection.Host
	local identity =
		`{Config.Version}|seed={roomPlan.Seed}|objective={objective.Id}@{objective.Version}|host={host.RoomId}@{host.Index}`

	return table.freeze({
		Seed = roomPlan.Seed,
		ConfigVersion = Config.Version,
		PlanIdentity = identity,
		ObjectiveId = objective.Id,
		ObjectiveVersion = objective.Version,
		ObjectiveType = objective.ObjectiveType,
		RequiredProgress = objective.RequiredProgress,
		HostIndex = host.Index,
		HostRoomId = host.RoomId,
	})
end

return table.freeze(OptionalObjectivePlanner)
