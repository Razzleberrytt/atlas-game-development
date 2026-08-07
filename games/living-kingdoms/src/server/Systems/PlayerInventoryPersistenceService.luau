--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Persistence.PlayerInventoryContracts)
local EquipmentContracts = require(ReplicatedStorage.Shared.Equipment.EquipmentRewardContracts)

export type EquipmentReward = EquipmentContracts.EquipmentReward
export type EquipmentSlotId = EquipmentContracts.EquipmentSlotId
export type PlayerInventoryRecord = Contracts.PlayerInventoryRecord
export type LoadResult = Contracts.LoadResult
export type MutationResult = Contracts.MutationResult

export type Store = {
	load: (self: Store, key: string) -> any,
	save: (self: Store, key: string, value: any) -> boolean,
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
	destroy: (self: Service) -> (),
}

local CURRENT_SCHEMA = Contracts.CurrentSchemaVersion
local VALID_SLOTS = EquipmentContracts.SlotIds
local VALID_RARITIES = EquipmentContracts.RarityIds
local VALID_SOURCES = EquipmentContracts.SourceIds

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
		UpdatedAtUnix = nowUnix,
	}
end

local function cloneRecord(record: PlayerInventoryRecord): PlayerInventoryRecord
	local inventory, equipped, instances, grants = {}, {}, {}, {}
	for id, reward in record.InventoryByInstanceId do
		inventory[id] = reward
	end
	for slot, id in record.EquippedBySlot do
		equipped[slot] = id
	end
	for id, value in record.AppliedRewardInstanceIds do
		instances[id] = value
	end
	for id, value in record.AppliedRewardGrantIds do
		grants[id] = value
	end
	return table.freeze({
		SchemaVersion = record.SchemaVersion,
		PlayerId = record.PlayerId,
		InventoryByInstanceId = table.freeze(inventory),
		EquippedBySlot = table.freeze(equipped),
		AppliedRewardInstanceIds = table.freeze(instances),
		AppliedRewardGrantIds = table.freeze(grants),
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
	if schema ~= nil and schema ~= 1 and schema ~= CURRENT_SCHEMA then
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

function Service.new(store: Store): Service
	assert(
		type(store) == "table" and type(store.load) == "function" and type(store.save) == "function",
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
	local normalized, migrated, reasonId = normalizeRecord(selfAny._store:load(keyFor(playerId)), playerId, nowUnix)
	if normalized == nil then
		return table.freeze({ Accepted = false, ReasonId = reasonId, Record = nil, Migrated = false })
	end
	if migrated and not selfAny._store:save(keyFor(playerId), normalized) then
		return table.freeze({ Accepted = false, ReasonId = "SaveFailed", Record = nil, Migrated = false })
	end
	selfAny._records[playerId] = normalized
	return table.freeze({ Accepted = true, ReasonId = reasonId, Record = cloneRecord(normalized), Migrated = migrated })
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
	if record.AppliedRewardGrantIds[normalized.GrantId] or record.AppliedRewardInstanceIds[normalized.InstanceId] then
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
	nextRecord.InventoryByInstanceId[normalized.InstanceId] = normalized
	nextRecord.AppliedRewardInstanceIds[normalized.InstanceId] = true
	nextRecord.AppliedRewardGrantIds[normalized.GrantId] = true
	if not selfAny._store:save(keyFor(playerId), nextRecord) then
		return result(false, "SaveFailed", cloneRecord(record))
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
	nextRecord.EquippedBySlot[slotId] = instanceId
	if not selfAny._store:save(keyFor(playerId), nextRecord) then
		return result(false, "SaveFailed", cloneRecord(record))
	end
	selfAny._records[playerId] = nextRecord
	return result(true, "ItemEquipped", cloneRecord(nextRecord))
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
