--!strict

--[[
	VS-0109 versioned player inventory/equipment persistence contracts.
	Saved data is server-authored and validated before use. Clients may request
	presentation or equip intent later, but they never supply authoritative records.
]]

local EquipmentContracts = require(script.Parent.Parent.Equipment.EquipmentRewardContracts)

export type EquipmentReward = EquipmentContracts.EquipmentReward
export type EquipmentSlotId = EquipmentContracts.EquipmentSlotId

export type PlayerInventoryRecord = {
	SchemaVersion: number,
	PlayerId: number,
	InventoryByInstanceId: { [string]: EquipmentReward },
	EquippedBySlot: { [EquipmentSlotId]: string? },
	AppliedRewardInstanceIds: { [string]: boolean },
	UpdatedAtUnix: number,
}

export type LoadResult = {
	Accepted: boolean,
	ReasonId: string,
	Record: PlayerInventoryRecord?,
	Migrated: boolean,
}

export type MutationResult = {
	Accepted: boolean,
	ReasonId: string,
	Record: PlayerInventoryRecord?,
}

return table.freeze({
	CurrentSchemaVersion = 1,
})
