--!strict

local EquipmentContracts = require(script.Parent.Parent.Equipment.EquipmentRewardContracts)
local Contracts = require(script.Parent.PlayerInventoryContracts)

export type EquipmentAffixRoll = EquipmentContracts.EquipmentAffixRoll
export type EquipmentSlotId = EquipmentContracts.EquipmentSlotId
export type EquipmentRarityId = EquipmentContracts.EquipmentRarityId
export type RewardSourceId = EquipmentContracts.RewardSourceId
export type PlayerInventoryRecord = Contracts.PlayerInventoryRecord

export type InventoryItemView = {
	InstanceId: string,
	ContentSignature: string,
	DefinitionId: string,
	DefinitionVersion: string,
	DisplayName: string,
	Slot: EquipmentSlotId,
	Rarity: EquipmentRarityId,
	Power: number,
	Affixes: { EquipmentAffixRoll },
	SourceId: RewardSourceId,
	Equipped: boolean,
}

export type PlayerInventorySnapshot = {
	OwnerId: number,
	SchemaVersion: number,
	UpdatedAtUnix: number,
	ItemCount: number,
	Items: { InventoryItemView },
	EquippedBySlot: { [EquipmentSlotId]: string? },
}

export type SnapshotResult = {
	Accepted: boolean,
	ReasonId: string,
	Snapshot: PlayerInventorySnapshot?,
}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0 and value > 0
end

local function reject(reasonId: string): SnapshotResult
	return table.freeze({ Accepted = false, ReasonId = reasonId, Snapshot = nil })
end

local function copyAffixes(affixes: { EquipmentAffixRoll }?): { EquipmentAffixRoll }
	local copied = {}
	-- Persistence normalizes pre-affix records on load, but the disclosure
	-- boundary remains defensive so legacy/synthetic records cannot crash an
	-- owner-only read. Missing affix data has the same meaning as zero affixes.
	for _, affix in affixes or {} do
		table.insert(
			copied,
			table.freeze({
				Id = affix.Id,
				Version = affix.Version,
				DisplayName = affix.DisplayName,
				EffectId = affix.EffectId,
				Value = affix.Value,
			})
		)
	end
	return table.freeze(copied)
end

local function sortedInstanceIds(record: PlayerInventoryRecord): { string }
	local instanceIds = {}
	for instanceId in record.InventoryByInstanceId do
		table.insert(instanceIds, instanceId)
	end
	table.sort(instanceIds)
	return instanceIds
end

local PlayerInventorySnapshot = {}

function PlayerInventorySnapshot.forOwner(
	requesterId: number,
	ownerId: number,
	record: PlayerInventoryRecord?
): SnapshotResult
	if not isPositiveInteger(requesterId) or not isPositiveInteger(ownerId) then
		return reject("InvalidPlayerIdentity")
	end
	if requesterId ~= ownerId then
		return reject("CrossPlayerInventoryAccess")
	end
	if record == nil then
		return reject("InventoryNotLoaded")
	end
	if record.PlayerId ~= ownerId then
		return reject("InventoryOwnerMismatch")
	end

	local equipped = table.clone(record.EquippedBySlot)
	local items = {}
	for _, instanceId in sortedInstanceIds(record) do
		local reward = record.InventoryByInstanceId[instanceId]
		table.insert(
			items,
			table.freeze({
				InstanceId = reward.InstanceId,
				ContentSignature = reward.ContentSignature,
				DefinitionId = reward.DefinitionId,
				DefinitionVersion = reward.DefinitionVersion,
				DisplayName = reward.DisplayName,
				Slot = reward.Slot,
				Rarity = reward.Rarity,
				Power = reward.Power,
				Affixes = copyAffixes(reward.Affixes),
				SourceId = reward.SourceId,
				Equipped = equipped[reward.Slot] == reward.InstanceId,
			})
		)
	end

	return table.freeze({
		Accepted = true,
		ReasonId = "InventoryDisclosed",
		Snapshot = table.freeze({
			OwnerId = ownerId,
			SchemaVersion = record.SchemaVersion,
			UpdatedAtUnix = record.UpdatedAtUnix,
			ItemCount = #items,
			Items = table.freeze(items),
			EquippedBySlot = table.freeze(equipped),
		}),
	})
end

return table.freeze(PlayerInventorySnapshot)
