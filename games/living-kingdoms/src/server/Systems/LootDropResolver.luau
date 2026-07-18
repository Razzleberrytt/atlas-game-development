--!strict

--[[
	HROI-0106 pure deterministic drop decision. The caller supplies one confirmed
	authoritative enemy-death fact and owns world creation, collection, cleanup,
	and every reward commit. No randomness, networking, Instances, or hidden state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootDropConfig = require(ReplicatedStorage.Shared.Config.LootDropConfig)
local LootDropContracts = require(ReplicatedStorage.Shared.Loot.LootDropContracts)

type DeathDropFact = LootDropContracts.DeathDropFact
type DropResolution = LootDropContracts.DropResolution

local Resolver = {}

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function stablePercent(text: string): number
	local hash = 0
	for index = 1, #text do
		hash = (hash * 131 + string.byte(text, index) * index) % 1000003
	end
	return hash % 100
end

local function reject(reasonId: string): DropResolution
	return table.freeze({
		didDrop = false,
		rejectionReasonId = reasonId,
		dropId = nil,
		kindId = nil,
		worldPosition = nil,
		expiresAtServerTimestamp = nil,
	}) :: DropResolution
end

function Resolver.resolve(fact: DeathDropFact): DropResolution
	if
		type(fact) ~= "table"
		or type(fact.enemyEntityId) ~= "string"
		or fact.enemyEntityId == ""
		or #fact.enemyEntityId > 240
		or type(fact.worldPosition) ~= "table"
		or not isFiniteNumber(fact.worldPosition.x)
		or not isFiniteNumber(fact.worldPosition.y)
		or not isFiniteNumber(fact.worldPosition.z)
		or not isFiniteNumber(fact.activeDropCount)
		or fact.activeDropCount < 0
		or fact.activeDropCount % 1 ~= 0
		or not isFiniteNumber(fact.serverTimestamp)
		or fact.serverTimestamp < 0
	then
		return reject("InvalidDeathFact")
	end
	if fact.activeDropCount >= LootDropConfig.MaximumActiveDrops then
		return reject("ActiveDropCapReached")
	end

	local roll = stablePercent(fact.enemyEntityId)
	local cursor = 0
	local selectedKindId: LootDropContracts.LootKindId? = nil
	for _, kindId in {
		LootDropContracts.LootKindIds.AmmunitionBundle,
		LootDropContracts.LootKindIds.FieldDressing,
		LootDropContracts.LootKindIds.FieldIntel,
	} do
		cursor += LootDropConfig.DropRollPercentByKind[kindId]
		if roll < cursor then
			selectedKindId = kindId
			break
		end
	end
	if selectedKindId == nil then
		return reject("NoDropRoll")
	end

	return table.freeze({
		didDrop = true,
		rejectionReasonId = nil,
		dropId = "loot:" .. fact.enemyEntityId,
		kindId = selectedKindId,
		worldPosition = table.freeze({
			x = fact.worldPosition.x,
			y = fact.worldPosition.y + LootDropConfig.Presentation.FloatHeightStuds,
			z = fact.worldPosition.z,
		}),
		expiresAtServerTimestamp = fact.serverTimestamp + LootDropConfig.DropLifetimeSeconds,
	}) :: DropResolution
end

return table.freeze(Resolver)
