--!strict

--[[
	VS-0106 deterministic optional secret branch resolver.

	The resolver consumes an already-valid main room plan and produces a separate
	branch descriptor. It never rewrites PreviousIndex/NextIndex on the required
	main route, so entry-to-boss connectivity cannot be damaged by the secret.
]]

local Config = require(script.Parent.Parent.Config.SecretBranchConfig)

export type SecretBranchPlan = {
	Seed: number,
	HostIndex: number,
	HostRoomId: string,
	SecretRoomId: string,
	SecretRoomVersion: string,
	RewardId: string,
	RewardVersion: string,
	RunCurrencyAmount: number,
}

export type SecretState = {
	Plan: SecretBranchPlan?,
	Discovered: boolean,
	Claimed: boolean,
}

local SecretBranchResolver = {}

local function nextValue(value: number): number
	return (value * 48_271) % 2_147_483_647
end

local function isEligible(node: any): boolean
	return Config.EligibleHostRoles[node.Role] == true
		and node.Depth >= Config.MinimumHostDepth
		and node.Depth <= Config.MaximumHostDepth
end

function SecretBranchResolver.plan(roomPlan: any): SecretBranchPlan?
	assert(type(roomPlan) == "table", "room plan is required")
	assert(type(roomPlan.Seed) == "number" and roomPlan.Seed % 1 == 0 and roomPlan.Seed > 0, "invalid room plan seed")
	assert(type(roomPlan.Nodes) == "table", "room plan nodes are required")

	local rollState = nextValue(roomPlan.Seed)
	local branchRoll = (rollState % 100) + 1
	if branchRoll > Config.BranchChancePercent then
		return nil
	end

	local candidates = {}
	for _, node in roomPlan.Nodes do
		if isEligible(node) then
			table.insert(candidates, node)
		end
	end
	if #candidates == 0 then
		return nil
	end

	rollState = nextValue(rollState)
	local host = candidates[(rollState % #candidates) + 1]
	return table.freeze({
		Seed = roomPlan.Seed,
		HostIndex = host.Index,
		HostRoomId = host.RoomId,
		SecretRoomId = Config.SecretRoom.Id,
		SecretRoomVersion = Config.SecretRoom.Version,
		RewardId = Config.Reward.RewardId,
		RewardVersion = Config.Reward.RewardVersion,
		RunCurrencyAmount = Config.Reward.RunCurrencyAmount,
	})
end

function SecretBranchResolver.newState(plan: SecretBranchPlan?): SecretState
	return {
		Plan = plan,
		Discovered = false,
		Claimed = false,
	}
end

function SecretBranchResolver.discover(state: SecretState, hostIndex: number): (boolean, string)
	if state.Plan == nil then
		return false, "NoSecretBranch"
	end
	if state.Discovered then
		return false, "AlreadyDiscovered"
	end
	if hostIndex ~= state.Plan.HostIndex then
		return false, "WrongHost"
	end
	state.Discovered = true
	return true, "SecretDiscovered"
end

function SecretBranchResolver.claim(state: SecretState): (boolean, string, number)
	if state.Plan == nil then
		return false, "NoSecretBranch", 0
	end
	if not state.Discovered then
		return false, "SecretUndiscovered", 0
	end
	if state.Claimed then
		return false, "RewardAlreadyClaimed", 0
	end
	state.Claimed = true
	return true, "RewardClaimed", state.Plan.RunCurrencyAmount
end

return table.freeze(SecretBranchResolver)
