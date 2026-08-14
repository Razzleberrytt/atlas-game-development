--!strict

--[[
	Patch 0.7 corruption classification and quarantine contract.

	A load that fails is not one thing. A read that exhausted its retries will
	very likely succeed in a minute; a record whose equipped slot names an item
	the player does not own will never fix itself. Treating those alike means
	either retrying forever on corruption or giving up permanently on a blip.

	Quarantine exists because the alternative to a corrupt record is not a good
	record -- it is no record. Copying the damaged payload aside preserves the
	evidence, and the source is deliberately never rewritten: whatever is wrong
	with it, it is still the only thing the player has.
]]

export type Classification = "Transient" | "Corrupt"

local InventoryRecoveryContracts = {}

InventoryRecoveryContracts.Classifications = table.freeze({
	Transient = "Transient" :: Classification,
	Corrupt = "Corrupt" :: Classification,
})

--[[
	Transient reasons describe the storage layer failing to answer. Corrupt
	reasons describe an answer that cannot be trusted. Anything unrecognised is
	treated as corrupt, because a reason nobody classified is not evidence that
	retrying is safe.
]]
local TRANSIENT_REASON_IDS = table.freeze({
	LoadFailed = true,
	SaveFailed = true,
	StorageUpdateFailed = true,
	UnreconciledRead = true,
})

local CORRUPT_REASON_IDS = table.freeze({
	InvalidSavedRecord = true,
	UnsupportedSchemaVersion = true,
	PlayerIdMismatch = true,
	InvalidInventoryReward = true,
	InvalidAppliedRewardIndex = true,
	InvalidAppliedGrantIndex = true,
	InvalidDismantleLedger = true,
	InvalidRewardSignatureLedger = true,
	EquippedItemMismatch = true,
	SchemaDowngradeNotAuthored = true,
	MissingMigrationStep = true,
})

function InventoryRecoveryContracts.classify(reasonId: any): Classification
	if type(reasonId) == "string" and TRANSIENT_REASON_IDS[reasonId] == true then
		return InventoryRecoveryContracts.Classifications.Transient
	end
	return InventoryRecoveryContracts.Classifications.Corrupt
end

function InventoryRecoveryContracts.isRecoverable(reasonId: any): boolean
	return InventoryRecoveryContracts.classify(reasonId) == InventoryRecoveryContracts.Classifications.Transient
end

function InventoryRecoveryContracts.isClassified(reasonId: any): boolean
	return type(reasonId) == "string"
		and (TRANSIENT_REASON_IDS[reasonId] == true or CORRUPT_REASON_IDS[reasonId] == true)
end

--[[
	Quarantine keys are derived, never authored, so a damaged record always lands
	somewhere an operator can find from the player id alone.
]]
function InventoryRecoveryContracts.quarantineKeyFor(sourceKey: string, nowUnix: number): string
	assert(type(sourceKey) == "string" and sourceKey ~= "", "quarantine requires a source key")
	assert(type(nowUnix) == "number" and nowUnix % 1 == 0 and nowUnix >= 0, "quarantine requires an integer timestamp")
	return string.format("quarantine:%s:%d", sourceKey, nowUnix)
end

function InventoryRecoveryContracts.quarantineEnvelope(
	sourceKey: string,
	reasonId: string,
	nowUnix: number,
	payload: any
): any
	return table.freeze({
		SourceKey = sourceKey,
		ReasonId = reasonId,
		Classification = InventoryRecoveryContracts.classify(reasonId),
		QuarantinedAtUnix = nowUnix,
		Payload = payload,
	})
end

return table.freeze(InventoryRecoveryContracts)
