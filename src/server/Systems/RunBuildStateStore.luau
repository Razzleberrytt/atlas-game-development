--!strict

--[[
	RPG-0102 pure operation-scoped run-build state owner, extended by RPG-0107
	with the relic reward, slot, and replacement framework.

	The store owns one retained record per admitted operative: the shared Field
	Upgrade stacks, the three equipped relic slots, and the bounded pending relic
	reward queue. Disconnecting only releases the live association; reconnecting
	during the same operation recovers the same record (including any stored
	reward offer, which is never rerolled), while reset/stop destroys every
	operation-bound fact.

	Relic effects are applied by the authoritative combat, reload, and life owners
	(RPG-0108); this store remains the single home for the equipped relics and
	their counted progress. It guarantees the framework invariants — rewards
	cannot duplicate, reroll through reconnects, exceed the slot cap, or survive
	operation teardown.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)
local RelicModifierResolver = require(ReplicatedStorage.Shared.RPG.RelicModifierResolver)
local RelicRewardResolver = require(ReplicatedStorage.Shared.RPG.RelicRewardResolver)

export type UpgradeStacks = { [string]: number }
export type CompatibilityIdSet = { [string]: boolean }

-- Revisioned server-only relic read for the authoritative effect owners. The
-- revision lets a caller cache derived modifiers until the build actually
-- changes; it is never sent to a client.
export type EquippedRelicRead = {
	revision: number,
	relicIds: { string },
}

-- Result of one counted-relic advance: the slot's stored counter after the
-- advance and how many times the relic triggered, which the caller commits
-- through the effect's own authoritative boundary.
export type RelicCounterAdvance = {
	counterAfter: number,
	triggerCount: number,
}

type OperativeState = {
	connected: boolean,
	revision: number,
	replacementStateId: string,
	upgradeStacks: UpgradeStacks,
	relicSlots: { any },
	pendingRewards: { any },
	nextRewardSequence: number,
	resolvedRewardSequences: { [number]: boolean },
	resolvedRewardOrder: { number },
}

export type Store = {
	startOperation: (self: Store) -> number,
	stopOperation: (self: Store) -> (),
	registerOperative: (self: Store, operativeId: string) -> boolean,
	disconnectOperative: (self: Store, operativeId: string) -> boolean,
	readOperationGeneration: (self: Store) -> number,
	readUpgradeStacks: (self: Store) -> UpgradeStacks,
	readSafeSnapshot: (self: Store, operativeId: string) -> any?,
	readEquippedRelicIds: (self: Store, operativeId: string) -> EquippedRelicRead?,
	advanceRelicCounter: (
		self: Store,
		operativeId: string,
		relicId: string,
		increment: number,
		threshold: number
	) -> RelicCounterAdvance?,
	readRelicCounter: (self: Store, operativeId: string, relicId: string) -> number?,
	consumeRelicCharge: (self: Store, operativeId: string, relicId: string) -> boolean,
	setRelicCounter: (self: Store, operativeId: string, relicId: string, value: number) -> boolean,
	commitUpgradeStacks: (
		self: Store,
		operationGeneration: number,
		requestId: string,
		upgradeStacks: UpgradeStacks
	) -> (boolean, string?),
	enqueueRelicReward: (
		self: Store,
		operationGeneration: number,
		requestId: string,
		operativeId: string,
		sourceId: string,
		loadoutCompatibilityIds: CompatibilityIdSet
	) -> (boolean, string?, number?),
	chooseRelic: (
		self: Store,
		operationGeneration: number,
		requestId: string,
		operativeId: string,
		rewardSequence: number,
		relicId: string
	) -> (boolean, string?),
	replaceRelic: (
		self: Store,
		operationGeneration: number,
		requestId: string,
		operativeId: string,
		rewardSequence: number,
		relicId: string,
		replaceSlotIndex: number
	) -> (boolean, string?),
}

local Rejections = RunRpgContracts.RunRpgRejectionReasonIds
local SlotStates = RunRpgContracts.RelicSlotStateIds
local EffectStates = RunRpgContracts.EffectStateIds
local ReplacementStates = RunRpgContracts.ReplacementStateIds
local RewardChoiceStates = RunRpgContracts.RewardChoiceStateIds

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

local function validateRequestId(requestId: unknown): boolean
	return type(requestId) == "string" and requestId ~= "" and #requestId <= 128
end

local function isKnownRewardSourceId(sourceId: unknown): boolean
	if type(sourceId) ~= "string" then
		return false
	end
	for _, definition in RunRpgConfig.RewardSourceCatalog do
		if definition.sourceId == sourceId then
			return true
		end
	end
	return false
end

local function emptyRelicSlots()
	local slots = {}
	for slotIndex = 1, RunRpgConfig.Limits.maximumEquippedRelicsPerOperative do
		table.insert(slots, {
			slotIndex = slotIndex,
			slotStateId = SlotStates.Empty,
			relicId = nil,
			effectStateId = EffectStates.Inactive,
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

-- Reset the slot record to its canonical empty shape so a discarded relic
-- leaves no lingering effect state.
local function clearRelicSlot(slot: any)
	slot.slotStateId = SlotStates.Empty
	slot.relicId = nil
	slot.effectStateId = EffectStates.Inactive
	slot.chargeCount = 0
	slot.counterValue = 0
	slot.cooldownEndServerTimestamp = nil
end

local function catalogDefinition(relicId: string): any?
	for _, definition in RunRpgConfig.RelicCatalog do
		if definition.relicId == relicId then
			return definition
		end
	end
	return nil
end

-- Equip a relic with its declared operation charges. Counters start empty; the
-- authoritative effect owners advance them.
local function equipRelicIntoSlot(slot: any, relicId: string)
	local definition = catalogDefinition(relicId)
	slot.slotStateId = SlotStates.Equipped
	slot.relicId = relicId
	slot.effectStateId = EffectStates.Inactive
	slot.chargeCount = if definition == nil then 0 else definition.maximumCharges
	slot.counterValue = 0
	slot.cooldownEndServerTimestamp = nil
	slot.revision += 1
end

local function equippedRelicIdSet(state: OperativeState): { [string]: boolean }
	local set = {}
	for _, slot in state.relicSlots do
		if slot.relicId ~= nil then
			set[slot.relicId] = true
		end
	end
	return set
end

local function firstEmptySlot(state: OperativeState): any?
	for _, slot in state.relicSlots do
		if slot.slotStateId == SlotStates.Empty then
			return slot
		end
	end
	return nil
end

local function findPendingReward(state: OperativeState, rewardSequence: number): (any?, number?)
	for index, reward in state.pendingRewards do
		if reward.rewardSequence == rewardSequence then
			return reward, index
		end
	end
	return nil, nil
end

-- A pending reward with no empty slot requires an explicit replacement choice.
local function refreshReplacementState(state: OperativeState)
	if #state.pendingRewards > 0 and firstEmptySlot(state) == nil then
		state.replacementStateId = ReplacementStates.AwaitingChoice
	else
		state.replacementStateId = ReplacementStates.None
	end
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

	-- Shared bounded replay history. Records only on a committed mutation so a
	-- rejected malformed request may be safely retried, while any accepted
	-- request cannot be replayed.
	local function isRequestReplayed(requestId: string): boolean
		return processedRequestIds[requestId] == true
	end

	local function recordRequest(requestId: string)
		processedRequestIds[requestId] = true
		table.insert(processedRequestOrder, requestId)
		if #processedRequestOrder > RunRpgConfig.Limits.maximumProcessedRequestIdsPerOperative then
			local expiredRequestId = table.remove(processedRequestOrder, 1)
			if expiredRequestId ~= nil then
				processedRequestIds[expiredRequestId] = nil
			end
		end
	end

	local function recordResolvedReward(state: OperativeState, rewardSequence: number)
		state.resolvedRewardSequences[rewardSequence] = true
		table.insert(state.resolvedRewardOrder, rewardSequence)
		if #state.resolvedRewardOrder > RunRpgConfig.Limits.maximumProcessedRewardIdsPerOperation then
			local expired = table.remove(state.resolvedRewardOrder, 1)
			if expired ~= nil then
				state.resolvedRewardSequences[expired] = nil
			end
		end
	end

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
			replacementStateId = ReplacementStates.None,
			upgradeStacks = copyUpgradeStacks(squadUpgradeStacks),
			relicSlots = emptyRelicSlots(),
			pendingRewards = {},
			nextRewardSequence = 0,
			resolvedRewardSequences = {},
			resolvedRewardOrder = {},
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

	function store:readEquippedRelicIds(operativeId: string): EquippedRelicRead?
		if not started then
			return nil
		end
		local state = operativeStates[operativeId]
		if state == nil then
			return nil
		end
		local relicIds = {}
		for _, slot in state.relicSlots do
			if slot.slotStateId == SlotStates.Equipped and type(slot.relicId) == "string" then
				table.insert(relicIds, slot.relicId)
			end
		end
		return table.freeze({
			revision = state.revision,
			relicIds = table.freeze(relicIds),
		})
	end

	-- Saturating ceiling for a stored relic counter. Counters express bounded
	-- progress (kills, sustained shots), never an unbounded accumulator.
	local MAXIMUM_RELIC_COUNTER_VALUE = 999

	local function equippedSlot(operativeId: string, relicId: string): any?
		if not started or type(relicId) ~= "string" then
			return nil
		end
		local state = operativeStates[operativeId]
		if state == nil then
			return nil
		end
		for _, slot in state.relicSlots do
			if slot.slotStateId == SlotStates.Equipped and slot.relicId == relicId then
				return slot
			end
		end
		return nil
	end

	-- Reads one equipped relic's stored counter, or `nil` when it is not equipped.
	function store:readRelicCounter(operativeId: string, relicId: string): number?
		local slot = equippedSlot(operativeId, relicId)
		return if slot == nil then nil else slot.counterValue
	end

	--[[
		Sets one equipped relic's counter directly, for saturating progress such as
		Suppression Engine's sustained-shot count. The value is clamped to a whole
		number inside the counter ceiling; a malformed value resets to zero rather
		than storing garbage.
	]]
	function store:setRelicCounter(operativeId: string, relicId: string, value: number): boolean
		local slot = equippedSlot(operativeId, relicId)
		if slot == nil then
			return false
		end
		if type(value) ~= "number" or value ~= value or value < 0 or value % 1 ~= 0 then
			slot.counterValue = 0
			return false
		end
		slot.counterValue = math.min(value, MAXIMUM_RELIC_COUNTER_VALUE)
		return true
	end

	--[[
		Spends one declared operation charge from an equipped relic, such as Second
		Wind's single reprieve. Returns false when the relic is not equipped or has
		no charge left, so a once-per-operation effect can never fire twice.
	]]
	function store:consumeRelicCharge(operativeId: string, relicId: string): boolean
		local slot = equippedSlot(operativeId, relicId)
		if slot == nil or type(slot.chargeCount) ~= "number" or slot.chargeCount < 1 then
			return false
		end
		slot.chargeCount -= 1
		return true
	end

	--[[
		Server-only counted-relic advance. The equipped slot's canonical
		counterValue is the only home for relic progress, and the pure resolver
		owns the arithmetic, so this store only holds and bounds the state. Returns
		`nil` when the operation is stopped, the operative is untracked, or the
		relic is not equipped; a stale or malformed increment simply triggers
		nothing.
	]]
	function store:advanceRelicCounter(
		operativeId: string,
		relicId: string,
		increment: number,
		threshold: number
	): RelicCounterAdvance?
		local slot = equippedSlot(operativeId, relicId)
		if slot == nil then
			return nil
		end
		local advance = RelicModifierResolver.advanceCounter(slot.counterValue, increment, threshold)
		slot.counterValue = advance.counterAfter
		return table.freeze({
			counterAfter = advance.counterAfter,
			triggerCount = advance.triggerCount,
		})
	end

	-- Shared entry validation for every operative-scoped request. Returns the
	-- resolved state on success, or `nil` plus a rejection reason.
	local function beginOperativeRequest(
		expectedGeneration: number,
		requestId: string,
		operativeId: string
	): (OperativeState?, string?)
		if not started then
			return nil, Rejections.ServiceStopped
		end
		if not isPositiveInteger(expectedGeneration) or expectedGeneration ~= operationGeneration then
			return nil, Rejections.StaleOperationGeneration
		end
		if not validateRequestId(requestId) then
			return nil, Rejections.InvalidIntent
		end
		if isRequestReplayed(requestId) then
			return nil, Rejections.DuplicateRequest
		end
		local state = operativeStates[operativeId]
		if state == nil then
			return nil, Rejections.NotParticipant
		end
		return state, nil
	end

	function store:commitUpgradeStacks(
		expectedGeneration: number,
		requestId: string,
		nextUpgradeStacks: UpgradeStacks
	): (boolean, string?)
		if not started then
			return false, Rejections.ServiceStopped
		end
		if not isPositiveInteger(expectedGeneration) or expectedGeneration ~= operationGeneration then
			return false, Rejections.StaleOperationGeneration
		end
		if not validateRequestId(requestId) or not validateUpgradeStacks(nextUpgradeStacks) then
			return false, Rejections.InvalidIntent
		end
		if isRequestReplayed(requestId) then
			return false, Rejections.DuplicateRequest
		end

		recordRequest(requestId)

		squadUpgradeStacks = copyUpgradeStacks(nextUpgradeStacks)
		revision += 1
		for _, state in operativeStates do
			state.revision = revision
			state.upgradeStacks = copyUpgradeStacks(squadUpgradeStacks)
		end
		return true, nil
	end

	function store:enqueueRelicReward(
		expectedGeneration: number,
		requestId: string,
		operativeId: string,
		sourceId: string,
		loadoutCompatibilityIds: CompatibilityIdSet
	): (boolean, string?, number?)
		local state, reason = beginOperativeRequest(expectedGeneration, requestId, operativeId)
		if state == nil then
			return false, reason, nil
		end
		if not isKnownRewardSourceId(sourceId) then
			return false, Rejections.InvalidIntent, nil
		end
		if #state.pendingRewards >= RunRpgConfig.Limits.maximumQueuedRelicRewardsPerOperative then
			return false, Rejections.RewardQueueFull, nil
		end

		local rewardSequence = state.nextRewardSequence + 1
		local offeredRelicIds = RelicRewardResolver.generateChoices(
			operationGeneration,
			rewardSequence,
			loadoutCompatibilityIds,
			equippedRelicIdSet(state)
		)
		if #offeredRelicIds < RunRpgConfig.Limits.relicChoiceCountPerReward then
			-- Not enough distinct compatible relics remain to present a real
			-- choice; do not offer or consume the reward sequence.
			return false, Rejections.RelicNotOffered, nil
		end

		recordRequest(requestId)
		state.nextRewardSequence = rewardSequence
		table.insert(state.pendingRewards, {
			rewardSequence = rewardSequence,
			sourceId = sourceId,
			stateId = RewardChoiceStates.Pending,
			offeredRelicIds = table.clone(offeredRelicIds),
			expiresAtServerTimestamp = nil,
		})
		revision += 1
		state.revision = revision
		refreshReplacementState(state)
		return true, nil, rewardSequence
	end

	-- Shared reward-selection validation for choose/replace: the reward must be
	-- pending and the chosen relic must be a known, offered, not-already-equipped
	-- relic.
	local function validateSelectedRelic(
		state: OperativeState,
		rewardSequence: number,
		relicId: string
	): (any?, string?)
		if not isPositiveInteger(rewardSequence) or type(relicId) ~= "string" then
			return nil, Rejections.InvalidIntent
		end
		local reward = findPendingReward(state, rewardSequence)
		if reward == nil or reward.stateId ~= RewardChoiceStates.Pending then
			return nil, Rejections.RewardNotPending
		end
		if not RunRpgContracts.isKnownRelicId(relicId) then
			return nil, Rejections.UnknownRelic
		end
		local wasOffered = false
		for _, offeredRelicId in reward.offeredRelicIds do
			if offeredRelicId == relicId then
				wasOffered = true
				break
			end
		end
		if not wasOffered then
			return nil, Rejections.RelicNotOffered
		end
		if equippedRelicIdSet(state)[relicId] then
			return nil, Rejections.RelicAlreadyEquipped
		end
		return reward, nil
	end

	local function resolveReward(state: OperativeState, rewardSequence: number)
		local _, index = findPendingReward(state, rewardSequence)
		if index ~= nil then
			table.remove(state.pendingRewards, index)
		end
		recordResolvedReward(state, rewardSequence)
	end

	function store:chooseRelic(
		expectedGeneration: number,
		requestId: string,
		operativeId: string,
		rewardSequence: number,
		relicId: string
	): (boolean, string?)
		local state, reason = beginOperativeRequest(expectedGeneration, requestId, operativeId)
		if state == nil then
			return false, reason
		end
		local reward, selectionReason = validateSelectedRelic(state, rewardSequence, relicId)
		if reward == nil then
			return false, selectionReason
		end
		local slot = firstEmptySlot(state)
		if slot == nil then
			-- Slots are full; the operative must submit an explicit replacement.
			return false, Rejections.SlotsFull
		end

		recordRequest(requestId)
		equipRelicIntoSlot(slot, relicId)
		resolveReward(state, rewardSequence)
		revision += 1
		state.revision = revision
		refreshReplacementState(state)
		return true, nil
	end

	function store:replaceRelic(
		expectedGeneration: number,
		requestId: string,
		operativeId: string,
		rewardSequence: number,
		relicId: string,
		replaceSlotIndex: number
	): (boolean, string?)
		local state, reason = beginOperativeRequest(expectedGeneration, requestId, operativeId)
		if state == nil then
			return false, reason
		end
		local reward, selectionReason = validateSelectedRelic(state, rewardSequence, relicId)
		if reward == nil then
			return false, selectionReason
		end
		if firstEmptySlot(state) ~= nil then
			-- An empty slot exists, so a destructive replacement is not required.
			return false, Rejections.ReplacementNotRequired
		end
		if not isPositiveInteger(replaceSlotIndex) then
			return false, Rejections.InvalidReplacementSlot
		end
		local targetSlot: any? = nil
		for _, slot in state.relicSlots do
			if slot.slotIndex == replaceSlotIndex and slot.slotStateId == SlotStates.Equipped then
				targetSlot = slot
				break
			end
		end
		if targetSlot == nil then
			return false, Rejections.InvalidReplacementSlot
		end

		recordRequest(requestId)
		-- Destroy the discarded relic for the remainder of the operation, then
		-- equip the chosen relic in its place.
		clearRelicSlot(targetSlot)
		equipRelicIntoSlot(targetSlot, relicId)
		resolveReward(state, rewardSequence)
		revision += 1
		state.revision = revision
		refreshReplacementState(state)
		return true, nil
	end

	return store :: Store
end

return table.freeze(RunBuildStateStore)
