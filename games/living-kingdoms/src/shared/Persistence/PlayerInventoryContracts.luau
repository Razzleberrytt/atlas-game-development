--!strict

local EquipmentContracts = require(script.Parent.Parent.Equipment.EquipmentRewardContracts)

export type EquipmentReward = EquipmentContracts.EquipmentReward
export type EquipmentSlotId = EquipmentContracts.EquipmentSlotId

export type CharacterProgressionRecord = {
	Version: string,
	TotalXP: number,
}

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
	-- Schema 4. Content identity per applied grant.
	AppliedRewardContentSignatures: { [string]: string },
	-- Schema 5. Long-horizon character XP stored inside the existing canonical
	-- account record so inventory/session-lease ownership remains singular.
	CharacterProgression: CharacterProgressionRecord,
	-- Durable idempotency for low-frequency progression grants such as an
	-- expedition completion. High-frequency kill/assist awards should use
	-- bounded encounter/session attribution rather than growing this forever.
	AppliedCharacterProgressionGrantIds: { [string]: boolean },
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

-- Every version the loader can still read. Historical records migrate forward.
local SupportedSchemaVersions = table.freeze({ 1, 2, 3, 4, 5 })

local function isSupportedSchemaVersion(value: any): boolean
	for _, supported in SupportedSchemaVersions do
		if value == supported then
			return true
		end
	end
	return false
end

return table.freeze({
	CurrentSchemaVersion = 5,
	SupportedSchemaVersions = SupportedSchemaVersions,
	isSupportedSchemaVersion = isSupportedSchemaVersion,
})
