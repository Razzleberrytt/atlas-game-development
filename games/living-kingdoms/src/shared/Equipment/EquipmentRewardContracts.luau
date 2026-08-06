--!strict

-- Blueprint v1.9 reward contracts. Authored definitions remain stable content;
-- generated instances carry both a deterministic content signature for replay
-- diagnostics and a globally unique server-created ownership identifier.

export type EquipmentSlotId = "Primary" | "Secondary" | "Armor" | "Relic"
export type EquipmentRarityId = "Common" | "Uncommon" | "Rare"
export type RewardSourceId = "Elite" | "Boss"

export type EquipmentDefinition = {
	Id: string,
	Version: string,
	DisplayName: string,
	Slot: EquipmentSlotId,
	MinimumPower: number,
	MaximumPower: number,
	AllowedRarities: { EquipmentRarityId },
	Tags: { string },
}

export type EquipmentReward = {
	InstanceId: string,
	ContentSignature: string,
	DefinitionId: string,
	DefinitionVersion: string,
	DisplayName: string,
	Slot: EquipmentSlotId,
	Rarity: EquipmentRarityId,
	Power: number,
	SourceId: RewardSourceId,
	RunId: string,
	Seed: number,
}

export type RewardClaimResult = {
	Accepted: boolean,
	ReasonId: string,
	Reward: EquipmentReward?,
}

local SlotIds = table.freeze({
	Primary = "Primary" :: EquipmentSlotId,
	Secondary = "Secondary" :: EquipmentSlotId,
	Armor = "Armor" :: EquipmentSlotId,
	Relic = "Relic" :: EquipmentSlotId,
})

local RarityIds = table.freeze({
	Common = "Common" :: EquipmentRarityId,
	Uncommon = "Uncommon" :: EquipmentRarityId,
	Rare = "Rare" :: EquipmentRarityId,
})

local SourceIds = table.freeze({
	Elite = "Elite" :: RewardSourceId,
	Boss = "Boss" :: RewardSourceId,
})

return table.freeze({
	SlotIds = SlotIds,
	RarityIds = RarityIds,
	SourceIds = SourceIds,
})
