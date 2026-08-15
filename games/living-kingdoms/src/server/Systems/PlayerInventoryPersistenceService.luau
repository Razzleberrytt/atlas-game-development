--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Persistence.PlayerInventoryContracts)
local InventoryDismantleResolver = require(ReplicatedStorage.Shared.Persistence.InventoryDismantleResolver)
local EquipmentContracts = require(ReplicatedStorage.Shared.Equipment.EquipmentRewardContracts)
local EquipmentAffixContracts = require(ReplicatedStorage.Shared.Equipment.EquipmentAffixContracts)
local StorageResults = require(ReplicatedStorage.Shared.Persistence.StorageResultContracts)
local DurableMutation = require(ReplicatedStorage.Shared.Persistence.DurableMutationContracts)
local MigrationSteps = require(ReplicatedStorage.Shared.Persistence.InventoryMigrationSteps)
local Recovery = require(ReplicatedStorage.Shared.Persistence.InventoryRecoveryContracts)
local Capacity = require(ReplicatedStorage.Shared.Persistence.InventoryCapacityContracts)

export type EquipmentReward = EquipmentContracts.EquipmentReward
export type EquipmentAffixRoll = EquipmentContracts.EquipmentAffixRoll
export type EquipmentSlotId = EquipmentContracts.EquipmentSlotId
export type PlayerInventoryRecord = Contracts.PlayerInventoryRecord
export type LoadResult = Contracts.LoadResult
export type MutationResult = Contracts.MutationResult

export type Store = {
	read: (self: Store, key: string) -> StorageResults.ReadResult,
	write: (self: Store, key: string, value: any) -> StorageResults.WriteResult,
	commit: (self: Store, key: string, transform: (any) -> any) -> StorageResults.WriteResult,
}

export type Service = {
	loadPlayer: (self: Service, playerId: number, nowUnix: number) -> LoadResult,
	applyReward: (self: Service, playerId: number, reward: EquipmentReward, nowUnix: number) -> MutationResult,
	applyCharacterProgression: (
		self: Service,
		playerId: number,
		progressionState: any,
		grantId: string?,
		nowUnix: number
	) -> MutationResult,
	equip: (self: Service, playerId: number, slotId: EquipmentSlotId, instanceId: string, nowUnix: number) -> MutationResult,
	dismantle: (
		self: Service,
		playerId: number,
		instanceId: string,
		transactionId: string,
		nowUnix: number,
		hasSessionLease: boolean,
		recentRequestTimestamps: { number }
	) -> any,
	getRecord: (self: Service, playerId: number) -> PlayerInventoryRecord?,
	releasePlayer: (self: Service, playerId: number) -> any,
	destroy: (self: Service) -> (),
}

local CURRENT_SCHEMA = Contracts.CurrentSchemaVersion
local VALID_SLOTS = EquipmentContracts.SlotIds
local VALID_RARITIES = EquipmentContracts.RarityIds
local VALID_SOURCES = EquipmentContracts.SourceIds
local VALID_AFFIX_EFFECTS = EquipmentAffixContracts.EffectIds
local CHARACTER_PROGRESSION_VERSION = "CHARACTER-XP-v1"

local Service = {}
Service.__index = Service

local function keyFor(playerId: number): string
	return string.format("player:%d:inventory", playerId)
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isKnownValue(container: any, value: any): boolean
	for _, candidate in container do
		if candidate == value then
			return true
		end
	end
	return false
end

local function normalizedCharacterProgression(value: any): any
	local raw = if type(value) == "table" then value else {}
	local totalXP = raw.TotalXP
	if totalXP == nil then
		totalXP = raw.CharacterTotalXP or raw.Experience or raw.XP or raw.TotalExperience
	end
	if not isFiniteNumber(totalXP) or totalXP < 0 then
		totalXP = 0
	end
	return table.freeze({
		Version = if type(raw.Version) == "string" and raw.Version ~= "" then raw.Version else CHARACTER_PROGRESSION_VERSION,
		TotalXP = math.floor(totalXP),
	})
end

local function normalizedAffixes(value: any): { EquipmentAffixRoll }?
	if value == nil then
		return table.freeze({})
	end
	if type(value) ~= "table" then
		return nil
	end
	local normalized = {}
	local seenIds = {}
	for index, rawAffix in value do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or type(rawAffix) ~= "table" then
			return nil
		end
		if
			type(rawAffix.Id) ~= "string"
			or #rawAffix.Id < 1
			or type(rawAffix.Version) ~= "string"
			or #rawAffix.Version < 1
			or type(rawAffix.DisplayName) ~= "string"
			or #rawAffix.DisplayName < 1
			or not isKnownValue(VALID_AFFIX_EFFECTS, rawAffix.EffectId)
			or not isInteger(rawAffix.Value)
			or seenIds[rawAffix.Id] == true
		then
			return nil
		end
		seenIds[rawAffix.Id] = true
		table.insert(normalized, table.freeze({
			Id = rawAffix.Id,
			Version = rawAffix.Version,
			DisplayName = rawAffix.DisplayName,
			EffectId = rawAffix.EffectId,
			Value = rawAffix.Value,
		}))
	end
	if #normalized ~= #value then
		return nil
	end
	return table.freeze(normalized)
end

local function normalizedReward(value: any): EquipmentReward?
	if type(value) ~= "table" or type(value.InstanceId) ~= "string" or #value.InstanceId < 8 then
		return nil
	end
	if type(value.DefinitionId) ~= "string" or type(value.DefinitionVersion) ~= "string" or type(value.DisplayName) ~= "string" then
		return nil
	end
	if not isKnownValue(VALID_SLOTS, value.Slot) or not isKnownValue(VALID_RARITIES, value.Rarity) then
		return nil
	end
	if not isInteger(value.Power) or value.Power < 1 or not isKnownValue(VALID_SOURCES, value.SourceId) then
		return nil
	end
	if type(value.RunId) ~= "string" or not isInteger(value.Seed) then
		return nil
	end
	local affixes = normalizedAffixes(value.Affixes)
	if affixes == nil then
		return nil
	end
	local grantId = value.GrantId
	if type(grantId) ~= "string" or #grantId < 8 then
		grantId = string.format("reward:%s:%s", value.RunId, value.SourceId)
	end
	local signature = value.ContentSignature
	if type(signature) ~= "string" or #signature < 3 then
		signature = "legacy|" .. value.InstanceId
	end
	return table.freeze({
		InstanceId = value.InstanceId,
		GrantId = grantId,
		ContentSignature = signature,
		DefinitionId = value.DefinitionId,
		DefinitionVersion = value.DefinitionVersion,
		DisplayName = value.DisplayName,
		Slot = value.Slot,
		Rarity = value.Rarity,
		Power = value.Power,
		Affixes = affixes,
		SourceId = value.SourceId,
		RunId = value.RunId,
		Seed = value.Seed,
	})
end

local function newRecord(playerId: number, nowUnix: number): PlayerInventoryRecord
	return {
		SchemaVersion = CURRENT_SCHEMA,
		PlayerId = playerId,
		InventoryByInstanceId = {},
		EquippedBySlot = {},
		AppliedRewardInstanceIds = {},
		AppliedRewardGrantIds = {},
		AppliedDismantleTransactions = {},
		AppliedRewardContentSignatures = {},
		CharacterProgression = normalizedCharacterProgression(nil),
		AppliedCharacterProgressionGrantIds = {},
		UpdatedAtUnix = nowUnix,
	}
end

local function mutableCopy(record: PlayerInventoryRecord, nowUnix: number): PlayerInventoryRecord
	return {
		SchemaVersion = CURRENT_SCHEMA,
		PlayerId = record.PlayerId,
		InventoryByInstanceId = table.clone(record.InventoryByInstanceId),
		EquippedBySlot = table.clone(record.EquippedBySlot),
		AppliedRewardInstanceIds = table.clone(record.AppliedRewardInstanceIds),
		AppliedRewardGrantIds = table.clone(record.AppliedRewardGrantIds),
		AppliedDismantleTransactions = table.clone(record.AppliedDismantleTransactions or {}),
		AppliedRewardContentSignatures = table.clone(record.AppliedRewardContentSignatures or {}),
		CharacterProgression = normalizedCharacterProgression(record.CharacterProgression),
		AppliedCharacterProgressionGrantIds = table.clone(record.AppliedCharacterProgressionGrantIds or {}),
		UpdatedAtUnix = nowUnix,
	}
end

local function cloneRecord(record: PlayerInventoryRecord): PlayerInventoryRecord
	return table.freeze({
		SchemaVersion = record.SchemaVersion,
		PlayerId = record.PlayerId,
		InventoryByInstanceId = table.freeze(table.clone(record.InventoryByInstanceId)),
		EquippedBySlot = table.freeze(table.clone(record.EquippedBySlot)),
		AppliedRewardInstanceIds = table.freeze(table.clone(record.AppliedRewardInstanceIds)),
		AppliedRewardGrantIds = table.freeze(table.clone(record.AppliedRewardGrantIds)),
		AppliedDismantleTransactions = table.freeze(table.clone(record.AppliedDismantleTransactions or {})),
		AppliedRewardContentSignatures = table.freeze(table.clone(record.AppliedRewardContentSignatures or {})),
		CharacterProgression = table.freeze(table.clone(record.CharacterProgression)),
		AppliedCharacterProgressionGrantIds = table.freeze(table.clone(record.AppliedCharacterProgressionGrantIds or {})),
		UpdatedAtUnix = record.UpdatedAtUnix,
	})
end

local function normalizeRecord(raw: any, playerId: number, nowUnix: number): (PlayerInventoryRecord?, boolean, string)
	if raw == nil then
		return newRecord(playerId, nowUnix), true, "CreatedNewRecord"
	end
	if type(raw) ~= "table" then
		return nil, false, "InvalidSavedRecord"
	end
	local schema = raw.SchemaVersion
	if schema ~= nil and not Contracts.isSupportedSchemaVersion(schema) then
		return nil, false, "UnsupportedSchemaVersion"
	end
	if raw.PlayerId ~= nil and raw.PlayerId ~= playerId then
		return nil, false, "PlayerIdMismatch"
	end
	if type(raw.InventoryByInstanceId or {}) ~= "table" or type(raw.EquippedBySlot or {}) ~= "table" then
		return nil, false, "InvalidSavedRecord"
	end

	local migrated = schema ~= CURRENT_SCHEMA
	local record = newRecord(playerId, nowUnix)
	for instanceId, rawReward in raw.InventoryByInstanceId or {} do
		local reward = normalizedReward(rawReward)
		if reward == nil or reward.InstanceId ~= instanceId then
			return nil, false, "InvalidInventoryReward"
		end
		record.InventoryByInstanceId[instanceId] = reward
		record.AppliedRewardInstanceIds[instanceId] = true
		record.AppliedRewardGrantIds[reward.GrantId] = true
	end
	for instanceId, applied in raw.AppliedRewardInstanceIds or {} do
		if type(instanceId) ~= "string" or applied ~= true then
			return nil, false, "InvalidAppliedRewardIndex"
		end
		record.AppliedRewardInstanceIds[instanceId] = true
	end
	for grantId, applied in raw.AppliedRewardGrantIds or {} do
		if type(grantId) ~= "string" or applied ~= true then
			return nil, false, "InvalidAppliedGrantIndex"
		end
		record.AppliedRewardGrantIds[grantId] = true
	end
	for transactionId, outcome in raw.AppliedDismantleTransactions or {} do
		if type(transactionId) ~= "string" or type(outcome) ~= "table" then
			return nil, false, "InvalidDismantleLedger"
		end
		if
			not DurableMutation.isValidTransactionId(transactionId)
			or type(outcome.InstanceId) ~= "string"
			or #outcome.InstanceId < 8
			or type(outcome.SalvagedDefinitionId) ~= "string"
			or #outcome.SalvagedDefinitionId < 1
			or type(outcome.SalvagedRarity) ~= "string"
			or not isKnownValue(VALID_RARITIES, outcome.SalvagedRarity)
			or not isInteger(outcome.SalvagedPower)
			or outcome.SalvagedPower < 0
		then
			return nil, false, "InvalidDismantleLedger"
		end
		record.AppliedDismantleTransactions[transactionId] = table.freeze({
			InstanceId = outcome.InstanceId,
			SalvagedDefinitionId = outcome.SalvagedDefinitionId,
			SalvagedRarity = outcome.SalvagedRarity,
			SalvagedPower = outcome.SalvagedPower,
		})
	end
	for grantId, signature in raw.AppliedRewardContentSignatures or {} do
		if type(grantId) ~= "string" or not DurableMutation.isValidContentIdentity(signature) then
			return nil, false, "InvalidRewardSignatureLedger"
		end
		if record.AppliedRewardGrantIds[grantId] ~= true then
			return nil, false, "InvalidRewardSignatureLedger"
		end
		record.AppliedRewardContentSignatures[grantId] = signature
	end
	for slotId, instanceId in raw.EquippedBySlot or {} do
		local reward = record.InventoryByInstanceId[instanceId]
		if not isKnownValue(VALID_SLOTS, slotId) or reward == nil or reward.Slot ~= slotId then
			return nil, false, "EquippedItemMismatch"
		end
		record.EquippedBySlot[slotId] = instanceId
	end

	record.CharacterProgression = normalizedCharacterProgression(raw.CharacterProgression or raw)
	for grantId, applied in raw.AppliedCharacterProgressionGrantIds or {} do
		if type(grantId) ~= "string" or #grantId < 8 or applied ~= true then
			return nil, false, "InvalidCharacterProgressionGrantLedger"
		end
		record.AppliedCharacterProgressionGrantIds[grantId] = true
	end
	return record, migrated, if migrated then "MigratedRecord" else "LoadedRecord"
end

local function result(accepted: boolean, reasonId: string, record: PlayerInventoryRecord?): any
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Record = record })
end

local function guardedWrite(store: any, key: string, record: PlayerInventoryRecord): (boolean, string)
	local classification, bytes = Capacity.classify(record)
	if classification == Capacity.SizeClassifications.Exceeded then
		warn(string.format(
			"[AtlasPersistence] refusing write for %s: estimated %d bytes exceeds the %d byte budget",
			key,
			bytes,
			Capacity.SafeRecordByteLimit
		))
		return false, "RecordSizeExceeded"
	end
	if classification == Capacity.SizeClassifications.Approaching then
		warn(string.format("[AtlasPersistence] %s is approaching the record budget at %d bytes", key, bytes))
	end
	if store:write(key, record).Status ~= StorageResults.WriteStatuses.Committed then
		return false, "SaveFailed"
	end
	return true, "Committed"
end

function Service.new(store: Store): Service
	assert(type(store) == "table" and type(store.read) == "function" and type(store.write) == "function" and type(store.commit) == "function", "invalid store")
	return setmetatable({ _store = store, _records = {}, _destroyed = false }, Service) :: any
end

function Service:loadPlayer(playerId: number, nowUnix: number): LoadResult
	local selfAny = self :: any
	if selfAny._destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Record = nil, Migrated = false })
	end
	if not isInteger(playerId) or playerId <= 0 or type(nowUnix) ~= "number" or nowUnix < 0 then
		return table.freeze({ Accepted = false, ReasonId = "InvalidLoadRequest", Record = nil, Migrated = false })
	end
	local readResult = selfAny._store:read(keyFor(playerId))
	if readResult.Status == StorageResults.ReadStatuses.Failed then
		return table.freeze({ Accepted = false, ReasonId = "LoadFailed", Record = nil, Migrated = false })
	end
	local key = keyFor(playerId)
	local sourceSchema = if type(readResult.Value) == "table" then readResult.Value.SchemaVersion else nil
	local normalized, migrated, reasonId = normalizeRecord(readResult.Value, playerId, nowUnix)
	if normalized == nil then
		self:_quarantine(key, reasonId, nowUnix, readResult.Value)
		return table.freeze({ Accepted = false, ReasonId = reasonId, Record = nil, Migrated = false, Classification = Recovery.classify(reasonId) })
	end
	local plan = MigrationSteps.plan(sourceSchema or CURRENT_SCHEMA, CURRENT_SCHEMA)
	if not plan.Accepted then
		self:_quarantine(key, plan.ReasonId, nowUnix, readResult.Value)
		return table.freeze({ Accepted = false, ReasonId = plan.ReasonId, Record = nil, Migrated = false, Classification = Recovery.classify(plan.ReasonId) })
	end
	if migrated then
		local reconciled = true
		local write = selfAny._store:commit(key, function(current: any): any
			if current ~= nil and type(current) == "table" and current.UpdatedAtUnix ~= nil then
				if type(readResult.Value) ~= "table" or current.UpdatedAtUnix ~= readResult.Value.UpdatedAtUnix or current.SchemaVersion ~= sourceSchema then
					reconciled = false
					return current
				end
			end
			reconciled = true
			return normalized
		end)
		if not reconciled then
			return table.freeze({ Accepted = false, ReasonId = "MigrationRaceDetected", Record = nil, Migrated = false, Classification = Recovery.Classifications.Transient })
		end
		if write.Status ~= StorageResults.WriteStatuses.Committed then
			return table.freeze({ Accepted = false, ReasonId = "SaveFailed", Record = nil, Migrated = false, Classification = Recovery.Classifications.Transient })
		end
	end
	selfAny._records[playerId] = normalized
	return table.freeze({ Accepted = true, ReasonId = reasonId, Record = cloneRecord(normalized), Migrated = migrated, MigrationStepIds = plan.StepIds })
end

function Service:_quarantine(sourceKey: string, reasonId: string, nowUnix: number, payload: any)
	local selfAny = self :: any
	if payload == nil or Recovery.isRecoverable(reasonId) then
		return
	end
	local quarantineKey = Recovery.quarantineKeyFor(sourceKey, math.floor(nowUnix))
	local envelope = Recovery.quarantineEnvelope(sourceKey, reasonId, math.floor(nowUnix), payload)
	local ok = pcall(function()
		selfAny._store:write(quarantineKey, envelope)
	end)
	if not ok then
		warn(string.format("[AtlasPersistence] failed to quarantine %s (%s)", sourceKey, reasonId))
	end
end

function Service:applyReward(playerId: number, reward: EquipmentReward, nowUnix: number): MutationResult
	local selfAny = self :: any
	if selfAny._destroyed then return result(false, "ServiceDestroyed", nil) end
	local record: PlayerInventoryRecord? = selfAny._records[playerId]
	if record == nil then return result(false, "PlayerNotLoaded", nil) end
	local normalized = normalizedReward(reward)
	if normalized == nil or type(nowUnix) ~= "number" or nowUnix < record.UpdatedAtUnix then return result(false, "InvalidReward", cloneRecord(record)) end
	if record.AppliedRewardGrantIds[normalized.GrantId] then
		local knownSignature = record.AppliedRewardContentSignatures[normalized.GrantId]
		if knownSignature ~= nil and knownSignature ~= normalized.ContentSignature then return result(false, "RewardGrantConflict", cloneRecord(record)) end
		return result(false, "RewardAlreadyApplied", cloneRecord(record))
	end
	if record.AppliedRewardInstanceIds[normalized.InstanceId] then return result(false, "RewardAlreadyApplied", cloneRecord(record)) end
	local nextRecord = mutableCopy(record, nowUnix)
	nextRecord.InventoryByInstanceId[normalized.InstanceId] = normalized
	nextRecord.AppliedRewardInstanceIds[normalized.InstanceId] = true
	nextRecord.AppliedRewardGrantIds[normalized.GrantId] = true
	nextRecord.AppliedRewardContentSignatures[normalized.GrantId] = normalized.ContentSignature
	if DurableMutation.exceedsBound(nextRecord.AppliedRewardGrantIds) or DurableMutation.exceedsBound(nextRecord.AppliedDismantleTransactions) or DurableMutation.exceedsBound(nextRecord.AppliedCharacterProgressionGrantIds) then
		return result(false, "MutationLedgerBoundExceeded", cloneRecord(record))
	end
	local written, writeReason = guardedWrite(selfAny._store, keyFor(playerId), nextRecord)
	if not written then return result(false, writeReason, cloneRecord(record)) end
	selfAny._records[playerId] = nextRecord
	return result(true, "RewardApplied", cloneRecord(nextRecord))
end

function Service:applyCharacterProgression(playerId: number, progressionState: any, grantId: string?, nowUnix: number): MutationResult
	local selfAny = self :: any
	if selfAny._destroyed then return result(false, "ServiceDestroyed", nil) end
	local record: PlayerInventoryRecord? = selfAny._records[playerId]
	if record == nil then return result(false, "PlayerNotLoaded", nil) end
	if type(nowUnix) ~= "number" or nowUnix < record.UpdatedAtUnix then return result(false, "InvalidCharacterProgressionRequest", cloneRecord(record)) end
	if grantId ~= nil and (type(grantId) ~= "string" or #grantId < 8) then return result(false, "InvalidCharacterProgressionGrantId", cloneRecord(record)) end
	if grantId ~= nil and record.AppliedCharacterProgressionGrantIds[grantId] then return result(false, "CharacterProgressionGrantAlreadyApplied", cloneRecord(record)) end
	local normalized = normalizedCharacterProgression(progressionState)
	local previous = normalizedCharacterProgression(record.CharacterProgression)
	if normalized.TotalXP < previous.TotalXP then return result(false, "CharacterProgressionRollbackRejected", cloneRecord(record)) end
	local nextRecord = mutableCopy(record, nowUnix)
	nextRecord.CharacterProgression = normalized
	if grantId ~= nil then nextRecord.AppliedCharacterProgressionGrantIds[grantId] = true end
	if DurableMutation.exceedsBound(nextRecord.AppliedCharacterProgressionGrantIds) then return result(false, "MutationLedgerBoundExceeded", cloneRecord(record)) end
	local written, writeReason = guardedWrite(selfAny._store, keyFor(playerId), nextRecord)
	if not written then return result(false, writeReason, cloneRecord(record)) end
	selfAny._records[playerId] = nextRecord
	return result(true, "CharacterProgressionApplied", cloneRecord(nextRecord))
end

function Service:equip(playerId: number, slotId: EquipmentSlotId, instanceId: string, nowUnix: number): MutationResult
	local selfAny = self :: any
	if selfAny._destroyed then return result(false, "ServiceDestroyed", nil) end
	local record: PlayerInventoryRecord? = selfAny._records[playerId]
	if record == nil then return result(false, "PlayerNotLoaded", nil) end
	if not isKnownValue(VALID_SLOTS, slotId) or type(instanceId) ~= "string" or type(nowUnix) ~= "number" or nowUnix < record.UpdatedAtUnix then return result(false, "InvalidEquipRequest", cloneRecord(record)) end
	local reward = record.InventoryByInstanceId[instanceId]
	if reward == nil then return result(false, "ItemNotOwned", cloneRecord(record)) end
	if reward.Slot ~= slotId then return result(false, "SlotMismatch", cloneRecord(record)) end
	local nextRecord = mutableCopy(record, nowUnix)
	nextRecord.EquippedBySlot[slotId] = instanceId
	local written, writeReason = guardedWrite(selfAny._store, keyFor(playerId), nextRecord)
	if not written then return result(false, writeReason, cloneRecord(record)) end
	selfAny._records[playerId] = nextRecord
	return result(true, "ItemEquipped", cloneRecord(nextRecord))
end

function Service:dismantle(playerId: number, instanceId: string, transactionId: string, nowUnix: number, hasSessionLease: boolean, recentRequestTimestamps: { number }): any
	local selfAny = self :: any
	if selfAny._destroyed then return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Outcome = nil, Record = nil }) end
	local record: PlayerInventoryRecord? = selfAny._records[playerId]
	local resolution = InventoryDismantleResolver.resolve({ RequesterId = playerId, OwnerId = playerId, InstanceId = instanceId, TransactionId = transactionId, NowUnix = nowUnix }, { Record = record, HasSessionLease = hasSessionLease == true, AppliedTransactions = if record then record.AppliedDismantleTransactions else {}, RecentRequestTimestamps = recentRequestTimestamps or {} })
	if resolution.Accepted ~= true then return table.freeze({ Accepted = false, ReasonId = resolution.ReasonId, Outcome = nil, Record = if record then cloneRecord(record) else nil }) end
	if resolution.Replayed == true then return table.freeze({ Accepted = true, ReasonId = resolution.ReasonId, Outcome = resolution.Outcome, Record = if record then cloneRecord(record) else nil }) end
	if record == nil then return table.freeze({ Accepted = false, ReasonId = "PlayerNotLoaded", Outcome = nil, Record = nil }) end
	local resolved = resolution.NextRecord :: any
	local durable = mutableCopy(record, resolved.UpdatedAtUnix)
	durable.InventoryByInstanceId = table.clone(resolved.InventoryByInstanceId)
	durable.EquippedBySlot = table.clone(resolved.EquippedBySlot)
	durable.AppliedRewardInstanceIds = table.clone(resolved.AppliedRewardInstanceIds)
	durable.AppliedRewardGrantIds = table.clone(resolved.AppliedRewardGrantIds)
	durable.AppliedDismantleTransactions = table.clone(resolved.AppliedDismantleTransactions)
	durable.AppliedDismantleTransactions[transactionId] = resolution.Outcome
	local written, writeReason = guardedWrite(selfAny._store, keyFor(playerId), durable)
	if not written then return table.freeze({ Accepted = false, ReasonId = writeReason, Outcome = nil, Record = cloneRecord(record) }) end
	selfAny._records[playerId] = durable
	return table.freeze({ Accepted = true, ReasonId = resolution.ReasonId, Outcome = resolution.Outcome, Record = cloneRecord(durable) })
end

function Service:releasePlayer(playerId: number): any
	local selfAny = self :: any
	if selfAny._destroyed then return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Released = false }) end
	if not isInteger(playerId) or playerId <= 0 then return table.freeze({ Accepted = false, ReasonId = "InvalidReleaseRequest", Released = false }) end
	local held = selfAny._records[playerId] ~= nil
	selfAny._records[playerId] = nil
	return table.freeze({ Accepted = true, ReasonId = if held then "RecordReleased" else "NoRecordHeld", Released = held })
end

function Service:getRecord(playerId: number): PlayerInventoryRecord?
	local selfAny = self :: any
	if selfAny._destroyed then return nil end
	local record = selfAny._records[playerId]
	return if record then cloneRecord(record) else nil
end

function Service:destroy()
	local selfAny = self :: any
	if selfAny._destroyed then return end
	selfAny._destroyed = true
	table.clear(selfAny._records)
end

return table.freeze(Service)
