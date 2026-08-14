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
	equip: (
		self: Service,
		playerId: number,
		slotId: EquipmentSlotId,
		instanceId: string,
		nowUnix: number
	) -> MutationResult,
	getRecord: (self: Service, playerId: number) -> PlayerInventoryRecord?,
	releasePlayer: (self: Service, playerId: number) -> any,
	destroy: (self: Service) -> (),
}

local CURRENT_SCHEMA = Contracts.CurrentSchemaVersion
local VALID_SLOTS = EquipmentContracts.SlotIds
local VALID_RARITIES = EquipmentContracts.RarityIds
local VALID_SOURCES = EquipmentContracts.SourceIds
local VALID_AFFIX_EFFECTS = EquipmentAffixContracts.EffectIds

local Service = {}
Service.__index = Service

local function keyFor(playerId: number): string
	return string.format("player:%d:inventory", playerId)
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0
end

local function isKnownValue(container: any, value: any): boolean
	for _, candidate in container do
		if candidate == value then
			return true
		end
	end
	return false
end

-- Saved rewards may predate Patch 0.3. Missing affixes therefore normalize to
-- an empty list, while malformed affix payloads fail closed instead of being
-- silently dropped. Historical rolls are validated structurally rather than
-- against today's config so a future balance change cannot invalidate old gear.
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
		table.insert(
			normalized,
			table.freeze({
				Id = rawAffix.Id,
				Version = rawAffix.Version,
				DisplayName = rawAffix.DisplayName,
				EffectId = rawAffix.EffectId,
				Value = rawAffix.Value,
			})
		)
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
	if
		type(value.DefinitionId) ~= "string"
		or type(value.DefinitionVersion) ~= "string"
		or type(value.DisplayName) ~= "string"
	then
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
		UpdatedAtUnix = nowUnix,
	}
end

--[[
	A shallow clone per field is sufficient: every value inside these tables is
	either a scalar or an already-frozen reward/outcome, so no caller can reach
	through a copy to mutate service state.
]]
local function cloneRecord(record: PlayerInventoryRecord): PlayerInventoryRecord
	local inventory = table.clone(record.InventoryByInstanceId)
	local equipped = table.clone(record.EquippedBySlot)
	local instances = table.clone(record.AppliedRewardInstanceIds)
	local grants = table.clone(record.AppliedRewardGrantIds)
	local dismantles = table.clone(record.AppliedDismantleTransactions or {})
	local signatures = table.clone(record.AppliedRewardContentSignatures or {})
	return table.freeze({
		SchemaVersion = record.SchemaVersion,
		PlayerId = record.PlayerId,
		InventoryByInstanceId = table.freeze(inventory),
		EquippedBySlot = table.freeze(equipped),
		AppliedRewardInstanceIds = table.freeze(instances),
		AppliedRewardGrantIds = table.freeze(grants),
		AppliedDismantleTransactions = table.freeze(dismantles),
		AppliedRewardContentSignatures = table.freeze(signatures),
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
	--[[
		Schema 3 added the dismantle ledger. Records saved at 1 or 2 simply have
		none, which migrates to an empty ledger: they predate dismantle, so no
		transaction can have been applied. A malformed entry is rejected rather
		than dropped, because silently discarding it would let an already-applied
		dismantle be replayed into a second destruction.
	]]
	for transactionId, outcome in raw.AppliedDismantleTransactions or {} do
		if type(transactionId) ~= "string" or type(outcome) ~= "table" then
			return nil, false, "InvalidDismantleLedger"
		end
		if type(outcome.InstanceId) ~= "string" or type(outcome.SalvagedDefinitionId) ~= "string" then
			return nil, false, "InvalidDismantleLedger"
		end
		--[[
			A replayed dismantle is answered from this record, not from the item,
			which no longer exists. A structurally incomplete outcome would answer
			the replay with nonsense, so every field a replay discloses is checked
			rather than merely typed.
		]]
		if
			not DurableMutation.isValidTransactionId(transactionId)
			or #outcome.InstanceId < 8
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
	--[[
		Schema 4 added per-grant content identity. Records saved at 1-3 have none:
		their grants are known to have happened but not what they were, so a
		repeat of one of those ids can only be treated as a replay. That is the
		safe direction -- it preserves today's behaviour for historical grants
		while new grants gain conflict detection.
	]]
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
	return record, migrated, if migrated then "MigratedRecord" else "LoadedRecord"
end

local function result(accepted: boolean, reasonId: string, record: PlayerInventoryRecord?): any
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Record = record })
end

--[[
	Every durable write passes through here. A record over the budget does not
	save a truncated version -- it does not save at all, and every later mutation
	fails the same way while the player keeps playing. Refusing before submission
	turns that into one reportable condition instead of silent permanent loss.
]]
local function guardedWrite(store: any, key: string, record: PlayerInventoryRecord): (boolean, string)
	local classification, bytes = Capacity.classify(record)
	if classification == Capacity.SizeClassifications.Exceeded then
		warn(
			string.format(
				"[AtlasPersistence] refusing write for %s: estimated %d bytes exceeds the %d byte budget",
				key,
				bytes,
				Capacity.SafeRecordByteLimit
			)
		)
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
	assert(
		type(store) == "table"
			and type(store.read) == "function"
			and type(store.write) == "function"
			and type(store.commit) == "function",
		"invalid store"
	)
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
	--[[
		A failed read is not an absent record. Treating it as one would build a
		blank record and try to persist it, so the read status is checked before
		normalization rather than relying on a downstream write guard to catch
		the consequence -- and the caller gets LoadFailed, which names what
		actually went wrong, instead of a SaveFailed that misdescribes it.
	]]
	local readResult = selfAny._store:read(keyFor(playerId))
	if readResult.Status == StorageResults.ReadStatuses.Failed then
		return table.freeze({ Accepted = false, ReasonId = "LoadFailed", Record = nil, Migrated = false })
	end

	local key = keyFor(playerId)
	local sourceSchema = if type(readResult.Value) == "table" then readResult.Value.SchemaVersion else nil
	local normalized, migrated, reasonId = normalizeRecord(readResult.Value, playerId, nowUnix)
	if normalized == nil then
		--[[
			A record we cannot parse is copied aside before the caller is told. The
			source is never rewritten: whatever is wrong with it, it is still the
			only durable state this player has, and a repair that guessed would
			destroy the evidence needed to do the repair properly.
		]]
		self:_quarantine(key, reasonId, nowUnix, readResult.Value)
		return table.freeze({
			Accepted = false,
			ReasonId = reasonId,
			Record = nil,
			Migrated = false,
			Classification = Recovery.classify(reasonId),
		})
	end

	--[[
		Migration is planned rather than assumed, so the jump taken is recorded and
		an unauthored one is refused instead of silently performed.
	]]
	local plan = MigrationSteps.plan(sourceSchema or CURRENT_SCHEMA, CURRENT_SCHEMA)
	if not plan.Accepted then
		self:_quarantine(key, plan.ReasonId, nowUnix, readResult.Value)
		return table.freeze({
			Accepted = false,
			ReasonId = plan.ReasonId,
			Record = nil,
			Migrated = false,
			Classification = Recovery.classify(plan.ReasonId),
		})
	end

	if migrated then
		--[[
			The write-back must not clobber a record that changed since the read.
			Committing through a transform lets the store's own value be compared
			at commit time, so a newer record wins instead of being overwritten by
			one derived from a stale read.
		]]
		local reconciled = true
		local write = selfAny._store:commit(key, function(current: any): any
			if current ~= nil and type(current) == "table" and current.UpdatedAtUnix ~= nil then
				if
					type(readResult.Value) ~= "table"
					or current.UpdatedAtUnix ~= readResult.Value.UpdatedAtUnix
					or current.SchemaVersion ~= sourceSchema
				then
					reconciled = false
					return current
				end
			end
			reconciled = true
			return normalized
		end)
		if not reconciled then
			return table.freeze({
				Accepted = false,
				ReasonId = "MigrationRaceDetected",
				Record = nil,
				Migrated = false,
				Classification = Recovery.Classifications.Transient,
			})
		end
		if write.Status ~= StorageResults.WriteStatuses.Committed then
			return table.freeze({
				Accepted = false,
				ReasonId = "SaveFailed",
				Record = nil,
				Migrated = false,
				Classification = Recovery.Classifications.Transient,
			})
		end
	end

	selfAny._records[playerId] = normalized
	return table.freeze({
		Accepted = true,
		ReasonId = reasonId,
		Record = cloneRecord(normalized),
		Migrated = migrated,
		MigrationStepIds = plan.StepIds,
	})
end

--[[
	Quarantine copies the damaged payload to a derived key and leaves the source
	untouched. A failure to quarantine is deliberately not fatal: the load has
	already failed, and losing the diagnostic copy is strictly better than turning
	a diagnosable failure into an unexplained one.
]]
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
	if selfAny._destroyed then
		return result(false, "ServiceDestroyed", nil)
	end
	local record: PlayerInventoryRecord? = selfAny._records[playerId]
	if record == nil then
		return result(false, "PlayerNotLoaded", nil)
	end
	local normalized = normalizedReward(reward)
	if normalized == nil or type(nowUnix) ~= "number" or nowUnix < record.UpdatedAtUnix then
		return result(false, "InvalidReward", cloneRecord(record))
	end
	--[[
		A repeat of a grant id is either a retry of the same grant or a different
		grant wearing a used id, and those need opposite answers. The ledger used
		to record only that an id had been used, so the second case was reported
		as the first and the differing reward was discarded without a signal.

		Historical grants carry no recorded signature, so they can only be treated
		as replays -- the safe direction, and exactly what happened before.
	]]
	if record.AppliedRewardGrantIds[normalized.GrantId] then
		local knownSignature = record.AppliedRewardContentSignatures[normalized.GrantId]
		if knownSignature ~= nil and knownSignature ~= normalized.ContentSignature then
			return result(false, "RewardGrantConflict", cloneRecord(record))
		end
		return result(false, "RewardAlreadyApplied", cloneRecord(record))
	end
	if record.AppliedRewardInstanceIds[normalized.InstanceId] then
		return result(false, "RewardAlreadyApplied", cloneRecord(record))
	end

	local nextRecord = newRecord(playerId, nowUnix)
	for id, existing in record.InventoryByInstanceId do
		nextRecord.InventoryByInstanceId[id] = existing
	end
	for slot, id in record.EquippedBySlot do
		nextRecord.EquippedBySlot[slot] = id
	end
	for id, applied in record.AppliedRewardInstanceIds do
		nextRecord.AppliedRewardInstanceIds[id] = applied
	end
	for id, applied in record.AppliedRewardGrantIds do
		nextRecord.AppliedRewardGrantIds[id] = applied
	end
	-- Carrying the dismantle ledger forward is mandatory: dropping it would let
	-- an already-applied dismantle replay into a second destruction.
	for transactionId, outcome in record.AppliedDismantleTransactions do
		nextRecord.AppliedDismantleTransactions[transactionId] = outcome
	end
	for grantId, signature in record.AppliedRewardContentSignatures do
		nextRecord.AppliedRewardContentSignatures[grantId] = signature
	end
	nextRecord.InventoryByInstanceId[normalized.InstanceId] = normalized
	nextRecord.AppliedRewardInstanceIds[normalized.InstanceId] = true
	nextRecord.AppliedRewardGrantIds[normalized.GrantId] = true
	nextRecord.AppliedRewardContentSignatures[normalized.GrantId] = normalized.ContentSignature

	--[[
		Ledgers only grow. A record past the bound would eventually stop saving
		at the DataStore size limit, losing the inventory rather than just the
		ledger, so the write is refused here where it can still be reported.
	]]
	if
		DurableMutation.exceedsBound(nextRecord.AppliedRewardGrantIds)
		or DurableMutation.exceedsBound(nextRecord.AppliedDismantleTransactions)
	then
		return result(false, "MutationLedgerBoundExceeded", cloneRecord(record))
	end
	local written, writeReason = guardedWrite(selfAny._store, keyFor(playerId), nextRecord)
	if not written then
		return result(false, writeReason, cloneRecord(record))
	end
	selfAny._records[playerId] = nextRecord
	return result(true, "RewardApplied", cloneRecord(nextRecord))
end

function Service:equip(playerId: number, slotId: EquipmentSlotId, instanceId: string, nowUnix: number): MutationResult
	local selfAny = self :: any
	if selfAny._destroyed then
		return result(false, "ServiceDestroyed", nil)
	end
	local record: PlayerInventoryRecord? = selfAny._records[playerId]
	if record == nil then
		return result(false, "PlayerNotLoaded", nil)
	end
	if
		not isKnownValue(VALID_SLOTS, slotId)
		or type(instanceId) ~= "string"
		or type(nowUnix) ~= "number"
		or nowUnix < record.UpdatedAtUnix
	then
		return result(false, "InvalidEquipRequest", cloneRecord(record))
	end
	local reward = record.InventoryByInstanceId[instanceId]
	if reward == nil then
		return result(false, "ItemNotOwned", cloneRecord(record))
	end
	if reward.Slot ~= slotId then
		return result(false, "SlotMismatch", cloneRecord(record))
	end
	local nextRecord = newRecord(playerId, nowUnix)
	for id, existing in record.InventoryByInstanceId do
		nextRecord.InventoryByInstanceId[id] = existing
	end
	for slot, id in record.EquippedBySlot do
		nextRecord.EquippedBySlot[slot] = id
	end
	for id, applied in record.AppliedRewardInstanceIds do
		nextRecord.AppliedRewardInstanceIds[id] = applied
	end
	for id, applied in record.AppliedRewardGrantIds do
		nextRecord.AppliedRewardGrantIds[id] = applied
	end
	-- Carrying the dismantle ledger forward is mandatory: dropping it would let
	-- an already-applied dismantle replay into a second destruction.
	for transactionId, outcome in record.AppliedDismantleTransactions do
		nextRecord.AppliedDismantleTransactions[transactionId] = outcome
	end
	for grantId, signature in record.AppliedRewardContentSignatures do
		nextRecord.AppliedRewardContentSignatures[grantId] = signature
	end
	nextRecord.EquippedBySlot[slotId] = instanceId
	local written, writeReason = guardedWrite(selfAny._store, keyFor(playerId), nextRecord)
	if not written then
		return result(false, writeReason, cloneRecord(record))
	end
	selfAny._records[playerId] = nextRecord
	return result(true, "ItemEquipped", cloneRecord(nextRecord))
end

--[[
	Destroys one owned item under a transaction id. The decision belongs to the
	pure resolver; this method owns only the durable parts — recording the
	transaction so a replay survives a rejoin, and the write itself.

	A failed save leaves the in-memory record untouched, so a retry of the same
	transaction re-runs the decision rather than reporting a destruction that
	was never persisted.
]]
function Service:dismantle(
	playerId: number,
	instanceId: string,
	transactionId: string,
	nowUnix: number,
	hasSessionLease: boolean,
	recentRequestTimestamps: { number }
): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Outcome = nil, Record = nil })
	end
	local record: PlayerInventoryRecord? = selfAny._records[playerId]

	local resolution = InventoryDismantleResolver.resolve({
		RequesterId = playerId,
		OwnerId = playerId,
		InstanceId = instanceId,
		TransactionId = transactionId,
		NowUnix = nowUnix,
	}, {
		Record = record,
		HasSessionLease = hasSessionLease == true,
		AppliedTransactions = if record then record.AppliedDismantleTransactions else {},
		RecentRequestTimestamps = recentRequestTimestamps or {},
	})

	if resolution.Accepted ~= true then
		return table.freeze({
			Accepted = false,
			ReasonId = resolution.ReasonId,
			Outcome = nil,
			Record = if record then cloneRecord(record) else nil,
		})
	end

	-- A replay writes nothing; the original transaction already persisted.
	if resolution.Replayed == true then
		return table.freeze({
			Accepted = true,
			ReasonId = resolution.ReasonId,
			Outcome = resolution.Outcome,
			Record = if record then cloneRecord(record) else nil,
		})
	end

	local nextRecord = resolution.NextRecord :: any
	local durable = newRecord(playerId, nextRecord.UpdatedAtUnix)
	for id, existing in nextRecord.InventoryByInstanceId do
		durable.InventoryByInstanceId[id] = existing
	end
	for slot, id in nextRecord.EquippedBySlot do
		durable.EquippedBySlot[slot] = id
	end
	for id, applied in nextRecord.AppliedRewardInstanceIds do
		durable.AppliedRewardInstanceIds[id] = applied
	end
	for id, applied in nextRecord.AppliedRewardGrantIds do
		durable.AppliedRewardGrantIds[id] = applied
	end
	for id, outcome in nextRecord.AppliedDismantleTransactions do
		durable.AppliedDismantleTransactions[id] = outcome
	end
	--[[
		Destroying an item must not erase the record that its grant was already
		applied, or the same reward could be granted again after a dismantle.
	]]
	for grantId, signature in record.AppliedRewardContentSignatures do
		durable.AppliedRewardContentSignatures[grantId] = signature
	end
	durable.AppliedDismantleTransactions[transactionId] = resolution.Outcome

	local written, writeReason = guardedWrite(selfAny._store, keyFor(playerId), durable)
	if not written then
		return table.freeze({
			Accepted = false,
			ReasonId = writeReason,
			Outcome = nil,
			Record = if record then cloneRecord(record) else nil,
		})
	end
	selfAny._records[playerId] = durable
	return table.freeze({
		Accepted = true,
		ReasonId = resolution.ReasonId,
		Outcome = resolution.Outcome,
		Record = cloneRecord(durable),
	})
end

--[[
	Drops one player's in-memory record. Load is wired to PlayerAdded, so without
	a symmetric release every player who ever joined stays resident for the life
	of the server, and a departed player's inventory remains readable through
	getRecord long after their session lease was released.

	This deliberately writes nothing. Every mutation path already saves before it
	updates memory, so the store is current by construction; saving on release
	would risk overwriting a newer record written by whichever server acquired
	the lease next.
]]
function Service:releasePlayer(playerId: number): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return table.freeze({ Accepted = false, ReasonId = "ServiceDestroyed", Released = false })
	end
	if not isInteger(playerId) or playerId <= 0 then
		return table.freeze({ Accepted = false, ReasonId = "InvalidReleaseRequest", Released = false })
	end
	local held = selfAny._records[playerId] ~= nil
	selfAny._records[playerId] = nil
	return table.freeze({
		Accepted = true,
		ReasonId = if held then "RecordReleased" else "NoRecordHeld",
		Released = held,
	})
end

function Service:getRecord(playerId: number): PlayerInventoryRecord?
	local selfAny = self :: any
	if selfAny._destroyed then
		return nil
	end
	local record = selfAny._records[playerId]
	return if record then cloneRecord(record) else nil
end

function Service:destroy()
	local selfAny = self :: any
	if selfAny._destroyed then
		return
	end
	selfAny._destroyed = true
	table.clear(selfAny._records)
end

return table.freeze(Service)
