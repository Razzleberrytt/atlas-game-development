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

export type Classification = "Transient" | "Operational" | "Corrupt"

local InventoryRecoveryContracts = {}

InventoryRecoveryContracts.Classifications = table.freeze({
	Transient = "Transient" :: Classification,
	Operational = "Operational" :: Classification,
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
	LeaseStoreFailed = true,
	LeaseLost = true,
	--[[
		A lost migration race is entirely retryable: another server simply wrote
		first, and the next load reads what it wrote. Classing it as corruption
		would tell a caller not to retry the one thing that fixes it.
	]]
	MigrationRaceDetected = true,
})

--[[
	Operational reasons are ordinary refusals: the request was understood and
	declined, or a bound was reached. Retrying the same request will fail the
	same way, but nothing is damaged. Folding these into either other class
	would be wrong in both directions -- a caller would either retry forever or
	quarantine a perfectly good record because a player asked for something twice.
]]
local OPERATIONAL_REASON_IDS = table.freeze({
	ServiceDestroyed = true,
	PlayerNotLoaded = true,
	InventoryNotLoaded = true,
	InvalidLoadRequest = true,
	InvalidReleaseRequest = true,
	InvalidEquipRequest = true,
	InvalidUnequipRequest = true,
	InvalidDismantleRequest = true,
	InvalidAcquireRequest = true,
	InvalidRenewRequest = true,
	InvalidPlayerIdentity = true,
	LeaseNotOwned = true,
	LeaseHeldByAnotherServer = true,
	LeaseAlreadyHeld = true,
	DismantleRateLimited = true,
	RateLimited = true,
	StaleDismantleRequest = true,
	NoActiveExpedition = true,
	InvalidCandidateItem = true,
	InvalidReward = true,
	ItemNotOwned = true,
	ItemEquipped = true,
	SlotMismatch = true,
	CrossPlayerInventoryAccess = true,
	SessionLeaseRequired = true,
	RewardAlreadyApplied = true,
	RewardGrantConflict = true,
	TransactionAlreadyApplied = true,
	RecordSizeExceeded = true,
	MutationLedgerBoundExceeded = true,
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
	--[[
		A record whose stored owner is not the player who asked for it is damage,
		not a refusal: something wrote the wrong identity into durable state.
	]]
	InventoryOwnerMismatch = true,
	LeaseRecordMalformed = true,
})

function InventoryRecoveryContracts.classify(reasonId: any): Classification
	if type(reasonId) ~= "string" then
		return InventoryRecoveryContracts.Classifications.Corrupt
	end
	if TRANSIENT_REASON_IDS[reasonId] == true then
		return InventoryRecoveryContracts.Classifications.Transient
	end
	if OPERATIONAL_REASON_IDS[reasonId] == true then
		return InventoryRecoveryContracts.Classifications.Operational
	end
	return InventoryRecoveryContracts.Classifications.Corrupt
end

function InventoryRecoveryContracts.isRecoverable(reasonId: any): boolean
	return InventoryRecoveryContracts.classify(reasonId) == InventoryRecoveryContracts.Classifications.Transient
end

function InventoryRecoveryContracts.isClassified(reasonId: any): boolean
	return type(reasonId) == "string"
		and (
			TRANSIENT_REASON_IDS[reasonId] == true
			or OPERATIONAL_REASON_IDS[reasonId] == true
			or CORRUPT_REASON_IDS[reasonId] == true
		)
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
