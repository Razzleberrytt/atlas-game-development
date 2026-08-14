--!strict

local EquipmentContracts = require(script.Parent.Parent.Equipment.EquipmentRewardContracts)

export type EquipmentReward = EquipmentContracts.EquipmentReward
export type EquipmentSlotId = EquipmentContracts.EquipmentSlotId

-- What a dismantle destroyed. Recorded so a replayed transaction can be answered
-- after a rejoin without consulting the item, which no longer exists.
export type DismantleOutcome = {
	InstanceId: string,
	SalvagedDefinitionId: string,
	SalvagedRarity: string,
	SalvagedPower: number,
}

export type PlayerInventoryRecord = {
	SchemaVersion: number,
	PlayerId: number,
	InventoryByInstanceId: { [string]: EquipmentReward },
	EquippedBySlot: { [EquipmentSlotId]: string? },
	AppliedRewardInstanceIds: { [string]: boolean },
	AppliedRewardGrantIds: { [string]: boolean },
	-- Schema 3. Idempotency ledger for dismantle, keyed by transaction id.
	AppliedDismantleTransactions: { [string]: DismantleOutcome },
	--[[
		Schema 4. Content identity per applied grant. AppliedRewardGrantIds can
		only say an id was used; this says what it was used for, so a repeat with
		different content reads as a conflict instead of a successful retry.
	]]
	AppliedRewardContentSignatures: { [string]: string },
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

--[[
	Every version the loader can still read. A record saved at any of these must
	load and migrate forward; dropping one strands live inventories, so this list
	only ever grows until a migration is proven to have retired a version.
]]
local SupportedSchemaVersions = table.freeze({ 1, 2, 3, 4 })

local function isSupportedSchemaVersion(value: any): boolean
	for _, supported in SupportedSchemaVersions do
		if value == supported then
			return true
		end
	end
	return false
end

return table.freeze({
	CurrentSchemaVersion = 4,
	SupportedSchemaVersions = SupportedSchemaVersions,
	isSupportedSchemaVersion = isSupportedSchemaVersion,
})
