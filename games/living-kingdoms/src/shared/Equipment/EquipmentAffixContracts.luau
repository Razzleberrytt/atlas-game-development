--!strict

-- Patch 0.3 deterministic equipment-affix vocabulary. Affixes are content
-- metadata owned by the existing equipment reward/inventory path; this module
-- does not create a second inventory, reward, persistence, or combat authority.

export type EquipmentAffixEffectId =
	"DamagePercent"
	| "ReloadSpeedPercent"
	| "MaxHealthPercent"
	| "MoveSpeedPercent"
	| "AbilityHastePercent"
	| "AbilityPowerPercent"

export type EquipmentAffixDefinition = {
	Id: string,
	Version: string,
	DisplayName: string,
	EffectId: EquipmentAffixEffectId,
	MinimumValue: number,
	MaximumValue: number,
	AllowedSlots: { string },
	RequiredTags: { string },
}

export type EquipmentAffixRoll = {
	Id: string,
	Version: string,
	DisplayName: string,
	EffectId: EquipmentAffixEffectId,
	Value: number,
}

export type EquipmentAffixResolution = {
	Accepted: boolean,
	ReasonId: string,
	Affixes: { EquipmentAffixRoll },
	Signature: string,
}

local EffectIds = table.freeze({
	DamagePercent = "DamagePercent" :: EquipmentAffixEffectId,
	ReloadSpeedPercent = "ReloadSpeedPercent" :: EquipmentAffixEffectId,
	MaxHealthPercent = "MaxHealthPercent" :: EquipmentAffixEffectId,
	MoveSpeedPercent = "MoveSpeedPercent" :: EquipmentAffixEffectId,
	AbilityHastePercent = "AbilityHastePercent" :: EquipmentAffixEffectId,
	AbilityPowerPercent = "AbilityPowerPercent" :: EquipmentAffixEffectId,
})

local ReasonIds = table.freeze({
	Resolved = "Resolved",
	InvalidConfig = "InvalidConfig",
	InvalidContext = "InvalidContext",
	InsufficientEligibleAffixes = "InsufficientEligibleAffixes",
})

return table.freeze({
	EffectIds = EffectIds,
	ReasonIds = ReasonIds,
})
