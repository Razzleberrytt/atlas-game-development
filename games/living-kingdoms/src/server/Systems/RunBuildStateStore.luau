--!strict

--[[
	RPG-0102 pure operation-scoped run-build state owner.

	The store owns one retained record per admitted operative and the shared Field
	Upgrade stacks used by every record. Disconnecting only releases the live
	association: reconnecting during the same operation recovers the same record,
	while reset/stop destroys every operation-bound fact.

	Relic mutations intentionally remain deferred. The empty slot/effect/reward
	shapes are established here so later RPG tasks extend this owner instead of
	creating parallel state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)

export type UpgradeStacks = { [string]: number }

type OperativeState = {
	connected: boolean,
	revision: number,
	replacementStateId: string,
	upgradeStacks: UpgradeStacks,
	relicSlots: { any },
	pendingRewards: { any },
}

export type Store = {
	startOperation: (self: Store) -> number,
	stopOperation: (self: Store) -> (),
	registerOperative: (self: Store, operativeId: string) -> boolean,
	disconnectOperative: (self: Store, operativeId: string) -> boolean,
	readOperationGeneration: (self: Store) -> number,
	readUpgradeStacks: (self: Store) -> UpgradeStacks,
	readSafeSnapshot: (self: Store, operativeId: string) -> any?,
	commitUpgradeStacks: (
		self: Store,
		operationGeneration: number,
		requestId: string,
		upgradeStacks: UpgradeStacks
	) -> (boolean, string?),
}

local function isPositiveInteger(value: unknown): boolean
	return type(value) == "number" and value == value and value > 0 and value % 1 == 0
end

local function copyUpgradeStacks(stacks: UpgradeStacks): UpgradeStacks
	return table.clone(stacks)
end

local function validateUpgradeStacks(stacks: unknown): boolean
	if type(stacks) ~= "table" then
		return false
	end
	for upgradeId, stackCount in stacks :: { [any]: any } do
		if
			type(upgradeId) ~= "string"
			or not RunRpgContracts.isKnownRunUpgradeId(upgradeId)
			or type(stackCount) ~= "number"
			or stackCount ~= stackCount
			or stackCount % 1 ~= 0
			or stackCount < 0
			or stackCount > RunRpgConfig.Limits.maximumUpgradeStacksPerDefinition
		then
			return false
		end
	end
	return true
end

local function emptyRelicSlots()
	local slots = {}
	for slotIndex = 1, RunRpgConfig.Limits.maximumEquippedRelicsPerOperative do
		table.insert(slots, {
			slotIndex = slotIndex,
			slotStateId = RunRpgContracts.RelicSlotStateIds.Empty,
			relicId = nil,
			effectStateId = RunRpgContracts.EffectStateIds.Inactive,
			chargeCount = 0,
			counterValue = 0,
			cooldownEndServerTimestamp = nil,
			revision = 0,
		})
	end
	return slots
end

local function copyRelicSlots(slots: { any }): { any }
	local result = {}
	for _, slot in slots do
		table.insert(result, table.clone(slot))
	end
	return result
end

local function copyPendingRewards(rewards: { any }): { any }
	local result = {}
	for _, reward in rewards do
		local copy = table.clone(reward)
		copy.offeredRelicIds = table.clone(reward.offeredRelicIds)
		table.insert(result, copy)
	end
	return result
end

local RunBuildStateStore = {}

function RunBuildStateStore.new(): Store
	local started = false
	local operationGeneration = 0
	local revision = 0
	local squadUpgradeStacks: UpgradeStacks = {}
	local operativeStates: { [string]: OperativeState } = {}
	local processedRequestIds: { [string]: boolean } = {}
	local processedRequestOrder: { string } = {}

	local store = {} :: any

	function store:startOperation(): number
		started = true
		operationGeneration += 1
		revision = 0
		table.clear(squadUpgradeStacks)
		table.clear(operativeStates)
		table.clear(processedRequestIds)
		table.clear(processedRequestOrder)
		return operationGeneration
	end

	function store:stopOperation()
		started = false
		revision = 0
		table.clear(squadUpgradeStacks)
		table.clear(operativeStates)
		table.clear(processedRequestIds)
		table.clear(processedRequestOrder)
	end

	function store:registerOperative(operativeId: string): boolean
		if not started or type(operativeId) ~= "string" or operativeId == "" or #operativeId > 96 then
			return false
		end
		local existing = operativeStates[operativeId]
		if existing ~= nil then
			existing.connected = true
			return true
		end
		local operativeCount = 0
		for _ in operativeStates do
			operativeCount += 1
		end
		if operativeCount >= RunRpgConfig.Limits.maximumTrackedOperativesPerOperation then
			return false
		end
		operativeStates[operativeId] = {
			connected = true,
			revision = revision,
			replacementStateId = RunRpgContracts.ReplacementStateIds.None,
			upgradeStacks = copyUpgradeStacks(squadUpgradeStacks),
			relicSlots = emptyRelicSlots(),
			pendingRewards = {},
		}
		return true
	end

	function store:disconnectOperative(operativeId: string): boolean
		local state = operativeStates[operativeId]
		if not started or state == nil or not state.connected then
			return false
		end
		state.connected = false
		return true
	end

	function store:readOperationGeneration(): number
		return operationGeneration
	end

	function store:readUpgradeStacks(): UpgradeStacks
		return table.freeze(copyUpgradeStacks(squadUpgradeStacks))
	end

	function store:readSafeSnapshot(operativeId: string): any?
		if not started then
			return nil
		end
		local state = operativeStates[operativeId]
		if state == nil then
			return nil
		end
		return table.freeze({
			operationId = RunRpgContracts.RunBuildNetworkOperationIds.Snapshot,
			operationGeneration = operationGeneration,
			revision = state.revision,
			replacementStateId = state.replacementStateId,
			upgradeStacks = table.freeze(copyUpgradeStacks(state.upgradeStacks)),
			relicSlots = copyRelicSlots(state.relicSlots),
			pendingRewards = copyPendingRewards(state.pendingRewards),
		})
	end

	function store:commitUpgradeStacks(
		expectedGeneration: number,
		requestId: string,
		nextUpgradeStacks: UpgradeStacks
	): (boolean, string?)
		if not started then
			return false, RunRpgContracts.RunRpgRejectionReasonIds.ServiceStopped
		end
		if not isPositiveInteger(expectedGeneration) or expectedGeneration ~= operationGeneration then
			return false, RunRpgContracts.RunRpgRejectionReasonIds.StaleOperationGeneration
		end
		if
			type(requestId) ~= "string"
			or requestId == ""
			or #requestId > 128
			or not validateUpgradeStacks(nextUpgradeStacks)
		then
			return false, RunRpgContracts.RunRpgRejectionReasonIds.InvalidIntent
		end
		if processedRequestIds[requestId] then
			return false, RunRpgContracts.RunRpgRejectionReasonIds.DuplicateRequest
		end

		processedRequestIds[requestId] = true
		table.insert(processedRequestOrder, requestId)
		if #processedRequestOrder > RunRpgConfig.Limits.maximumProcessedRequestIdsPerOperative then
			local expiredRequestId = table.remove(processedRequestOrder, 1)
			if expiredRequestId ~= nil then
				processedRequestIds[expiredRequestId] = nil
			end
		end

		squadUpgradeStacks = copyUpgradeStacks(nextUpgradeStacks)
		revision += 1
		for _, state in operativeStates do
			state.revision = revision
			state.upgradeStacks = copyUpgradeStacks(squadUpgradeStacks)
		end
		return true, nil
	end

	return store :: Store
end

return table.freeze(RunBuildStateStore)
