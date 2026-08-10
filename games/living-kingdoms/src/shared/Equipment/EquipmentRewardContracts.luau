--!strict

-- Blueprint v1.9 reward contracts. Authored definitions remain stable content;
-- generated instances carry deterministic content and grant identities plus a
-- globally unique server-created ownership identifier.

local EquipmentAffixContracts = require(script.Parent.EquipmentAffixContracts)

export type EquipmentAffixRoll = EquipmentAffixContracts.EquipmentAffixRoll
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
	-- The combat weapon this item drives when equipped. Present on weapon slots
	-- only; armor and relic definitions carry none.
	WeaponId: string?,
}

export type EquipmentReward = {
	InstanceId: string,
	GrantId: string,
	ContentSignature: string,
	DefinitionId: string,
	DefinitionVersion: string,
	DisplayName: string,
	Slot: EquipmentSlotId,
	Rarity: EquipmentRarityId,
	Power: number,
	Affixes: { EquipmentAffixRoll },
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

-- Rarity is an ordered scale, so comparison needs one shared ranking rather than
-- each caller inventing its own. Ranks are contiguous from 1 so a difference of
-- ranks is a meaningful step count.
local RarityRanks = table.freeze({
	[RarityIds.Common] = 1,
	[RarityIds.Uncommon] = 2,
	[RarityIds.Rare] = 3,
})

return table.freeze({
	SlotIds = SlotIds,
	RarityIds = RarityIds,
	SourceIds = SourceIds,
	RarityRanks = RarityRanks,
})
