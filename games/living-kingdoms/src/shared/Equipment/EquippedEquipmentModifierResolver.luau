--!strict

-- Resolves modifier facts from the authoritative durable inventory record passed
-- by a server owner. This module owns no inventory state and no gameplay outcome;
-- it only joins an equipped instance to its authored definition and delegates
-- effect arithmetic to EquipmentAffixModifierResolver.

local EquipmentRewardConfig = require(script.Parent.Parent.Config.EquipmentRewardConfig)
local EquipmentRewardContracts = require(script.Parent.EquipmentRewardContracts)
local EquipmentAffixModifierResolver = require(script.Parent.EquipmentAffixModifierResolver)

export type EquipmentSlotId = EquipmentRewardContracts.EquipmentSlotId
export type EquipmentReward = EquipmentRewardContracts.EquipmentReward

export type InventoryRecordLike = {
	InventoryByInstanceId: { [string]: EquipmentReward },
	EquippedBySlot: { [EquipmentSlotId]: string? },
}

export type ResolvedEquippedModifiers = {
	damageMultiplier: number,
	reloadDurationMultiplier: number,
	maximumHealthMultiplier: number,
	sourceInstanceId: string?,
}

local definitionsById: { [string]: any } = {}
for _, definition in EquipmentRewardConfig.Definitions do
	definitionsById[definition.Id] = definition
end

local function neutral(): ResolvedEquippedModifiers
	return table.freeze({
		damageMultiplier = 1,
		reloadDurationMultiplier = 1,
		maximumHealthMultiplier = 1,
		sourceInstanceId = nil,
	})
end

local function isKnownSlotId(value: unknown): boolean
	local slots = EquipmentRewardContracts.SlotIds
	return value == slots.Primary or value == slots.Secondary or value == slots.Armor or value == slots.Relic
end

local function equippedItem(
	record: InventoryRecordLike?,
	slotId: EquipmentSlotId
): (string?, EquipmentReward?, any?)
	if
		type(record) ~= "table"
		or type(record.InventoryByInstanceId) ~= "table"
		or type(record.EquippedBySlot) ~= "table"
	then
		return nil, nil, nil
	end
	local validRecord = record :: InventoryRecordLike
	local instanceId = validRecord.EquippedBySlot[slotId]
	if type(instanceId) ~= "string" or instanceId == "" then
		return nil, nil, nil
	end
	local reward = validRecord.InventoryByInstanceId[instanceId]
	if type(reward) ~= "table" or type(reward.DefinitionId) ~= "string" then
		return nil, nil, nil
	end
	local definition = definitionsById[reward.DefinitionId]
	if definition == nil or definition.Slot ~= slotId then
		return nil, nil, nil
	end
	return instanceId, reward, definition
end

local function resolveReward(instanceId: string, reward: EquipmentReward): ResolvedEquippedModifiers
	local modifiers = EquipmentAffixModifierResolver.resolve(reward.Affixes)
	return table.freeze({
		damageMultiplier = modifiers.damageMultiplier,
		reloadDurationMultiplier = modifiers.reloadDurationMultiplier,
		maximumHealthMultiplier = modifiers.maximumHealthMultiplier,
		sourceInstanceId = instanceId,
	})
end

local EquippedEquipmentModifierResolver = {}

function EquippedEquipmentModifierResolver.resolveForSlot(
	record: InventoryRecordLike?,
	slotId: unknown
): ResolvedEquippedModifiers
	if not isKnownSlotId(slotId) then
		return neutral()
	end
	local knownSlotId = slotId :: EquipmentSlotId
	local instanceId, reward = equippedItem(record, knownSlotId)
	if instanceId == nil or reward == nil then
		return neutral()
	end
	return resolveReward(instanceId, reward)
end

function EquippedEquipmentModifierResolver.resolveForWeapon(
	record: InventoryRecordLike?,
	weaponId: unknown
): ResolvedEquippedModifiers
	if type(weaponId) ~= "string" or weaponId == "" then
		return neutral()
	end

	for _, slotId in { EquipmentRewardContracts.SlotIds.Primary, EquipmentRewardContracts.SlotIds.Secondary } do
		local instanceId, reward, definition = equippedItem(record, slotId)
		if instanceId ~= nil and reward ~= nil and definition ~= nil and definition.WeaponId == weaponId then
			return resolveReward(instanceId, reward)
		end
	end

	return neutral()
end

function EquippedEquipmentModifierResolver.neutral(): ResolvedEquippedModifiers
	return neutral()
end

return table.freeze(EquippedEquipmentModifierResolver)
