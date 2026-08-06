--!strict

--[[
	VS-0109 account-safe inventory/equipment persistence over an injected store.
	The adapter validates every loaded record, migrates empty/legacy state, applies
	rewards idempotently by immutable instance ID, and persists server-owned copies.
]]

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
	equip: (self: Service, playerId: number, slotId: EquipmentSlotId, instanceId: string, nowUnix: number) -> MutationResult,
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

local function copyReward(reward: EquipmentReward): EquipmentReward
	return table.freeze({
		InstanceId = reward.InstanceId,
		DefinitionId = reward.DefinitionId,
		DefinitionVersion = reward.DefinitionVersion,
		DisplayName = reward.DisplayName,
		Slot = reward.Slot,
		Rarity = reward.Rarity,
		Power = reward.Power,
		SourceId = reward.SourceId,
		RunId = reward.RunId,
		Seed = reward.Seed,
	})
end

local function validateReward(value: any): boolean
	return type(value) == "table"
		and type(value.InstanceId) == "string"
		and #value.InstanceId >= 8
		and type(value.DefinitionId) == "string"
		and type(value.DefinitionVersion) == "string"
		and type(value.DisplayName) == "string"
		and isKnownValue(VALID_SLOTS, value.Slot)
		and isKnownValue(VALID_RARITIES, value.Rarity)
		and isInteger(value.Power)
		and value.Power >= 1
		and isKnownValue(VALID_SOURCES, value.SourceId)
		and type(value.RunId) == "string"
		and isInteger(value.Seed)
end

local function newRecord(playerId: number, nowUnix: number): PlayerInventoryRecord
	return {
		SchemaVersion = CURRENT_SCHEMA,
		PlayerId = playerId,
		InventoryByInstanceId = {},
		EquippedBySlot = {},
		AppliedRewardInstanceIds = {},
		UpdatedAtUnix = nowUnix,
	}
end

local function cloneRecord(record: PlayerInventoryRecord): PlayerInventoryRecord
	local inventory = {}
	for instanceId, reward in record.InventoryByInstanceId do
		inventory[instanceId] = copyReward(reward)
	end

	local equipped = {}
	for slotId, instanceId in record.EquippedBySlot do
		equipped[slotId] = instanceId
	end

	local applied = {}
	for instanceId, value in record.AppliedRewardInstanceIds do
		applied[instanceId] = value
	end

	return table.freeze({
		SchemaVersion = record.SchemaVersion,
		PlayerId = record.PlayerId,
		InventoryByInstanceId = table.freeze(inventory),
		EquippedBySlot = table.freeze(equipped),
		AppliedRewardInstanceIds = table.freeze(applied),
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

	local schemaVersion = raw.SchemaVersion
	if schemaVersion == nil then
		-- Explicit migration from the pre-schema empty inventory shape.
		raw = {
			SchemaVersion = CURRENT_SCHEMA,
			PlayerId = playerId,
			InventoryByInstanceId = raw.InventoryByInstanceId or {},
			EquippedBySlot = raw.EquippedBySlot or {},
			AppliedRewardInstanceIds = raw.AppliedRewardInstanceIds or {},
			UpdatedAtUnix = nowUnix,
		}
		schemaVersion = CURRENT_SCHEMA
	end
	if schemaVersion ~= CURRENT_SCHEMA then
		return nil, false, "UnsupportedSchemaVersion"
	end
	if raw.PlayerId ~= playerId then
		return nil, false, "PlayerIdMismatch"
	end
	if type(raw.InventoryByInstanceId) ~= "table"
		or type(raw.EquippedBySlot) ~= "table"
		or type(raw.AppliedRewardInstanceIds) ~= "table"
	then
		return nil, false, "InvalidSavedRecord"
	end

	local record = newRecord(playerId, nowUnix)
	for instanceId, reward in raw.InventoryByInstanceId do
		if type(instanceId) ~= "string" or not validateReward(reward) or reward.InstanceId ~= instanceId then
			return nil, false, "InvalidInventoryReward"
		end
		record.InventoryByInstanceId[instanceId] = copyReward(reward)
	end
	for instanceId, applied in raw.AppliedRewardInstanceIds do
		if type(instanceId) ~= "string" or applied ~= true then
			return nil, false, "InvalidAppliedRewardIndex"
		end
		record.AppliedRewardInstanceIds[instanceId] = true
	end
	for slotId, instanceId in raw.EquippedBySlot do
		if not isKnownValue(VALID_SLOTS, slotId) or type(instanceId) ~= "string" then
			return nil, false, "InvalidEquippedSlot"
		end
		local reward = record.InventoryByInstanceId[instanceId]
		if reward == nil or reward.Slot ~= slotId then
			return nil, false, "EquippedItemMismatch"
		end
		record.EquippedBySlot[slotId] = instanceId
	end

	return record, raw.SchemaVersion == nil, "LoadedRecord"
end

local function result(accepted: boolean, reasonId: string, record: PlayerInventoryRecord?): any
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Record = record })
end

function Service.new(store: Store): Service
	assert(type(store) == "table" and type(store.load) == "function" and type(store.save) == "function", "invalid store")
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

	local raw = selfAny._store:load(keyFor(playerId))
	local normalized, migrated, reasonId = normalizeRecord(raw, playerId, nowUnix)
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
	if not validateReward(reward) or type(nowUnix) ~= "number" or nowUnix < record.UpdatedAtUnix then
		return result(false, "InvalidReward", cloneRecord(record))
	end
	if record.AppliedRewardInstanceIds[reward.InstanceId] then
		return result(false, "RewardAlreadyApplied", cloneRecord(record))
	end

	local nextRecord = newRecord(playerId, nowUnix)
	for instanceId, existing in record.InventoryByInstanceId do
		nextRecord.InventoryByInstanceId[instanceId] = existing
	end
	for slotId, instanceId in record.EquippedBySlot do
		nextRecord.EquippedBySlot[slotId] = instanceId
	end
	for instanceId, applied in record.AppliedRewardInstanceIds do
		nextRecord.AppliedRewardInstanceIds[instanceId] = applied
	end
	nextRecord.InventoryByInstanceId[reward.InstanceId] = copyReward(reward)
	nextRecord.AppliedRewardInstanceIds[reward.InstanceId] = true

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
	if not isKnownValue(VALID_SLOTS, slotId) or type(instanceId) ~= "string" or type(nowUnix) ~= "number" or nowUnix < record.UpdatedAtUnix then
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
	for id, existing in record.InventoryByInstanceId do nextRecord.InventoryByInstanceId[id] = existing end
	for existingSlot, equippedId in record.EquippedBySlot do nextRecord.EquippedBySlot[existingSlot] = equippedId end
	for id, applied in record.AppliedRewardInstanceIds do nextRecord.AppliedRewardInstanceIds[id] = applied end
	nextRecord.EquippedBySlot[slotId] = instanceId

	if not selfAny._store:save(keyFor(playerId), nextRecord) then
		return result(false, "SaveFailed", cloneRecord(record))
	end
	selfAny._records[playerId] = nextRecord
	return result(true, "ItemEquipped", cloneRecord(nextRecord))
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
