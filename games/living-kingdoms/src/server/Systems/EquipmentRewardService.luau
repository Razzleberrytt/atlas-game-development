--!strict

-- Blueprint v1.9 authoritative, run-scoped equipment reward pipeline.
-- The same trusted reward context reproduces the same content signature, while
-- every newly-created item receives a globally unique server-owned instance ID.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Equipment.EquipmentRewardContracts)
local Config = require(ReplicatedStorage.Shared.Config.EquipmentRewardConfig)

export type RewardSourceId = Contracts.RewardSourceId
export type EquipmentReward = Contracts.EquipmentReward
export type RewardClaimResult = Contracts.RewardClaimResult

export type Service = {
	claimReward: (self: Service, sourceId: RewardSourceId) -> RewardClaimResult,
	getClaimedReward: (self: Service, sourceId: RewardSourceId) -> EquipmentReward?,
	destroy: (self: Service) -> (),
}

type InternalState = {
	RunId: string,
	Seed: number,
	ClaimedBySource: { [string]: EquipmentReward },
	Destroyed: boolean,
}

local MODULUS = 2_147_483_647
local MULTIPLIER = 48_271

local EquipmentRewardService = {}
EquipmentRewardService.__index = EquipmentRewardService

local function nextSeed(seed: number): number
	return (seed * MULTIPLIER) % MODULUS
end

local function deriveSeed(baseSeed: number, sourceId: string, salt: number): number
	local value = baseSeed
	for index = 1, #sourceId do
		value = nextSeed(value + string.byte(sourceId, index) + salt)
	end
	return math.max(1, value)
end

local function contains(list, value: string): boolean
	for _, entry in list do
		if entry == value then
			return true
		end
	end
	return false
end

local function selectRarity(seed: number, source): string
	local roll = (seed % 100) + 1
	local cumulative = 0
	for _, rarityId in { Contracts.RarityIds.Common, Contracts.RarityIds.Uncommon, Contracts.RarityIds.Rare } do
		cumulative += source.RarityWeights[rarityId] or 0
		if roll <= cumulative then
			return rarityId
		end
	end
	error("rarity weights did not resolve")
end

local function eligibleDefinitions(rarityId: string, source): { any }
	local eligible = {}
	for _, definition in Config.Definitions do
		local minimum = math.max(definition.MinimumPower, source.MinimumPower)
		local maximum = math.min(definition.MaximumPower, source.MaximumPower)
		if minimum <= maximum and contains(definition.AllowedRarities, rarityId) then
			table.insert(eligible, definition)
		end
	end
	return eligible
end

local function contentSignature(definition: any, rarityId: string, power: number, sourceId: string, rollSeed: number): string
	return table.concat({
		"v1",
		definition.Id,
		definition.Version,
		rarityId,
		tostring(power),
		sourceId,
		tostring(rollSeed),
	}, "|")
end

local function copyReward(reward: EquipmentReward): EquipmentReward
	return table.freeze({
		InstanceId = reward.InstanceId,
		ContentSignature = reward.ContentSignature,
		DefinitionId = reward.DefinitionId,
		DefinitionVersion = reward.DefinitionVersion,
		DisplayName = reward.DisplayName,
		Slot = reward.Slot,
		Rarity = reward.Rarity,
		Power = reward.Power,
		SourceId = reward.SourceId,
		RunId = reward.RunId,
		Seed = reward.Seed,
	})
end

local function reject(reasonId: string): RewardClaimResult
	return table.freeze({ Accepted = false, ReasonId = reasonId, Reward = nil })
end

function EquipmentRewardService.new(runId: string, seed: number): Service
	assert(type(runId) == "string" and #runId >= 8 and #runId <= 96, "invalid reward run id")
	assert(type(seed) == "number" and seed % 1 == 0 and seed >= 1 and seed < MODULUS, "invalid reward seed")

	return setmetatable({
		_state = {
			RunId = runId,
			Seed = seed,
			ClaimedBySource = {},
			Destroyed = false,
		},
	}, EquipmentRewardService) :: any
end

function EquipmentRewardService:claimReward(sourceId: RewardSourceId): RewardClaimResult
	local state: InternalState = (self :: any)._state
	if state.Destroyed then
		return reject("ServiceDestroyed")
	end
	local source = Config.Sources[sourceId]
	if source == nil then
		return reject("UnknownSource")
	end
	if state.ClaimedBySource[sourceId] ~= nil then
		return reject("SourceAlreadyClaimed")
	end

	local raritySeed = deriveSeed(state.Seed, sourceId, 11)
	local rarityId = selectRarity(raritySeed, source)
	local eligible = eligibleDefinitions(rarityId, source)
	if #eligible == 0 then
		return reject("NoEligibleDefinition")
	end

	local definitionSeed = deriveSeed(state.Seed, sourceId, 29)
	local definition = eligible[(definitionSeed % #eligible) + 1]
	local minimumPower = math.max(definition.MinimumPower, source.MinimumPower)
	local maximumPower = math.min(definition.MaximumPower, source.MaximumPower)
	local powerSeed = deriveSeed(state.Seed, sourceId, 47)
	local power = minimumPower + (powerSeed % (maximumPower - minimumPower + 1))
	local rollSeed = deriveSeed(state.Seed, sourceId, 71)

	local reward: EquipmentReward = table.freeze({
		InstanceId = "item_" .. HttpService:GenerateGUID(false),
		ContentSignature = contentSignature(definition, rarityId, power, sourceId, rollSeed),
		DefinitionId = definition.Id,
		DefinitionVersion = definition.Version,
		DisplayName = definition.DisplayName,
		Slot = definition.Slot,
		Rarity = rarityId,
		Power = power,
		SourceId = sourceId,
		RunId = state.RunId,
		Seed = rollSeed,
	})
	state.ClaimedBySource[sourceId] = reward

	return table.freeze({ Accepted = true, ReasonId = "RewardClaimed", Reward = copyReward(reward) })
end

function EquipmentRewardService:getClaimedReward(sourceId: RewardSourceId): EquipmentReward?
	local state: InternalState = (self :: any)._state
	if state.Destroyed then
		return nil
	end
	local reward = state.ClaimedBySource[sourceId]
	if reward == nil then
		return nil
	end
	return copyReward(reward)
end

function EquipmentRewardService:destroy()
	local state: InternalState = (self :: any)._state
	state.Destroyed = true
	table.clear(state.ClaimedBySource)
end

return table.freeze(EquipmentRewardService)
