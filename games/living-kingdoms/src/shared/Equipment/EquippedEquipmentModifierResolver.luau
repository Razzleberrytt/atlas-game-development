--!strict

-- Resolves modifier facts from the authoritative durable inventory record passed
-- by a server owner. This module owns no inventory state and no combat outcome;
-- it only joins an equipped instance to its authored weapon definition and then
-- delegates effect arithmetic to EquipmentAffixModifierResolver.

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
	sourceInstanceId: string?,
}

local definitionsById: { [string]: any } = {}
for _, definition in EquipmentRewardConfig.Definitions do
	definitionsById[definition.Id] = definition
end

local function neutral(): ResolvedEquippedModifiers
	return table.freeze({
		damageMultiplier = 1,
		sourceInstanceId = nil,
	})
end

local EquippedEquipmentModifierResolver = {}

function EquippedEquipmentModifierResolver.resolveForWeapon(
	record: InventoryRecordLike?,
	weaponId: unknown
): ResolvedEquippedModifiers
	if
		type(weaponId) ~= "string"
		or weaponId == ""
		or type(record) ~= "table"
		or type(record.InventoryByInstanceId) ~= "table"
		or type(record.EquippedBySlot) ~= "table"
	then
		return neutral()
	end

	for _, slotId in { EquipmentRewardContracts.SlotIds.Primary, EquipmentRewardContracts.SlotIds.Secondary } do
		local instanceId = record.EquippedBySlot[slotId]
		if type(instanceId) == "string" and instanceId ~= "" then
			local reward = record.InventoryByInstanceId[instanceId]
			if type(reward) == "table" and type(reward.DefinitionId) == "string" then
				local definition = definitionsById[reward.DefinitionId]
				if definition ~= nil and definition.WeaponId == weaponId then
					local modifiers = EquipmentAffixModifierResolver.resolve(reward.Affixes)
					return table.freeze({
						damageMultiplier = modifiers.damageMultiplier,
						sourceInstanceId = instanceId,
					})
				end
			end
		end
	end

	return neutral()
end

function EquippedEquipmentModifierResolver.neutral(): ResolvedEquippedModifiers
	return neutral()
end

return table.freeze(EquippedEquipmentModifierResolver)
