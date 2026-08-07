--!strict

--[[
	Server-only, run-scoped reward distribution coordinator.

	The caller freezes the eligible participant roster and supplies the finalized
	reward list. Each player is marked complete only after every reward has either
	been applied or was already present. Temporary failures remain pending and are
	retried on later calls without duplicating successful inserts.
]]

export type MutationResult = {
	Accepted: boolean,
	ReasonId: string,
}

export type InventoryOwner = {
	applyReward: (self: InventoryOwner, playerId: number, reward: any, nowUnix: number) -> MutationResult,
}

export type DistributionResult = {
	Complete: boolean,
	CompletedPlayerIds: { number },
	PendingPlayerIds: { number },
	FailureReasonsByPlayerId: { [number]: string },
}

export type Service = {
	distribute: (self: Service, rewards: { any }, nowUnix: number) -> DistributionResult,
	isComplete: (self: Service) -> boolean,
	destroy: (self: Service) -> (),
}

type Internal = {
	InventoryOwner: InventoryOwner,
	ParticipantUserIds: { number },
	CompletedByPlayerId: { [number]: boolean },
	Destroyed: boolean,
}

local Service = {}
Service.__index = Service

local function copyIds(source: { number }): { number }
	local copy = {}
	for _, playerId in source do
		table.insert(copy, playerId)
	end
	return table.freeze(copy)
end

local function snapshot(state: Internal, failureReasons: { [number]: string }): DistributionResult
	local completed = {}
	local pending = {}
	for _, playerId in state.ParticipantUserIds do
		if state.CompletedByPlayerId[playerId] then
			table.insert(completed, playerId)
		else
			table.insert(pending, playerId)
		end
	end
	return table.freeze({
		Complete = #pending == 0,
		CompletedPlayerIds = table.freeze(completed),
		PendingPlayerIds = table.freeze(pending),
		FailureReasonsByPlayerId = table.freeze(failureReasons),
	})
end

function Service.new(inventoryOwner: InventoryOwner, participantUserIds: { number }): Service
	assert(
		type(inventoryOwner) == "table" and type(inventoryOwner.applyReward) == "function",
		"invalid inventory owner"
	)
	assert(type(participantUserIds) == "table", "invalid participant roster")

	local seen = {}
	local ordered = {}
	for _, playerId in participantUserIds do
		assert(type(playerId) == "number" and playerId % 1 == 0 and playerId > 0, "invalid participant id")
		if not seen[playerId] then
			seen[playerId] = true
			table.insert(ordered, playerId)
		end
	end
	table.sort(ordered)

	return setmetatable(
		{
			InventoryOwner = inventoryOwner,
			ParticipantUserIds = copyIds(ordered),
			CompletedByPlayerId = {},
			Destroyed = false,
		} :: Internal,
		Service
	) :: any
end

function Service:distribute(rewards: { any }, nowUnix: number): DistributionResult
	local state: Internal = self :: any
	if state.Destroyed then
		return table.freeze({
			Complete = false,
			CompletedPlayerIds = table.freeze({}),
			PendingPlayerIds = table.freeze({}),
			FailureReasonsByPlayerId = table.freeze({}),
		})
	end
	assert(type(rewards) == "table", "invalid rewards")
	assert(type(nowUnix) == "number" and nowUnix >= 0, "invalid timestamp")

	local failures = {}
	for _, playerId in state.ParticipantUserIds do
		if state.CompletedByPlayerId[playerId] then
			continue
		end

		local allApplied = true
		for _, reward in rewards do
			local mutation = state.InventoryOwner:applyReward(playerId, reward, nowUnix)
			if mutation.Accepted ~= true and mutation.ReasonId ~= "RewardAlreadyApplied" then
				allApplied = false
				failures[playerId] = mutation.ReasonId
				break
			end
		end

		if allApplied then
			state.CompletedByPlayerId[playerId] = true
		end
	end

	return snapshot(state, failures)
end

function Service:isComplete(): boolean
	local state: Internal = self :: any
	if state.Destroyed then
		return false
	end
	for _, playerId in state.ParticipantUserIds do
		if not state.CompletedByPlayerId[playerId] then
			return false
		end
	end
	return true
end

function Service:destroy()
	local state: Internal = self :: any
	if state.Destroyed then
		return
	end
	state.Destroyed = true
	table.clear(state.CompletedByPlayerId)
end

return table.freeze(Service)
